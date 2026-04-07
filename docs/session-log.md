# Thesis State — Phase 4 Final Verification

> Last updated: 2026-04-07.
> Current code-side source of truth for this thesis.
> All numbers below come from the full post-recode rerun on 2026-04-07.
> The LaTeX chapters have not yet been updated to match these refreshed outputs.

---

## 1. Pipeline Status

**Phase 1 (Foundation): CLOSED** — Tasks 1-5 complete.  
**Phase 2 (Causal Build): CLOSED** — Tasks 6-7 complete.  
**Checkpoint 1: CLOSED** — Initial full code audit and rebuild completed on 2026-04-01.  
**Phase 3 (Chapter Reconstruction): CLOSED** — Tasks 8-13 complete.  
**Checkpoint 2: CLOSED** — Full chapter `/challenge` pass completed on 2026-04-05.

**Checkpoint 3: CODE-SIDE REVALIDATION COMPLETE (refreshed again on 2026-04-07)**  
The full analysis pipeline was rerun after fixing:
- judgment-bearing disposition miscoding in `01_clean.R`
- global censoring of `DISP=18` (statistical closing)
- global collapse of `origin_cat == "Removed"` into `"Other"`
- Fine-Gray subject-level clustering with `case_id`
- diagnostics AUC figure y-axis truncation that dropped the 5-year Fine-Gray settlement point
- modular-script cwd bootstrapping so the pipeline is runnable from outside the repo root
- IPTW Row 3 relabeling to "Weighted + Covariates (Regression-Adjusted IPTW)"
- trimmed-weight kill-switch reporting in `05_propensity_scores.R`
- removal of stale RDD / identification framing in robustness utilities

**Phase 4 (Polish): IN PROGRESS**
- Task 14 (Abstract): COMPLETE
- Task 15 (Formatting): COMPLETE
- Task 16 (Final Number Verification): IN PROGRESS

**Current blocker before submission:** propagate the refreshed code outputs into LaTeX, then run the final thesis-level `/review` and `/challenge` pass on the `.tex` files.

---

## 2. Immutable Methodological Decisions

### Data Pipeline
- **Cohort**: 12,968 securities class actions (NOS 850), 1990-2024, from FJC IDB.
- **Pipeline counts**: 65,899 → 13,708 (NOS 850 filter) → 12,968 (valid duration and usable disposition coding).
- **Dropped administrative artifacts**: zero-duration cases only; no substantive selection change.

### Judgment-Bearing Disposition Coding (CRITICAL, 2026-04-06)
For FJC judgment-bearing dispositions, the thesis now uses the `JUDGMENT` field consistently:
- `disp %in% {4, 6, 15, 17, 19, 20}` and `JUDGMENT = 1` → **Settlement**
- `disp %in% {4, 6, 15, 17, 19, 20}` and `JUDGMENT = 2` → **Dismissal**
- `disp %in% {4, 6, 15, 17, 19, 20}` and ambiguous/missing `JUDGMENT` → **Censored**
- `disp = 18` (statistical closing) → **Censored** in all schemes

This supersedes the earlier narrower Code 6-only disaggregation.

### Disposition Schemes
- **Scheme A (primary)**: 3,801 settlement / 5,971 dismissal / 3,196 censored  
  `29.3% / 46.0% / 24.6%`
- **Scheme B**: 5,605 settlement / 4,167 dismissal / 3,196 censored
- **Scheme C**: 5,919 settlement / 4,167 dismissal / 2,882 censored

### Covariate Decisions
- `ext_formula_rhs`: `post_pslra + circuit_f + origin_cat + mdl_flag + juris_fq + stat_basis_f`
- `stat_basis_f` missing values are retained as explicit `"Missing"` when coverage is adequate
- `mdl_flag` remains excluded from the propensity score model because pre-PSLRA MDL cases are structurally absent
- `origin_cat == "Removed"` is collapsed into `"Other"` globally in `01_clean.R` so Cox, Fine-Gray, IPTW, frailty, and diagnostics all use the same factor structure
- Performance models still omit `stat_basis_f` when needed to avoid complete separation in train/test diagnostics
- Interaction models omit `stat_basis_f` because of thin interaction cells

### IPTW Design
- **Estimand**: ATT
- **Trim rule**: 99th percentile cap on pre-PSLRA weights (`trim_cap ≈ 43.54`)
- **ESS after trimming**: 577.6 pre-PSLRA, 11,835 post-PSLRA
- **Balance**: all 20 adjusted balance rows were under `|SMD| < 0.1`
- **Consistency guardrail**: manual ATT weights are now asserted equal to the trimmed `WeightIt` weights used in the Love plot

### Frailty Design
- `coxme::coxme()` with Gaussian random intercept `(1 | circuit_f)`
- 11 usable circuit clusters; treat frailty as a sensitivity analysis, not the primary estimator
- Extended comparison tables now use the same `ext_formula_rhs` metadata as `03_cox_models.R`

### Fine-Gray / Diagnostics
- `case_id` is created in `01_clean.R` and carried into `finegray()` data
- downstream Fine-Gray `coxph()` fits now use `cluster = case_id`
- `fig_auc_over_time` now lowers its y-axis below `0.4` when needed so low AUC values are not silently dropped

