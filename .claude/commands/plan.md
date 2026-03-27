Read the following files to understand where we are:
1. `docs/session-log.md` — what was done in previous sessions
2. `docs/execution-plan.md` — the approved plan (if it exists)
3. `docs/compact-context.md` — context from last compaction (if it exists)

Then:

**If no execution plan exists yet:**
→ Say: "No execution plan found. We should start with the Discovery & Planning phase. Run the Discovery Prompt from WORKFLOW_GUIDE.md."

**If an execution plan exists:**
→ Determine which task we're on based on the session log
→ Propose what to work on this session:
  1. What is the next task from the plan?
  2. What files need to be read to start it?
  3. Are there any blockers or open issues from previous sessions?
  4. Is an adversarial checkpoint due? (check if we just finished a phase)

The execution plan should be extremely detailed and comprehensive. Wait for confirmation before executing.
