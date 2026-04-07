---
name: latex-writing
description: Academic LaTeX writing for Princeton ORFE thesis. Use when writing, editing, or reviewing any thesis chapters (Introduction, Literature Review, Methodology, Results, Discussion, Conclusion). Also use when converting R output into thesis-ready prose or creating LaTeX tables/figures.
---

# LaTeX Thesis Writing Skill

## Voice & Style
- Write in third person or first-person plural ("we estimate", "this analysis examines")
- Precise, not verbose. Every sentence should advance the argument.
- No filler phrases: "it is worth noting that", "it is important to mention", "interestingly"

## Audience & Self-Containment (Advisor Directive)
The thesis must be **self-contained**. It will be read by:
- **ORFE professors** — fluent in statistics but may not know securities law or competing-risks survival analysis specifically
- **Legal scholars / judges** — fluent in securities litigation but may not know what a hazard function is
- **Generalist academics** — smart people with neither specialty

This means:
1. **Never assume the reader knows your method.** The first time you mention "cumulative incidence function," explain what it measures and why it matters — in one clear sentence. The reader should be able to follow the argument without googling. If they WANT more depth (e.g., the mathematical derivation of the Fine-Gray model), they can look it up, but they should never be LOST.
2. **Never assume the reader knows securities law.** Explain what a class action is, what the PSLRA did, what "settlement" vs. "dismissal" means in this context, what circuit courts are. One sentence each is enough — just don't skip it.
3. **Build up logically.** The thesis should read like a guided tour:
   - Introduction: here's the problem, here's why it matters, here's what we did
   - Literature: here's what others have done, here's the gap
   - Methodology: here are the tools, explained from simple to complex (KM → CIF → Cox → Fine-Gray → Frailty/IPTW), each building on the previous
   - Results: here's what we found, organized the same way as methodology
   - Discussion: here's what it means
4. **The "cocktail party" test:** Could a smart non-specialist read any paragraph and understand the main point, even if they skip the math? If not, add a plain-language sentence before the technical detail.
5. **Cross-reference forward and backward.** When introducing a method in chapter 3, say why it matters for the results in chapter 4. When presenting a result in chapter 4, remind the reader which method from chapter 3 produced it.
6. **Use concrete examples.** Instead of just "higher hazard ratio," say "a 62% increase in the rate of dismissal, meaning cases filed after PSLRA were resolved through dismissal substantially faster."

## chapter Templates

### Introduction (~3-4 pages)
1. Opening hook: importance of securities litigation, scale of the market — written so a judge AND a statistician both care
2. Brief context paragraph: what class actions are, what happens to them (settlement or dismissal), why timing matters
3. Research question: clearly stated in plain language first, then precise formulation
4. Why survival analysis: the time-to-event framing explained in one accessible paragraph ("we borrow tools from medical research where doctors track time to recovery or relapse...")
5. Preview of methods and key findings — accessible summary
6. Contribution statement: what's new vs. existing literature
7. Roadmap paragraph: explicit guide to what each chapter covers

### Literature Review (~4-5 pages)
1. Securities litigation landscape — accessible to a statistician who doesn't know law (legal scholars: Cox, Thomas, Pritchard)
2. PSLRA and its effects — explain the law first, then review empirical studies
3. Survival analysis in legal/financial contexts — bridge the two worlds
4. Competing risks methodology — explain why standard survival analysis isn't enough, accessible to a lawyer
5. Gap identification → thesis contribution

### Methodology (~5-7 pages)
1. **Goal statement** (first paragraph): "This chapter develops the statistical framework for modeling time-to-resolution..."
2. **Intuition paragraph** before any math: explain the logical progression of methods in plain language. "We begin with the simplest approach (KM) to establish baseline patterns, then introduce competing risks (CIF) because cases can end in different ways, then build regression models (Cox, Fine-Gray) to isolate the effect of specific factors, and finally use Frailty models and IPTW as sensitivity and composition-adjustment tools, accounting for unobserved geography and shifting case characteristics without overclaiming causal identification."
3. Data description: source, sample construction, variable definitions
4. Notation block: define T, C, δ, λ, F all in one place — with a plain-English gloss for each symbol
5. KM and CIF estimation — start with what it tells us, then the math
6. Cause-specific Cox model specification — explain "cause-specific" in accessible terms first
7. Fine-Gray subdistribution model specification — explain how it differs from Cox in plain language before the formula
8. Shared Frailty specification: Frame this as "controlling for unobserved jurisdictional culture and baseline judicial hostility to securities claims.
9. IPTW specification: Frame this as "composition-adjusting the pre- and post-PSLRA comparison by balancing observed case characteristics," not as achieving causal identification.
10. Model evaluation metrics (C-index, AUC, IBS) — each explained with an analogy or example
11. PH assumption testing and remedies

### Results (~6-8 pages)
1. Descriptive Survival Patterns (KM/CIF baseline plots).
2. Claim 1: The PSLRA Association After Composition Adjustment (Present the Baseline Cox, then compare it to the IPTW hazard ratio and the Piecewise timing model without calling IPTW causal).
3. Claim 2: Circuit Geography Dictates Outcomes (Present the Circuit Cox models, then validate with the Shared Frailty model to prove it's not just a composition effect).
4. Claim 3: MDL Consolidation Freezes Resolution (Present the Extended Cox vs. Fine-Gray divergence).
5. Robustness Checks (Alternative coding schemes).


### Discussion & Conclusion (~3-4 pages)
1. Summary of key findings
2. Connection back to research question
3. Policy implications (PSLRA effectiveness, circuit shopping)
4. Limitations (data, methodology, scope)
5. Future work directions
6. Concluding paragraph

## Table Formatting
Use `booktabs` style. Example:
```latex
\begin{table}[htbp]
\centering
\caption{Cause-Specific Cox Model: Settlement Hazard}
\label{tab:cox_settlement}
\begin{tabular}{lccc}
\toprule
Covariate & HR & 95\% CI & $p$-value \\
\midrule
PSLRA (post-1995) & [ACTUAL_HR] & ([LOWER_CI], [UPPER_CI]) & [ACTUAL_P] \\
% ... more rows
\bottomrule
\end{tabular}
\end{table}
```

## Figure Integration
```latex
\begin{figure}[htbp]
\centering
\includegraphics[width=\textwidth]{output/figures/fig_cif_overall.pdf}
\caption{Cumulative incidence of settlement and dismissal...}
\label{fig:cif_overall}
\end{figure}
```


