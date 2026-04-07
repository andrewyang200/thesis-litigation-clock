# ============================================================
# Script: 03_cox_models.R
# Purpose: All cause-specific Cox proportional hazards models:
#          baseline, piecewise time-varying, circuit, extended, interaction
# Input: data/cleaned/securities_cohort_cleaned.rds
# Output: Console output with model summaries, HRs, PH tests
#         output/models/cox_models.rds (saved model objects for diagnostics)
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
cat(" 03_cox_models.R — CAUSE-SPECIFIC COX MODELS\n")
cat("=================================================================\n\n")

# =============================================================================
# LOAD DATA
# =============================================================================
cat("Loading cleaned data...\n")
df <- readRDS(here::here("data", "cleaned", "securities_cohort_cleaned.rds"))
cat(sprintf("  Loaded: %s rows\n", format(nrow(df), big.mark = ",")))

# --- Derived datasets ---
# Circuits with >= 50 cases (for stable coefficient estimation)
circuit_counts <- df %>% count(circuit, sort = TRUE)
circuits_incl  <- circuit_counts %>% filter(n >= 50) %>% pull(circuit)
cat(sprintf("  Circuits with >= 50 cases: %d of %d\n",
            length(circuits_incl), n_distinct(df$circuit)))

# Circuit-level dataset (reference = Circuit 2 / Second Circuit)
# Reference level rationale: The Second Circuit (SDNY) is the dominant venue
# for securities litigation by volume, so all other circuits are compared to
# the jurisdiction that handles the most securities class actions. This is
# standard in securities litigation empirics. Note: Circuit 2 is an outlier on
# the settlement dimension (lowest settlement hazard) — this means all other
# circuits show HR > 1 for settlement, which readers should interpret as
# "relative to the most restrictive settlement venue."
df_circ <- df %>%
  filter(circuit %in% circuits_incl) %>%
  mutate(circuit_f = relevel(factor(circuit), ref = "2"))
cat(sprintf("  Circuit dataset: %s rows\n", format(nrow(df_circ), big.mark = ",")))

# Extended dataset: complete cases on core covariates
# Check statutory basis coverage for conditional inclusion
stat_coverage <- 100 * mean(!is.na(df$stat_basis_f))
include_stat  <- stat_coverage >= 15
cat(sprintf("  Statutory basis coverage: %.1f%% (include in models: %s)\n",
            stat_coverage, include_stat))

df_ext <- df_circ %>%
  filter(!is.na(origin_cat), !is.na(mdl_flag), !is.na(juris_fq))

# Convert stat_basis_f NA to explicit factor level so all rows contribute
# (otherwise coxph silently drops NA rows, making stat_basis_miss constant=0)
if (include_stat) {
  df_ext <- df_ext %>%
    mutate(stat_basis_f = forcats::fct_na_value_to_level(stat_basis_f, level = "Missing"))
}
cat(sprintf("  Extended model sample: %s rows\n", format(nrow(df_ext), big.mark = ",")))

# Formula for extended models
# stat_basis_miss is no longer needed — NA is now an explicit factor level
base_formula_rhs <- "post_pslra + circuit_f + origin_cat + mdl_flag + juris_fq"
if (include_stat) {
  ext_formula_rhs <- paste(base_formula_rhs, "+ stat_basis_f")
} else {
  ext_formula_rhs <- base_formula_rhs
  cat("  Statutory basis omitted (coverage below 15% threshold).\n")
}


# =============================================================================
# SECTION 1: BASELINE COX MODELS (PSLRA only)
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("BASELINE COX MODELS (PSLRA only, full sample)\n")
cat("-----------------------------------------------------------------\n")

cox_s_base <- coxph(
  Surv(duration_years, event_type == 1) ~ post_pslra,
  data = df
)
cox_d_base <- coxph(
  Surv(duration_years, event_type == 2) ~ post_pslra,
  data = df
)

cat("\nBaseline Cox — Settlement:\n")
print(summary(cox_s_base))

cat("\nBaseline Cox — Dismissal:\n")
print(summary(cox_d_base))

cat("\nProportional hazards tests (baseline):\n")
cat("Settlement:\n"); print(cox.zph(cox_s_base))
cat("Dismissal:\n");  print(cox.zph(cox_d_base))


# =============================================================================
# SECTION 2: PIECEWISE TIME-VARYING PSLRA EFFECT
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("PIECEWISE PSLRA EFFECT ON DISMISSAL (time-varying)\n")
cat("-----------------------------------------------------------------\n")

