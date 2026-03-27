# ============================================================
# Script: 02_descriptives.R
# Purpose: Kaplan-Meier survival curves, cumulative incidence functions,
#          Gray's tests, and descriptive CIF tables
# Input: data/cleaned/securities_cohort_cleaned.rds
# Output: output/figures/fig_km_overall.{pdf,png}
#         output/figures/fig_cif_overall.{pdf,png}
#         output/figures/fig_cif_pslra.{pdf,png}
#         output/figures/fig_cif_circuit_dismissal.{pdf,png}
#         output/figures/fig_cif_circuit_settlement.{pdf,png}
# Dependencies: survival, cmprsk, ggsurvfit, tidyverse, scales, here
# Seed: N/A (deterministic)
# ============================================================

source("code/utils.R")

cat("=================================================================\n")
cat(" 02_descriptives.R — KM, CIF, AND DESCRIPTIVE FIGURES\n")
cat("=================================================================\n\n")

# =============================================================================
# LOAD DATA
# =============================================================================
cat("Loading cleaned data...\n")
df <- readRDS(here::here("data", "cleaned", "securities_cohort_cleaned.rds"))
cat(sprintf("  Loaded: %s rows, %s cols\n", format(nrow(df), big.mark = ","), ncol(df)))
cat(sprintf("  Event distribution: Settlement=%s, Dismissal=%s, Censored=%s\n",
            sum(df$event_type == 1), sum(df$event_type == 2), sum(df$event_type == 0)))


# =============================================================================
# HELPER: Extract CIF curve from cuminc object
# =============================================================================
extract_cif <- function(cif_obj, group_name, event_code, event_label) {
  key <- paste(group_name, event_code)
  if (!key %in% names(cif_obj)) return(NULL)
  tibble(
    time    = cif_obj[[key]]$time,
    prob    = cif_obj[[key]]$est,
    group   = group_name,
    outcome = event_label
  )
}


# =============================================================================
# FIGURE 1: KAPLAN-MEIER OVERALL SURVIVAL
# =============================================================================
cat("\nFigure 1: Kaplan-Meier overall survival curve...\n")

surv_obj   <- Surv(df$duration_years, df$event_type != 0)
km_overall <- survfit(surv_obj ~ 1)

km_df <- tibble(
  time  = km_overall$time,
  surv  = km_overall$surv,
  lower = km_overall$lower,
  upper = km_overall$upper
)

fig_km <- ggplot(km_df, aes(x = time, y = surv)) +
  geom_step(linewidth = 1, color = "#2166AC") +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.18, fill = "#2166AC") +
  scale_x_continuous(limits = c(0, 10), breaks = seq(0, 10, 2)) +
  scale_y_continuous(limits = c(0, 1), labels = percent_format(accuracy = 1)) +
  labs(
    title    = "Duration of Federal Securities Class Actions",
    subtitle = paste0("Kaplan-Meier estimate (n = ",
                      format(nrow(df), big.mark = ","), ")"),
    x        = "Years Since Filing",
    y        = "Proportion Pending (Unresolved)",
    caption  = paste0(
      "Source: FJC Integrated Database, NOS 850 with class action flag, 1990-2024.\n",
      "Shaded band = 95% pointwise confidence interval."
    )
  ) +
  theme(
    plot.caption = element_text(size = 9, color = "gray50", hjust = 0)
  )

save_figure(fig_km, "fig_km_overall")

# Print KM summary at key timepoints
cat("  KM survival estimates:\n")
print(summary(km_overall, times = c(1, 2, 3, 5, 8)))


# =============================================================================
# FIGURE 2: CUMULATIVE INCIDENCE — OVERALL
# =============================================================================
cat("\nFigure 2: Aalen-Johansen CIF (overall)...\n")

cif_overall <- cmprsk::cuminc(
  ftime   = df$duration_years,
  fstatus = df$event_type,
  cencode = 0
)

cif_overall_df <- bind_rows(
  tibble(time = cif_overall$`1 1`$time,
         prob = cif_overall$`1 1`$est,
         outcome = "Settlement"),
  tibble(time = cif_overall$`1 2`$time,
         prob = cif_overall$`1 2`$est,
         outcome = "Dismissal")
)

