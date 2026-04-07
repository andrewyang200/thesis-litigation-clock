# ============================================================
# Script: 05_causal_iptw.R
# Purpose: TRIANGULATION of the PSLRA effect via four estimation
#          strategies. Tests whether the association is robust to
#          functional form (regression vs. weighting) and whether
#          observable case composition explains the raw effect.
#          ATT weights with 99th percentile trimming.
#          NOT causal — adjusts for observable compositional shifts.
#
# CRITICAL FRAMING NOTE (post-treatment bias):
#   Covariates like circuit filing choice and MDL status may be
#   consequences of PSLRA, not pre-treatment confounders. If PSLRA
#   changed WHERE cases were filed (e.g., more SDNY filings) or HOW
#   they were consolidated (MDL growth), then adjusting for these
#   removes part of the PSLRA effect pathway. The "composition-adjusted"
#   estimate is therefore best interpreted as a DECOMPOSITION — isolating
#   the direct PSLRA association net of compositional shifts — and may
#   represent a LOWER BOUND on the total PSLRA effect. The unadjusted
#   HR (Row 1) captures both direct and composition-mediated channels.
# Input: data/cleaned/securities_cohort_cleaned.rds
# Output: output/figures/fig_iptw_balance.{pdf,png}
#         output/figures/fig_cif_weighted_settlement.{pdf,png}
#         output/figures/fig_cif_weighted_dismissal.{pdf,png}
#         output/models/iptw_results.rds
# Dependencies: survival, tidyverse, here, WeightIt, cobalt
# Seed: N/A (deterministic — logistic regression, no bootstrapping)
#
# FOUR ESTIMATION STRATEGIES (the "triangulation"):
#   1. Unadjusted:           Cox with post_pslra only (no covariates)
#   2. Regression-Adjusted:  Cox with post_pslra + full covariate set
#   3. Weighted + Covariates: IPTW-weighted Cox with full covariate set
#   4. Marginal Structural:  IPTW-weighted Cox with post_pslra only
#
# The informative comparisons are:
#   Row 1 → Row 2: How much does regression adjustment change the HR?
#                   (answers: "does observable composition matter?")
#   Row 2 → Row 3: Does weighting + regression differ from regression alone?
#                   (answers: "is the functional form assumption driving results?")
#   Row 1 → Row 4: MSM vs. unadjusted — the full composition adjustment
#                   via weighting alone, no regression covariates.
#   Row 2 ≈ Row 3 ≈ Row 4: Convergence across methods = robust finding.
#
# NOTE ON PH VIOLATIONS:
#   IPTW weighting can amplify PH violations. The single-HR summaries
#   reported here are time-averaged effects, not constant hazard ratios.
#   The unweighted piecewise decomposition (03_cox_models.R) remains the
#   preferred specification for characterizing the time-varying PSLRA effect.
#   The weighted HR is best interpreted as: "on average over follow-up,
#   after composition adjustment, PSLRA is associated with X."
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
cat(" 05_causal_iptw.R — IPTW TRIANGULATION ANALYSIS\n")
cat("=================================================================\n\n")
cat("PURPOSE: Triangulate the PSLRA effect across four estimation\n")
cat("strategies to test robustness to functional form and composition.\n\n")
cat("NOTE: All IPTW estimates are 'composition-adjusted,' not 'causal.'\n")
cat("IPTW reweights pre-PSLRA cases to match post-PSLRA on observables.\n")
cat("Unmeasured confounders (economic cycles, judicial attitudes,\n")
cat("plaintiff bar sophistication) are NOT controlled.\n\n")

# =============================================================================
# LOAD & PREPARE DATA (mirrors 03_cox_models.R pipeline exactly)
# =============================================================================
cat("Loading cleaned data...\n")
df <- readRDS(here::here("data", "cleaned", "securities_cohort_cleaned.rds"))
cat(sprintf("  Full sample: %s rows\n", format(nrow(df), big.mark = ",")))

# Circuits with >= 50 cases
circuit_counts <- df %>% count(circuit, sort = TRUE)
circuits_incl  <- circuit_counts %>% filter(n >= 50) %>% pull(circuit)

df_circ <- df %>%
  filter(circuit %in% circuits_incl) %>%
  mutate(circuit_f = relevel(factor(circuit), ref = "2"))

