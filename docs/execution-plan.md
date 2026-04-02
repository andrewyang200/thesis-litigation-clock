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
│   ├── Composition-adjusted estimate (IPTW)
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
│   ├── Covariate balance + effective sample size (IPTW diagnostics)
│   └── Discrimination: C-index and AUC (Cox/Fine-Gray only — NOT IPTW)
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

## Risk Matrix

### CRITICAL Risks (could derail the thesis)

#### RISK-C1: IPTW with a Legislative Date Cutoff is Not Standard Causal Inference

PSLRA treatment is deterministic — every case filed after Dec 22, 1995 is "treated." There is no selection mechanism into treatment. The propensity score model is really modeling *temporal trends in case composition* (e.g., more cases from certain circuits after 1995), not treatment assignment in the Rubin potential-outcomes sense. The core assumption of no unmeasured confounding is almost certainly violated: economic cycles, judicial attitudes, plaintiff bar sophistication, SEC enforcement patterns, and defendant litigation strategies all changed between 1990 and 2024 and are not in the IDB.

**Failure scenario**: An ORFE examiner asks: "Your propensity score models P(filing after 1995). But that's 1 for all post-1995 cases and 0 for all pre-1995 cases. What exactly are you adjusting for?"

**Mitigation — reframe BEFORE coding**:
1. Do NOT call IPTW results "causal" in the thesis. Use "composition-adjusted" — IPTW adjusts for compositional differences in the observable case mix across time periods.
2. Frame the contribution as: "We demonstrate that the raw PSLRA effect is [robust to / partially explained by] concurrent changes in case composition, using propensity-score re-weighting to isolate the component not attributable to compositional shifts."
3. Explicitly state that unmeasured confounders remain uncontrolled and that this is a quasi-experimental adjustment, not a randomized experiment.
4. Reference Austin & Fine (2025) as methodological precedent but note they apply IPTW to an actual treatment (statin prescriptions) where selection is plausible.
5. Optionally: restrict IPTW to a narrow window (1993–1998) around the PSLRA cutoff as supplementary analysis, where quasi-experimental interpretation is strongest.

**Impact on plan**: Task 6 WHY section must be rewritten. "Crown jewel" language replaced with "composition-adjustment." Cascades to Tasks 9, 10, 11, 13, 14.

#### RISK-C2: Pre/Post PSLRA Sample Imbalance (1,032 vs. 11,936) Threatens Positivity

The pre-PSLRA sample is ~1,032 cases (5 years). Post-PSLRA is ~11,936 (29 years). This is an 11.6:1 ratio. Many covariate cells will be empty pre-PSLRA (certain circuits, MDL combinations, statutory bases). This produces extreme propensity scores, extreme weights, and a collapsed effective sample size after re-weighting. Trimming at 99th percentile changes the estimand.

**Failure scenario**: Effective sample size drops to 400–500. Standard errors explode. The IPTW HR confidence interval is so wide it is uninformative, or the result is fragile to excluding a handful of observations.

**Mitigation**:
1. Use ATT (average treatment effect on the treated) weights rather than ATE — ATT only reweights the smaller pre-PSLRA group, reducing extreme weights.
2. Report effective sample sizes prominently.
3. Check overlap: plot propensity score distributions for pre- vs. post-PSLRA. If there is minimal overlap, acknowledge IPTW is infeasible and present this as a finding.
4. Run a narrow-window analysis (1993–1998) as supplementary where balance is more plausible.
5. If all weighting approaches fail, the IPTW section becomes: "We document that compositional adjustment is infeasible due to extreme covariate imbalance, suggesting the PSLRA effect cannot be separated from concurrent compositional changes in the case mix." This is still a valid thesis contribution.

#### RISK-C3: The 13-Day Timeline Has No Real Buffer for Statistical Failures

