# ============================================================
# Script: utils.R
# Purpose: Shared helper functions and configuration for all analysis scripts
# Usage: source this file via a script-path resolver at the top of each script
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
theme_thesis <- theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", size = 16),
    plot.subtitle = element_text(size = 13, color = "grey40"),
    axis.title = element_text(size = 14),
    axis.text = element_text(size = 12),
    legend.position = "bottom",
    legend.title = element_text(size = 13),
    legend.text = element_text(size = 12),
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold", size = 13)
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
# Simplified Scheme A event coding helper.
# This mirrors the CURRENT Scheme A logic for one-row-at-a-time inspection only.
# The authoritative implementation remains code/01_clean.R::code_events(), which
# also handles Schemes B/C and operates on full data frames.
# Source: FJC IDB Codebook (docs/fjc_codebook.md)
# NOTE: Schemes B and C reclassify codes 12 and 5 — see code/01_clean.R::code_events()
code_event <- function(disposition, judgment = NA_integer_) {
  case_when(
    disposition == 13                                           ~ 1L,  # Settlement
    disposition %in% c(4, 6, 15, 17, 19, 20) & judgment == 1    ~ 1L,  # Plaintiff judgment
    disposition %in% c(2, 3, 12, 14)                            ~ 2L,  # Dismissal
    disposition %in% c(4, 6, 15, 17, 19, 20) & judgment == 2    ~ 2L,  # Defendant judgment
    disposition == 18                                            ~ 0L,  # Statistical closing
    TRUE                                                         ~ 0L   # Censored/other
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
  coef_names <- rownames(s$coefficients)
  if (!(coef_name %in% coef_names)) {
    stop(sprintf("Coefficient '%s' not found in model.", coef_name))
  }
  
  # Handle standard/robust coxph vs coxme (frailty) objects
  if (inherits(model, "coxme")) {
    idx <- which(coef_names == coef_name)
    hr <- exp(s$coefficients[idx, "coef"])
    # coxme doesn't have a native confint method, compute manually using SE
    se <- s$coefficients[idx, "se(coef)"]
    ci_lo <- exp(s$coefficients[idx, "coef"] - 1.96 * se)
    ci_hi <- exp(s$coefficients[idx, "coef"] + 1.96 * se)
    p <- s$coefficients[idx, "p"]
  } else {
    idx <- which(coef_names == coef_name)
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
