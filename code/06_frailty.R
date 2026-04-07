# ============================================================
# Script: 06_frailty.R
# Purpose: Shared frailty (mixed-effects) Cox models with circuit-level
#          random intercepts. Quantifies unobserved circuit heterogeneity
#          and tests whether the PSLRA HR is robust to random-effects
#          specification. Framed as SENSITIVITY ANALYSIS — 11 clusters
#          (circuits with >= 50 cases) is below the ~20-30 typically
#          recommended for reliable frailty variance estimation.
#
# CRITICAL FRAMING NOTE (post-treatment bias):
#   Covariates like circuit filing choice and MDL status may be
#   consequences of PSLRA, not pre-treatment confounders. These
#   estimates represent a decomposition of the PSLRA effect, and
#   the composition-adjusted HR may be a lower bound on the total
#   effect if PSLRA changed WHERE and HOW cases were filed.
#
# NOTE ON FE vs RE COMPARISON:
#   The PSLRA HR is invariant between fixed- and random-effects
#   specifications because PSLRA is a national-level shock applied
#   uniformly to all circuits. The frailty model's value lies NOT
#   in the PSLRA HR itself — which cannot differ — but in:
#   (a) the frailty variance theta, which quantifies unobserved
#       circuit heterogeneity, and
#   (b) the cluster-robust SEs, which provide conservative inference.
# Input: data/cleaned/securities_cohort_cleaned.rds
#        output/models/cox_models.rds (for fixed-effect comparison)
# Output: output/models/frailty_results.rds
#         Console: frailty model summaries, comparison table
# Dependencies: survival, coxme, tidyverse, here
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
cat(" 06_frailty.R — SHARED FRAILTY MODELS (Sensitivity Analysis)\n")
cat("=================================================================\n\n")
cat("PURPOSE: Test whether the PSLRA effect is robust to accounting for\n")
cat("unobserved circuit-level heterogeneity via random intercepts.\n\n")
cat("FRAMING: Sensitivity analysis, not standalone model.\n")
cat("  - Only 11 circuit clusters (below 20-30 recommended for frailty).\n")
cat("  - Frailty variance is a rough estimate, subject to small-cluster bias.\n")
cat("  - Primary robustness check remains cluster-robust SEs (sandwich).\n")
cat("  - Frailty adds value by estimating the MAGNITUDE of unobserved\n")
cat("    circuit heterogeneity, which cluster-robust SEs do not.\n\n")

# =============================================================================
# LOAD DATA (mirrors 03_cox_models.R pipeline exactly)
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

cat(sprintf("  Circuits included: %d (n >= 50 cases)\n", length(circuits_incl)))
cat(sprintf("  Circuit dataset: %s rows\n", format(nrow(df_circ), big.mark = ",")))

# Extended dataset: complete cases on core covariates
stat_coverage <- 100 * mean(!is.na(df$stat_basis_f))
include_stat  <- stat_coverage >= 15

df_ext <- df_circ %>%
  filter(!is.na(origin_cat), !is.na(mdl_flag), !is.na(juris_fq))

if (include_stat) {
  df_ext <- df_ext %>%
    mutate(stat_basis_f = forcats::fct_na_value_to_level(stat_basis_f, level = "Missing"))
}
cat(sprintf("  Extended model sample: %s rows\n", format(nrow(df_ext), big.mark = ",")))

# Circuit distribution
cat("\n  Circuit case counts:\n")
circ_tab <- df_ext %>% count(circuit_f, sort = TRUE)
for (i in seq_len(nrow(circ_tab))) {
  cat(sprintf("    Circuit %s: %s cases\n", circ_tab$circuit_f[i],
              format(circ_tab$n[i], big.mark = ",")))
}

# =============================================================================
# LOAD FIXED-EFFECT COX MODELS (for comparison)
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("LOADING FIXED-EFFECT COX MODELS FOR COMPARISON\n")
cat("-----------------------------------------------------------------\n")

cox_results <- readRDS(here::here("output", "models", "cox_models.rds"))
cat("  Loaded: output/models/cox_models.rds\n")
ext_formula_rhs <- cox_results$ext_formula_rhs

# Extract fixed-effect PSLRA HRs for comparison table
fe_s_base <- summary(cox_results$cox_s_base)
fe_d_base <- summary(cox_results$cox_d_base)
fe_s_ext  <- summary(cox_results$cox_s_ext)
fe_d_ext  <- summary(cox_results$cox_d_ext)