### Time-Trend Specification
- Linear `filing_year` remains banned
- Only the spline robustness specification `ns(filing_year, df = 3)` is used

---

## 3. Current Authoritative Results (2026-04-07 Rerun)

### Baseline Cox (PSLRA only)
| Outcome | HR | 95% CI | p |
|---|---|---|---|
| Settlement | 0.563 | [0.511, 0.621] | < 0.001 |
| Dismissal | 1.409 | [1.269, 1.565] | < 0.001 |

### Extended Cox (full covariates)
| Outcome | HR | 95% CI | p |
|---|---|---|---|
| Settlement | 0.784 | [0.709, 0.867] | < 0.001 |
| Dismissal | 1.661 | [1.493, 1.847] | < 0.001 |

### Piecewise Cox (Dismissal, time-varying PSLRA effect)
| Period | HR | p |
|---|---|---|
| 0-1 years | 1.789 | < 0.001 |
| 1-2 years | 1.255 | 0.035 |
| 2+ years | 1.063 | 0.510 |

### IPTW Triangulation (composition-adjusted)
| Row | Strategy | Settlement HR | Dismissal HR | 95% CI |
|---|---|---|---|---|
| 1 | Unadjusted | 0.557 | 1.414 | `0.505--0.615`, `1.273--1.570` |
| 2 | Regression-Adjusted | 0.784 | 1.661 | `0.709--0.867`, `1.493--1.847` |
| 3 | Weighted + Covariates (Regression-Adjusted IPTW) | 0.780 | 1.754 | `0.682--0.892`, `1.549--1.987` |
| 4 | **MSM (IPTW only)** | **0.741** | **1.519** | `0.632--0.868`, `1.335--1.729` |

All eight IPTW comparison rows remain statistically significant.

### Frailty / Cluster-Robust Sensitivity
- **Settlement frailty variance**: baseline `θ = 0.2192`, extended `θ = 0.1296`
- **Dismissal frailty variance**: baseline `θ = 0.1643`, extended `θ = 0.0397`
- **Extended cluster-robust settlement Cox**: `HR = 0.784`, `95% CI = [0.559, 1.099]`, `p = 0.158`
- **Extended cluster-robust dismissal Cox**: `HR = 1.661`, `95% CI = [1.298, 2.126]`, `p < 0.001`
- FE vs RE PSLRA deltas remain near zero, as expected for a national treatment indicator

### Fine-Gray (Subdistribution)
- **Extended settlement SHR**: `0.503` `[0.452, 0.560]`, `p < 0.001`
- **Extended dismissal SHR**: `1.719` `[1.549, 1.908]`, `p < 0.001`
- **PH tests on Fine-Gray fits**:
- Settlement `post_pslra`: `p = 1.25e-13`
- Dismissal `post_pslra`: `p = 5.97e-04`

### Robustness (7 specifications)
| Specification | Settlement HR | Dismissal HR |
|---|---|---|
| Scheme A | 0.563 | 1.409 |
| Scheme B | 0.799 | 1.183 |
| Scheme C | 0.788 | 1.183 |
| Exclude post-2020 | 0.558 | 1.333 |
| Second Circuit only | 1.052 | 1.941 |
| Ninth Circuit only | 0.957 | 1.575 |
| Spline time trend | 0.714 | 3.515 |

Headline robustness ranges:
- **Settlement HRs**: `[0.558, 1.052]`
- **Dismissal HRs**: `[1.183, 3.515]`

### Diagnostics / Performance
| Model | C-index | AUC @ 1yr | AUC @ 3yr | AUC @ 5yr | IBS |
|---|---|---|---|---|---|
| Cox (Settlement) | 0.679 | 0.732 | 0.705 | 0.793 | 0.1212 |
| Cox (Dismissal) | 0.597 | 0.595 | 0.643 | 0.775 | 0.1842 |
| Fine-Gray (Settlement) | 0.555 | 0.659 | 0.531 | 0.377 | NA |
| Fine-Gray (Dismissal) | 0.595 | 0.592 | 0.633 | 0.770 | NA |

PH tests on extended Cox models:
- Settlement GLOBAL: `χ² = 597.4`, `p < 0.001`
- Dismissal GLOBAL: `χ² = 361.8`, `p < 0.001`

---

## 4. Active Writing Constraints

### Three-Tier Language Discipline
1. **"Associated with"** for Cox and Fine-Gray
2. **"Composition-adjusted"** or **"after adjusting for observable case composition"** for IPTW
3. **Never** write "causally attributable to" in this thesis

### Headline Numbers to Use
- Lead dismissal claims with **IPTW MSM dismissal HR ≈ 1.52**, not the spline extreme
- Report the current dismissal robustness range as **`[1.18, 3.52]`**
- Report the current settlement robustness range as **`[0.56, 1.05]`**
- Settlement attenuation language must reflect the new pattern:
- still below 1 in the spline model (`HR = 0.714`, `p = 0.013`)
- not significant in the Second Circuit (`HR = 1.052`, `p = 0.762`)
- not significant in the Ninth Circuit (`HR = 0.957`, `p = 0.622`)
- Extended cluster-robust settlement is now non-significant (`p = 0.158`)

