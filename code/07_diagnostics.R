# ============================================================
# Script: 07_diagnostics.R
# Purpose: Model diagnostics and performance evaluation:
#          - Schoenfeld residual plots (PH assumption)
#          - C-index on held-out test set (Cox AND Fine-Gray independently)
#          - Time-dependent AUC at 1, 2, 3, 5 year horizons
#          - Integrated Brier Score
#          - Performance comparison table
#          - AUC-over-time figure
# Input: data/cleaned/securities_cohort_cleaned.rds,
#        output/models/cox_models.rds, output/models/fine_gray_models.rds
# Output: output/figures/fig_schoenfeld_*.pdf
#         output/figures/fig_auc_over_time.pdf
#         output/tables/tab_model_performance.tex
#         Console: corrected performance metrics
# Dependencies: survival, timeROC, pec, tidyverse, here
# Seed: 42 (train/test split)
# ============================================================

source("code/utils.R")

# Load timeROC and pec (not in default utils.R required list)
for (pkg in c("timeROC", "pec")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("Package '%s' required. Install with: install.packages('%s')", pkg, pkg))
  }
  library(pkg, character.only = TRUE)
}

cat("=================================================================\n")
cat(" 07_diagnostics.R — MODEL DIAGNOSTICS & PERFORMANCE EVALUATION\n")
cat("=================================================================\n\n")

# =============================================================================
# LOAD DATA AND SAVED MODELS
# =============================================================================
cat("Loading cleaned data and saved model objects...\n")
df <- readRDS(here::here("data", "cleaned", "securities_cohort_cleaned.rds"))
cat(sprintf("  Data: %s rows\n", format(nrow(df), big.mark = ",")))

cox_results <- readRDS(here::here("output", "models", "cox_models.rds"))
fg_results  <- readRDS(here::here("output", "models", "fine_gray_models.rds"))
cat("  Loaded: cox_models.rds, fine_gray_models.rds\n")

# Validate required fields exist (fail fast if .rds is stale)
stopifnot("cox_models.rds missing 'ext_formula_rhs'" = "ext_formula_rhs" %in% names(cox_results))
stopifnot("cox_models.rds missing 'circuits_incl'"    = "circuits_incl"   %in% names(cox_results))
stopifnot("cox_models.rds missing 'include_stat'"     = "include_stat"    %in% names(cox_results))

# Extract metadata
ext_formula_rhs <- cox_results$ext_formula_rhs
circuits_incl   <- cox_results$circuits_incl


# =============================================================================
# RECONSTRUCT EXTENDED DATASET (needed for cox.zph, train/test split)
# =============================================================================
cat("\nReconstructing extended dataset...\n")

df_circ <- df %>%
  filter(circuit %in% circuits_incl) %>%
  mutate(circuit_f = relevel(factor(circuit), ref = "2"))

df_ext <- df_circ %>%
  filter(!is.na(origin_cat), !is.na(mdl_flag), !is.na(juris_fq))

# Load include_stat from saved metadata (consistency with 03_cox_models.R)
include_stat <- cox_results$include_stat
if (include_stat) {
  df_ext <- df_ext %>%
    mutate(stat_basis_f = forcats::fct_na_value_to_level(stat_basis_f, level = "Missing"))
}
cat(sprintf("  Extended dataset: %s rows\n", format(nrow(df_ext), big.mark = ",")))

# Refit extended Cox on full sample (cox.zph needs the data in scope)
cox_s_ext <- coxph(
  as.formula(paste("Surv(duration_years, event_type==1) ~", ext_formula_rhs)),
  data = df_ext
)
cox_d_ext <- coxph(
  as.formula(paste("Surv(duration_years, event_type==2) ~", ext_formula_rhs)),
  data = df_ext
)
cat("  Extended Cox models refit for diagnostics.\n")