cat(sprintf("  Fixed-effect baseline (no circuit) settlement HR: %.3f\n",
            exp(coef(cox_results$cox_s_base)["post_pslra"])))
cat(sprintf("  Fixed-effect baseline (no circuit) dismissal HR:  %.3f\n",
            exp(coef(cox_results$cox_d_base)["post_pslra"])))
cat(sprintf("  Fixed-effect circuit FE settlement HR:             %.3f\n",
            exp(coef(cox_results$cox_s_circ)["post_pslra"])))
cat(sprintf("  Fixed-effect circuit FE dismissal HR:              %.3f\n",
            exp(coef(cox_results$cox_d_circ)["post_pslra"])))
cat(sprintf("  Fixed-effect extended settlement HR:               %.3f\n",
            exp(coef(cox_results$cox_s_ext)["post_pslra"])))
cat(sprintf("  Fixed-effect extended dismissal HR:                %.3f\n",
            exp(coef(cox_results$cox_d_ext)["post_pslra"])))

# =============================================================================
# SECTION 1: BASELINE FRAILTY MODELS (PSLRA + circuit random intercept)
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("BASELINE FRAILTY MODELS: post_pslra + (1 | circuit_f)\n")
cat("-----------------------------------------------------------------\n")
cat("Using coxme::coxme() with Gaussian random intercepts on the log-hazard scale.\n")
cat("(i.e., u_c ~ N(0, theta); the multiplicative frailty exp(u_c) is log-normal.)\n")
cat("These models include NO fixed-effect circuit terms — circuit\n")
cat("heterogeneity is captured entirely by the random intercept.\n\n")

# Settlement — baseline frailty
cat("Fitting baseline frailty — Settlement...\n")
frailty_s_base <- tryCatch(
  coxme(
    Surv(duration_years, event_type == 1) ~ post_pslra + (1 | circuit_f),
    data = df_circ
  ),
  error = function(e) {
    cat(sprintf("  *** CONVERGENCE FAILURE: %s ***\n", e$message))
    NULL
  }
)

if (!is.null(frailty_s_base)) {
  cat("\nBaseline Frailty — Settlement:\n")
  print(frailty_s_base)
  cat(sprintf("\n  PSLRA HR (frailty, circuit RE):     %.3f\n", exp(fixef(frailty_s_base)["post_pslra"])))
  cat(sprintf("  PSLRA HR (circuit FE):              %.3f\n", exp(coef(cox_results$cox_s_circ)["post_pslra"])))
  cat(sprintf("  PSLRA HR (no circuit, for ref):     %.3f\n", exp(coef(cox_results$cox_s_base)["post_pslra"])))
  cat(sprintf("  Frailty variance (circuit): %.4f\n", VarCorr(frailty_s_base)$circuit_f[1]))
  cat(sprintf("  Frailty SD (circuit):       %.4f\n", sqrt(VarCorr(frailty_s_base)$circuit_f[1])))
  if (VarCorr(frailty_s_base)$circuit_f[1] < 1e-10) {
    cat("  *** WARNING: Frailty variance is exactly zero (boundary). ***\n")
    cat("  *** The random effect is degenerate — interpret with caution. ***\n")
  }
  cat("\n  NOTE: The valid comparison is frailty RE vs. circuit FE (both adjust\n")
  cat("  for circuit). The 'no circuit' HR differs because it omits circuit\n")
  cat("  adjustment entirely, not because of the random-effects specification.\n")
}

# Dismissal — baseline frailty
cat("\nFitting baseline frailty — Dismissal...\n")
frailty_d_base <- tryCatch(
  coxme(
    Surv(duration_years, event_type == 2) ~ post_pslra + (1 | circuit_f),
    data = df_circ
  ),
  error = function(e) {
    cat(sprintf("  *** CONVERGENCE FAILURE: %s ***\n", e$message))
    NULL
  }
)

