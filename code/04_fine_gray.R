# ============================================================
# Script: 04_fine_gray.R
# Purpose: Fine-Gray subdistribution hazard models (baseline + extended)
#          and cause-specific vs. subdistribution comparison table
# Input: data/cleaned/securities_cohort_cleaned.rds
# Output: Console output with Fine-Gray model summaries and comparison tables
#         output/models/fine_gray_models.rds (saved model objects for diagnostics)
# Dependencies: survival, tidyverse, here
# Seed: N/A (deterministic)
# ============================================================

get_script_path <- function() {
  cmd_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", cmd_args, value = TRUE)
  if (length(file_arg) > 0) {
    return(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = TRUE))
  }
  for (i in rev(seq_along(sys.frames()))) {
    if (!is.null(sys.frames()[[i]]$ofile)) {
      return(normalizePath(sys.frames()[[i]]$ofile, winslash = "/", mustWork = TRUE))
    }
  }
  stop("Unable to resolve script path for sourcing utils.R")
}

script_path <- get_script_path()
project_root <- dirname(dirname(script_path))
setwd(project_root)
source(file.path(project_root, "code", "utils.R"))
rm(get_script_path, project_root, script_path)

cat("=================================================================\n")
cat(" 04_fine_gray.R — FINE-GRAY SUBDISTRIBUTION MODELS\n")
cat("=================================================================\n\n")

# =============================================================================
# LOAD DATA
# =============================================================================
cat("Loading cleaned data...\n")
df <- readRDS(here::here("data", "cleaned", "securities_cohort_cleaned.rds"))
cat(sprintf("  Loaded: %s rows\n", format(nrow(df), big.mark = ",")))
stopifnot("event_type must be in {0, 1, 2}" = all(df$event_type %in% 0:2))
stopifnot("case_id column required for Fine-Gray clustering" = "case_id" %in% names(df))

# --- Derived datasets (same construction as 03_cox_models.R) ---
circuit_counts <- df %>% count(circuit, sort = TRUE)
circuits_incl  <- circuit_counts %>% filter(n >= 50) %>% pull(circuit)

df_circ <- df %>%
  filter(circuit %in% circuits_incl) %>%
  mutate(circuit_f = relevel(factor(circuit), ref = "2"))
cat(sprintf("  Circuit dataset: %s rows\n", format(nrow(df_circ), big.mark = ",")))

# Extended dataset
stat_coverage <- 100 * mean(!is.na(df$stat_basis_f))
include_stat  <- stat_coverage >= 15

df_ext <- df_circ %>%
  filter(!is.na(origin_cat), !is.na(mdl_flag), !is.na(juris_fq))

# Convert stat_basis_f NA to explicit factor level (matches 03_cox_models.R)
if (include_stat) {
  df_ext <- df_ext %>%
    mutate(stat_basis_f = forcats::fct_na_value_to_level(stat_basis_f, level = "Missing"))
}
cat(sprintf("  Extended model sample: %s rows\n", format(nrow(df_ext), big.mark = ",")))

base_formula_rhs <- "post_pslra + circuit_f + origin_cat + mdl_flag + juris_fq"
if (include_stat) {
  ext_formula_rhs <- paste(base_formula_rhs, "+ stat_basis_f")
} else {
  ext_formula_rhs <- base_formula_rhs
}


# =============================================================================
# SECTION 1: FINE-GRAY BASELINE (with circuit)
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("FINE-GRAY BASELINE (PSLRA + circuit)\n")
cat("-----------------------------------------------------------------\n")

# --- Settlement subdistribution ---
fg_base_s_data <- tryCatch(
  finegray(Surv(duration_years, factor(event_type, 0:2)) ~ .,
           data = df_circ %>% select(duration_years, event_type, post_pslra, circuit_f, case_id),
           etype = 1),
  error = function(e) { cat("  finegray error (base S):", e$message, "\n"); NULL }
)
fg_base_s <- if (!is.null(fg_base_s_data)) tryCatch(
  coxph(Surv(fgstart, fgstop, fgstatus) ~ post_pslra + circuit_f,
        data = fg_base_s_data, weights = fgwt, cluster = case_id,
        x = TRUE, y = TRUE, model = TRUE),
  error = function(e) { cat("  coxph error (base S):", e$message, "\n"); NULL }
)

