# ============================================================
# Script: extract_all_numbers.R
# Purpose: Read-only extraction of ALL authoritative numbers
#          from the April 7, 2026 pipeline outputs.
#          Every number in docs/authoritative-numbers.md must
#          be reproducible from a single run of this script.
# Input:   data/cleaned/*.rds, output/models/*.rds,
#          output/tables/tab_model_performance.tex
# Output:  Console only (stdout)
# ============================================================

suppressPackageStartupMessages({
  library(survival)
  library(here)
  library(dplyr)
  library(forcats)
  library(cmprsk)
  library(coxme)
  library(cobalt)
})

cat("================================================================\n")
cat(" AUTHORITATIVE NUMBER EXTRACTION — 2026-04-07 Pipeline\n")
cat("================================================================\n\n")

# ------------------------------------------------------------------
# SECTION 0: LOAD DATA AND MODEL OBJECTS + BUILD EXTENDED SAMPLE
# ------------------------------------------------------------------
df <- readRDS(here("data", "cleaned", "securities_cohort_cleaned.rds"))
cox <- readRDS(here("output", "models", "cox_models.rds"))
iptw <- readRDS(here("output", "models", "iptw_results.rds"))
frailty_obj <- readRDS(here("output", "models", "frailty_results.rds"))
robust <- readRDS(here("output", "models", "robustness_results.rds"))

# Fine-Gray .rds may have been cleaned up; flag for later refit
fg_path <- here("output", "models", "fine_gray_models.rds")
has_fg <- file.exists(fg_path)
if (has_fg) {
  fg <- readRDS(fg_path)
  cat("  fine_gray_models.rds loaded.\n")
} else {
  cat("  fine_gray_models.rds NOT FOUND — will refit in Section 5.\n")
}

# Replicate the exact data-prep from 03_cox_models.R so that
# cox.zph() and other refit-dependent extractions work correctly.
circuits_incl <- c("1","2","3","4","5","6","7","8","9","10","11")
df_circ <- df %>%
  filter(circuit %in% circuits_incl) %>%
  mutate(circuit_f = relevel(factor(circuit), ref = "2"))

df_ext <- df_circ %>%
  filter(!is.na(origin_cat), !is.na(mdl_flag), !is.na(juris_fq)) %>%
  mutate(stat_basis_f = fct_na_value_to_level(stat_basis_f, level = "Missing"))

ext_rhs <- "post_pslra + circuit_f + origin_cat + mdl_flag + juris_fq + stat_basis_f"

stopifnot(nrow(df_ext) == cox$df_ext_nrow)
cat(sprintf("  df_ext N = %d (matches saved metadata: %s)\n",
            nrow(df_ext), nrow(df_ext) == cox$df_ext_nrow))
cat("All files loaded successfully.\n\n")

# Helper to print model summary. For Fine-Gray models, model$n is the
# finegray-expanded row count rather than the original case count.
print_cox <- function(model, label, n_override = NULL) {
  s <- summary(model)
  coefs <- s$conf.int
  pvals <- s$coefficients[, "Pr(>|z|)", drop = FALSE]
  n_display <- if (is.null(n_override)) model$n else n_override
  cat(sprintf("--- %s (n=%d, events=%d) ---\n", label, n_display, model$nevent))
  for (i in seq_len(nrow(coefs))) {
    nm <- rownames(coefs)[i]
    hr <- coefs[nm, "exp(coef)"]
    lo <- coefs[nm, "lower .95"]
    hi <- coefs[nm, "upper .95"]
    p  <- pvals[nm, 1]
    cat(sprintf("  %-35s HR=%.3f [%.3f, %.3f]  p=%.4g\n", nm, hr, lo, hi, p))
  }
  cat("\n")
}

# ==================================================================
# SECTION 1: DATA CHAPTER NUMBERS
# ==================================================================
cat("================================================================\n")
cat(" SECTION 1: DATA CHAPTER (Chapter 4)\n")
cat("================================================================\n\n")

