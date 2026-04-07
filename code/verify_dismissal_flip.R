# ============================================================
# Script: verify_dismissal_flip.R
# Purpose: Four stress tests for the Dismissal Flip time-control result
#   Step 1: Non-linear spline test (ns(filing_year, df=3))
#   Step 2: Local window comparison (1993-1998 only)
#   Step 3: 1992 placebo split (pre-PSLRA only)
#   Step 4: IPTW trimming sensitivity (95th vs 99th percentile)
# Input: data/cleaned/securities_cohort_cleaned.rds
# Output: Console output only (verification — no saved objects)
# Dependencies: survival, splines, tidyverse, here, WeightIt, cobalt
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
cat(" DISMISSAL FLIP STRESS TESTS\n")
cat("=================================================================\n\n")

df <- readRDS(here::here("data", "cleaned", "securities_cohort_cleaned.rds"))
cat(sprintf("Loaded: %s rows\n\n", format(nrow(df), big.mark = ",")))

# =============================================================================
# STEP 1: NON-LINEAR SPLINE TEST
# =============================================================================
cat("=================================================================\n")
cat(" STEP 1: NON-LINEAR SPLINE TEST\n")
cat(" Replace linear filing_year with ns(filing_year, df=3)\n")
cat(" If PSLRA dismissal HR < 1.0 vanishes → linear time control was too restrictive\n")
cat("=================================================================\n\n")

library(splines)

# First: remind ourselves what the linear model gives
cox_d_linear <- coxph(
  Surv(duration_years, event_type == 2) ~ post_pslra + filing_year,
  data = df
)
cox_s_linear <- coxph(
  Surv(duration_years, event_type == 1) ~ post_pslra + filing_year,
  data = df
)

cat("--- LINEAR time trend (reference) ---\n")
cat(sprintf("  Settlement: HR = %.4f, p = %.2e\n",
    exp(coef(cox_s_linear)["post_pslra"]),
    summary(cox_s_linear)$coefficients["post_pslra", "Pr(>|z|)"]))
cat(sprintf("  Dismissal:  HR = %.4f, p = %.2e\n",
    exp(coef(cox_d_linear)["post_pslra"]),
    summary(cox_d_linear)$coefficients["post_pslra", "Pr(>|z|)"]))

# Now: natural spline with 3 df
cox_d_spline <- coxph(
  Surv(duration_years, event_type == 2) ~ post_pslra + ns(filing_year, df = 3),
  data = df
)
cox_s_spline <- coxph(
  Surv(duration_years, event_type == 1) ~ post_pslra + ns(filing_year, df = 3),
  data = df
)

cat("\n--- SPLINE time trend (ns, df=3) ---\n")
cat(sprintf("  Settlement: HR = %.4f, 95%% CI: [%.4f, %.4f], p = %.2e\n",
    exp(coef(cox_s_spline)["post_pslra"]),
    exp(confint(cox_s_spline)["post_pslra", 1]),
    exp(confint(cox_s_spline)["post_pslra", 2]),
    summary(cox_s_spline)$coefficients["post_pslra", "Pr(>|z|)"]))
cat(sprintf("  Dismissal:  HR = %.4f, 95%% CI: [%.4f, %.4f], p = %.2e\n",
    exp(coef(cox_d_spline)["post_pslra"]),
    exp(confint(cox_d_spline)["post_pslra", 1]),
    exp(confint(cox_d_spline)["post_pslra", 2]),
    summary(cox_d_spline)$coefficients["post_pslra", "Pr(>|z|)"]))

# Also try df=5 for maximum flexibility
cox_d_spline5 <- coxph(
  Surv(duration_years, event_type == 2) ~ post_pslra + ns(filing_year, df = 5),
  data = df
)
cox_s_spline5 <- coxph(
  Surv(duration_years, event_type == 1) ~ post_pslra + ns(filing_year, df = 5),
  data = df
)

cat(sprintf("\n--- SPLINE time trend (ns, df=5) ---\n"))
cat(sprintf("  Settlement: HR = %.4f, 95%% CI: [%.4f, %.4f], p = %.2e\n",
    exp(coef(cox_s_spline5)["post_pslra"]),
    exp(confint(cox_s_spline5)["post_pslra", 1]),
    exp(confint(cox_s_spline5)["post_pslra", 2]),
    summary(cox_s_spline5)$coefficients["post_pslra", "Pr(>|z|)"]))
cat(sprintf("  Dismissal:  HR = %.4f, 95%% CI: [%.4f, %.4f], p = %.2e\n",
    exp(coef(cox_d_spline5)["post_pslra"]),
    exp(confint(cox_d_spline5)["post_pslra", 1]),
    exp(confint(cox_d_spline5)["post_pslra", 2]),
    summary(cox_d_spline5)$coefficients["post_pslra", "Pr(>|z|)"]))

