# Thesis State — Phase 3 Ready

> Last updated: 2026-04-01. This document is the single source of truth for Phase 3 (Writing).
> It replaces the chronological session log. All analysis code is locked.

---

## 1. PIPELINE STATUS

**Phase 1 (Foundation): CLOSED** — Tasks 1-5 complete.
**Phase 2 (Causal Build): CLOSED** — Tasks 6-7 complete.
**Checkpoint 1: CLOSED** — All 8 scripts (01-08) adversarially audited, fixed, and verified end-to-end on 2026-04-01. Zero errors. Full pipeline: `01_clean → 02_descriptives → 03_cox_models → 04_fine_gray → 05_causal_iptw → 06_frailty → 07_diagnostics → 08_robustness`.

**Phase 3 (Chapter Reconstruction): IN PROGRESS** — Tasks 8-13.
- Task 8 (Lit Review): COMPLETE (2026-04-01) — reviewed, 7 targeted fixes applied, no flip contamination found.
- Task 9 (Methodology): COMPLETE (2026-04-01) — reviewed, 9 targeted fixes applied (frailty eq, IPTW assumptions, notation, accessibility, cross-refs). Writing reviewer: 0 HIGH remaining.
- Task 10 (Introduction): COMPLETE (2026-04-02) — 5 contributions, 3 number fixes, CRITICAL significance error corrected, purpose statement + roadmap added.
- Tasks 11-12 (Results restructure): NOT STARTED.
- Task 13 (Discussion + Future Work): NOT STARTED.

**Phase 4 (Polish): NOT STARTED** — Tasks 14-16 (Abstract, Formatting, Final Verification).

**Deadline: April 9, 2026.**

---

## 2. IMMUTABLE METHODOLOGICAL DECISIONS

### Data Pipeline
- **Cohort**: 12,968 securities class actions (NOS 850), 1990-2024, from FJC IDB.
- **Pipeline counts**: 65,899 → 13,708 (NOS 850 filter) → 12,968 (duration > 0, valid disposition).
- **740 dropped cases**: All zero-duration administrative artifacts. No selection bias.

### Code 6 Disaggregation (CRITICAL)
FJC disposition Code 6 ("Judgment on Motion Before Trial") is disaggregated using the IDB JUDGMENT field:
- JUDGMENT = 1 (plaintiff victory, 701 cases) → **Settlement** (plaintiff-favorable resolution)
- JUDGMENT = 2 (defendant victory, 1,418 cases) → **Dismissal** (defense motion granted)
- JUDGMENT ∈ {3, 4, -8, NA} (ambiguous/missing, 270 cases) → **Censored** (conservative default)

**Final Scheme A distribution: 20.9% settlement / 67.3% dismissal / 11.7% censored.**

This is applied identically across Schemes A, B, and C. Scheme B additionally reclassifies Code 12 (voluntary dismissal) as settlement. Scheme C adds Code 5 (consent judgment) as settlement.

### Covariate Decisions
- `ext_formula_rhs`: `post_pslra + circuit_f + origin_cat + mdl_flag + juris_fq + stat_basis_f`
- `stat_basis_f` NA → explicit "Missing" factor level (134 cases, avoids silent row-dropping by coxph)
- `juris_fq`: 99.6% federal question — near-degenerate, included but noted
- `log_demand`: 98.4% missing — excluded from all models
- `mdl_flag` excluded from propensity score model (zero pre-PSLRA MDL cases → perfect separation)
- `origin_cat` "Removed" collapsed into "Other" (1 pre-PSLRA case → near-complete separation)
- Performance metrics (C-index, AUC) use reduced formula excluding `stat_basis_f` (complete separation → Inf coefficients)
- Interaction models omit `stat_basis_f` (thin cells at the interaction level)
- Reference circuit: Circuit 2 (PSLRA HR is algebraically invariant to reference choice in additive model)

### IPTW Design
- **Estimand**: ATT (not ATE) — due to 11.5:1 pre/post imbalance
- **Trimming**: 99th percentile (trim cap ~43.54, ~11 control cases trimmed)
- **ESS**: 578 (57.5% efficiency)
- **Balance**: All 19 covariates |SMD| < 0.1 after weighting
- **4-strategy triangulation**: Unadjusted → Regression-Adjusted → Doubly Robust → Marginal Structural

