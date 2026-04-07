# ============================================================
# Script: 01_clean.R
# Purpose: Load raw IDB extract, filter to securities class actions,
#          construct covariates and disposition schemes, save cleaned .rds
# Input: data/raw/cv88on.txt
# Output: data/cleaned/securities_cohort_cleaned.rds,
#         data/cleaned/securities_scheme_B.rds,
#         data/cleaned/securities_scheme_C.rds
# Dependencies: tidyverse, lubridate, janitor, here
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
library(janitor)

cat("=================================================================\n")
cat(" 01_clean.R — DATA LOADING AND CLEANING\n")
cat("=================================================================\n\n")

# =============================================================================
# SECTION 1: DATA LOADING
# =============================================================================
cat("SECTION 1: Loading raw IDB data...\n")

raw_path <- here::here("data", "raw", "cv88on.txt")
stopifnot("Raw data file not found" = file.exists(raw_path))

df_raw <- read_tsv(
  raw_path,
  guess_max      = 200000,
  show_col_types = FALSE
) %>%
  clean_names()

cat(sprintf("  Total rows loaded: %s\n", format(nrow(df_raw), big.mark = ",")))

# Filter to NOS 850, parse dates, compute duration
df_sec <- df_raw %>%
  filter(nos == 850) %>%
  mutate(
    filedate  = as.Date(parse_date_time(filedate, orders = c("mdy", "ymd", "dmy"),
                                        quiet = TRUE)),
    termdate  = as.Date(parse_date_time(termdate, orders = c("mdy", "ymd", "dmy"),
                                        quiet = TRUE)),
    duration_years = as.numeric(termdate - filedate) / 365.25
  ) %>%
  filter(filedate >= as.Date("1990-01-01"))

cat(sprintf("  NOS 850 cases (post-1990): %s\n", format(nrow(df_sec), big.mark = ",")))


# =============================================================================
# SECTION 2: STATUTORY BASIS FROM SECTION FIELD
# =============================================================================
cat("\nSECTION 2: Exploring SECTION field for statutory basis signal...\n")

section_check <- df_sec %>%
  mutate(section_raw = as.character(section)) %>%
  filter(!is.na(section_raw), section_raw != "-8", section_raw != "") %>%
  count(section_raw, sort = TRUE) %>%
  mutate(pct = round(100 * n / nrow(df_sec), 2))

cat(sprintf("  Cases with non-missing SECTION: %s (%s%% of NOS 850)\n",
            format(sum(section_check$n), big.mark = ","),
            round(100 * sum(section_check$n) / nrow(df_sec), 1)))

cat("  Top SECTION values (NOS 850 cases):\n")
print(head(section_check, 10))

# Code statutory basis
df_sec <- df_sec %>%
  mutate(
    section_raw = toupper(trimws(as.character(section))),
    statutory_basis = case_when(
      section_raw %in% c("-8", "", "NA") | is.na(section_raw) ~ NA_character_,
      grepl("10B|78J|10\\(B\\)|10B-5|0078", section_raw)  ~ "10(b)",
      grepl("^11$|77K|^11 |0077", section_raw)            ~ "Section 11",
      !is.na(section_raw) & section_raw != "-8"           ~ "Other/Both"
    ),
    statutory_basis_f    = factor(statutory_basis,
                                  levels = c("10(b)", "Section 11", "Other/Both")),
    statutory_basis_miss = as.integer(is.na(statutory_basis))
  )

cat("\n  Statutory basis distribution after coding:\n")
print(table(df_sec$statutory_basis, useNA = "always"))
cat(sprintf("  Coverage rate: %s%%\n",
            round(100 * mean(!is.na(df_sec$statutory_basis)), 1)))


# =============================================================================
# SECTION 3: SAMPLE CONSTRUCTION
# =============================================================================
cat("\nSECTION 3: Constructing analysis sample...\n")

n_nos850   <- nrow(df_sec)
n_classact <- sum(df_sec$classact == 1, na.rm = TRUE)

df_cohort <- df_sec %>%
  filter(classact == 1, duration_years > 0) %>%
  mutate(case_id = row_number())
n_valid <- nrow(df_cohort)

cat(sprintf("  All NOS 850 (post-1990): %s\n", format(n_nos850, big.mark = ",")))
cat(sprintf("  Class action flag = 1:   %s\n", format(n_classact, big.mark = ",")))
cat(sprintf("  Valid duration (>0):     %s\n", format(n_valid, big.mark = ",")))