# Extended dataset: complete cases on core covariates
stat_coverage <- 100 * mean(!is.na(df$stat_basis_f))
include_stat  <- stat_coverage >= 15

df_ext <- df_circ %>%
  filter(!is.na(origin_cat), !is.na(mdl_flag), !is.na(juris_fq))

if (include_stat) {
  df_ext <- df_ext %>%
    mutate(stat_basis_f = forcats::fct_na_value_to_level(stat_basis_f, level = "Missing"))
}

cat(sprintf("  Analysis sample: %s rows (%d pre / %d post PSLRA)\n",
            format(nrow(df_ext), big.mark = ","),
            sum(df_ext$post_pslra == 0), sum(df_ext$post_pslra == 1)))

# =============================================================================
# SECTION 1: PROPENSITY SCORE MODEL
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("PROPENSITY SCORE MODEL: P(post_pslra = 1 | X)\n")
cat("-----------------------------------------------------------------\n")

# Same covariates as the Cox extended model, minus post_pslra itself.
# These are case characteristics that may differ systematically across eras.
# NOTE: mdl_flag is excluded because zero pre-PSLRA cases have mdl_flag == 1,
# producing perfect separation (coef → ±∞). The IDB did not code MDL
# consolidation in the pre-PSLRA era, so this is a data limitation, not a
# modeling choice. MDL composition cannot be adjusted for.
if (include_stat) {
  ps_formula <- post_pslra ~ circuit_f + origin_cat + juris_fq + stat_basis_f
} else {
  ps_formula <- post_pslra ~ circuit_f + origin_cat + juris_fq
}

ps_model <- glm(ps_formula, data = df_ext, family = binomial(link = "logit"))
df_ext$ps <- predict(ps_model, type = "response")

cat(sprintf("  PS range: [%.4f, %.4f]\n", min(df_ext$ps), max(df_ext$ps)))
cat(sprintf("  PS mean — Pre: %.4f | Post: %.4f\n",
            mean(df_ext$ps[df_ext$post_pslra == 0]),
            mean(df_ext$ps[df_ext$post_pslra == 1])))

# =============================================================================
# SECTION 2: ATT WEIGHTS WITH 99TH PERCENTILE TRIMMING
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("ATT WEIGHTS (99th percentile trimmed)\n")
cat("-----------------------------------------------------------------\n")

# ATT: treated (post-PSLRA) get weight 1, controls get ps/(1-ps).
# This reweights pre-PSLRA to match post-PSLRA on observables.
df_ext <- df_ext %>%
  mutate(att_weight_raw = ifelse(post_pslra == 1, 1, ps / (1 - ps)))

# 99th percentile trimming on control weights only
w_pre_raw <- df_ext$att_weight_raw[df_ext$post_pslra == 0]
trim_cap  <- quantile(w_pre_raw, 0.99)

df_ext <- df_ext %>%
  mutate(att_weight = ifelse(post_pslra == 1, 1, pmin(att_weight_raw, trim_cap)))

w_pre <- df_ext$att_weight[df_ext$post_pslra == 0]

cat(sprintf("  Trim cap (99th pctl): %.2f\n", trim_cap))
cat(sprintf("  Weights trimmed: %d of %d control cases (%.1f%%)\n",
            sum(w_pre_raw > trim_cap), length(w_pre_raw),
            100 * mean(w_pre_raw > trim_cap)))

# Effective sample size
ess_pre  <- sum(w_pre)^2 / sum(w_pre^2)
ess_post <- sum(df_ext$post_pslra == 1)

cat(sprintf("  ESS — Pre-PSLRA: %.1f of %d (%.1f%% efficiency)\n",
            ess_pre, length(w_pre), 100 * ess_pre / length(w_pre)))
cat(sprintf("  ESS — Post-PSLRA: %d (all weight = 1)\n", ess_post))
cat(sprintf("  ESS — Total: %.1f\n", ess_pre + ess_post))

# =============================================================================
# SECTION 3: LOVE PLOT — BALANCE BEFORE vs AFTER WEIGHTING
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("COVARIATE BALANCE: Love Plot\n")
cat("-----------------------------------------------------------------\n")

