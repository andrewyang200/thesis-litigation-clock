# Number Verification Report — Task 4

> **Superseded for code-side numbers on 2026-04-07.** Later full reruns corrected judgment-bearing disposition coding in `01_clean.R`, censored `DISP=18`, refreshed the model outputs, and refreshed `07_diagnostics.R`. For the current authoritative code outputs, use `docs/session-log.md`.

> **Generated**: 2026-03-28
> **Pipeline**: 01_clean.R → 02_descriptives.R → 03_cox_models.R → 04_fine_gray.R → 07_diagnostics.R → 08_robustness.R
> **All scripts ran cleanly with zero errors.**
> **Root cause of all discrepancies**: Code 6 (judgment on motion) reclassified from censored → dismissal per FJC Codebook (Task 1). This moved 2,389 cases from censored to dismissal under Scheme A.

---

## data.tex Verification

### Table 4.1: Sample Construction — ALL CONFIRMED
| Item | Thesis | R Output | Status |
|------|--------|----------|--------|
| NOS 850 cases | 65,899 | 65,899 | CONFIRMED |
| Class action flag=1 | 13,708 | 13,708 | CONFIRMED |
| Valid duration | 12,968 | 12,968 | CONFIRMED |

### Table 4.2: Outcome Distribution by Scheme
| Item | Thesis | R Output | Status |
|------|--------|----------|--------|
| Scheme A Settlements | 2,015 | 2,015 | CONFIRMED |
| Scheme A Dismissals | 7,313 | **9,702** | DISCREPANCY → UPDATED |
| Scheme A Censored | 3,640 | **1,251** | DISCREPANCY → UPDATED |
| Scheme A %S | 15.5% | 15.5% | CONFIRMED |
| Scheme A %D | 56.4% | **74.8%** | DISCREPANCY → UPDATED |
| Scheme B Settlements | 3,819 | 3,819 | CONFIRMED |
| Scheme B Dismissals | 5,509 | **7,898** | DISCREPANCY → UPDATED |
| Scheme B Censored | 3,640 | **1,251** | DISCREPANCY → UPDATED |
| Scheme B %S | 29.4% | 29.4% | CONFIRMED |
| Scheme B %D | 42.5% | **60.9%** | DISCREPANCY → UPDATED |
| Scheme C Settlements | 4,133 | 4,133 | CONFIRMED |
| Scheme C Dismissals | 5,509 | **7,898** | DISCREPANCY → UPDATED |
| Scheme C Censored | 3,326 | **937** | DISCREPANCY → UPDATED |
| Scheme C %S | 31.9% | 31.9% | CONFIRMED |
| Scheme C %D | 42.5% | **60.9%** | DISCREPANCY → UPDATED |

### Table 4.3: Circuit Distribution — ALL CONFIRMED
All 12 circuits match exactly.

### Table 4.4: Duration by Outcome
| Item | Thesis | R Output | Status |
|------|--------|----------|--------|
| Settlement N=2,015, Mean=2.85, Median=2.53, Q25=1.45, Q75=3.56 | — | — | ALL CONFIRMED |
| Dismissal N | 7,313 | **9,702** | DISCREPANCY → UPDATED |
| Dismissal Mean | 1.97 | **2.19** | DISCREPANCY → UPDATED |
| Dismissal Median | 1.13 | **1.53** | DISCREPANCY → UPDATED |
| Dismissal Q25 | 0.23 | **0.33** | DISCREPANCY → UPDATED |
| Dismissal Q75 | 3.04 | **3.22** | DISCREPANCY → UPDATED |

### Table 4.5: By PSLRA Regime
| Item | Thesis | R Output | Status |
|------|--------|----------|--------|
| Pre-PSLRA N=1,032, Settle=367, %S=35.6% | — | — | CONFIRMED |
| Pre-PSLRA Dismiss | 386 | **576** | DISCREPANCY → UPDATED |
| Pre-PSLRA Censored | 279 | **89** | DISCREPANCY → UPDATED |
| Pre-PSLRA %D | 37.4% | **55.8%** | DISCREPANCY → UPDATED |
| Post-PSLRA N=11,936, Settle=1,648, %S=13.8% | — | — | CONFIRMED |
| Post-PSLRA Dismiss | 6,927 | **9,126** | DISCREPANCY → UPDATED |
| Post-PSLRA Censored | 3,361 | **1,162** | DISCREPANCY → UPDATED |
| Post-PSLRA %D | 58.0% | **76.5%** | DISCREPANCY → UPDATED |