# --- 1a. Sample Construction ---
cat("--- 1a. Sample Construction ---\n")
cat(sprintf("  Total analysis sample: %d\n", nrow(df)))
cat(sprintf("  NOS 850 before class action filter: 65,899 (hardcoded from pipeline)\n"))
cat(sprintf("  After class action filter: 13,708 (hardcoded from pipeline)\n"))
cat(sprintf("  After valid duration filter: %d\n\n", nrow(df)))

# --- 1b. Scheme A Event Distribution ---
cat("--- 1b. Scheme A Event Distribution ---\n")
scheme_a <- table(df$event_type)
cat(sprintf("  Settlement (event=1): %d (%.1f%%)\n", scheme_a["1"], 100*scheme_a["1"]/nrow(df)))
cat(sprintf("  Dismissal  (event=2): %d (%.1f%%)\n", scheme_a["2"], 100*scheme_a["2"]/nrow(df)))
cat(sprintf("  Censored   (event=0): %d (%.1f%%)\n", scheme_a["0"], 100*scheme_a["0"]/nrow(df)))
cat(sprintf("  Total: %d\n\n", nrow(df)))

# --- 1c. Scheme B and C ---
cat("--- 1c. Schemes B and C ---\n")
df_B <- readRDS(here("data", "cleaned", "securities_scheme_B.rds"))
df_C <- readRDS(here("data", "cleaned", "securities_scheme_C.rds"))
scheme_b <- table(df_B$event_type)
scheme_c <- table(df_C$event_type)
cat(sprintf("  Scheme B: %d settlement / %d dismissal / %d censored (%.1f%% / %.1f%% / %.1f%%)\n",
            scheme_b["1"], scheme_b["2"], scheme_b["0"],
            100*scheme_b["1"]/nrow(df_B), 100*scheme_b["2"]/nrow(df_B), 100*scheme_b["0"]/nrow(df_B)))
cat(sprintf("  Scheme C: %d settlement / %d dismissal / %d censored (%.1f%% / %.1f%% / %.1f%%)\n",
            scheme_c["1"], scheme_c["2"], scheme_c["0"],
            100*scheme_c["1"]/nrow(df_C), 100*scheme_c["2"]/nrow(df_C), 100*scheme_c["0"]/nrow(df_C)))
rm(df_B, df_C)
cat("\n")

# --- 1d. Duration Statistics by Outcome ---
cat("--- 1d. Duration Statistics by Outcome (Scheme A, resolved cases) ---\n")
for (evt in c(1, 2)) {
  lbl <- if (evt == 1) "Settlement" else "Dismissal"
  d <- df$duration_years[df$event_type == evt]
  cat(sprintf("  %s: N=%d, Mean=%.2f, Median=%.2f, Q25=%.2f, Q75=%.2f\n",
              lbl, length(d), mean(d), median(d), quantile(d, 0.25), quantile(d, 0.75)))
}
cat("\n")

# --- 1e. PSLRA Regime Distribution ---
cat("--- 1e. PSLRA Regime Distribution ---\n")
for (era in c(0, 1)) {
  lbl <- if (era == 0) "Pre-PSLRA" else "Post-PSLRA"
  sub <- df[df$post_pslra == era, ]
  tbl <- table(sub$event_type)
  n <- nrow(sub)
  cat(sprintf("  %s: N=%d, Settle=%d (%.1f%%), Dismiss=%d (%.1f%%), Censored=%d (%.1f%%)\n",
              lbl, n, tbl["1"], 100*tbl["1"]/n, tbl["2"], 100*tbl["2"]/n, tbl["0"], 100*tbl["0"]/n))
}
cat("\n")