# Cutpoint justification: The 1-year and 2-year boundaries are chosen on
# institutional grounds, not data-driven selection:
#   0-1 years: Corresponds to the motion-to-dismiss phase. Under the PSLRA's
#              heightened pleading standard (15 U.S.C. §78u-4(b)), defendants
#              must move to dismiss within ~60 days; judicial resolution of
#              these motions typically occurs within 6-12 months of filing.
#   1-2 years: The discovery and class certification phase. Cases surviving
#              the initial motion enter merits discovery.
#   2+ years:  Settlement negotiation and trial preparation. Cases reaching
#              this stage have cleared the major procedural hurdles.
# These cutpoints align with well-documented litigation milestones in the
# securities class action lifecycle (see e.g., Cox et al. 2009).

df_split <- survSplit(
  Surv(duration_years, event_type == 2) ~ .,
  data    = df,
  cut     = c(1, 2),
  episode = "period"
) %>%
  mutate(
    period_label = factor(period, 1:3,
                          c("0-1 years", "1-2 years", "2+ years"))
  )

cox_piecewise <- coxph(
  Surv(tstart, duration_years, event) ~ post_pslra:period_label,
  data = df_split
)

cat("\nPSLRA Effect on Dismissal Hazard by Time Period:\n")
pw_tbl <- tibble(
  Period   = c("0-1 years", "1-2 years", "2+ years"),
  HR       = round(exp(coef(cox_piecewise)), 3),
  CI_lower = round(exp(confint(cox_piecewise))[, 1], 3),
  CI_upper = round(exp(confint(cox_piecewise))[, 2], 3),
  p_value  = round(summary(cox_piecewise)$coefficients[, "Pr(>|z|)"], 4)
)
print(pw_tbl)

# Also run piecewise for settlement
df_split_s <- survSplit(
  Surv(duration_years, event_type == 1) ~ .,
  data    = df,
  cut     = c(1, 2),
  episode = "period"
) %>%
  mutate(
    period_label = factor(period, 1:3,
                          c("0-1 years", "1-2 years", "2+ years"))
  )

cox_piecewise_s <- coxph(
  Surv(tstart, duration_years, event) ~ post_pslra:period_label,
  data = df_split_s
)

cat("\nPSLRA Effect on Settlement Hazard by Time Period:\n")
pw_tbl_s <- tibble(
  Period   = c("0-1 years", "1-2 years", "2+ years"),
  HR       = round(exp(coef(cox_piecewise_s)), 3),
  CI_lower = round(exp(confint(cox_piecewise_s))[, 1], 3),
  CI_upper = round(exp(confint(cox_piecewise_s))[, 2], 3),
  p_value  = round(summary(cox_piecewise_s)$coefficients[, "Pr(>|z|)"], 4)
)
print(pw_tbl_s)


# =============================================================================
# SECTION 3: COX WITH CIRCUIT FIXED EFFECTS
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("COX WITH CIRCUIT FIXED EFFECTS\n")
cat("-----------------------------------------------------------------\n")

cox_s_circ <- coxph(
  Surv(duration_years, event_type == 1) ~ post_pslra + circuit_f,
  data = df_circ
)
cox_d_circ <- coxph(
  Surv(duration_years, event_type == 2) ~ post_pslra + circuit_f,
  data = df_circ
)

cat("\nCox with Circuit Effects — Settlement:\n")
print(round(summary(cox_s_circ)$conf.int, 3))

cat("\nCox with Circuit Effects — Dismissal:\n")
print(round(summary(cox_d_circ)$conf.int, 3))


# =============================================================================
# SECTION 4: EXTENDED COX WITH ALL COVARIATES
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("EXTENDED COX WITH ALL COVARIATES\n")
cat("-----------------------------------------------------------------\n")

cox_s_ext <- coxph(
  as.formula(paste("Surv(duration_years, event_type==1) ~", ext_formula_rhs)),
  data = df_ext
)
cox_d_ext <- coxph(
  as.formula(paste("Surv(duration_years, event_type==2) ~", ext_formula_rhs)),
  data = df_ext
)

cat("\nExtended Cox — Settlement:\n")
print(summary(cox_s_ext))

cat("\nExtended Cox — Dismissal:\n")
print(summary(cox_d_ext))

cat("\nProportional hazards tests (extended models):\n")
cat("Settlement:\n"); print(cox.zph(cox_s_ext))
cat("Dismissal:\n");  print(cox.zph(cox_d_ext))