### Scheme A Definition (prose)
- OLD: "Codes 2, 3, 4, 12, 14, 15, 17, 18, 19"
- NEW: "Codes 2, 3, 4, **6**, 12, 14, 15, 17, 18, 19" → UPDATED

---

## results.tex Verification

### CIF Horizons Table
| Item | Thesis | R Output | Status |
|------|--------|----------|--------|
| Pre-PSLRA Settle 1/2/3/5yr | 4.7/19.1/28.1/43.8 | **4.6/17.8/25.3/36.5** | DISCREPANCY → UPDATED |
| Pre-PSLRA Dismiss 1/2/3/5yr | 15.0/25.9/29.5/42.2 | **19.0/34.6/41.7/55.1** | DISCREPANCY → UPDATED |
| Post-PSLRA Settle 1/2/3/5yr | 2.0/5.8/10.1/15.7 | **2.0/5.5/8.9/13.0** | DISCREPANCY → UPDATED |
| Post-PSLRA Dismiss 1/2/3/5yr | 29.6/38.9/48.5/62.9 | **31.8/46.7/59.1/73.0** | DISCREPANCY → UPDATED |

### Gray's Test Statistics
| Item | Thesis | R Output | Status |
|------|--------|----------|--------|
| PSLRA Settlement | 397.6 | **370.3** | DISCREPANCY → UPDATED |
| PSLRA Dismissal | 179.8 | **172.8** | DISCREPANCY → UPDATED |
| Circuit Dismissal | 812.6 | **573.5** | DISCREPANCY → UPDATED |
| Circuit Settlement | 38.2 | **15.3** | DISCREPANCY → UPDATED |

### Baseline Cox
| Item | Thesis | R Output | Status |
|------|--------|----------|--------|
| Settlement HR=0.378 (0.337, 0.424), PH p=0.12 | — | — | ALL CONFIRMED |
| Dismissal HR | 1.638 (1.478, 1.815) | **1.415 (1.301, 1.540)** | DISCREPANCY → UPDATED |
| Dismissal PH p | 0.0001 | **<0.001** | DISCREPANCY → UPDATED |

### Piecewise Model
| Item | Thesis | R Output | Status |
|------|--------|----------|--------|
| 0-1yr HR | 2.180 (1.850, 2.560) | **1.860 (1.610, 2.150)** | DISCREPANCY → UPDATED |
| 1-2yr HR | 0.922 (0.748, 1.140), p=0.444 | **1.040 (0.884, 1.230), p=0.614** | DISCREPANCY → UPDATED |
| 2+yr HR | 1.550 (1.300, 1.840) | **1.290 (1.130, 1.480)** | DISCREPANCY → UPDATED |

### Circuit Cox — Settlement HRs: ALL CONFIRMED (unchanged)
### Circuit Cox — Dismissal HRs: ALL CHANGED
| Circuit | Thesis | R Output |
|---------|--------|----------|
| PSLRA | 1.846 | **1.617** |
| First | 1.385 | **1.641** |
| Third | 1.178 | **1.341** |
| Fourth | 0.262 | **0.516** |
| Fifth | 1.483 | **1.560** |
| Sixth | 0.726 | **0.974** |
| Seventh | 1.251 | **1.309** |
| Eighth | 0.913 | **1.266** |
| Ninth | 1.103 | **1.327** |
| Tenth | 0.805 | **1.149** |
| Eleventh | 1.607 | **1.625** |

### Extended Cox — Settlement
| Item | Thesis | R Output | Status |
|------|--------|----------|--------|
| PSLRA HR | 0.617 | **0.609** | DISCREPANCY → UPDATED |
| Statutory coverage | 97.5% | **99.0%** | DISCREPANCY → UPDATED |
| Most circuit/case HRs | Minor changes | — | UPDATED |
| NEW: stat_basis Missing row | (absent) | 0.891 (0.618, 1.283) | ADDED |

### Extended Cox — Dismissal: ALL CHANGED
| Item | Thesis | R Output | Status |
|------|--------|----------|--------|
| PSLRA HR | 1.941 | **1.736** | DISCREPANCY → UPDATED |
| All circuit/case HRs changed | — | — | ALL UPDATED |
| NEW: stat_basis Missing row | (absent) | 1.018 (0.826, 1.255) | ADDED |

