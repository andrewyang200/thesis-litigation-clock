# Discovery Assessment

> **Generated**: 2026-03-27 by Claude Code during Phase 1 (Staged Discovery).
> Built across three stages: Data & Code, Writing & Thesis, Gap Analysis & Planning.
> This document is the basis for the Execution Plan.

---

## A. Data Assessment

### File inventory

| Location | File | Format | Size |
|---|---|---|---|
| `data/raw/` | `cv88on.txt` | Tab-separated (TSV) | **1.96 GB** |
| `data/cleaned/` | *EMPTY* | — | — |

The single data file is the **full FJC Integrated Database civil extract** — all case types, all years. It has **46 columns** including: `CIRCUIT`, `DISTRICT`, `OFFICE`, `DOCKET`, `ORIGIN`, `FILEDATE`, `JURIS`, `NOS`, `SECTION`, `CLASSACT`, `DEMANDED`, `MDLDOCK`, `TERMDATE`, `DISP`, `PROCPROG`, plus plaintiff/defendant names and various date fields.

The full IDB contains millions of rows across all case types. The thesis filters to ~12,968 NOS 850 (securities) class actions filed 1990-2024.

### Data quality issues

1. **No cleaned .rds file exists.** The InterimScript claims to produce `securities_cohort_cleaned.rds` — it does not exist. Every run re-processes the 2 GB raw file from scratch.
2. **Missing-value encoding**: The IDB uses `-8` for missing values (visible in SECTION, JURY, DEMANDED, MDLDOCK), not `NA`. The script handles this, but it's fragile.
3. **Several columns entirely empty**: `TITL`, `FILEJUDG`, `FILEMAG`, `TRANSDAT`, `PRETRIAL`, `TRIBEGAN`, `TRIALEND`, `IFP`, `STATUSCD` all read as `logical NA` — likely empty in this extract.

---

## B. Code Assessment

### File inventory

| Script | Lines | Purpose | Status |
|---|---|---|---|
| `code/utils.R` | 122 | Shared helpers: package loading, theme, color palette, `save_figure()`, `save_table()`, `code_event()`, `format_hr()` | **ORPHANED** — never sourced by any script |
| `code/InterimScript.R` | ~1,540 | Monolithic analysis: data loading through model comparison | **Has fatal bugs** |
| `code/inspect_data.R` | ~80 | Data inspection utility (created during assessment) | Utility only |

### InterimScript.R section-by-section

| Section | Lines | Content | Status |
|---|---|---|---|
| 1-3 | 1-120 | Data loading, filtering to NOS 850 | Functional (but hardcoded path) |
| 4 | 121-200 | Disposition coding (3 schemes) | Functional |
| 5 | 201-320 | Covariate construction | Functional |
| 6 | 321-380 | Descriptive statistics | Functional |
| 7-10 | 381-570 | KM curves, CIF plots (overall, PSLRA, circuit) | Functional |
| 11 | 571-640 | Baseline cause-specific Cox | Functional |
| 12 | 641-700 | Piecewise time-varying PSLRA | Functional |
| 13 | 701-750 | Cox with circuit fixed effects | Functional |
| 14 | 751-780 | Fine-Gray baseline | Functional |
| 15 | 781-870 | Extended Cox/Fine-Gray (all covariates) | Functional (dead code block at 782-789) |
| 16 | 871-930 | PSLRA x Circuit interaction | Functional |
| 17 | 931-1050 | Robustness checks | Functional |
| 18 | 1051-1070 | Train/test split | Functional |
| 19 | 1071-1090 | C-index computation | **FATAL BUG** |
| 20 | 1091-1200 | Time-dependent AUC | Has ordering issue |
| 21 | 1201-1300 | Brier Score / IBS | May work if run after 20 |
| 22 | 1301-1420 | Random Survival Forest | **ABANDONED** (project pivot) |
| 23 | 1421-1500 | Model comparison table | **Logical error** (Fine-Gray C-index) |
| 24 | 1501-1540 | Save results | Never executed successfully |