# Use WeightIt for proper balance computation
# Pass trimming through WeightIt's interface
w_out <- weightit(
  ps_formula,
  data = df_ext,
  method = "glm",
  estimand = "ATT"
)
# Apply our 99th-percentile trimming to the WeightIt object
w_out$weights[df_ext$post_pslra == 0] <- pmin(
  w_out$weights[df_ext$post_pslra == 0],
  trim_cap
)
if (!isTRUE(all.equal(unname(df_ext$att_weight), unname(w_out$weights), tolerance = 1e-10))) {
  stop("Manual ATT weights do not match trimmed WeightIt weights.")
}
cat("  Verified: manual ATT weights match trimmed WeightIt weights.\n")

# Balance table
bt <- bal.tab(w_out, stats = c("m", "v"), thresholds = c(m = 0.1), un = TRUE)
cat("\nBalance table (unadjusted vs. adjusted SMD):\n")
print(bt)

# Love plot
p_love <- love.plot(
  w_out,
  stats = "mean.diffs",
  threshold = 0.1,
  abs = TRUE,
  var.order = "unadjusted",
  colors = c("#B2182B", "#2166AC"),
  shapes = c(17, 16),
  sample.names = c("Unadjusted", "IPTW-Adjusted"),
  title = "Covariate Balance: IPTW Weighting",
  position = "bottom"
) +
  theme_thesis +
  theme(legend.position = "bottom")

save_figure(p_love, "fig_iptw_balance", width = 8, height = 6)

# Check: any post-weighting SMD >= 0.1?
# Note: bt$Balance$Diff.Adj is unnamed; use rownames from the data frame.
# Exclude the propensity score distance row — SMD thresholds apply to
# individual covariates, not the summary PS distance.
adj_smd <- bt$Balance$Diff.Adj
names(adj_smd) <- rownames(bt$Balance)
covariate_smd <- adj_smd[names(adj_smd) != "prop.score"]
bad_balance <- names(covariate_smd[abs(covariate_smd) >= 0.1])

if (length(bad_balance) > 0) {
  cat(sprintf("\n  *** WARNING: %d covariates with |SMD| >= 0.1 after weighting: %s ***\n",
              length(bad_balance), paste(bad_balance, collapse = ", ")))
} else {
  cat(sprintf("\n  All %d covariates balanced (|SMD| < 0.1 after weighting).\n",
              length(covariate_smd)))
}
# Also report propensity score distance for transparency
ps_smd <- adj_smd["prop.score"]
cat(sprintf("  Propensity score distance SMD: %.4f %s\n",
            ps_smd, ifelse(abs(ps_smd) >= 0.1, "(NOTE: > 0.1)", "(< 0.1)")))

# =============================================================================
# SECTION 4a: TRULY UNADJUSTED COX (PSLRA only, no covariates)
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("ROW 1 — UNADJUSTED: Cox with post_pslra only\n")
cat("-----------------------------------------------------------------\n")

# No covariates — raw PSLRA association on the df_ext sample
cox_s_raw <- coxph(Surv(duration_years, event_type == 1) ~ post_pslra, data = df_ext)
cox_d_raw <- coxph(Surv(duration_years, event_type == 2) ~ post_pslra, data = df_ext)

s_raw_sum <- summary(cox_s_raw)
d_raw_sum <- summary(cox_d_raw)

cat(sprintf("\n  Settlement: HR = %.3f, 95%% CI: %.3f--%.3f, p = %.2e\n",
            exp(coef(cox_s_raw)["post_pslra"]),
            exp(confint(cox_s_raw)["post_pslra", 1]),
            exp(confint(cox_s_raw)["post_pslra", 2]),
            s_raw_sum$coefficients["post_pslra", "Pr(>|z|)"]))
cat(sprintf("  Dismissal:  HR = %.3f, 95%% CI: %.3f--%.3f, p = %.2e\n",
            exp(coef(cox_d_raw)["post_pslra"]),
            exp(confint(cox_d_raw)["post_pslra", 1]),
            exp(confint(cox_d_raw)["post_pslra", 2]),
            d_raw_sum$coefficients["post_pslra", "Pr(>|z|)"]))

# =============================================================================
# SECTION 4b: REGRESSION-ADJUSTED COX (extended covariate set, unweighted)
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("ROW 2 — REGRESSION-ADJUSTED: Cox with full covariate set\n")
cat("-----------------------------------------------------------------\n")