The dependency chain is fully serial from Day 3 onward. If IPTW conceptual/implementation issues consume 3 days instead of 2, everything downstream shifts. The Results chapter restructure (Tasks 11–12) depends on finalized IPTW/Frailty results. Writing the Discussion (Task 13) depends on the Results. The 1-day buffer is consumed by a single unexpected setback.

**Mitigation**:
1. **Day 1 "kill switch" decision**: Before writing any IPTW code, spend 2–3 hours on the conceptual framing (RISK-C1). Decide: is IPTW defensible? What language will we use? This prevents wasting 2 days coding before discovering the framing is wrong.
2. **Day 10 feature freeze**: No new analysis after Day 10. Only writing and verification from Day 10 onward.
3. **Build Results skeleton early**: On Day 5, create the Results chapter structure (section headings, claim statements, figure/table placeholders) BEFORE IPTW/Frailty code is final. Fill in numbers later. This decouples writing from coding.
4. **Pre-write two Discussion variants**: One paragraph for "IPTW confirms associational results" and one for "IPTW attenuates/contradicts." Write both on Day 5 so there is no scramble if results surprise.

### HIGH Risks (significant but manageable)

#### RISK-H1: IPTW Results Could Contradict the Associational Cox Results

The raw Cox shows HR = 1.638 for dismissal and HR = 0.378 for settlement. If IPTW re-weighting reveals that most of this is driven by compositional changes (the post-PSLRA case mix skews toward circuits with naturally higher dismissal rates), the composition-adjusted HR could be ~1.0 and non-significant. This would require major narrative restructuring with days to go.

**Mitigation — pre-write both scenarios**:
- **Scenario A (IPTW confirms)**: "The composition-adjusted PSLRA effect remains large (HR = X.XX), suggesting the legislative reform's impact is not an artifact of changing case demographics."
- **Scenario B (IPTW attenuates)**: "After adjusting for concurrent changes in case composition, the PSLRA effect on dismissal is substantially reduced (HR = X.XX vs. unadjusted 1.64). This suggests the raw PSLRA coefficient partially reflects secular changes in the types of cases filed, highlighting the importance of compositional adjustment in evaluating legislative effects."
- **Scenario C (IPTW reverses)**: "The IPTW-adjusted estimate contradicts the unadjusted association, revealing that the apparent PSLRA effect is largely an artifact of confounding by case composition. This methodological finding — that naive survival estimates of legislative impacts are unreliable — is itself a contribution to the legal empirics literature."

All three are publishable. None require fabrication.

#### RISK-H2: PH Violations Will Carry Into IPTW-Weighted Models

The existing Cox models have severe PH violations (settlement: χ² = 102.9, p < 0.001; dismissal: χ² = 436.9, p < 0.001). IPTW changes the weighting but not the functional form. If PSLRA's effect is time-varying (which we already know from the piecewise model), a single IPTW-weighted HR averages over a time-varying effect. This average may be misleading.

**Mitigation**:
1. Run the Grambsch-Therneau test on the IPTW-weighted model.
2. If PH is violated (expected), implement a **piecewise IPTW model** with the same three time periods already used in the unweighted analysis. Report composition-adjusted HRs for each period.
3. Present the constant-HR IPTW model first (for comparability with the unadjusted constant-HR model), then the piecewise IPTW model as the more appropriate specification.

#### RISK-H3: data.tex "DO NOT TOUCH" Contradicts Task 4 Verification

Task 4 verifies every number. data.tex is "DO NOT TOUCH." If any number is wrong — even by 1 case due to filtering edge cases — data.tex must change. The raw data extract may have different totals if it was updated since the thesis was written.

**Resolution**: Remove data.tex from the DO NOT TOUCH list. Replace with: "data.tex is high-quality and should not be restructured, but all numbers must be verified and corrected if discrepant."

#### RISK-H4: Frailty with 13 Clusters is Statistically Marginal

Reliable frailty variance estimation typically requires 20–30+ clusters. With 13 circuits (some with very few cases — DC has ~16), the frailty variance estimate may be biased downward, sit on the boundary (zero), or have a wide uncomputable confidence interval.