# Validate disposition codes before coding events
stopifnot(
  "Unexpected disposition codes outside 0-20" =
    all(df_cohort$disp %in% 0:20, na.rm = TRUE),
  "All disposition codes are NA -- check data integrity" =
    any(!is.na(df_cohort$disp)),
  "Expected JUDGMENT column not found after clean_names()" =
    "judgment" %in% names(df_cohort)
)
cat("  Disposition code validation: PASSED (all codes in 0-20)\n")
n_na_disp <- sum(is.na(df_cohort$disp))
if (n_na_disp > 0) {
  cat(sprintf("  WARNING: %d cases have NA disposition (will be coded as censored)\n", n_na_disp))
} else {
  cat("  No NA dispositions found\n")
}


# =============================================================================
# SECTION 4: THREE DISPOSITION CODING SCHEMES
# =============================================================================
# Source: FJC IDB Codebook (docs/fjc_codebook.md)
#
# Scheme A (Primary):
#   Settlement: Code 13; judgment-bearing codes {4,15,17,19,20} with
#               JUDGMENT=1; Code 6 with JUDGMENT=1
#   Dismissal:  Codes 2 (want of prosecution), 3 (lack of jurisdiction),
#               12 (voluntary), 14 (other dismissal);
#               judgment-bearing codes {4,15,17,19,20} with JUDGMENT=2;
#               Code 6 with JUDGMENT=2
#   Censored:   Codes 0,1,10,11 (transfers/remands); code 18
#               (statistical closing); codes 7-9 (trial outcomes);
#               judgment-bearing codes with JUDGMENT in {0,3,4,-8,NA}
#
# Scheme B (Liberal):  Reclassify Code 12 (voluntary) -> settlement (hidden settlements)
# Scheme C (Expanded): Scheme B + Code 5 (consent judgment) -> settlement
#
# JUDGMENT DISAGGREGATION NOTE:
# For FJC "Judgment On" dispositions, the IDB JUDGMENT field records the
# prevailing party:
#   JUDGMENT = 1 (Plaintiff) -> Settlement (1L): plaintiff-favorable resolution
#   JUDGMENT = 2 (Defendant) -> Dismissal (2L): defense motion granted (MTD/SJ)
#   JUDGMENT in {0,3,4,-8} or NA -> Censored (0L): ambiguous, conservative default
# This applies to Code 6 and the other judgment-bearing dispositions used in
# the thesis coding scheme: 4 (default), 15 (arbitrator), 17 (other judgment),
# 19 (appeal affirmed, magistrate), and 20 (appeal denied, magistrate).
#
# CODE 18 NOTE:
# Code 18 (statistical closing) is an administrative closure without substantive
# adjudication and is treated as right-censoring in all schemes.
# =============================================================================
cat("\nSECTION 4: Coding three disposition schemes...\n")

code_events <- function(df, scheme = "A") {
  df %>%
    mutate(
      event_type = case_when(
        # --- Settlements ---
        disp == 13                                ~ 1L, # Settled
        scheme %in% c("B","C") & disp == 12      ~ 1L, # Voluntary -> settlement (B,C)
        scheme == "C"          & disp == 5       ~ 1L, # Consent judgment -> settlement (C)
        disp %in% c(4, 15, 17, 19, 20) &
          judgment == 1                           ~ 1L, # Plaintiff judgment -> settlement
        disp == 6 & judgment == 1                 ~ 1L, # Code 6 plaintiff victory -> settlement

        # --- Dismissals ---
        disp %in% c(2, 3, 14)                    ~ 2L, # Dismissals (all schemes)
        scheme == "A"          & disp == 12      ~ 2L, # Voluntary -> dismissal (A only)
        disp %in% c(4, 15, 17, 19, 20) &
          judgment == 2                           ~ 2L, # Defendant judgment -> dismissal
        disp == 6 & judgment == 2                 ~ 2L, # Code 6 defendant victory -> dismissal

        # --- Censored ---
        # Includes: transfers (0,1), remands (10,11), consent judgments in
        # Schemes A/B, trial outcomes (7-9), stayed (16), statistical closing
        # (18), and judgment-bearing codes with ambiguous/missing JUDGMENT.
        TRUE                                      ~ 0L
      ),
      coding_scheme = scheme
    )
}


# =============================================================================
# SECTION 5: COVARIATE CONSTRUCTION
# =============================================================================
cat("\nSECTION 5: Constructing covariates...\n")