if (!is.null(frailty_d_base)) {
  cat("\nBaseline Frailty — Dismissal:\n")
  print(frailty_d_base)
  cat(sprintf("\n  PSLRA HR (frailty, circuit RE):     %.3f\n", exp(fixef(frailty_d_base)["post_pslra"])))
  cat(sprintf("  PSLRA HR (circuit FE):              %.3f\n", exp(coef(cox_results$cox_d_circ)["post_pslra"])))
  cat(sprintf("  PSLRA HR (no circuit, for ref):     %.3f\n", exp(coef(cox_results$cox_d_base)["post_pslra"])))
  cat(sprintf("  Frailty variance (circuit): %.4f\n", VarCorr(frailty_d_base)$circuit_f[1]))
  cat(sprintf("  Frailty SD (circuit):       %.4f\n", sqrt(VarCorr(frailty_d_base)$circuit_f[1])))
  if (VarCorr(frailty_d_base)$circuit_f[1] < 1e-10) {
    cat("  *** WARNING: Frailty variance is exactly zero (boundary). ***\n")
    cat("  *** The random effect is degenerate — interpret with caution. ***\n")
  }
  cat("\n  NOTE: The valid comparison is frailty RE vs. circuit FE (both adjust\n")
  cat("  for circuit). The 'no circuit' HR differs because it omits circuit\n")
  cat("  adjustment entirely, not because of the random-effects specification.\n")
}


# =============================================================================
# SECTION 2: EXTENDED FRAILTY MODELS (full covariates + circuit random effect)
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("EXTENDED FRAILTY MODELS: full covariates + (1 | circuit_f)\n")
cat("-----------------------------------------------------------------\n")
cat("These models include all extended covariates as fixed effects,\n")
cat("EXCEPT circuit_f which moves from fixed to random.\n")
cat("This tests whether unobserved circuit heterogeneity persists\n")
cat("after controlling for observable case characteristics.\n\n")

# Formula: everything from the saved extended Cox specification EXCEPT circuit_f
# (which moves from fixed to random here).
ext_no_circuit_rhs <- ext_formula_rhs %>%
  stringr::str_replace("\\s*\\+\\s*circuit_f\\b", "") %>%
  stringr::str_squish()
cat(sprintf("  Fixed effects: %s\n", ext_no_circuit_rhs))
cat("  Random effect: (1 | circuit_f)\n\n")

# Settlement — extended frailty
cat("Fitting extended frailty — Settlement...\n")
frailty_s_ext <- tryCatch(
  coxme(
    as.formula(paste("Surv(duration_years, event_type == 1) ~",
                     ext_no_circuit_rhs, "+ (1 | circuit_f)")),
    data = df_ext
  ),
  error = function(e) {
    cat(sprintf("  *** CONVERGENCE FAILURE: %s ***\n", e$message))
    NULL
  }
)

if (!is.null(frailty_s_ext)) {
  cat("\nExtended Frailty — Settlement:\n")
  print(frailty_s_ext)
  cat(sprintf("\n  PSLRA HR (frailty):      %.3f\n", exp(fixef(frailty_s_ext)["post_pslra"])))
  cat(sprintf("  PSLRA HR (fixed-effect): %.3f\n", exp(coef(cox_results$cox_s_ext)["post_pslra"])))
  cat(sprintf("  Frailty variance (circuit): %.4f\n", VarCorr(frailty_s_ext)$circuit_f[1]))
  cat(sprintf("  Frailty SD (circuit):       %.4f\n", sqrt(VarCorr(frailty_s_ext)$circuit_f[1])))
}

# Dismissal — extended frailty
cat("\nFitting extended frailty — Dismissal...\n")
frailty_d_ext <- tryCatch(
  coxme(
    as.formula(paste("Surv(duration_years, event_type == 2) ~",
                     ext_no_circuit_rhs, "+ (1 | circuit_f)")),
    data = df_ext
  ),
  error = function(e) {
    cat(sprintf("  *** CONVERGENCE FAILURE: %s ***\n", e$message))
    NULL
  }
)

if (!is.null(frailty_d_ext)) {
  cat("\nExtended Frailty — Dismissal:\n")
  print(frailty_d_ext)
  cat(sprintf("\n  PSLRA HR (frailty):      %.3f\n", exp(fixef(frailty_d_ext)["post_pslra"])))
  cat(sprintf("  PSLRA HR (fixed-effect): %.3f\n", exp(coef(cox_results$cox_d_ext)["post_pslra"])))
  cat(sprintf("  Frailty variance (circuit): %.4f\n", VarCorr(frailty_d_ext)$circuit_f[1]))
  cat(sprintf("  Frailty SD (circuit):       %.4f\n", sqrt(VarCorr(frailty_d_ext)$circuit_f[1])))
}