# --- 1f. Circuit Distribution ---
cat("--- 1f. Circuit Distribution ---\n")
circ_tbl <- sort(table(df$circuit_f), decreasing = TRUE)
for (i in seq_along(circ_tbl)) {
  cat(sprintf("  %s: %d (%.1f%%)\n", names(circ_tbl)[i], circ_tbl[i], 100*circ_tbl[i]/nrow(df)))
}
cat(sprintf("  Total: %d\n\n", sum(circ_tbl)))

# --- 1g. Judgment-Bearing Disposition Disaggregation ---
cat("--- 1g. Judgment-Bearing Disposition Counts ---\n")
jb_codes <- c(4, 6, 15, 17, 19, 20)
jb_rows <- df[df$disp %in% jb_codes, ]
cat(sprintf("  Total judgment-bearing (codes 4,6,15,17,19,20): %d\n", nrow(jb_rows)))
for (code in jb_codes) {
  sub <- jb_rows[jb_rows$disp == code, ]
  if (nrow(sub) > 0) {
    j1 <- sum(sub$judgment == 1, na.rm = TRUE)
    j2 <- sum(sub$judgment == 2, na.rm = TRUE)
    jother <- nrow(sub) - j1 - j2
    cat(sprintf("  Code %2d: N=%4d | J=1(plaintiff):%4d | J=2(defendant):%4d | ambig:%4d\n",
                code, nrow(sub), j1, j2, jother))
  }
}
total_j1 <- sum(jb_rows$judgment == 1, na.rm = TRUE)
total_j2 <- sum(jb_rows$judgment == 2, na.rm = TRUE)
cat(sprintf("  TOTAL: J=1=%d  J=2=%d  ambig=%d\n", total_j1, total_j2, nrow(jb_rows) - total_j1 - total_j2))
# Era breakdown for J=1
j1_pre  <- sum(jb_rows$judgment == 1 & jb_rows$post_pslra == 0, na.rm = TRUE)
j1_post <- sum(jb_rows$judgment == 1 & jb_rows$post_pslra == 1, na.rm = TRUE)
cat(sprintf("  J=1 era: Pre-PSLRA %d (%.1f%%), Post-PSLRA %d (%.1f%%)\n",
            j1_pre, 100*j1_pre/total_j1, j1_post, 100*j1_post/total_j1))

cat("\n--- DISP=18 check ---\n")
d18 <- df[df$disp == 18, ]
cat(sprintf("  DISP=18 cases: %d, all censored: %s\n", nrow(d18), all(d18$event_type == 0)))
cat("\n")

# --- 1h. Origin Category Distribution ---
cat("--- 1h. Origin Category Distribution ---\n")
cat("  Levels:", paste(levels(df$origin_cat), collapse = ", "), "\n")
print(table(df$origin_cat))
cat("\n")

# --- 1i. Statutory Basis Coverage (on extended sample with Missing level) ---
cat(sprintf("--- 1i. Statutory Basis (extended model sample, N=%d) ---\n", nrow(df_ext)))
cat(sprintf("  Levels: %s\n", paste(levels(df_ext$stat_basis_f), collapse = ", ")))
print(table(df_ext$stat_basis_f))
pct_non_missing <- 100 * sum(df_ext$stat_basis_f != "Missing") / nrow(df_ext)
cat(sprintf("  Coverage (non-Missing): %.1f%%\n\n", pct_non_missing))

# ==================================================================
# SECTION 2: COX MODEL NUMBERS (Chapter 5)
# ==================================================================
cat("================================================================\n")
cat(" SECTION 2: COX MODELS\n")
cat("================================================================\n\n")

# --- 2a. Baseline Cox ---
cat("--- 2a. Baseline Cox (PSLRA only) ---\n")
print_cox(cox$cox_s_base, "Settlement Baseline")
print_cox(cox$cox_d_base, "Dismissal Baseline")

# --- 2b. Piecewise Cox ---
cat("--- 2b. Piecewise Cox ---\n")
print_cox(cox$cox_piecewise, "Dismissal Piecewise")
if (!is.null(cox$cox_piecewise_s)) {
  print_cox(cox$cox_piecewise_s, "Settlement Piecewise")
}