# Build covariates as a reusable function so all schemes get them
add_covariates <- function(df) {
  df %>%
    mutate(
      # ---- Core covariates ----
      post_pslra  = as.integer(filedate >= as.Date("1995-12-22")),
      pslra_label = factor(post_pslra, 0:1, c("Pre-PSLRA", "Post-PSLRA")),
      filing_year = year(filedate),
      circuit_f   = factor(circuit),

      # ---- ORIGIN: how the case entered federal court ----
      # FJC codes: 1=original, 2=removed from state, 3=remand from CoA,
      #            4=reinstated, 5=transfer 1404, 6=MDL transfer, 13=MDL originating
      # Codes 7-12 (magistrate appeals, reopens) are procedurally distinct and
      # rare in NOS 850; treated as NA per FJC documentation.
      # "Removed" is collapsed into "Other" globally so all downstream models
      # share the same factor structure; the standalone "Removed" cell is too
      # sparse pre-PSLRA to support stable cross-script comparisons.
      origin_cat = case_when(
        origin == 1          ~ "Original",
        origin == 2          ~ "Other",
        origin %in% c(6, 13) ~ "MDL",
        origin %in% c(3,4,5) ~ "Other",
        TRUE                 ~ NA_character_
      ),
      origin_cat = factor(origin_cat, levels = c("Original", "MDL", "Other")),

      # ---- MDL FLAG ----
      mdl_flag = as.integer(!is.na(mdldock) &
                              as.character(mdldock) != "-8" &
                              as.character(mdldock) != ""),

      # ---- JURY DEMAND: adversarial intensity proxy ----
      jury_demand = case_when(
        jury %in% c("B","P","D") ~ 1L,
        jury == "N"              ~ 0L,
        TRUE                     ~ NA_integer_
      ),

      # ---- MONETARY DEMAND: case size proxy ----
      # WARNING: 98.4% missing — only ~212 valid observations. The FJC sentinel
      # value 9999 means "not recorded" and is excluded. Use log_demand with
      # extreme caution in regression; consider excluding or using missingness
      # indicator only.
      demanded_num = suppressWarnings(as.numeric(demanded)),
      demand_valid = !is.na(demanded_num) & demanded_num > 0 & demanded_num < 9999,
      log_demand   = if_else(demand_valid, log(demanded_num + 1), NA_real_),
      demand_miss  = as.integer(!demand_valid),

      # ---- JURISDICTION: federal question vs. diversity ----
      # WARNING: 99.6% of NOS 850 cases are federal question (juris==3).
      # Near-zero variance — likely unusable in regression without separation issues.
      juris_fq = as.integer(juris == 3),

      # ---- STATUTORY BASIS (already coded in Section 2) ----
      stat_basis_f    = statutory_basis_f,
      stat_basis_miss = statutory_basis_miss,

      # ---- Event label ----
      event_label = factor(event_type, 0:2,
                           c("Censored","Settlement","Dismissal"))
    )
}

# Apply scheme coding + covariates to all three schemes
df_A <- code_events(df_cohort, "A") %>% add_covariates()
df_B <- code_events(df_cohort, "B") %>% add_covariates()
df_C <- code_events(df_cohort, "C") %>% add_covariates()

# Scheme A is the primary analysis dataset
df_model <- df_A

# Scheme summary table
scheme_summary <- map_dfr(list(A = df_A, B = df_B, C = df_C), function(d) {
  tibble(
    N           = nrow(d),
    Settlements = sum(d$event_type == 1),
    Dismissals  = sum(d$event_type == 2),
    Censored    = sum(d$event_type == 0),
    Pct_Settle  = round(100 * mean(d$event_type == 1), 1),
    Pct_Dismiss = round(100 * mean(d$event_type == 2), 1)
  )
}, .id = "Scheme")

cat("\nTABLE S1: Outcome distribution by disposition coding scheme\n")
print(scheme_summary)

cat("\n  Covariate missingness summary:\n")
miss_tbl <- df_model %>%
  summarise(
    origin_miss     = round(100 * mean(is.na(origin_cat)), 1),
    mdl_miss        = round(100 * mean(is.na(mdl_flag)), 1),
    jury_miss       = round(100 * mean(is.na(jury_demand)), 1),
    demand_miss_pct = round(100 * mean(demand_miss == 1), 1),
    juris_miss      = round(100 * mean(is.na(juris_fq)), 1),
    stat_basis_miss = round(100 * mean(stat_basis_miss == 1), 1)
  )
