# Execution Plan — Final Sprint (Condensed)

> Last updated: 2026-04-07.
> Historical buildout detail has been removed. This file now tracks only the remaining submission work.
> For current numbers, use `docs/authoritative-numbers.md` and `docs/session-log.md`.

---

## 1. Current Position

- **Deadline**: 2026-04-09
- **Phases 1-3**: complete
- **Phase 4**: only final thesis synchronization and final review remain

### Already Closed
- modular pipeline (`01_clean.R` through `08_robustness.R`)
- diagnostics repair and refreshed performance outputs
- RSF removal
- IPTW composition-adjusted analysis
- frailty sensitivity analysis
- Fine-Gray clustering and saved-artifact support
- authoritative extractor / reference reconciliation

### Remaining Deliverable
The code is done enough. The remaining job is to make the LaTeX thesis match the verified 2026-04-07 outputs and pass a final adversarial review.

---

## 2. Non-Negotiables

### Source Hierarchy
1. `docs/authoritative-numbers.md`
2. `code/utils/extract_all_numbers.R`
3. `output/models/*.rds` and `output/tables/tab_model_performance.tex`
4. `docs/session-log.md`
5. Everything else only if consistent with the sources above

### Language Discipline
- Cox / Fine-Gray: **associated with**
- IPTW: **composition-adjusted** / **after adjusting for observable case composition**
- Do **not** use strong causal language

### Scope Discipline
- No new model-building unless a real numeric inconsistency appears.
- Do not reopen RSF, old causal-risk memos, or historical contingency analysis.
- Treat constant-HR models as time-averaged summaries because PH is violated.

### Fine-Gray / Verification Guardrails
- `output/models/fine_gray_models.rds` is expected to exist.
- `code/04_fine_gray.R` must save reload-safe `coxph` objects.
- `code/utils/extract_all_numbers.R` must succeed with the saved Fine-Gray artifact present.

---

## 3. Remaining Tasks

### Task 16 [REVIEW]: Propagate Verified Numbers Into LaTeX

**Goal**: make the thesis text match the verified 2026-04-07 code outputs.

**Files to update**
- `writing/chapters/abstract.tex`
- `writing/chapters/introduction.tex`
- `writing/chapters/methodology.tex`
- `writing/chapters/data.tex`
- `writing/chapters/results.tex`
- `writing/chapters/discussion.tex`
- `writing/chapters/conclusion.tex`

**Must-fix themes**
- current Scheme A event shares and sample counts
- current Cox, Fine-Gray, IPTW, frailty, and robustness numbers
- broader judgment-bearing coding and `DISP = 18` censoring
- current PH-violation language
- current robustness ranges
- non-significant extended cluster-robust settlement result

**Acceptance criteria**
- all tables and inline numbers trace to `docs/authoritative-numbers.md`
- no stale values from pre-2026-04-07 reruns remain
- no placeholder or guessed numbers remain

### Checkpoint 3 [REVIEW]: Final Thesis-Level Gate

**After the chapters are updated**
- run `/review` on the LaTeX files
- run `/challenge` on the LaTeX files
- resolve every critical or high-severity issue

**Acceptance criteria**
- no critical number-integrity issues
- no causal-language drift
- no thesis sections promising results the current code does not support

### Final Submission Prep

- make sure `writing/chapters/acknow.tex` has Andrew's personal text
- verify references, figure paths, and chapter cross-references
- clear any `% TODO: VERIFY` markers
- make sure no stale RSF / RDD / old-robustness language remains

---

## 4. Chapter Update Checklist

| File | What to check |
|---|---|
| `abstract.tex` | concise statement of data, methods, verified findings, and implications |
| `introduction.tex` | contributions, headline results, and framing consistent with composition-adjusted language |
| `methodology.tex` | current coding rules, IPTW/frailty framing, PH language, no causal overclaim |
| `data.tex` | sample construction, scheme shares, judgment-bearing dispositions, origin collapse |
| `results.tex` | all tables, inline numbers, robustness ranges, PH results, performance values |
| `discussion.tex` | interpretation consistent with current robustness and limitation structure |
| `conclusion.tex` | summary claims match actual verified results |
| `acknow.tex` | personal text present |

---

## 5. Final Gate Checklist

Before submission:
1. Rerun `Rscript code/utils/extract_all_numbers.R`
2. Spot-check a sample of thesis numbers against the extractor output
3. Confirm `docs/authoritative-numbers.md` still matches the emitted values
4. Run final thesis-level `/review`
5. Run final thesis-level `/challenge`
6. Fix any remaining citation, formatting, or wording problems

---

## 6. Deferred / Do Not Reopen

These are no longer active plan items:
- historical risk matrix
- early 13-day timeline and contingency branches
- task-by-task build history for Phases 1-3
- RSF planning and removal details
- old IPTW feasibility contingencies unless a new concrete failure appears

If a future session needs background on what changed in the codebase, use the condensed recap in `docs/session-log.md` instead of restoring the old long-form plan.

