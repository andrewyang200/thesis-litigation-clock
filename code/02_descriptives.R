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
  est <- cif_obj[[key]]$est
  v   <- cif_obj[[key]]$var
  tibble(
    time    = cif_obj[[key]]$time,
    prob    = est,
    lower   = pmax(0, est - 1.96 * sqrt(v)),
    upper   = pmin(1, est + 1.96 * sqrt(v)),
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
    title = "Duration of Federal Securities Class Actions",
    x     = "Years Since Filing",
    y     = "Proportion Pending (Unresolved)"
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
  tibble(time    = cif_overall$`1 1`$time,
         prob    = cif_overall$`1 1`$est,
         lower   = pmax(0, cif_overall$`1 1`$est - 1.96 * sqrt(cif_overall$`1 1`$var)),
         upper   = pmin(1, cif_overall$`1 1`$est + 1.96 * sqrt(cif_overall$`1 1`$var)),
         outcome = "Settlement"),
  tibble(time    = cif_overall$`1 2`$time,
         prob    = cif_overall$`1 2`$est,
         lower   = pmax(0, cif_overall$`1 2`$est - 1.96 * sqrt(cif_overall$`1 2`$var)),
         upper   = pmin(1, cif_overall$`1 2`$est + 1.96 * sqrt(cif_overall$`1 2`$var)),
         outcome = "Dismissal")
)

fig_cif <- ggplot(cif_overall_df, aes(x = time, y = prob, color = outcome)) +
  geom_ribbon(aes(ymin = lower, ymax = upper, fill = outcome),
              alpha = 0.15, color = NA, show.legend = FALSE) +
  geom_step(linewidth = 1.2) +
  scale_x_continuous(limits = c(0, 8), breaks = seq(0, 8, 2)) +
  scale_y_continuous(limits = c(0, 1), labels = percent_format(accuracy = 1)) +
  scale_color_manual(values = thesis_colors[c("Settlement", "Dismissal")]) +
  scale_fill_manual(values = thesis_colors[c("Settlement", "Dismissal")]) +
  labs(
    title = "Cumulative Incidence of Settlement vs. Dismissal",
    x     = "Years Since Filing",
    y     = "Cumulative Probability",
    color = "Outcome"
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
  mutate(series = paste(group, outcome, sep = " - "))

pslra_colors <- c(
  "Pre-PSLRA - Settlement"  = "#2166AC",
  "Pre-PSLRA - Dismissal"   = "#B2182B",
  "Post-PSLRA - Settlement" = "#67A9CF",
  "Post-PSLRA - Dismissal"  = "#EF8A62"
)

fig_pslra <- ggplot(cif_pslra_df,
                     aes(x = time, y = prob, color = series, linetype = series)) +
  geom_ribbon(aes(ymin = lower, ymax = upper, fill = series),
              alpha = 0.12, color = NA, show.legend = FALSE) +
  geom_step(linewidth = 1) +
  scale_x_continuous(limits = c(0, 8), breaks = seq(0, 8, 2)) +
  scale_y_continuous(limits = c(0, 1), labels = percent_format(accuracy = 1)) +
  scale_color_manual(values = pslra_colors) +
  scale_fill_manual(values = pslra_colors) +
  scale_linetype_manual(values = c(
    "Pre-PSLRA - Settlement"  = "solid",
    "Pre-PSLRA - Dismissal"   = "solid",
    "Post-PSLRA - Settlement" = "dashed",
    "Post-PSLRA - Dismissal"  = "dashed"
  )) +
  guides(
    color    = guide_legend(nrow = 2, byrow = TRUE),
    linetype = guide_legend(nrow = 2, byrow = TRUE)
  ) +
  labs(
    title    = "Cumulative Incidence by PSLRA Regime",
    x        = "Years Since Filing",
    y        = "Cumulative Probability",
    color    = NULL, linetype = NULL
  ) +
  theme(
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
# FIGURES 4-5: CIF BY CIRCUIT (Top 4 by volume + Sixth Circuit)
# =============================================================================
cat("\nFigures 4-5: CIF by circuit (top 4 + Sixth)...\n")

# Top 4 by case volume + Sixth Circuit (highest settlement rate at ~37%,
# analytically important for the settlement story despite smaller N=361)
circuit_counts <- df %>% count(circuit, sort = TRUE)
top_circuits   <- unique(c(
  circuit_counts %>% head(4) %>% pull(circuit),
  6  # Sixth Circuit
))

df_circ <- df %>%
  filter(circuit %in% top_circuits) %>%
  mutate(circuit_name = case_when(
    circuit == 2 ~ "Second (NYC)",
    circuit == 9 ~ "Ninth (CA)",
    circuit == 3 ~ "Third (PA/NJ/DE)",
    circuit == 5 ~ "Fifth (TX/LA)",
    circuit == 6 ~ "Sixth (OH/MI/KY/TN)",
    TRUE         ~ paste("Circuit", circuit)
  ))

cif_circuit <- cmprsk::cuminc(
  ftime   = df_circ$duration_years,
  fstatus = df_circ$event_type,
  group   = df_circ$circuit_name,
  cencode = 0
)

cat("\nGray's test for equality of CIF across selected circuits:\n")
print(cif_circuit$Tests)

circuit_names  <- unique(df_circ$circuit_name)
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
  geom_ribbon(aes(ymin = lower, ymax = upper, fill = group),
              alpha = 0.10, color = NA, show.legend = FALSE) +
  geom_step(linewidth = 1) +
  scale_x_continuous(limits = c(0, 6), breaks = 0:6) +
  scale_y_continuous(limits = c(0, 1), labels = percent_format(accuracy = 1)) +
  scale_color_brewer(palette = "Set1") +
  scale_fill_brewer(palette = "Set1") +
  guides(color = guide_legend(nrow = 2, byrow = TRUE)) +
  labs(
    title = "Cumulative Incidence of Dismissal by Circuit",
    x     = "Years Since Filing",
    y     = "Cumulative Probability of Dismissal",
    color = "Circuit"
  )

save_figure(fig_circ_d, "fig_cif_circuit_dismissal", width = 9)

# Figure 5: Settlement by circuit
fig_circ_s <- cif_circuit_df %>%
  filter(outcome == "Settlement") %>%
  ggplot(aes(x = time, y = prob, color = group)) +
  geom_ribbon(aes(ymin = lower, ymax = upper, fill = group),
              alpha = 0.10, color = NA, show.legend = FALSE) +
  geom_step(linewidth = 1) +
  scale_x_continuous(limits = c(0, 6), breaks = 0:6) +
  scale_y_continuous(limits = c(0, 0.45), breaks = seq(0, 0.45, 0.05),
                     labels = percent_format(accuracy = 1)) +
  scale_color_brewer(palette = "Set1") +
  scale_fill_brewer(palette = "Set1") +
  guides(color = guide_legend(nrow = 2, byrow = TRUE)) +
  labs(
    title = "Cumulative Incidence of Settlement by Circuit",
    x     = "Years Since Filing",
    y     = "Cumulative Probability of Settlement",
    color = "Circuit"
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