# =============================================================================
# SECTION 1: SCHOENFELD RESIDUAL PLOTS (PH ASSUMPTION)
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("SCHOENFELD RESIDUAL TESTS (extended models on full sample)\n")
cat("-----------------------------------------------------------------\n")

# PH tests on the full-sample EXTENDED models (includes stat_basis_f).
# Note: performance metrics (C-index, AUC, IBS) in Sections 4-6 use a REDUCED
# formula without stat_basis_f (complete separation produces Inf coefficients).
# The PH test applies to the richer specification; performance is evaluated on
# the specification that yields finite predictions.
ph_test_s <- cox.zph(cox_s_ext)
ph_test_d <- cox.zph(cox_d_ext)

cat("\nProportional Hazards Test — Extended Settlement Model:\n")
print(ph_test_s)

cat("\nProportional Hazards Test — Extended Dismissal Model:\n")
print(ph_test_d)

# Schoenfeld plots for post_pslra (the key covariate)
cat("\nGenerating Schoenfeld residual plots...\n")

# Helper: render a base-R plot to both PDF and PNG
save_base_plot <- function(filename, width, height, plot_fn) {
  pdf(here::here("output", "figures", paste0(filename, ".pdf")),
      width = width, height = height)
  plot_fn()
  dev.off()
  png(here::here("output", "figures", paste0(filename, ".png")),
      width = width, height = height, units = "in", res = 300)
  plot_fn()
  dev.off()
  cat(sprintf("  Saved: output/figures/%s.{pdf,png}\n", filename))
}

# Settlement: post_pslra
save_base_plot("fig_schoenfeld_settlement_pslra", 8, 6, function() {
  plot(ph_test_s, var = "post_pslra",
       main = "Schoenfeld Residuals: PSLRA (Settlement Model)",
       xlab = "Time (years)", ylab = "Beta(t) for post_pslra")
  abline(h = coef(cox_s_ext)["post_pslra"], col = "red", lty = 2)
  legend("topright", "Overall coefficient", col = "red", lty = 2, bty = "n")
})

# Dismissal: post_pslra
save_base_plot("fig_schoenfeld_dismissal_pslra", 8, 6, function() {
  plot(ph_test_d, var = "post_pslra",
       main = "Schoenfeld Residuals: PSLRA (Dismissal Model)",
       xlab = "Time (years)", ylab = "Beta(t) for post_pslra")
  abline(h = coef(cox_d_ext)["post_pslra"], col = "red", lty = 2)
  legend("topright", "Overall coefficient", col = "red", lty = 2, bty = "n")
})

# Full Schoenfeld panel for dismissal (all covariates)
n_terms_d <- nrow(ph_test_d$table) - 1  # exclude GLOBAL
n_rows <- ceiling(n_terms_d / 3)

save_base_plot("fig_schoenfeld_dismissal_all", 12, 4 * n_rows, function() {
  par(mfrow = c(n_rows, 3))
  for (i in seq_len(n_terms_d)) {
    plot(ph_test_d, var = i,
         main = rownames(ph_test_d$table)[i],
         xlab = "Time (years)", ylab = "Beta(t)")
  }
})
cat(sprintf("  (%d panels in dismissal_all)\n", n_terms_d))


# =============================================================================
# SECTION 2: TRAIN/TEST SPLIT FOR PERFORMANCE EVALUATION
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("TRAIN/TEST SPLIT (70/30, stratified by PSLRA)\n")
cat("-----------------------------------------------------------------\n")

# Performance models use a REDUCED formula excluding stat_basis
# (complete separation in stat_basis_fSection11 produces infinite coefficients
# that propagate as Inf linear predictors, breaking concordance computation)
perf_formula_rhs <- "post_pslra + circuit_f + origin_cat + mdl_flag + juris_fq"

set.seed(42)

df_perf <- df_ext %>%
  mutate(
    circuit_f  = droplevels(circuit_f),
    origin_cat = droplevels(origin_cat),
    row_id     = row_number()
  )