if (include_stat) {
  ext_rhs <- "post_pslra + circuit_f + origin_cat + mdl_flag + juris_fq + stat_basis_f"
} else {
  ext_rhs <- "post_pslra + circuit_f + origin_cat + mdl_flag + juris_fq"
}

cox_s_reg <- coxph(
  as.formula(paste("Surv(duration_years, event_type == 1) ~", ext_rhs)),
  data = df_ext
)
cox_d_reg <- coxph(
  as.formula(paste("Surv(duration_years, event_type == 2) ~", ext_rhs)),
  data = df_ext
)

s_reg_sum <- summary(cox_s_reg)
d_reg_sum <- summary(cox_d_reg)

cat(sprintf("\n  Settlement: HR = %.3f, 95%% CI: %.3f--%.3f, p = %.2e\n",
            exp(coef(cox_s_reg)["post_pslra"]),
            exp(confint(cox_s_reg)["post_pslra", 1]),
            exp(confint(cox_s_reg)["post_pslra", 2]),
            s_reg_sum$coefficients["post_pslra", "Pr(>|z|)"]))
cat(sprintf("  Dismissal:  HR = %.3f, 95%% CI: %.3f--%.3f, p = %.2e\n",
            exp(coef(cox_d_reg)["post_pslra"]),
            exp(confint(cox_d_reg)["post_pslra", 1]),
            exp(confint(cox_d_reg)["post_pslra", 2]),
            d_reg_sum$coefficients["post_pslra", "Pr(>|z|)"]))

# =============================================================================
# SECTION 5a: WEIGHTED + COVARIATES — IPTW-weighted Cox with full covariates
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("ROW 3 — WEIGHTED + COVARIATES (Regression-Adjusted IPTW)\n")
cat("-----------------------------------------------------------------\n")
cat("(IPTW-weighted Cox with the full covariate set in the outcome model;\n")
cat(" this is regression-adjusted IPTW, not a doubly robust estimator.)\n")

# Weighted Cox with robust (sandwich) SEs.
# coxph automatically uses Lin-Wei robust variance when weights are provided.
cox_s_ra_iptw <- coxph(
  as.formula(paste("Surv(duration_years, event_type == 1) ~", ext_rhs)),
  data = df_ext,
  weights = att_weight,
  robust = TRUE
)

cox_d_ra_iptw <- coxph(
  as.formula(paste("Surv(duration_years, event_type == 2) ~", ext_rhs)),
  data = df_ext,
  weights = att_weight,
  robust = TRUE
)

s_ra_iptw_sum <- summary(cox_s_ra_iptw)
d_ra_iptw_sum <- summary(cox_d_ra_iptw)

cat(sprintf("\n  Settlement: HR = %.3f, 95%% CI: %.3f--%.3f, p = %.2e\n",
            exp(coef(cox_s_ra_iptw)["post_pslra"]),
            exp(confint(cox_s_ra_iptw)["post_pslra", 1]),
            exp(confint(cox_s_ra_iptw)["post_pslra", 2]),
            s_ra_iptw_sum$coefficients["post_pslra", "Pr(>|z|)"]))
cat(sprintf("  Dismissal:  HR = %.3f, 95%% CI: %.3f--%.3f, p = %.2e\n",
            exp(coef(cox_d_ra_iptw)["post_pslra"]),
            exp(confint(cox_d_ra_iptw)["post_pslra", 1]),
            exp(confint(cox_d_ra_iptw)["post_pslra", 2]),
            d_ra_iptw_sum$coefficients["post_pslra", "Pr(>|z|)"]))

# Full model summaries for the weighted + covariates models (for reference)
cat("\n--- Weighted + Covariates Settlement (full model output) ---\n")
print(s_ra_iptw_sum)
cat("\n--- Weighted + Covariates Dismissal (full model output) ---\n")
print(d_ra_iptw_sum)

# =============================================================================
# SECTION 5b: MARGINAL STRUCTURAL MODEL — IPTW-weighted Cox, PSLRA only
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("ROW 4 — MARGINAL STRUCTURAL: IPTW-weighted Cox, post_pslra only\n")
cat("-----------------------------------------------------------------\n")
cat("(The standard MSM specification: covariates are in the weights,\n")
cat(" not the outcome model. Isolates the composition-adjusted effect.)\n")

