# Request Handling Protocol

**Purpose:** Classify incoming requests and route appropriately so user prompts (in whatever state) are maximally effective

---

## Core Principle

**Users shouldn't need perfect prompts. You should have systematic protocols to handle whatever comes in.**

This means:
- Don't guess at vague requests
- Don't over-plan trivial tasks
- Don't under-plan substantial tasks
- Do clarify ambiguity efficiently
- Do adapt response to request type
- Do route to appropriate protocol

---

## Classification Framework

Classify every request along three dimensions:

### Dimension 1: Task Type

| Type | Examples |
|------|----------|
| **Code** | Write R function, fix bug, refactor, add feature |
| **Writing** | Draft paper section, edit manuscript, write grant |
| **Analysis** | Process data, run model, generate figures |
| **Planning** | Design study, write spec, outline approach |
| **Review** | Code review, paper review, grant review |
| **Infrastructure** | Setup project, create template, configure tool |
| **Meta** | Update framework, modify workflow, improve rules |

### Dimension 2: Clarity Level

| Level | Indicators |
|-------|-----------|
| **CLEAR** | Specific file/function named, success criteria evident, actionable as stated |
| **NEEDS-SCOPING** | High-level goal, multiple valid interpretations, missing key details |
| **AMBIGUOUS-BLOCKED** | Contradictory, unclear goal, cannot proceed without clarification |

### Dimension 3: Size Estimate

| Size | Indicators | Time |
|------|-----------|------|
| **Trivial** | Single small change, no decisions needed, obvious approach | <5 min |
| **Small** | 1-3 files, straightforward implementation, few decisions | 5-30 min |
| **Substantial** | >3 files OR novel decisions OR complex logic | >30 min |

---

## Response Strategy Matrix

| Clarity | Size | Strategy | Protocol |
|---------|------|----------|----------|
| CLEAR | Trivial | Execute directly, then verify | No planning needed |
| CLEAR | Small | Quick inline plan, execute, verify | Outline approach in 3-5 bullets |
| CLEAR | Substantial | Enter plan mode, full plan | `.claude/rules/plan-first-workflow.md` |
| NEEDS-SCOPING | Trivial | Quick clarification (1-2 questions) | See clarification template below |
| NEEDS-SCOPING | Small | Clarification (2-3 questions), then plan | AskUserQuestion, then route |
| NEEDS-SCOPING | Substantial | Requirements spec, then plan | Spec-then-plan workflow |
| AMBIGUOUS-BLOCKED | Any | Identify gaps, cannot proceed | State what's unclear, ask directed questions |

---

## Classification Examples

### Example 1: Clear + Trivial
**Request:** "Fix the typo in line 42 of analysis.R"

**Classification:**
- Type: Code
- Clarity: CLEAR (specific line, specific file)
- Size: Trivial (one line)

**Strategy:** Execute directly
```
Action: Read file, fix typo, verify compiles
No plan needed
```

### Example 2: Clear + Substantial
**Request:** "Implement the three-stage analysis pipeline described in the spec"

**Classification:**
- Type: Code + Analysis
- Clarity: CLEAR (spec exists, pipeline defined)
- Size: Substantial (multi-stage, multiple files)

**Strategy:** Enter plan mode
```
Action: EnterPlanMode, read spec, draft plan, save to disk, wait for approval
```

### Example 3: Needs-Scoping + Small
**Request:** "Improve the error messages in the package"

**Classification:**
- Type: Code
- Clarity: NEEDS-SCOPING (which functions? what improvements?)
- Size: Uncertain (depends on scope)

**Strategy:** Clarify scope first
```
Action: AskUserQuestion with 2-3 specific questions:
1. Which functions? (all exported, or specific ones?)
2. What kind of improvements? (more informative, follow cli package patterns, add hints?)
3. Should I also update tests?
```

### Example 4: Needs-Scoping + Substantial
**Request:** "Analyze the trial data and write up results"