train_ids <- df_perf %>%
  group_by(post_pslra) %>%
  slice_sample(prop = 0.70) %>%
  pull(row_id)

df_train <- df_perf %>% filter( row_id %in% train_ids)
df_test  <- df_perf %>% filter(!row_id %in% train_ids)

# Align factor levels (safe idiom: re-factor rather than reassign levels)
for (fv in c("circuit_f", "origin_cat")) {
  df_test[[fv]] <- factor(df_test[[fv]], levels = levels(df_train[[fv]]))
}

cat(sprintf("  Training: %s | Test: %s\n",
            format(nrow(df_train), big.mark = ","),
            format(nrow(df_test), big.mark = ",")))
cat(sprintf("  Note: stat_basis excluded from performance models (complete separation).\n"))


# =============================================================================
# SECTION 3: REFIT MODELS ON TRAINING DATA
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("REFITTING MODELS ON TRAINING DATA\n")
cat("-----------------------------------------------------------------\n")

# --- Cox models (training set, reduced formula) ---
cox_s_train <- coxph(
  as.formula(paste("Surv(duration_years, event_type==1) ~", perf_formula_rhs)),
  data = df_train, x = TRUE
)
cox_d_train <- coxph(
  as.formula(paste("Surv(duration_years, event_type==2) ~", perf_formula_rhs)),
  data = df_train, x = TRUE
)
cat("  Cox models refit on training data.\n")

# --- Fine-Gray models (training set, reduced formula) ---
fg_cols <- c("duration_years", "event_type", "post_pslra", "circuit_f",
             "origin_cat", "mdl_flag", "juris_fq")

fg_tr_s_data <- finegray(
  Surv(duration_years, factor(event_type, 0:2)) ~ .,
  data  = df_train %>% select(all_of(fg_cols)),
  etype = 1
)
fg_s_train <- coxph(
  as.formula(paste("Surv(fgstart, fgstop, fgstatus) ~", perf_formula_rhs)),
  data = fg_tr_s_data, weights = fgwt, x = TRUE
)

fg_tr_d_data <- finegray(
  Surv(duration_years, factor(event_type, 0:2)) ~ .,
  data  = df_train %>% select(all_of(fg_cols)),
  etype = 2
)
fg_d_train <- coxph(
  as.formula(paste("Surv(fgstart, fgstop, fgstatus) ~", perf_formula_rhs)),
  data = fg_tr_d_data, weights = fgwt, x = TRUE
)
cat("  Fine-Gray models refit on training data.\n")


# =============================================================================
# SECTION 4: C-INDEX ON HELD-OUT TEST SET
# (FIX: compute linear predictors BEFORE using them;
#  FIX: compute Fine-Gray C-index independently from Cox)
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("C-INDEX ON HELD-OUT TEST SET\n")
cat("-----------------------------------------------------------------\n")

# Step 1: Compute linear predictors from Cox training models
lp_cox_s <- predict(cox_s_train, newdata = df_test, type = "lp")
lp_cox_d <- predict(cox_d_train, newdata = df_test, type = "lp")
cat(sprintf("  Cox linear predictors computed: %d values each\n", length(lp_cox_s)))

# Step 2: Compute linear predictors from Fine-Gray training models
# Fine-Gray models operate on the finegray-expanded dataset, but for prediction
# on the original test data we need the model matrix from the original covariates.
# The coefficients apply to the same covariates, so we can compute lp manually.
fg_s_coefs <- coef(fg_s_train)
fg_d_coefs <- coef(fg_d_train)

# Build model matrix from test data using the same formula
mm_test <- model.matrix(
  as.formula(paste("~", perf_formula_rhs)),
  data = df_test
)[, -1]  # drop intercept

lp_fg_s <- as.numeric(mm_test %*% fg_s_coefs)
lp_fg_d <- as.numeric(mm_test %*% fg_d_coefs)
cat(sprintf("  Fine-Gray linear predictors computed: %d values each\n", length(lp_fg_s)))