**Mitigation**:
1. Frame frailty as a **sensitivity analysis**, not a standalone model.
2. Always pair frailty results with the already-implemented cluster-robust SEs as the primary robustness check.
3. Compare frailty PSLRA HR with fixed-effect PSLRA HR. If similar → main finding is robust (the interesting result). If different → discuss why.
4. Do NOT overclaim frailty variance as "quantifying unobserved heterogeneity" with only 13 clusters — present it as "a rough estimate, subject to small-cluster limitations."

#### RISK-H5: Disposition Coding Scheme Sensitivity Interacts with IPTW

Under Scheme A, the PSLRA settlement HR is 0.378. Under Scheme B, it is 0.696. This is a 2x sensitivity, not a rounding difference. The plan does not specify which scheme IPTW uses, or whether IPTW should run under multiple schemes.

**Mitigation**: Run IPTW under all three coding schemes (or at minimum Schemes A and B). Report the range of composition-adjusted HRs across schemes. Be explicit that the Scheme A settlement HR is the most extreme plausible estimate.

### MEDIUM Risks (plan adjustments needed)

#### RISK-M1: Tasks Claiming "RISKS: None" Have Real Risks

- **Task 5 (RSF pruning)**: RSF removal spans 4 LaTeX chapters. Deleting code is trivial; removing RSF from `intro.tex`, `methodology.tex`, `results.tex`, and `discussions.tex` without orphaned cross-references or missing content is not.
- **Task 8 (Lit review)**: New causal inference subsection must address the "legislative treatment" issue (RISK-C1), not just copy standard IPTW framing from papers that study actual treatments.
- **Task 13 (Discussion)**: Discussion rewrite depends on unfinished IPTW results. If IPTW produces unexpected results, the Discussion must handle them — that is not "straightforward."
- **Task 14 (Abstract)**: Must accurately reflect final results, which are not yet known when writing starts.

#### RISK-M2: C-Index / AUC are Inappropriate for Composition-Adjustment Models

C-index and AUC measure predictive discrimination. IPTW models estimate treatment effects, not predictions. Reporting C-index for the IPTW model confuses prediction and causal/compositional inference — the very conflation the thesis is trying to avoid. Per CLAUDE.md: "Use C-index/AUC only for the baseline Cox models."

**Mitigation**: IPTW diagnostics are (1) covariate balance, (2) effective sample size, (3) weight distribution. NOT C-index/AUC. Update Results Section 5.5 structure accordingly.

#### RISK-M3: Three-Tier Language Discipline Will Be Hard to Enforce

The restructured Results discusses the same PSLRA effect from multiple models in the same section (5.2). The temptation to use causal language for Cox results will be strong.

**Mitigation — define three tiers explicitly**:
1. **"Associated with"** — for Cox/Fine-Gray results
2. **"After adjusting for observable case composition"** — for IPTW results
3. **"Causally attributable to"** — reserved for designs with stronger identification (RDD, IV). Do NOT use this language anywhere in this thesis.

### LOW Risks (noted for awareness)

- **LOW-1**: `hyperref` package conflicts — load last, easy fix if it breaks
- **LOW-2**: Figure paths diverge between Overleaf and local — mechanical fix, but easy to forget
- **LOW-3**: `acknow.tex` is still placeholder — 15-minute task, but unlisted
- **LOW-4**: Second Circuit settlement anomaly (HR 5–17x lower) could be a coding artifact — check if Scheme B reduces the anomaly

---

## DO NOT TOUCH List

These are done and good. Do not modify unless a number verification reveals an error:

- **`data.tex`** — Professional tables, clear sample construction. Do not restructure, but all numbers must be verified and corrected if discrepant (see RISK-H3).
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
- [x] COMPLETE (2026-03-27)

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
- [x] COMPLETE (2026-03-27)

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
- [x] COMPLETE (2026-03-27)

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
- [x] COMPLETE (2026-03-28)

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
- [x] COMPLETE (2026-03-28)

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

