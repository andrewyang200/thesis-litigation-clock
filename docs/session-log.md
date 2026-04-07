# Thesis State — Current Code-Side Source of Truth

> Last updated: 2026-04-07.
> Use `docs/authoritative-numbers.md` and `code/utils/extract_all_numbers.R` for exact thesis numbers.
> This file is the condensed continuity summary for future sessions.

---

## 1. Status

- **Phase 1-3**: complete.
- **Phase 4**: code-side verification complete; LaTeX propagation and final thesis-level review still pending.
- **Current blocker**: update the chapter `.tex` files to match the verified 2026-04-07 outputs, then run final `/review` and `/challenge`.

### Source Hierarchy
1. `docs/authoritative-numbers.md`
2. `code/utils/extract_all_numbers.R`
3. `output/models/*.rds` and `output/tables/tab_model_performance.tex`
4. `CLAUDE.md`
5. Historical planning / verification docs only for background, not for current numbers

---

## 2. Locked Analytical State

### Data and Coding
- **Cohort**: 12,968 securities class actions (NOS 850), 1990-2024, from FJC IDB.
- **Pipeline counts**: 65,899 -> 13,708 -> 12,968.
- **Scheme A**: 3,801 settlement / 5,971 dismissal / 3,196 censored.
- **Scheme B**: 5,605 settlement / 4,167 dismissal / 3,196 censored.
- **Scheme C**: 5,919 settlement / 4,167 dismissal / 2,882 censored.
- **Judgment-bearing dispositions**: `disp %in% {4, 6, 15, 17, 19, 20}` use `JUDGMENT` consistently.
- **Statistical closings**: `disp = 18` is censored in all schemes.
- **Origin factor**: `origin_cat == "Removed"` is collapsed into `"Other"` globally.

### Model Specification
- **Extended formula**: `post_pslra + circuit_f + origin_cat + mdl_flag + juris_fq + stat_basis_f`
- `stat_basis_f` missing values are retained as explicit `"Missing"` in the extended sample.
- `mdl_flag` stays out of the propensity score model because pre-PSLRA MDL cases are structurally absent.
- Linear `filing_year` is banned. Only the spline robustness specification `ns(filing_year, df = 3)` is used.

### Fine-Gray and Verification
- Fine-Gray models use subject-level clustering with `cluster = case_id`.
- Saved Fine-Gray `coxph` objects now retain `x`, `y`, and `model`, so `cox.zph()` works after reload from `output/models/fine_gray_models.rds`.
- `code/utils/extract_all_numbers.R` is now verified on the **saved-model branch**, not only the Fine-Gray refit fallback.
- Fine-Gray sample size should be reported as **`N = 12,866` cases**, not the finegray-expanded row count.

### Language Discipline
- Use **"associated with"** for Cox and Fine-Gray.
- Use **"composition-adjusted"** or **"after adjusting for observable case composition"** for IPTW.
- Do **not** describe IPTW results as causal.
- Constant-HR models are time-averaged summaries because PH is violated.

---

## 3. Current Authoritative Results

### Headline Models
| Model | Settlement | Dismissal |
|---|---|---|
| Baseline Cox | 0.563 [0.511, 0.621] | 1.409 [1.269, 1.565] |
| Extended Cox | 0.784 [0.709, 0.867] | 1.661 [1.493, 1.847] |
| Extended Fine-Gray | 0.503 [0.452, 0.560] | 1.719 [1.549, 1.908] |
| IPTW MSM | 0.741 [0.632, 0.868] | 1.519 [1.335, 1.729] |

### Piecewise Dismissal Cox
| Period | HR | p |
|---|---|---|
| 0-1 years | 1.789 | <0.001 |
| 1-2 years | 1.255 | 0.035 |
| 2+ years | 1.063 | 0.510 |

### IPTW Design and Diagnostics
- **Estimand**: ATT
- **Trim cap**: 43.54
- **Sample**: 1,031 pre-PSLRA / 11,835 post-PSLRA (`N = 12,866`)
- **ESS after trimming**: 577.61 pre-PSLRA / 11,835 post-PSLRA
- **Balance**: all 20 adjusted rows are below `|SMD| < 0.1`
- **Max adjusted |SMD|**: 0.053 (propensity score)
- **Max covariate |SMD|**: 0.035 (Section 11)

### Frailty and Cluster-Robust Sensitivity
- **Frailty variance**:
  - Settlement: baseline `0.2192`, extended `0.1296`
  - Dismissal: baseline `0.1643`, extended `0.0397`
