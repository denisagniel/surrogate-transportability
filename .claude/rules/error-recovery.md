# Error Recovery Protocol

**Purpose:** Systematic recovery when things go wrong instead of flailing or guessing

---

## Core Principle

**When something fails, stop and diagnose before retrying.**

- Don't guess fixes
- Don't retry the same approach endlessly
- Don't mask symptoms instead of fixing root causes
- Don't continue when confused

---

## 1. Compilation / Test Failures

### Protocol

1. **[ ] Read error message carefully**
   - Don't skim
   - Read full error, not just first line
   - Note line numbers, file paths, specific values

2. **[ ] Identify root cause, not symptom**
   - Why did this fail?
   - What assumption was violated?
   - What's the actual problem?

3. **[ ] If unclear, investigate or ask**
   - Read relevant code
   - Check documentation
   - Ask user if ambiguous

4. **[ ] Fix root cause**
   - Not symptom
   - Not workaround
   - Actual underlying issue

5. **[ ] Verify fix works**
   - Re-run compilation/test
   - Check that error is gone
   - Verify output is correct

6. **[ ] Max 2 retries of same approach**
   - If same approach fails twice, stop
   - Try different approach or ask user

### Examples

**BAD (symptom fix):**
```r
Error: object 'x' not found
→ Add x <- NULL at top of function
→ Masks real issue, creates new problems
```

**GOOD (root cause):**
```r
Error: object 'x' not found
→ Why is x missing?
→ Check: Was it supposed to be passed as argument?
→ Check: Typo in variable name?
→ Check: Wrong scope?
→ Fix: Add x to function parameters
```

**BAD (infinite retry):**
```
LaTeX error: Package not found
→ Try compile again (fails)
→ Try compile again (fails)
→ Try compile again (fails)
→ ...
```

**GOOD (diagnose first):**
```
LaTeX error: Package not found
→ Which package? Read error message
→ Check if package installed
→ Install package or ask user
→ Then retry
```

### Common Pitfalls

| Pitfall | Why Bad | Instead |
|---------|---------|---------|
| Add NULL checks everywhere | Masks real bugs | Find why value is NULL |
| Wrap in try() without handling | Silences errors | Fix the error |
| Guess at fix without reading error | Wrong diagnosis | Read error carefully |
| Keep retrying compilation | Wastes time | Diagnose after 1 failure |
| Fix symptom instead of cause | Bug persists | Identify root cause |

---

## 2. Confusion / Lost State

### Protocol

1. **[ ] Stop generating immediately**
   - Don't continue when confused
   - Don't guess what user wants
   - Don't make assumptions

2. **[ ] Run grounding protocol**
   - See `.claude/rules/grounding-protocol.md`
   - Read recent plan, session log, git status
   - Synthesize understanding

3. **[ ] State what's unclear**
   - Be specific: "I don't know whether X or Y"
   - Not vague: "I'm confused"

4. **[ ] Ask specific question**
   - Directed: "Should I prioritize X or Y?"
   - Not fishing: "What should I do?"

5. **[ ] Resume only with clarity**
   - Wait for user answer
   - Confirm understanding
   - Then proceed

### Examples

**BAD (guessing under uncertainty):**
```
User: "Continue with the analysis"
→ I'll assume you want the regression model
→ (Wrong assumption, implements wrong thing)
```

**GOOD (clarify first):**
```
User: "Continue with the analysis"
→ "I see two possible next steps:
   (a) Run the regression model from the plan
   (b) Generate descriptive statistics first
   Which should I start with?"
```

---

## 3. Conflicting Instructions

### Protocol

1. **[ ] Stop immediately**
   - Don't guess which instruction applies
   - Don't try to reconcile on your own

2. **[ ] Surface conflict explicitly**
   - Show both instructions
   - Quote exact text
   - Be clear about the conflict

3. **[ ] Note instruction hierarchy**
   - Constitution overrides everything (for research quality/ethics)
   - CLAUDE.md overrides user prompts (for workflow)
   - Explicit user override can override CLAUDE.md (if user says "ignore CLAUDE.md")
   - Recent instruction typically overrides old instruction

4. **[ ] Ask user to clarify**
   - "Which applies here?"
   - "Should I follow A or B?"
   - Don't decide yourself

5. **[ ] Document resolution**
   - Note which instruction won
   - Why it won
   - Save to session log if systematic

### Examples

**Conflict: Prompt vs CLAUDE.md**
```
User prompt: "Skip the plan and just implement"
CLAUDE.md: "Enter plan mode before non-trivial tasks"

→ STOP. Surface conflict:
"CLAUDE.md requires planning first for non-trivial tasks.
You've asked to skip planning. Should I:
(a) Enter plan mode (per CLAUDE.md)
(b) Skip planning (per your request)
Which do you prefer?"
```

**Conflict: Constitution vs prompt**
```
User: "Run simulation with only favorable settings"
Constitution §9: "Include stress regimes, no quiet favoritism"

→ STOP. Surface conflict:
"The constitution requires stress regimes in simulations.
You've asked for only favorable settings.
I'll follow the constitution and include stress regimes.
If you need different behavior, we should discuss why."
```