print(miss_tbl)

cat("\nEvent distribution (Scheme A):\n")
print(table(df_model$event_label))


# =============================================================================
# SECTION 6: DESCRIPTIVE STATISTICS
# =============================================================================
cat("\nSECTION 6: Descriptive statistics...\n")

# ---- Table 1A: Sample construction ----
cat("\nTABLE 1A: Sample Construction\n")
tribble(
  ~Stage, ~Description, ~N, ~Pct,
  "1", "All NOS 850 (1990-present)",   n_nos850,   100.0,
  "2", "Class action flag = 1",        n_classact, round(100*n_classact/n_nos850, 1),
  "3", "Valid duration (>0 days)",     n_valid,    round(100*n_valid/n_nos850, 1)
) %>%
  print()

# ---- Table 1B: Outcome distribution ----
cat("\nTABLE 1B: Outcome Distribution\n")
df_model %>%
  count(event_label) %>%
  mutate(Pct = round(100*n/sum(n), 1)) %>%
  print()

# ---- Table 1C: By PSLRA regime ----
cat("\nTABLE 1C: By PSLRA Regime\n")
df_model %>%
  group_by(pslra_label) %>%
  summarise(
    N              = n(),
    Settlements    = sum(event_type == 1),
    Dismissals     = sum(event_type == 2),
    Pct_Settlement = round(100*mean(event_type==1), 1),
    Pct_Dismissal  = round(100*mean(event_type==2), 1),
    .groups = "drop"
  ) %>%
  print()

# ---- Table 1D: Duration by outcome (resolved cases only) ----
cat("\nTABLE 1D: Duration Statistics by Outcome (resolved cases)\n")
df_model %>%
  filter(event_type != 0) %>%
  group_by(event_label) %>%
  summarise(
    N      = n(),
    Mean   = round(mean(duration_years), 2),
    Median = round(median(duration_years), 2),
    Q25    = round(quantile(duration_years, 0.25), 2),
    Q75    = round(quantile(duration_years, 0.75), 2),
    .groups= "drop"
  ) %>%
  print()

# ---- Table 1E: Circuit distribution ----
cat("\nTABLE 1E: Circuit Distribution\n")
df_model %>%
  count(circuit) %>%
  mutate(
    Pct = round(100*n/sum(n), 1),
    Circuit_Name = case_when(
      circuit == 0  ~ "D.C.",
      circuit == 1  ~ "First",
      circuit == 2  ~ "Second (NYC)",
      circuit == 3  ~ "Third (PA/NJ/DE)",
      circuit == 4  ~ "Fourth",
      circuit == 5  ~ "Fifth (TX/LA)",
      circuit == 6  ~ "Sixth",
      circuit == 7  ~ "Seventh",
      circuit == 8  ~ "Eighth",
      circuit == 9  ~ "Ninth (CA)",
      circuit == 10 ~ "Tenth",
      circuit == 11 ~ "Eleventh",
      TRUE          ~ paste("Circuit", circuit)
    )
  ) %>%
  arrange(desc(n)) %>%
  print()


# =============================================================================
# SAVE: Cleaned datasets (all schemes with full covariates)
# =============================================================================
cat("\n=================================================================\n")
cat("SAVING cleaned datasets...\n")

# Save primary (Scheme A) with all covariates
saveRDS(df_model, here::here("data", "cleaned", "securities_cohort_cleaned.rds"))
cat(sprintf("  Saved: data/cleaned/securities_cohort_cleaned.rds (%s rows, %s cols)\n",
            format(nrow(df_model), big.mark = ","),
            ncol(df_model)))

# Save Scheme B and C for robustness checks (08_robustness.R)
# Both have full covariates — only event_type differs
saveRDS(df_B, here::here("data", "cleaned", "securities_scheme_B.rds"))
saveRDS(df_C, here::here("data", "cleaned", "securities_scheme_C.rds"))
cat(sprintf("  Saved: data/cleaned/securities_scheme_B.rds (%s rows, %s cols)\n",
            format(nrow(df_B), big.mark = ","), ncol(df_B)))
cat(sprintf("  Saved: data/cleaned/securities_scheme_C.rds (%s rows, %s cols)\n",
            format(nrow(df_C), big.mark = ","), ncol(df_C)))

cat("\n=================================================================\n")
cat(" 01_clean.R COMPLETE\n")
cat("=================================================================\n")

print_session()