# --- Dismissal subdistribution ---
fg_base_d_data <- tryCatch(
  finegray(Surv(duration_years, factor(event_type, 0:2)) ~ .,
           data = df_circ %>% select(duration_years, event_type, post_pslra, circuit_f, case_id),
           etype = 2),
  error = function(e) { cat("  finegray error (base D):", e$message, "\n"); NULL }
)
fg_base_d <- if (!is.null(fg_base_d_data)) tryCatch(
  coxph(Surv(fgstart, fgstop, fgstatus) ~ post_pslra + circuit_f,
        data = fg_base_d_data, weights = fgwt, cluster = case_id,
        x = TRUE, y = TRUE, model = TRUE),
  error = function(e) { cat("  coxph error (base D):", e$message, "\n"); NULL }
)

cat("\nFine-Gray Baseline — Settlement:\n")
print(round(summary(fg_base_s)$conf.int, 3))

cat("\nFine-Gray Baseline — Dismissal:\n")
print(round(summary(fg_base_d)$conf.int, 3))


# =============================================================================
# SECTION 2: COMPARISON TABLE — CAUSE-SPECIFIC vs. SUBDISTRIBUTION
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("CAUSE-SPECIFIC vs. SUBDISTRIBUTION COMPARISON\n")
cat("-----------------------------------------------------------------\n")

# Refit cause-specific Cox with same formula for apples-to-apples comparison
cox_s_circ <- coxph(
  Surv(duration_years, event_type == 1) ~ post_pslra + circuit_f,
  data = df_circ
)
cox_d_circ <- coxph(
  Surv(duration_years, event_type == 2) ~ post_pslra + circuit_f,
  data = df_circ
)

comparison_tbl_baseline <- tibble(
  Outcome = c("Settlement", "Settlement", "Dismissal", "Dismissal"),
  Model   = c("Cause-Specific Cox", "Fine-Gray Subdist.",
              "Cause-Specific Cox", "Fine-Gray Subdist."),
  Covariate = "post_pslra",
  HR      = round(c(
    exp(coef(cox_s_circ)["post_pslra"]),
    exp(coef(fg_base_s)["post_pslra"]),
    exp(coef(cox_d_circ)["post_pslra"]),
    exp(coef(fg_base_d)["post_pslra"])
  ), 3),
  CI_lower = round(c(
    exp(confint(cox_s_circ)["post_pslra", 1]),
    exp(confint(fg_base_s)["post_pslra", 1]),
    exp(confint(cox_d_circ)["post_pslra", 1]),
    exp(confint(fg_base_d)["post_pslra", 1])
  ), 3),
  CI_upper = round(c(
    exp(confint(cox_s_circ)["post_pslra", 2]),
    exp(confint(fg_base_s)["post_pslra", 2]),
    exp(confint(cox_d_circ)["post_pslra", 2]),
    exp(confint(fg_base_d)["post_pslra", 2])
  ), 3),
  # L5: Add p_value column for consistency with extended comparison table
  p_value = round(c(
    summary(cox_s_circ)$coefficients["post_pslra", "Pr(>|z|)"],
    summary(fg_base_s)$coefficients["post_pslra", "Pr(>|z|)"],
    summary(cox_d_circ)$coefficients["post_pslra", "Pr(>|z|)"],
    summary(fg_base_d)$coefficients["post_pslra", "Pr(>|z|)"]
  ), 4)
)

# Keep backward compatibility
comparison_tbl <- comparison_tbl_baseline

cat("\nCause-Specific vs. Subdistribution Hazard — PSLRA (Baseline Models):\n")
print(comparison_tbl_baseline)


# =============================================================================
# SECTION 3: EXTENDED FINE-GRAY WITH ALL COVARIATES
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("EXTENDED FINE-GRAY WITH ALL COVARIATES\n")
cat("-----------------------------------------------------------------\n")