# --- 2c. Circuit Cox (PSLRA + circuit) ---
cat("--- 2c. Circuit Cox (PSLRA + circuit) ---\n")
print_cox(cox$cox_s_circ, "Settlement + Circuit")
print_cox(cox$cox_d_circ, "Dismissal + Circuit")

# --- 2d. Extended Cox ---
cat("--- 2d. Extended Cox (full covariates) ---\n")
print_cox(cox$cox_s_ext, "Settlement Extended")
print_cox(cox$cox_d_ext, "Dismissal Extended")

# --- 2e. PH Tests (refit on df_ext to avoid environment issues) ---
cat("--- 2e. Proportional Hazards Tests (Extended Cox, refit on df_ext) ---\n")
refit_s <- coxph(as.formula(paste("Surv(duration_years, event_type == 1) ~", ext_rhs)), data = df_ext)
refit_d <- coxph(as.formula(paste("Surv(duration_years, event_type == 2) ~", ext_rhs)), data = df_ext)

# Verify refit matches saved model
stopifnot(
  abs(coef(refit_s)["post_pslra"] - coef(cox$cox_s_ext)["post_pslra"]) < 1e-6,
  abs(coef(refit_d)["post_pslra"] - coef(cox$cox_d_ext)["post_pslra"]) < 1e-6
)
cat("  Refit coefficients match saved models.\n\n")

cat("  Settlement PH Test:\n")
ph_s <- cox.zph(refit_s)
print(ph_s$table)
cat("\n  Dismissal PH Test:\n")
ph_d <- cox.zph(refit_d)
print(ph_d$table)
cat("\n")

# Also: baseline Cox PH tests (these work on df directly)
cat("--- 2e-bis. Baseline Cox PH Tests ---\n")
refit_sb <- coxph(Surv(duration_years, event_type == 1) ~ post_pslra, data = df)
refit_db <- coxph(Surv(duration_years, event_type == 2) ~ post_pslra, data = df)
cat("  Settlement baseline:\n"); print(cox.zph(refit_sb)$table)
cat("\n  Dismissal baseline:\n"); print(cox.zph(refit_db)$table)
cat("\n")

# --- 2f. Interaction Models ---
cat("--- 2f. Interaction Models ---\n")
if (!is.null(cox$cox_s_int)) {
  print_cox(cox$cox_s_int, "Settlement Interaction")
  print_cox(cox$cox_d_int, "Dismissal Interaction")

  lrt_s <- anova(cox$cox_s_noint, cox$cox_s_int)
  lrt_d <- anova(cox$cox_d_noint, cox$cox_d_int)
  cat("  Settlement LRT:\n"); print(lrt_s)
  cat("\n  Dismissal LRT:\n"); print(lrt_d)
}
cat("\n")

# --- 2g. C-indices (in-sample, from saved objects) ---
cat("--- 2g. C-indices (in-sample) ---\n")
for (nm in c("cox_s_base","cox_d_base","cox_s_circ","cox_d_circ",
             "cox_s_ext","cox_d_ext","cox_s_int","cox_d_int")) {
  m <- cox[[nm]]
  if (!is.null(m)) {
    cc <- summary(m)$concordance
    cat(sprintf("  %-18s C=%.3f (SE=%.4f)\n", nm, cc[1], cc[2]))
  }
}
cat("\n")

# ==================================================================
# SECTION 3: IPTW NUMBERS
# ==================================================================
cat("================================================================\n")
cat(" SECTION 3: IPTW TRIANGULATION\n")
cat("================================================================\n\n")

# --- 3a. Triangulation Table ---
cat("--- 3a. Comparison Table ---\n")
if (!is.null(iptw$comparison_table)) {
  print(iptw$comparison_table)
}
cat("\n")