# Step 3: C-index
# concordance(Surv ~ x) convention: higher x = BETTER prognosis (longer survival).
# But Cox lp: higher = higher hazard = WORSE prognosis. So we negate lp.
# (Same for Fine-Gray: higher subdistribution lp = higher subdistribution hazard.)

eval_df <- data.frame(
  time     = df_test$duration_years,
  status_s = as.numeric(df_test$event_type == 1),
  status_d = as.numeric(df_test$event_type == 2),
  neg_lp_cox_s = -lp_cox_s,
  neg_lp_cox_d = -lp_cox_d,
  neg_lp_fg_s  = -lp_fg_s,
  neg_lp_fg_d  = -lp_fg_d
)

# NOTE on Fine-Gray concordance: concordance() treats competing events as censored
# (binary status_s/status_d), but the Fine-Gray subdistribution framework keeps
# competing-event subjects at risk. There is no out-of-the-box "subdistribution
# concordance" in the survival package. This is a standard approximation; the
# limitation is documented in the thesis Discussion chapter.
cind_cox_s <- concordance(Surv(time, status_s) ~ neg_lp_cox_s, data = eval_df)
cind_cox_d <- concordance(Surv(time, status_d) ~ neg_lp_cox_d, data = eval_df)
cind_fg_s  <- concordance(Surv(time, status_s) ~ neg_lp_fg_s,  data = eval_df)
cind_fg_d  <- concordance(Surv(time, status_d) ~ neg_lp_fg_d,  data = eval_df)

# Sanity check: training set C-index should match
cind_train_check <- concordance(cox_s_train)
cat(sprintf("  Sanity: Cox-S training C-index = %.4f (expect > 0.5)\n",
            cind_train_check$concordance))

cat("\n  --- C-index Results ---\n")
cat(sprintf("  Cox C-index (Settlement):       %.4f (SE: %.4f)\n",
            cind_cox_s$concordance, sqrt(cind_cox_s$var)))
cat(sprintf("  Cox C-index (Dismissal):        %.4f (SE: %.4f)\n",
            cind_cox_d$concordance, sqrt(cind_cox_d$var)))
cat(sprintf("  Fine-Gray C-index (Settlement): %.4f (SE: %.4f)\n",
            cind_fg_s$concordance, sqrt(cind_fg_s$var)))
cat(sprintf("  Fine-Gray C-index (Dismissal):  %.4f (SE: %.4f)\n",
            cind_fg_d$concordance, sqrt(cind_fg_d$var)))

# Verify Cox != Fine-Gray (the false assumption from the old code)
if (abs(cind_cox_s$concordance - cind_fg_s$concordance) < 1e-6 &&
    abs(cind_cox_d$concordance - cind_fg_d$concordance) < 1e-6) {
  cat("  WARNING: Cox and Fine-Gray C-indices are identical.\n")
  cat("           This is unlikely — check linear predictor computation.\n")
} else {
  cat("  VERIFIED: Cox and Fine-Gray C-indices differ (independently computed).\n")
}


# =============================================================================
# SECTION 5: TIME-DEPENDENT AUC
# iid=TRUE enabled: produces AUC confidence intervals via confint().
# This is slower (~10min vs ~1min with 3.8k obs) but required for final output.
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("TIME-DEPENDENT AUC ON HELD-OUT TEST SET\n")
cat("-----------------------------------------------------------------\n")

time_points <- c(1, 2, 3, 5)

# Cox AUC — use full event_type (0/1/2) so timeROC computes competing-risks-
# aware IPCW weights (competing events are not independent censoring).
troc_cox_s <- tryCatch(
  timeROC(
    T      = df_test$duration_years,
    delta  = as.integer(df_test$event_type),
    marker = lp_cox_s,
    cause  = 1,
    times  = time_points,
    iid    = TRUE
  ),
  error = function(e) { cat("  timeROC error (Cox-S):", conditionMessage(e), "\n"); NULL }
)

