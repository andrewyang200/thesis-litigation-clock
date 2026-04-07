Run a full adversarial review of: $ARGUMENTS

This is a three-stage quality gate that evaluates code, math, logic, writing, and framing. Determine the scope based on the argument:

- If a `.R` file: focus on code bugs, then check if any thesis chapter reference its output and verify those too
- If a `.R` file and the user explicitly wants refreshed outputs, rerun the relevant script after the review instead of relying only on saved artifacts
- If a `.tex` or `.md` file: focus on math, logic, writing, cross-references, and number tracing
- If a chapter name (e.g., "methodology", "results"): find the relevant .tex file AND the R scripts that produced results for that chapter, review both
- If "full thesis" or "everything": DO NOT review it all at once. Propose a chunked review plan (e.g., "I will run the challenge on Intro + Methods first, then Results + Discussion"). Wait for approval before starting the first chunk.

## Stage 1: Bug Finder
Use the bug-finder agent. Based on the scope:
- For code: run Code Bugs, Statistical Correctness, and Output checklists
- For writing: run Math Bugs, Logic Bugs, Writing Bugs, Cross-Reference Bugs, and Number Tracing checklists
- For full thesis: run ALL checklists across all files
- Trace every number in the text back to R output

## Stage 2: Devil's Advocate
Use the devils-advocate agent on the same scope:
- Challenge every major statistical claim
- Challenge the logical flow and argument coherence
- Challenge the methodology choices
- Check writing quality and self-containment (could a judge, ORFE professor, or generalist follow this?)
- Check narrative framing — is the thesis telling the data's story or the author's preferred story?
- Check for sycophancy patterns

## Stage 3: Referee Synthesis
After both agents report, synthesize into a final verdict:

```
## Challenge Report: [target]

### Bug Finder Results
- Code bugs: [count and severity, or "clean"]
- Math bugs: [count and severity, or "clean"]
- Logic bugs: [count and severity, or "clean"]
- Writing bugs: [count and severity, or "clean"]
- Cross-reference bugs: [count, or "clean"]
- Number tracing: [all verified / X unverifiable / X mismatched]

### Devil's Advocate Results
- Claims challenged: [N tested, X survived, Y weakened, Z broken]
- Logic coherence: [assessment]
- Self-containment: [pass / fail with specifics]
- Narrative integrity: [data-driven / author-driven]
- Sycophancy detected: [YES with details / NO]

### Combined Verdict
Choose ONE:
- **SUBMIT-READY**: No critical issues across any dimension. Claims are defensible. Writing is accessible. Numbers verified.
- **NEEDS WORK**: [list specific items by category that must be fixed, prioritized]
- **UNRELIABLE**: [major integrity issues — stop all forward progress and fix these first]

### Top 5 Required Actions (prioritized across all dimensions)
1. [most critical fix — category, location, what to do]
2. [next]
3. [next]
4. [next]
5. [next]

### Examiner Prep
- Strongest attack a committee member could make: [the attack]
- What would confuse a judge reading this: [specific passages]
- What would an ORFE professor challenge: [specific methodological points]
```

Be ruthlessly honest. A SUBMIT-READY verdict on weak work will result in a failed defense.
A NEEDS-WORK verdict on strong work wastes time. Get the call right.