cat("\nFull summary of spline (df=3) dismissal model:\n")
print(summary(cox_d_spline))

# VIF check: how collinear is post_pslra with the spline basis?
X <- model.matrix(~ post_pslra + ns(filing_year, df = 3), data = df)[, -1]
vif_manual <- 1 / (1 - summary(lm(X[,1] ~ X[,2:4]))$r.squared)
cat(sprintf("\nVIF for post_pslra in spline model: %.2f\n", vif_manual))


# =============================================================================
# STEP 2: LOCAL WINDOW COMPARISON (1993-1998)
# =============================================================================
cat("\n\n=================================================================\n")
cat(" STEP 2: LOCAL WINDOW COMPARISON (1993-1998)\n")
cat(" Check whether the sign persists in a narrow pre/post PSLRA window\n")
cat(" without imposing any explicit filing_year trend control\n")
cat("=================================================================\n\n")

df_window <- df %>% filter(filing_year >= 1993, filing_year <= 1998)
cat(sprintf("Window sample: %d cases (%d pre / %d post PSLRA)\n",
    nrow(df_window),
    sum(df_window$post_pslra == 0),
    sum(df_window$post_pslra == 1)))
cat(sprintf("  Filing years: %d to %d\n",
    min(df_window$filing_year), max(df_window$filing_year)))
cat(sprintf("  Events: %d settlements, %d dismissals, %d censored\n",
    sum(df_window$event_type == 1),
    sum(df_window$event_type == 2),
    sum(df_window$event_type == 0)))

# NO time controls — local window comparison
cox_s_window <- coxph(
  Surv(duration_years, event_type == 1) ~ post_pslra,
  data = df_window
)
cox_d_window <- coxph(
  Surv(duration_years, event_type == 2) ~ post_pslra,
  data = df_window
)

cat(sprintf("\n--- 1993-1998 Window, NO time controls ---\n"))
cat(sprintf("  Settlement: HR = %.4f, 95%% CI: [%.4f, %.4f], p = %.2e\n",
    exp(coef(cox_s_window)["post_pslra"]),
    exp(confint(cox_s_window)["post_pslra", 1]),
    exp(confint(cox_s_window)["post_pslra", 2]),
    summary(cox_s_window)$coefficients["post_pslra", "Pr(>|z|)"]))
cat(sprintf("  Dismissal:  HR = %.4f, 95%% CI: [%.4f, %.4f], p = %.2e\n",
    exp(coef(cox_d_window)["post_pslra"]),
    exp(confint(cox_d_window)["post_pslra", 1]),
    exp(confint(cox_d_window)["post_pslra", 2]),
    summary(cox_d_window)$coefficients["post_pslra", "Pr(>|z|)"]))

cat("\nFull summary — Dismissal (1993-1998 window):\n")
print(summary(cox_d_window))

cat("\nFull summary — Settlement (1993-1998 window):\n")
print(summary(cox_s_window))

# Also try with filing_year in the window (should be modest over only 6 years)
cox_d_window_time <- coxph(
  Surv(duration_years, event_type == 2) ~ post_pslra + filing_year,
  data = df_window
)
cat(sprintf("\n--- 1993-1998 Window, WITH linear time control ---\n"))
cat(sprintf("  Dismissal:  HR = %.4f, 95%% CI: [%.4f, %.4f], p = %.2e\n",
    exp(coef(cox_d_window_time)["post_pslra"]),
    exp(confint(cox_d_window_time)["post_pslra", 1]),
    exp(confint(cox_d_window_time)["post_pslra", 2]),
    summary(cox_d_window_time)$coefficients["post_pslra", "Pr(>|z|)"]))


# =============================================================================
# STEP 3: 1992 PLACEBO TEST
# =============================================================================
cat("\n\n=================================================================\n")
cat(" STEP 3: PLACEBO SPLIT TEST (fake PSLRA date = Jan 1, 1992)\n")
cat(" Run on pre-PSLRA cases only (1990-1995)\n")
cat(" If the fake split is significant, secular time structure remains even pre-PSLRA\n")
cat("=================================================================\n\n")

df_pre <- df %>% filter(post_pslra == 0)
cat(sprintf("Pre-PSLRA sample: %d cases (filing years %d to %d)\n",
    nrow(df_pre), min(df_pre$filing_year), max(df_pre$filing_year)))
cat(sprintf("  Events: %d settlements, %d dismissals, %d censored\n",
    sum(df_pre$event_type == 1),
    sum(df_pre$event_type == 2),
    sum(df_pre$event_type == 0)))

