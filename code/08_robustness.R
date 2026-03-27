# ============================================================
# Script: 08_robustness.R
# Purpose: Robustness checks across disposition coding schemes,
#          temporal restrictions, and circuit-specific sub-models.
#          Produces the robustness forest plot.
# Input: data/cleaned/securities_cohort_cleaned.rds (Scheme A)
#        data/cleaned/securities_scheme_B.rds
#        data/cleaned/securities_scheme_C.rds
# Output: output/figures/fig_robustness_hr.{pdf,png}
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

  bind_rows(
    if (!is.null(s)) tibble(
      Specification = label, Outcome = "Settlement", N = nrow(df),
      N_events = sum(df$event_type == 1),
      HR = round(exp(coef(s)[["post_pslra"]]), 3),
      CI_lower = round(exp(confint(s)["post_pslra", 1]), 3),
      CI_upper = round(exp(confint(s)["post_pslra", 2]), 3),
      p_value  = round(summary(s)$coefficients["post_pslra", "Pr(>|z|)"], 4)
    ),
    if (!is.null(d)) tibble(
      Specification = label, Outcome = "Dismissal", N = nrow(df),
      N_events = sum(df$event_type == 2),
      HR = round(exp(coef(d)[["post_pslra"]]), 3),
      CI_lower = round(exp(confint(d)["post_pslra", 1]), 3),
      CI_upper = round(exp(confint(d)["post_pslra", 2]), 3),
      p_value  = round(summary(d)$coefficients["post_pslra", "Pr(>|z|)"], 4)
    )
  )
}


# =============================================================================
# ROBUSTNESS SPECIFICATIONS
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("RUNNING ROBUSTNESS SPECIFICATIONS\n")
cat("-----------------------------------------------------------------\n")

# 1. Alternative coding schemes
cat("\n  [1/6] Scheme A (primary)...\n")
rob_A <- run_pslra_cox(df_A, "Scheme A: Primary")

cat("  [2/6] Scheme B (code 12 = settlement)...\n")
rob_B <- run_pslra_cox(df_B, "Scheme B: Code 12 = Settlement")

cat("  [3/6] Scheme C (codes 12+5 = settlement)...\n")
rob_C <- run_pslra_cox(df_C, "Scheme C: Codes 12+5 = Settlement")

# 2. Temporal restriction
cat("  [4/6] Temporal: exclude post-2020...\n")
rob_T <- run_pslra_cox(
  df_A %>% filter(filedate <= as.Date("2020-12-31")),
  "Temporal: exclude post-2020"
)

# 3. Circuit-specific sub-models
cat("  [5/6] Second Circuit only...\n")
rob_2nd <- run_pslra_cox(
  df_A %>% filter(circuit == 2),
  "Second Circuit only"
)

cat("  [6/6] Ninth Circuit only...\n")
rob_9th <- run_pslra_cox(
  df_A %>% filter(circuit == 9),
  "Ninth Circuit only"
)

robustness_all <- bind_rows(rob_A, rob_B, rob_C, rob_T, rob_2nd, rob_9th)

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
  scale_color_manual(values = c("Settlement" = "#1B7837", "Dismissal" = "#B2182B")) +
  scale_x_log10(breaks = c(0.1, 0.3, 0.5, 1, 1.5, 2, 3),
                labels = c("0.1", "0.3", "0.5", "1", "1.5", "2", "3")) +
  labs(
    title    = "PSLRA Hazard Ratios Across Robustness Specifications",
    subtitle = "PSLRA effect direction is consistent; magnitude varies by specification",
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
# DONE
# =============================================================================
cat("\n=================================================================\n")
cat(" 08_robustness.R COMPLETE\n")
cat("=================================================================\n")

print_session()
