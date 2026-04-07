# Authoritative Numbers Reference — April 7, 2026 Pipeline
# Reproducible from: Rscript code/utils/extract_all_numbers.R
# Verified on 2026-04-07 against saved artifacts, including output/models/fine_gray_models.rds
# Use ONLY these numbers in LaTeX.

---

## 1. DATA CHAPTER

### Sample Construction
- NOS 850 (1990+): 65,899
- Class action flag = 1: 13,708
- Valid duration (>0 days): **12,968**
- Zero-duration dropped: 740

### Scheme A Event Distribution
| | N | % |
|---|---|---|
| Settlement | 3,801 | 29.3 |
| Dismissal | 5,971 | 46.0 |
| Censored | 3,196 | 24.6 |
| **Total** | **12,968** | **100.0** |

### Scheme B
| Settlement | Dismissal | Censored | %S | %D | %C |
|---|---|---|---|---|---|
| 5,605 | 4,167 | 3,196 | 43.2 | 32.1 | 24.6 |

### Scheme C
| Settlement | Dismissal | Censored | %S | %D | %C |
|---|---|---|---|---|---|
| 5,919 | 4,167 | 2,882 | 45.6 | 32.1 | 22.2 |

### Duration Statistics (Scheme A, resolved)
| Outcome | N | Mean | Median | Q25 | Q75 |
|---|---|---|---|---|---|
| Settlement | 3,801 | 3.59 | 3.00 | 1.81 | 5.10 |
| Dismissal | 5,971 | 1.56 | 1.01 | 0.24 | 2.18 |

### PSLRA Regime
| Regime | N | Settle | %S | Dismiss | %D | Censored | %C |
|---|---|---|---|---|---|---|---|
| Pre-PSLRA | 1,032 | 465 | 45.1 | 374 | 36.2 | 193 | 18.7 |
| Post-PSLRA | 11,936 | 3,336 | 27.9 | 5,597 | 46.9 | 3,003 | 25.2 |

### Circuit Distribution
(Same as old — confirmed unchanged)
Ninth: 4,051 (31.2%), Second: 3,737 (28.8%), Third: 828 (6.4%),
Fifth: 752 (5.8%), Fourth: 695 (5.4%), Eleventh: 627 (4.8%),
Seventh: 535 (4.1%), Tenth: 532 (4.1%), Eighth: 453 (3.5%),
First: 381 (2.9%), Sixth: 361 (2.8%), DC: 16 (0.1%)

### Origin Categories
Levels: Original, MDL, Other (NOTE: "Removed" collapsed into "Other")
- Original: 11,029
- MDL: 607
- Other: 1,246

### Statutory Basis
Levels: 10(b), Section 11, Other/Both, Missing
- 10(b): 9,424 [in extended sample]
- Section 11: 1,488
- Other/Both: 1,820
- Missing: 134
- Coverage (non-Missing): 99.0%

### Judgment-Bearing Dispositions (codes 4, 6, 15, 17, 19, 20)
| Code | N | JUDGMENT=1 | JUDGMENT=2 | Ambig/Missing |
|---|---|---|---|---|
| 4 | 60 | 57 | 3 | 0 |
| 6 | 2,389 | 701 | 1,418 | 270 |
| 15 | 4 | 3 | 0 | 1 |
| 17 | 1,723 | 1,024 | 225 | 474 |
| 19 | 4 | 0 | 1 | 3 |
| 20 | 2 | 1 | 0 | 1 |
| **Total** | **4,182** | **1,786** | **1,647** | **749** |

Code 6 alone: 2,389 cases (701 plaintiff / 1,418 defendant / 270 ambiguous)

JUDGMENT=1 era breakdown: Pre-PSLRA 98 (5.5%) / Post-PSLRA 1,688 (94.5%)

### DISP=18
1,198 cases, all correctly censored (event_type = 0)

### Settlement Composition (by disposition code)
Code 13: 2,015 | Code 17 (J=1): 1,024 | Code 6 (J=1): 701 | Code 4 (J=1): 57 | Code 15 (J=1): 3 | Code 20 (J=1): 1
Total: 3,801

