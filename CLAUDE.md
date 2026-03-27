# Princeton ORFE Senior Thesis — Securities Litigation Survival Analysis

## Project Identity
This is a Princeton University ORFE (Operations Research & Financial Engineering) senior thesis.
The thesis models **time-to-resolution and outcomes of U.S. federal securities class action cases** using competing-risks survival analysis.
The goal is a **department thesis prize-worthy** submission due **April 9, 2026**, with oral defense in late April/early May.

## Core Research Question
How do legal regime changes (PSLRA), court geography (federal circuit), and case characteristics shape both the timing and the type of resolution (settlement vs. dismissal) in securities litigation?

## Data
- **Source**: Federal Judicial Center (FJC) Integrated Database (IDB)
- **Universe**: ~12,968 securities class actions (NOS 850), 1990–2024
- **Key fields**: filing date, termination date, NOS code, disposition codes, cause-of-action (statutory basis), class-action flag, jurisdiction, circuit, origin, MDL status, monetary demand
- **Competing risks** (three disposition coding schemes per FJC IDB Codebook):
  - **Scheme A (Primary)**: Settlement = code 13; Dismissal = codes 2,3,4,6,12,14,15,17,18,19; all else censored
  - **Scheme B (Liberal)**: Reclassifies code 12 (voluntary dismissal) as settlement (hidden settlements)
  - **Scheme C (Expanded)**: Scheme B + code 5 (consent judgment) reclassified as settlement
  - Codes 0,1,10,11 (transfers/remands) and codes 7-9 (trial outcomes without judgment) are censored in all schemes
- Data lives in `data/` directory. Raw IDB extract is `data/raw/`. Cleaned analysis-ready data is `data/cleaned/`.

## Methods (in order of complexity)
1. Kaplan-Meier / Nelson-Aalen estimators (overall survival)
2. Cumulative Incidence Functions (CIF) — Aalen-Johansen estimator for competing risks
3. Cause-specific Cox proportional hazards models (one per outcome)
4. Fine-Gray subdistribution hazard models
5. Propensity Score Weighting (IPTW) — composition-adjusted estimates that isolate the PSLRA component from concurrent changes in case composition. NOT causal — use "composition-adjusted" language.
6. Shared Frailty Models (Mixed Effects) — to account for unobserved heterogeneity and clustering within judicial circuits.
7. Model diagnostics: C-index, time-dependent AUC (`timeROC`), Covariate Balance (IPTW), Frailty Variance, and Schoenfeld residuals for PH testing

## Key Covariates
- `pslra`: binary indicator (filing after Dec 22, 1995)
- `circuit`: federal circuit (1–11, DC, Federal)
- `nos_detailed` / `statutory_basis`: Section 10b, Section 11, Section 16, etc.
- `origin`: original filing vs. transfer vs. remand
- `mdl_status`: MDL consolidation indicator
- `demand_category`: monetary demand buckets
- `case_complexity_proxy`: number of defendants or related cases (when available)

## Tech Stack
- **Analysis**: R (≥4.3). Key packages: `survival`, `cmprsk`, `tidycmprsk`, `timeROC`, `pec`, `ggsurvfit`, `tidyverse`, `coxme`, `WeightIt`, `cobalt`
- **Writing**: LaTeX (Overleaf template). The thesis `.tex` source is in `writing/`. Converted markdown drafts are in `writing/drafts/`.
- **Figures**: All figures output to `output/figures/` as publication-quality PDFs/PNGs.
- **Tables**: All tables output to `output/tables/` as `.tex` files or written directly in `writing/chapters` for direct inclusion.

## Critical Rules
1. **NEVER fabricate results**. If a model doesn't converge, if a result is non-significant, if data is insufficient — say so. A null result is a result. DO NOT force narratives.
2. **NEVER use placeholder numbers** in the thesis text. Every number must trace to actual R output.
3. When writing methodology, "violations" means **proportional hazards assumption violations**, not legal violations. Make this distinction explicit.
4. Every chapter must open with 1-3 sentences stating what the chapter does and why.
5. All mathematical notation must be defined on first use and used consistently.
6. Hazard ratios alone are insufficient — always accompany with model accuracy metrics.
7. Results must be discussed in prose, not just displayed in tables/figures.
8. If unsure about a statistical claim, flag it with `% TODO: VERIFY` in LaTeX.
9. **Scope discipline**: If a task is too large for one session, say so and propose a smaller scope. "This is a 3-session task. Want to start with just [X]?" A working smaller deliverable beats a half-finished ambitious one.
10. **Operationalize every fix**: When you catch a mistake (wrong code, bad notation, fabricated number, logical flaw), don't just fix it — update the relevant rule file in `.claude/rules/` so the same class of mistake can't recur. Every error is a learning opportunity. Encode the lesson.
11. Standard Cox models identify associations between covariates and hazard rates. Causal interpretations are reserved for IPTW-adjusted estimates, contingent on assumptions of no unmeasured confounding, positivity, and correct model specification.
12. ONLY use verified legal definitions and disposition mappings provided in docs/new_lit_sources.txt and docs/fjc_disposition_manual.pdf. Do not invent legal interpretations outside these documents

## File Organization
```
thesis-project/
├── CLAUDE.md                    ← You are here
├── CLAUDE.local.md              ← Personal overrides (gitignored)
├── WORKFLOW_GUIDE.md            ← Master workflow (Plan → Execute → Evaluate)
├── .claude/                     ← Claude Code config
│   ├── rules/                   ← Modular rules (auto-loaded every session)
│   ├── commands/                ← Slash commands (/project:plan, etc.)
│   ├── skills/                  ← Task-specific skills (loaded on demand)
│   ├── agents/                  ← Subagent definitions (spawned by commands)
│   └── settings.json            ← Permissions
├── data/
│   ├── raw/                     ← Untouched IDB extracts
│   └── cleaned/                 ← Analysis-ready datasets
├── code/
│   ├── utils.R                  ← Shared helper functions
│   └── [scripts determined by execution plan]
├── output/
│   ├── figures/                 ← All thesis figures (PDF/PNG)
│   └── tables/                  ← All thesis tables (.tex)
├── writing/
│   ├── main thesis.tex file     ← Imported from Overleaf and contains writeup structure
│   ├── chapters/                ← Individual .tex chapter files
│   ├── drafts/                  ← Markdown working drafts
│   └── refs.bib         ← BibTeX references
└── docs/
    ├── discovery-assessment.md  ← Staged assessment (generated by Claude Code)
    ├── execution-plan.md        ← The approved plan (generated by Claude Code)
    ├── new_lit_sources.txt      ← Verified external literature for Causal Inference
    ├── fjc_disposition_manual.pdf  ← FJC IDB Official Codebook from SY 1988 to present
    ├── session-log.md           ← Session continuity log
    ├── advisor-feedback.md      ← Compiled advisor feedback
    ├── rubric.md                ← Thesis rubric requirements
    └── compact-context.md       ← Context survival document
```

## Running Code
- Run R scripts from the project root: `Rscript code/XX_name.R`
- Scripts should be independently runnable but share `utils.R` for common functions
- All scripts read from `data/cleaned/` and write to `output/`
- Before running any analysis, always read and understand the existing script first

## Writing Conventions
- Use `\citet{}` for "Author (Year)" and `\citep{}` for "(Author, Year)"
- Figures referenced as `Figure~\ref{fig:name}`, tables as `Table~\ref{tab:name}`
- Equations numbered only when referenced later
- American English spelling
- Define all acronyms on first use (PSLRA, IDB, CIF, etc.)
