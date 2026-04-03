# Grounding Protocol

**Purpose:** Systematic re-orientation when confused, after compression, or resuming work

---

## Core Principle

**When you don't know what's happening, stop and re-ground yourself.**

Don't:
- Guess at current state
- Assume you remember everything
- Continue working when uncertain
- Make up what you think happened

Do:
- Read persistent artifacts (plans, logs, git)
- Synthesize understanding
- State what you know
- Confirm with user before proceeding

---

## When to Ground

Execute grounding protocol in these situations:

### 1. After Context Compression
- Your context was cleared
- You don't remember recent conversation
- Need to reconstruct state from disk

### 2. When Unsure of Current State
- Can't articulate what's been completed
- Don't know what comes next
- Uncertain about active task

### 3. Before Substantial Work
- About to start multi-file changes
- Need baseline understanding
- Want to verify assumptions

### 4. User Says "Continue"
- No additional context provided
- Previous conversation may have been compressed
- Need to determine where you left off

### 5. When Confused
- Lost track of task
- Conflicting mental model
- Error recovery needed

**Rule:** If you can't clearly state "I'm working on X, just completed Y, next step is Z", then ground yourself.

---

## Grounding Checklist

Execute in order. Don't skip steps.

### Step 1: Read Most Recent Plan

**Location:** `quality_reports/plans/` (most recent .md file by date)

**Extract:**
- Goal: What is the overall objective?
- Approach: What's the strategy?
- Current step: Where should you be in the sequence?
- Files: Which files are involved?

**Example:**
```bash
# Find most recent plan
ls -lt quality_reports/plans/ | head -5
```

### Step 2: Read Last Session Log Entry

**Location:** `quality_reports/session_logs/` (most recent .md file by date)

**Extract:**
- Last changes: What was just done?
- Decisions: What choices were made?
- Open questions: What's still unclear?
- Status: What's the current state?

**Look for:**
- "## Current Status" section
- Recent timestamps
- Open question markers

### Step 3: Check Git History

**Commands:**
```bash
git log --oneline -5        # Recent commits
git status                  # Current changes
git diff                    # What's modified
```

**Extract:**
- Recent commits: What was just saved?
- Current changes: What's uncommitted?
- Clean or dirty: Is workspace clean?

### Step 4: Synthesize State

**Combine information from steps 1-3:**

- **Completed:** What's been done (from git commits + session log)
- **In progress:** What's currently being worked on (from git diff + session log)
- **Next:** What comes next (from plan)
- **Blockers:** Any open questions or issues (from session log)

**Template:**
```
From plan: [Goal from step 1]
Completed: [List from git commits]
In progress: [Current files from git diff]
Next step: [From plan]
Open questions: [From session log]
```

### Step 5: Confirm with User

**Present understanding and wait for confirmation:**

```
Resuming [project/task].

Completed: [concrete list]
In progress: [specific current work]
Next: [from plan]

Correct?
```

**Wait for user response.** Do not proceed until confirmed.

---

## Output Format

Use this template for grounding:

```
Resuming [project/task name].

From plan: [brief goal statement]

Completed:
- [concrete item 1]
- [concrete item 2]

In progress:
- [current file/task]

Next step:
- [next item from plan]

Open questions:
- [any blockers or unclear items]

Is this understanding correct?
```

---

## Examples

### Example 1: After Compression

**Situation:** Context was compressed, user says "continue"

**Grounding:**
```
Resuming scaffolding rules implementation.

From plan: quality_reports/plans/2026-04-02_scaffolding-rules.md
Goal: Build six scaffolding rules for Claude effectiveness

Completed (from git log):
- error-recovery.md created
- grounding-protocol.md created

In progress (from git diff):
- No uncommitted changes

Next step (from plan):
- Create request-handling.md (Phase 1, step 3)

No open questions noted in last session log.

Is this correct? Should I proceed with request-handling.md?
```

### Example 2: User Says "Continue" with No Context

**Situation:** User message just says "continue", unclear what they mean

