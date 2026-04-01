# ============================================================
# Script: 08_robustness.R
# Purpose: Robustness checks across disposition coding schemes,
#          temporal restrictions, and circuit-specific sub-models.
#          Produces the robustness forest plot.
# Input: data/cleaned/securities_cohort_cleaned.rds (Scheme A)
#        data/cleaned/securities_scheme_B.rds
#        data/cleaned/securities_scheme_C.rds
# Output: output/figures/fig_robustness_hr.{pdf,png}
#         output/models/robustness_results.rds
#         Console output with robustness table
# Dependencies: survival, tidyverse, here
# Seed: N/A (deterministic)
# ============================================================

source("code/utils.R")

cat("=================================================================\n")
cat(" 08_robustness.R — ROBUSTNESS CHECKS\n")
cat("=================================================================\n\n")

# =============================================================================
# LOAD ALL THREE DISPOSITION SCHEMES
# =============================================================================
cat("Loading all three disposition scheme datasets...\n")

df_A <- readRDS(here::here("data", "cleaned", "securities_cohort_cleaned.rds"))
df_B <- readRDS(here::here("data", "cleaned", "securities_scheme_B.rds"))
df_C <- readRDS(here::here("data", "cleaned", "securities_scheme_C.rds"))

cat(sprintf("  Scheme A: %s rows (Settlement=%s, Dismissal=%s)\n",
            format(nrow(df_A), big.mark = ","),
            sum(df_A$event_type == 1), sum(df_A$event_type == 2)))
cat(sprintf("  Scheme B: %s rows (Settlement=%s, Dismissal=%s)\n",
            format(nrow(df_B), big.mark = ","),
            sum(df_B$event_type == 1), sum(df_B$event_type == 2)))
cat(sprintf("  Scheme C: %s rows (Settlement=%s, Dismissal=%s)\n",
            format(nrow(df_C), big.mark = ","),
            sum(df_C$event_type == 1), sum(df_C$event_type == 2)))


# =============================================================================
# HELPER: Run baseline PSLRA Cox for both outcomes
# =============================================================================
run_pslra_cox <- function(df, label) {
  s <- tryCatch(
    coxph(Surv(duration_years, event_type == 1) ~ post_pslra, data = df),
    error = function(e) { cat(sprintf("  Cox error (S, %s): %s\n", label, e$message)); NULL }
  )
  d <- tryCatch(
    coxph(Surv(duration_years, event_type == 2) ~ post_pslra, data = df),
    error = function(e) { cat(sprintf("  Cox error (D, %s): %s\n", label, e$message)); NULL }
  )

  extract_row <- function(model, outcome_label) {
    if (is.null(model)) return(NULL)
    ci <- tryCatch(confint(model)["post_pslra", ], error = function(e) c(NA, NA))
    tibble(
      Specification = label, Outcome = outcome_label, N = nrow(df),
      N_events = sum(df$event_type == ifelse(outcome_label == "Settlement", 1, 2)),
      HR = round(exp(coef(model)[["post_pslra"]]), 3),
      CI_lower = round(exp(ci[1]), 3),
      CI_upper = round(exp(ci[2]), 3),
      p_value  = round(summary(model)$coefficients["post_pslra", "Pr(>|z|)"], 4)
    )
  }

  bind_rows(extract_row(s, "Settlement"), extract_row(d, "Dismissal"))
}


# =============================================================================
# ROBUSTNESS SPECIFICATIONS
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("RUNNING ROBUSTNESS SPECIFICATIONS\n")
cat("-----------------------------------------------------------------\n")

# 1. Alternative coding schemes
cat("\n  [1/7] Scheme A (primary)...\n")
rob_A <- run_pslra_cox(df_A, "Scheme A: Primary")

cat("  [2/7] Scheme B (code 12 = settlement)...\n")
rob_B <- run_pslra_cox(df_B, "Scheme B: Code 12 = Settlement")

cat("  [3/7] Scheme C (codes 12+5 = settlement)...\n")
rob_C <- run_pslra_cox(df_C, "Scheme C: Codes 12+5 = Settlement")

# 2. Temporal restriction
cat("  [4/7] Temporal: exclude post-2020...\n")
rob_T <- run_pslra_cox(
  df_A %>% filter(filedate <= as.Date("2020-12-31")),
  "Temporal: exclude post-2020"
)

# 3. Circuit-specific sub-models
cat("  [5/7] Second Circuit only...\n")
rob_2nd <- run_pslra_cox(
  df_A %>% filter(circuit == 2),
  "Second Circuit only"
)

cat("  [6/7] Ninth Circuit only...\n")
rob_9th <- run_pslra_cox(
  df_A %>% filter(circuit == 9),
  "Ninth Circuit only"
)

# 4. Secular time-trend control (natural spline)
# The key identification challenge: post_pslra is collinear with calendar time.
# A linear filing_year control is too restrictive — it forces 34 years of non-linear
# judicial drift into one slope, absorbing the PSLRA step-change. A natural spline
# (df=3) flexibly captures secular trends while preserving the PSLRA discontinuity.
# Validated by verify_dismissal_flip.R: linear → HR=0.598 (artifact); spline → HR=1.94.
cat("  [7/7] Time-trend control (+ ns(filing_year, df=3))...\n")
library(splines)

