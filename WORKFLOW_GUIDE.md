# Complete Claude Code Thesis Workflow Guide
## From Setup to Submission — April 9, 2026

---

## THE CORE IDEA

This workflow follows a **Plan → Execute → Evaluate** loop. You do NOT prescribe specific tasks to Claude Code upfront. Instead:

1. **PLAN**: Claude Code reads everything you have, assesses the real state, and produces a detailed plan
2. **EXECUTE**: You feed the plan back in phases, Claude Code does the work
3. **EVALUATE**: After each unit of work, you run cooperative + adversarial review

The rules, skills, and agents in `.claude/` encode what "good" looks like. The plan encodes what to actually do. These are separate concerns — quality standards are fixed, but the plan emerges from your actual files.

---

## PART 1: INITIAL SETUP (Do This Once)

### Step 1: Install Claude Code
```bash
npm install -g @anthropic-ai/claude-code
```

### Step 2: Set Up the Project Directory
Unzip the project template to your desired location:
```bash
cd ~/Documents
unzip thesis-project-final.zip -d thesis
cd thesis
```

### Step 3: Initialize Git
```bash
git init
git add .
git commit -m "Initial project setup with Claude Code config"
```

### Step 4: Populate Your Existing Work
Copy everything you have into the right places:

```bash
# Your R code (one script or multiple — doesn't matter, put it all in code/)
cp /path/to/your/*.R code/

# Your LaTeX thesis (export from Overleaf as zip, unzip, copy)
cp /path/to/overleaf-export/*.tex writing/
cp /path/to/overleaf-export/*.bib writing/
cp /path/to/overleaf-export/*.sty writing/
cp /path/to/overleaf-export/*.cls writing/

# Your data
cp /path/to/your/idb_data.* data/raw/

# Any existing figures and tables
cp /path/to/your/figures/* output/figures/
cp /path/to/your/tables/* output/tables/
```

**⚠️ IMPORTANT — Data File Sizes:**
If your raw data file is large (>10MB), Claude Code should NEVER read it directly into context.
This will crash the session or burn your entire usage quota on a single file read.
Instead, Claude Code should always inspect data via R commands that produce summaries:
```r
# RIGHT: Create code/utils/inspect.R with str() and head(), then run:
Rscript code/utils/inspect.R

# WRONG: Read the whole file into context or use complex inline Rscript -e "..."
cat data/raw/file.csv    # ← NEVER DO THIS with large files

This is already enforced in the Discovery Prompt (which uses R to summarize data files)
and in `.claude/rules/r-coding.md`, but keep it in mind if you ever ask Claude Code
to "look at the data" directly.

### Step 5: Fill In Context Documents
Open these in any text editor and paste the real content:
- `docs/advisor-feedback.md` → your actual advisor feedback (replace the template)
- `docs/rubric.md` → the actual ORF 499 rubric

### Step 6: Verify R Environment
```bash
Rscript -e "
pkgs <- c('survival','cmprsk','tidycmprsk','randomForestSRC',
          'timeROC','pec','ggsurvfit','tidyverse','kableExtra',
          'xtable','here','scales','patchwork')
missing <- pkgs[!sapply(pkgs, requireNamespace, quietly=TRUE)]
if(length(missing)) cat('INSTALL:', paste(missing, collapse=', '), '\n')
else cat('All packages ready.\n')
"
```

### Step 7: Commit Everything
```bash
git add .
git commit -m "Added all existing thesis files"
```

### Step 8: Launch Claude Code
```bash
cd ~/Documents/thesis
claude
```

---

## PART 2: THE PLAN → EXECUTE → EVALUATE LOOP

### PHASE 1: DISCOVERY & PLANNING

This is the most important phase. Claude Code reads everything you have and builds the plan. You do NOT tell it what the plan should be — you tell it what to read and what questions to answer.

**IMPORTANT: Staged Discovery.** Do NOT ask Claude Code to read everything at once. Large context windows degrade from "lost in the middle" syndrome — if you feed it 50 pages of LaTeX and 10 R scripts simultaneously, it will skim and miss nuanced issues. Instead, run three discovery prompts in sequence, each building on the last.

**Prompt 1A — Data & Code Discovery (run this first):**
```
I need you to do a thorough assessment of my senior thesis project before we do ANY work.
We'll do this in stages to keep the assessment sharp. Stage 1 is Data and Code.

