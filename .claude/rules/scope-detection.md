# Scope Detection & Decomposition

**Purpose:** Recognize when tasks are too big and systematically break them down

---

## Core Principle

**Tasks that are too large lead to incomplete implementations, missed requirements, and quality problems.**

Signs of a too-large task:
- Can't hold full scope in working memory
- Plan would be >1 page
- Uncertain about intermediate states
- Too many novel decisions at once

**Solution:** Break into manageable subtasks, complete one at a time with quality.

---

## Task Too Big If...

**Any of these conditions indicate task should be decomposed:**

### 1. File Count: Touches >5 Files with Non-Trivial Changes

**Examples:**

❌ **Too big:**
```
"Refactor the entire package structure"
→ Touches: 15 R files, tests, docs, DESCRIPTION
→ Break down by: subsystem or phase
```

✅ **Right-sized:**
```
"Refactor the validation module (3 files)"
→ Touches: validation.R, validation-helpers.R, test-validation.R
→ Manageable in one task
```

### 2. Decision Count: Requires >3 Novel Design Decisions

**Novel decisions** = choices where:
- Multiple valid approaches exist
- No obvious "right" answer
- Need to balance tradeoffs
- Might need user input

**Examples:**

❌ **Too big:**
```
"Implement ML pipeline"
→ Decisions: preprocessing strategy, model selection, validation approach,
   error handling, API design, performance optimization
→ Break down by: phase (each with 1-2 decisions)
```

✅ **Right-sized:**
```
"Implement data preprocessing for ML pipeline"
→ Decisions: handling missing data, scaling approach
→ Manageable decisions for one task
```

### 3. Verification: Cannot Articulate How to Verify Success

**Can you clearly state:**
- What outputs will exist?
- How to test they're correct?
- What "done" looks like?

**Examples:**

❌ **Too big (vague success criteria):**
```
"Improve the package quality"
→ Cannot articulate specific verification
→ Break down by: concrete measurables (test coverage, documentation, error handling)
```

✅ **Right-sized:**
```
"Add tests to bring coverage to 80%"
→ Verification: Run covr::package_coverage(), check percentage
→ Clear success criteria
```

### 4. Plan Length: Plan Would Exceed 1 Page

**If your plan is >1 page of prose**, you're trying to do too much.

**Why this matters:**
- Can't hold full plan in working memory
- Easy to lose track of progress
- High chance of missing steps

**Solution:**
- Break into subtasks
- Full plan for first subtask
- High-level outline for remaining subtasks

### 5. Uncertainty: Uncertain About Intermediate States

**Can you describe the state after each step?**

❌ **Too big (uncertain intermediates):**
```
"Migrate from data.table to dplyr"
→ Uncertain: Will package still work after step 2?
→ Uncertain: How to test partially migrated code?
→ Break down by: file or function, so intermediates are testable
```

✅ **Right-sized:**
```
"Migrate data_cleaning.R from data.table to dplyr"
→ After step 1: data_cleaning.R uses dplyr, tests still pass
→ Clear intermediate state
```

---

## Decomposition Strategies

Choose the strategy that best fits your task.

### Strategy 1: By Subsystem

**When to use:** Task spans independent components

**How:**
1. Identify logical subsystems (modules, packages, features)
2. Order by dependency (foundational first)
3. Complete one subsystem at a time

**Example:**
```
Original task: "Build analysis pipeline"

Decomposed:
1. Data loading module (no dependencies)
2. Data cleaning module (depends on loading)
3. Statistical analysis module (depends on cleaning)
4. Visualization module (depends on analysis)
5. Report generation (depends on all)

Start with task 1, complete fully, then move to task 2.
```

### Strategy 2: By Phase

**When to use:** Task has natural sequential stages

**How:**
1. Identify phases (design → implement → test → document)
2. Complete each phase for whole scope
3. Or complete all phases for subset, then repeat

**Example:**
```
Original task: "Add new feature to package"

Decomposed (all phases for subset):
1. Design + implement + test + document core functionality
2. Design + implement + test + document edge case handling
3. Design + implement + test + document user-facing API

Or (one phase for whole scope):
1. Design complete feature (all aspects)
2. Implement all components
3. Test comprehensively
4. Document fully

Choose based on: first approach better for uncertain design, second better for clear design.
```