**RISKS**: Code deletion is trivial, but RSF removal spans 4 LaTeX chapters (`intro.tex`, `methodology.tex`, `results.tex`, `discussions.tex`). Risk of orphaned cross-references, broken figure/table numbering, or sections that jump numbers. *Mitigation*: grep all .tex files for RSF/randomForest mentions after deletion. Verify section numbering is continuous.

---

### Phase 2: CAUSAL BUILD

---

#### Task 6 [CREATE]: Implement IPTW Composition-Adjusted Analysis
- [x] COMPLETE (2026-03-28)

**WHAT**: Write `code/05_causal_iptw.R` implementing:
1. **Propensity score model**: logistic regression for `post_pslra ~ circuit_f + origin_cat + mdl_flag + juris_fq + stat_basis_f + stat_basis_miss` (only pre-treatment covariates)
2. **Weight computation**: use `WeightIt::weightit()` with ATT or ATE weights
3. **Balance diagnostics**: use `cobalt::bal.tab()` and `cobalt::love.plot()` — output balance table and Love plot to `output/figures/`
4. **IPTW-weighted Cox models**: cause-specific Cox for settlement and dismissal with PSLRA indicator, weighted by IPTW
5. **IPTW-weighted CIF**: if feasible, compute weighted Aalen-Johansen CIF curves by PSLRA regime
6. **Sensitivity analysis**: vary the weight estimator (logistic, GBM) and trimming threshold

**WHY**: This is THE critical addition. It moves the thesis from purely associational estimates to composition-adjusted estimates that isolate the PSLRA component from concurrent changes in case composition. It directly answers the advisor's #1 concern. See RISK-C1 for why we use "composition-adjusted" rather than "causal" — the no-unmeasured-confounding assumption is implausible for a legislative date cutoff spanning 34 years.

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

**RISKS** (see Risk Matrix for full details):
- **Conceptual validity (RISK-C1)**: IPTW for a legislative date cutoff is not standard causal inference. Resolution: frame as "composition-adjusted," not "causal." Decide framing BEFORE writing code.
- **Positivity violation (RISK-C2)**: 1,032 pre- vs. 11,936 post-PSLRA cases. Many covariate cells empty pre-PSLRA. *Mitigation*: use ATT weights, plot propensity score overlap, report effective sample size, trim judiciously.
- **Balance failure**: if covariates can't be balanced after trying logistic, GBM, and entropy balancing, report the failure. The IPTW section becomes "we document that compositional adjustment is infeasible" — still a valid contribution.
- **Null or contradictory result (RISK-H1)**: IPTW may attenuate or reverse the PSLRA HR. *Pre-write Discussion paragraphs for both confirming and disconfirming scenarios.* All three scenarios (confirms, attenuates, contradicts) are publishable.
- **PH violations carry over (RISK-H2)**: IPTW doesn't fix PH violations. If PH is violated in the weighted model, implement piecewise IPTW with same time periods as the unweighted analysis.
- **Disposition scheme sensitivity (RISK-H5)**: Run IPTW under Schemes A and B at minimum. Report the range of composition-adjusted HRs.

**CRITICAL PRE-TASK**: Before writing any code, spend 2–3 hours resolving the IPTW conceptual framing. What does the propensity score model mean when treatment is a date cutoff? What language will the thesis use? This decision propagates into every chapter. Do not skip this step.

---

