# ============================================================
# Script: 05_propensity_scores.R
# Purpose: IPTW kill-switch diagnostics — propensity score model,
#          overlap assessment, effective sample size, positivity check.
#          Does NOT fit weighted Cox models (that decision depends on
#          the diagnostics produced here).
# Input: data/cleaned/securities_cohort_cleaned.rds
# Output: output/figures/fig_ps_overlap.{pdf,png}
#         Console: trimmed ESS, extreme-weight positivity, balance summary
# Dependencies: survival, tidyverse, here, WeightIt, cobalt
# Seed: N/A (deterministic — logistic regression)
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
cat(" 05_propensity_scores.R — IPTW KILL-SWITCH DIAGNOSTICS\n")
cat("=================================================================\n\n")

# =============================================================================
# LOAD & PREPARE DATA (mirrors 03_cox_models.R pipeline)
# =============================================================================
cat("Loading cleaned data...\n")
df <- readRDS(here::here("data", "cleaned", "securities_cohort_cleaned.rds"))
cat(sprintf("  Full sample: %s rows\n", format(nrow(df), big.mark = ",")))

# --- Replicate 03_cox_models.R data preparation ---
# Circuits with >= 50 cases
circuit_counts <- df %>% count(circuit, sort = TRUE)
circuits_incl  <- circuit_counts %>% filter(n >= 50) %>% pull(circuit)
cat(sprintf("  Circuits with >= 50 cases: %d of %d\n",
            length(circuits_incl), n_distinct(df$circuit)))

df_circ <- df %>%
  filter(circuit %in% circuits_incl) %>%
  mutate(circuit_f = relevel(factor(circuit), ref = "2"))

# Extended dataset: complete cases on core covariates
stat_coverage <- 100 * mean(!is.na(df$stat_basis_f))
include_stat  <- stat_coverage >= 15

df_ext <- df_circ %>%
  filter(!is.na(origin_cat), !is.na(mdl_flag), !is.na(juris_fq))

if (include_stat) {
  df_ext <- df_ext %>%
    mutate(stat_basis_f = forcats::fct_na_value_to_level(stat_basis_f, level = "Missing"))
}

cat(sprintf("  Analysis sample (df_ext): %s rows\n", format(nrow(df_ext), big.mark = ",")))
cat(sprintf("  Pre-PSLRA: %d  |  Post-PSLRA: %d  |  Ratio: %.1f:1\n",
            sum(df_ext$post_pslra == 0), sum(df_ext$post_pslra == 1),
            sum(df_ext$post_pslra == 1) / sum(df_ext$post_pslra == 0)))

# =============================================================================
# SECTION 1: PROPENSITY SCORE MODEL
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("PROPENSITY SCORE MODEL: P(post_pslra = 1 | X)\n")
cat("-----------------------------------------------------------------\n")

# Covariates: same as 05_causal_iptw.R (minus post_pslra itself).
# mdl_flag excluded: zero pre-PSLRA cases have mdl_flag == 1, producing
# perfect separation (coef → ±∞). This is a data limitation (IDB did not
# code MDL consolidation pre-PSLRA), not a modeling choice.
if (include_stat) {
  ps_formula <- post_pslra ~ circuit_f + origin_cat + juris_fq + stat_basis_f
} else {
  ps_formula <- post_pslra ~ circuit_f + origin_cat + juris_fq
}

ps_model <- glm(ps_formula, data = df_ext, family = binomial(link = "logit"))

cat("\nPropensity Score Model Summary:\n")
print(summary(ps_model))

# Extract propensity scores
df_ext$ps <- predict(ps_model, type = "response")

cat("\n--- Propensity Score Distribution ---\n")
cat("\nOverall:\n")
print(summary(df_ext$ps))

cat("\nPre-PSLRA (control):\n")
print(summary(df_ext$ps[df_ext$post_pslra == 0]))

cat("\nPost-PSLRA (treated):\n")
print(summary(df_ext$ps[df_ext$post_pslra == 1]))

# =============================================================================
# SECTION 2: MIRROR DENSITY PLOT (OVERLAP ASSESSMENT)
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("OVERLAP ASSESSMENT: Mirror Density Plot\n")
cat("-----------------------------------------------------------------\n")

# Compute densities manually for mirroring
dens_pre  <- density(df_ext$ps[df_ext$post_pslra == 0], from = 0, to = 1, n = 512)
dens_post <- density(df_ext$ps[df_ext$post_pslra == 1], from = 0, to = 1, n = 512)

n_pre_label  <- sprintf("Pre-PSLRA (n = %s)", format(sum(df_ext$post_pslra == 0), big.mark = ","))
n_post_label <- sprintf("Post-PSLRA (n = %s)", format(sum(df_ext$post_pslra == 1), big.mark = ","))