### Critical bugs

| # | Location | Severity | Issue |
|---|---|---|---|
| 1 | **Lines 1073-1074** | **FATAL** | `lp_s` and `lp_d` used before they are defined. They are referenced at line 1073 but not computed until line 1095-1096. Script crashes if run top-to-bottom. |
| 2 | **Lines 1387-1388** | **Logical error** | Fine-Gray C-index is copy-pasted from Cox C-index with comment "Same linear predictor as Cox." This is methodologically wrong — Fine-Gray uses different weights and pseudo-observations. The Fine-Gray C-index is never actually computed. |
| 3 | **Line 42** | **Config** | Hardcoded path `/Users/andrewyang/Documents/thesis/cv88on.txt` — differs from actual data location (`data/raw/cv88on.txt`). Script won't find data as-is. |
| 4 | **Lines 386, 435, 512, etc.** | **Path** | All `ggsave()` calls write to working directory (e.g., `"figure1_km_overall.png"`), not `output/figures/`. |
| 5 | **Lines 1512-1513** | **Path** | `saveRDS()` writes to working directory, not to `data/cleaned/` or `output/`. |

### Completely missing methods

| Method | Status | Notes |
|---|---|---|
| **IPTW / Propensity Score Weighting** | Not implemented | Core of the causal inference pivot. Requires propensity score model, WeightIt, cobalt diagnostics. |
| **Shared Frailty Models** | Not implemented | Requires `coxme` with circuit-level random effects. |
| **Schoenfeld residual plots** | Not implemented | PH *tests* exist but diagnostic *plots* are never generated. |
| **Cleaned .rds data pipeline** | Not implemented | No `securities_cohort_cleaned.rds` saved anywhere. |
| **LaTeX table output** | Not implemented | All tables printed to console only. No `.tex` files generated. |

---

## C. Output Assessment

### Existing figures

| File | Source | Format | Stale? |
|---|---|---|---|
| `figure1_km_overall.png` | Section 7 | PNG only | Yes (figures from 02:59, script modified 17:49) |
| `figure2_cif_overall.png` | Section 8 | PNG only | Yes |
| `figure3_cif_pslra.png` | Section 9 | PNG only | Yes |
| `figure4_cif_circuit_dismissal.png` | Section 10 | PNG only | Yes |
| `figure5_cif_circuit_settlement.png` | Section 10 | PNG only | Yes |
| `figure6_robustness_hr.png` | Section 17 | PNG only | Yes |
| `figure7_rsf_vimp.png` | Section 22 | PNG only | **ABANDONED** (RSF pivot) |
| `figure8_auc_comparison.png` | Section 23 | PNG only | Yes; relies on buggy C-index |

### Missing outputs

- No PDF figures (thesis requires PDF)
- No `.tex` table files in `output/tables/`
- No `securities_cohort_cleaned.rds`
- No `results_fall.rds` or `results_spring.rds`
- No Schoenfeld residual plots
- No IPTW balance diagnostic plots
- No frailty model outputs

---

## D. Writing Assessment

### Chapter-by-chapter status

| Chapter | File | Completeness | Quality |
|---|---|---|---|
| Abstract | `abstract.tex` | **PLACEHOLDER** — lorem ipsum, `$\pi \approx 3.14$` | Not started |
| Acknowledgements | `acknow.tex` | **PLACEHOLDER** — template text | Not started |
| Introduction | `intro.tex` (81 lines) | Complete | Strong prose, but frames thesis around methods not causal inference. Lists RSF as contribution (iv). |
| Literature Review | `litreview.tex` (229 lines) | Complete | Solid. Covers survival methods, securities lit, IDB limitations, research gap. |
| Methodology | `methodology.tex` (265 lines) | Complete for interim scope | Rigorous math. Missing: IPTW section, Frailty section, $\widehat{\text{risk}}$ definition. |
| Data | `data.tex` (307 lines) | Complete | Professional booktabs tables. Clear sample construction. |
| Results | `results.tex` (~649 lines) | Complete for interim scope | Dense but thorough. **Wrong organizational structure** — model-by-model instead of claim-by-claim. |
| Discussion | `discussions.tex` (278 lines) | Complete | Strong synthesis. Good policy implications. Needs updating for IPTW/Frailty. |
| Future Work | `future.tex` (132 lines) | **UNUSABLE** — reads as project planning notes | Must be completely rewritten as a proper thesis chapter. |