### Frailty Design
- `coxme::coxme()` with `(1 | circuit_f)` random effect — Gaussian on log-hazard scale
- 11 circuits (clusters). Frailty is a **sensitivity analysis**, not a standalone model.
- **methodology.tex:331 has a WRONG equation** (`u_c ~ LogNormal`). Must be fixed to `u_c ~ N(0, θ)` in Task 9.

### Time-Trend Specification
- **Linear `filing_year` is BANNED** from all models. It was the source of the debunked "Dismissal Flip" artifact (HR=0.598).
- The correct specification is `ns(filing_year, df=3)` (natural spline), used exclusively in `08_robustness.R`.
- Linear time-trend sections were permanently deleted from `03_cox_models.R` (Section 1B) and `04_fine_gray.R` (Section 5).

### Diagnostics
- `timeROC` uses `iid=TRUE` (confidence intervals enabled). All `$AUC_1` paired with `$CI_AUC_1`.
- Fine-Gray C-index is an approximation (`survival::concordance()` treats competing events as censored). Documented limitation.
- IBS (pec package) also treats competing events as censored — cause-specific approximation.

---

## 3. THE FINAL NARRATIVE TRUTHS

All numbers below are from the Code 6-disaggregated data (2026-04-01 pipeline run). These are authoritative.

### Baseline Cox (Unadjusted, PSLRA only)
| Outcome | HR | 95% CI | p |
|---|---|---|---|
| Settlement | 0.445 | [0.401, 0.495] | < 0.001 |
| Dismissal | 1.468 | [1.342, 1.606] | < 0.001 |

### Extended Cox (Full Covariates)
| Outcome | HR |
|---|---|
| Settlement | 0.702 |
| Dismissal | 1.751 |

### Piecewise Cox (Dismissal, Time-Varying Effect)
| Period | HR | p |
|---|---|---|
| 0-1 yr | 1.95 | < 0.001 |
| 1-2 yr | 1.05 | 0.582 |
| 2+ yr | 1.33 | 0.0001 |

### IPTW Triangulation (Composition-Adjusted)
| Row | Strategy | Settlement HR | Dismissal HR |
|---|---|---|---|
| 1 | Unadjusted | 0.439 | 1.466 |
| 2 | Regression-Adjusted | 0.701 | 1.746 |
| 3 | Doubly Robust | 0.709 | 1.804 |
| 4 | **MSM (IPTW only)** | **0.690** | **1.526** |

All 8 models p < 0.001 (max p = 1.29e-05 for MSM settlement).

### Frailty (Sensitivity Analysis)
| Outcome | θ (frailty variance) | Interpretation | Cluster-robust SE widening |
|---|---|---|---|
| Settlement | 0.449 | Substantial circuit heterogeneity | 2.8× (p=0.023) |
| Dismissal | 0.033 | Moderate circuit heterogeneity | 2.0× (p<0.0001) |

PSLRA HR is virtually identical between fixed-effect and random-effect models (delta=0.001). This is mathematically expected for a national-level treatment — not evidence of robustness. The model's value is θ and the cluster-robust SEs.

### Robustness (7 Specifications)
All 7 specifications show dismissal HR > 1 and settlement HR < 1. The strongest identification test is the spline time-trend control:
- **Spline (df=3)**: Settlement HR=0.610 (p=0.001), Dismissal HR=2.449 (p<0.001)
- **Range across all 7 specs**: Dismissal HR ∈ [1.28, 2.45], Settlement HR ∈ [0.34, 0.61]

### Identification Limits
- **1992 Placebo test FAILED**: HR=0.710 (p<0.001). The model detects pre-existing trends before PSLRA was enacted. This limits causal interpretability of all estimates.
- **Clean-window RDD (1993-1998)**: Dismissal HR=1.378 (p<0.001). Effect survives in narrow window, but not a pure causal test given the placebo failure.
- **IPTW covariates may be post-treatment**: Circuit, origin, MDL, and statutory basis could be consequences of PSLRA, not confounders. Composition-adjusted HR is a lower bound on the total effect.