- **Extended cluster-robust settlement Cox**: `0.784 [0.559, 1.099]`, `p = 0.158`
- **Extended cluster-robust dismissal Cox**: `1.661 [1.298, 2.126]`, `p = 5.51e-05`

### Fine-Gray PH Tests
- Settlement `post_pslra`: `chi-sq = 54.92`, `p = 1.25e-13`
- Settlement global: `chi-sq = 1463.8`, `p = 2.81e-300`
- Dismissal `post_pslra`: `chi-sq = 11.78`, `p = 5.97e-04`
- Dismissal global: `chi-sq = 346.5`, `p = 1.20e-62`

### Extended Cox PH Tests
- Settlement global: `chi-sq = 597.4`, `p = 3.06e-115`
- Dismissal global: `chi-sq = 361.8`, `p = 8.11e-66`
- Dismissal `post_pslra`: `chi-sq = 14.67`, `p = 1.28e-04`

### Robustness Range
| Specification | Settlement | Dismissal |
|---|---|---|
| Scheme A | 0.563 | 1.409 |
| Scheme B | 0.799 | 1.183 |
| Scheme C | 0.788 | 1.183 |
| Exclude post-2020 | 0.558 | 1.333 |
| 2nd Circuit only | 1.052 | 1.941 |
| 9th Circuit only | 0.957 | 1.575 |
| Spline time trend | 0.714 | 3.515 |

### Performance
| Model | C-index | AUC @ 1yr | AUC @ 3yr | AUC @ 5yr | IBS |
|---|---|---|---|---|---|
| Cox (Settlement) | 0.679 | 0.732 | 0.705 | 0.793 | 0.1212 |
| Cox (Dismissal) | 0.597 | 0.595 | 0.643 | 0.775 | 0.1842 |
| Fine-Gray (Settlement) | 0.555 | 0.659 | 0.531 | 0.377 | NA |
| Fine-Gray (Dismissal) | 0.595 | 0.592 | 0.633 | 0.770 | NA |

---

## 4. Writing Constraints and Stale Chapters

### Headline Writing Rules
- Lead dismissal claims with the IPTW MSM dismissal estimate (`HR = 1.519`) rather than the spline extreme.
- Report robustness ranges as settlement `[0.558, 1.052]` and dismissal `[1.183, 3.515]`.
- State clearly that extended cluster-robust settlement is **not significant**.
- Report that both outcomes violate PH; do not describe the constant-HR models as fully time-invariant.
- Report Fine-Gray honestly: stronger causal-composition contrast for settlement, but weaker discrimination than Cox.

### Known Stale `.tex` Files
- `writing/chapters/abstract.tex`
- `writing/chapters/introduction.tex`
- `writing/chapters/methodology.tex`
- `writing/chapters/data.tex`
- `writing/chapters/results.tex`
- `writing/chapters/discussion.tex`
- `writing/chapters/conclusion.tex`

### Specific Stale Themes To Remove
- old Scheme A event shares (`20.9 / 67.3 / 11.7`)
- old Cox numbers (`0.445`, `1.468`, `0.702`, `1.751`)
- old Fine-Gray numbers (`0.454`, `1.864`)
- old robustness ranges (`[1.32, 2.45]` dismissal; `[0.44, 0.98]` settlement)
- any claim that extended cluster-robust settlement remains significant
- any prose that treats judgment-bearing coding as a Code-6-only issue
- any causal language stronger than the locked discipline above

### Final Non-Code Item
- `writing/chapters/acknow.tex` still needs Andrew's personal text.

---

## 5. Next Steps

1. Propagate the verified 2026-04-07 numbers into the stale chapter files.
2. Update prose so the coding rules, robustness ranges, PH violations, and Fine-Gray findings match the current outputs.
3. Run thesis-level `/review` on the `.tex` files.
4. Run thesis-level `/challenge` on the `.tex` files.
5. Resolve any last citation, formatting, or number-integrity issues before submission.

---

## 6. Recent History (Condensed)

### 2026-04-06
- fixed judgment-bearing disposition coding across `{4, 6, 15, 17, 19, 20}`
- censored `DISP = 18` globally
- collapsed `origin_cat == "Removed"` into `"Other"`
- added `case_id` and carried it into Fine-Gray clustering

### 2026-04-07
- reran the full authoritative analysis pipeline and refreshed diagnostics outputs
- refreshed `output/tables/tab_model_performance.tex`
- regenerated `output/models/fine_gray_models.rds`
- reconciled `docs/authoritative-numbers.md`, `code/utils/extract_all_numbers.R`, and the saved Fine-Gray artifact