# --- 3b. MSM detail ---
cat("--- 3b. MSM Models (Row 4) ---\n")
print_cox(iptw$cox_s_msm, "MSM Settlement")
print_cox(iptw$cox_d_msm, "MSM Dismissal")

# --- 3c. Weighted + Covariates (Row 3) ---
cat("--- 3c. Regression-Adjusted IPTW (Row 3) ---\n")
print_cox(iptw$cox_s_ra_iptw, "RA-IPTW Settlement")
print_cox(iptw$cox_d_ra_iptw, "RA-IPTW Dismissal")

# --- 3d. Metadata ---
cat("--- 3d. IPTW Metadata ---\n")
cat(sprintf("  Estimand: %s\n", iptw$metadata$estimand))
cat(sprintf("  N total: %d\n", iptw$metadata$n_total))
cat(sprintf("  N pre-PSLRA: %d\n", iptw$metadata$n_pre))
cat(sprintf("  N post-PSLRA: %d\n", iptw$metadata$n_post))
cat(sprintf("  Trim cap: %.2f\n", iptw$metadata$trim_cap_value))
cat("\n")

# --- 3e. Balance (via cobalt::bal.tab) and ESS ---
cat("--- 3e. Balance and ESS ---\n")
w <- iptw$weightit_obj
bt <- bal.tab(w, stats = "m", thresholds = c(m = 0.1), un = TRUE)
cat("  Balance table:\n")
print(bt)
cat(sprintf("\n  Number of balance rows: %d\n", nrow(bt$Balance)))
cat(sprintf("  Max adjusted |SMD|: %.4f\n", max(abs(bt$Balance$Diff.Adj))))
cat(sprintf("  All under 0.1: %s\n", all(abs(bt$Balance$Diff.Adj) < 0.1)))

ws <- summary(w)
cat(sprintf("\n  ESS (from WeightIt summary):\n"))
print(ws$effective.sample.size)
cat("\n")

# ==================================================================
# SECTION 4: FRAILTY NUMBERS
# ==================================================================
cat("================================================================\n")
cat(" SECTION 4: FRAILTY AND CLUSTER-ROBUST\n")
cat("================================================================\n\n")

# --- 4a. Frailty Variance ---
cat("--- 4a. Frailty Variance ---\n")
extract_frailty_var <- function(model, label) {
  if (inherits(model, "coxme")) {
    theta <- coxme::VarCorr(model)
    if (is.list(theta)) theta <- theta[[1]]
    cat(sprintf("  %s: theta = %.4f\n", label, as.numeric(theta)))
  } else {
    cat(sprintf("  %s: not a coxme object\n", label))
  }
}
extract_frailty_var(frailty_obj$frailty_s_base, "Settlement Baseline Frailty")
extract_frailty_var(frailty_obj$frailty_d_base, "Dismissal Baseline Frailty")
extract_frailty_var(frailty_obj$frailty_s_ext, "Settlement Extended Frailty")
extract_frailty_var(frailty_obj$frailty_d_ext, "Dismissal Extended Frailty")
cat("\n")

# --- 4b. Frailty PSLRA HR ---
cat("--- 4b. Frailty PSLRA Hazard Ratios ---\n")
extract_frailty_hr <- function(model, label) {
  if (inherits(model, "coxme")) {
    coefs <- model$coefficients
    pslra_idx <- grep("post_pslra", names(coefs))
    if (length(pslra_idx) > 0) {
      beta <- coefs[pslra_idx]
      hr <- exp(beta)
      vcov_m <- as.matrix(vcov(model))
      se <- sqrt(vcov_m[pslra_idx, pslra_idx])
      lo <- exp(beta - 1.96 * se)
      hi <- exp(beta + 1.96 * se)
      p <- 2 * pnorm(-abs(beta / se))
      cat(sprintf("  %s: HR=%.3f [%.3f, %.3f]  p=%.4g\n", label, hr, lo, hi, p))
    }
  }
}
extract_frailty_hr(frailty_obj$frailty_s_base, "Settlement Baseline RE")
extract_frailty_hr(frailty_obj$frailty_d_base, "Dismissal Baseline RE")
extract_frailty_hr(frailty_obj$frailty_s_ext, "Settlement Extended RE")
extract_frailty_hr(frailty_obj$frailty_d_ext, "Dismissal Extended RE")
cat("\n")