# Placebo: filed on or after Jan 1, 1992
df_pre <- df_pre %>%
  mutate(placebo_pslra = as.integer(filing_year >= 1992))

cat(sprintf("  Placebo split: %d 'pre' (1990-1991) / %d 'post' (1992-1995)\n",
    sum(df_pre$placebo_pslra == 0),
    sum(df_pre$placebo_pslra == 1)))

cox_s_placebo <- coxph(
  Surv(duration_years, event_type == 1) ~ placebo_pslra,
  data = df_pre
)
cox_d_placebo <- coxph(
  Surv(duration_years, event_type == 2) ~ placebo_pslra,
  data = df_pre
)

cat(sprintf("\n--- Placebo (fake Jan 1, 1992), NO time controls ---\n"))
cat(sprintf("  Settlement: HR = %.4f, 95%% CI: [%.4f, %.4f], p = %.4f\n",
    exp(coef(cox_s_placebo)["placebo_pslra"]),
    exp(confint(cox_s_placebo)["placebo_pslra", 1]),
    exp(confint(cox_s_placebo)["placebo_pslra", 2]),
    summary(cox_s_placebo)$coefficients["placebo_pslra", "Pr(>|z|)"]))
cat(sprintf("  Dismissal:  HR = %.4f, 95%% CI: [%.4f, %.4f], p = %.4f\n",
    exp(coef(cox_d_placebo)["placebo_pslra"]),
    exp(confint(cox_d_placebo)["placebo_pslra", 1]),
    exp(confint(cox_d_placebo)["placebo_pslra", 2]),
    summary(cox_d_placebo)$coefficients["placebo_pslra", "Pr(>|z|)"]))

cat("\nFull summary — Dismissal (placebo 1992):\n")
print(summary(cox_d_placebo))

# Also: placebo with filing_year control
cox_d_placebo_time <- coxph(
  Surv(duration_years, event_type == 2) ~ placebo_pslra + filing_year,
  data = df_pre
)
cat(sprintf("\n--- Placebo (fake 1992), WITH filing_year control ---\n"))
cat(sprintf("  Dismissal:  HR = %.4f, 95%% CI: [%.4f, %.4f], p = %.4f\n",
    exp(coef(cox_d_placebo_time)["placebo_pslra"]),
    exp(confint(cox_d_placebo_time)["placebo_pslra", 1]),
    exp(confint(cox_d_placebo_time)["placebo_pslra", 2]),
    summary(cox_d_placebo_time)$coefficients["placebo_pslra", "Pr(>|z|)"]))


# =============================================================================
# STEP 4: IPTW TRIMMING SENSITIVITY (95th vs 99th percentile)
# =============================================================================
cat("\n\n=================================================================\n")
cat(" STEP 4: IPTW TRIMMING SENSITIVITY (95th vs 99th percentile)\n")
cat("=================================================================\n\n")

# Prepare data (mirrors the current 05_causal_iptw.R pipeline)
circuit_counts <- df %>% count(circuit, sort = TRUE)
circuits_incl  <- circuit_counts %>% filter(n >= 50) %>% pull(circuit)
stat_coverage  <- 100 * mean(!is.na(df$stat_basis_f))
include_stat   <- stat_coverage >= 15

df_ext <- df %>%
  filter(circuit %in% circuits_incl) %>%
  mutate(circuit_f = relevel(factor(circuit), ref = "2")) %>%
  filter(!is.na(origin_cat), !is.na(mdl_flag), !is.na(juris_fq))

if (include_stat) {
  df_ext <- df_ext %>%
    mutate(stat_basis_f = forcats::fct_na_value_to_level(stat_basis_f, level = "Missing"))
}

# Propensity score model (same as 05)
if (include_stat) {
  ps_formula <- post_pslra ~ circuit_f + origin_cat + juris_fq + stat_basis_f
} else {
  ps_formula <- post_pslra ~ circuit_f + origin_cat + juris_fq
}
ps_model <- glm(ps_formula, data = df_ext, family = binomial(link = "logit"))
df_ext$ps <- predict(ps_model, type = "response")

# ATT weights
df_ext <- df_ext %>%
  mutate(att_weight_raw = ifelse(post_pslra == 1, 1, ps / (1 - ps)))