### Fine-Gray (Subdistribution)
- Extended: Settlement SHR=0.454, Dismissal SHR=1.864
- FG dismissal PH test: p=0.362 (passes! — new finding under Code 6 data). Settlement PH: p=2.44e-07 (violated).
- MDL FG settlement SHR=1.167 (p=0.217) — NOT significant, opposite direction from CS Cox HR=0.284. Substantive finding for Results/Discussion.

### Diagnostics
| Model | C-index (Settlement) | C-index (Dismissal) |
|---|---|---|
| Cox | 0.727 | 0.597 |
| Fine-Gray | 0.662 | 0.578 |

PH tests: Both GLOBAL violated (Settlement χ²=301.1, Dismissal χ²=471.2, both p<0.001).
IBS: Settlement 0.100, Dismissal 0.181.

### Code 18 Sensitivity
Reclassifying Code 18 (statistical closing, 1,198 cases = 9.2%) as censored does not change main findings. Dismissal time-trend HR actually strengthens (0.536 vs 0.598). One-sentence note in Results/Discussion.

---

## 4. ACTIVE WRITING CONSTRAINTS

### Three-Tier Language Discipline (ENFORCED EVERYWHERE)
1. **"Associated with"** — for Cox and Fine-Gray results
2. **"After adjusting for observable case composition"** or **"composition-adjusted"** — for IPTW results
3. **"Causally attributable to"** — **NEVER USED** in this thesis. The placebo test failure and post-treatment bias concern prohibit causal claims.

### Headline Numbers
- Lead with **IPTW MSM HR ≈ 1.53** for dismissal (composition-adjusted), not the spline HR ≈ 2.45.
- Report the full range [1.28, 2.45] across specifications.
- Settlement claim must be hedged: "attenuates substantially under flexible time-trend controls (HR = 0.610) and loses statistical significance entirely in circuit-specific sub-samples" (Second Circuit HR=0.980, p=0.95; Ninth Circuit HR=0.869, p=0.13). The 1992 placebo further undermines identification.

### Framing Rules
- IPTW is a **decomposition** (how much of the raw PSLRA effect is explained by observable composition changes), not an "adjustment toward truth."
- Frailty is a **sensitivity analysis** (11 clusters is marginal), not a standalone model.
- The "Dismissal Flip" is an **artifact of linear overfitting** and must never appear in the thesis.
- PH violations make all constant-HR estimates "time-averaged summaries."
- Fine-Gray C-index is an **approximation** — acknowledge in Discussion.
- The thesis reports both confirming and disconfirming evidence honestly. Null results are results.

### Known Stale Content in .tex Files
- **7 `% TODO: REWRITE PROSE` markers** in results.tex — resolve in Tasks 11-12
- **data.tex**: Scheme A distribution, all three scheme tables, duration tables — all reflect pre-Code-6 numbers
- **results.tex**: All inline HRs, CIs, p-values, CIF horizons, Gray's test stats — stale
- **discussion.tex**: Some inline numbers updated, but most prose was written before Code 6 disaggregation
- **methodology.tex:331**: Frailty equation wrong (`LogNormal` → must be `Gaussian`)
- **Robustness LaTeX table**: Has 7 rows but may need number updates from latest pipeline run

### Prose Warnings from Devil's Advocate (Fix in Phase 3)
- Gray's test p-values: accompany with effect size context (N=12,968 makes everything significant)
- Censoring framing: "non-modeled exit pathways," NOT "snapshot date censoring" — all 1,251 censored cases have termination dates
- Don't say "permanent reduction" from CIF alone without controlling for confounders
- Second Circuit: say "Second Circuit" not "SDNY" — data is circuit-level (includes EDNY, NDNY, etc.)
- Code 6 era confound: 93.4% of reclassified plaintiff victories are post-PSLRA. Note in Discussion as data limitation.

---

## 5. REMAINING OPEN ISSUES

| Issue | Priority | Where to Address |
|---|---|---|
| Tasks 8-10 must restart from scratch (debunked flip context) | HIGH | Phase 3 start |
| All thesis numbers stale (pre-Code-6-disaggregation) | HIGH | Tasks 11-12 |
| methodology.tex frailty equation wrong | HIGH | Task 9 |
| 7 `% TODO: REWRITE PROSE` markers in results.tex | HIGH | Tasks 11-12 |
| Narrow-window IPTW (1993-1998) not implemented | LOW | Future work or robustness footnote |
| Piecewise IPTW not implemented | LOW | Discuss as limitation |
| Second Circuit anomaly not formally investigated | LOW | Note in Discussion |
| Cross-script df_ext construction duplication (03, 04, 07) | LOW | Not blocking; cosmetic |