#### Task 7 [CREATE]: Implement Shared Frailty Models
- [x] COMPLETE (2026-03-29)

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
- [x] COMPLETE (2026-04-01) — All 8 scripts audited, fixed, and verified end-to-end. Zero errors.
  - 03: Deleted Section 1B (debunked linear time-trend) and Section 6 (algebraically vacuous reference test). Both debunked model objects removed from cox_models.rds.
  - 04: Deleted Section 5 (debunked linear time-trend). Added M3 stopifnot sync check, M5/L2 NULL-safety, M6 citation fix, L5 p_value column. Debunked models removed from fine_gray_models.rds.
  - 05: Made ps_formula/ext_rhs conditional on include_stat. Replaced all hardcoded narrative (balance claim, "big move", "all p < 0.001", PH p-value) with dynamic output. Re-run and iptw_results.rds refreshed (2026-04-01).
  - 06: Fixed frailty distribution label (LogNormal→Gaussian). Replaced hardcoded KEY FINDINGS block (stale theta=0.48/0.02, unconditional convergence claim) with dynamic output from model objects. Removed stale discussion.tex reminder. Re-run and frailty_results.rds refreshed (2026-04-01). Added % TODO to methodology.tex:331 for LaTeX equation fix in Phase 3.

**WHAT**: Run `/project:challenge` targeting ALL code scripts (`code/01_clean.R` through `code/08_robustness.R`). Specifically challenge:
- Statistical correctness of IPTW implementation (correct weight construction, correct SE estimation)
- Frailty model specification
- Whether C-index and AUC are computed correctly
- Whether any numbers could be artifacts of coding errors
- Whether three-tier language discipline is enforced (RISK-M3)

**WHY**: Catch errors before they propagate into the thesis text. Code errors are cheaper to fix than writing errors.

**INPUTS**: All scripts in `code/`

**OUTPUTS**: List of issues found, with fixes applied

**ACCEPTANCE CRITERIA**: All flagged issues resolved or documented with justification.

---

### Phase 3: CHAPTER RECONSTRUCTION

---

#### Task 8 [EXTEND]: Update Literature Review + Add New Sources
- [x] COMPLETE (2026-04-01) — Reviewed existing draft (no flip contamination found), fixed 7 issues flagged by writing-reviewer: redundancy, causal verbs, imprecise Austin&Fine claim, NOS expansion. All acceptance criteria met.

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

**RISKS**: The new causal inference subsection must address the "legislative treatment" framing issue (RISK-C1). It must motivate IPTW as a compositional adjustment, not copy standard IPTW framing from papers studying actual treatments (drugs, interventions). If the lit review promises "causal identification" but the methodology section says "composition-adjusted," the reader will notice the inconsistency. *Mitigation*: write the lit review subsection AFTER the IPTW conceptual framing decision (Task 6 pre-task).

---

#### Task 9 [EXTEND]: Rewrite Methodology Chapter
- [x] COMPLETE (2026-04-01) — Reviewed existing draft (no flip contamination), fixed 9 issues: frailty equation (Gaussian), IPTW 3 assumptions enumerated, stale HR example, broken cross-ref, θ notation collision, Fine-Gray accessibility, stat_basis drop documented, three-tier language tightened, hardcoded refs → \ref{}. Writing reviewer: 0 CRITICAL, 0 HIGH remaining.

**WHAT**:
1. **Add plain-English hazard ratio definition** before the first equation — one paragraph explaining what a HR means intuitively ("a hazard ratio of 1.62 means that, at any point in time, post-PSLRA cases face a 62% higher instantaneous rate of dismissal compared to pre-PSLRA cases, holding other factors constant")
2. **Add IPTW section** (new Section 3.5 or 3.6): propensity score estimation, IPTW weighting, assumptions (no unmeasured confounding, positivity, correct specification), balance diagnostics, robust variance estimation. **CRITICAL**: Frame as compositional adjustment, not causal identification. Explicitly discuss why the no-unmeasured-confounding assumption is implausible for a legislative date cutoff and what IPTW actually achieves in this context (see RISK-C1).
3. **Add Shared Frailty section** (new Section 3.6 or 3.7): mixed-effects Cox model, frailty variance interpretation, comparison with fixed effects
4. **Define $\widehat{\text{risk}}_i$** in the C-index equation as "the predicted risk score from the model (e.g., the linear predictor $\hat{\eta}_i = \hat{\boldsymbol{\beta}}^\top \mathbf{X}_i$ for Cox models)"
5. **Remove RSF section** (current Section 3.5) entirely
6. **Remove false Fine-Gray C-index claim** (current lines 244-248)
7. **Update model comparison section** to remove RSF and add IPTW/Frailty diagnostics
8. **Update validation strategy** to note IPTW uses full sample (no train/test for compositional adjustment) while predictive diagnostics (C-index/AUC) use the held-out test set for Cox/Fine-Gray only (see RISK-M2)

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
- "Composition-adjusted" language used in IPTW section; "associated with" elsewhere; never "causally attributable" (RISK-M3)