### Dismissal Composition (by disposition code)
Code 14: 2,401 | Code 12: 1,804 | Code 6 (J=2): 1,418 | Code 17 (J=2): 225 | Code 2: 96 | Code 3: 23 | Code 4 (J=2): 3 | Code 19 (J=2): 1
Total: 5,971

---

## 2. COX MODELS

### Baseline Cox (PSLRA only, N=12,968)
| Outcome | HR | 95% CI | p |
|---|---|---|---|
| Settlement | 0.563 | [0.511, 0.621] | 1.28e-30 |
| Dismissal | 1.409 | [1.269, 1.565] | 1.51e-10 |

### Piecewise Dismissal (N=26,602 person-periods, 5,971 events)
| Period | HR | 95% CI | p |
|---|---|---|---|
| 0-1 years | 1.789 | [1.520, 2.105] | 2.42e-12 |
| 1-2 years | 1.255 | [1.016, 1.550] | 0.035 |
| 2+ years | 1.063 | [0.886, 1.276] | 0.510 |

### Piecewise Settlement
| Period | HR | 95% CI | p |
|---|---|---|---|
| 0-1 years | 0.518 | [0.395, 0.678] | 1.71e-06 |
| 1-2 years | 0.387 | [0.323, 0.464] | 9.94e-25 |
| 2+ years | 0.673 | [0.591, 0.767] | 2.37e-09 |

### Circuit Cox (PSLRA + circuit, N=12,952)
**Settlement (events=3,798):**
| Covariate | HR | 95% CI | p |
|---|---|---|---|
| post_pslra | 0.754 | [0.683, 0.834] | 3.63e-08 |
| 1st | 2.248 | [1.751, 2.886] | 2.08e-10 |
| 3rd | 4.326 | [3.768, 4.965] | 2.92e-96 |
| 4th | 1.134 | [1.008, 1.275] | 0.036 |
| 5th | 1.986 | [1.664, 2.371] | 2.97e-14 |
| 6th | 3.830 | [3.216, 4.562] | 2.99e-51 |
| 7th | 2.536 | [2.140, 3.005] | 5.99e-27 |
| 8th | 3.672 | [3.070, 4.393] | 5.48e-46 |
| 9th | 2.451 | [2.233, 2.691] | 4.73e-79 |
| 10th | 3.233 | [2.785, 3.751] | 7.81e-54 |
| 11th | 2.165 | [1.803, 2.600] | 1.34e-16 |

Circuit settlement range: 1.134 (4th) to 4.326 (3rd) times Second Circuit
NOTE: Old chapter said "4.1 to 17.6" — this was from the old data. Now it's 1.1 to 4.3.

**Dismissal (events=5,966):**
| Covariate | HR | 95% CI | p |
|---|---|---|---|
| post_pslra | 1.558 | [1.401, 1.733] | 2.73e-16 |
| 1st | 1.442 | [1.239, 1.680] | 2.45e-06 |
| 3rd | 1.043 | [0.918, 1.186] | 0.515 |
| 4th | 0.367 | [0.318, 0.422] | 8.68e-44 |
| 5th | 1.396 | [1.247, 1.564] | 7.52e-09 |
| 6th | 0.995 | [0.841, 1.178] | 0.956 |
| 7th | 1.500 | [1.323, 1.701] | 2.48e-10 |
| 8th | 1.051 | [0.903, 1.223] | 0.519 |
| 9th | 1.183 | [1.108, 1.262] | 3.96e-07 |
| 10th | 0.745 | [0.637, 0.872] | 0.000 |
| 11th | 1.528 | [1.355, 1.723] | 4.09e-12 |