# =============================================================================
# SECTION 5: PSLRA x CIRCUIT INTERACTION
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("PSLRA x CIRCUIT INTERACTION (top 6 circuits)\n")
cat("-----------------------------------------------------------------\n")

# Top 6 circuits for stable interaction estimates
top6 <- circuit_counts %>% head(6) %>% pull(circuit)
df_int <- df_ext %>%
  filter(circuit %in% top6) %>%
  mutate(circuit_f = relevel(factor(circuit), ref = "2"))

cat(sprintf("  Interaction sample: %s rows across %d circuits\n",
            format(nrow(df_int), big.mark = ","), length(top6)))

# Interaction models use reduced covariate set (no stat_basis) to limit
# parameter count — the PSLRA*circuit interaction already adds 5 terms
# Settlement: interaction vs. no interaction
cox_s_int <- coxph(
  as.formula(paste("Surv(duration_years, event_type==1) ~ post_pslra * circuit_f +",
                   "origin_cat + mdl_flag + juris_fq")),
  data = df_int
)
cox_s_noint <- coxph(
  as.formula(paste("Surv(duration_years, event_type==1) ~ post_pslra + circuit_f +",
                   "origin_cat + mdl_flag + juris_fq")),
  data = df_int
)

# Dismissal: interaction vs. no interaction
cox_d_int <- coxph(
  as.formula(paste("Surv(duration_years, event_type==2) ~ post_pslra * circuit_f +",
                   "origin_cat + mdl_flag + juris_fq")),
  data = df_int
)
cox_d_noint <- coxph(
  as.formula(paste("Surv(duration_years, event_type==2) ~ post_pslra + circuit_f +",
                   "origin_cat + mdl_flag + juris_fq")),
  data = df_int
)

cat("\nLRT: PSLRA x Circuit — Settlement:\n")
print(anova(cox_s_noint, cox_s_int))
cat("\nLRT: PSLRA x Circuit — Dismissal:\n")
print(anova(cox_d_noint, cox_d_int))

# Interaction coefficients (HR ratios relative to Circuit 2)
cat("\nPSLRA x Circuit interaction HRs — Settlement:\n")
int_coefs_s <- coef(cox_s_int)
int_coefs_s <- int_coefs_s[grepl("post_pslra:circuit_f", names(int_coefs_s))]
print(round(exp(int_coefs_s), 3))

cat("\nPSLRA x Circuit interaction HRs — Dismissal:\n")
int_coefs_d <- coef(cox_d_int)
int_coefs_d <- int_coefs_d[grepl("post_pslra:circuit_f", names(int_coefs_d))]
print(round(exp(int_coefs_d), 3))


# =============================================================================
# SAVE MODEL OBJECTS (for 07_diagnostics.R)
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("SAVING MODEL OBJECTS\n")
cat("-----------------------------------------------------------------\n")

# Create output/models/ if needed
models_dir <- here::here("output", "models")
if (!dir.exists(models_dir)) dir.create(models_dir, recursive = TRUE)

cox_results <- list(
  # Baseline
  cox_s_base    = cox_s_base,
  cox_d_base    = cox_d_base,
  # Piecewise
  cox_piecewise   = cox_piecewise,
  cox_piecewise_s = cox_piecewise_s,
  # Circuit
  cox_s_circ    = cox_s_circ,
  cox_d_circ    = cox_d_circ,
  # Extended
  cox_s_ext     = cox_s_ext,
  cox_d_ext     = cox_d_ext,
  # Interaction
  cox_s_int     = cox_s_int,
  cox_d_int     = cox_d_int,
  cox_s_noint   = cox_s_noint,
  cox_d_noint   = cox_d_noint,
  # Metadata
  ext_formula_rhs = ext_formula_rhs,
  include_stat    = include_stat,
  circuits_incl   = circuits_incl,
  df_ext_nrow     = nrow(df_ext),
  df_int_nrow     = nrow(df_int),
  cox_s_ext_n     = cox_s_ext$n,
  cox_d_ext_n     = cox_d_ext$n
)

saveRDS(cox_results, here::here("output", "models", "cox_models.rds"))
cat("  Saved: output/models/cox_models.rds\n")


# =============================================================================
# DONE
# =============================================================================
cat("\n=================================================================\n")
cat(" 03_cox_models.R COMPLETE\n")
cat("=================================================================\n")

print_session()