### Strategy 3: By Risk

**When to use:** Some parts are uncertain or risky

**How:**
1. Identify risky/uncertain components (novel algorithms, unclear requirements)
2. Do risky parts first (fail fast, learn early)
3. Do safe parts after (build on validated foundation)

**Example:**
```
Original task: "Implement novel estimator with UI"

Decomposed by risk:
1. Implement core novel estimator (HIGH RISK - algorithm might not work)
2. Add standard inference methods (MEDIUM RISK - depends on estimator)
3. Build UI for estimator (LOW RISK - routine work)

Rationale: If estimator doesn't work (step 1), avoid wasting time on UI (step 3).
```

### Strategy 4: By Deliverable

**When to use:** Multiple concrete outputs needed

**How:**
1. Identify distinct deliverables (spec, implementation, tests, docs, vignette)
2. Order by dependency
3. Complete one deliverable at a time

**Example:**
```
Original task: "Document and test new package"

Decomposed by deliverable:
1. Write function documentation (roxygen2)
2. Write tests for documented functions
3. Write vignette with examples
4. Create pkgdown site
5. Write NEWS.md entry

Each deliverable is independently valuable.
```

---

## User Communication Protocol

When you detect a task is too big, **don't silently proceed with partial implementation**.

### Step 1: Acknowledge Scope

State what you've observed:

**Good:**
```
"This task touches 8 files and requires 5 design decisions.
That's too large to complete reliably in one pass."
```

**Bad:**
```
"This is complicated" (vague)
"This will take a while" (not actionable)
```

### Step 2: Explain Why Breaking Down Helps

Give rationale:

**Good:**
```
"Breaking this into 3 subtasks will:
- Allow us to verify each piece works before moving on
- Make it easier to track progress
- Reduce risk of partial/incomplete implementation"
```

**Bad:**
```
"It's too hard to do all at once" (sounds like complaining)
```

### Step 3: Propose Breakdown

Suggest specific decomposition:

**Good:**
```
"I propose breaking this into 3 subtasks:

1. Refactor core validation logic (validation.R, validation-helpers.R)
   - 2 files, 1 design decision
   - Verification: existing tests still pass

2. Update tests to match new validation API
   - test-validation.R
   - Verification: full test coverage maintained

3. Update documentation and examples
   - roxygen2 comments, vignette
   - Verification: pkgdown site builds without warnings

Each subtask is manageable and has clear verification."
```

**Bad:**
```
"Let's do this in pieces" (not specific)
```

### Step 4: Get Buy-In

Ask for confirmation:

**Good:**
```
"Should I start with subtask 1 (core validation logic)?
Or would you prefer a different breakdown?"
```

**Bad:**
```
"I'll start with the first piece" (no user input)
"Which one should I do?" (too open-ended)
```

---

## Integration with Plan-First Workflow

### If Task is Too Big During Planning

**In plan mode:**
1. Note that task is too big (cite specific criteria)
2. Propose decomposition strategy
3. Plan **only first subtask** in detail
4. Outline remaining subtasks (high-level)
5. Get user approval on decomposition
6. Exit plan mode
7. Execute first subtask fully
8. Return to planning for next subtask

**Plan structure:**
```markdown
# Plan: [Original Task Name]

## Scope Assessment
This task is too large (>5 files, >3 decisions). Breaking into subtasks.

## Proposed Decomposition
1. [Subtask 1] - PLAN IN DETAIL BELOW
2. [Subtask 2] - High-level outline
3. [Subtask 3] - High-level outline

## Detailed Plan for Subtask 1
[Full plan with steps, files, verification]

## Next Steps
After subtask 1 complete:
- Review outcomes
- Plan subtask 2 in detail
- Iterate
```

### If Task Grows During Execution

**During implementation:**
1. Stop current work
2. Commit what's done so far (if at 80/100)
3. Document current state in session log
4. Propose decomposition of remaining work
5. Get user approval
6. Plan next piece
7. Continue