---

## Session: 2026-04-01 (Checkpoint 1 Final Close + Session Log Compression)
### Plan Progress
- Tasks completed this session: Checkpoint 1 re-audit of scripts 07 and 08 (final 2 of 8). Full pipeline end-to-end verification. Session log compression.
- Current position in plan: Checkpoint 1 CLOSED. Ready for Phase 3: Task 8 (Literature Review).
- Plan modifications needed: Checkpoint 1 status in execution-plan.md should be marked COMPLETE.
### Completed
- **Adversarial audit of 07_diagnostics.R**: 0 CRITICALs, 3 MEDIUMs, 4 LOWs. Code 6 disaggregation did NOT break timeROC encoding, Schoenfeld plots, or C-index calculations. All `iid=TRUE` confirmed.
- **Adversarial audit of 08_robustness.R**: 0 CRITICALs, 3 MEDIUMs, 5 LOWs. Spline (df=3) executes cleanly. Forest plot renders all 7 specs without clipping. Scheme B/C Code 6 handling is correct.
- **Fixes applied to 07_diagnostics.R**:
  - Strict `get_auc()`: removed `$AUC` fallback, now requires `$AUC_1` with `stopifnot`
  - Added 3 `stopifnot` checks on loaded .rds fields (ext_formula_rhs, circuits_incl, include_stat)
  - Added IBS limitation comment (cause-specific approximation)
- **Fixes applied to 08_robustness.R**:
  - Forest plot subtitle: removed subjective claim → "Hazard Ratios across Alternative Specifications and Subsets"
  - Spline interpretation: replaced static narrative with dynamic `sprintf()` + significance flag
  - Wrapped `confint()` in `tryCatch` inside `run_pslra_cox()` helper
- **Full pipeline run (01→08)**: All 8 scripts executed with zero errors against Code 6-disaggregated data
- **Visual verification**: Forest plot and Schoenfeld plots render correctly
- **Session log compressed**: Replaced 657-line chronological play-by-play with 163-line "Current State of the Thesis" document organized by pipeline status, methodological decisions, narrative truths, writing constraints, and open issues
### Key Decisions
- **No CRITICALs found in final audit**: The Code 6 disaggregation did not break any diagnostic or robustness logic. The pipeline is iron-clad.
- **Hardcoded narrative purged from all scripts**: Every `cat()` block in 07 and 08 now computes values dynamically from model objects. Zero static claims remain.
- **Session log format change**: The chronological session log was consuming excessive context tokens with deprecated history. The new format preserves only what Phase 3 writing needs.
### Next Steps
- **Task 8**: Restart Literature Review from scratch. Read `docs/new_lit_sources.txt`, current `litreview.tex`, and `refs.bib`. Add IPTW/frailty literature subsection. Remove RSF. Reframe research gap around composition-adjusted inference.
- **Start next session with `/plan`** to reload the condensed session log and execution plan.
### Open Issues
- All open issues documented in Section 5 of the condensed session log above. No new issues from this session.
---

## Session: 2026-04-01 (Task 8: Literature Review)
### Plan Progress
- Tasks completed this session: Task 8 (Update Literature Review + Add New Sources)
- Current position in plan: Task 8 of 16 complete. Next: Task 9 (Methodology rewrite).
- Plan modifications needed: Task 8 status should change from "DRAFT-IN-REVIEW" to COMPLETE. The "restart from scratch" directive was overly cautious — no flip contamination was found in the existing draft. Future tasks 9 and 10 should also be reviewed-then-fixed rather than rewritten from scratch.
### Completed
- **Reviewed litreview.tex for flip contamination**: Zero matches for flip/reversal/0.598/linear time-trend. Draft was clean.
- **Ran writing-reviewer agent**: Found 5 substantive issues, all fixed.
- **7 targeted edits to litreview.tex**:
  1. Replaced redundant "no prior work" claim (lines 54-60) with transition to IPTW/frailty subsection — claim now appears only in Research Gap (Section 2.5)
  2. "Central to this thesis" → "augment the core competing-risks framework" (frailty is a sensitivity analysis)
  3. Split Austin & Fine claim: Aalen-Johansen recovers CIF, Cox recovers HRs (was technically imprecise)
  4. Replaced "standard causal assumptions" with named assumptions (no unmeasured confounding, positivity, correct specification)
  5. "PSLRA increased" → "was associated with higher" (three-tier language in lit review)
  6. "market share affects" → "is associated with" (same)
  7. Expanded NOS on first use in this chapter (accessibility)