# --- 4c. Cluster-Robust SEs ---
cat("--- 4c. Cluster-Robust Models (Extended) ---\n")
print_cox(frailty_obj$cox_s_cluster_ext, "Settlement Cluster-Robust Extended")
print_cox(frailty_obj$cox_d_cluster_ext, "Dismissal Cluster-Robust Extended")

# --- 4d. Comparison Tables ---
cat("--- 4d. Frailty Comparison Tables ---\n")
cat("  Settlement Comparison:\n")
print(frailty_obj$comparison_settlement)
cat("\n  Dismissal Comparison:\n")
print(frailty_obj$comparison_dismissal)
cat("\n")

# ==================================================================
# SECTION 5: FINE-GRAY NUMBERS
# ==================================================================
cat("================================================================\n")
cat(" SECTION 5: FINE-GRAY (refit if .rds missing)\n")
cat("================================================================\n\n")

if (has_fg) {
  fg_s_ext <- fg$fg_s_ext
  fg_d_ext <- fg$fg_d_ext
  cat("  Using saved Fine-Gray models.\n\n")
} else {
  cat(sprintf("  Refitting extended Fine-Gray models on df_ext (N=%d)...\n", nrow(df_ext)))
  fg_cols <- c("duration_years","event_type","post_pslra","circuit_f",
               "origin_cat","mdl_flag","juris_fq","stat_basis_f","case_id")
  fg_s_data <- finegray(
    Surv(duration_years, factor(event_type, 0:2)) ~ .,
    data = df_ext[, fg_cols], etype = "1"
  )
  fg_s_ext <- coxph(
    Surv(fgstart, fgstop, fgstatus) ~ post_pslra + circuit_f + origin_cat +
      mdl_flag + juris_fq + stat_basis_f,
    data = fg_s_data, weights = fgwt, cluster = case_id
  )
  cat("  Settlement done.\n")

  fg_d_data <- finegray(
    Surv(duration_years, factor(event_type, 0:2)) ~ .,
    data = df_ext[, fg_cols], etype = "2"
  )
  fg_d_ext <- coxph(
    Surv(fgstart, fgstop, fgstatus) ~ post_pslra + circuit_f + origin_cat +
      mdl_flag + juris_fq + stat_basis_f,
    data = fg_d_data, weights = fgwt, cluster = case_id
  )
  cat("  Dismissal done.\n\n")
}

# Fine-Gray model$n is the finegray-expanded row count, not the case count.
# Validate the case count via the number of events, which must match the
# Cox extended model's event count (same cases, same outcomes).
fg_s_events <- fg_s_ext$nevent
fg_d_events <- fg_d_ext$nevent
stopifnot(
  fg_s_events == cox$cox_s_ext$nevent,
  fg_d_events == cox$cox_d_ext$nevent
)
cat(sprintf("  Fine-Gray case-count validation: settlement events=%d, dismissal events=%d (match Cox extended)\n",
            fg_s_events, fg_d_events))
cat(sprintf("  Fine-Gray estimation sample: N=%d cases (same df_ext as Cox extended)\n\n", nrow(df_ext)))

cat(sprintf("--- 5a. Extended Fine-Gray (all covariates, N=%d cases) ---\n", nrow(df_ext)))
print_cox(fg_s_ext, "Fine-Gray Settlement Extended", n_override = nrow(df_ext))
print_cox(fg_d_ext, "Fine-Gray Dismissal Extended", n_override = nrow(df_ext))