cox_s_msm <- coxph(
  Surv(duration_years, event_type == 1) ~ post_pslra,
  data = df_ext,
  weights = att_weight,
  robust = TRUE
)

cox_d_msm <- coxph(
  Surv(duration_years, event_type == 2) ~ post_pslra,
  data = df_ext,
  weights = att_weight,
  robust = TRUE
)

s_msm_sum <- summary(cox_s_msm)
d_msm_sum <- summary(cox_d_msm)

cat(sprintf("\n  Settlement: HR = %.3f, 95%% CI: %.3f--%.3f, p = %.2e\n",
            exp(coef(cox_s_msm)["post_pslra"]),
            exp(confint(cox_s_msm)["post_pslra", 1]),
            exp(confint(cox_s_msm)["post_pslra", 2]),
            s_msm_sum$coefficients["post_pslra", "Pr(>|z|)"]))
cat(sprintf("  Dismissal:  HR = %.3f, 95%% CI: %.3f--%.3f, p = %.2e\n",
            exp(coef(cox_d_msm)["post_pslra"]),
            exp(confint(cox_d_msm)["post_pslra", 1]),
            exp(confint(cox_d_msm)["post_pslra", 2]),
            d_msm_sum$coefficients["post_pslra", "Pr(>|z|)"]))

# =============================================================================
# PH TESTS ON WEIGHTED MODELS
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("PH TESTS (weighted models)\n")
cat("-----------------------------------------------------------------\n")
# NOTE: IPTW weighting can amplify PH violations. If the weighted PH
# test rejects, the single-HR summary is a time-averaged effect, not a
# constant hazard ratio. The unweighted piecewise decomposition in
# 03_cox_models.R remains the preferred specification for characterizing
# the time-varying PSLRA effect.
cat("Weighted + Covariates Settlement:\n")
tryCatch(print(cox.zph(cox_s_ra_iptw)), error = function(e) cat("  PH test failed:", e$message, "\n"))
cat("\nWeighted + Covariates Dismissal:\n")
tryCatch(print(cox.zph(cox_d_ra_iptw)), error = function(e) cat("  PH test failed:", e$message, "\n"))
cat("\nMSM Settlement:\n")
tryCatch(print(cox.zph(cox_s_msm)), error = function(e) cat("  PH test failed:", e$message, "\n"))
cat("\nMSM Dismissal:\n")
tryCatch(print(cox.zph(cox_d_msm)), error = function(e) cat("  PH test failed:", e$message, "\n"))

# =============================================================================
# SECTION 6: FOUR-ROW TRIANGULATION TABLE
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("TRIANGULATION TABLE: PSLRA Hazard Ratios Across Four Strategies\n")
cat("-----------------------------------------------------------------\n")

# Helper to extract HR, CI, p for the PSLRA coefficient
extract_pslra <- function(model) {
  s <- summary(model)
  hr <- exp(coef(model)["post_pslra"])
  ci <- exp(confint(model)["post_pslra", ])
  p_col <- grep("^Pr\\(", colnames(s$coefficients), value = TRUE)[1]
  p  <- s$coefficients["post_pslra", p_col]
  list(hr = hr, ci_lo = ci[1], ci_hi = ci[2], p = p)
}

# Extract all 8 models
s_raw_e <- extract_pslra(cox_s_raw);  d_raw_e <- extract_pslra(cox_d_raw)
s_reg_e <- extract_pslra(cox_s_reg);  d_reg_e <- extract_pslra(cox_d_reg)
s_ra_iptw_e  <- extract_pslra(cox_s_ra_iptw);   d_ra_iptw_e  <- extract_pslra(cox_d_ra_iptw)
s_msm_e <- extract_pslra(cox_s_msm);  d_msm_e <- extract_pslra(cox_d_msm)

# Build one table per outcome
build_triangulation <- function(raw, reg, ra_iptw, msm, outcome) {
  tibble(
    Outcome  = outcome,
    Strategy = c("1. Unadjusted", "2. Regression-Adjusted",
                 "3. Weighted + Covariates (Regression-Adjusted IPTW)",
                 "4. Marginal Structural (IPTW only)"),
    Covariates = c("none", "regression", "regression + weights", "weights only"),
    HR       = c(raw$hr, reg$hr, ra_iptw$hr, msm$hr),
    `95% CI` = sprintf("%.3f--%.3f",
                        c(raw$ci_lo, reg$ci_lo, ra_iptw$ci_lo, msm$ci_lo),
                        c(raw$ci_hi, reg$ci_hi, ra_iptw$ci_hi, msm$ci_hi)),
    p        = c(raw$p, reg$p, ra_iptw$p, msm$p),
    `vs Row 1` = sprintf("%+.1f%%", 100 * (c(raw$hr, reg$hr, ra_iptw$hr, msm$hr) - raw$hr) / raw$hr)
  )
}