- **Verified refs.bib**: All 4 new references (ruetenbudde2019, frevent2024, xieliu2005, austinfine2025) already present from previous session. No changes needed.
- **All acceptance criteria verified**: 4 sources cited (8 total citations), IPTW/frailty motivated, RSF absent, research gap reframed, no fabricated citations, three-tier language enforced.
### Key Decisions
- **Did NOT restart from scratch**: The existing litreview.tex draft was 95% sound. The "restart" directive in the session log was based on fear of flip contamination that did not materialize. Targeted fixes were more appropriate than a full rewrite.
- **Causal verb discipline extended to literature summaries**: When summarizing other authors' findings (Johnson 2001, Wang 2022), replaced causal verbs with "associated with" since we cannot verify those studies established causation. This protects against a reviewer asking "did that study actually identify causation?"
- **Redundancy eliminated**: The "no prior work" claim was stated in both Section 2.2.4 (Prior Survival Methods) and Section 2.5 (Research Gap). Trimmed 2.2.4 to focus on Brochet critique; gap claim is now exclusively in 2.5.
### Next Steps
- **Task 9**: Rewrite Methodology chapter. Read current `methodology.tex`. Key fixes: (1) fix frailty equation at line 331 (LogNormal → Gaussian), (2) review IPTW and frailty sections added in previous session, (3) verify three-tier language, (4) confirm RSF removal is complete. Same approach as Task 8: review existing draft for issues rather than rewriting from scratch.
- **Task 10**: Review Introduction (same approach — review then fix).
### Open Issues
- No new issues. All prior open issues from Section 5 of the condensed session log remain unchanged.
---