### Extended Cox (N=12,866)
**Settlement (events=3,755):**
| Covariate | HR | 95% CI | p |
|---|---|---|---|
| post_pslra | 0.784 | [0.709, 0.867] | 2.42e-06 |
| 1st | 1.782 | [1.385, 2.292] | 6.91e-06 |
| 3rd | 3.481 | [3.021, 4.012] | 1.39e-66 |
| 4th | 1.926 | [1.592, 2.331] | 1.62e-11 |
| 5th | 1.722 | [1.439, 2.061] | 2.88e-09 |
| 6th | 3.086 | [2.583, 3.689] | 2.85e-35 |
| 7th | 2.011 | [1.691, 2.392] | 2.78e-15 |
| 8th | 3.062 | [2.554, 3.670] | 1.13e-33 |
| 9th | 1.944 | [1.762, 2.145] | 4.06e-40 |
| 10th | 2.805 | [2.398, 3.281] | 4.45e-38 |
| 11th | 1.625 | [1.346, 1.961] | 4.26e-07 |
| origin: MDL | 0.397 | [0.330, 0.478] | 1.32e-22 |
| origin: Other | 1.720 | [1.543, 1.918] | 1.36e-22 |
| MDL flag | 0.490 | [0.425, 0.566] | 1.64e-22 |
| Fed Question | 2.830 | [1.702, 4.706] | 6.05e-05 |
| Section 11 | 1.091 | [0.979, 1.217] | 0.115 |
| Other/Both | 0.994 | [0.902, 1.095] | 0.899 |
| Missing | 0.831 | [0.600, 1.151] | 0.265 |

Extended settlement circuit range: 1.625 (11th) to 3.481 (3rd) times Second Circuit.

**Dismissal (events=5,959):**
| Covariate | HR | 95% CI | p |
|---|---|---|---|
| post_pslra | 1.661 | [1.493, 1.847] | 8.61e-21 |
| 1st | 1.194 | [1.025, 1.390] | 0.023 |
| 3rd | 0.870 | [0.766, 0.989] | 0.033 |
| 4th | 0.643 | [0.527, 0.783] | 1.15e-05 |
| 5th | 1.202 | [1.073, 1.347] | 0.001 |
| 6th | 0.833 | [0.702, 0.988] | 0.036 |
| 7th | 1.200 | [1.058, 1.361] | 0.005 |
| 8th | 0.910 | [0.782, 1.058] | 0.220 |
| 9th | 0.968 | [0.907, 1.033] | 0.326 |
| 10th | 0.727 | [0.621, 0.851] | 7.12e-05 |
| 11th | 1.222 | [1.084, 1.378] | 0.001 |
| origin: MDL | 0.323 | [0.261, 0.400] | 5.06e-25 |
| origin: Other | 0.857 | [0.777, 0.945] | 0.002 |
| MDL flag | 0.106 | [0.084, 0.134] | 2.97e-78 |
| Fed Question | 2.148 | [1.368, 3.373] | 0.001 |
| Section 11 | 1.167 | [1.074, 1.269] | 0.000 |
| Other/Both | 1.097 | [1.019, 1.181] | 0.014 |
| Missing | 0.851 | [0.646, 1.122] | 0.254 |

### PH Tests (Extended Cox)
**Settlement:**
| Covariate | chi-sq | df | p |
|---|---|---|---|
| post_pslra | 92.35 | 1 | 7.27e-22 |
| circuit_f | 268.9 | 10 | 5.63e-52 |
| origin_cat | 241.2 | 2 | 4.26e-53 |
| mdl_flag | 197.3 | 1 | 8.04e-45 |
| juris_fq | 0.004 | 1 | 0.947 |
| stat_basis_f | 59.76 | 3 | 6.62e-13 |
| **GLOBAL** | **597.4** | **18** | **3.06e-115** |

**Dismissal:**
| Covariate | chi-sq | df | p |
|---|---|---|---|
| post_pslra | 14.67 | 1 | **1.28e-04** |
| circuit_f | 177.1 | 10 | 9.58e-33 |
| origin_cat | 132.0 | 2 | 2.21e-29 |
| mdl_flag | 1.053 | 1 | 0.305 |
| juris_fq | 2.668 | 1 | 0.102 |
| stat_basis_f | 63.26 | 3 | 1.18e-13 |
| **GLOBAL** | **361.8** | **18** | **8.11e-66** |

CRITICAL: Dismissal PSLRA PH is now p=0.000128 (REJECTS PH), not p=0.120 as in old text.

### Baseline Cox PH Tests
| Covariate | Settlement chi-sq / p | Dismissal chi-sq / p |
|---|---|---|
| post_pslra | 43.31 / 4.67e-11 | 38.69 / 4.98e-10 |