# Select columns for finegray (it needs a clean dataset)
fg_cols <- c("duration_years", "event_type", "post_pslra", "circuit_f", "case_id",
             "origin_cat", "mdl_flag", "juris_fq")
if (include_stat) fg_cols <- c(fg_cols, "stat_basis_f")

# --- Extended Settlement ---
fg_ext_s_data <- tryCatch(
  finegray(Surv(duration_years, factor(event_type, 0:2)) ~ .,
           data = df_ext %>% select(all_of(fg_cols)), etype = 1),
  error = function(e) { cat("  finegray error (ext S):", e$message, "\n"); NULL }
)
fg_s_ext <- if (!is.null(fg_ext_s_data)) tryCatch(
  coxph(as.formula(paste("Surv(fgstart, fgstop, fgstatus) ~", ext_formula_rhs)),
        data = fg_ext_s_data, weights = fgwt, cluster = case_id,
        x = TRUE, y = TRUE, model = TRUE),
  error = function(e) { cat("  coxph error (ext S):", e$message, "\n"); NULL }
)

# --- Extended Dismissal ---
fg_ext_d_data <- tryCatch(
  finegray(Surv(duration_years, factor(event_type, 0:2)) ~ .,
           data = df_ext %>% select(all_of(fg_cols)), etype = 2),
  error = function(e) { cat("  finegray error (ext D):", e$message, "\n"); NULL }
)
fg_d_ext <- if (!is.null(fg_ext_d_data)) tryCatch(
  coxph(as.formula(paste("Surv(fgstart, fgstop, fgstatus) ~", ext_formula_rhs)),
        data = fg_ext_d_data, weights = fgwt, cluster = case_id,
        x = TRUE, y = TRUE, model = TRUE),
  error = function(e) { cat("  coxph error (ext D):", e$message, "\n"); NULL }
)

# L2: NULL-safety before printing — if a model failed, report and skip
cat("\nExtended Fine-Gray — Settlement:\n")
if (!is.null(fg_s_ext)) print(summary(fg_s_ext)) else cat("  MODEL FAILED — check error above\n")

cat("\nExtended Fine-Gray — Dismissal:\n")
if (!is.null(fg_d_ext)) print(summary(fg_d_ext)) else cat("  MODEL FAILED — check error above\n")

# --- Extended Comparison Table: CS Cox vs Fine-Gray (with CIs) ---
# Load saved Cox extended models for apples-to-apples comparison
# M3: Verify sample sizes match before comparing — if scripts ran on different data versions
# this comparison would silently be apples-to-oranges.
cox_results <- readRDS(here::here("output", "models", "cox_models.rds"))
cox_s_ext_loaded <- cox_results$cox_s_ext
cox_d_ext_loaded <- cox_results$cox_d_ext
stopifnot(
  "Cox and FG extended models must be fit on same N" =
    cox_results$df_ext_nrow == nrow(df_ext)
)

# Key covariates to compare (not cherry-picked — the ones discussed in the thesis)
key_covars <- c("post_pslra", grep("mdl", names(coef(cox_s_ext_loaded)), value = TRUE))

build_comparison_row <- function(model, covar, model_label, outcome) {
  # M5: NULL-safety — if model failed to fit, return NULL silently
  if (is.null(model)) return(NULL)
  coef_name <- covar
  if (!(coef_name %in% names(coef(model)))) return(NULL)
  tibble(
    Outcome   = outcome,
    Model     = model_label,
    Covariate = covar,
    HR        = round(exp(coef(model)[[coef_name]]), 3),
    CI_lower  = round(exp(confint(model)[coef_name, 1]), 3),
    CI_upper  = round(exp(confint(model)[coef_name, 2]), 3),
    p_value   = round(summary(model)$coefficients[coef_name, "Pr(>|z|)"], 4)
  )
}

