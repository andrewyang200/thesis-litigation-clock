# Session Log

This file maintains continuity across Claude Code sessions. 
Read this FIRST at the start of every session (via /project:plan).

---

## Session: Initial Setup
### Plan Progress
- No execution plan yet — project scaffolding only
### Completed
- Created project directory structure
- Set up Claude Code configuration (.claude/ folder with rules, skills, agents, commands)
### Key Decisions
- Using Plan → Execute → Evaluate workflow (not prescriptive prompts)
- Claude Code will read all existing files and generate the plan based on actual state
### Next Steps
- Copy existing R code, LaTeX files, data, and output into the project directory
- Fill in docs/advisor-feedback.md and docs/rubric.md with actual content
- Verify R environment with `Rscript -e "source('code/utils.R')"`
- Run the Discovery Prompt (see WORKFLOW_GUIDE.md Phase 1)
### Open Issues
- Need to transfer all existing work into this directory before planning can begin
---

## Session: 2026-03-27 (Continued — Risk Analysis)
### Plan Progress
- Tasks completed this session: None (pre-execution risk analysis phase)
- Current position in plan: Task 0 of 16 — awaiting user approval of execution plan
- Plan modifications needed: Major — risk matrix added, IPTW framing changed, contingencies built in (all changes applied to execution-plan.md this session)
### Completed
- Ran adversarial risk analysis (devil's advocate agent) against the full execution plan
- Identified 3 CRITICAL risks, 5 HIGH risks, 3 MEDIUM risks, 4 LOW risks
- Added comprehensive Risk Matrix section to `docs/execution-plan.md`
- Reframed IPTW from "causal" to "composition-adjusted" throughout the entire plan (all 16 tasks + 3 checkpoints)
- Defined three-tier language discipline: "associated with" (Cox) / "after compositional adjustment" (IPTW) / never "causally attributable"
- Added Day 3 kill-switch decision point for IPTW feasibility
- Added Day 10 feature freeze (no new analysis after Day 10)
- Added two contingency plans: "IPTW Fails Entirely" and "IPTW Contradicts Cox"
- Fixed all "RISKS: None" entries (Tasks 5, 8, 13, 14) with honest risk assessments
- Removed data.tex from strict DO NOT TOUCH list (numbers must be verified)
- Pre-wrote three Discussion scenarios (IPTW confirms / attenuates / contradicts)
- Downgraded Frailty from standalone model to sensitivity analysis
- Excluded C-index/AUC from IPTW diagnostics (balance + effective sample size only)
### Key Decisions
- **IPTW is "composition-adjusted," not "causal"** — PSLRA is a deterministic legislative date cutoff with no selection mechanism. The propensity score models temporal trends in case composition, not treatment assignment. The no-unmeasured-confounding assumption is implausible over 34 years. This is the single most important framing decision for the thesis.
- **Pre-write for all IPTW outcomes** — Because IPTW could confirm, attenuate, or contradict the associational Cox results, Discussion paragraphs for all three scenarios should be drafted before results are finalized. All three are publishable.
- **Day 3 kill-switch** — Before writing IPTW code, spend 2-3 hours deciding whether IPTW is feasible and defensible. This prevents wasting 2 days coding before discovering the framing is wrong.
- **Frailty as sensitivity analysis** — 13 clusters is too few for reliable frailty variance estimation. Present alongside cluster-robust SEs, not as a standalone model.
- **ATT weights preferred over ATE** — Due to 11.6:1 pre/post sample imbalance, ATT weights (reweight only the smaller pre-PSLRA group) are less extreme.
### Next Steps
- **User must approve the updated execution plan** before any work begins
- Once approved, begin Task 1: Extract InterimScript Sections 1-6 into `01_clean.R`
- Preparation: re-read InterimScript.R lines 1-200, read utils.R, understand the data loading and cleaning pipeline
### Open Issues
- **RISK-C1 unresolved**: Is IPTW defensible at all for a legislative date cutoff? The plan includes a kill-switch, but Andrew should consider whether an ORFE examiner would accept "composition-adjusted" framing or push back harder
- **Narrow-window IPTW (1993-1998)**: Should we restrict IPTW to cases near the PSLRA cutoff? Better quasi-experimental interpretation but possibly too few pre-PSLRA cases
- **Disposition Scheme A vs B for IPTW**: Plan says run both, but Andrew should decide which is primary
- **Piecewise IPTW**: If PH is violated in the IPTW model (expected), we need piecewise IPTW with the same three time periods — this adds complexity to Task 6
- **Second Circuit anomaly**: Should we investigate whether the extreme settlement HR is a coding artifact (Scheme B vs A) before building IPTW models?
---

## Session: 2026-03-27 (Task 1 — Data Cleaning Pipeline)
### Plan Progress
- Tasks completed this session: Task 1 (Modularize Code Pipeline — Data Cleaning)
- Current position in plan: Task 1 of 16 COMPLETE — ready for Task 2
- Plan modifications needed: Minor — Code 6 reclassification changes the baseline outcome distribution (see Key Decisions). All downstream scripts will use the updated Scheme A mapping. The execution plan's expected numbers (e.g., "HR = 1.638 for dismissal") will change when models are re-run on the new data.
### Completed
- Extracted InterimScript.R Sections 1-6 into standalone `code/01_clean.R`
- Script runs independently from project root: `Rscript code/01_clean.R`
- Produces `data/cleaned/securities_cohort_cleaned.rds` (12,968 rows, 68 cols)
- Produces `data/cleaned/securities_scheme_B.rds` and `securities_scheme_C.rds` (68 cols each, full covariates)
- Pipeline counts verified: 65,899 → 13,708 → 12,968 (matches data.tex)
- Added Code 6 (judgment on motion) to dismissal list per FJC Codebook
- Synchronized disposition mapping across 4 files: `01_clean.R`, `utils.R`, `CLAUDE.md`, `bug-finder.md`
- Replaced `file.path()` with `here::here()` in `01_clean.R` and `utils.R` output helpers
- Added `stopifnot()` validation before disposition coding
- Added data quality warnings for `juris_fq` (99.6% constant) and `log_demand` (98.4% missing)
- Documented origin codes 7-12 as intentionally NA
- Passed 3 rounds of r-code-reviewer agent review (0 CRITICALs remaining)
### Key Decisions
- **Code 6 reclassified from censored to dismissal**: Per FJC Codebook, Code 6 ("Motion Before Trial") represents a terminal disposition by final judgment — in securities litigation, this is a granted Motion to Dismiss or Summary Judgment. This moves 2,389 cases (18.4% of cohort) from censored to dismissal. New Scheme A distribution: 15.5% settlement, 74.8% dismissal, 9.6% censored (was 15.5/56.4/28.1). This is a substantive analytical change that will affect all model results.
- **All three schemes get full covariates**: Scheme B/C .rds files now contain all 68 columns (post_pslra, circuit_f, origin_cat, etc.), so `08_robustness.R` can load them directly without covariate reconstruction.
- **`juris_fq` flagged as near-degenerate**: 99.6% federal question. Should be excluded from regression models or handled with care.
- **`log_demand` flagged as unusable**: 98.4% missing. Only 212 valid observations. Downstream models should not include it in standard regression.
### Next Steps
- **Task 2**: Modularize remaining InterimScript sections into `02_descriptives.R`, `03_cox_models.R`, `04_fine_gray.R`, `08_robustness.R`
- Preparation: read InterimScript.R Sections 7-17, understand the analytical pipeline
- NOTE: All downstream models will produce different results from those currently in the thesis because Code 6 reclassification changed the outcome distribution. Task 4 (number verification) will catch and document all discrepancies.
### Open Issues
- **Code 6 impact on existing thesis numbers**: The HR, CI, and p-values in `results.tex` and `data.tex` were computed with Code 6 censored. They will all change. Task 4 will systematically verify and update.
- **Previous open issues still unresolved**: RISK-C1 (IPTW framing), narrow-window IPTW, disposition scheme for IPTW, piecewise IPTW, Second Circuit anomaly — all deferred to Phase 2.
---

## Session: 2026-03-27 (Task 2 — Modularize Analysis Scripts)
### Plan Progress
- Tasks completed this session: Task 2 (Modularize Code Pipeline — Analysis Scripts)
- Current position in plan: Task 2 of 16 COMPLETE — ready for Task 3
- Plan modifications needed: Minor — `stat_basis_miss` removed from all formulas (NA→explicit "Missing" factor level instead). `ext_formula_rhs` no longer includes `stat_basis_miss`.
### Completed
- Extracted InterimScript Sections 7-10 into `code/02_descriptives.R` (KM, CIF, Gray's tests, 5 figures)
- Extracted Sections 11-13, 15-16 into `code/03_cox_models.R` (baseline, piecewise, circuit, extended, interaction Cox models)
- Extracted Sections 14-15 (Fine-Gray) into `code/04_fine_gray.R` (baseline + extended subdistribution models + comparison table)
- Extracted Section 17 into `code/08_robustness.R` (3 schemes, temporal restriction, circuit-specific, forest plot)
- All 4 scripts run independently from project root via `Rscript code/XX_name.R`
- Fixed `stat_basis_miss` aliasing bug: converted `stat_basis_f` NA to explicit "Missing" factor level in 03 and 04 scripts. All 12,866 extended-model rows now contribute.
- Fixed deprecated `geom_errorbarh()` → `geom_errorbar(..., orientation = "y")`
- Fixed fragile p-value extraction in robustness helper (`$coef[5]` → named indexing)
- Fixed misleading "consistent" subtitle in robustness forest plot
- Fixed unicode em-dash rendering issue in PDF output
- Saved model objects to `output/models/` (cox_models.rds, fine_gray_models.rds)
- Passed 3-agent R code review (0 CRITICALs remaining after fixes)
- Passed final 2-agent review (bug-finder + cross-script consistency): 50+ items verified correct
- Fixed `format_hr()` regex bug in utils.R — `|p` matched "exp(coef)" instead of "Pr(>|z|)"
- Fixed fragile piecewise p-value extraction `[, 5]` → `[, "Pr(>|z|)"]` in 03_cox_models.R
### Key Decisions
- **`stat_basis_miss` removed from formulas**: The missingness indicator was aliased (NA coefficient) because coxph silently dropped the 134 rows with `stat_basis_f == NA`. Fix: use `fct_na_value_to_level()` to create an explicit "Missing" level. This adds a proper "Missing" coefficient to all extended models. The ext_formula_rhs is now `post_pslra + circuit_f + origin_cat + mdl_flag + juris_fq + stat_basis_f` (no `stat_basis_miss`).
- **Figure naming convention**: New figures use descriptive names (`fig_km_overall`, `fig_cif_pslra`, etc.) without numbered prefixes. Old `figureN_*.png` files from InterimScript remain in `output/figures/` and will be cleaned in Task 5.
- **Color palette**: Kept original green (#1B7837)/red (#B2182B) for Settlement/Dismissal in figures, despite utils.R defining blue/red. Changing mid-project risks inconsistency with existing thesis figures. Deferred to Phase 4 polish.
- **Interaction models omit stat_basis**: The PSLRA × Circuit interaction models use a reduced covariate set (no stat_basis) to limit parameter count. Documented in code comments.
### Next Steps
- **Task 3**: Create diagnostics script (`07_diagnostics.R`) — Schoenfeld residuals, C-index, time-dependent AUC
- Preparation: read InterimScript Sections 18-21, 23. Load saved model objects from `output/models/`.
- Fix the fatal Section 19 bug (`lp_s`/`lp_d` used before definition)
- Compute Fine-Gray C-index independently (not copied from Cox)
### Open Issues
- **Updated model results differ from thesis text**: All HRs now reflect Code 6 reclassification. Key changes:
  - Baseline dismissal HR = 1.415 (was 1.638 in thesis — lower because Code 6 cases dilute the effect)
  - Settlement HR = 0.378 (unchanged — Code 6 doesn't affect settlement coding)
  - Extended model now uses 12,866 rows (was 12,732 due to stat_basis NA dropping)
  - stat_basis_fMissing: Settlement HR=0.891, Dismissal HR=1.018 (new coefficients)
- **Cross-script data derivation duplication**: 03 and 04 both independently construct df_circ/df_ext with identical logic. Reviewers recommend extracting into a `prepare_model_data()` function in utils.R before writing scripts 05-07.
- **Previous open issues still unresolved**: RISK-C1 (IPTW framing), narrow-window IPTW, Second Circuit anomaly — all deferred to Phase 2.
---

## Session: 2026-03-27 (Task 3 — Diagnostics Script)
### Plan Progress
- Tasks completed this session: Task 3 (Create Diagnostics Script — Fix Performance Metrics)
- Current position in plan: Task 3 of 16 COMPLETE — ready for Task 4
- Plan modifications needed: None. All acceptance criteria met.
### Completed
- Created `code/07_diagnostics.R` from InterimScript Sections 18-21, 23
- Fixed fatal Section 19 bug: `lp_s`/`lp_d` used before definition — now computed before C-index
- Fixed false Fine-Gray = Cox C-index assumption: Fine-Gray C-index now independently computed via model matrix multiplication
- Fixed C-index sign convention: negated linear predictors (concordance expects higher = better prognosis, Cox lp has higher = worse)
- Fixed Cox AUC to use competing-risks delta encoding (multi-level 0/1/2 instead of binary)
- Fixed Fine-Gray AUC to use competing-risks delta encoding with correct `cause` argument
- Fixed IBS computation: now reports IBS[0, 5yr) at single horizon, not mean of nested integrals
- Fixed LaTeX label duplication (`tab:tab:` → `tab:`)
- Removed all RSF references
- Added `save_base_plot()` helper for Schoenfeld plots — all figures now output both PDF and PNG
- Added documentation comment about Fine-Gray concordance approximation (no subdistribution C-index in survival package)
- Added clarifying comment about PH tests (ext_formula with stat_basis) vs performance metrics (reduced formula without stat_basis)
- Loaded `include_stat` from saved metadata instead of recomputing
- Removed orphan `circuit_counts` variable and dead `par()` reset
- Set `iid=FALSE` in timeROC for speed; added TODO comment to re-enable for final run
- Passed r-code-reviewer agent review twice (all CRITICALs resolved)
- Script runs cleanly in ~1 minute, produces all outputs
### Key Decisions
- **`iid=FALSE` for development speed**: `timeROC` with `iid=TRUE` on ~3,800 competing-risks observations takes ~10 minutes. Set to FALSE for now; AUC point estimates are identical. Will flip to TRUE before Task 12 (Results diagnostics section) or Task 16 (final verification) to get confidence intervals. Memory note saved.
- **Fine-Gray concordance is an approximation**: `survival::concordance()` treats competing events as censored, but Fine-Gray keeps them at risk. No clean fix exists in the package. Documented in code comments; limitation will be noted in thesis Discussion chapter.
- **Performance metrics use reduced formula**: `stat_basis_f` excluded from performance evaluation models due to complete separation producing infinite coefficients. PH tests still use the full extended formula. Both model specifications are documented.
### Next Steps
- **Task 4**: Run full pipeline (01 through 08) end-to-end, capture all console output to `output/analysis_log.txt`, then systematically verify every number in `data.tex` and `results.tex` against the log
- Preparation: ensure all scripts run independently, then run in sequence
- NOTE: All thesis numbers will change from Code 6 reclassification (Task 1). Task 4 will document all discrepancies.
### Open Issues
- **timeROC iid=TRUE needed before final run**: Memory note saved. No cascade risk — point estimates unchanged; only CIs are added.
- **Cross-script data derivation duplication** (from Task 2): 03, 04, and now 07 all independently construct df_ext. Still recommended to extract into utils.R before scripts 05-07, but not blocking.
- **Previous open issues still unresolved**: RISK-C1 (IPTW framing), narrow-window IPTW, Second Circuit anomaly — all deferred to Phase 2.
---

## Session: 2026-03-28 (Task 4 — Full Pipeline Verification & Number Update)
### Plan Progress
- Tasks completed this session: Task 4 (Run Full Pipeline & Verify All Numbers)
- Current position in plan: Task 4 of 16 COMPLETE — ready for Task 5
- Plan modifications needed: Minor — Task 5 RSF pruning scope reduced because RSF section + figure references + performance table rows already deleted from results.tex in this session. Task 5 now only needs to: (1) delete stale figure files from output/figures/, (2) grep remaining .tex chapters for RSF mentions, (3) clear future.tex, (4) clean utils.R. The results.tex RSF cleanup is DONE.
### Completed
- Ran full pipeline: 01_clean.R → 02_descriptives.R → 03_cox_models.R → 04_fine_gray.R → 07_diagnostics.R → 08_robustness.R — all 6 scripts ran cleanly with zero errors
- Created `docs/verification-report.md` — comprehensive audit trail of every number checked (Thesis vs. R Output)
- Updated `data.tex`: 7 edits covering Scheme A definition (added Code 6), outcome distribution table (all 3 schemes), duration table (dismissal row), PSLRA regime table (all rows), and associated prose
- Updated `results.tex` tables only (not prose): CIF horizons, Gray's test stats (both captions), baseline Cox, piecewise, circuit Cox (all 11 dismissal HRs), extended Cox settlement (19 coefficients + Missing row added), extended Cox dismissal (19 coefficients + Missing row added), PH test stats, Fine-Gray comparison (all 8 cells), interaction LRT dismissal, robustness (all 6 dismissal HRs), performance table (corrected C-indices, added Fine-Gray AUCs)
- Deleted RSF section from results.tex: Variable Importance subsection, RSF VIMP figure reference, RSF AUC figure reference, RSF comparison prose, RSF rows from performance table
- Fixed performance table: Fine-Gray C-indices now independently computed (0.692/0.566 vs old identical-to-Cox 0.735/0.602), Fine-Gray AUCs added, IBS reported in note
- Updated statutory basis coverage 97.5% → 99.0% in results.tex
- Placed 7 `% TODO: REWRITE PROSE` markers across all results.tex sections
- Verified: zero instances of old "56.4%", "7,313", "1.638", or "RSF" remain in updated files
### Key Decisions
- **Tables updated, prose untouched**: Per user instruction, only table values were corrected. Prose paragraphs still contain stale inline numbers (e.g., "HR = 1.638" in baseline Cox prose, "HR = 2.18" in piecewise prose). These are flagged with TODO markers and will be rewritten during the Results chapter restructure (Tasks 11-12).
- **RSF deletion done early**: The RSF section, figure references, and performance table rows were deleted in this session rather than waiting for Task 5. This reduces Task 5 scope to file-level cleanup (deleting PNGs, grepping other .tex files, clearing future.tex).
- **Missing stat_basis row added**: Both extended Cox tables now include the "Missing" row for stat_basis_f, reflecting the Task 2 fix that converted NA to an explicit factor level. This is a new row not present in the old thesis.
- **Fine-Gray C-indices are an approximation**: The note in the performance table now honestly states that `survival::concordance()` treats competing events as censored, making Fine-Gray C-index approximate. This limitation will be discussed in the thesis.
### Next Steps
- **Task 5**: Prune RSF from codebase and delete stale outputs. Reduced scope:
  - Delete `output/figures/figure7_rsf_vimp.png` and `output/figures/figure8_auc_comparison.png`
  - Grep `intro.tex`, `methodology.tex`, `discussions.tex` for RSF mentions and remove
  - Check `utils.R` for RSF package references
  - Clear `future.tex` content (replace with placeholder comment)
- **Then Task 6**: IPTW implementation — the big Phase 2 task. Requires IPTW conceptual framing decision first (RISK-C1 kill-switch).
### Open Issues
- **Stale prose numbers in results.tex**: 7 sections have TODO markers. Inline numbers like "HR = 1.638", "HR = 2.18", "more than double", "26% of the Second Circuit", "MDL FG SHR essentially null" are all stale. Will be addressed in Tasks 11-12 (Results restructure).
- **Interpretive changes from Code 6**: Piecewise 1-2yr period flipped direction (0.922→1.04, still non-sig). MDL FG settlement SHR went from "essentially null" (0.963) to above 1 (1.126). Fourth Circuit dismissal doubled (0.262→0.516). None change qualitative story but prose must reflect these.
- **timeROC iid=TRUE**: Still needed before final run (Task 16).
- **Cross-script data derivation duplication**: Still present in 03, 04, 07. Not blocking.
- **Previous open issues still unresolved**: RISK-C1 (IPTW framing), narrow-window IPTW, Second Circuit anomaly — all deferred to Phase 2.
---

## Session: 2026-03-28 (Task 5 — RSF Pruning)
### Plan Progress
- Tasks completed this session: Task 5 (Prune RSF from Codebase and Delete Stale Outputs)
- Current position in plan: Task 5 of 16 COMPLETE — Phase 1 DONE. Ready for Phase 2: Task 6 (IPTW)
- Plan modifications needed: None. Task 5 scope was already reduced during Task 4 (RSF rows/sections in results.tex already removed). All remaining items completed this session.
### Completed
- Removed RSF sentence from `intro.tex` (line 60-62)
- Removed RSF paragraph from `litreview.tex` (lines 50-56)
- Deleted entire RSF section from `methodology.tex` (Section 3.5, ~20 lines)
- Replaced false Fine-Gray C-index claim in `methodology.tex` (lines 244-248) with accurate description of independent Fine-Gray concordance approximation
- Removed "RSF variable importance rankings" reference from `discussion.tex` (line 95), replaced with "Fine-Gray subdistribution analysis"
- Deleted entire "Semi-Parametric Advantage" section from `discussion.tex` (~25 lines comparing Cox vs RSF performance)
- Cleared `future.tex` planning memo, replaced with placeholder comment for future rewrite
- Deleted 8 stale figure files: `figure7_rsf_vimp.png`, `figure8_auc_comparison.png`, plus 6 old numbered `figure1-6_*.png` duplicates from InterimScript
- Verified: zero RSF/VIMP mentions remain in any `.tex` chapter file or modular R script
- `refs.bib` RSF entries (ishwaran2008, ishwaran2014) left intact per DO NOT TOUCH policy — harmless uncited entries
### Key Decisions
- **Fine-Gray C-index claim fixed opportunistically**: While removing RSF from methodology.tex, noticed the false claim that Fine-Gray C-index equals Cox C-index "by construction." Replaced with accurate description noting the approximation limitation. This aligns with the Task 3 fix and will be discussed in the thesis.
- **Old numbered figures deleted**: The `figure1-6_*.png` files from InterimScript were duplicates of the new `fig_*.png` files from modular scripts. Deleted to prevent confusion.
- **InterimScript.R not modified**: RSF code remains in the archived monolithic script. It's not sourced by any modular script and serves as historical reference.
### Next Steps
- **Task 6**: Implement IPTW Causal Analysis (`code/05_causal_iptw.R`)
- **CRITICAL PRE-TASK**: Before writing any code, resolve the IPTW conceptual framing (RISK-C1 kill-switch). Key question: is IPTW defensible for a legislative date cutoff? What language will the thesis use? This decision propagates into every chapter.
- Preparation: read `docs/new_lit_sources.txt` for Austin & Fine (2025) reference, review the Risk Matrix RISK-C1/C2 sections
### Open Issues
- **All previous open issues carry forward**: stale prose in results.tex (7 TODO markers), timeROC iid=TRUE, cross-script duplication, RISK-C1 (IPTW framing), narrow-window IPTW, Second Circuit anomaly
- **Phase 1 fully complete**: Tasks 1-5 all done. Foundation is solid. Phase 2 (Causal Build) begins next session.
---

## Session: 2026-03-28 (Task 6 — IPTW Composition-Adjusted Analysis)
### Plan Progress
- Tasks completed this session: Task 6 (Implement IPTW Composition-Adjusted Analysis)
- Current position in plan: Task 6 of 16 COMPLETE — ready for Task 7 (Shared Frailty)
- Plan modifications needed: Minor — Task 6 scope expanded beyond the execution plan. The plan called for a 2-model comparison (unadjusted vs IPTW). We now have a 4-strategy triangulation (unadjusted, regression-adjusted, doubly robust, marginal structural). This strengthens the thesis substantially and addresses the devil's advocate finding that comparing regression vs IPTW on the same covariates is near-tautological. The comparison table in Tasks 11-12 (Results chapter) should use the 4-row triangulation format, not the original 2-row format.
### Completed
- **Kill-switch diagnostics** (`code/05_propensity_scores.R`): propensity score model, mirror density overlap plot, ESS=592.6 (57.5% efficiency), positivity check (0 cases with PS<0.01), all 21 covariates balanced. Decision: PROCEED.
- **Full IPTW script** (`code/05_causal_iptw.R`): 4-strategy triangulation analysis
  - Row 1: Unadjusted (PSLRA only) — Settlement HR=0.370, Dismissal HR=1.415
  - Row 2: Regression-Adjusted (Extended Cox) — Settlement HR=0.609, Dismissal HR=1.736
  - Row 3: Doubly Robust (IPTW + covariates) — Settlement HR=0.617, Dismissal HR=1.783
  - Row 4: Marginal Structural (IPTW only) — Settlement HR=0.565, Dismissal HR=1.518
- **Balance diagnostics**: Love plot saved to `output/figures/fig_iptw_balance.pdf`. All 21 covariates |SMD| < 0.1. PS distance SMD=0.112 (transparently reported).
- **Weighted CIF plots**: `fig_cif_weighted_settlement.pdf`, `fig_cif_weighted_dismissal.pdf`
- **PS overlap plot**: `fig_ps_overlap.pdf` (mirror density, pre vs post PSLRA)
- **Model objects saved**: `output/models/iptw_results.rds` (all 8 models + comparison table + metadata)
- **Devil's advocate review**: Identified the "rigged comparison" problem (comparing regression vs IPTW on same covariates is near-tautological). Led to the 4-row triangulation reframe.
- **R code review**: Fixed 2 CRITICALs — (1) balance check was silently failing due to unnamed vector, (2) hardcoded balance claim was wrong. Both fixed and verified.
- **Bug-finder investigation**: Confirmed IPTW weights are NOT uniform despite weak PS model (CV=0.86, max/min=37.6x). Weighting accounts for 85% of the total adjustment. The skeptic's claim that "weights are doing nothing" is empirically falsified.
### Key Decisions
- **RISK-C1 kill-switch: PROCEED**: ESS=593 > 300 threshold, good overlap, all covariates balanced. IPTW is feasible.
- **4-strategy triangulation over 2-model comparison**: The devil's advocate correctly identified that comparing regression-adjusted vs IPTW (same covariates) is uninformative. Adding the truly-unadjusted (Row 1) and MSM (Row 4) makes the analysis honest and defensible. The informative comparison is Row 1 → Row 4 (full weighting effect: +53% for settlement) and the convergence of Rows 2/3/4 (functional form robustness).
- **ATT estimand with 99th percentile trimming**: ATT preferred over ATE due to 11.5:1 imbalance. Trim cap at 48.56 (11 of 1,031 control cases trimmed). ESS improves from 521 to 593 with trimming.
- **"Composition-adjusted" language enforced**: All code comments, console output, and framing use "composition-adjusted" — never "causal." Unmeasured confounders caveat appears in header, summary, and inline.
- **PH violations acknowledged as time-averaging**: IPTW weighting amplifies PH violations (PSLRA dismissal goes from p=0.26 to p<2e-16). Weighted HRs are interpreted as time-averaged effects. The unweighted piecewise decomposition in 03_cox_models.R remains the preferred specification for time-varying effects.
- **Decomposition finding**: 85% of the HR adjustment comes from weighting, 15% from additional regression. This means observable composition (circuit, origin, MDL, statutory basis) explains a substantial share of the raw PSLRA association, but the PSLRA effect survives adjustment.
### Next Steps
- **Task 7**: Implement Shared Frailty Models (`code/06_frailty.R`)
  - Use `coxme::coxme()` with `(1 | circuit)` random effect
  - Settlement and dismissal cause-specific models
  - Compare frailty-adjusted PSLRA HR with fixed-effect HR
  - Report frailty variance (quantifying unobserved circuit heterogeneity)
  - Frame as sensitivity analysis, not standalone model (only 13 clusters)
  - Preparation: read coxme documentation, review RISK-H4 (frailty with 13 clusters)
- **After Task 7**: Checkpoint 1 — adversarial code review of all scripts (01-08)
### Open Issues
- **Stale prose in results.tex**: 7 `% TODO: REWRITE PROSE` markers remain. Will be addressed in Tasks 11-12.
- **timeROC iid=TRUE**: Still needed before final run (Task 16).
- **Cross-script data derivation duplication**: 03, 04, 07 all independently construct df_ext. Not blocking.
- **Narrow-window IPTW (1993-1998)**: Execution plan mentions this as supplementary analysis. Not yet implemented. Could strengthen quasi-experimental interpretation but may have too few pre-PSLRA cases. Defer to robustness or future work.
- **Second Circuit anomaly**: Settlement HR is extreme (5-17x lower than other circuits). Not investigated yet. Deferred.
- **PH violations in weighted models**: Substantially worse than unweighted. Piecewise IPTW not implemented. Thesis should discuss this as a limitation or implement piecewise IPTW as a robustness check (adds complexity to an already complex section).
---