### Interaction Models (N=10,652)
**Settlement:**
| Term | HR | 95% CI | p |
|---|---|---|---|
| PSLRA (main, 2nd Cir) | 1.411 | [1.016, 1.959] | 0.040 |
| x 3rd | 0.377 | [0.250, 0.567] | 2.91e-06 |
| x 4th | 0.745 | [0.308, 1.804] | 0.514 |
| x 5th | 0.380 | [0.229, 0.629] | 0.000 |
| x 9th | 0.761 | [0.525, 1.101] | 0.148 |
| x 11th | 0.235 | [0.137, 0.403] | 1.43e-07 |

**Dismissal:**
| Term | HR | 95% CI | p |
|---|---|---|---|
| PSLRA (main, 2nd Cir) | 2.660 | [1.904, 3.716] | 9.70e-09 |
| x 3rd | 2.325 | [1.214, 4.453] | 0.011 |
| x 4th | 0.145 | [0.081, 0.259] | 7.71e-11 |
| x 5th | 0.447 | [0.284, 0.703] | 0.000 |
| x 9th | 0.589 | [0.405, 0.855] | 0.005 |
| x 11th | 0.678 | [0.395, 1.165] | 0.160 |

**LRT:**
- Settlement: chi-sq = 51.45, df=5, p = 7.00e-10
- Dismissal: chi-sq = 71.87, df=5, p = 4.17e-14

### C-Indices (in-sample, full training data)
| Model | Settlement | Dismissal |
|---|---|---|
| Baseline | 0.537 | 0.517 |
| Circuit-only | 0.646 | 0.569 |
| Extended | 0.689 | 0.611 |
| Interaction | 0.690 | 0.607 |

---

## 3. IPTW

### Triangulation Table (N=12,866)
| Strategy | Settlement HR | 95% CI | p | Dismissal HR | 95% CI | p |
|---|---|---|---|---|---|---|
| 1. Unadjusted | 0.557 | 0.505–0.615 | 1.32e-31 | 1.414 | 1.273–1.570 | 9.97e-11 |
| 2. Regression-Adjusted | 0.784 | 0.709–0.867 | 2.42e-06 | 1.661 | 1.493–1.847 | 8.61e-21 |
| 3. Weighted + Covariates | 0.780 | 0.682–0.892 | 2.76e-04 | 1.754 | 1.549–1.987 | 8.49e-19 |
| 4. MSM | **0.741** | **0.632–0.868** | **2.04e-04** | **1.519** | **1.335–1.729** | **2.37e-10** |

### Metadata
- Estimand: ATT
- N total: 12,866
- N pre-PSLRA: 1,031
- N post-PSLRA: 11,835
- Trim cap: 43.54

### Balance
- 20 balance rows (incl. propensity score distance)
- All |SMD| < 0.10 after weighting
- Max adjusted |SMD|: 0.053 (propensity score)
- Max covariate |SMD|: 0.035 (Section 11)
- ESS: pre-PSLRA 577.61 (56.0% of 1,031); post-PSLRA 11,835

---

## 4. FRAILTY

### Frailty Variance (theta)
| Model | Settlement theta | Dismissal theta |
|---|---|---|
| Baseline | 0.2192 | 0.1643 |
| Extended | **0.1296** | **0.0397** |

### PSLRA Hazard Ratios by Estimation Strategy
| Model | Settlement HR [CI] p | Dismissal HR [CI] p |
|---|---|---|
| No circuit (naive SE) | 0.563 [0.511, 0.621] 1.28e-30 | 1.409 [1.269, 1.565] 1.51e-10 |
| No circuit (cluster-robust) | 0.564 [0.381, 0.833] 4.04e-03 | 1.409 [1.013, 1.961] 4.14e-02 |
| Circuit FE (naive SE) | 0.754 [0.683, 0.834] 3.63e-08 | 1.558 [1.401, 1.733] 2.73e-16 |
| Circuit RE (frailty) | 0.752 [0.681, 0.832] 2.65e-08 | 1.556 [1.399, 1.730] 3.45e-16 |
| Extended FE (naive SE) | 0.784 [0.709, 0.867] 2.42e-06 | 1.661 [1.493, 1.847] 8.61e-21 |
| **Extended FE (cluster-robust)** | **0.784 [0.559, 1.099] p=0.158** | **1.661 [1.298, 2.126] p=5.51e-05** |
| Extended RE (frailty) | 0.783 [0.707, 0.866] 2.01e-06 | 1.660 [1.493, 1.847] 9.09e-21 |