**Classification:**
- Type: Analysis + Writing
- Clarity: NEEDS-SCOPING (which analyses? what format? what's the hypothesis?)
- Size: Substantial (multi-step, multiple outputs)

**Strategy:** Requirements spec, then plan
```
Action: Create requirements spec using templates/requirements-spec.md
- Ask 4-5 clarification questions
- Document MUST/SHOULD/MAY requirements
- Mark CLEAR/ASSUMED/BLOCKED items
- Get spec approval
- Then enter plan mode
```

### Example 5: Ambiguous-Blocked
**Request:** "Make it better"

**Classification:**
- Type: Unknown
- Clarity: AMBIGUOUS-BLOCKED (what is "it"? better how?)
- Size: Unknown

**Strategy:** Cannot proceed, identify gaps
```
Action: State what's unclear
"I need clarification:
1. What should I improve? (code, writing, analysis, something else?)
2. What file or component?
3. What aspect needs improvement? (performance, clarity, correctness, style?)

Please provide more context."
```

---

## Clarification Template

When clarity is NEEDS-SCOPING or AMBIGUOUS-BLOCKED, use this structure:

### 1. State What You Understand
"I understand you want to [X]"

**Good:**
```
"I understand you want to improve error messages in the package"
```

**Bad:**
```
"I understand" (too vague)
```

### 2. Identify What's Unclear
"I'm uncertain about [Y, Z]"

**Good:**
```
"I'm uncertain about:
- Which functions need improved messages (all, or specific ones?)
- What constitutes 'improvement' (more detail, better formatting, cli patterns?)
- Scope (messages only, or also warnings and validation?)"
```

**Bad:**
```
"I don't know what you want" (too vague, sounds confused)
```

### 3. Offer Interpretations (if applicable)
"This could mean: (a) [...], (b) [...], (c) [...]"

**Good:**
```
"This could mean:
(a) Update all user-facing error messages to use cli package formatting
(b) Focus on the top 3 confusing errors identified in issues
(c) Add more informative messages with hints for common mistakes"
```

**Bad:**
```
"There are many ways to interpret this" (not helpful)
```

### 4. Ask Directed Questions
"Which approach fits your goal? Are there constraints I should know?"

**Good:**
```
"Questions:
1. Should I focus on specific functions or improve all errors?
2. Are there examples of good error messages you'd like me to follow?
3. Should I update tests to match new messages?"
```

**Bad:**
```
"What do you want me to do?" (too broad)
"Can you clarify?" (too vague)
```

---

## Decision Tree

```
New request
    ↓
Can you articulate specific success criteria?
    ↓
   YES → CLEAR
    │
    ├─ <5 min, single change?
    │   ↓
    │  YES → Execute directly
    │
    ├─ 1-3 files, straightforward?
    │   ↓
    │  YES → Quick inline plan (3-5 bullets), then execute
    │
    └─ >3 files OR novel decisions?
        ↓
       YES → EnterPlanMode, full plan

    ↓
   NO → NEEDS-SCOPING or AMBIGUOUS-BLOCKED?
    │
    ├─ High-level but reasonable assumptions possible?
    │   ↓
    │  YES → NEEDS-SCOPING
    │   │
    │   ├─ Trivial/Small → 1-3 clarifying questions, then route
    │   │
    │   └─ Substantial → Requirements spec (spec-then-plan)
    │
    └─ Cannot make progress without answers?
        ↓
       YES → AMBIGUOUS-BLOCKED
        │
        └─ Identify gaps, state what's unclear, ask directed questions
```

---

## Special Request Types

### "Continue" with No Context

**Classification:** Likely CLEAR if work was in progress, but need to verify

**Strategy:**
1. Run grounding protocol (`.claude/rules/grounding-protocol.md`)
2. Read plan, session log, git status
3. Synthesize understanding
4. Confirm with user: "Resuming X. Last completed Y. Next is Z. Correct?"
5. Wait for confirmation
6. Then proceed

### "Review [file]"

**Classification:**
- Type: Review
- Clarity: Usually CLEAR (file is specified)
- Size: Depends on file size and review depth

**Strategy:**
- Small file (<200 lines): Review directly
- Large file or complex: Use relevant review skill (/review-paper, /review-r, /review-code)

### "Implement [vague description]"

**Classification:**
- Type: Code
- Clarity: NEEDS-SCOPING (vague description)
- Size: Unknown

**Strategy:**
1. Ask clarifying questions (3-5 questions)
2. Once clear, re-classify size
3. Route to appropriate strategy (small vs substantial)

---

## Anti-Patterns

**Don't do these:**

❌ **Guess at vague requests**
```
Request: "Improve the code"
Bad: Starts refactoring without asking what needs improvement
Good: "Which code? What aspect needs improvement (performance, clarity, organization)?"
```

❌ **Over-plan trivial tasks**
```
Request: "Fix typo in line 10"
Bad: Enters plan mode, writes 200-word plan
Good: Fix directly, verify
```

❌ **Under-plan substantial tasks**
```
Request: "Build the entire analysis pipeline"
Bad: Starts coding without plan
Good: Enter plan mode, spec if needed, full plan with verification steps
```

❌ **Ask vague clarification questions**
```
Request: (ambiguous)
Bad: "What do you want?"
Good: "I need to know: (1) which files, (2) what outcomes, (3) any constraints?"
```

❌ **Proceed when blocked**
```
Request: (contradictory instructions)
Bad: Guess which instruction to follow
Good: Stop, surface conflict, ask user
```

---

## Integration Points

### With Plan-First Workflow

When classification → CLEAR + Substantial:
1. Route to plan-first workflow
2. EnterPlanMode
3. If complex/ambiguous, create requirements spec first
4. Then draft plan

See: `.claude/rules/plan-first-workflow.md`

### With Scope Detection

When task might be too big:
1. Use scope detection criteria
2. Propose decomposition if needed
3. Get user agreement

See: `.claude/rules/scope-detection.md`

### With Grounding Protocol

When request is "continue" or after compression:
1. Use grounding protocol to re-orient
2. Confirm understanding
3. Then route appropriately

See: `.claude/rules/grounding-protocol.md`

### With Error Recovery

When request is ambiguous-blocked:
1. Follow error recovery → confusion protocol
2. Stop, state what's unclear, ask specific questions
3. Wait for clarification

See: `.claude/rules/error-recovery.md`

---

## Quick Reference

### Classification Quick Check

```
CLEAR? → Can you articulate specific success criteria?
         Can you execute without assumptions?

NEEDS-SCOPING? → Reasonable assumptions possible?
                  2-5 questions would clarify?

AMBIGUOUS-BLOCKED? → Cannot proceed without answers?
                      Conflicting/contradictory?

TRIVIAL? → <5 min, single change, obvious

SMALL? → 1-3 files, straightforward, few decisions

SUBSTANTIAL? → >3 files OR novel decisions OR >30 min
```

### Response Quick Guide

| Classification | Response |
|----------------|----------|
| Clear + Trivial | Execute → verify |
| Clear + Small | 3-5 bullet plan → execute → verify |
| Clear + Substantial | EnterPlanMode → full plan |
| Needs-scoping | Clarify (1-5 questions) → re-classify |
| Ambiguous-blocked | State gaps → ask directed questions |

---

## See Also

- `.claude/rules/plan-first-workflow.md` - When and how to plan
- `.claude/rules/scope-detection.md` - Recognizing tasks too big
- `.claude/rules/grounding-protocol.md` - Handling "continue"
- `.claude/rules/error-recovery.md` - Handling confusion
- `templates/requirements-spec.md` - Spec-then-plan for complex tasks

---

## Version History

- **2026-04-02**: Initial version - systematic request classification and routing