**Don't:**
- Keep going with partial implementation
- Commit unfinished work at <80/100
- Switch between subtasks rapidly

---

## Examples

### Example 1: Too Many Files

**Request:** "Refactor the package to use R6"

**Detection:**
```
Task assessment:
- Files: 12 R files, 12 test files, docs
- Decisions: conversion strategy, API changes, backward compatibility
- Verification: all tests pass, no API breaks
→ TOO BIG (>5 files, >3 decisions)
```

**Decomposition (by subsystem):**
```
"This task touches 24 files and makes 3+ design decisions.

I propose breaking into 4 subtasks:

1. Convert core classes to R6 (3 files: base, derived, utilities)
2. Convert data handling classes (2 files: data, validators)
3. Convert analysis classes (3 files: models, summaries, plots)
4. Update all tests and documentation

Start with subtask 1?"
```

### Example 2: Too Many Decisions

**Request:** "Add caching to the package"

**Detection:**
```
Task assessment:
- Decisions: caching strategy (memory/disk?), cache invalidation,
  API design (opt-in/out?), serialize format, cache location
- 5+ novel decisions
→ TOO BIG (>3 decisions)
```

**Decomposition (by risk):**
```
"This requires 5 design decisions. Let's de-risk by deciding first:

1. Design caching strategy (spec document)
   - Decide: memory vs disk, invalidation, API
   - Deliverable: design doc for review

2. Implement core caching (after design approved)
   - 2-3 files

3. Add user-facing API
   - 1 file + tests + docs

Start with design doc?"
```

### Example 3: Unclear Verification

**Request:** "Improve package performance"

**Detection:**
```
Task assessment:
- Verification: How to measure "improved"?
- Success criteria: Not specified
- Scope: Which functions? How much faster?
→ TOO BIG (cannot articulate verification)
```

**Decomposition (by deliverable):**
```
"I can't verify 'improved performance' without metrics.

I propose:

1. Benchmark current performance (deliverable: benchmark report)
   - Identify bottlenecks
   - Set improvement targets

2. Optimize identified bottlenecks (after targets set)
   - One bottleneck at a time
   - Verify: benchmark shows improvement

3. Document performance characteristics (after optimization)

Start with benchmarking?"
```

---

## Anti-Patterns

**Don't do these:**

❌ **Silently proceed with partial implementation**
```
Task is too big
→ Start coding
→ Get halfway through
→ Realize can't complete
→ Leave partial work
```

❌ **Break down too finely**
```
Task: "Add validation to 3 functions"
→ Subtask 1: Add validation to function 1
→ Subtask 2: Add validation to function 2
→ Subtask 3: Add validation to function 3
→ TOO GRANULAR (original task was manageable)
```

❌ **Break down without rationale**
```
"Let's do this in pieces"
→ User doesn't know why
→ Seems like you're avoiding work
```

❌ **Break down without specific proposal**
```
"This is too big"
→ No proposed subtasks
→ Not actionable
```

---

## Quick Reference

### Detection Checklist

```
Task too big if ANY of:
[ ] >5 files with non-trivial changes
[ ] >3 novel design decisions
[ ] Cannot articulate verification
[ ] Plan would be >1 page
[ ] Uncertain about intermediate states
```

### Decomposition Strategies

| Strategy | When to Use | How |
|----------|------------|-----|
| By subsystem | Independent components | Order by dependency |
| By phase | Sequential stages | Complete phases for subset or all |
| By risk | Uncertain parts exist | Risky parts first |
| By deliverable | Multiple outputs | One deliverable at a time |

### Communication Template

```
1. Acknowledge: "This task [specific criteria met]"
2. Explain: "Breaking down will [benefits]"
3. Propose: "I suggest [N] subtasks: [list with verification]"
4. Get buy-in: "Start with [first subtask]?"
```

---

## See Also

- `.claude/rules/plan-first-workflow.md` - Planning process
- `.claude/rules/request-handling.md` - Size classification
- `.claude/rules/quality-philosophy.md` - Why quality over speed matters
- `templates/requirements-spec.md` - Clarifying scope before planning

---

## Version History

- **2026-04-02**: Initial version - systematic scope detection and decomposition