CRITICAL: Extended cluster-robust settlement is **NON-SIGNIFICANT** (p=0.158).

---

## 5. FINE-GRAY

### Extended Fine-Gray (N=12,866)
**Settlement SHRs:**
| Covariate | SHR | 95% CI | p |
|---|---|---|---|
| post_pslra | 0.503 | [0.452, 0.560] | 5.82e-36 |
| MDL flag | 2.468 | [2.241, 2.717] | 1.91e-75 |
| origin: MDL | 1.195 | [1.039, 1.374] | 0.013 |
| origin: Other | 1.689 | [1.496, 1.908] | 2.90e-17 |

**Dismissal SHRs:**
| Covariate | SHR | 95% CI | p |
|---|---|---|---|
| post_pslra | 1.719 | [1.549, 1.908] | 2.42e-24 |
| MDL flag | 0.174 | [0.138, 0.219] | 3.84e-50 |
| origin: MDL | 0.510 | [0.402, 0.646] | 2.56e-08 |
| origin: Other | 0.727 | [0.658, 0.802] | 2.31e-10 |

### CS Cox vs Fine-Gray Comparison (for results table)
| Outcome | Covariate | CS HR | FG SHR | FG 95% CI | FG p |
|---|---|---|---|---|---|
| Settlement | Post-PSLRA | 0.784 | 0.503 | [0.452, 0.560] | <0.001 |
| Settlement | MDL Flag | 0.490 | 2.468 | [2.241, 2.717] | <0.001 |
| Dismissal | Post-PSLRA | 1.661 | 1.719 | [1.549, 1.908] | <0.001 |
| Dismissal | MDL Flag | 0.106 | 0.174 | [0.138, 0.219] | <0.001 |

NOTE: The MDL sign reversal is now a confirmed, highly significant result.
CS settlement MDL: 0.490 (suppressed) vs FG SHR: 2.468 (amplified, p<0.001).

### Fine-Gray PH Tests
| Model | post_pslra chi-sq / p | GLOBAL chi-sq / p |
|---|---|---|
| Settlement | 54.92 / 1.25e-13 | 1463.8 / 2.81e-300 |
| Dismissal | 11.78 / 5.97e-04 | 346.5 / 1.20e-62 |

---

## 6. ROBUSTNESS

| Specification | Outcome | N | Events | HR | CI_lower | CI_upper | p |
|---|---|---|---|---|---|---|---|
| Scheme A | Settlement | 12,968 | 3,801 | 0.563 | 0.511 | 0.621 | <0.001 |
| Scheme A | Dismissal | 12,968 | 5,971 | 1.409 | 1.269 | 1.565 | <0.001 |
| Scheme B | Settlement | 12,968 | 5,605 | 0.799 | 0.730 | 0.874 | <0.001 |
| Scheme B | Dismissal | 12,968 | 4,167 | 1.183 | 1.053 | 1.330 | 0.005 |
| Scheme C | Settlement | 12,968 | 5,919 | 0.788 | 0.722 | 0.859 | <0.001 |
| Scheme C | Dismissal | 12,968 | 4,167 | 1.183 | 1.053 | 1.330 | 0.005 |
| Excl post-2020 | Settlement | 12,108 | 3,702 | 0.558 | 0.506 | 0.616 | <0.001 |
| Excl post-2020 | Dismissal | 12,108 | 5,423 | 1.333 | 1.200 | 1.481 | <0.001 |
| 2nd Circuit | Settlement | 3,737 | 982 | 1.052 | 0.757 | 1.462 | 0.762 |
| 2nd Circuit | Dismissal | 3,737 | 1,942 | 1.941 | 1.387 | 2.715 | <0.001 |
| 9th Circuit | Settlement | 4,051 | 1,081 | 0.957 | 0.803 | 1.140 | 0.622 |
| 9th Circuit | Dismissal | 4,051 | 1,891 | 1.575 | 1.329 | 1.865 | <0.001 |
| Spline | Settlement | 12,968 | 3,801 | 0.714 | 0.548 | 0.932 | 0.013 |
| Spline | Dismissal | 12,968 | 5,971 | 3.515 | 2.730 | 4.525 | <0.001 |