# =============================================================================
# SECTION 3: CLUSTER-ROBUST STANDARD ERRORS (primary robustness check)
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("CLUSTER-ROBUST SEs: Fixed-effect Cox with sandwich variance\n")
cat("-----------------------------------------------------------------\n")
cat("The primary robustness check for within-circuit correlation.\n")
cat("Unlike frailty, cluster-robust SEs adjust inference (CIs/p-values)\n")
cat("but do NOT estimate the magnitude of circuit heterogeneity.\n\n")

# Baseline: PSLRA only, clustered by circuit.
# IMPORTANT: cluster = circuit_f adjusts STANDARD ERRORS for within-circuit
# correlation (sandwich/robust variance), but does NOT include circuit as a
# covariate in the mean model. The HR is nearly identical to the no-circuit
# model (differs only by circuit filtering); the primary effect is
# SE/CI/p-value adjustment. This is SE-adjustment, NOT confounding
# adjustment. For circuit-level confounding adjustment, see the circuit FE
# and circuit RE (frailty) models above.
cox_s_cluster_base <- coxph(
  Surv(duration_years, event_type == 1) ~ post_pslra,
  data = df_circ,
  cluster = circuit_f
)
cox_d_cluster_base <- coxph(
  Surv(duration_years, event_type == 2) ~ post_pslra,
  data = df_circ,
  cluster = circuit_f
)

cat("Baseline (PSLRA only) with cluster-robust SEs:\n")
cat(sprintf("  Settlement: HR = %.3f, robust SE = %.4f\n",
            exp(coef(cox_s_cluster_base)["post_pslra"]),
            summary(cox_s_cluster_base)$coefficients["post_pslra", "robust se"]))
cat(sprintf("  Dismissal:  HR = %.3f, robust SE = %.4f\n",
            exp(coef(cox_d_cluster_base)["post_pslra"]),
            summary(cox_d_cluster_base)$coefficients["post_pslra", "robust se"]))

# Extended: full covariates (with circuit fixed effects), clustered by circuit
cox_s_cluster_ext <- coxph(
  as.formula(paste("Surv(duration_years, event_type == 1) ~", ext_formula_rhs)),
  data = df_ext,
  cluster = circuit_f
)
cox_d_cluster_ext <- coxph(
  as.formula(paste("Surv(duration_years, event_type == 2) ~", ext_formula_rhs)),
  data = df_ext,
  cluster = circuit_f
)

cat("\nExtended (full covariates) with cluster-robust SEs:\n")
cat(sprintf("  Settlement: HR = %.3f, robust SE = %.4f\n",
            exp(coef(cox_s_cluster_ext)["post_pslra"]),
            summary(cox_s_cluster_ext)$coefficients["post_pslra", "robust se"]))
cat(sprintf("  Dismissal:  HR = %.3f, robust SE = %.4f\n",
            exp(coef(cox_d_cluster_ext)["post_pslra"]),
            summary(cox_d_cluster_ext)$coefficients["post_pslra", "robust se"]))


# =============================================================================
# SECTION 4: RANDOM EFFECTS — CIRCUIT-LEVEL BLUPs
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("CIRCUIT-LEVEL RANDOM EFFECTS (BLUPs)\n")
cat("-----------------------------------------------------------------\n")
cat("Best Linear Unbiased Predictors for each circuit's deviation\n")
cat("from the population average hazard. Exponentiated = HR multiplier.\n\n")

# Extract BLUPs from the extended models (richer specification)
# Use whichever converged
models_for_blup <- list()
if (!is.null(frailty_s_ext)) models_for_blup$settlement <- frailty_s_ext
if (!is.null(frailty_d_ext)) models_for_blup$dismissal  <- frailty_d_ext