**RISKS**: IPTW methodology section may be long. Keep it concise — define the estimator, state the assumptions, describe the diagnostics. No textbook-length derivations.

---

#### Task 10 [FIX]: Rewrite Introduction
- [ ] DRAFT-IN-REVIEW — Auto-accepted but rewritten twice. Current version has honest HR range [1.28-1.94], IPTW ≈1.53 headline, settlement hedge, placebo mention. Needs final review.

**WHAT**: Reframe the Introduction around composition-adjusted inference:
1. Replace contribution (iv) — currently RSF — with IPTW composition-adjusted analysis
2. Add contribution about shared frailty / unobserved heterogeneity (as sensitivity analysis)
3. Rewrite the contributions paragraph to lead with: "first application of propensity-score re-weighting to adjust for compositional confounding in securities litigation outcomes"
4. Frame the thesis as moving beyond purely associational estimates by examining how much of the raw PSLRA effect survives compositional adjustment
5. Remove all RSF mentions

**WHY**: The Introduction sets reader expectations. The advisor said the objective is understanding what makes cases settle or dismiss. The IPTW framing must be honest: it adjusts for observable compositional shifts, not all confounders (see RISK-C1).

**INPUTS**: `writing/chapters/intro.tex`, updated methodology (Task 9)

**OUTPUTS**: Updated `intro.tex`

**ACCEPTANCE CRITERIA**:
- Contributions explicitly mention IPTW (framed as compositional adjustment) and frailty (as sensitivity analysis)
- No RSF mentioned
- No over-promising of causal claims — use "composition-adjusted" language
- Still accessible to a non-specialist reader

**RISKS**: Over-promising causal claims. Mitigation: the Introduction should promise "we examine the PSLRA's association with litigation outcomes and assess how robust this association is to compositional adjustment" — not "we prove PSLRA caused X." If IPTW is infeasible (see IPTW Fails contingency), the Introduction must be revised again.

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
- Evidence layer 4: IPTW composition-adjusted HR
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
- "Composition-adjusted" language used for IPTW estimates; "associated with" for Cox/Fine-Gray (see RISK-M3 three-tier language)
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
- Distinguish associational findings (Cox) from composition-adjusted findings (IPTW)

**WHY**: Diagnostics demonstrate rigor. Summary provides the reader a clear takeaway. Both are required by the rubric.

**INPUTS**: R output from `07_diagnostics.R`, `05_causal_iptw.R`, `06_frailty.R`

**OUTPUTS**: Completed `results.tex`

**ACCEPTANCE CRITERIA**:
- Diagnostics section includes at least one Schoenfeld plot
- IPTW balance diagnostics visible (Love plot or balance table)
- Performance table has corrected values (no RSF, proper Fine-Gray C-index)
- Summary explicitly distinguishes composition-adjusted from associational findings
- Total results chapter is shorter than the current version (~500 lines target vs. ~650)

**RISKS**: Diagnostics may reveal issues (PH violations, poor balance). These are findings to report, not problems to hide.

---

#### Task 13 [EXTEND]: Rewrite Discussion & Conclusion/Future Work
- [ ] Not started