### Discussion filename issue
**FIXED** by user — `thesis.tex` now references correct filename.

### Key writing problems

1. **Abstract is a placeholder** — must be written (rubric: 200-300 words).
2. **Acknowledgements is a placeholder** — must be written.
3. **Introduction frames thesis wrong** — emphasizes "first competing-risks framework" and RSF. Must reframe around causal inference (IPTW) per advisor.
4. **Results organized by model, not by claim** — advisor's #1 structural ask, completely unaddressed.
5. **"Hazard ratio" never defined in plain English** — used ~50 times, never explained intuitively.
6. **$\widehat{\text{risk}}$ undefined** in C-index equation (methodology.tex, equation 3.13).
7. **Causal language misuse** — results.tex line 231 calls the piecewise pattern "the PSLRA's time-varying causal signature" but this is a standard Cox model, not IPTW-adjusted. Violates CLAUDE.md Rule 11.
8. **Fine-Gray C-index claim is false** — both methodology.tex (lines 244-248) and results.tex (lines 586-587) claim Fine-Gray and Cox "share the same linear predictor." They do not.
9. **Future Work is a to-do list**, not a thesis chapter ("diagnose and fix the silent failure of the pec IBS computation").
10. **No `hyperref` package** — rubric says references should be clickable.
11. **`newcommands.tex` contains unrelated commands** (CDS pricing, Black-Scholes) and is never `\input`'d. Harmless but sloppy.

### Self-containment assessment

- **For a judge**: Introduction and legal context are accessible. PSLRA is well-explained. BUT "hazard ratio" is never defined — a judge hits a wall at the first results table.
- **For an ORFE professor**: Math is rigorous. BUT professor wouldn't know what NOS 850 is or why disposition codes matter without the Data chapter.
- **"Drop-In" Test**: Fails in Results. Opening to any model table (e.g., Table 5.5), there's no reminder of the research question or why this model matters. Reader is swimming in HR tables with no connecting thread.

### Violations terminology
**ADDRESSED** in methodology.tex lines 14-17: *"any reference to a 'violation' denotes a statistical failure of the proportional hazards assumption, not a legal or regulatory infraction."* Should be reinforced when PH violations are discussed in Results.

### Notation
Core notation ($T_i$, $\delta_i$, $\mathbf{X}_i$, $\lambda_k$, $F_k$, $\boldsymbol{\beta}_k$, $\boldsymbol{\gamma}_k$) is consistent throughout. Only gap: $\widehat{\text{risk}}_i$ undefined.

---

## E. Writing vs. Code Alignment

### Untrustworthy numbers

The **C-index and AUC values in Table 5.11** (Cox C-index 0.735/0.602; RSF C-index 0.549/0.540) are **unreliable**. InterimScript Section 19 uses `lp_s`/`lp_d` before they are defined — these numbers could only exist from a partial interactive run with lingering environment variables. They should be treated as **contaminated**.

### False methodological claim in both code and writing

Both `methodology.tex` (lines 244-248) and `results.tex` (lines 586-587) state that Fine-Gray and Cox share the same linear predictor. This is **methodologically wrong** — the `finegray()` augmented-data approach creates pseudo-observations with different weights and a modified risk set. The code (Section 23) simply copies Cox C-index values for Fine-Gray.

### Causal language violation

`results.tex` line 231: *"the first formal empirical documentation of the PSLRA's time-varying **causal signature**"* — uses causal language for a standard Cox model without IPTW adjustment. Per CLAUDE.md Rule 11, causal language is reserved for IPTW-adjusted estimates only.