for (outcome_name in names(models_for_blup)) {
  m <- models_for_blup[[outcome_name]]
  re <- ranef(m)$circuit_f
  blup_df <- tibble(
    circuit = names(re),
    random_effect = as.numeric(re),
    exp_re = exp(as.numeric(re))
  ) %>%
    left_join(circ_tab %>% mutate(circuit = as.character(circuit_f)),
              by = "circuit") %>%
    arrange(desc(abs(random_effect)))

  cat(sprintf("\n  %s — Circuit Random Effects (sorted by |deviation|):\n",
              tools::toTitleCase(outcome_name)))
  cat(sprintf("  %-10s  %10s  %10s  %8s\n", "Circuit", "BLUP", "exp(BLUP)", "N"))
  cat(sprintf("  %-10s  %10s  %10s  %8s\n", "-------", "--------", "---------", "------"))
  for (j in seq_len(nrow(blup_df))) {
    cat(sprintf("  %-10s  %10.4f  %10.3f  %8s\n",
                blup_df$circuit[j],
                blup_df$random_effect[j],
                blup_df$exp_re[j],
                format(blup_df$n[j], big.mark = ",")))
  }
}


# =============================================================================
# SECTION 5: COMPARISON TABLE — Fixed vs. Frailty vs. Cluster-Robust
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("COMPARISON: Fixed-Effect vs. Frailty vs. Cluster-Robust\n")
cat("-----------------------------------------------------------------\n")

# Helper to extract PSLRA HR, SE, CI, p from different model types
extract_comparison <- function(model, model_type) {
  if (inherits(model, "coxme")) {
    coefs <- summary(model)$coefficients
    beta <- coefs["post_pslra", "coef"]
    se   <- coefs["post_pslra", "se(coef)"]
    p    <- coefs["post_pslra", "p"]
    hr   <- exp(beta)
    ci_lo <- exp(beta - 1.96 * se)
    ci_hi <- exp(beta + 1.96 * se)
  } else {
    # coxph (possibly with cluster-robust SEs)
    s <- summary(model)
    beta <- coef(model)["post_pslra"]
    p_col <- grep("^Pr\\(", colnames(s$coefficients), value = TRUE)[1]
    p <- s$coefficients["post_pslra", p_col]
    # Use robust SE if available (cluster models), else naive SE
    se_col <- if ("robust se" %in% colnames(s$coefficients)) "robust se" else "se(coef)"
    se <- s$coefficients["post_pslra", se_col]
    hr <- exp(beta)
    ci <- exp(confint(model)["post_pslra", ])
    ci_lo <- ci[1]
    ci_hi <- ci[2]
  }
  tibble(
    Model = model_type,
    HR = hr,
    SE = se,
    CI = sprintf("%.3f--%.3f", ci_lo, ci_hi),
    p = p
  )
}

# Build comparison for each outcome x specification
# The meaningful comparison is: models that all adjust for circuit, but differ
# in HOW they adjust (fixed effect vs. random intercept vs. cluster-robust SE).
# The baseline-no-circuit model is included only as a reference point.
cat("\n=== SETTLEMENT ===\n")
comp_s <- bind_rows(
  extract_comparison(cox_results$cox_s_base, "No circuit (naive SE)"),
  extract_comparison(cox_s_cluster_base, "No circuit (cluster-robust SE)"),
  extract_comparison(cox_results$cox_s_circ, "Circuit FE (naive SE)"),
  if (!is.null(frailty_s_base)) extract_comparison(frailty_s_base, "Circuit RE (frailty)"),
  extract_comparison(cox_results$cox_s_ext, "Extended FE (naive SE)"),
  extract_comparison(cox_s_cluster_ext, "Extended FE (cluster-robust SE)"),
  if (!is.null(frailty_s_ext)) extract_comparison(frailty_s_ext, "Extended RE (frailty)")
)
print(as.data.frame(comp_s), row.names = FALSE)

cat("\n=== DISMISSAL ===\n")
comp_d <- bind_rows(
  extract_comparison(cox_results$cox_d_base, "No circuit (naive SE)"),
  extract_comparison(cox_d_cluster_base, "No circuit (cluster-robust SE)"),
  extract_comparison(cox_results$cox_d_circ, "Circuit FE (naive SE)"),
  if (!is.null(frailty_d_base)) extract_comparison(frailty_d_base, "Circuit RE (frailty)"),
  extract_comparison(cox_results$cox_d_ext, "Extended FE (naive SE)"),
  extract_comparison(cox_d_cluster_ext, "Extended FE (cluster-robust SE)"),
  if (!is.null(frailty_d_ext)) extract_comparison(frailty_d_ext, "Extended RE (frailty)")
)
print(as.data.frame(comp_d), row.names = FALSE)