**WHAT**:
1. **Update Discussion** (`discussions.tex`):
   - Add section on IPTW composition-adjusted interpretation: what does the composition-adjusted HR tell us that the unadjusted HR didn't?
   - Add section on frailty findings: what does the frailty variance reveal about circuit heterogeneity?
   - Update limitations: remove "we cannot implement frailty models" (we did). Add IPTW assumptions as a limitation.
   - Remove all RSF discussion (current Section 6.5)
   - Update Section 6.6 "Limitations" to reflect current state
   - Enforce three-tier language discipline (RISK-M3): "associated with" for Cox, "after compositional adjustment" for IPTW, never "causally attributable"

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
- Three-tier language discipline enforced throughout (RISK-M3)
- Future Work reads as a proper academic chapter
- Limitations section is accurate and current

**RISKS**: Discussion rewrite depends on finalized IPTW/Frailty results. If IPTW produces unexpected results (attenuated, contradictory, or infeasible — see RISK-H1), the Discussion must handle this gracefully. The "straightforward" assumption holds only if IPTW confirms the existing narrative. *Mitigation*: pre-write Discussion paragraphs for both confirming and disconfirming IPTW scenarios (see RISK-H1 mitigation). Also: removing 2 RSF-dependent Discussion sections may leave gaps in the chapter flow that require new transition paragraphs.

---

#### CHECKPOINT 2 [REVIEW]: Adversarial Thesis Review
- [ ] Not started

**WHAT**: Run `/project:challenge` targeting the FULL thesis (all .tex chapters). Specifically challenge:
- Does the Introduction promise what the Results deliver?
- Is three-tier language discipline enforced? (RISK-M3: "associated with" / "after compositional adjustment" / never "causally attributable")
- Does every number trace to R output?
- Would a skeptical reviewer reach the same conclusions?
- Does the thesis pass the "Drop-In" test at any random page?
- Are all advisor feedback items addressed?

**WHY**: Catch writing errors, logical gaps, and narrative inconsistencies before final polish.

**INPUTS**: All files in `writing/chapters/`

**OUTPUTS**: List of issues found, with fixes applied

**ACCEPTANCE CRITERIA**: All 7 advisor feedback items marked as addressed. No fabricated numbers. Three-tier language discipline enforced. IPTW framing consistent across all chapters (composition-adjusted, not causal).

---

### Phase 4: POLISH

---

#### Task 14 [CREATE]: Write Abstract
- [ ] Not started

**WHAT**: Write a 200-300 word abstract covering:
1. Research question (what determines timing and type of resolution?)
2. Data (12,968 FJC IDB securities class actions, 1990-2024)
3. Methods (competing-risks framework: CIF, Cox, Fine-Gray, IPTW, frailty)
4. Key findings (PSLRA time-varying effect, circuit dominance, IPTW composition-adjusted HR, frailty variance)
5. Implications (policy evaluation of PSLRA, geographic inequality in litigation)
6. Novelty (first application of propensity-score compositional adjustment to securities litigation outcomes)

**WHY**: Rubric requires a complete abstract. Currently placeholder. This is the first thing readers see.

**INPUTS**: Completed results chapter, discussion chapter

**OUTPUTS**: Updated `abstract.tex`

**ACCEPTANCE CRITERIA**:
- 200-300 words
- All 6 elements present
- No numbers that aren't in the results chapter
- Accessible to a non-specialist

**RISKS**: Abstract must reflect finalized results, which are not yet known at writing time. If IPTW fails or contradicts (see contingency sections), the abstract must be revised. *Mitigation*: write the abstract AFTER all Results and Discussion are finalized, not before.

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

