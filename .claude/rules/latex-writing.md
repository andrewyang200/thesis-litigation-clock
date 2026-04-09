# LaTeX & Academic Writing Standards

## Chapter Structure
Every chapter MUST open with 1-3 sentences stating:
1. What this chapter does
2. Why it matters for the thesis argument

## Notation Discipline
- Define every symbol on first use: "Let $T$ denote the time from filing to termination"
- Use $\lambda_k(t)$ for cause-specific hazard of event type $k$
- Use $F_k(t)$ for cumulative incidence of event type $k$  
- Use $\hat{\beta}$ for estimated coefficients, $\text{HR} = \exp(\hat{\beta})$ for hazard ratios
- "Violation" in this thesis means PH assumption violation, not legal violation — clarify early and often

## Discussing Results
- Never present a table or figure without discussing it in the text
- Lead with the substantive finding, then the statistical evidence: "PSLRA substantially increased dismissal hazard ($\text{HR} = 1.62$, $p < 0.001$)"
- Always contextualize hazard ratios: "a hazard ratio of 1.62 indicates a 62\% increase in the instantaneous rate of dismissal"
- Report confidence intervals alongside point estimates
- For causal and frailty models: explicitly discuss covariate balance (for IPTW) and the variance of the random effect (for Frailty) alongside the hazard ratios. Use C-index/AUC only for the baseline Cox models.

## LaTeX Conventions
- Use `\input{Chapters/filename}` to include chapter files
- Cross-references: `Figure~\ref{fig:xxx}`, `Table~\ref{tab:xxx}`, `Equation~\eqref{eq:xxx}`
- `\citet{key}` for textual citations, `\citep{key}` for parenthetical
- Wrap all math in `\( \)` for inline, `\[ \]` or `equation` env for display
- Use `booktabs` for tables (no vertical rules)
- Keep paragraphs focused — one idea per paragraph
- Avoid unsupported novelty claims such as "first," "novel," or "unique" unless the literature review has already established the comparison set; otherwise describe the contribution directly.
- If a priority claim is warranted but not fully exhaustive, hedge it precisely with "to our knowledge" and specify the exact estimand, model class, or empirical object that is new.

## Quality Markers
- Flag uncertain claims: `% TODO: VERIFY — [what needs checking]`
- Flag advisor feedback items: `% ADDRESSED: [feedback item]`
- Flag areas needing Andrew's judgment: `% REVIEW: [interpretive choice]`