# =============================================================================
# SECTION 6: FRAILTY VARIANCE INTERPRETATION
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("FRAILTY VARIANCE INTERPRETATION\n")
cat("-----------------------------------------------------------------\n")

# Collect frailty variances
frailty_models <- list(
  "Settlement (baseline)" = frailty_s_base,
  "Settlement (extended)" = frailty_s_ext,
  "Dismissal (baseline)"  = frailty_d_base,
  "Dismissal (extended)"  = frailty_d_ext
)

cat("\n  Frailty Variance Summary:\n")
cat(sprintf("  %-25s  %10s  %10s  %s\n",
            "Model", "Variance", "SD", "Interpretation"))
cat(sprintf("  %-25s  %10s  %10s  %s\n",
            "-------------------------", "----------", "----------",
            "--------------------------------------------"))

for (nm in names(frailty_models)) {
  m <- frailty_models[[nm]]
  if (is.null(m)) {
    cat(sprintf("  %-25s  %10s  %10s  %s\n", nm, "FAILED", "---", "Model did not converge"))
    next
  }
  var_val <- VarCorr(m)$circuit_f[1]
  sd_val  <- sqrt(var_val)

  # Interpret: exp(+/- 1 SD) gives the range of circuit-level HR multipliers
  interp <- sprintf("Circuits span HR multiplier %.2f to %.2f",
                     exp(-sd_val), exp(sd_val))
  if (var_val < 0.01) {
    interp <- paste(interp, "(minimal heterogeneity)")
  } else if (var_val < 0.1) {
    interp <- paste(interp, "(moderate heterogeneity)")
  } else {
    interp <- paste(interp, "(substantial heterogeneity)")
  }

  cat(sprintf("  %-25s  %10.4f  %10.4f  %s\n", nm, var_val, sd_val, interp))
}

cat(sprintf("\n  NOTE: With only %d clusters, frailty variance may be biased downward.\n", length(circuits_incl)))
cat("  The estimates above should be interpreted as rough lower bounds on the\n")
cat("  true extent of unobserved circuit-level heterogeneity.\n")


# =============================================================================
# SECTION 7: SAVE RESULTS
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("SAVING RESULTS\n")
cat("-----------------------------------------------------------------\n")

frailty_results <- list(
  # Baseline frailty models
  frailty_s_base = frailty_s_base,
  frailty_d_base = frailty_d_base,

  # Extended frailty models
  frailty_s_ext = frailty_s_ext,
  frailty_d_ext = frailty_d_ext,

  # Cluster-robust SE models
  cox_s_cluster_base = cox_s_cluster_base,
  cox_d_cluster_base = cox_d_cluster_base,
  cox_s_cluster_ext  = cox_s_cluster_ext,
  cox_d_cluster_ext  = cox_d_cluster_ext,

  # Comparison tables
  comparison_settlement = comp_s,
  comparison_dismissal  = comp_d,

  # Metadata
  metadata = list(
    n_circ = length(circuits_incl),
    n_rows_circ = nrow(df_circ),
    n_ext  = nrow(df_ext),
    n_circuits = length(circuits_incl),
    circuits = circuits_incl,
    frailty_type = "Gaussian random intercept (coxme); exp(u) is log-normal",
    ext_formula_rhs_no_circuit = ext_no_circuit_rhs,
    framing = sprintf("sensitivity analysis (%d clusters < recommended 20-30)", length(circuits_incl)),
    date = Sys.time()
  )
)

saveRDS(frailty_results, here::here("output", "models", "frailty_results.rds"))
cat("  Saved: output/models/frailty_results.rds\n")


# =============================================================================
# FINAL SUMMARY
# =============================================================================
cat("\n=================================================================\n")
cat(" FRAILTY ANALYSIS SUMMARY\n")
cat("=================================================================\n")

# Collect key numbers
summary_lines <- character()