fig_cif <- ggplot(cif_overall_df, aes(x = time, y = prob, color = outcome)) +
  geom_step(linewidth = 1.2) +
  scale_x_continuous(limits = c(0, 8), breaks = seq(0, 8, 2)) +
  scale_y_continuous(limits = c(0, 1), labels = percent_format(accuracy = 1)) +
  scale_color_manual(values = c("Settlement" = "#1B7837", "Dismissal" = "#B2182B")) +
  labs(
    title    = "Cumulative Incidence of Settlement vs. Dismissal",
    subtitle = "Aalen-Johansen estimates under competing-risks framework",
    x        = "Years Since Filing",
    y        = "Cumulative Probability",
    color    = "Outcome",
    caption  = paste0(
      "Source: FJC Integrated Database. Scheme A coding.\n",
      "Settlement = code 13; Dismissal = codes 2,3,4,6,12,14,15,17,18,19."
    )
  ) +
  theme(
    plot.caption = element_text(size = 9, color = "gray50", hjust = 0)
  )

save_figure(fig_cif, "fig_cif_overall")


# =============================================================================
# FIGURE 3: CIF BY PSLRA REGIME + GRAY'S TEST
# =============================================================================
cat("\nFigure 3: CIF by PSLRA regime + Gray's test...\n")

cif_pslra <- cmprsk::cuminc(
  ftime   = df$duration_years,
  fstatus = df$event_type,
  group   = df$pslra_label,
  cencode = 0
)

cat("\nGray's test for equality of CIF across PSLRA regimes:\n")
print(cif_pslra$Tests)

cif_pslra_df <- bind_rows(
  extract_cif(cif_pslra, "Pre-PSLRA",  1, "Settlement"),
  extract_cif(cif_pslra, "Pre-PSLRA",  2, "Dismissal"),
  extract_cif(cif_pslra, "Post-PSLRA", 1, "Settlement"),
  extract_cif(cif_pslra, "Post-PSLRA", 2, "Dismissal")
) %>%
  mutate(series = paste(group, outcome, sep = " \u2014 "))

fig_pslra <- ggplot(cif_pslra_df,
                     aes(x = time, y = prob, color = series, linetype = series)) +
  geom_step(linewidth = 1) +
  scale_x_continuous(limits = c(0, 8), breaks = seq(0, 8, 2)) +
  scale_y_continuous(limits = c(0, 1), labels = percent_format(accuracy = 1)) +
  scale_color_manual(values = c(
    "Pre-PSLRA \u2014 Settlement"  = "#1B7837",
    "Pre-PSLRA \u2014 Dismissal"   = "#B2182B",
    "Post-PSLRA \u2014 Settlement" = "#74C476",
    "Post-PSLRA \u2014 Dismissal"  = "#FC8D59"
  )) +
  scale_linetype_manual(values = c(
    "Pre-PSLRA \u2014 Settlement"  = "solid",
    "Pre-PSLRA \u2014 Dismissal"   = "solid",
    "Post-PSLRA \u2014 Settlement" = "dashed",
    "Post-PSLRA \u2014 Dismissal"  = "dashed"
  )) +
  guides(
    color    = guide_legend(nrow = 2, byrow = TRUE),
    linetype = guide_legend(nrow = 2, byrow = TRUE)
  ) +
  labs(
    title    = "Cumulative Incidence by PSLRA Regime",
    subtitle = "Private Securities Litigation Reform Act (effective December 22, 1995)",
    x        = "Years Since Filing",
    y        = "Cumulative Probability",
    color    = NULL, linetype = NULL,
    caption  = "Source: FJC Integrated Database. Solid = Pre-PSLRA; dashed = Post-PSLRA."
  ) +
  theme(
    plot.caption     = element_text(size = 9, color = "gray50", hjust = 0),
    legend.key.width = unit(1.8, "lines")
  )

save_figure(fig_pslra, "fig_cif_pslra", width = 9)


# --- Table: CIF at key horizons ---
get_cif_at_t <- function(cif_curve, t_target) {
  idx <- which(cif_curve$time <= t_target)
  if (length(idx) == 0) return(0)
  cif_curve$est[max(idx)]
}

horizons <- c(1, 2, 3, 5)

cat("\nCumulative Incidence at Key Horizons by PSLRA Regime (%):\n")
cif_horizon_tbl <- expand_grid(
  Group   = c("Pre-PSLRA", "Post-PSLRA"),
  Outcome = c("Settlement", "Dismissal"),
  Horizon = horizons
) %>%
  rowwise() %>%
  mutate(
    ev_code = if_else(Outcome == "Settlement", 1, 2),
    key     = paste(Group, ev_code),
    CIF_pct = round(get_cif_at_t(cif_pslra[[key]], Horizon) * 100, 1)
  ) %>%
  select(Group, Outcome, Horizon, CIF_pct) %>%
  pivot_wider(names_from = Horizon, values_from = CIF_pct,
              names_prefix = "Yr_")