dens_df <- bind_rows(
  tibble(ps = dens_post$x, density =  dens_post$y, group = n_post_label),
  tibble(ps = dens_pre$x,  density = -dens_pre$y,  group = n_pre_label)
)

# Max density for symmetric y-axis
y_max <- max(abs(dens_df$density)) * 1.1

# Named color vector
fill_colors <- setNames(c("#984EA3", "#4DAF4A"), c(n_post_label, n_pre_label))

p_overlap <- ggplot(dens_df, aes(x = ps, y = density, fill = group)) +
  geom_area(alpha = 0.6) +
  geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
  scale_fill_manual(values = fill_colors) +
  scale_y_continuous(
    labels = function(x) format(abs(x), big.mark = ","),
    limits = c(-y_max, y_max)
  ) +
  labs(
    title = "Propensity Score Overlap: Pre- vs. Post-PSLRA Cases",
    x     = "Estimated Propensity Score P(Post-PSLRA | X)",
    y     = "Density",
    fill  = NULL
  ) +
  theme(legend.position = "bottom")

save_figure(p_overlap, "fig_ps_overlap", width = 8, height = 5)

# =============================================================================
# SECTION 3: ATT WEIGHTS AND EFFECTIVE SAMPLE SIZE
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("ATT WEIGHTS AND EFFECTIVE SAMPLE SIZE\n")
cat("-----------------------------------------------------------------\n")

# ATT weights (Average Treatment Effect on the Treated):
#   Treated (post_pslra = 1): w = 1
#   Control (post_pslra = 0): w = ps / (1 - ps)
# This reweights pre-PSLRA to look like post-PSLRA on observables.

df_ext <- df_ext %>%
  mutate(
    att_weight_raw = ifelse(post_pslra == 1, 1, ps / (1 - ps))
  )

w_pre_raw <- df_ext$att_weight_raw[df_ext$post_pslra == 0]
trim_cap <- quantile(w_pre_raw, 0.99)

df_ext <- df_ext %>%
  mutate(att_weight = ifelse(post_pslra == 1, 1, pmin(att_weight_raw, trim_cap)))

cat("\n--- ATT Weight Distribution ---\n")
cat("\nPost-PSLRA (all weight = 1):\n")
cat(sprintf("  n = %d, sum(w) = %.1f\n",
            sum(df_ext$post_pslra == 1), sum(df_ext$att_weight[df_ext$post_pslra == 1])))

cat("\nPre-PSLRA raw ATT weights:\n")
cat(sprintf("  n = %d\n", length(w_pre_raw)))
cat(sprintf("  Weight summary:\n"))
print(summary(w_pre_raw))
cat(sprintf("  sum(w) = %.1f\n", sum(w_pre_raw)))
cat(sprintf("  sd(w)  = %.4f\n", sd(w_pre_raw)))

w_pre <- df_ext$att_weight[df_ext$post_pslra == 0]
n_trimmed <- sum(w_pre_raw > trim_cap)
pct_trimmed <- 100 * n_trimmed / length(w_pre_raw)

cat(sprintf("\nPre-PSLRA 99th-pctl trimmed ATT weights (cap = %.2f):\n", trim_cap))
cat(sprintf("  Controls trimmed at cap: %d of %d (%.2f%%)\n",
            n_trimmed, length(w_pre_raw), pct_trimmed))
cat(sprintf("  Weight summary:\n"))
print(summary(w_pre))
cat(sprintf("  sum(w) = %.1f\n", sum(w_pre)))
cat(sprintf("  sd(w)  = %.4f\n", sd(w_pre)))

# Effective sample size for the control group
# ESS = (sum(w))^2 / sum(w^2)
ess_pre_raw <- sum(w_pre_raw)^2 / sum(w_pre_raw^2)
ess_pre <- sum(w_pre)^2 / sum(w_pre^2)
ess_post <- sum(df_ext$post_pslra == 1)  # trivially n_post (all weights = 1)
ess_total <- ess_pre + ess_post

cat("\n--- Effective Sample Size (ESS) ---\n")
cat(sprintf("  Pre-PSLRA (99th-pctl trimmed ATT): ESS = %.1f  (of %d original, %.1f%% retained)\n",
            ess_pre, length(w_pre), 100 * ess_pre / length(w_pre)))
cat(sprintf("  Pre-PSLRA (raw ATT):              ESS = %.1f\n", ess_pre_raw))
cat(sprintf("  Post-PSLRA: ESS = %.1f  (all weight = 1)\n", ess_post))
cat(sprintf("  Total:      ESS = %.1f  (of %d original)\n", ess_total, nrow(df_ext)))