Read the following:
1. CLAUDE.md (you should already have this)
2. docs/advisor-feedback.md
3. docs/rubric.md
4. Every file in code/ — read each R script completely

For data files in data/: do NOT try to read raw data files directly into context.
Instead, create and run a dedicated inspection script:
1. Create a file `code/inspect_data.R` that safely summarizes all files in `data/`
   without loading full datasets into memory. Use `str()`, `head()`, `nrows=5`,
   `file.size()`, `dim()` etc. to produce a text summary.
2. Run it: `Rscript code/inspect_data.R`
3. Read the console output — that's your data summary.
Do NOT pass inline R code through `Rscript -e "..."` with complex quoting —
it's fragile and will break on nested quotes or regex. Always use script files.

Also check what exists in output/figures/ and output/tables/ (just list the filenames, don't read image files).

Produce an assessment of ONLY data and code:

## A. Data Assessment
- What data files exist? What format? How many observations?
- What variables are available? What's the structure?
- Is there already a cleaned/analysis-ready dataset, or only raw data?
- Any obvious data quality issues visible from the summary?

## B. Code Assessment  
- For EACH R script: does it run? Is it complete? What does it produce?
- What analysis steps are already implemented and working?
- What analysis steps are partially implemented or broken?
- What analysis steps are completely missing?
- Are there any bugs, errors, or suspect logic you can identify?

## C. Output Assessment
- What figures and tables already exist in output/?
- Which R scripts produce which output files?
- Are any outputs stale (older than the code that produces them)?

Be BRUTALLY honest. If something is broken, say so. If something is fabricated, flag it.
If something is good, say that too. Do NOT propose solutions yet — just diagnose.
```

**Review the Stage 1 assessment.** Does it match your understanding? Correct anything wrong. Then:

**Prompt 1B — Writing & Thesis Discovery (run this second):**
```
Good. Now Stage 2: assess the writing. Keep the Data & Code assessment in mind — 
we need to check whether the writing accurately reflects what the code actually produces.

Read:
1. Every file in writing/ — read each .tex and .bib file completely
2. Every file in writing/chapter/ and writing/drafts/

Produce an assessment of ONLY the writing:

## D. Writing Assessment
- For EACH chapter that exists: how complete is it? What quality?
- What chapter are missing entirely?
- Does the existing writing have the opening goal statements the advisor requested?
- Is the "violations" terminology disambiguated (statistical PH vs. legal)?
- Is notation consistent? Are there obvious notation problems?
- How self-contained is the current draft? Could a judge follow the methodology?
  Could an ORFE professor follow the legal context?

## E. Writing vs. Code Alignment
- Do the numbers in the thesis text match what the R code actually produces?
  (Cross-reference against the code assessment from Stage 1)
- Are there results described in the text that don't correspond to any R script?
- Are there R outputs that exist but aren't discussed in the thesis?
- Flag any numbers that look like they might be placeholders or fabricated.

## F. Cross-References
- Any broken \ref, \cite, or \eqref?
- Figures/tables referenced but missing? Existing but unreferenced?

Be specific. Quote the exact passage if something looks wrong.
```

**Review Stage 2. Then:**

**Prompt 1C — Gap Analysis & Planning Foundation (run this third):**
```
Good. Now Stage 3: synthesize everything from Stages 1 and 2 into an overall assessment 
and prepare for planning.

Read docs/advisor-feedback.md and docs/rubric.md again with fresh eyes, now that you've 
seen the actual state of the code and writing.

## G. Advisor Feedback Compliance
- For EACH item in docs/advisor-feedback.md: is it addressed, partially addressed, or not addressed?
  Be specific — cite the exact chapter/file where it's addressed or note where it's missing.

## H. Rubric Compliance
- For each rubric criterion: what's the current state?

## I. Gap Analysis
- What is DONE and GOOD (preserve — DO NOT TOUCH)?
- What is DONE but NEEDS FIXING (specific problems)?
- What is PARTIALLY DONE (what remains)?
- What is COMPLETELY MISSING (must create from scratch)?

## J. Risk Assessment
- What are the top risks to completing by April 9?
- What depends on what? (dependency chain — be explicit)
- What can be done in parallel?
- Where are the "if this doesn't work, we need a fallback" points?

## K. Honest Bottom Line
- If I had to submit the thesis AS-IS tomorrow, what grade would it get and why?
- What are the 3 highest-impact improvements to make?
- What should I NOT waste time on?

Save this complete three-stage assessment to docs/discovery-assessment.md.
```

**Now you have a thorough, staged assessment.** Review it carefully. Then move to planning:

**Prompt — The Planning Prompt:**
```
Read docs/discovery-assessment.md.

You are now the Lead Architect. Taking what you now know, create a PROJECT-WIDE REFACTORING & EXECUTION PLAN to take this thesis from its current "Interim" state to a "Final" causal inference submission.

The Core Mandate: Cascading Consistency Every change in methodology MUST cascade through all files. If RSF is deleted from the code, its "contribution" must be deleted from the Intro, its "derivation" from Methodology, its "plots" from Results, and its "limitations" from the Discussion. Likewise, if a new methodological is used, be sure to mention it in relevant chapters (i.e. literature review, methodology, etc)

Requirements for the Plan:
- Modularize the Monolith: Break InterimScript.R into a numbered pipeline (e.g., 01_clean.R, 02_descriptives.R, 03_cox_models.R, 04_causal_iptw.R).
- Surgical Repairs First: Fix the Section 19 crash, the Fine-Gray C-index logic, and data paths before any new writing occurs.
- The Results Restructure: Plan a complete rewrite of Section 5 to be organized by Substantive Claims (e.g., "The Impact of PSLRA," "Geographic Disparity") rather than model types.
- Break the work into discrete, independently completable tasks
- Session-Based Tasks: Each task must be a 1-2 hour unit of work. For each, specify:
  - WHAT: exactly what needs to be done
  - WHY: why this task matters (connects to rubric, advisor feedback, or thesis quality)
  - INPUTS: what files need to be read
  - OUTPUTS: what files will be created or modified
  - ACCEPTANCE CRITERIA: how do we know this task is done correctly
  - RISKS: what could go wrong and what's the fallback
- Mark each task as one of:
  - FIX: repairing something that exists but is broken
  - EXTEND: building on something that partially exists
  - CREATE: building from scratch
  - REVIEW: evaluating existing work without changing it
- Include THREE mandatory adversarial checkpoints:
  - After all code/analysis is done → /project:challenge on all code
  - After all writing is done → /project:challenge on full thesis
  - Before submission → final /project:challenge as last gate
- Pruning Protocol: Explicitly list the deletion of the RSF blocks and the "Future Work" memo as standalone tasks to clear context.
- Include explicit "DO NOT TOUCH" items — things that are already good and should be preserved

CRITICAL CONSTRAINTS:
- Never plan to fabricate results. If a model won't work, the plan should say "attempt X; 
  if it fails, document the failure as a finding."
- Every number in the thesis must trace to actual R output. The plan must include verification steps.
- The thesis must be self-contained per the advisor's directive. The plan must include accessibility review.
- **Pruning Mandate:** You have explicit permission to aggressively DELETE and remove any deprecated legacy work from the interim report (e.g., Random Survival Forests, machine learning prediction framing) that conflicts with our pivot to Causal Inference. Do not try to salvage deprecated methodology.

Task Categories:
- FOUNDATION: Bug fixes, modularization, path updates, figure format shift (PNG → PDF).
- CAUSAL BUILD: IPTW pipeline and Shared Frailty implementation + diagnostics.
- CHAPTER RECONSTRUCTION: Rewriting Intro, Methodology, Results, and Discussion to reflect the pivot.
- POLISH: Abstract, Acknowledgements, hyperref, and final verification.

Present the plan as a numbered task list I can approve, modify, or reorder.
Wait for my approval before executing anything. Save the final plan to docs/execution-plan.md.
```

**BEFORE you approve the plan, manually verify the dependency chain:**
LLMs sometimes produce plans that look logically ordered but have subtle dependency violations.
Check the critical path yourself:
- Data cleaning must be fully verified BEFORE any model fitting begins
- Model fitting must be fully verified BEFORE any LaTeX table generation
- All R output must exist BEFORE any results chapter is written
- All results must be verified BEFORE the Discussion chapter is written

If the plan has tasks out of order, reorder them before approving.

**Once you approve:**
```
I approve this plan with the following modifications: [any changes you made].
Save the final plan to docs/execution-plan.md.
Let's start with Task 1. Read the relevant input files, then execute.
Show me the actual output when done.
```

---

### PHASE 2: EXECUTION

You feed tasks from the approved plan one at a time. The rhythm:

```
Execute Task [N] from the plan: [paste or reference the task description].
Read the input files first, then do the work. 
Show me the actual output — don't summarize, show me.
```

**After each task completes:**

```
/project:review [the file(s) that were just created or modified]
```

This runs cooperative review (code quality, writing quality, basic correctness checks).

**After review passes — COMMIT (do not skip):**

Open your **SECOND terminal tab** (do NOT run this inside your active Claude Code session — git output wastes context tokens and writing the commit message wastes your time):

```bash
# In a separate terminal tab, stage your exact files:
git add code/the_script_you_just_edited.R

# Then run your custom headless commit alias:
aicommit
```

This spawns a headless Claude instance that reads the diffs, writes an intelligent commit message, commits, and exits. Your main session's context stays clean. If you prefer manual commits, that works too — just do it outside the Claude Code session:

```bash
# Manual alternative (still in the second terminal):
git add -A && git commit -m "Task N: [description]"
```

Git is your undo button. If a future task breaks something that was working, you can roll back. Treat each commit as a save point.

**After a group of related tasks completes** (e.g., all analysis code, or all writing):

```
/project:challenge [scope]
```

This runs the adversarial pipeline (bug-finder + devil's advocate + referee synthesis).

**After each session:**

```
/project:wrapup
```

This logs what was done, decisions made, and what's next.

**Before the next session:**

```
/project:plan
```

This reads the session log and orients to the current state.

**The execution loop looks like this:**

```
┌─────────────────────────────┐
│  /project:plan              │  ← start of session
│  (reads session log + plan, │
│   proposes what to do)      │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│  Execute Task N             │  ← do the work
│  (one deliverable at a time)│
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│  /project:review [file]     │  ← cooperative check
│  (quality, correctness)     │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│  git commit (2nd terminal)  │  ← SAVE POINT (do not skip)
│  Use headless claude -p or  │     Do NOT run in main session
│  manual git in separate tab │
└──────────┬──────────────────┘
           │
           ▼
    ┌──────┴──────┐
    │ End of      │ YES ──► /project:challenge [scope]
    │ phase?      │         (adversarial stress-test)
    └──────┬──────┘         then git tag phase-N-complete
           │ NO
           ▼
    ┌──────┴──────┐
    │ More tasks  │ YES ──► back to Execute Task N+1
    │ this session│
    └──────┬──────┘
           │ NO
           ▼
┌─────────────────────────────┐
│  /project:wrapup            │  ← end of session
│  (log everything)           │
└─────────────────────────────┘
```

**Git recovery if something breaks:**
```bash
# See what changed
git log --oneline -10

# Roll back to the last good commit
git checkout [commit-hash] -- [file-that-broke]

# Or reset entirely to a known good state
git reset --hard [commit-hash]
```

---

### PHASE 3: EVALUATION

Evaluation happens at three levels:

**Level 1: Routine (after every task)**
```
/project:review [filename]
```
Runs cooperative review — catches basic quality issues, formatting problems, missing labels.

**Level 2: Adversarial (at checkpoints and when suspicious)**
```
/project:challenge [scope]
```
Runs bug-finder + devil's advocate across all dimensions (code, math, logic, writing, cross-references, numbers, sycophancy). Use at the three mandatory checkpoints and anytime results feel too clean.

The scope can be:
- A specific file: `/project:challenge code/03_cox_models.R`
- A chapter: `/project:challenge writing/chapter/results.tex`
- All code: `/project:challenge code/`
- The full thesis: `/project:challenge full thesis`

**Level 3: Number Audit (before any numbers go into prose)**
```
/project:verify-numbers [tex file]
```
Traces every quantitative claim in the text back to R output. Use this BEFORE finalizing any results chapter.

**The three mandatory adversarial checkpoints:**

| When | What | Why |
|------|------|-----|
| After all analysis code is done | `/project:challenge code/` | Don't carry bad numbers into writing |
| After all writing is done | `/project:challenge full thesis` | Full integrity check before polish |
| Before submission | Final `/project:challenge full thesis` | Last gate — the definitive verdict |

---

## PART 3: CONTEXT MANAGEMENT

### Session Start
```
/project:plan
```

### During a Session
- ONE deliverable at a time
- `/project:review [file]` after every completed task (cooperative)
- Git commit in SECOND terminal after every passing review (headless `claude -p` or manual — never inside main session)
- `/project:challenge [scope]` at checkpoints (adversarial)
- If context feels heavy → `/compact` (mid-task) or `/clear` (switching task types)
- If approaching limits → `/project:compact-prep` then `/compact`

### Session End
```
/project:wrapup
```

### /compact vs /clear — Know the Difference

These are your two most important context management tools. Using the wrong one wastes tokens or loses state.

**`/compact` — Use mid-task when you need to keep going but context is filling up.**
- Summarizes the conversation history and carries the summary forward
- Claude retains a compressed version of what happened — it doesn't forget
- Use when: you're debugging a Cox model script and hit token limits but need to keep working on that same script
- After compacting: Claude still knows roughly what you've been doing

**`/clear` — Use between distinct tasks when you want a completely fresh slate.**
- Wipes conversation history to zero tokens. Clean reset.
- Claude retains NOTHING from the previous conversation (CLAUDE.md and rules still load fresh)
- Use when: you finished writing R code and now need to write the LaTeX literature review. You do NOT want 8,000 tokens of Cox model debugging history polluting your writing context.
- After clearing: re-read the execution plan and the specific files for your next task

**Decision rule:**
| Situation | Use |
|-----------|-----|
| Mid-task, hitting token limits | `/compact` |
| Switching from code to writing (or vice versa) | `/clear` |
| Switching between unrelated tasks | `/clear` |
| Continuing the same task after a break | `claude --continue` |
| Starting a brand new session | `/clear` + read plan |

**Before using either**, run `/project:compact-prep` if you've done meaningful work — this saves state to `docs/compact-context.md` regardless of which command you use next.

**After `/clear`, always start with:**
```
Read CLAUDE.md and docs/execution-plan.md. 
We completed through Task [N]. Start Task [N+1].
Read [specific files needed for the next task].
```

### If You Hit Usage Limits
1. Run `/project:compact-prep` first (saves state)
2. Wait if it's a TPM (tokens per minute) limit — usually clears within 60 seconds
3. If it's a daily quota limit, your work is safe in files. Resume tomorrow.
4. To resume: `claude --continue` (picks up last session) or start fresh with `/clear` + plan

### Preserving the Plan Across Sessions
The plan Claude Code generates in Phase 1 is your most valuable artifact. **Save it:**
```
Save the approved plan to docs/execution-plan.md
```
Then every new session can reference it:
```
Read docs/execution-plan.md. We completed through Task [N]. Pick up at Task [N+1].
```

---

## PART 4: ANTI-SYCOPHANCY PROTOCOLS

### During Planning
If Claude Code's plan seems to perfectly match what you expected — every analysis confirms your hypothesis, every chapter is straightforward — push back:
```
This plan seems too optimistic. What could go WRONG? Where are the risks 
that a model won't converge, data will be insufficient, or results will 
contradict my hypotheses? Build those contingencies into the plan.
```

### During Execution
If Claude Code produces results that perfectly confirm your priors:
```
These results perfectly match my hypothesis. That makes me suspicious.
Use the devils-advocate agent. Try to break the finding that [X]. 
If you can't break it, say so honestly. If you can, I need to know.
```

### If You Think Something Is Wrong But Claude Disagrees
```
I think there's a problem with [X]. But I might be wrong.
Use the bug-finder agent. Check [X] independently — if it's actually 
correct, tell me it's correct and explain why. Don't fabricate a bug 
just because I suggested one exists.
```

### If Claude Always Agrees With You
```
You've agreed with every suggestion I've made in this session. 
That's a red flag for sycophancy. Push back on something. 
What's the weakest decision we've made so far? 
What would you do differently if I weren't here?
```

---

## PART 5: WHAT GOES WHERE — QUICK REFERENCE

| File | Purpose | When to Edit |
|------|---------|-------------|
| `CLAUDE.md` | Project context, file map, critical rules | When project structure changes |
| `CLAUDE.local.md` | Personal preferences | Once, then forget |
| `.claude/rules/*.md` | Quality standards | When Claude keeps making a specific mistake |
| `.claude/commands/*.md` | Slash commands | When you want a new workflow shortcut |
| `.claude/skills/*/SKILL.md` | Domain expertise | When Claude lacks specific knowledge |
| `.claude/agents/*.md` | Subagent personas | When you need specialized review |
| `.claude/settings.json` | Permissions | Once, then forget |
| `docs/discovery-assessment.md` | Staged assessment of existing work | Generated in Phase 1, referenced by plan |
| `docs/execution-plan.md` | The approved plan | Created in Phase 1, updated each session |
| `docs/session-log.md` | Session continuity | Every session (via /project:wrapup) |
| `docs/advisor-feedback.md` | Feedback tracking | When feedback is received |
| `docs/rubric.md` | Thesis requirements | Once |
| `docs/compact-context.md` | Context survival | Before compaction (via /project:compact-prep) |

---

## PART 6: TROUBLESHOOTING

**Claude Code produces a plan that misses something obvious:**
→ You know your thesis better than it does after one read. Add the missing items. The plan is a collaboration, not a dictation.

**Claude Code's plan has dependency issues (task order doesn't make sense):**
→ LLMs sometimes struggle with topological sorting. Manually verify the critical path before approving: data cleaning → model fitting → table generation → results writing → discussion. If tasks are out of order, reorder them.

**Claude Code's plan is too ambitious for the timeline:**
→ Ask: "Given the April 9 deadline, what is the MINIMUM viable thesis vs. the aspirational thesis? Separate must-haves from nice-to-haves."

**Claude tries to read raw data files directly (cat data/raw/big_file.csv):**
→ Stop it immediately. "Do NOT read raw data into context. Use R to produce a summary: `Rscript -e \"str(read.csv('data/raw/file.csv', nrows=5))\"`"

**Claude keeps making up numbers:**
→ Run `/project:verify-numbers` on every chapter before finalizing. This is non-negotiable.

**Claude rewrites things that were already good:**
→ This is why the plan has "DO NOT TOUCH" items. If it happens anyway: "Stop. That chapter was marked as good in the assessment. Revert your changes and only modify [specific thing]."

**A task breaks something that was previously working:**
→ This is why you commit after every task. Run `git diff` to see what changed, then `git checkout [last-good-commit] -- [broken-file]` to restore the working version. Fix the task that caused the regression before continuing.

**Claude agrees with everything you say:**
→ Use the anti-sycophancy prompts from Part 4. Run `/project:challenge` to get an independent assessment.

**All results perfectly confirm your hypothesis:**
→ Real data is messy. Run the devil's advocate. Ask: "What's the strongest argument AGAINST my main finding?"

**A model doesn't converge or produces nonsense:**
→ This is a FINDING, not a failure. Document it. Ask Claude to try a simpler specification. If that fails too, report it honestly: "Model X did not converge with the full covariate set, suggesting [possible reason]."

**The thesis doesn't feel self-contained:**
→ Pick three random pages. For each: could a judge follow this paragraph? Could an ORFE professor? If not, ask Claude to add a context sentence. Use: "A judge is reading this paragraph for the first time. What would confuse them? Fix it."

**You run out of usage quota:**
→ Run `/project:compact-prep` first. Your work is in files, not in context. Start fresh tomorrow with the resume protocol.

**Context is too large and Claude gets confused:**
→ `/project:compact-prep` then `/compact`. Start the next task with a focused scope: "Read ONLY [the 2-3 files relevant to the next task]. Don't read the whole project."

---

## PART 7: PRINCIPLES

1. **Plan from evidence, not assumptions.** Let Claude Code read your files before deciding what to do.
2. **One deliverable per session.** Don't try to rewrite everything at once. If a task is too big, break it down.
3. **Review then challenge.** Cooperative checks after every task. Adversarial checks at milestones.
4. **The session log is sacred.** It's the continuity backbone. Always `/project:wrapup`.
5. **The plan is a living document.** Update it as you learn more. Plans change — that's fine.
6. **Verify everything.** Run the code. Check the numbers. Never accept output on faith.
7. **Null results are results.** If PSLRA doesn't affect something, report that honestly.
8. **The goal is defensible, not perfect.** Honest limitations beat hidden fabrications every time.
9. **You are the thesis author.** Claude Code writes code and prose. You make decisions, interpretations, and arguments. The defense is yours.
10. **Operationalize every fix.** When you catch a mistake, don't just fix it — update the rule that should have prevented it. The system gets better with every error. This is the flywheel.
11. **Scope discipline.** If Claude says a task will take 3 sessions, trust it and start with the smallest viable piece. A working small thing beats a half-finished grand vision.

---

## PART 8: SESSION & TOKEN MANAGEMENT

### How Claude Code Sessions Work
- **Closing the terminal does NOT lose your session.** Claude Code persists session history to `~/.claude/projects/`. Your conversation is saved automatically.
- **`claude --continue`** resumes your most recent session exactly where you left off. Use this when you close the terminal, take a break, or your connection drops.
- **`claude --resume`** opens a picker showing all past sessions. Use this to go back to a specific session from days ago.
- **Starting `claude` with no flags** begins a fresh session. CLAUDE.md and rules load automatically, but there's no conversation history.

### Token Limits
- **Tokens Per Minute (TPM):** Claude Code has a rate limit on tokens per minute. If you hit it, you'll see a pause or error. Wait ~60 seconds and it clears automatically. Don't panic — your session isn't lost.
- **Daily/monthly usage quota:** Depends on your subscription tier (Pro vs Max). When you hit it, you can't send more messages until it resets. Your files and work are safe — they live on disk, not in context.
- **Context window:** Claude Code's context window fills up as the conversation progresses. As it fills:
  - Quality of reasoning degrades (the "lost in the middle" effect)
  - Claude may start ignoring instructions in CLAUDE.md or rules
  - Eventually it auto-compacts, which you want to control manually for better results

### The Two-Terminal Setup
Keep two terminal tabs open at all times:

**Tab 1: Claude Code (your main session)**
- All prompting, task execution, and review happens here
- NEVER run git commands here (wastes context tokens on git output)
- NEVER run long bash commands here unless Claude needs to see the output

**Tab 2: Git & utilities (your admin terminal)**
- All git commits happen here (headless `claude -p` or manual)
- Quick file checks (`wc -l`, `ls -la`, `head -5`)
- Package installs
- Anything that produces output you DON'T need Claude to see

### When Things Go Wrong
| Symptom | Cause | Fix |
|---------|-------|-----|
| Claude ignores CLAUDE.md rules | Context window too full | `/compact` or `/clear` |
| Responses getting vague/repetitive | Context degradation | `/clear` + restart from plan |
| "Rate limit" error | TPM limit | Wait 60 seconds, retry |
| "Usage limit reached" | Daily quota | Resume tomorrow with `claude --continue` |
| Terminal closed accidentally | — | `claude --continue` (session is saved) |
| Claude starts hallucinating numbers | Context too full or sycophancy | `/clear`, re-read source files, run `/project:verify-numbers` |