troc_cox_d <- tryCatch(
  timeROC(
    T      = df_test$duration_years,
    delta  = as.integer(df_test$event_type),
    marker = lp_cox_d,
    cause  = 2,
    times  = time_points,
    iid    = TRUE
  ),
  error = function(e) { cat("  timeROC error (Cox-D):", conditionMessage(e), "\n"); NULL }
)

# Fine-Gray AUC (independently — NOT copied from Cox)
# Fine-Gray models the subdistribution hazard, which keeps competing-event
# subjects "at risk." Use the full event_type (0/1/2) with cause= argument
# so timeROC computes the competing-risks AUC (cumulative/dynamic).
troc_fg_s <- tryCatch(
  timeROC(
    T      = df_test$duration_years,
    delta  = as.integer(df_test$event_type),
    marker = lp_fg_s,
    cause  = 1,
    times  = time_points,
    iid    = TRUE
  ),
  error = function(e) { cat("  timeROC error (FG-S):", conditionMessage(e), "\n"); NULL }
)

troc_fg_d <- tryCatch(
  timeROC(
    T      = df_test$duration_years,
    delta  = as.integer(df_test$event_type),
    marker = lp_fg_d,
    cause  = 2,
    times  = time_points,
    iid    = TRUE
  ),
  error = function(e) { cat("  timeROC error (FG-D):", conditionMessage(e), "\n"); NULL }
)

# Strict AUC extraction: competing-risks delta (0/1/2) always populates $AUC_1.
# No fallback to $AUC — if $AUC_1 is missing, the delta encoding is wrong and
# we want a loud failure, not silent degradation.
get_auc <- function(troc) {
  stopifnot("AUC_1 not found — check that delta is multi-level (0/1/2)" =
              !is.null(troc$AUC_1))
  troc$AUC_1
}

cat("\n  --- Time-Dependent AUC Results ---\n")
if (!is.null(troc_cox_s)) {
  cat("  Cox AUC (Settlement) at 1/2/3/5 yr:       ",
      paste(round(get_auc(troc_cox_s), 3), collapse = " / "), "\n")
}
if (!is.null(troc_cox_d)) {
  cat("  Cox AUC (Dismissal)  at 1/2/3/5 yr:       ",
      paste(round(get_auc(troc_cox_d), 3), collapse = " / "), "\n")
}
if (!is.null(troc_fg_s)) {
  cat("  Fine-Gray AUC (Settlement) at 1/2/3/5 yr: ",
      paste(round(get_auc(troc_fg_s), 3), collapse = " / "), "\n")
}
if (!is.null(troc_fg_d)) {
  cat("  Fine-Gray AUC (Dismissal)  at 1/2/3/5 yr: ",
      paste(round(get_auc(troc_fg_d), 3), collapse = " / "), "\n")
}

