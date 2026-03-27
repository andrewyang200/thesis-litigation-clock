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

source("code/utils.R")

cat("=================================================================\n")
cat(" 04_fine_gray.R — FINE-GRAY SUBDISTRIBUTION MODELS\n")
cat("=================================================================\n\n")

# =============================================================================
# LOAD DATA
# =============================================================================
cat("Loading cleaned data...\n")
df <- readRDS(here::here("data", "cleaned", "securities_cohort_cleaned.rds"))
cat(sprintf("  Loaded: %s rows\n", format(nrow(df), big.mark = ",")))

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
fg_base_s_data <- finegray(
  Surv(duration_years, factor(event_type, 0:2)) ~ .,
  data  = df_circ %>% select(duration_years, event_type, post_pslra, circuit_f),
  etype = 1
)
fg_base_s <- coxph(
  Surv(fgstart, fgstop, fgstatus) ~ post_pslra + circuit_f,
  data = fg_base_s_data, weights = fgwt
)

# --- Dismissal subdistribution ---
fg_base_d_data <- finegray(
  Surv(duration_years, factor(event_type, 0:2)) ~ .,
  data  = df_circ %>% select(duration_years, event_type, post_pslra, circuit_f),
  etype = 2
)
fg_base_d <- coxph(
  Surv(fgstart, fgstop, fgstatus) ~ post_pslra + circuit_f,
  data = fg_base_d_data, weights = fgwt
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

comparison_tbl <- tibble(
  Outcome = c("Settlement", "Settlement", "Dismissal", "Dismissal"),
  Model   = c("Cause-Specific Cox", "Fine-Gray Subdist.",
              "Cause-Specific Cox", "Fine-Gray Subdist."),
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
  ), 3)
)

cat("\nCause-Specific vs. Subdistribution Hazard — PSLRA Effect:\n")
print(comparison_tbl)


# =============================================================================
# SECTION 3: EXTENDED FINE-GRAY WITH ALL COVARIATES
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("EXTENDED FINE-GRAY WITH ALL COVARIATES\n")
cat("-----------------------------------------------------------------\n")

# Select columns for finegray (it needs a clean dataset)
fg_cols <- c("duration_years", "event_type", "post_pslra", "circuit_f",
             "origin_cat", "mdl_flag", "juris_fq")
if (include_stat) fg_cols <- c(fg_cols, "stat_basis_f")

# --- Extended Settlement ---
fg_ext_s_data <- finegray(
  Surv(duration_years, factor(event_type, 0:2)) ~ .,
  data  = df_ext %>% select(all_of(fg_cols)),
  etype = 1
)
fg_s_ext <- coxph(
  as.formula(paste("Surv(fgstart, fgstop, fgstatus) ~", ext_formula_rhs)),
  data    = fg_ext_s_data,
  weights = fgwt
)

# --- Extended Dismissal ---
fg_ext_d_data <- finegray(
  Surv(duration_years, factor(event_type, 0:2)) ~ .,
  data  = df_ext %>% select(all_of(fg_cols)),
  etype = 2
)
fg_d_ext <- coxph(
  as.formula(paste("Surv(fgstart, fgstop, fgstatus) ~", ext_formula_rhs)),
  data    = fg_ext_d_data,
  weights = fgwt
)

cat("\nExtended Fine-Gray — Settlement:\n")
print(summary(fg_s_ext))

cat("\nExtended Fine-Gray — Dismissal:\n")
print(summary(fg_d_ext))


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
  # Comparison
  comparison_tbl = comparison_tbl,
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