s_time <- tryCatch(
  coxph(Surv(duration_years, event_type == 1) ~ post_pslra + ns(filing_year, df = 3), data = df_A),
  error = function(e) { cat(sprintf("  Cox error (S, time-trend): %s\n", e$message)); NULL }
)
d_time <- tryCatch(
  coxph(Surv(duration_years, event_type == 2) ~ post_pslra + ns(filing_year, df = 3), data = df_A),
  error = function(e) { cat(sprintf("  Cox error (D, time-trend): %s\n", e$message)); NULL }
)

rob_time <- bind_rows(
  if (!is.null(s_time)) tibble(
    Specification = "Time-trend control (spline)", Outcome = "Settlement",
    N = nrow(df_A), N_events = sum(df_A$event_type == 1),
    HR = round(exp(coef(s_time)[["post_pslra"]]), 3),
    CI_lower = round(exp(confint(s_time)["post_pslra", 1]), 3),
    CI_upper = round(exp(confint(s_time)["post_pslra", 2]), 3),
    p_value  = round(summary(s_time)$coefficients["post_pslra", "Pr(>|z|)"], 4)
  ),
  if (!is.null(d_time)) tibble(
    Specification = "Time-trend control (spline)", Outcome = "Dismissal",
    N = nrow(df_A), N_events = sum(df_A$event_type == 2),
    HR = round(exp(coef(d_time)[["post_pslra"]]), 3),
    CI_lower = round(exp(confint(d_time)["post_pslra", 1]), 3),
    CI_upper = round(exp(confint(d_time)["post_pslra", 2]), 3),
    p_value  = round(summary(d_time)$coefficients["post_pslra", "Pr(>|z|)"], 4)
  )
)

# Print detail for the spline model
cat("\n  --- Time-Trend Sensitivity Detail (Spline df=3) ---\n")
if (!is.null(s_time)) {
  s_hr <- exp(coef(s_time)["post_pslra"])
  s_p  <- summary(s_time)$coefficients["post_pslra", "Pr(>|z|)"]
  cat(sprintf("  Settlement: PSLRA HR=%.3f (p=%.1e) %s\n",
              s_hr, s_p, ifelse(s_p < 0.05, "[significant]", "[NOT significant]")))
}
if (!is.null(d_time)) {
  d_hr <- exp(coef(d_time)["post_pslra"])
  d_p  <- summary(d_time)$coefficients["post_pslra", "Pr(>|z|)"]
  cat(sprintf("  Dismissal:  PSLRA HR=%.3f (p=%.1e) %s\n",
              d_hr, d_p, ifelse(d_p < 0.05, "[significant]", "[NOT significant]")))
}

robustness_all <- bind_rows(rob_A, rob_B, rob_C, rob_T, rob_2nd, rob_9th, rob_time)

cat("\n-----------------------------------------------------------------\n")
cat("PSLRA Hazard Ratios Across Robustness Specifications:\n")
cat("-----------------------------------------------------------------\n")
print(robustness_all, n = Inf)


# =============================================================================
# FIGURE 6: ROBUSTNESS FOREST PLOT
# =============================================================================
cat("\nGenerating robustness forest plot...\n")

fig_rob <- robustness_all %>%
  mutate(Specification = factor(Specification, levels = rev(unique(Specification)))) %>%
  ggplot(aes(x = HR, y = Specification, color = Outcome, shape = Outcome)) +
  geom_point(size = 3.5, position = position_dodge(width = 0.4)) +
  geom_errorbar(
    aes(xmin = CI_lower, xmax = CI_upper),
    width = 0.2,
    position = position_dodge(width = 0.4),
    orientation = "y"
  ) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
  scale_color_manual(values = thesis_colors[c("Settlement", "Dismissal")]) +
  scale_x_log10(breaks = c(0.1, 0.3, 0.5, 1, 1.5, 2, 3),
                labels = c("0.1", "0.3", "0.5", "1", "1.5", "2", "3")) +
  labs(
    title    = "PSLRA Hazard Ratios Across Robustness Specifications",
    subtitle = "Hazard Ratios across Alternative Specifications and Subsets",
    x        = "Hazard Ratio (log scale) -- Post-PSLRA vs. Pre-PSLRA",
    y        = NULL,
    color    = "Outcome", shape = "Outcome",
    caption  = "Each row = separate Cox model. Dashed line at HR = 1 (null effect). Bars = 95% CI."
  ) +
  theme(
    plot.caption = element_text(size = 9, color = "gray50", hjust = 0)
  )

save_figure(fig_rob, "fig_robustness_hr", width = 10)


# =============================================================================
# SAVE ROBUSTNESS RESULTS
# =============================================================================
cat("\nSaving robustness results...\n")
models_dir <- here::here("output", "models")
if (!dir.exists(models_dir)) dir.create(models_dir, recursive = TRUE)

robustness_results <- list(
  table          = robustness_all,
  time_trend_s   = s_time,
  time_trend_d   = d_time,
  n_specs        = length(unique(robustness_all$Specification)),
  generated      = Sys.time()
)
saveRDS(robustness_results, here::here("output", "models", "robustness_results.rds"))
cat(sprintf("  Saved: output/models/robustness_results.rds (%d specifications)\n",
            robustness_results$n_specs))


# =============================================================================
# DONE
# =============================================================================
cat("\n=================================================================\n")
cat(" 08_robustness.R COMPLETE\n")
cat("=================================================================\n")

print_session()