# --- AUC 95% Confidence Intervals (requires iid=TRUE) ---
# confint.timeROC returns a list with $CI_AUC_1 and $CI_AUC_2, corresponding to
# AUC definitions 1 and 2 (NOT cause 1 and cause 2). Since get_auc() returns
# $AUC_1 (definition 1), we always use $CI_AUC_1 for matching CIs.
# Each CI matrix is [time_points x 2] with columns (lower, upper) on a 0-100 scale.
cat("\n  --- AUC 95% Confidence Intervals ---\n")
extract_auc_ci <- function(troc, label) {
  if (is.null(troc)) { cat(sprintf("  %s: timeROC object is NULL\n", label)); return(NULL) }
  ci <- tryCatch(confint(troc), error = function(e) {
    cat(sprintf("  %s: confint failed — %s\n", label, e$message)); NULL
  })
  if (is.null(ci)) return(NULL)

  auc_vals <- get_auc(troc)
  # Always use CI_AUC_1 to match AUC_1 (which get_auc() returns)
  ci_mat <- ci[["CI_AUC_1"]]
  if (is.null(ci_mat)) {
    cat(sprintf("  %s: CI_AUC_1 not found in confint output\n", label)); return(NULL)
  }
  # Convert from percentage (0-100) to proportion (0-1)
  ci_mat <- ci_mat / 100

  # Sanity check: point estimate should fall within CI
  for (i in seq_along(time_points)) {
    in_ci <- auc_vals[i] >= ci_mat[i, 1] & auc_vals[i] <= ci_mat[i, 2]
    low_flag <- if (ci_mat[i, 1] < 0.60) " *** LOW PREDICTIVE POWER ***" else ""
    san_flag <- if (!in_ci) " !!! SANITY FAIL: AUC outside CI !!!" else ""
    cat(sprintf("  %s @ %dyr: AUC=%.3f [%.3f, %.3f]%s%s\n",
                label, time_points[i], auc_vals[i],
                ci_mat[i, 1], ci_mat[i, 2], low_flag, san_flag))
  }
  invisible(ci_mat)
}

ci_cox_s <- extract_auc_ci(troc_cox_s, "Cox Settlement")
ci_cox_d <- extract_auc_ci(troc_cox_d, "Cox Dismissal")
ci_fg_s  <- extract_auc_ci(troc_fg_s,  "FG Settlement")
ci_fg_d  <- extract_auc_ci(troc_fg_d,  "FG Dismissal")


# =============================================================================
# SECTION 6: INTEGRATED BRIER SCORE
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("INTEGRATED BRIER SCORE\n")
cat("-----------------------------------------------------------------\n")

# NOTE: pec/IBS treats competing events as censored (binary Surv(time, ev)),
# making this a cause-specific approximation, not a true competing-risks metric.
# This is the standard approach and matches our cause-specific C-index treatment.
eval_times <- seq(0.25, 5, by = 0.25)

ibs_cox_s <- tryCatch({
  df_te_s <- df_test %>% mutate(ev = as.integer(event_type == 1))
  pf <- pec(
    object     = list("Cox" = cox_s_train),
    formula    = Surv(duration_years, ev) ~ 1,
    data       = df_te_s,
    times      = eval_times,
    exact      = FALSE,
    cens.model = "marginal"
  )
  # crps() returns a matrix: rows = models, cols = time windows
  # Each column is IBS[0; t_k) — a cumulative integral over [0, t_k).
  # Report the last column: IBS integrated over the full [0, 5yr] window.
  cr <- crps(pf, times = eval_times)
  ibs_val <- round(cr["Cox", ncol(cr)], 4)
  ibs_ref <- round(cr["Reference", ncol(cr)], 4)
  cat(sprintf("    Cox IBS[0,5yr): %.4f | Reference (KM): %.4f\n", ibs_val, ibs_ref))
  ibs_val
}, error = function(e) {
  cat("  pec error (Cox-S):", conditionMessage(e), "\n")
  NA_real_
})

ibs_cox_d <- tryCatch({
  df_te_d <- df_test %>% mutate(ev = as.integer(event_type == 2))
  pf <- pec(
    object     = list("Cox" = cox_d_train),
    formula    = Surv(duration_years, ev) ~ 1,
    data       = df_te_d,
    times      = eval_times,
    exact      = FALSE,
    cens.model = "marginal"
  )
  cr <- crps(pf, times = eval_times)
  ibs_val <- round(cr["Cox", ncol(cr)], 4)
  ibs_ref <- round(cr["Reference", ncol(cr)], 4)
  cat(sprintf("    Cox IBS[0,5yr): %.4f | Reference (KM): %.4f\n", ibs_val, ibs_ref))
  ibs_val
}, error = function(e) {
  cat("  pec error (Cox-D):", conditionMessage(e), "\n")
  NA_real_
})