### Numbers that appear traceable but unverified

The hard-coded numbers in Data tables (12,968 cases; 65,899 NOS 850 before class action filter; 2,015 settlements; 7,313 dismissals) appear to match what the InterimScript's Sections 3-6 would produce. These are **plausible but cannot be verified** without running the script — no saved .rds or log files exist.

The train/test split sizes (9,005 training / 3,861 test) are plausible given 12,866 x 0.70 = 9,006.

### Missing alignment

| Status | Detail |
|---|---|
| Code exists, thesis covers | KM, CIF, baseline Cox, piecewise, circuit effects, Fine-Gray, extended models, interaction, robustness |
| Code exists, thesis doesn't need | RSF (abandoned) |
| Thesis mentions, code missing | IPTW, Shared Frailty, Schoenfeld plots |
| Code outputs not in thesis | Statutory basis distribution, covariate missingness rates (mentioned as inline numbers but no formal table) |

---

## F. Cross-References

### Structural issues

| Issue | Severity | Status |
|---|---|---|
| Discussion filename mismatch | Was compilation error | **FIXED** |
| Figure paths (`./Figures/` vs `output/figures/`) | Compilation error locally | Works on Overleaf (different directory structure) |
| No `hyperref` | Rubric violation | **OPEN** |
| `newcommands.tex` orphaned | Minor | Not `\input`'d, harmless |

### \ref / \label integrity
All `\ref{}` calls have matching `\label{}` definitions. **No broken cross-references.**

### \cite integrity
- All cited keys exist in `refs.bib`. **No missing citations.**
- **Uncited bib entries**: `eisenberg1997`, `heagerty2005`, `courtlistener`.
- **Duplicate citation style** (rubric violation): `litreview.tex` line 129-130 writes `Wang et al.\ (2022) find that...settlement patterns \citep{wang2022}` — the name is written out AND cited parenthetically. Should use `\citet{wang2022}` or just the parenthetical.

### Figure coverage
All 8 figures referenced in text exist in `output/figures/`. RSF figures (7, 8) must be removed or replaced after the pivot. No PDF versions exist — only PNG.

---

## G. Advisor Feedback Compliance

| # | Feedback Item | Status | Detail |
|---|---|---|---|
| 1 | **Clarify Objective** — core is causal inference, not ML prediction | **NOT ADDRESSED** | Introduction frames thesis as "first competing-risks framework." Contribution (iv) cites RSF. IPTW not mentioned. Methodology says frailty "could" be done. The word "causal" is misused once (results line 231). |
| 2 | **Restructure Results** — organize by substantive claims, not by model | **NOT ADDRESSED** | Results chapter has 9 sections organized by model: §5.1 Nonparametric → §5.2 Baseline Cox → §5.3 Circuit → §5.4 Extended → §5.5 Fine-Gray → §5.6 Interaction → §5.7 Robustness → §5.8 RSF → §5.9 Performance. |
| 3 | **Shorten & Focus** — thesis too long, easy to get lost | **NOT ADDRESSED** | Results chapter is ~650 lines of dense model-by-model exposition. |
| 4 | **Judge/Professor Test** — self-contained, logical buildup | **PARTIALLY** | Legal context is accessible. Math is rigorous. But no HR definition, no connecting thread in Results, and "Drop-In" test fails. |
| 5 | **Define Hazard Ratio** — plain-English definition before first interpretation | **NOT ADDRESSED** | First appearance is as "log-hazard ratios" in methodology. First interpretation in Results gives no intuitive explanation. |
| 6 | **Define $\widehat{\text{risk}}$** — in or around equation (3.13) | **NOT ADDRESSED** | Equation uses the symbol with no definition. |
| 7 | **Figure Readability** — fix resizing issues, especially Figure 5.1 | **NOT ADDRESSED** | Figures are PNG only. Cannot verify legibility without viewing, but no code changes were made to address sizing. |

**Score: 0/7 items fully addressed.**

