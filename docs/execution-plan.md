# Execution Plan: Interim → Final Causal Inference Thesis

> **Generated**: 2026-03-27
> **Deadline**: April 9, 2026 (13 days)
> **Source**: docs/discovery-assessment.md (3-stage assessment)

---

## Architecture Overview

### Code Pipeline (Target State)

```
code/
├── utils.R                  ← Shared helpers (theme, colors, save functions) — REVIVED
├── 01_clean.R               ← Load raw IDB, filter, code, save cleaned .rds
├── 02_descriptives.R        ← Descriptive tables, KM, CIF (Figures 1-5)
├── 03_cox_models.R          ← Baseline, piecewise, circuit, extended Cox + interaction
├── 04_fine_gray.R           ← Fine-Gray subdistribution models
├── 05_causal_iptw.R         ← NEW: Propensity score, IPTW-weighted Cox + CIF
├── 06_frailty.R             ← NEW: Shared frailty (coxme) with circuit clusters
├── 07_diagnostics.R         ← Schoenfeld plots, C-index, time-dependent AUC
├── 08_robustness.R          ← Robustness checks (schemes, temporal, circuit subsets)
└── inspect_data.R           ← Utility (already exists)
```

Every script after `01_clean.R` reads from `data/cleaned/securities_cohort_cleaned.rds`.
Every script sources `code/utils.R`.
Every script writes figures to `output/figures/` (PDF + PNG) and tables to `output/tables/` (.tex).

### Results Chapter (Target Structure)

The claim-based restructure maps directly to the analytical pipeline:

```
Chapter 5: Results
├── 5.1  Overview: Duration and Competing Outcomes      [02_descriptives.R]
├── 5.2  The PSLRA Effect on Litigation Outcomes         [03, 05, 08]
│   ├── Associational evidence (Cox, Fine-Gray)
│   ├── Time-varying effect (piecewise)
│   ├── Causal estimate (IPTW) ← crown jewel
│   └── Robustness across coding schemes
├── 5.3  Geographic Disparity Across Circuits            [03, 06]
│   ├── Circuit effects (Cox)
│   ├── PSLRA × Circuit interaction
│   ├── Unobserved heterogeneity (Frailty variance)
│   └── Circuit-specific submodels
├── 5.4  Case Characteristics: MDL, Origin, Statutory    [03, 04]
│   ├── Extended model results
│   └── Cause-specific vs. subdistribution (MDL case study)
├── 5.5  Model Diagnostics and Validation                [07]
│   ├── Proportional hazards assessment
│   ├── Covariate balance (IPTW diagnostics)
│   └── Discrimination: C-index and AUC
└── 5.6  Summary of Findings
```

### Cascading Consistency Protocol

Every methodological change triggers updates in ALL of these files:

| Change | intro.tex | litreview.tex | methodology.tex | data.tex | results.tex | discussions.tex | refs.bib |
|---|---|---|---|---|---|---|---|
| RSF removed | ✓ | ✓ | ✓ | — | ✓ | ✓ | — |
| IPTW added | ✓ | ✓ | ✓ | — | ✓ | ✓ | ✓ |
| Frailty added | ✓ | ✓ | ✓ | — | ✓ | ✓ | ✓ |

---

## DO NOT TOUCH List

These are done and good. Do not modify unless a number verification reveals an error:

- **`data.tex`** — Professional tables, clear sample construction, correct numbers (pending verification)
- **`litreview.tex` Sections 2.2-2.4** — Empirical landscape, PSLRA background, determinants of settlement. Only Section 2.1 (survival methods) and 2.5 (research gap) need updating.
- **Core notation block** in `methodology.tex` Sections 3.1-3.3 — The symbols ($T_i$, $\delta_i$, $\lambda_k$, $F_k$, $\boldsymbol{\beta}_k$, $\boldsymbol{\gamma}_k$) are correct and consistent.
- **Disposition coding logic** in InterimScript Sections 1-6 — Correct filtering, coding, covariate construction.
- **Robustness check logic** in InterimScript Section 17 — Sound approach across schemes, temporal, circuit subsets.
- **`refs.bib`** existing entries — All correct. Only add new entries; don't reorganize.

---

## Task List

### Phase 1: FOUNDATION