cat(sprintf("  IBS Cox (Settlement): %s\n", ibs_cox_s))
cat(sprintf("  IBS Cox (Dismissal):  %s\n", ibs_cox_d))


# =============================================================================
# SECTION 7: PERFORMANCE COMPARISON TABLE
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("MODEL PERFORMANCE COMPARISON TABLE\n")
cat("-----------------------------------------------------------------\n")

perf_table <- tibble(
  Model = c(
    "Cox (Settlement)", "Cox (Dismissal)",
    "Fine-Gray (Settlement)", "Fine-Gray (Dismissal)"
  ),
  `C-index` = c(
    round(cind_cox_s$concordance, 3),
    round(cind_cox_d$concordance, 3),
    round(cind_fg_s$concordance, 3),
    round(cind_fg_d$concordance, 3)
  ),
  `C-index SE` = c(
    round(sqrt(cind_cox_s$var), 3),
    round(sqrt(cind_cox_d$var), 3),
    round(sqrt(cind_fg_s$var), 3),
    round(sqrt(cind_fg_d$var), 3)
  ),
  `AUC @ 1yr` = c(
    if (!is.null(troc_cox_s)) round(get_auc(troc_cox_s)[1], 3) else NA,
    if (!is.null(troc_cox_d)) round(get_auc(troc_cox_d)[1], 3) else NA,
    if (!is.null(troc_fg_s))  round(get_auc(troc_fg_s)[1], 3)  else NA,
    if (!is.null(troc_fg_d))  round(get_auc(troc_fg_d)[1], 3)  else NA
  ),
  `AUC @ 3yr` = c(
    if (!is.null(troc_cox_s)) round(get_auc(troc_cox_s)[3], 3) else NA,
    if (!is.null(troc_cox_d)) round(get_auc(troc_cox_d)[3], 3) else NA,
    if (!is.null(troc_fg_s))  round(get_auc(troc_fg_s)[3], 3)  else NA,
    if (!is.null(troc_fg_d))  round(get_auc(troc_fg_d)[3], 3)  else NA
  ),
  `AUC @ 5yr` = c(
    if (!is.null(troc_cox_s)) round(get_auc(troc_cox_s)[4], 3) else NA,
    if (!is.null(troc_cox_d)) round(get_auc(troc_cox_d)[4], 3) else NA,
    if (!is.null(troc_fg_s))  round(get_auc(troc_fg_s)[4], 3)  else NA,
    if (!is.null(troc_fg_d))  round(get_auc(troc_fg_d)[4], 3)  else NA
  ),
  IBS = c(
    ibs_cox_s, ibs_cox_d, NA, NA
  )
)

cat("\nTABLE: Model Performance Comparison (Held-Out Test Set)\n")
print(perf_table, n = 10)

# Save as LaTeX table
perf_tex <- kableExtra::kbl(
  perf_table,
  format   = "latex",
  booktabs = TRUE,
  caption  = "Model performance comparison on held-out test set (30\\%). C-index and time-dependent AUC computed independently for each model class.",
  label    = "model_performance"
) %>%
  kableExtra::kable_styling(latex_options = c("hold_position"))

save_table(perf_tex, "tab_model_performance",
           caption = "Model Performance Comparison",
           label   = "tab:model_performance")


# =============================================================================
# SECTION 8: AUC-OVER-TIME FIGURE (Cox vs. Fine-Gray, no RSF)
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("AUC-OVER-TIME FIGURE\n")
cat("-----------------------------------------------------------------\n")

auc_available <- !is.null(troc_cox_s) && !is.null(troc_cox_d) &&
                 !is.null(troc_fg_s)  && !is.null(troc_fg_d)