tri_settlement <- build_triangulation(s_raw_e, s_reg_e, s_ra_iptw_e, s_msm_e, "Settlement")
tri_dismissal  <- build_triangulation(d_raw_e, d_reg_e, d_ra_iptw_e, d_msm_e, "Dismissal")

comparison_table <- bind_rows(tri_settlement, tri_dismissal)

cat("\n=== SETTLEMENT ===\n")
print(as.data.frame(tri_settlement), row.names = FALSE)
cat("\n=== DISMISSAL ===\n")
print(as.data.frame(tri_dismissal), row.names = FALSE)

# Dynamic triangulation interpretation
s_shift_1_to_2 <- 100 * (s_reg_e$hr - s_raw_e$hr) / s_raw_e$hr
d_shift_1_to_2 <- 100 * (d_reg_e$hr - d_raw_e$hr) / d_raw_e$hr
s_shift_1_to_4 <- 100 * (s_msm_e$hr - s_raw_e$hr) / s_raw_e$hr
d_shift_1_to_4 <- 100 * (d_msm_e$hr - d_raw_e$hr) / d_raw_e$hr

cat("\n--- Triangulation Interpretation (computed from actual HRs) ---\n")
cat(sprintf("  Row 1 → Row 2: Regression adjustment shifts settlement HR %+.1f%% and dismissal HR %+.1f%%.\n",
            s_shift_1_to_2, d_shift_1_to_2))
cat(sprintf("  Row 1 → Row 4: MSM (weighting only) shifts settlement HR %+.1f%% and dismissal HR %+.1f%%.\n",
            s_shift_1_to_4, d_shift_1_to_4))
cat(sprintf("  Row 2 vs Row 3 vs Row 4 convergence: Settlement HRs = %.3f / %.3f / %.3f\n",
            s_reg_e$hr, s_ra_iptw_e$hr, s_msm_e$hr))
cat(sprintf("                                        Dismissal HRs  = %.3f / %.3f / %.3f\n",
            d_reg_e$hr, d_ra_iptw_e$hr, d_msm_e$hr))

# =============================================================================
# SECTION 7: WEIGHTED CIF PLOTS
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("WEIGHTED CUMULATIVE INCIDENCE FUNCTIONS\n")
cat("-----------------------------------------------------------------\n")

# For weighted CIF, we use the cmprsk::cuminc approach cannot handle weights
# directly. Instead, we use a manual weighted Aalen-Johansen estimator via
# the survfit approach from the survival package with weights.

# Settlement CIF (weighted)
cat("Computing weighted CIF for settlement...\n")
cif_s_pre <- survfit(
  Surv(duration_years, factor(event_type, levels = 0:2)) ~ 1,
  data = df_ext %>% filter(post_pslra == 0),
  weights = att_weight
)

cif_s_post <- survfit(
  Surv(duration_years, factor(event_type, levels = 0:2)) ~ 1,
  data = df_ext %>% filter(post_pslra == 1),
  weights = att_weight
)

# Extract CIF data from multi-state survfit objects
# survfit with multi-state returns cumulative incidence for each state
extract_cif <- function(sf, group_label) {
  # Multi-state survfit stores CIF in $pstate columns
  # Column 1 = P(in state 0) = "event-free", columns 2+ = CIF for each event
  n_states <- ncol(sf$pstate)

  tibble(
    time = sf$time,
    cif_settlement = sf$pstate[, 2],  # Event type 1 (settlement)
    cif_dismissal  = sf$pstate[, 3],  # Event type 2 (dismissal)
    group = group_label
  )
}

cif_pre_data  <- extract_cif(cif_s_pre,  "Pre-PSLRA (weighted)")
cif_post_data <- extract_cif(cif_s_post, "Post-PSLRA")