cat("--- 5b. CS Cox vs Fine-Gray Comparison ---\n")
# Build comparison for PSLRA and MDL
for (out_lbl in c("Settlement", "Dismissal")) {
  cox_mod <- if (out_lbl == "Settlement") cox$cox_s_ext else cox$cox_d_ext
  fg_mod  <- if (out_lbl == "Settlement") fg_s_ext else fg_d_ext
  for (cv in c("post_pslra", "mdl_flag")) {
    cs_s <- summary(cox_mod)
    fg_s_obj <- summary(fg_mod)
    cs_hr <- cs_s$conf.int[cv, "exp(coef)"]
    fg_hr <- fg_s_obj$conf.int[cv, "exp(coef)"]
    fg_lo <- fg_s_obj$conf.int[cv, "lower .95"]
    fg_hi <- fg_s_obj$conf.int[cv, "upper .95"]
    fg_p  <- fg_s_obj$coefficients[cv, "Pr(>|z|)"]
    cat(sprintf("  %s | %-14s | CS HR=%.3f | FG SHR=%.3f [%.3f, %.3f] p=%.4g\n",
                out_lbl, cv, cs_hr, fg_hr, fg_lo, fg_hi, fg_p))
  }
}
cat("\n")

cat("--- 5c. Fine-Gray PH Tests ---\n")
fg_zph_or_die <- function(model, label) {
  tryCatch(
    cox.zph(model),
    error = function(e) stop(sprintf("%s FG PH error: %s", label, e$message), call. = FALSE)
  )
}

ph_fg_s <- fg_zph_or_die(fg_s_ext, "Settlement")
ph_fg_d <- fg_zph_or_die(fg_d_ext, "Dismissal")
cat("  Settlement:\n"); print(ph_fg_s$table)
cat("\n")
cat("  Dismissal:\n");  print(ph_fg_d$table)
cat("\n")

# ==================================================================
# SECTION 6: ROBUSTNESS NUMBERS
# ==================================================================
cat("================================================================\n")
cat(" SECTION 6: ROBUSTNESS\n")
cat("================================================================\n\n")

cat("--- 6a. Robustness Table ---\n")
print(robust$table, n = 50)
cat("\n")

cat("--- 6b. Spline Time-Trend Models ---\n")
if (!is.null(robust$time_trend_s)) print_cox(robust$time_trend_s, "Settlement (spline)")
if (!is.null(robust$time_trend_d)) print_cox(robust$time_trend_d, "Dismissal (spline)")

# ==================================================================
# SECTION 7: CIF HORIZONS AND GRAY'S TESTS
# ==================================================================
cat("================================================================\n")
cat(" SECTION 7: CIF HORIZONS AND GRAY'S TESTS\n")
cat("================================================================\n\n")

# --- 7a. CIF by PSLRA Regime (use group arg on full data) ---
cat("--- 7a. CIF by PSLRA Regime ---\n")
ci_pslra <- cuminc(df$duration_years, df$event_type, group = df$post_pslra)
# Keys are "0 1", "0 2", "1 1", "1 2"
for (grp in c("0", "1")) {
  grp_lbl <- if (grp == "0") "Pre-PSLRA" else "Post-PSLRA"
  for (evt in c("1", "2")) {
    evt_lbl <- if (evt == "1") "Settlement" else "Dismissal"
    key <- paste(grp, evt)
    times <- ci_pslra[[key]]$time
    est   <- ci_pslra[[key]]$est
    stopifnot(!is.null(times))
    for (t_star in c(1, 2, 3, 5)) {
      idx <- max(which(times <= t_star))
      cat(sprintf("  %s %s @ %d yr: %.1f%%\n", grp_lbl, evt_lbl, t_star, 100 * est[idx]))
    }
  }
}
cat("\n")