---

## H. Rubric Compliance

### Overall Writing
| Criterion | Status |
|---|---|
| References correctly placed | ✅ Mostly (one duplicate style issue) |
| Paragraph consistency | ✅ |
| Transitions between paragraphs | ✅ |
| Key terms consistent | ✅ |
| Grammar | ✅ (needs final proofread) |
| Technical terms described | ❌ Hazard ratio not defined |
| Acronyms introduced | ✅ PSLRA, IDB, CIF, etc. |

### Formatting & References
| Criterion | Status |
|---|---|
| Clickable references (hyperref) | ❌ Not loaded |
| Reference style consistency | ⚠️ Needs bib audit |
| No Subsection 0 | ✅ All start with 1 |
| Variable labels in `$...$` | ✅ |
| No duplicate citation style | ❌ One instance (Wang et al.) |
| No code in thesis | ✅ |
| Orphan/widow headings | ⚠️ Can't verify without compilation |
| Figure/table bleeding | ⚠️ Can't verify without compilation |

### Section-Specific
| Section | Status |
|---|---|
| Abstract | ❌ Placeholder |
| Introduction | ⚠️ Good but needs objective reframe |
| Methodology | ⚠️ Missing IPTW/Frailty sections, undefined $\widehat{\text{risk}}$ |
| Results | ❌ Wrong structure; most important results not first |
| Discussion/Conclusions/Future | ⚠️ Discussion good; Future Work unusable |

---

## I. Gap Analysis

### DONE AND GOOD — preserve, do not touch

- **Data pipeline logic** (InterimScript Sections 1-6): filtering, disposition coding, covariate construction
- **Nonparametric analyses** (Sections 7-10): KM curves, CIF overall/PSLRA/circuit, Gray's tests
- **Cause-specific Cox models** (Sections 11-13): baseline, piecewise, circuit effects
- **Fine-Gray models** (Section 14): baseline subdistribution hazard
- **Extended models** (Section 15): full covariate Cox and Fine-Gray
- **Interaction models** (Section 16): PSLRA x Circuit
- **Robustness checks** (Section 17): coding schemes, temporal restriction, circuit subsets
- **Literature Review** (litreview.tex): complete and well-researched
- **Data Chapter** (data.tex): professional tables, clear sample construction
- **Discussion Chapter** (discussions.tex): strong synthesis, policy implications
- **Notation system** (methodology.tex): consistent, well-defined (except $\widehat{\text{risk}}$)

### DONE BUT NEEDS FIXING

