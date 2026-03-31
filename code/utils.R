# ============================================================
# Script: utils.R
# Purpose: Shared helper functions and configuration for all analysis scripts
# Usage: source("code/utils.R") at the top of every script
# ============================================================

# --- Package Loading ---
required_packages <- c(
  "survival", "cmprsk", "tidycmprsk", 
  "ggsurvfit", "tidyverse", "kableExtra", "xtable",
  "here", "scales", "patchwork",
  "coxme", "WeightIt", "cobalt"  # <-- The New Causal Stack
)

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message(sprintf("Package '%s' not installed. Install with: install.packages('%s')", pkg, pkg))
  }
  library(pkg, character.only = TRUE)
}

# --- Consistent Theme ---
theme_thesis <- theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "grey40"),
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 10),
    legend.position = "bottom",
    legend.title = element_text(size = 11),
    legend.text = element_text(size = 10),
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold", size = 11)
  )
theme_set(theme_thesis)

# --- Color Palette ---
# Consistent across all figures
thesis_colors <- c(
  "Settlement" = "#2166AC",   # blue
  "Dismissal"  = "#B2182B",   # red
  "Censored"   = "#999999",   # grey
  "Pre-PSLRA"  = "#4DAF4A",   # green
  "Post-PSLRA" = "#984EA3"    # purple
)

# Circuit colors (for when needed)
circuit_colors <- scales::hue_pal()(13)
names(circuit_colors) <- c(paste0("Circuit ", 1:11), "DC", "Federal")

# --- Output Helpers ---
save_figure <- function(plot, filename, width = 8, height = 6, dpi = 300) {
  # Save as both PDF (for thesis) and PNG (for preview)
  ggsave(
    filename = here::here("output", "figures", paste0(filename, ".pdf")),
    plot = plot, width = width, height = height, device = "pdf"
  )
  ggsave(
    filename = here::here("output", "figures", paste0(filename, ".png")),
    plot = plot, width = width, height = height, dpi = dpi, device = "png"
  )
  message(sprintf("Saved: output/figures/%s.{pdf,png}", filename))
}

save_table <- function(tbl, filename, caption = "", label = "") {
  writeLines(tbl, here::here("output", "tables", paste0(filename, ".tex")))
  message(sprintf("Saved: output/tables/%s.tex", filename))
}

# --- Data Helpers ---
# Standard event coding (Scheme A — primary analysis)
# Source: FJC IDB Codebook (docs/fjc_codebook.md)
#   Settlement: Code 13 (settlement)
#   Dismissal:  Codes 2 (want of prosecution), 3 (lack of jurisdiction),
#               4 (default judgment), 6 (judgment on motion), 12 (voluntary),
#               14 (other dismissal), 15 (award of arbitrator),
#               17 (other judgment), 18 (statistical closing), 19 (appeal affirmed, magistrate)
#   Censored:   Everything else (transfers, remands, pending)
# NOTE: Schemes B and C reclassify codes 12 and 5 — see code/01_clean.R::code_events()
code_event <- function(disposition) {
  case_when(
    disposition == 13                                     ~ 1L,  # Settlement
    disposition %in% c(2, 3, 4, 6, 12, 14, 15, 17, 18, 19) ~ 2L,  # Dismissal
    TRUE                                                  ~ 0L   # Censored/other
  )
}

# Duration in years
compute_duration <- function(filing_date, termination_date) {
  as.numeric(difftime(termination_date, filing_date, units = "days")) / 365.25
}

# --- Reporting Helpers ---
format_hr <- function(model, coef_name, digits = 2) {
  # Extract hazard ratio with CI and p-value for prose
  s <- summary(model)
  
  # Handle standard/robust coxph vs coxme (frailty) objects
  if (inherits(model, "coxme")) {
    idx <- which(rownames(s$coefficients) == coef_name)
    hr <- exp(s$coefficients[idx, "coef"])
    # coxme doesn't have a native confint method, compute manually using SE
    se <- s$coefficients[idx, "se(coef)"]
    ci_lo <- exp(s$coefficients[idx, "coef"] - 1.96 * se)
    ci_hi <- exp(s$coefficients[idx, "coef"] + 1.96 * se)
    p <- s$coefficients[idx, "p"]
  } else {
    idx <- which(rownames(s$coefficients) == coef_name)
    hr <- exp(s$coefficients[idx, "coef"])
    ci_lo <- exp(confint(model)[idx, 1])
    ci_hi <- exp(confint(model)[idx, 2])
    # Extract p-value (handles robust SE column shifting)
    p_col <- grep("^Pr\\(", colnames(s$coefficients), value = TRUE)[1]
    p <- s$coefficients[idx, p_col]
  }
  
  p_str <- if (p < 0.001) "$p < 0.001$" else sprintf("$p = %.3f$", p)
  
  sprintf(
    "$\\text{HR} = %.*f$, 95\\%% CI: %.*f--%.*f, %s",
    digits, hr, digits, ci_lo, digits, ci_hi, p_str
  )
}

# --- Session Info ---
print_session <- function() {
  message("\n--- Session Info ---")
  print(sessionInfo())
}
