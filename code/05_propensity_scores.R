# ============================================================
# Script: 05_propensity_scores.R
# Purpose: IPTW kill-switch diagnostics — propensity score model,
#          overlap assessment, effective sample size, positivity check.
#          Does NOT fit weighted Cox models (that decision depends on
#          the diagnostics produced here).
# Input: data/cleaned/securities_cohort_cleaned.rds
# Output: output/figures/fig_ps_overlap.{pdf,png}
#         Console: ESS, positivity violations, balance summary
# Dependencies: survival, tidyverse, here, WeightIt, cobalt
# Seed: N/A (deterministic — logistic regression)
# ============================================================

source("code/utils.R")

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

# --- Hardened logic (synced with 05_causal_iptw.R) ---
# Collapse origin_cat == "Removed" into "Other": only 1 pre-PSLRA "Removed"
# case causes near-complete separation in the propensity model.
df_ext <- df_ext %>%
  mutate(origin_cat = forcats::fct_recode(origin_cat, Other = "Removed"))
cat(sprintf("  Collapsed origin_cat 'Removed' into 'Other' (1 pre-PSLRA case)\n"))

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
ps_formula <- post_pslra ~ circuit_f + origin_cat + juris_fq + stat_basis_f

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
    subtitle = "Mirror density plot | Good overlap requires substantial distribution overlap",
    x = "Estimated Propensity Score P(Post-PSLRA | X)",
    y = "Density",
    fill = NULL
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
    att_weight = ifelse(post_pslra == 1, 1, ps / (1 - ps))
  )

cat("\n--- ATT Weight Distribution ---\n")
cat("\nPost-PSLRA (all weight = 1):\n")
cat(sprintf("  n = %d, sum(w) = %.1f\n",
            sum(df_ext$post_pslra == 1), sum(df_ext$att_weight[df_ext$post_pslra == 1])))

cat("\nPre-PSLRA (reweighted):\n")
w_pre <- df_ext$att_weight[df_ext$post_pslra == 0]
cat(sprintf("  n = %d\n", length(w_pre)))
cat(sprintf("  Weight summary:\n"))
print(summary(w_pre))
cat(sprintf("  sum(w) = %.1f\n", sum(w_pre)))
cat(sprintf("  sd(w)  = %.4f\n", sd(w_pre)))

# Effective sample size for the control group
# ESS = (sum(w))^2 / sum(w^2)
ess_pre <- sum(w_pre)^2 / sum(w_pre^2)
ess_post <- sum(df_ext$post_pslra == 1)  # trivially n_post (all weights = 1)
ess_total <- ess_pre + ess_post

cat("\n--- Effective Sample Size (ESS) ---\n")
cat(sprintf("  Pre-PSLRA:  ESS = %.1f  (of %d original, %.1f%% retained)\n",
            ess_pre, length(w_pre), 100 * ess_pre / length(w_pre)))
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
cat("POSITIVITY CHECK: Extreme Propensity Scores\n")
cat("-----------------------------------------------------------------\n")

# Cases with near-certain classification (PS < 0.01 or > 0.99)
n_low  <- sum(df_ext$ps < 0.01)
n_high <- sum(df_ext$ps > 0.99)
n_extreme <- n_low + n_high

cat(sprintf("\n  PS < 0.01:  %d cases (%.2f%%)\n", n_low, 100 * n_low / nrow(df_ext)))
cat(sprintf("  PS > 0.99:  %d cases (%.2f%%)\n", n_high, 100 * n_high / nrow(df_ext)))
cat(sprintf("  Total extreme: %d cases (%.2f%%)\n", n_extreme, 100 * n_extreme / nrow(df_ext)))

# Wider thresholds
n_low5  <- sum(df_ext$ps < 0.05)
n_high95 <- sum(df_ext$ps > 0.95)
cat(sprintf("\n  PS < 0.05:  %d cases (%.2f%%)\n", n_low5, 100 * n_low5 / nrow(df_ext)))
cat(sprintf("  PS > 0.95:  %d cases (%.2f%%)\n", n_high95, 100 * n_high95 / nrow(df_ext)))

# Cross-tab: extreme PS by treatment group
cat("\n  Extreme PS by group:\n")
cat(sprintf("    Pre-PSLRA  with PS < 0.05:  %d of %d (%.1f%%)\n",
            sum(df_ext$ps[df_ext$post_pslra == 0] < 0.05),
            sum(df_ext$post_pslra == 0),
            100 * mean(df_ext$ps[df_ext$post_pslra == 0] < 0.05)))
cat(sprintf("    Post-PSLRA with PS > 0.95:  %d of %d (%.1f%%)\n",
            sum(df_ext$ps[df_ext$post_pslra == 1] > 0.95),
            sum(df_ext$post_pslra == 1),
            100 * mean(df_ext$ps[df_ext$post_pslra == 1] > 0.95)))

# Weight truncation analysis: what if we trim at 99th percentile?
w99 <- quantile(w_pre, 0.99)
w_pre_trimmed <- pmin(w_pre, w99)
ess_trimmed <- sum(w_pre_trimmed)^2 / sum(w_pre_trimmed^2)

cat(sprintf("\n--- Trimming Sensitivity (99th percentile cap at %.2f) ---\n", w99))
cat(sprintf("  Pre-PSLRA ESS after trimming: %.1f (was %.1f)\n", ess_trimmed, ess_pre))

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

POSITIVITY VIOLATIONS
  PS < 0.01: %d cases (%.2f%%)
  PS > 0.99: %d cases (%.2f%%)
  PS < 0.05: %d cases  |  PS > 0.95: %d cases

EFFECTIVE SAMPLE SIZE (ATT weights)
  Pre-PSLRA ESS: %.1f of %d (%.1f%% efficiency)
  Pre-PSLRA ESS (99th pctl trimmed): %.1f

DECISION CRITERIA
  PROCEED if: ESS > 300, overlap visible, no massive positivity holes
  CAUTION if: 100 < ESS < 300 or >5%% extreme PS
  KILL if:    ESS < 100, no overlap, or >20%% positivity violations
=================================================================\n",
  format(nrow(df_ext), big.mark = ","),
  sum(df_ext$post_pslra == 0), sum(df_ext$post_pslra == 1),
  min(df_ext$ps[df_ext$post_pslra == 0]), max(df_ext$ps[df_ext$post_pslra == 0]),
  min(df_ext$ps[df_ext$post_pslra == 1]), max(df_ext$ps[df_ext$post_pslra == 1]),
  n_low, 100 * n_low / nrow(df_ext),
  n_high, 100 * n_high / nrow(df_ext),
  n_low5, n_high95,
  ess_pre, length(w_pre), 100 * ess_pre / length(w_pre),
  ess_trimmed
))

# --- Session Info ---
print_session()