comparison_tbl_extended <- bind_rows(
  lapply(key_covars, function(cv) {
    bind_rows(
      build_comparison_row(cox_s_ext_loaded, cv, "CS Cox", "Settlement"),
      build_comparison_row(fg_s_ext, cv, "Fine-Gray", "Settlement"),
      build_comparison_row(cox_d_ext_loaded, cv, "CS Cox", "Dismissal"),
      build_comparison_row(fg_d_ext, cv, "Fine-Gray", "Dismissal")
    )
  })
)

cat("\n-----------------------------------------------------------------\n")
cat("EXTENDED MODEL COMPARISON: CS Cox vs Fine-Gray (with 95% CIs)\n")
cat("-----------------------------------------------------------------\n")
print(as.data.frame(comparison_tbl_extended), row.names = FALSE)


# =============================================================================
# SECTION 4: PROPORTIONAL SUBDISTRIBUTION HAZARDS TEST
# =============================================================================
# cox.zph() is valid on finegray-weighted coxph objects (Austin & Fine, 2025).
# This parallels the PH diagnostics in 03_cox_models.R / 07_diagnostics.R.
cat("\n-----------------------------------------------------------------\n")
cat("PROPORTIONAL SUBDISTRIBUTION HAZARDS TEST\n")
cat("-----------------------------------------------------------------\n")

fg_ph_s <- tryCatch(cox.zph(fg_s_ext), error = function(e) {
  cat(sprintf("  PH test error (Settlement): %s\n", e$message)); NULL
})
fg_ph_d <- tryCatch(cox.zph(fg_d_ext), error = function(e) {
  cat(sprintf("  PH test error (Dismissal): %s\n", e$message)); NULL
})

if (!is.null(fg_ph_s)) {
  cat("\n  Fine-Gray PH Test — Settlement (extended):\n")
  cat(sprintf("    Global test: chi-sq=%.1f, df=%d, p=%.2e\n",
              fg_ph_s$table["GLOBAL", "chisq"],
              fg_ph_s$table["GLOBAL", "df"],
              fg_ph_s$table["GLOBAL", "p"]))
  cat(sprintf("    post_pslra: chi-sq=%.1f, p=%.2e\n",
              fg_ph_s$table["post_pslra", "chisq"],
              fg_ph_s$table["post_pslra", "p"]))
}
if (!is.null(fg_ph_d)) {
  cat("\n  Fine-Gray PH Test — Dismissal (extended):\n")
  cat(sprintf("    Global test: chi-sq=%.1f, df=%d, p=%.2e\n",
              fg_ph_d$table["GLOBAL", "chisq"],
              fg_ph_d$table["GLOBAL", "df"],
              fg_ph_d$table["GLOBAL", "p"]))
  cat(sprintf("    post_pslra: chi-sq=%.1f, p=%.2e\n",
              fg_ph_d$table["post_pslra", "chisq"],
              fg_ph_d$table["post_pslra", "p"]))
}


# =============================================================================
# SAVE MODEL OBJECTS (for 07_diagnostics.R)
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("SAVING MODEL OBJECTS\n")
cat("-----------------------------------------------------------------\n")

models_dir <- here::here("output", "models")
if (!dir.exists(models_dir)) dir.create(models_dir, recursive = TRUE)

fg_results <- list(
  # Baseline
  fg_base_s     = fg_base_s,
  fg_base_d     = fg_base_d,
  # Extended
  fg_s_ext      = fg_s_ext,
  fg_d_ext      = fg_d_ext,
  # PH tests
  fg_ph_s       = fg_ph_s,
  fg_ph_d       = fg_ph_d,
  # Comparison tables
  comparison_tbl          = comparison_tbl,           # baseline PSLRA only (backward compat)
  comparison_tbl_extended = comparison_tbl_extended,   # extended with CIs for all key covariates
  # Metadata
  ext_formula_rhs = ext_formula_rhs,
  include_stat    = include_stat
)

saveRDS(fg_results, here::here("output", "models", "fine_gray_models.rds"))
cat("  Saved: output/models/fine_gray_models.rds\n")


# =============================================================================
# DONE
# =============================================================================
cat("\n=================================================================\n")
cat(" 04_fine_gray.R COMPLETE\n")
cat("=================================================================\n")

print_session()