### Interpretation Rules
- IPTW is still a decomposition of observable case composition changes, not a clean causal estimate
- Frailty is still a sensitivity analysis with only 11 clusters
- Constant-HR models remain time-averaged summaries because PH is violated
- Fine-Gray discrimination remains weaker than Cox for settlement and should be reported honestly

### Known Stale `.tex` Content After the 2026-04-07 Rerun
These files now require number updates before submission:
- `writing/chapters/abstract.tex`
- `writing/chapters/introduction.tex`
- `writing/chapters/methodology.tex`
- `writing/chapters/data.tex`
- `writing/chapters/results.tex`
- `writing/chapters/discussion.tex`
- `writing/chapters/conclusion.tex`

Specific stale themes:
- old Scheme A event shares (`20.9 / 67.3 / 11.7`)
- old baseline and extended Cox numbers (`0.445`, `1.468`, `0.702`, `1.751`)
- old Fine-Gray numbers (`0.454`, `1.864`)
- old robustness range (`[1.32, 2.45]` dismissal; `[0.44, 0.98]` settlement)
- any prose implying extended cluster-robust settlement remains significant

---

## 5. Task 16 Remaining Work

### Immediate
- propagate all refreshed code numbers into the LaTeX chapters
- update disposition-coding prose to reflect the broader `JUDGMENT` use and `DISP=18` censoring
- update any results/discussion text that still describes the old robustness range or old headline HRs

### Then
- run `/review` on the LaTeX files
- run `/challenge` on the LaTeX files
- resolve any last citation, coherence, or number-integrity issues

### Final Non-Code Item
- `writing/chapters/acknow.tex` is still a placeholder and needs Andrew's personal text

---

## Session: 2026-04-06 Code-Side Revalidation

### What Changed
- `01_clean.R`: fixed judgment-bearing dispositions `{4, 6, 15, 17, 19, 20}`, censored `DISP=18`, added `case_id`, and collapsed `origin_cat == "Removed"` globally
- `04_fine_gray.R` / `07_diagnostics.R`: added subject-level clustering with `cluster = case_id`
- `05_causal_iptw.R`: removed stale reminder, asserted manual ATT weights equal `WeightIt` weights
- `05_propensity_scores.R`: now mirrors `include_stat` logic from the main IPTW script
- `06_frailty.R`: now reuses saved extended-formula metadata and uses consistent CI extraction
- `07_diagnostics.R`: AUC figure now includes low values without dropped-row warnings
- auxiliary scripts cleaned: `code_event()` in `utils.R` now reflects current Scheme A logic, `verify_dismissal_flip.R` no longer assumes a `"Removed"` origin level, `judgment_diagnostic.R` now verifies the current coding instead of the old bug state, and `InterimScript.R` is hard-stopped as historical-only
- `.claude/rules/r-coding.md`: added recurrence-prevention rule for FJC disposition coding

### Full Rerun Completed
`01_clean -> 02_descriptives -> 03_cox_models -> 04_fine_gray -> 05_causal_iptw -> 05_propensity_scores -> 06_frailty -> 07_diagnostics -> 08_robustness`

### Current Source Hierarchy for Future Sessions
1. `docs/session-log.md` — current authoritative results and writing constraints
2. `CLAUDE.md` — high-level project framing and current core outputs
3. `output/models/*.rds` and `output/tables/*.tex` — artifact-level ground truth
4. `docs/verification-report.md` — historical only, now superseded for code-side numbers
5. Do not use `code/InterimScript.R` as a source of logic or numbers; it is intentionally disabled

---

## Session: 2026-04-07 Final Output Refresh

### What Changed
- reran the full authoritative analysis pipeline again: `01_clean -> 02_descriptives -> 03_cox_models -> 04_fine_gray -> 05_propensity_scores -> 05_causal_iptw -> 06_frailty -> 07_diagnostics -> 08_robustness`
- reran auxiliary sanity-check utilities: `verify_dismissal_flip.R`, `inspect_data.R`, and `code/utils/judgment_diagnostic.R`
- refreshed the final diagnostics outputs after letting `07_diagnostics.R` complete its long `timeROC` / `pec` stage
- updated handoff documents and `.claude` review/challenge guidance so the next session does not inherit stale "Doubly Robust", `RDD`, or causal-identification language

### Output Freshness Check
- all files in `output/figures/` now carry 2026-04-07 timestamps
- `output/tables/tab_model_performance.tex` refreshed at `2026-04-07 11:42:47`
- key model artifacts refreshed on 2026-04-07:
  - `output/models/cox_models.rds`
  - `output/models/fine_gray_models.rds`
  - `output/models/iptw_results.rds`
  - `output/models/frailty_results.rds`
  - `output/models/robustness_results.rds`

### New-Session Read Order
1. `CLAUDE.md`
2. `docs/session-log.md`
3. `docs/execution-plan.md`
4. `docs/verification-report.md` only for historical context, not current numbers