if (auc_available) {
  auc_plot_data <- tibble(
    Time    = rep(time_points, 4),
    AUC     = c(get_auc(troc_cox_s), get_auc(troc_cox_d),
                get_auc(troc_fg_s),  get_auc(troc_fg_d)),
    Model   = rep(c("Cox", "Cox", "Fine-Gray", "Fine-Gray"),
                  each = length(time_points)),
    Outcome = rep(c("Settlement", "Dismissal", "Settlement", "Dismissal"),
                  each = length(time_points))
  )

  fig_auc <- ggplot(auc_plot_data,
                    aes(x = Time, y = AUC, color = Outcome, linetype = Model)) +
    geom_line(linewidth = 1.1) +
    geom_point(size = 3) +
    geom_hline(yintercept = 0.5, linetype = "dotted", color = "gray60") +
    scale_color_manual(values = c("Settlement" = "#2166AC",
                                  "Dismissal"  = "#B2182B")) +
    scale_y_continuous(limits = c(0.4, 1.0),
                       labels = scales::percent_format(accuracy = 1)) +
    scale_x_continuous(breaks = time_points) +
    labs(
      title    = "Time-Dependent AUC: Cox vs. Fine-Gray",
      subtitle = "Discrimination at 1, 2, 3, and 5-year prediction horizons (held-out test set)",
      x        = "Prediction Horizon (Years)",
      y        = "Area Under the ROC Curve (AUC)",
      color    = "Outcome",
      linetype = "Model",
      caption  = "AUC > 0.5 = better than random. Dotted line = no-skill classifier."
    )

  save_figure(fig_auc, "fig_auc_over_time", width = 9, height = 6)
} else {
  cat("  Skipping AUC figure — one or more timeROC computations failed.\n")
}


# =============================================================================
# SECTION 9: SUMMARY
# =============================================================================
cat("\n=================================================================\n")
cat(" DIAGNOSTICS SUMMARY\n")
cat("=================================================================\n\n")

cat("PH Assumption Tests (Extended Models):\n")
cat(sprintf("  Settlement — GLOBAL: chi-sq = %.1f, p = %.4f %s\n",
            ph_test_s$table["GLOBAL", "chisq"],
            ph_test_s$table["GLOBAL", "p"],
            ifelse(ph_test_s$table["GLOBAL", "p"] < 0.05, "(VIOLATED)", "(OK)")))
cat(sprintf("  Dismissal  — GLOBAL: chi-sq = %.1f, p = %.4f %s\n",
            ph_test_d$table["GLOBAL", "chisq"],
            ph_test_d$table["GLOBAL", "p"],
            ifelse(ph_test_d$table["GLOBAL", "p"] < 0.05, "(VIOLATED)", "(OK)")))

cat("\nC-index (held-out test set):\n")
cat(sprintf("  Cox Settlement:       %.4f\n", cind_cox_s$concordance))
cat(sprintf("  Cox Dismissal:        %.4f\n", cind_cox_d$concordance))
cat(sprintf("  Fine-Gray Settlement: %.4f\n", cind_fg_s$concordance))
cat(sprintf("  Fine-Gray Dismissal:  %.4f\n", cind_fg_d$concordance))

if (auc_available) {
  cat("\nAUC @ 3 years:\n")
  cat(sprintf("  Cox Settlement:       %.3f\n", get_auc(troc_cox_s)[3]))
  cat(sprintf("  Cox Dismissal:        %.3f\n", get_auc(troc_cox_d)[3]))
  cat(sprintf("  Fine-Gray Settlement: %.3f\n", get_auc(troc_fg_s)[3]))
  cat(sprintf("  Fine-Gray Dismissal:  %.3f\n", get_auc(troc_fg_d)[3]))
}

cat("\nIntegrated Brier Score:\n")
cat(sprintf("  Cox Settlement: %s\n", ibs_cox_s))
cat(sprintf("  Cox Dismissal:  %s\n", ibs_cox_d))


# =============================================================================
# DONE
# =============================================================================
cat("\n=================================================================\n")
cat(" 07_diagnostics.R COMPLETE\n")
cat("=================================================================\n")

print_session()