cif_data <- bind_rows(cif_pre_data, cif_post_data)

# --- Settlement CIF plot ---
p_cif_s <- ggplot(cif_data, aes(x = time, y = cif_settlement, color = group, linetype = group)) +
  geom_step(linewidth = 0.9) +
  scale_color_manual(values = c("Pre-PSLRA (weighted)" = "#4DAF4A", "Post-PSLRA" = "#984EA3")) +
  scale_linetype_manual(values = c("Pre-PSLRA (weighted)" = "dashed", "Post-PSLRA" = "solid")) +
  coord_cartesian(xlim = c(0, 15)) +
  labs(
    title = "Composition-Adjusted CIF: Settlement",
    x     = "Years from Filing",
    y     = "Cumulative Incidence of Settlement",
    color = NULL, linetype = NULL
  ) +
  theme(legend.position = "bottom")

save_figure(p_cif_s, "fig_cif_weighted_settlement", width = 8, height = 6)

# --- Dismissal CIF plot ---
p_cif_d <- ggplot(cif_data, aes(x = time, y = cif_dismissal, color = group, linetype = group)) +
  geom_step(linewidth = 0.9) +
  scale_color_manual(values = c("Pre-PSLRA (weighted)" = "#4DAF4A", "Post-PSLRA" = "#984EA3")) +
  scale_linetype_manual(values = c("Pre-PSLRA (weighted)" = "dashed", "Post-PSLRA" = "solid")) +
  coord_cartesian(xlim = c(0, 15)) +
  labs(
    title = "Composition-Adjusted CIF: Dismissal",
    x     = "Years from Filing",
    y     = "Cumulative Incidence of Dismissal",
    color = NULL, linetype = NULL
  ) +
  theme(legend.position = "bottom")

save_figure(p_cif_d, "fig_cif_weighted_dismissal", width = 8, height = 6)

# =============================================================================
# SECTION 8: SAVE RESULTS
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("SAVING RESULTS\n")
cat("-----------------------------------------------------------------\n")

iptw_results <- list(
  # Propensity score model
  ps_model = ps_model,
  ps_formula = ps_formula,
  trim_cap = trim_cap,

  # Effective sample size
  ess_pre = ess_pre,
  ess_post = ess_post,

  # Row 1: Unadjusted (PSLRA only)
  cox_s_raw = cox_s_raw,
  cox_d_raw = cox_d_raw,

  # Row 2: Regression-adjusted (extended covariates, unweighted)
  cox_s_reg = cox_s_reg,
  cox_d_reg = cox_d_reg,

  # Row 3: Weighted + Covariates (regression-adjusted IPTW)
  cox_s_ra_iptw = cox_s_ra_iptw,
  cox_d_ra_iptw = cox_d_ra_iptw,

  # Row 4: Marginal structural model (IPTW-weighted, PSLRA only)
  cox_s_msm = cox_s_msm,
  cox_d_msm = cox_d_msm,

  # Triangulation table
  comparison_table = comparison_table,

  # WeightIt object (for downstream balance diagnostics)
  weightit_obj = w_out,

  # Metadata
  metadata = list(
    n_total = nrow(df_ext),
    n_pre = sum(df_ext$post_pslra == 0),
    n_post = sum(df_ext$post_pslra == 1),
    estimand = "ATT",
    trimming = "99th percentile",
    trim_cap_value = trim_cap,
    language = "composition-adjusted (NOT causal)",
    design = "4-strategy triangulation",
    date = Sys.time()
  )
)

saveRDS(iptw_results, here::here("output", "models", "iptw_results.rds"))
cat("  Saved: output/models/iptw_results.rds\n")

# =============================================================================
# SECTION 9: FINAL SUMMARY — TRIANGULATION
# =============================================================================
cat("\n=================================================================\n")
cat(" IPTW TRIANGULATION SUMMARY\n")
cat("=================================================================\n")

# All summary values computed dynamically from model objects
pseudo_r2 <- 1 - ps_model$deviance / ps_model$null.deviance
all_p <- c(s_raw_e$p, s_reg_e$p, s_ra_iptw_e$p, s_msm_e$p,
           d_raw_e$p, d_reg_e$p, d_ra_iptw_e$p, d_msm_e$p)
max_p <- max(all_p)