for (outcome in c("Settlement", "Dismissal")) {
  base_m <- if (outcome == "Settlement") frailty_s_base else frailty_d_base
  ext_m  <- if (outcome == "Settlement") frailty_s_ext  else frailty_d_ext
  fe_base <- if (outcome == "Settlement") cox_results$cox_s_base else cox_results$cox_d_base
  fe_ext  <- if (outcome == "Settlement") cox_results$cox_s_ext  else cox_results$cox_d_ext

  cat(sprintf("\n%s:\n", toupper(outcome)))

  fe_circ <- if (outcome == "Settlement") cox_results$cox_s_circ else cox_results$cox_d_circ

  if (!is.null(base_m)) {
    base_var <- VarCorr(base_m)$circuit_f[1]
    cat(sprintf("  Baseline — Frailty RE: %.3f | Circuit FE: %.3f | Frailty var: %.4f\n",
                exp(fixef(base_m)["post_pslra"]),
                exp(coef(fe_circ)["post_pslra"]),
                base_var))
  } else {
    cat("  Baseline — CONVERGENCE FAILURE\n")
  }

  if (!is.null(ext_m)) {
    ext_var <- VarCorr(ext_m)$circuit_f[1]
    cat(sprintf("  Extended — Frailty RE: %.3f | Extended FE: %.3f | Frailty var: %.4f\n",
                exp(fixef(ext_m)["post_pslra"]),
                exp(coef(fe_ext)["post_pslra"]),
                ext_var))
  } else {
    cat("  Extended — CONVERGENCE FAILURE\n")
  }
}

# --- Dynamic KEY FINDINGS (all values computed from model objects) ---
n_converged <- sum(!sapply(list(frailty_s_base, frailty_d_base, frailty_s_ext, frailty_d_ext), is.null))
cat(sprintf("\nKEY FINDINGS (computed from model output):\n"))
cat(sprintf("  1. %d of 4 frailty models converge with %d clusters.\n", n_converged, length(circuits_incl)))

# FE vs RE comparison (dynamic)
if (!is.null(frailty_s_ext)) {
  fe_re_delta_s <- abs(exp(fixef(frailty_s_ext)["post_pslra"]) - exp(coef(cox_results$cox_s_ext)["post_pslra"]))
  cat(sprintf("  2. PSLRA HR: FE-RE delta = %.4f (settlement)", fe_re_delta_s))
}
if (!is.null(frailty_d_ext)) {
  fe_re_delta_d <- abs(exp(fixef(frailty_d_ext)["post_pslra"]) - exp(coef(cox_results$cox_d_ext)["post_pslra"]))
  cat(sprintf(", %.4f (dismissal)", fe_re_delta_d))
}
cat("\n     (Near-zero expected: PSLRA is a national-level shock.)\n")

# Frailty variance (dynamic)
cat("  3. Frailty variance (theta):\n")
for (nm in names(frailty_models)) {
  m <- frailty_models[[nm]]
  if (!is.null(m)) {
    theta <- VarCorr(m)$circuit_f[1]
    label <- if (theta < 0.01) "minimal" else if (theta < 0.1) "moderate" else "substantial"
    cat(sprintf("     - %s: theta = %.4f (%s heterogeneity)\n", nm, theta, label))
  } else {
    cat(sprintf("     - %s: FAILED\n", nm))
  }
}

# Cluster-robust SE widening (dynamic)
naive_se_s <- summary(cox_results$cox_s_ext)$coefficients["post_pslra", "se(coef)"]
robust_se_s <- summary(cox_s_cluster_ext)$coefficients["post_pslra", "robust se"]
naive_se_d <- summary(cox_results$cox_d_ext)$coefficients["post_pslra", "se(coef)"]
robust_se_d <- summary(cox_d_cluster_ext)$coefficients["post_pslra", "robust se"]
p_cluster_s <- summary(cox_s_cluster_ext)$coefficients["post_pslra", grep("^Pr\\(", colnames(summary(cox_s_cluster_ext)$coefficients), value = TRUE)[1]]
p_cluster_d <- summary(cox_d_cluster_ext)$coefficients["post_pslra", grep("^Pr\\(", colnames(summary(cox_d_cluster_ext)$coefficients), value = TRUE)[1]]

cat(sprintf("  4. Cluster-robust SE widening (extended, vs naive):\n"))
cat(sprintf("     - Settlement: %.1fx (p = %.4f)\n", robust_se_s / naive_se_s, p_cluster_s))
cat(sprintf("     - Dismissal:  %.1fx (p = %.4f)\n", robust_se_d / naive_se_d, p_cluster_d))
cat(sprintf("  5. With %d clusters, frailty variance may be biased downward.\n", length(circuits_incl)))
cat("=================================================================\n")

print_session()