## Session: 2026-04-01 (Task 9: Methodology Review & Fix)
### Plan Progress
- Tasks completed this session: Task 9 (Methodology chapter review and fix)
- Current position in plan: Task 9 of 16 complete. Next: Task 10 (Introduction review).
- Plan modifications needed: Task 9 status should change from "DRAFT-IN-REVIEW" to COMPLETE. Same review-then-fix approach confirmed effective — no flip contamination, no need for full restart.
### Completed
- **Reviewed methodology.tex for issues**: Used review-then-fix approach (same as Task 8). No flip contamination found.
- **Fix 1 — Frailty equation**: Changed `u_c ~ LogNormal(0, θ)` with multiplicative hazard form to `u_c ~ N(0, θ)` with additive-on-log-scale form `exp(β'X + u_c)`. Added equivalence note to multiplicative frailty. Removed stale TODO comment.
- **Fix 2 — IPTW assumptions enumerated**: Expanded Interpretive Scope into a numbered list explicitly naming all three assumptions: (1) No unmeasured confounding, (2) Positivity, (3) Correct model specification. Each discusses why it's strained in this setting. Closing sentence enforces "composition-adjusted, never causally attributable."
- **Fix 3 — Stale illustrative HR**: Changed 1.62 (no actual result matches) to 1.50 with subjunctive "would mean" to clearly signal illustrative example.
- **Fix 4 — Broken cross-reference**: Replaced hardcoded `Section~5.5` (wrong) with `Chapter~\ref{ch:results}` (robust to restructure).
- **Fix 5 — Notation collision**: Renamed interaction coefficient `θ` (bold) to `α` (bold) to avoid collision with frailty variance scalar `θ`.
- **Fix 6 — Fine-Gray accessibility**: Added 7-line plain-English paragraph before Fine-Gray formula explaining distinction from cause-specific Cox.
- **Fix 7 — Interaction model stat_basis drop documented**: Added sentence explaining why statutory basis is excluded (thin cells at interaction level).
- **Fix 8 — Three-tier language tightened**: "effect on" → "association with", "PSLRA's effect" → "PSLRA's association", "baseline PSLRA effect" → "baseline PSLRA coefficient" in Cox-context lines.
- **Fix 9 — Hardcoded refs → \ref{}**: Added `\label{sec:hazard_regression}` to Section 3.3. Replaced `Section~4.3` → `Section~\ref{sec:coding_schemes}`, two `Section~3.3` → `Section~\ref{sec:hazard_regression}`.
- **Verified prior-session fixes already in place**: Plain-English HR def (lines 96-104), `risk_hat_i` defined (line 372-373), Fine-Gray ≠ Cox claim eradicated (lines 401-408), RSF fully eradicated (0 grep matches).
- **Writing reviewer agent**: 0 CRITICAL, 2 HIGH (both fixed), 5 MEDIUM (all fixed), 5 LOW (cosmetic, not blocking).
### Key Decisions
- **Review-then-fix approach confirmed for Phase 3**: Like Task 8, the existing methodology draft was ~90% sound. Targeted fixes were the right approach. Tasks 10+ should follow the same pattern.
- **Illustrative HR uses round hypothetical (1.50)**: Avoids looking like a fabricated result number while still being concrete enough to teach the reader. Subjunctive "would mean" signals it's illustrative.
- **Interaction coefficient renamed α to avoid θ collision**: This is a cosmetic but important clarity fix — the frailty section's θ is a key parameter and should have exclusive use of that symbol.
### Next Steps
- **Task 10**: Review Introduction. Read current `intro.tex`. Key checks: (1) contributions mention IPTW (composition-adjusted) and frailty (sensitivity), (2) no RSF, (3) HR range [1.28-1.94] and IPTW ≈ 1.53 headline numbers correct, (4) settlement hedge present, (5) placebo mentioned, (6) three-tier language. Same review-then-fix approach.
- **Tasks 11-12**: Results restructure (the big lift — claim-based rewrite with all stale numbers replaced).
### Open Issues
- **5 LOW writing-review items deferred** (not blocking): subscript gap β_1→β_4→β_5, 11.6:1 vs 11.5:1 minor ratio discrepancy, Gray's test large-sample note, train/test split count note (12,866 vs 12,968), missing \label{} on non-cross-referenced sections. Can be addressed during Phase 4 polish (Task 15).
- All prior open issues from Section 5 of the condensed session log remain unchanged.
---

## Session: 2026-04-02 (Task 10: Introduction Review & Fix)
### Plan Progress
- Tasks completed this session: Task 10 (Introduction review and fix)
- Current position in plan: Task 10 of 16 complete. Next: Task 11 (Results restructure Part 1).
- Plan modifications needed: Task 10 status should change from "DRAFT-IN-REVIEW" to COMPLETE.
### Completed
- **Reviewed and restructured intro.tex contributions**: Expanded from 4 to 5 contributions. Contribution 2 (IPTW) sharpened to "first application of propensity-score re-weighting to adjust for compositional confounding in securities litigation outcomes." NEW contribution 3 (Sensitivity) added for shared frailty as explicit sensitivity analysis.
- **Fixed 3 stale/wrong numbers**:
  - Dismissal HR range: 1.94 → 2.45 (verified from robustness_results.rds)
  - Settlement baseline HR: 0.378 → 0.445 (verified from cox_models.rds — 0.378 was pre-Code-6)
  - Circuit count: 13 → 11 (verified from frailty_results.rds metadata — code filters n >= 50)