| Item | Problem | Fix needed |
|---|---|---|
| InterimScript path (line 42) | Hardcoded to wrong directory | Change to `data/raw/cv88on.txt` |
| C-index computation (Section 19) | `lp_s`/`lp_d` used before defined | Reorder: compute linear predictors before using them |
| Fine-Gray C-index (Section 23) | Copy-pasted from Cox, methodologically wrong | Compute actual Fine-Gray C-index |
| Fine-Gray claim in writing | Methodology + Results say they share linear predictors | Remove false claim, report actual values |
| `ggsave()` paths | Write to working directory, not `output/figures/` | Prefix all paths with `output/figures/` |
| `saveRDS()` paths | Write to working directory | Save to `data/cleaned/` |
| Figure format | PNG only, no PDF | Add PDF output alongside PNG |
| Results chapter structure | Model-by-model, not claim-by-claim | Full restructure (advisor's #1 ask) |
| Introduction framing | Methods-focused, not causal inference | Rewrite contributions, reframe objective |
| Causal language (results line 231) | "causal signature" used without IPTW | Remove causal language or qualify |
| RSF references | Abandoned but still in intro, methodology, results | Remove Sections 22-23 references, update contribution (iv) |
| Duplicate citation (litreview line 129) | Wang et al. cited two ways | Use `\citet` only |
| Performance table (Table 5.11) | Numbers unreliable | Recompute after fixing bug |

### PARTIALLY DONE

| Item | What exists | What remains |
|---|---|---|
| Methodology chapter | KM, CIF, Cox, Fine-Gray, RSF, diagnostics | Add IPTW section, add Frailty section, define $\widehat{\text{risk}}$, add HR definition, remove RSF or reduce to appendix |
| Abstract | Placeholder file | Write 200-300 word summary |
| Acknowledgements | Placeholder file | Write actual acknowledgements |
| Train/test evaluation | Split exists, AUC code exists | Fix ordering bug, recompute, verify numbers |

### COMPLETELY MISSING — must create from scratch

| Item | Scope | Priority |
|---|---|---|
| **IPTW implementation** (R code) | Propensity score model for PSLRA, WeightIt, cobalt balance diagnostics, IPTW-weighted Cox and CIF | **CRITICAL** — addresses advisor's core ask |
| **Shared Frailty implementation** (R code) | coxme with circuit-level random effects, frailty variance reporting | **HIGH** — addresses unobserved heterogeneity |
| **IPTW methodology section** (LaTeX) | Math, intuition, assumptions, diagnostics | **CRITICAL** |
| **Frailty methodology section** (LaTeX) | Math, intuition, interpretation | **HIGH** |
| **IPTW results** (LaTeX) | Balance table, weighted HRs, causal interpretation | **CRITICAL** |
| **Frailty results** (LaTeX) | Frailty variance, adjusted HRs | **HIGH** |
| **Schoenfeld residual plots** (R code) | Diagnostic plots for PH assumption | **MEDIUM** |
| **Cleaned .rds pipeline** | Save filtered/coded dataset for fast reloads | **MEDIUM** |
| **LaTeX table files** | `.tex` output for all numbered tables | **LOW** (tables are already hard-coded in chapters; auto-generation is nice-to-have) |
| **Proper Future Work / Conclusion** | Rewrite from scratch as thesis chapter | **MEDIUM** |
| **`hyperref` integration** | Add package, configure | **LOW** |

---

## J. Risk Assessment

### Top 5 risks to April 9 completion

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | **IPTW reveals null PSLRA effect** after adjustment | Medium | High — changes the narrative | This is a feature, not a bug. A null causal result is publishable. Prepare Discussion framing for both outcomes. |
| 2 | **Shared Frailty doesn't converge** with 13 circuit-level clusters | Medium | Medium | Fallback: fixed effects + cluster-robust SEs (already partially done). |
| 3 | **Results restructuring takes too long** — 650 lines to reorganize | High | High — advisor's #1 ask | Start with the claim structure outline before rewriting prose. Reuse existing content, don't write from scratch. |
| 4 | **Undiscovered bugs** in Sections 1-17 after path fix | Low-Medium | High — could invalidate numbers in thesis | Run full script end-to-end first, before any new analysis. |
| 5 | **Time pressure** — 13 days for code + writing + review | Certain | Variable | Strict prioritization. Cut scope if needed. |

### Dependency chain

```
Fix data path & script bugs
    ↓
Run clean end-to-end → Verify ALL existing numbers
    ↓
┌──────────────────────┬──────────────────────┐
│ Implement IPTW       │ Implement Frailty    │  (parallel)
│   ↓                  │   ↓                  │
│ Write IPTW method    │ Write Frailty method │  (parallel)
│   ↓                  │   ↓                  │
│ Write IPTW results   │ Write Frailty results│  (parallel)
└──────────┬───────────┴──────────┬───────────┘
           ↓                      ↓
     Restructure Results chapter (claim-based)
           ↓
     Reframe Introduction (causal inference objective)
           ↓
     Update Discussion & write Conclusion/Future Work
           ↓
     Write Abstract
           ↓
     Final polish: hyperref, figure PDFs, proofread
```

### What can be parallelized

- IPTW code and Frailty code are independent — can develop simultaneously
- Methodology sections for IPTW and Frailty can be written in parallel
- Literature review updates (adding 4 new sources from `new_lit_sources.txt`) independent of all code work
- Schoenfeld plots can be generated alongside IPTW/Frailty work

### Fallback points

| If this fails... | Then do this instead... |
|---|---|
| IPTW balance is unachievable | Report the failure honestly. Use sensitivity analysis / partial identification bounds. Still demonstrates causal thinking. |
| Frailty model doesn't converge | Use cause-specific Cox with circuit fixed effects + cluster-robust standard errors (already implemented). Frame frailty as "attempted." |
| Time runs out before all writing is done | Prioritize: (1) IPTW results, (2) Results restructure, (3) Abstract. Drop: Frailty if necessary. |
| Existing numbers don't match after clean rerun | Update ALL hard-coded numbers in thesis. This is non-negotiable — fabricated numbers are worse than a delayed deadline. |

---

## K. Honest Bottom Line

### If submitted tomorrow: ~70-75/100

**Why not higher:**
- Advisor gave 7 specific feedback items. **Zero are addressed.** The advisor grades the thesis.
- Two major promised methods (IPTW, Frailty) completely missing.
- Performance numbers (C-index, AUC) are unreliable due to a code bug.
- Abstract is a placeholder containing $\pi \approx 3.14$.
- Results are organized the exact way the advisor said not to.
- One instance of false causal language. One false methodological claim (Fine-Gray C-index).

**Why not lower:**
- The prose quality is genuinely strong — clear, well-structured, accessible legal context.
- The fall analysis (KM, CIF, Cox, Fine-Gray, robustness) is substantively correct and complete.
- Literature review is thorough and well-cited.
- Data chapter is professional with proper booktabs tables.
- Discussion synthesizes findings well.

### Top 3 highest-impact improvements

1. **Implement IPTW and write it up.** This single addition transforms the thesis from "descriptive survival analysis" to "causal inference study." It directly answers the advisor's #1 concern, adds the most analytical value, and justifies the reframing of the entire thesis objective. This is the difference between a B thesis and an A thesis.

2. **Restructure Results by substantive claims.** The advisor's #2 ask. Convert from "Section 5.2: Cox Model, Section 5.3: Circuit Effects..." to "Claim 1: PSLRA increased dismissal rates by X%... (evidence from Cox, Fine-Gray, IPTW)." This makes the thesis readable and demonstrates that the student is making arguments, not just running models.

3. **Fix the code bugs and rerun end-to-end.** Ensures every number in the thesis is trustworthy. Non-negotiable for academic integrity. Must happen before any new analysis.

### What NOT to waste time on

- **RSF**: Abandoned. Don't fix, don't diagnose, don't discuss. Remove references.
- **`newcommands.tex` cleanup**: Harmless dead weight. Ignore.
- **`utils.R` integration**: Nice-to-have but doesn't affect the grade. The monolithic script works (once bugs are fixed).
- **LaTeX table auto-generation**: Tables are already hard-coded in chapters. Auto-gen from R is cleaner but won't change the grade.
- **Extensive bib formatting audit**: One duplicate citation style to fix. Don't audit every entry.
- **PDF figure conversion**: 5-minute task. Do it last.
- **`hyperref`**: One line to add. Do it last.

---

## Summary: State of the Thesis

| Dimension | Grade | Notes |
|---|---|---|
| Data quality | B | Raw data exists, cleaning logic correct, but no saved clean dataset |
| Code correctness | C+ | Fall analysis solid, spring additions have fatal bugs, two methods missing |
| Writing quality | B+ | Prose is strong, but structure doesn't match advisor's asks |
| Advisor compliance | F | 0/7 items addressed |
| Rubric compliance | C+ | Many items unchecked, placeholder abstract |
| Analytical depth | C+ | Good descriptive + associational work, no causal inference yet |
| **Overall** | **C+/B-** | Strong foundation, critical gaps in execution |

The thesis has strong bones. The writing is better than most ORFE theses at this stage. The analytical framework is sound. But the gap between "what's promised" and "what's delivered" is large, and the advisor's feedback is completely unaddressed. The next 13 days must close that gap.