**Grounding:**
```
Let me check current state:

Reading most recent plan... quality_reports/plans/2026-04-02_r-package-review.md
Reading last session log... quality_reports/session_logs/2026-04-02_r-package-review.md
Checking git status... last commit "Fix input validation in helper.R"

From context:
- Working on: R package code review
- Just completed: Fixed input validation issues
- Next in plan: Review test coverage

Should I continue with test coverage review?
```

### Example 3: Confused During Work

**Situation:** Lost track during multi-step task

**Grounding:**
```
I've lost track of where I am in this task. Let me reground:

Reading plan: quality_reports/plans/2026-04-02_refactoring.md
Plan shows: Refactor data pipeline (Step 3 of 5: Update tests)

Checking git:
- data_pipeline.R modified
- tests/ not yet touched

From session log:
- Completed: Refactored data_pipeline.R
- Next: Update corresponding tests

I should now update tests in tests/testthat/test-data-pipeline.R.
Correct?
```

---

## What to Do After Grounding

### If Understanding Confirmed

Proceed with confidence:
1. Execute next step from plan
2. Follow normal workflow
3. Update session log as you work

### If Understanding Incorrect

User will correct you:
1. Note the correction
2. Update your mental model
3. Re-state understanding
4. Wait for confirmation
5. Then proceed

### If Still Unclear

Ask specific follow-up questions:
- "I see X and Y in the plan. Which should I prioritize?"
- "The session log mentions Z was blocked. Is this still an issue?"
- "Should I proceed with the plan as written, or has the goal changed?"

**Don't proceed until clear.**

---

## Grounding Failure Modes

### Failure: Skipping Steps

**Don't:**
```
User: "Continue"
→ I'll work on the next file
→ (Wrong file, wrong task)
```

**Do:**
```
User: "Continue"
→ Run grounding protocol first
→ Read plan, log, git
→ Confirm understanding
→ Then proceed
```

### Failure: Assuming You Remember

**Don't:**
```
After compression:
→ "I think we were working on X"
→ (Guess, might be wrong)
```

**Do:**
```
After compression:
→ Read plan and log
→ "From the artifacts, we're working on X"
→ (Evidence-based)
```

### Failure: Not Waiting for Confirmation

**Don't:**
```
→ Synthesize state
→ Immediately start coding
→ (User can't correct if wrong)
```

**Do:**
```
→ Synthesize state
→ Present to user
→ Wait for confirmation
→ Then proceed
```

---

## Integration Points

### With Error Recovery

When confused (error-recovery.md step 2):
1. Stop generating
2. Run grounding protocol
3. State what's unclear
4. Ask specific question

See: `.claude/rules/error-recovery.md`

### With Plan-First Workflow

Plans enable grounding:
- Plans are saved to disk (survive compression)
- Plans have clear structure (easy to parse)
- Plans show sequence (know where you are)

See: `.claude/rules/plan-first-workflow.md`

### With Session Logging

Session logs enable grounding:
- Logs capture decisions and status
- Logs note open questions
- Logs show what's been completed

See: `.claude/rules/session-logging.md`

---

## Quick Reference

### Grounding Checklist (Quick)

```
[ ] Read most recent plan → extract goal, approach, current step
[ ] Read last session log → extract status, decisions, questions
[ ] Check git log + status → extract commits, changes
[ ] Synthesize state → completed, in-progress, next, blockers
[ ] Present to user → wait for confirmation
```

### When to Ground

- After context compression
- User says "continue" with no context
- Unsure of current state
- Before substantial work
- When confused

### Output Template

```
Resuming [X].
Completed: [Y].
In progress: [Z].
Next: [A from plan].
Correct?
```

---

## See Also

- `.claude/rules/error-recovery.md` - When to use grounding protocol
- `.claude/rules/plan-first-workflow.md` - Plans that survive compression
- `.claude/rules/session-logging.md` - Logs that enable grounding
- `.claude/rules/request-handling.md` - Handling "continue" requests

---

## Version History

- **2026-04-02**: Initial version - systematic grounding protocol