# --- 7b. Overall CIF (no group) ---
cat("--- 7b. Overall CIF ---\n")
ci_all <- cuminc(df$duration_years, df$event_type)
for (evt in c("1", "2")) {
  evt_lbl <- if (evt == "1") "Settlement" else "Dismissal"
  key <- paste("1", evt)  # ungrouped cuminc puts all in group "1"
  times <- ci_all[[key]]$time
  est   <- ci_all[[key]]$est
  for (t_star in c(1, 2, 3, 5, 8)) {
    idx <- max(which(times <= t_star))
    cat(sprintf("  Overall %s @ %d yr: %.1f%%\n", evt_lbl, t_star, 100 * est[idx]))
  }
}
cat("\n")

# --- 7c. Gray's Tests ---
cat("--- 7c. Gray's Tests (PSLRA) ---\n")
print(ci_pslra$Tests)
cat("\n")

cat("--- 7d. Gray's Tests (Circuit) ---\n")
ci_circ <- cuminc(df$duration_years, df$event_type, group = df$circuit_f)
print(ci_circ$Tests)
cat("\n")

# ==================================================================
# SECTION 8: PERFORMANCE TABLE
# ==================================================================
cat("================================================================\n")
cat(" SECTION 8: PERFORMANCE TABLE (from .tex file)\n")
cat("================================================================\n\n")

perf_file <- here("output", "tables", "tab_model_performance.tex")
if (file.exists(perf_file)) {
  cat(paste(readLines(perf_file), collapse = "\n"))
  cat("\n\n")
} else {
  cat("  tab_model_performance.tex NOT FOUND.\n\n")
}

# ==================================================================
# SECTION 9: CLEAN-WINDOW AND PLACEBO TESTS
# ==================================================================
cat("================================================================\n")
cat(" SECTION 9: CLEAN-WINDOW AND PLACEBO\n")
cat("================================================================\n\n")

# --- 9a. Clean Window (1993-1998) ---
cat("--- 9a. Clean Window (1993-1998) ---\n")
df_cw <- df[df$filing_year >= 1993 & df$filing_year <= 1998, ]
cat(sprintf("  N = %d\n", nrow(df_cw)))
print_cox(coxph(Surv(duration_years, event_type == 1) ~ post_pslra, data = df_cw),
          "Clean Window Settlement")
print_cox(coxph(Surv(duration_years, event_type == 2) ~ post_pslra, data = df_cw),
          "Clean Window Dismissal")

# --- 9b. Placebo Test (1992 cutoff, pre-PSLRA only) ---
cat("--- 9b. Placebo Test (1992 cutoff) ---\n")
df_pre <- df[df$post_pslra == 0, ]
df_pre$placebo <- as.integer(df_pre$filing_year >= 1992)
cat(sprintf("  N pre-PSLRA = %d\n", nrow(df_pre)))
print_cox(coxph(Surv(duration_years, event_type == 1) ~ placebo, data = df_pre),
          "Placebo Settlement")
print_cox(coxph(Surv(duration_years, event_type == 2) ~ placebo, data = df_pre),
          "Placebo Dismissal")

# ==================================================================
# SECTION 10: MISC NUMBERS FOR PROSE
# ==================================================================
cat("================================================================\n")
cat(" SECTION 10: MISC NUMBERS FOR PROSE\n")
cat("================================================================\n\n")

cat(sprintf("  Extended model N: %d\n", cox$df_ext_nrow))
cat(sprintf("  Interaction model N: %d\n", cox$df_int_nrow))
cat(sprintf("  Zero-duration cases dropped: 740 (hardcoded from 01_clean.R)\n"))

# Settlement/dismissal composition by disp code
cat("\n--- Settlement composition by disp code ---\n")
print(sort(table(df$disp[df$event_type == 1]), decreasing = TRUE))
cat("\n--- Dismissal composition by disp code ---\n")
print(sort(table(df$disp[df$event_type == 2]), decreasing = TRUE))
cat("\n--- Censored composition by disp code ---\n")
print(sort(table(df$disp[df$event_type == 0]), decreasing = TRUE))

cat("\n================================================================\n")
cat(" EXTRACTION COMPLETE\n")
cat("================================================================\n")