### Summary Ranges
- Settlement HRs: [0.558, 1.052] — NOTE: Second Circuit crosses 1!
- Dismissal HRs: [1.183, 3.515]

---

## 7. CIF HORIZONS

### By PSLRA Regime (Aalen-Johansen)
| Regime | Outcome | 1 yr | 2 yr | 3 yr | 5 yr |
|---|---|---|---|---|---|
| Pre-PSLRA | Settlement | 6.4 | 22.4 | 33.3 | 51.0 |
| Pre-PSLRA | Dismissal | 15.4 | 25.6 | 29.7 | 37.8 |
| Post-PSLRA | Settlement | 3.0 | 9.0 | 16.2 | 26.8 |
| Post-PSLRA | Dismissal | 25.4 | 37.5 | 45.5 | 52.1 |

### Overall CIF (ungrouped)
| Outcome | 1 yr | 2 yr | 3 yr | 5 yr | 8 yr |
|---|---|---|---|---|---|
| Settlement | 3.3 | 10.1 | 17.7 | 28.8 | 39.3 |
| Dismissal | 24.6 | 36.5 | 44.2 | 50.9 | 54.1 |

### Gray's Tests
| Stratifier | Outcome 1 stat | Outcome 2 stat | p |
|---|---|---|---|
| PSLRA | 131.3 (settlement) | 82.1 (dismissal) | <0.001 |
| Circuit | 204.0 (settlement) | 321.2 (dismissal) | <0.001 |

---

## 8. CLEAN WINDOW AND PLACEBO

### Clean Window (1993-1998, N=1,235)
| Outcome | HR | 95% CI | p |
|---|---|---|---|
| Settlement | 0.724 | [0.607, 0.864] | 0.000 |
| Dismissal | 1.482 | [1.243, 1.768] | 1.20e-05 |

### Placebo (1992 cutoff, pre-PSLRA only, N=1,032)
| Outcome | HR | 95% CI | p |
|---|---|---|---|
| Settlement | 1.638 | [1.289, 2.082] | 5.33e-05 |
| Dismissal | 0.733 | [0.588, 0.913] | 0.006 |

---

## 9. PERFORMANCE (held-out 30% test set)

| Model | C-index | SE | AUC@1yr | AUC@3yr | AUC@5yr | IBS |
|---|---|---|---|---|---|---|
| Cox (Settlement) | 0.679 | 0.009 | 0.732 | 0.705 | 0.793 | 0.1212 |
| Cox (Dismissal) | 0.597 | 0.007 | 0.595 | 0.643 | 0.775 | 0.1842 |
| Fine-Gray (Settlement) | 0.555 | 0.010 | 0.659 | 0.531 | 0.377 | NA |
| Fine-Gray (Dismissal) | 0.595 | 0.007 | 0.592 | 0.633 | 0.770 | NA |

---

## 10. REWRITE FLAGS

Key current-pipeline facts the LaTeX chapters must reflect (see
`docs/session-log.md` Section 4 for the stale chapter list):

1. Piecewise 1-2 yr dismissal is marginally significant (p=0.035); 2+ yr is null (p=0.510).
2. Dismissal PSLRA now rejects PH (p=1.28e-04). Both outcomes violate PH.
3. Extended cluster-robust settlement is non-significant (p=0.158).
4. Extended settlement frailty variance = 0.1296.
5. Circuit-only settlement HRs range 1.134–4.326; extended range 1.625–3.481.
6. MDL FG settlement SHR = 2.468 (p<0.001, significant).
7. Second Circuit robustness settlement HR = 1.052 (crosses 1, p=0.762).
8. PSLRA Gray's test statistics: settlement 131.3, dismissal 82.1.
9. Origin "Removed" is collapsed into "Other" — three levels only.
10. Judgment-bearing disaggregation covers codes {4,6,15,17,19,20}, not Code 6 alone.