print(cif_horizon_tbl)


# =============================================================================
# FIGURES 4-5: CIF BY CIRCUIT (Top 4)
# =============================================================================
cat("\nFigures 4-5: CIF by circuit (top 4)...\n")

circuit_counts <- df %>% count(circuit, sort = TRUE)
top4_circuits  <- circuit_counts %>% head(4) %>% pull(circuit)

df_top4 <- df %>%
  filter(circuit %in% top4_circuits) %>%
  mutate(circuit_name = case_when(
    circuit == 2 ~ "Second (NYC)",
    circuit == 9 ~ "Ninth (CA)",
    circuit == 3 ~ "Third (PA/NJ/DE)",
    circuit == 5 ~ "Fifth (TX/LA)",
    TRUE         ~ paste("Circuit", circuit)
  ))

cif_circuit <- cmprsk::cuminc(
  ftime   = df_top4$duration_years,
  fstatus = df_top4$event_type,
  group   = df_top4$circuit_name,
  cencode = 0
)

cat("\nGray's test for equality of CIF across circuits (top 4):\n")
print(cif_circuit$Tests)

circuit_names  <- unique(df_top4$circuit_name)
cif_circuit_df <- map_dfr(circuit_names, function(cn) {
  bind_rows(
    extract_cif(cif_circuit, cn, 1, "Settlement"),
    extract_cif(cif_circuit, cn, 2, "Dismissal")
  )
})

# Figure 4: Dismissal by circuit
fig_circ_d <- cif_circuit_df %>%
  filter(outcome == "Dismissal") %>%
  ggplot(aes(x = time, y = prob, color = group)) +
  geom_step(linewidth = 1) +
  scale_x_continuous(limits = c(0, 6), breaks = 0:6) +
  scale_y_continuous(limits = c(0, 1), labels = percent_format(accuracy = 1)) +
  scale_color_brewer(palette = "Set1") +
  guides(color = guide_legend(nrow = 2, byrow = TRUE)) +
  labs(
    title    = "Cumulative Incidence of Dismissal by Circuit",
    subtitle = "Top 4 circuits by case volume",
    x        = "Years Since Filing",
    y        = "Cumulative Probability of Dismissal",
    color    = "Circuit",
    caption  = "Source: FJC Integrated Database, 1990-2024."
  ) +
  theme(
    plot.caption = element_text(size = 9, color = "gray50", hjust = 0)
  )

save_figure(fig_circ_d, "fig_cif_circuit_dismissal", width = 9)

# Figure 5: Settlement by circuit
fig_circ_s <- cif_circuit_df %>%
  filter(outcome == "Settlement") %>%
  ggplot(aes(x = time, y = prob, color = group)) +
  geom_step(linewidth = 1) +
  scale_x_continuous(limits = c(0, 6), breaks = 0:6) +
  scale_y_continuous(limits = c(0, 0.30), labels = percent_format(accuracy = 1)) +
  scale_color_brewer(palette = "Set1") +
  guides(color = guide_legend(nrow = 2, byrow = TRUE)) +
  labs(
    title    = "Cumulative Incidence of Settlement by Circuit",
    subtitle = "Top 4 circuits by case volume",
    x        = "Years Since Filing",
    y        = "Cumulative Probability of Settlement",
    color    = "Circuit",
    caption  = "Source: FJC Integrated Database, 1990-2024."
  ) +
  theme(
    plot.caption = element_text(size = 9, color = "gray50", hjust = 0)
  )

save_figure(fig_circ_s, "fig_cif_circuit_settlement", width = 9)


# =============================================================================
# DONE
# =============================================================================
cat("\n=================================================================\n")
cat(" 02_descriptives.R COMPLETE\n")
cat("=================================================================\n")
cat("Figures saved to output/figures/:\n")
cat("  fig_km_overall.{pdf,png}\n")
cat("  fig_cif_overall.{pdf,png}\n")
cat("  fig_cif_pslra.{pdf,png}\n")
cat("  fig_cif_circuit_dismissal.{pdf,png}\n")
cat("  fig_cif_circuit_settlement.{pdf,png}\n")

print_session()