### PH Tests (Extended)
| Item | Thesis | R Output | Status |
|------|--------|----------|--------|
| Settlement χ² | 102.9 | **112.8** | DISCREPANCY → UPDATED |
| Dismissal χ² | 436.9 | **587.1** | DISCREPANCY → UPDATED |

### Fine-Gray Comparison Table
| Item | Thesis | R Output | Status |
|------|--------|----------|--------|
| Settlement CS HR | 0.617 | **0.609** | DISCREPANCY → UPDATED |
| Settlement FG SHR | 0.411 | **0.410** | ~CONFIRMED |
| Dismissal CS HR | 1.941 | **1.736** | DISCREPANCY → UPDATED |
| Dismissal FG SHR | 2.050 | **1.915** | DISCREPANCY → UPDATED |
| MDL Settle CS HR | 0.262 | **0.261** | ~CONFIRMED |
| MDL Settle FG SHR | 0.963 | **1.126** | DISCREPANCY → UPDATED |
| MDL Dismiss CS HR | 0.274 | **0.225** | DISCREPANCY → UPDATED |
| MDL Dismiss FG SHR | 0.500 | **0.455** | DISCREPANCY → UPDATED |

### Interaction LRT
| Item | Thesis | R Output | Status |
|------|--------|----------|--------|
| Settlement χ²=13.46, p=0.019 | — | — | CONFIRMED |
| Dismissal χ² | 25.05 | **40.14** | DISCREPANCY → UPDATED |
| Dismissal p | 0.0001 | **$<$0.001** | DISCREPANCY → UPDATED |

### Robustness Table — Settlement HRs: ALL CONFIRMED
### Robustness Table — Dismissal HRs: ALL CHANGED
| Spec | Thesis | R Output |
|------|--------|----------|
| Scheme A | 1.638 (1.478, 1.815) | **1.42 (1.30, 1.54)** |
| Scheme B | 1.470 (1.310, 1.650) | **1.28 (1.17, 1.40)** |
| Scheme C | 1.470 (1.310, 1.650) | **1.28 (1.17, 1.40)** |
| Excl post-2020 | 1.570 (1.420, 1.740) | **1.35 (1.24, 1.47)** |
| 2nd Cir | 1.680 (1.300, 2.180) | **1.77 (1.39, 2.26)** |
| 9th Cir | 2.340 (1.940, 2.830) | **1.74 (1.52, 2.01)** |

### Performance Table
| Item | Thesis | R Output | Status |
|------|--------|----------|--------|
| Cox Settlement C-idx | 0.735 | 0.735 | CONFIRMED |
| Cox Dismissal C-idx | 0.602 | **0.593** | DISCREPANCY → UPDATED |
| Cox Settle AUC@1/3/5 | 0.746/0.741/0.836 | **0.746/0.750/0.845** | DISCREPANCY → UPDATED |
| Cox Dismiss AUC@1/3/5 | 0.606/0.639/0.772 | **0.604/0.662/0.774** | DISCREPANCY → UPDATED |
| FG Settle C-idx | 0.735 (=Cox, BUG) | **0.692** | BUG FIXED → UPDATED |
| FG Dismiss C-idx | 0.602 (=Cox, BUG) | **0.566** | BUG FIXED → UPDATED |
| FG AUC@1/3/5 | --- | **0.700/0.688/0.715 and 0.548/0.597/0.746** | NEW → ADDED |
| RSF rows | Present | **DELETED** | RSF REMOVED |

---

## Interpretive Changes (for future prose rewrite)

1. **Baseline dismissal HR**: 1.638 → 1.415 (still significant, p<0.001, but "64% higher" becomes "42% higher")
2. **Piecewise 0-1yr**: 2.18 → 1.86 ("more than double" → "86% higher")
3. **Piecewise 1-2yr**: 0.922 → 1.04 (direction flipped from below-1 to above-1, still non-significant)
4. **Fourth Circuit dismissal**: 0.262 → 0.516 ("26% of Second Circuit" → "52% of Second Circuit")
5. **MDL Fine-Gray settlement SHR**: 0.963 → 1.126 ("essentially null" → slightly above 1)
6. **Several circuits changed significance**: Sixth (0.726→0.974), Eighth (0.913→1.266), Tenth (0.805→1.149) — all moved toward or above 1.0

None of these changes alter the qualitative thesis narrative. The PSLRA still increases dismissal and suppresses settlement. Circuit geography remains dominant. The magnitudes are attenuated because Code 6 cases (judgment on motion = dismissal) were previously hidden in the censored category.