- **Fixed CRITICAL factual error caught by writing-reviewer**: "loses statistical significance under flexible time-trend controls" was false — spline settlement HR = 0.610 has p = 0.001 (significant). Corrected to "attenuates substantially under flexible time-trend controls (HR = 0.610) and loses statistical significance entirely in circuit-specific sub-samples" (Second Circuit p=0.95, Ninth Circuit p=0.13).
- **Three-tier language fixes**: "isolate the PSLRA's effect" → "examine the PSLRA's association"; "demonstrating that the Act operates as a persistent accelerant" → "finding that the Act is associated with persistently elevated dismissal hazard"; "raw PSLRA effect" → "raw PSLRA association".
- **Added chapter-opening purpose statement** (lines 5-8): "This chapter motivates the research question..."
- **Added sample size** (N=12,968, 1990-2024) to contribution 1.
- **Expanded "hidden settlements"** with explanatory clause for non-specialists.
- **Added roadmap paragraph** at end with \ref{} cross-references to all 7 chapters.
- **Fixed session-log stale instructions**: Line 159 settlement hedge corrected; line 163 frailty clusters 13→11.
### Key Decisions
- **Settlement hedge revised based on actual data**: The session log's own hedge instruction was internally contradictory (said "loses significance" then cited p=0.001). The correct pattern is: attenuates under spline (but remains significant), loses significance in circuit sub-samples. This distinction matters for Results/Discussion chapters — do not claim global loss of significance.
- **Five contributions, not four**: Frailty earns its own bullet as a sensitivity analysis rather than being buried in the IPTW contribution. This makes the thesis structure clearer.
- **"Population-level administrative data" replaced with concrete N**: 12,968 cases is more compelling and verifiable than a vague descriptor.
### Next Steps
- **Task 11**: Restructure Results Chapter Part 1 (Sections 5.1-5.4). This is the biggest lift remaining — claim-based rewrite with all stale pre-Code-6 numbers replaced from actual R output. Read current `results.tex` first. Key structure: 5.1 Overview, 5.2 PSLRA Effect (layered evidence), 5.3 Geographic Disparity (circuits + frailty), 5.4 Case Characteristics (MDL, origin, statutory basis).
- **Task 12**: Results Part 2 (Diagnostics + Summary). Depends on Task 11 completion.
- **Reminder**: 7 `% TODO: REWRITE PROSE` markers in results.tex must all be resolved in Tasks 11-12.
### Open Issues
- **5 LOW writing-review items from Task 9 still deferred**: subscript gap, ratio discrepancy, Gray's test note, train/test count, missing labels. Address in Phase 4 (Task 15).
- All prior open issues from Section 5 of the condensed session log remain unchanged except: settlement hedge instruction (FIXED), frailty cluster count (FIXED).
---

## Session: 2026-04-02 (Task 11 Part 1: Results Sections 5.1-5.2)
### Plan Progress
- Tasks completed this session: Task 11 Part 1 (Results Sections 5.1 and 5.2)
- Current position in plan: Task 11 partially complete. Sections 5.1-5.2 done. Sections 5.3-5.4 pending.
- Plan modifications needed: Task 11 should be split — Part 1 (5.1-5.2) COMPLETE, Part 2 (5.3-5.4) next session.
### Completed
- **Full structural outline** created and approved: 5.1 (Overview), 5.2 (PSLRA Effect with 5 evidence layers), 5.3 (Geographic), 5.4 (Case Characteristics), 5.5 (Diagnostics), 5.6 (Summary).
- **Verified ALL numbers from R output** against Code 6-disaggregated data:
  - CIF horizons: Pre-PSLRA settl 5.9/20.2/29.1/41.8, dism 17.6/31.9/37.1/49.2; Post-PSLRA settl 2.5/6.6/11.3/17.0, dism 30.9/44.9/55.7/68.1
  - Baseline Cox: Settlement HR=0.445 (0.401-0.495), Dismissal HR=1.468 (1.342-1.606)
  - **PH test: Settlement NOW REJECTS (p<0.001, was p=0.12)** — both outcomes violate PH
  - Piecewise: 0-1yr HR=1.948 (1.675-2.266), 1-2yr HR=1.050 (0.883-1.249, p=0.582), 2+yr HR=1.329 (1.148-1.538)
  - IPTW MSM: Settlement HR=0.690, Dismissal HR=1.526. All 8 estimates p<0.001.
  - Robustness: all 7 specs updated. Range: Dismissal [1.32, 2.45], Settlement [0.44, 0.98].
  - Placebo: Dismissal HR=0.719 (0.597-0.867, p=0.00055). Clean-window: Dismissal HR=1.394 (1.190-1.633).
  - Gray's test (PSLRA): Settlement stat=302, Dismissal stat=167.
  - Interaction LR: Settlement χ²=20.5 (df=5, p=0.001), Dismissal χ²=37.2 (df=5, p<0.001).
