Review the file specified: $ARGUMENTS

If it's an R script (`.R`):
- Use the r-code-reviewer agent to check statistical correctness, code quality, and output quality.
- Verify it respects the "No Raw Data in Context" rule.
- If it is a lightweight script (e.g., data cleaning, simple plots), run it to verify.
- If it contains heavy model fitting (Cox, Frailty, IPTW weighting, Bootstrap), default to static review plus existing outputs unless the user explicitly asks for a rerun or refreshed artifacts.

If it's a LaTeX file (`.tex` or `.md` draft):
- Use the writing-reviewer agent to check structure, clarity, rigor, and advisor feedback compliance
- Cross-reference any reported numbers against the R output in `output/`
- Check notation consistency against the methodology chapter

If it's a figure or table:
- Check labels, legends, titles, captions
- Verify the data shown matches the analysis that produced it

Report findings with CRITICAL / WARNING / SUGGESTION categories.