---

## 4. Context Limits Approaching

### Protocol

1. **[ ] Save critical state before compression**
   - Update session log: current status, decisions, open questions
   - Update MEMORY.md: any [LEARN] items from this session
   - Save active plan to disk: `quality_reports/plans/`
   - Note what must persist: key context that can't be lost

2. **[ ] Check what's already persistent**
   - Plans in `quality_reports/plans/`
   - Session logs in `quality_reports/session_logs/`
   - MEMORY.md entries
   - Git commits with good messages

3. **[ ] Allow compression or suggest /clear**
   - Normal case: allow auto-compression (context survives in saved artifacts)
   - Polluted case: suggest `/clear` to user (e.g., after many failed attempts)

4. **[ ] After compression: ground immediately**
   - Run grounding protocol (see `.claude/rules/grounding-protocol.md`)
   - Don't assume you remember everything
   - Verify understanding before continuing

### What Must Persist

**Critical (save before compression):**
- Current task and status
- Key decisions made in this session
- Open questions or blockers
- Active plan details

**Already persistent (no action needed):**
- Git commits
- Saved plans in quality_reports/plans/
- Session logs in quality_reports/session_logs/
- MEMORY.md learnings

**Ephemeral (okay to lose):**
- Specific conversation details
- Intermediate reasoning
- Tool outputs that led to final state

### Example

**Before compression:**
```
Token limit approaching...

[ ] Check session log updated (within last 10 mins)
[ ] Check MEMORY.md has [LEARN] items from session
[ ] Check active plan saved to disk
[ ] Note open questions in session log

Ready for compression.
```

**After compression:**
```
Context compressed. Running grounding protocol:

1. Reading most recent plan: quality_reports/plans/2026-04-02_scaffolding-rules.md
2. Reading last session log: quality_reports/session_logs/2026-04-02_scaffolding-rules.md
3. Checking git: last commit was "Add error-recovery.md"
4. Current status: Completed error-recovery.md, next is grounding-protocol.md

Resuming implementation of scaffolding rules. Correct?
```

---

## 5. Tool Failures

### Protocol

1. **[ ] Read error from tool**
   - Don't assume what went wrong
   - Read actual error message

2. **[ ] Common tool issues:**
   - **File not found:** Check path, check typo
   - **Permission denied:** Check file permissions, check if file open elsewhere
   - **Edit failed:** Did you Read the file first? (required for Edit tool)
   - **Bash command failed:** Check exit code, check stderr

3. **[ ] Fix and retry once**
   - Fix the specific issue
   - Retry exactly once
   - If fails again, diagnose differently

4. **[ ] If tool not working, try alternative**
   - Edit failed → try Write (if complete rewrite)
   - Bash command failed → try dedicated tool (Read instead of cat)
   - Can't find file → try Glob to search

---

## Quick Reference

| Error Type | Protocol | Max Retries |
|------------|----------|-------------|
| Compilation/test failure | Read error → diagnose → fix root cause | 2 same approach |
| Confusion/lost state | Stop → grounding protocol → ask specific question | N/A |
| Conflicting instructions | Stop → surface conflict → ask user | N/A |
| Context limits | Save state → allow compression → ground after | N/A |
| Tool failure | Read error → fix issue → retry once | 1 |

---

## Anti-Patterns

**Don't do these:**

- ❌ Keep retrying without diagnosing
- ❌ Fix symptoms instead of root causes
- ❌ Guess user intent when confused
- ❌ Choose between conflicting instructions yourself
- ❌ Continue working when fundamentally unclear
- ❌ Add error suppression (try/catch) without handling
- ❌ Wrap everything in NULL checks instead of fixing bugs
- ❌ Skip verification after fix

**Do these:**

- ✅ Stop and diagnose before retrying
- ✅ Identify root causes
- ✅ Ask specific questions when confused
- ✅ Surface conflicts explicitly
- ✅ Ground yourself after compression
- ✅ Verify fixes work
- ✅ Fix actual bugs, not symptoms
- ✅ Max 2 retries of same approach

---

## Integration

### With Grounding Protocol

When confused or after compression:
1. Use grounding protocol to re-orient
2. State understanding
3. Ask specific question if needed

See: `.claude/rules/grounding-protocol.md`

### With Quality Philosophy

Error recovery aligns with correctness-over-speed:
- Take time to diagnose properly
- Fix root causes, not symptoms
- Don't rush fixes that create more problems

See: `.claude/rules/quality-philosophy.md`

### With Plan-First Workflow

When errors reveal design issues:
- May need to revise plan
- Document decision in session log
- Update plan on disk

See: `.claude/rules/plan-first-workflow.md`

---

## See Also

- `.claude/rules/grounding-protocol.md` - Re-orientation when confused
- `.claude/rules/quality-philosophy.md` - Fix-it-right principle
- `.claude/rules/plan-first-workflow.md` - Context survival via plans
- `.claude/rules/request-handling.md` - Clarifying ambiguous requests

---

## Version History

- **2026-04-02**: Initial version - systematic error recovery protocols