run_iptw_at_trim <- function(df, pctl, label) {
  w_pre_raw <- df$att_weight_raw[df$post_pslra == 0]
  cap <- quantile(w_pre_raw, pctl)

  df$att_w <- ifelse(df$post_pslra == 1, 1, pmin(df$att_weight_raw, cap))

  w_pre <- df$att_w[df$post_pslra == 0]
  ess <- sum(w_pre)^2 / sum(w_pre^2)
  n_trimmed <- sum(w_pre_raw > cap)

  cat(sprintf("\n--- %s (trim cap = %.2f, %d cases trimmed, ESS = %.1f) ---\n",
      label, cap, n_trimmed, ess))
  if (pctl < 0.99 && identical(unname(cap), unname(quantile(w_pre_raw, 0.99)))) {
    cat("  Note: trim cap equals the 99th-percentile cap because the weight distribution is discrete in this upper tail.\n")
  }

  # MSM (Row 4 equivalent)
  s_msm <- coxph(Surv(duration_years, event_type == 1) ~ post_pslra,
                  data = df, weights = att_w, robust = TRUE)
  d_msm <- coxph(Surv(duration_years, event_type == 2) ~ post_pslra,
                  data = df, weights = att_w, robust = TRUE)

  cat(sprintf("  Settlement MSM: HR = %.4f, 95%% CI: [%.4f, %.4f], p = %.2e\n",
      exp(coef(s_msm)["post_pslra"]),
      exp(confint(s_msm)["post_pslra", 1]),
      exp(confint(s_msm)["post_pslra", 2]),
      summary(s_msm)$coefficients["post_pslra", "Pr(>|z|)"]))
  cat(sprintf("  Dismissal  MSM: HR = %.4f, 95%% CI: [%.4f, %.4f], p = %.2e\n",
      exp(coef(d_msm)["post_pslra"]),
      exp(confint(d_msm)["post_pslra", 1]),
      exp(confint(d_msm)["post_pslra", 2]),
      summary(d_msm)$coefficients["post_pslra", "Pr(>|z|)"]))

  # Weighted + Covariates (Row 3 equivalent)
  if (include_stat) {
    ext_rhs <- "post_pslra + circuit_f + origin_cat + mdl_flag + juris_fq + stat_basis_f"
  } else {
    ext_rhs <- "post_pslra + circuit_f + origin_cat + mdl_flag + juris_fq"
  }
  s_ra_iptw <- coxph(as.formula(paste("Surv(duration_years, event_type == 1) ~", ext_rhs)),
                     data = df, weights = att_w, robust = TRUE)
  d_ra_iptw <- coxph(as.formula(paste("Surv(duration_years, event_type == 2) ~", ext_rhs)),
                     data = df, weights = att_w, robust = TRUE)

  cat(sprintf("  Settlement Weighted + Covariates: HR = %.4f, 95%% CI: [%.4f, %.4f], p = %.2e\n",
      exp(coef(s_ra_iptw)["post_pslra"]),
      exp(confint(s_ra_iptw)["post_pslra", 1]),
      exp(confint(s_ra_iptw)["post_pslra", 2]),
      summary(s_ra_iptw)$coefficients["post_pslra", "Pr(>|z|)"]))
  cat(sprintf("  Dismissal  Weighted + Covariates: HR = %.4f, 95%% CI: [%.4f, %.4f], p = %.2e\n",
      exp(coef(d_ra_iptw)["post_pslra"]),
      exp(confint(d_ra_iptw)["post_pslra", 1]),
      exp(confint(d_ra_iptw)["post_pslra", 2]),
      summary(d_ra_iptw)$coefficients["post_pslra", "Pr(>|z|)"]))

  invisible(list(ess = ess, cap = cap, n_trimmed = n_trimmed))
}

cat("Existing 99th percentile (reference):\n")
res_99 <- run_iptw_at_trim(df_ext, 0.99, "99th percentile trim")

cat("\nNew 95th percentile (more aggressive trimming):\n")
res_95 <- run_iptw_at_trim(df_ext, 0.95, "95th percentile trim")

cat("\nFor completeness — 90th percentile (very aggressive):\n")
res_90 <- run_iptw_at_trim(df_ext, 0.90, "90th percentile trim")


# =============================================================================
# VERDICT
# =============================================================================
cat("\n\n=================================================================\n")
cat(" VERDICT SUMMARY\n")
cat("=================================================================\n")
cat("
Step 1 (Spline):
  If dismissal HR still < 1.0 and significant → sign is stable to a non-linear time trend
  If dismissal HR moves materially or changes sign → the linear time control was too restrictive

Step 2 (1993-1998 Window):
  If dismissal HR > 1.0 → the local-window sign differs from the full-sample time-control result
  If dismissal HR < 1.0 → the sign persists in the narrow window
  If dismissal HR ≈ 1.0 → inconclusive (underpowered or mixed)

Step 3 (Placebo):
  If placebo p > 0.05 → no comparable pre-PSLRA split is detected
  If placebo p < 0.05 → secular time structure appears around an arbitrary pre-PSLRA cutoff

Step 4 (Trimming):
  If MSM HRs are stable across 90th/95th/99th → finding is robust to weight extremes
  If MSM HRs flip or lose significance → finding is fragile to weight specification
=================================================================\n")