# Balance summary
if (length(bad_balance) == 0) {
  balance_msg <- sprintf("All %d covariates |SMD| < 0.1 after weighting", length(covariate_smd))
} else {
  balance_msg <- sprintf("%d of %d covariates FAILED |SMD| < 0.1 threshold: %s",
                         length(bad_balance), length(covariate_smd),
                         paste(bad_balance, collapse = ", "))
}

# PH test results (dynamic)
ph_d_msm <- tryCatch(cox.zph(cox_d_msm), error = function(e) NULL)
ph_d_msg <- if (!is.null(ph_d_msm)) {
  p_ph <- ph_d_msm$table["post_pslra", "p"]
  if (p_ph < 0.001) sprintf("p = %.2e", p_ph) else sprintf("p = %.3f", p_ph)
} else { "test failed" }

cat(sprintf("
Sample: %s cases (%d pre / %d post PSLRA, ratio %.1f:1)
Weights: ATT with 99th percentile trim (cap = %.2f)
ESS: %.1f pre-PSLRA (%.1f%% efficiency), %d post-PSLRA
Balance: %s (PS distance: %.3f)

SETTLEMENT — PSLRA Hazard Ratios
  1. Unadjusted:           HR = %.3f  (%s)
  2. Regression-Adjusted:  HR = %.3f  (%s)  [%s vs Row 1]
  3. Weighted + Covariates (Regression-Adjusted IPTW): HR = %.3f  (%s)  [%s vs Row 1]
  4. Marginal Structural:  HR = %.3f  (%s)  [%s vs Row 1]

DISMISSAL — PSLRA Hazard Ratios
  1. Unadjusted:           HR = %.3f  (%s)
  2. Regression-Adjusted:  HR = %.3f  (%s)  [%s vs Row 1]
  3. Weighted + Covariates (Regression-Adjusted IPTW): HR = %.3f  (%s)  [%s vs Row 1]
  4. Marginal Structural:  HR = %.3f  (%s)  [%s vs Row 1]

FINDINGS (computed from model output):
  1. Row 1 → Row 2 shift: settlement %+.1f%%, dismissal %+.1f%%
  2. Rows 2/3/4 convergence: settlement %.3f/%.3f/%.3f, dismissal %.3f/%.3f/%.3f
  3. Max p-value across all 8 models: %.2e
  4. Weighted PH test (MSM dismissal): %s

CAVEATS:
  - NOT causal. Unmeasured confounders are NOT controlled.
  - Propensity model pseudo-R2 = %.3f (limited discrimination).
  - Covariates may be post-treatment (see header note). Adjusted HR
    is a decomposition, potentially a lower bound on total effect.
=================================================================\n",
  format(nrow(df_ext), big.mark = ","),
  sum(df_ext$post_pslra == 0), sum(df_ext$post_pslra == 1),
  sum(df_ext$post_pslra == 1) / sum(df_ext$post_pslra == 0),
  trim_cap,
  ess_pre, 100 * ess_pre / length(w_pre), ess_post,
  balance_msg, ps_smd,
  # Settlement
  s_raw_e$hr, tri_settlement$`95% CI`[1],
  s_reg_e$hr, tri_settlement$`95% CI`[2], tri_settlement$`vs Row 1`[2],
  s_ra_iptw_e$hr,  tri_settlement$`95% CI`[3], tri_settlement$`vs Row 1`[3],
  s_msm_e$hr, tri_settlement$`95% CI`[4], tri_settlement$`vs Row 1`[4],
  # Dismissal
  d_raw_e$hr, tri_dismissal$`95% CI`[1],
  d_reg_e$hr, tri_dismissal$`95% CI`[2], tri_dismissal$`vs Row 1`[2],
  d_ra_iptw_e$hr,  tri_dismissal$`95% CI`[3], tri_dismissal$`vs Row 1`[3],
  d_msm_e$hr, tri_dismissal$`95% CI`[4], tri_dismissal$`vs Row 1`[4],
  # Dynamic findings
  s_shift_1_to_2, d_shift_1_to_2,
  s_reg_e$hr, s_ra_iptw_e$hr, s_msm_e$hr,
  d_reg_e$hr, d_ra_iptw_e$hr, d_msm_e$hr,
  max_p,
  ph_d_msg,
  # Pseudo-R2
  pseudo_r2
))

# --- Session Info ---
print_session()