| Day | Phase | Tasks | Key Output | Risk Gate |
|---|---|---|---|---|
| 1-2 | Foundation | Tasks 1-4 | Working modular pipeline, verified numbers | |
| 2 | Foundation | Task 5 | RSF pruned, stale outputs deleted | |
| 3 | Causal Build | Task 6 **pre-task** | IPTW conceptual framing decision | **KILL SWITCH**: if IPTW is infeasible, reframe thesis around associational methods + limitations |
| 3-4 | Causal Build | Tasks 6-7 | IPTW + Frailty results | Check: do results confirm, attenuate, or contradict? |
| 4 | Checkpoint | CP1 | Code validated | |
| 5 | Reconstruction | Task 8 + Results skeleton | Updated lit review, Results section headings/placeholders | |
| 5-6 | Reconstruction | Task 9 | Updated methodology | |
| 6 | Reconstruction | Task 10 | Reframed introduction | |
| 7-8 | Reconstruction | Tasks 11-12 | Restructured results | |
| 8-9 | Reconstruction | Task 13 | Updated discussion + future work | |
| 9 | Checkpoint | CP2 | Thesis validated | |
| 10 | **FEATURE FREEZE** | Tasks 14-15 | Abstract, formatting | No new analysis after this point |
| 11 | Polish | Task 16 | Numbers verified | |
| 12 | Checkpoint | CP3 | Final gate | |
| 13 | Buffer | — | Emergency fixes, submission | |

---

## Contingency Triage (If Time Runs Short)

**Cut order** (last to first — cut from the bottom):

1. ~~Task 15 formatting polish~~ — do hyperref + citation fix only, skip figure PDF conversion
2. ~~Task 7 Frailty~~ — if IPTW works, frailty is nice-to-have. Fixed effects + cluster-robust SEs are already implemented. Frame as "future work."
3. ~~Task 8 lit review update~~ — add bib entries and cite them inline, skip the new subsection

**Never cut:**
- Tasks 1-4 (foundation — pipeline must work)
- Task 6 (IPTW — the thesis's analytical centerpiece, even if reframed as composition-adjustment)
- Tasks 10-12 (Results restructure + Introduction reframe — advisor's explicit asks)
- Task 14 (Abstract — rubric requirement)
- Task 16 (Number verification — academic integrity)

## Contingency: IPTW Fails Entirely

If the Day 3 kill-switch fires — IPTW is infeasible (no overlap, extreme weights, balance impossible) — the thesis still has a strong submission path:

**Fallback thesis framing**: "A competing-risks survival analysis framework reveals strong associational evidence for PSLRA effects, with important limitations for causal interpretation. We document that compositional adjustment via IPTW is infeasible due to extreme covariate imbalance across the pre- and post-reform periods, identifying this as a fundamental challenge for causal evaluation of structural legal reforms."

**What changes**:
- Introduction: contributions are (1) first competing-risks framework for securities litigation, (2) evidence of time-varying PSLRA effects, (3) documentation of geographic disparity, (4) demonstration that IPTW causal identification is infeasible in this setting + explanation of why
- Methodology: IPTW section becomes shorter — describe the approach, state assumptions, document the failure and why
- Results Section 5.2: replace "IPTW composition-adjusted HR" with "IPTW feasibility assessment" — report propensity score overlap failure, balance diagnostics, and explain what this means
- Discussion: the infeasibility itself becomes a finding about the limits of quasi-experimental methods for evaluating structural legal reforms

**What stays the same**: Everything in Phases 1, 3 (except IPTW-specific content), and 4. The thesis is still strong on descriptive analysis, Cox modeling, Fine-Gray, piecewise effects, circuit analysis, and robustness checks. The grade ceiling drops from A to A-/B+ but the thesis is still defensible and honest.

## Contingency: IPTW Contradicts Cox

If IPTW dramatically attenuates or reverses the PSLRA HR:

**Reframing**: The thesis becomes STRONGER, not weaker. The finding is: "Naive Cox estimates of legislative effects are confounded by temporal changes in case composition. The raw PSLRA dismissal HR of 1.64 is inflated by [X%] due to concurrent shifts in circuit distribution, case origins, and statutory bases. This highlights a systematic bias in the existing securities litigation literature, which uniformly reports unadjusted estimates."

This is a more interesting paper than "IPTW confirms what Cox already showed."