---

#### Task 1 [FIX]: Modularize Code Pipeline — Data Cleaning
- [ ] Not started

**WHAT**: Extract InterimScript Sections 1-6 into `01_clean.R`. Fix the hardcoded data path. Update `utils.R` to be actively sourced. Save the cleaned analysis dataset as `data/cleaned/securities_cohort_cleaned.rds`.

**WHY**: Every subsequent script depends on a reliable, fast-loading cleaned dataset. Currently the 2 GB raw file is re-parsed on every run. This is the foundation of the entire pipeline.

**INPUTS**: `code/InterimScript.R` (Sections 1-6), `code/utils.R`, `data/raw/cv88on.txt`

**OUTPUTS**:
- `code/01_clean.R` (new)
- `code/utils.R` (updated — ensure it's general-purpose, remove any stale helpers)
- `data/cleaned/securities_cohort_cleaned.rds` (new)
- Console output with sample counts, missingness summary, event distribution

**ACCEPTANCE CRITERIA**:
- `Rscript code/01_clean.R` runs without errors from project root
- Produces `securities_cohort_cleaned.rds` with expected ~12,968 rows
- All three disposition schemes (A/B/C) coded correctly
- Console output matches numbers in `data.tex` (65,899 → 13,708 → 12,968)

**RISKS**: Data path on new machine may differ. Mitigation: use `here::here()` or relative paths.

---

#### Task 2 [FIX]: Modularize Code Pipeline — Analysis Scripts
- [ ] Not started

**WHAT**: Extract the remaining working sections of InterimScript into modular scripts:
- `02_descriptives.R`: Sections 7-10 (KM, CIF plots, Gray's tests, descriptive tables)
- `03_cox_models.R`: Sections 11-16 (all Cox models — baseline, piecewise, circuit, extended, interaction)
- `04_fine_gray.R`: Section 14-15 Fine-Gray portions (baseline + extended subdistribution models)
- `08_robustness.R`: Section 17 (robustness checks + forest plot)

Fix ALL known bugs during extraction:
- Fix all `ggsave()` paths → `output/figures/` with both PDF and PNG
- Remove dead code block (InterimScript lines 782-789)
- Ensure every script sources `utils.R` and reads from `securities_cohort_cleaned.rds`

**WHY**: Modular scripts are independently runnable, debuggable, and won't crash downstream when one section has an issue. Fixes the path and dead-code issues.

**INPUTS**: `code/InterimScript.R` (Sections 7-17)

**OUTPUTS**:
- `code/02_descriptives.R`, `code/03_cox_models.R`, `code/04_fine_gray.R`, `code/08_robustness.R`
- Updated figures in `output/figures/` (PDF + PNG)

**ACCEPTANCE CRITERIA**:
- Each script runs independently: `Rscript code/02_descriptives.R`, etc.
- All figures output to `output/figures/` as both PDF and PNG
- No references to RSF anywhere in these scripts
- No dead code blocks

**RISKS**: Section extraction may introduce scope bugs (missing variables). Mitigation: each script loads the .rds and constructs what it needs locally, or saves intermediate objects.

---

#### Task 3 [FIX]: Create Diagnostics Script — Fix Performance Metrics
- [ ] Not started

**WHAT**: Create `code/07_diagnostics.R` that correctly computes:
- Schoenfeld residual plots for the extended Cox models
- C-index on held-out test set for BOTH Cox AND Fine-Gray (do NOT copy-paste)
- Time-dependent AUC at 1, 2, 3, 5 year horizons
- Fix the fatal Section 19 bug: compute `lp_s`/`lp_d` BEFORE using them
- Remove the false Fine-Gray = Cox C-index assumption

**WHY**: The current performance numbers are unreliable (code bug) and the Fine-Gray C-index claim is methodologically false. These numbers are cited in the thesis. This must be fixed before any writing.

**INPUTS**: `code/InterimScript.R` (Sections 18-21, 23), `data/cleaned/securities_cohort_cleaned.rds`

**OUTPUTS**:
- `code/07_diagnostics.R`
- Schoenfeld residual plots in `output/figures/`
- Performance comparison table printed to console (C-index, AUC for Cox and Fine-Gray separately)
- Console output with corrected values

**ACCEPTANCE CRITERIA**:
- Script runs without errors
- Cox and Fine-Gray C-indices are computed independently (different values expected)
- Schoenfeld plots generated for at least the extended dismissal model
- `lp_s` and `lp_d` are defined before any use

**RISKS**: Fine-Gray C-index may be worse than Cox. That's fine — report honestly. If Schoenfeld plots reveal severe PH violations, document as a finding.

---

#### Task 4 [FIX]: Run Full Pipeline & Verify All Numbers
- [ ] Not started

**WHAT**: Run scripts 01 through 08 end-to-end, capture ALL console output to a log file (`output/analysis_log.txt`). Then systematically verify every hard-coded number in `data.tex` and `results.tex` against the log.

**WHY**: Academic integrity. Every number in the thesis must trace to actual R output. The thesis was written from interactive session output that may not be reproducible.

**INPUTS**: All code scripts, `data/raw/cv88on.txt`

**OUTPUTS**:
- `output/analysis_log.txt` (complete console output from all scripts)
- A verification checklist: each number in `data.tex` and `results.tex` marked as CONFIRMED or DISCREPANCY
- Any discrepant numbers flagged with `% TODO: VERIFY` in the .tex files

**ACCEPTANCE CRITERIA**:
- All scripts run without errors in sequence
- Every number in data.tex Tables 4.1-4.5 matches the log
- Every HR, CI, and p-value in results.tex matches the log
- Any discrepancies are documented and corrected

**RISKS**: Numbers may differ slightly from what's in the thesis (different data snapshot, rounding). Mitigation: if the differences are < 1% and don't change interpretation, update the thesis text. If they change interpretation, flag for Andrew's review.

---

#### Task 5 [FIX]: Prune RSF from Codebase and Delete Stale Outputs
- [ ] Not started

**WHAT**: Surgically remove all RSF traces:
- Delete `output/figures/figure7_rsf_vimp.png`
- Delete `output/figures/figure8_auc_comparison.png`
- Ensure no modular script references `randomForestSRC`
- Remove RSF from `utils.R` required packages list if present
- Erase the content of `writing/chapters/future.tex` (the planning memo), replacing with a placeholder comment `% TO BE REWRITTEN as proper Conclusion & Future Work chapter`

**WHY**: RSF is abandoned. Stale outputs and dead references create confusion and waste context. The "Future Work" memo is not a thesis chapter and must be rebuilt from scratch later.

**INPUTS**: `output/figures/`, `code/utils.R`, `writing/chapters/future.tex`

**OUTPUTS**:
- Deleted: `figure7_rsf_vimp.png`, `figure8_auc_comparison.png`
- Updated: `utils.R` (no RSF packages)
- Cleared: `future.tex`

**ACCEPTANCE CRITERIA**:
- `grep -r "randomForestSRC\|rsf\|RSF\|vimp\|VIMP" code/` returns no matches
- RSF figures deleted from `output/figures/`
- `future.tex` contains only the placeholder comment

**RISKS**: None. This is pure deletion of abandoned work.

---

### Phase 2: CAUSAL BUILD

---

#### Task 6 [CREATE]: Implement IPTW Causal Analysis
- [ ] Not started

**WHAT**: Write `code/05_causal_iptw.R` implementing:
1. **Propensity score model**: logistic regression for `post_pslra ~ circuit_f + origin_cat + mdl_flag + juris_fq + stat_basis_f + stat_basis_miss` (only pre-treatment covariates)
2. **Weight computation**: use `WeightIt::weightit()` with ATT or ATE weights
3. **Balance diagnostics**: use `cobalt::bal.tab()` and `cobalt::love.plot()` — output balance table and Love plot to `output/figures/`
4. **IPTW-weighted Cox models**: cause-specific Cox for settlement and dismissal with PSLRA indicator, weighted by IPTW
5. **IPTW-weighted CIF**: if feasible, compute weighted Aalen-Johansen CIF curves by PSLRA regime
6. **Sensitivity analysis**: vary the weight estimator (logistic, GBM) and trimming threshold

**WHY**: This is THE critical addition. It transforms the thesis from "associational" to "causal inference." It directly answers the advisor's #1 concern. The IPTW-adjusted PSLRA HR is the crown jewel of the final thesis.

**INPUTS**: `data/cleaned/securities_cohort_cleaned.rds`, `code/utils.R`

**OUTPUTS**:
- `code/05_causal_iptw.R`
- `output/figures/fig_iptw_balance.pdf` (Love plot)
- `output/figures/fig_iptw_cif.pdf` (weighted CIF by PSLRA, if feasible)
- Console output: balance table, weighted HRs with CIs, effective sample size

**ACCEPTANCE CRITERIA**:
- Balance diagnostics show standardized mean differences < 0.1 for all covariates after weighting (the gold standard)
- IPTW-weighted Cox models converge
- Weighted HRs are reported with robust (sandwich) standard errors
- Script includes explicit `set.seed(42)` before any stochastic operation

**RISKS**:
- **Positivity violation**: some circuit × covariate combinations may have no pre-PSLRA cases, producing extreme weights. *Mitigation*: trim weights at 99th percentile, report effective sample size.
- **Balance failure**: if covariates can't be balanced, report the failure. Use entropy balancing or GBM as fallback. If all fail, the IPTW section becomes "we attempted causal identification and document why it's infeasible with these data" — still a valid contribution.
- **Null result**: IPTW may attenuate the PSLRA HR toward 1. *This is not a problem* — it's a finding. A null causal result after IPTW adjustment, versus a strong associational result in Cox, is a publishable insight about confounding.

---

#### Task 7 [CREATE]: Implement Shared Frailty Models
- [ ] Not started

**WHAT**: Write `code/06_frailty.R` implementing:
1. **Circuit-level shared frailty**: use `coxme::coxme()` with `(1 | circuit)` random effect for both settlement and dismissal outcomes
2. **Report frailty variance**: extract and interpret $\hat{\theta}$ (frailty variance). Large variance → substantial unobserved circuit-level heterogeneity.
3. **Compare fixed vs. random effects**: compare frailty-adjusted PSLRA HR with fixed-effect Cox PSLRA HR
4. **Extended specification**: include all covariates alongside the circuit random effect

**WHY**: Addresses unobserved heterogeneity. The current Discussion admits "we cannot implement frailty models" — now we can. Frailty variance quantifies how much circuit-level variation exists beyond what covariates explain.

**INPUTS**: `data/cleaned/securities_cohort_cleaned.rds`, `code/utils.R`

**OUTPUTS**:
- `code/06_frailty.R`
- Console output: frailty model summary (HRs, frailty variance, comparison with fixed effects)

**ACCEPTANCE CRITERIA**:
- `coxme()` converges for both outcomes
- Frailty variance is extracted and reported
- PSLRA HR is compared between frailty and fixed-effect models

**RISKS**:
- **Convergence failure** with 13 circuit-level clusters. *Mitigation*: (a) try gamma vs. log-normal frailty distributions; (b) reduce to top-6 circuits; (c) if all fail, report fixed effects + cluster-robust SEs (sandwich estimator via `survival::coxph(..., cluster = circuit)`) as the fallback, and document frailty convergence failure as a limitation.
- **Tiny frailty variance**: if $\hat{\theta} \approx 0$, it means fixed effects fully capture circuit heterogeneity. This is a finding, not a failure.

---

#### CHECKPOINT 1 [REVIEW]: Adversarial Code Review
- [ ] Not started

**WHAT**: Run `/project:challenge` targeting ALL code scripts (`code/01_clean.R` through `code/08_robustness.R`). Specifically challenge:
- Statistical correctness of IPTW implementation (correct weight construction, correct SE estimation)
- Frailty model specification
- Whether C-index and AUC are computed correctly
- Whether any numbers could be artifacts of coding errors
- Whether causal language is only used for IPTW results

**WHY**: Catch errors before they propagate into the thesis text. Code errors are cheaper to fix than writing errors.

**INPUTS**: All scripts in `code/`

**OUTPUTS**: List of issues found, with fixes applied

**ACCEPTANCE CRITERIA**: All flagged issues resolved or documented with justification.

---

### Phase 3: CHAPTER RECONSTRUCTION

---

#### Task 8 [EXTEND]: Update Literature Review + Add New Sources
- [ ] Not started

**WHAT**:
1. Add 4 new references from `docs/new_lit_sources.txt` to `refs.bib`
2. Add a new subsection to `litreview.tex` Section 2.1: "Causal Inference in Survival Analysis" covering IPTW and shared frailty methods
3. Revise Section 2.5 "Research Gap and Contribution" to emphasize causal identification as the gap (not just "first competing-risks framework")
4. Remove or downweight RSF paragraph in Section 2.1 (currently lines 50-56)

**WHY**: The literature review must motivate the methods we actually use. IPTW and frailty need literature support. RSF literature is no longer relevant.

**INPUTS**: `writing/chapters/litreview.tex`, `docs/new_lit_sources.txt`, `writing/refs.bib`

**OUTPUTS**:
- Updated `litreview.tex`
- Updated `refs.bib` (4 new entries)

**ACCEPTANCE CRITERIA**:
- All 4 new sources cited at least once
- Causal inference methods motivated by literature
- RSF paragraph removed or reduced to one sentence
- Research gap explicitly mentions causal identification
- No fabricated citations (only from `new_lit_sources.txt`)

**RISKS**: None. Straightforward literature integration.

---

#### Task 9 [EXTEND]: Rewrite Methodology Chapter
- [ ] Not started

**WHAT**:
1. **Add plain-English hazard ratio definition** before the first equation — one paragraph explaining what a HR means intuitively ("a hazard ratio of 1.62 means that, at any point in time, post-PSLRA cases face a 62% higher instantaneous rate of dismissal compared to pre-PSLRA cases, holding other factors constant")
2. **Add IPTW section** (new Section 3.5 or 3.6): propensity score estimation, IPTW weighting, assumptions (no unmeasured confounding, positivity, correct specification), balance diagnostics, robust variance estimation
3. **Add Shared Frailty section** (new Section 3.6 or 3.7): mixed-effects Cox model, frailty variance interpretation, comparison with fixed effects
4. **Define $\widehat{\text{risk}}_i$** in the C-index equation as "the predicted risk score from the model (e.g., the linear predictor $\hat{\eta}_i = \hat{\boldsymbol{\beta}}^\top \mathbf{X}_i$ for Cox models)"
5. **Remove RSF section** (current Section 3.5) entirely
6. **Remove false Fine-Gray C-index claim** (current lines 244-248)
7. **Update model comparison section** to remove RSF and add IPTW/Frailty diagnostics
8. **Update validation strategy** to note IPTW uses full sample (no train/test for causal estimation) while diagnostics use the held-out test set

**WHY**: Methodology must describe ALL procedures used AND define all terms. Advisor flagged missing HR definition and $\widehat{\text{risk}}$ definition. IPTW and Frailty need formal mathematical treatment.

**INPUTS**: `writing/chapters/methodology.tex`, IPTW/Frailty R output from Tasks 6-7

**OUTPUTS**: Updated `methodology.tex`

**ACCEPTANCE CRITERIA**:
- HR defined in plain English before first formula
- $\widehat{\text{risk}}_i$ explicitly defined
- IPTW assumptions stated (no unmeasured confounding, positivity, correct specification)
- Frailty model formally specified
- No RSF section remains
- No false Fine-Gray claim remains
- Causal language used ONLY in IPTW section

**RISKS**: IPTW methodology section may be long. Keep it concise — define the estimator, state the assumptions, describe the diagnostics. No textbook-length derivations.

---

#### Task 10 [FIX]: Rewrite Introduction
- [ ] Not started

**WHAT**: Reframe the Introduction around causal inference:
1. Replace contribution (iv) — currently RSF — with IPTW causal identification
2. Add contribution about shared frailty / unobserved heterogeneity
3. Rewrite the "three core contributions" paragraph to lead with causal inference
4. Change framing from "first application of competing-risks framework" to "first causal estimates of PSLRA effects using IPTW in a competing-risks framework"
5. Remove all RSF mentions

**WHY**: The Introduction sets reader expectations. If it promises ML prediction, the reader evaluates the thesis as a prediction paper. If it promises causal inference, the reader evaluates it as a causal paper. The advisor explicitly said the objective is understanding what makes cases settle or dismiss — that's causal.

**INPUTS**: `writing/chapters/intro.tex`, updated methodology (Task 9)

**OUTPUTS**: Updated `intro.tex`

**ACCEPTANCE CRITERIA**:
- Core objective stated as causal inference in the first 3 paragraphs
- Contributions explicitly mention IPTW and frailty
- No RSF mentioned
- Still accessible to a non-specialist reader

**RISKS**: Over-promising causal claims. Mitigation: be precise — "we estimate the causal effect under stated assumptions" not "we prove PSLRA caused X."

---

#### Task 11 [CREATE]: Restructure Results Chapter — Part 1 (Claims 1-4)
- [ ] Not started

**WHAT**: Completely restructure Results chapter. Write Sections 5.1-5.4:

**5.1 Overview: Duration and Competing Outcomes** (~1 page)
- KM overall, CIF overall — brief, sets the stage
- Key takeaway: dismissal is the dominant resolution pathway

**5.2 The PSLRA Transformed Securities Litigation** (~3-4 pages)
- Open with the claim: "The PSLRA increased early dismissal rates and suppressed settlement probabilities"
- Evidence layer 1: CIF by PSLRA regime + Gray's test
- Evidence layer 2: Baseline Cox HRs (associational)
- Evidence layer 3: Piecewise time-varying effect (the three-phase pattern)
- Evidence layer 4: IPTW-adjusted causal HR ← crown jewel
- Evidence layer 5: Robustness across coding schemes
- Synthesis paragraph connecting all layers

**5.3 Geographic Disparity Across Circuits** (~2-3 pages)
- Open with the claim: "Circuit geography is the dominant structural predictor of case outcomes"
- CIF by circuit
- Cox circuit HRs
- PSLRA x Circuit interaction
- Frailty variance (quantifying unobserved circuit heterogeneity)
- Circuit-specific submodels from robustness

**5.4 Case Characteristics: MDL, Origin, and Statutory Basis** (~2 pages)
- Extended model HRs
- Fine-Gray vs. cause-specific comparison (MDL case study)
- The MDL bilateral suppression finding

**WHY**: Advisor's #1 ask. Organize by claims, not models. Each section tells a story with statistical evidence woven underneath. Reuses ~70% of existing content but restructured.

**INPUTS**: Current `results.tex`, R output from all scripts, `output/figures/`

**OUTPUTS**: New `results.tex` Sections 5.1-5.4

**ACCEPTANCE CRITERIA**:
- Each section opens with a substantive claim, not a model name
- Evidence from multiple models layered under each claim
- IPTW results appear in Section 5.2 (PSLRA claim)
- Frailty results appear in Section 5.3 (circuit claim)
- Causal language used ONLY for IPTW estimates
- Every number traces to R output (verified in Task 4)

**RISKS**: Restructuring is time-intensive. Mitigation: reuse existing paragraphs wherever possible — the prose is already good, it just needs reorganization.

---

#### Task 12 [CREATE]: Restructure Results Chapter — Part 2 (Diagnostics + Summary)
- [ ] Not started

**WHAT**: Write Sections 5.5-5.6:

**5.5 Model Diagnostics and Validation** (~2 pages)
- PH assumption tests + Schoenfeld residual plots
- Covariate balance table and Love plot (IPTW diagnostics)
- C-index and AUC comparison (Cox vs. Fine-Gray only — no RSF)
- Frailty variance interpretation

**5.6 Summary of Findings** (~1 page)
- Numbered list of 5-6 key findings
- Each finding stated as a claim with the statistical evidence cited
- Distinguish associational findings (Cox) from causal findings (IPTW)

**WHY**: Diagnostics demonstrate rigor. Summary provides the reader a clear takeaway. Both are required by the rubric.

**INPUTS**: R output from `07_diagnostics.R`, `05_causal_iptw.R`, `06_frailty.R`

**OUTPUTS**: Completed `results.tex`

**ACCEPTANCE CRITERIA**:
- Diagnostics section includes at least one Schoenfeld plot
- IPTW balance diagnostics visible (Love plot or balance table)
- Performance table has corrected values (no RSF, proper Fine-Gray C-index)
- Summary explicitly distinguishes causal from associational findings
- Total results chapter is shorter than the current version (~500 lines target vs. ~650)

**RISKS**: Diagnostics may reveal issues (PH violations, poor balance). These are findings to report, not problems to hide.

---

#### Task 13 [EXTEND]: Rewrite Discussion & Conclusion/Future Work
- [ ] Not started

**WHAT**:
1. **Update Discussion** (`discussions.tex`):
   - Add section on IPTW causal interpretation: what does the causal HR tell us that the associational HR didn't?
   - Add section on frailty findings: what does the frailty variance reveal about circuit heterogeneity?
   - Update limitations: remove "we cannot implement frailty models" (we did). Add IPTW assumptions as a limitation.
   - Remove all RSF discussion (current Section 6.5)
   - Update Section 6.6 "Limitations" to reflect current state
   - Fix any causal language that isn't backed by IPTW

2. **Rewrite Future Work** (`future.tex`):
   - Replace the planning memo with a proper 1-2 page thesis chapter
   - Sections: CourtListener integration, settlement amount analysis, post-2018 structural breaks, full time-varying coefficient models
   - Framed as research directions, not to-do items

3. **Ensure Conclusion exists**: either as the final section of Discussion or as a standalone subsection

**WHY**: Discussion must interpret the new IPTW and frailty results. Future Work must read as a thesis chapter, not project notes. The current Future Work chapter is the most obviously "unfinished" part of the thesis.

**INPUTS**: `writing/chapters/discussions.tex`, `writing/chapters/future.tex`, R output from Tasks 6-7

**OUTPUTS**: Updated `discussions.tex`, rewritten `future.tex`

**ACCEPTANCE CRITERIA**:
- IPTW findings interpreted substantively
- No mention of RSF
- No causal language without IPTW backing
- Future Work reads as a proper academic chapter
- Limitations section is accurate and current

**RISKS**: None. Straightforward writing task.

---

#### CHECKPOINT 2 [REVIEW]: Adversarial Thesis Review
- [ ] Not started

**WHAT**: Run `/project:challenge` targeting the FULL thesis (all .tex chapters). Specifically challenge:
- Does the Introduction promise what the Results deliver?
- Is causal language used ONLY for IPTW results?
- Does every number trace to R output?
- Would a skeptical reviewer reach the same conclusions?
- Does the thesis pass the "Drop-In" test at any random page?
- Are all advisor feedback items addressed?

**WHY**: Catch writing errors, logical gaps, and narrative inconsistencies before final polish.

**INPUTS**: All files in `writing/chapters/`

**OUTPUTS**: List of issues found, with fixes applied

**ACCEPTANCE CRITERIA**: All 7 advisor feedback items marked as addressed. No fabricated numbers. No causal language violations.

---

### Phase 4: POLISH

---

#### Task 14 [CREATE]: Write Abstract
- [ ] Not started

**WHAT**: Write a 200-300 word abstract covering:
1. Research question (what determines timing and type of resolution?)
2. Data (12,968 FJC IDB securities class actions, 1990-2024)
3. Methods (competing-risks framework: CIF, Cox, Fine-Gray, IPTW, frailty)
4. Key findings (PSLRA time-varying effect, circuit dominance, IPTW causal HR, frailty variance)
5. Implications (policy evaluation of PSLRA, geographic inequality in litigation)
6. Novelty (first IPTW causal estimates for securities litigation outcomes)

**WHY**: Rubric requires a complete abstract. Currently placeholder. This is the first thing readers see.

**INPUTS**: Completed results chapter, discussion chapter

**OUTPUTS**: Updated `abstract.tex`

**ACCEPTANCE CRITERIA**:
- 200-300 words
- All 6 elements present
- No numbers that aren't in the results chapter
- Accessible to a non-specialist

**RISKS**: None.

---

#### Task 15 [FIX]: Formatting, References, and Figure Polish
- [ ] Not started

**WHAT**:
1. Add `\usepackage{hyperref}` to `thesis.tex` (with `\hypersetup{colorlinks=true, linkcolor=blue, citecolor=blue, urlcolor=blue}`)
2. Fix the duplicate Wang et al. citation in `litreview.tex` line 129
3. Remove uncited bib entries (`eisenberg1997`, `heagerty2005`) or cite them if relevant
4. Verify all figure paths work (may need to adjust for Overleaf vs. local)
5. Ensure all figures are referenced as PDF in the thesis (for print quality)
6. Check that all `\ref{}` and `\cite{}` are unbroken after restructuring

**WHY**: Rubric compliance. Clickable references, consistent citation style, print-quality figures.

**INPUTS**: `writing/thesis.tex`, `writing/refs.bib`, all chapter files

**OUTPUTS**: Updated thesis.tex, refs.bib, chapter files

**ACCEPTANCE CRITERIA**:
- `hyperref` loaded
- No duplicate citation styles
- All `\ref{}` resolve
- All `\cite{}` resolve

**RISKS**: `hyperref` can conflict with other packages. Mitigation: load it last with appropriate options.

---

#### Task 16 [REVIEW]: Final Number Verification
- [ ] Not started

**WHAT**: Run a systematic cross-check of every number in the thesis against R output:
- Re-run all scripts, capture output
- For each table in the thesis: verify every cell
- For each inline number: trace to specific R output line
- Check that figure captions match the data (sample sizes, test statistics)

**WHY**: Academic integrity. This is the last gate before submission. Per CLAUDE.md Rule 2: "Every number must trace to actual R output."

**INPUTS**: All code scripts, all chapter files, `output/analysis_log.txt`

**OUTPUTS**: Verification report (all numbers confirmed or corrected)

**ACCEPTANCE CRITERIA**:
- Zero unverified numbers remain
- All `% TODO: VERIFY` comments resolved
- No placeholder numbers

**RISKS**: May find discrepancies. Mitigation: fix them. A correct thesis submitted on time is better than a thesis with fabricated numbers submitted early.

---

#### CHECKPOINT 3 [REVIEW]: Final Adversarial Gate
- [ ] Not started

**WHAT**: Run `/project:challenge` one final time as the submission gate. This review covers:
- Full thesis coherence (intro promises match results delivery)
- Number integrity (spot-check 10 random numbers against R output)
- Causal language discipline
- Self-containment (judge/professor test)
- Rubric checklist completion
- Advisor feedback compliance (all 7 items)

**WHY**: Final quality gate. No thesis ships without passing this.

**INPUTS**: Complete thesis

**OUTPUTS**: PASS/FAIL with specific issues if FAIL

**ACCEPTANCE CRITERIA**: PASS with no critical issues. Minor issues documented for Andrew's final review.

---

## Summary Timeline

| Day | Phase | Tasks | Key Output |
|---|---|---|---|
| 1-2 | Foundation | Tasks 1-4 | Working modular pipeline, verified numbers |
| 2 | Foundation | Task 5 | RSF pruned, stale outputs deleted |
| 3-4 | Causal Build | Tasks 6-7 | IPTW + Frailty results |
| 4 | Checkpoint | CP1 | Code validated |
| 5 | Reconstruction | Task 8 | Updated lit review |
| 5-6 | Reconstruction | Task 9 | Updated methodology |
| 6 | Reconstruction | Task 10 | Reframed introduction |
| 7-8 | Reconstruction | Tasks 11-12 | Restructured results |
| 8-9 | Reconstruction | Task 13 | Updated discussion + future work |
| 9 | Checkpoint | CP2 | Thesis validated |
| 10 | Polish | Tasks 14-15 | Abstract, formatting |
| 11 | Polish | Task 16 | Numbers verified |
| 12 | Checkpoint | CP3 | Final gate |
| 13 | Buffer | — | Emergency fixes, submission |

---

## Contingency Triage (If Time Runs Short)

**Cut order** (last to first — cut from the bottom):

1. ~~Task 15 formatting polish~~ — do hyperref + citation fix only, skip figure PDF conversion
2. ~~Task 7 Frailty~~ — if IPTW works, frailty is nice-to-have. Fixed effects + cluster-robust SEs are already implemented. Frame as "future work."
3. ~~Task 8 lit review update~~ — add bib entries and cite them inline, skip the new subsection

**Never cut:**
- Tasks 1-4 (foundation — pipeline must work)
- Task 6 (IPTW — the thesis's analytical centerpiece)
- Tasks 10-12 (Results restructure + Introduction reframe — advisor's explicit asks)
- Task 14 (Abstract — rubric requirement)
- Task 16 (Number verification — academic integrity)