# Flag if ESS is critically low
if (ess_pre < 100) {
  cat("\n  *** WARNING: Pre-PSLRA ESS < 100. IPTW results will be unreliable. ***\n")
} else if (ess_pre < 300) {
  cat("\n  ** CAUTION: Pre-PSLRA ESS < 300. Results should be interpreted carefully. **\n")
} else {
  cat("\n  ESS looks reasonable for inference.\n")
}

# =============================================================================
# SECTION 4: POSITIVITY CHECK
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("POSITIVITY CHECK: Extreme ATT Weights After 99th-pctl Trimming\n")
cat("-----------------------------------------------------------------\n")

max_weight_trimmed <- max(w_pre)

cat(sprintf("\n  Control trim cap (99th percentile): %.2f\n", trim_cap))
cat(sprintf("  Controls trimmed at cap: %d of %d (%.2f%%)\n",
            n_trimmed, length(w_pre_raw), pct_trimmed))
cat(sprintf("  Max control weight after trimming: %.2f\n", max_weight_trimmed))
cat(sprintf("  95th percentile control weight after trimming: %.2f\n",
            unname(quantile(w_pre, 0.95))))
cat(sprintf("  99th percentile control weight after trimming: %.2f\n",
            unname(quantile(w_pre, 0.99))))
cat(sprintf("\n  Pre-PSLRA ESS after trimming: %.1f (was %.1f before trimming)\n",
            ess_pre, ess_pre_raw))

# =============================================================================
# SECTION 5: COVARIATE BALANCE (pre-weighting vs post-weighting)
# =============================================================================
cat("\n-----------------------------------------------------------------\n")
cat("COVARIATE BALANCE (Standardized Mean Differences)\n")
cat("-----------------------------------------------------------------\n")

# Use WeightIt + cobalt for proper balance diagnostics
w_out <- weightit(
  ps_formula,
  data = df_ext,
  method = "glm",
  estimand = "ATT"
)
w_out$weights[df_ext$post_pslra == 0] <- pmin(
  w_out$weights[df_ext$post_pslra == 0],
  trim_cap
)
if (!isTRUE(all.equal(unname(df_ext$att_weight), unname(w_out$weights), tolerance = 1e-10))) {
  stop("Manual ATT weights do not match trimmed WeightIt weights.")
}
cat("\nVerified: manual ATT weights match trimmed WeightIt weights.\n")

cat("\nWeightIt summary:\n")
print(summary(w_out))

cat("\nBalance table (SMD < 0.1 is acceptable):\n")
bt <- bal.tab(w_out, stats = c("m", "v"), thresholds = c(m = 0.1))
print(bt)

# =============================================================================
# SECTION 6: SUMMARY FOR KILL-SWITCH DECISION
# =============================================================================
cat("\n=================================================================\n")
cat(" KILL-SWITCH SUMMARY\n")
cat("=================================================================\n")
cat(sprintf("
PROPENSITY SCORE MODEL
  Covariates: circuit, origin, jurisdiction, statutory basis (mdl_flag excluded: perfect separation)
  Analysis sample: %s cases (%d pre / %d post)

OVERLAP
  Pre-PSLRA PS range:  [%.4f, %.4f]
  Post-PSLRA PS range: [%.4f, %.4f]

POSITIVITY / EXTREME WEIGHTS
  99th-pctl trim cap: %.2f
  Controls trimmed at cap: %d of %d (%.2f%%)
  Max trimmed control weight: %.2f

EFFECTIVE SAMPLE SIZE (99th-pctl trimmed ATT weights)
  Pre-PSLRA ESS: %.1f of %d (%.1f%% efficiency)
  Pre-PSLRA ESS before trimming: %.1f

DECISION CRITERIA
  PROCEED if: ESS > 300, overlap visible, limited trimming
  CAUTION if: 100 < ESS < 300 or >5%% controls hit the trim cap
  KILL if:    ESS < 100, no overlap, or >20%% controls hit the trim cap
=================================================================\n",
  format(nrow(df_ext), big.mark = ","),
  sum(df_ext$post_pslra == 0), sum(df_ext$post_pslra == 1),
  min(df_ext$ps[df_ext$post_pslra == 0]), max(df_ext$ps[df_ext$post_pslra == 0]),
  min(df_ext$ps[df_ext$post_pslra == 1]), max(df_ext$ps[df_ext$post_pslra == 1]),
  trim_cap,
  n_trimmed, length(w_pre_raw), pct_trimmed,
  max_weight_trimmed,
  ess_pre, length(w_pre), 100 * ess_pre / length(w_pre),
  ess_pre_raw
))

# --- Session Info ---
print_session()