- **Wrote new Section 5.1** (~70 lines): Updated KM and CIF numbers, added research-question transition.
- **Wrote new Section 5.2** (~350 lines): 6 subsections with all 5 evidence layers:
  - 5.2.1 CIF by PSLRA (updated table + Gray's stats)
  - 5.2.2 Baseline Cox (updated HRs, PH now rejects for BOTH, settlement hedge foreshadow added)
  - 5.2.3 Piecewise (updated HRs and CIs)
  - 5.2.4 IPTW Triangulation (ENTIRELY NEW: table, weighted CIF figure, 4-strategy analysis)
  - 5.2.5 Robustness + Identification (updated table, placebo/clean-window with CIs)
  - 5.2.6 Synthesis (NEW: ties all layers together with settlement hedge)
- **Writing reviewer agent**: Found 2 CRITICALs, 4 HIGHs, 4 MEDIUMs, 4 LOWs. All CRITICAL and HIGH fixed:
  1. CRITICAL: HR discrepancy between baseline (N=12,968) and IPTW unadjusted (N=12,866) — added explanation of 102 dropped cases
  2. CRITICAL: "factor of four" imprecise — changed to "factor of four or more"
  3. HIGH: "Effect" in piecewise headers → "Association"
  4. HIGH: "Both effects" → "Both associations" in clean-window
  5. HIGH: Added HR definition reminder at first use in results chapter
  6. HIGH: "isolate" → "remove the portion...explained by"
  7. MEDIUM: "first documentation" → "to our knowledge, the first"
  8. MEDIUM: Added Section 5.1 transition sentence connecting to research question
  9. LOW: Removed redundant "empirical"
  10. LOW: "reform impacts" → "reform associations"
- **Reorganized Sections 5.3-5.6**: Old content placed under new section headings with TODO markers. All old tables/figures preserved. Labels preserved for cross-reference integrity.
### Key Decisions
- **Settlement PH now rejects**: Code 6 disaggregation changed the settlement baseline PH test from p=0.12 (not rejected) to p<0.001 (rejected). BOTH outcomes now violate PH. The old text's "fails to reject PH for settlement" is now WRONG. Updated to note both violations and interpret baseline HRs as "time-averaged summaries."
- **IPTW dismissal HR is AMPLIFIED, not attenuated**: MSM HR=1.526 > unadjusted 1.466. Composition partially OFFSET the PSLRA dismissal effect. This is the opposite of the settlement story and is an important nuance.
- **Settlement composition attenuation is ~45%**: Raw 56% reduction → 31% after IPTW. "Approximately half" is defensible.
- **Interaction LR stats updated**: Settlement χ²=20.5 (was 13.46), Dismissal χ²=37.2 (was 40.14). Updated in 5.3 placeholder.
- **Robustness range corrected**: Session log had stale [0.34, 0.61] for settlement; actual is [0.44, 0.98]. Dismissal range [1.32, 2.45] (session log had [1.28, 2.45]).
### Next Steps
- **Task 11 Part 2**: Write Sections 5.3 (Geographic Disparity) and 5.4 (Case Characteristics). Key new content: frailty results (5.3.4), interaction table (tab:interaction), all stale numbers in circuit/extended/FG tables.
- **Task 12**: Sections 5.5 (Diagnostics) and 5.6 (Summary). Schoenfeld plots, IPTW balance, performance table verification.
- **Task 13**: Discussion + Future Work.
### Open Issues
- **IPTW table lacks CIs**: Writing reviewer flagged missing confidence intervals in tab:iptw_triangulation. Need to check if iptw_results.rds stores CIs for all 4 strategies. LOW priority — all p<0.001 and table note says so.
- **Old content in 5.3-5.4 has stale numbers**: All tables (tab:cox_circuit, tab:cox_ext_settle, tab:cox_ext_dismiss, tab:fg_comparison) need verification. Inline prose numbers also stale.
- **Gray's test stats in circuit CIF caption are stale** (573.5/15.3): Need recomputation with all 11 circuits.
- **5 LOW items from Task 9 still deferred**: subscript gap, ratio discrepancy, Gray's test note, train/test count, missing labels.
---
