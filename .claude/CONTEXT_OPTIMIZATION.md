# Context Optimization Guide

**Purpose:** Practical techniques for minimizing token usage while preserving functionality

**See also:** `.claude/ARCHITECTURE.md` for the three-tier architecture model (this document focuses on how to optimize within that model)

---

## Core Principle

**Load only what you need, when you need it.**

Three questions for any context:
1. **Is this needed at startup?** (>80% of sessions) → Tier 1 (always-on)
2. **Is this needed only for specific file types?** → Tier 2 (path-conditional)
3. **Is this needed only when skill invoked?** → Tier 3 (skill-internal)

**Default to lower tiers** (path-conditional or skill-internal) unless proven need for always-on.

---

## Token Budgets by Component

### Target Budgets

| Component | Token Budget | Rationale |
|-----------|--------------|-----------|
| **Startup context (Tier 1)** | 1,500-2,000 | Essentials only, loaded every session |
| **Path-conditional rule** | 400-1,000 | Detailed protocol, loads when matched |
| **Scaffolding rule (always-on)** | 600-800 | Universal protocol, keep focused |
| **Quality rubric (path-conditional)** | 2,000-3,000 | Comprehensive, loads for specific types |
| **Agent context** | 500-1,000 | Specialized, loads only when agent used |
| **Skill (minimal wrapper)** | 100-300 | Routing only, delegates to agent |
| **Skill (full implementation)** | 800-1,500 | Self-contained with embedded protocols |

### Current Framework (As of 2026-04-02)

| Component | Actual | Budget | Status |
|-----------|--------|--------|--------|
| **Tier 1 (startup)** | ~1,830 | 1,500-2,000 | ✓ Good |
| **error-recovery.md** | ~2,500 | 600-800 | ⚠️ Large (but comprehensive) |
| **grounding-protocol.md** | ~2,100 | 600-800 | ⚠️ Large (but comprehensive) |
| **request-handling.md** | ~2,700 | 600-800 | ⚠️ Large (but comprehensive) |
| **scope-detection.md** | ~3,200 | 600-800 | ⚠️ Large (but comprehensive) |
| **quality-rubrics.md** | ~3,200 | 2,000-3,000 | ✓ Good (path-conditional) |
| **decision-frameworks.md** | ~3,200 | 400-1,000 | ⚠️ Large |

**Note:** Scaffolding rules are larger than typical rules because they're comprehensive and self-contained. This is intentional for clarity, but consider splitting if they exceed 4,000 tokens (~16 KB).

---

## Optimization Techniques

### Technique 1: Extract Relevant Sections

**When to use:** Large document where agents/skills only need subsections

**Pattern:**
```markdown
# Full document: meta-spec/RESEARCH_CONSTITUTION.md (122 lines, ~3,000 tokens)
# Agent needs: §2-5 only (principles, not workflow)
# Extract to: .claude/rules/specialized/research-principles.md (80 lines, ~2,000 tokens)
# Savings: 33% per agent invocation
```

**Example from RAND repo:**
- **Before:** domain-reviewer loaded full constitution (3,000 tokens)
- **After:** domain-reviewer loads extracted principles (2,000 tokens)
- **Savings:** 1,000 tokens per review

**How to apply in this framework:**

1. **For agents that need constitution subset:**
   ```markdown
   # Instead of loading full RESEARCH_CONSTITUTION.md
   # Create .claude/rules/specialized/research-principles-excerpt.md
   # With only §2-5 (identification, evidence, reproducibility, strength)
   ```

2. **For skills that need orchestrator subset:**
   ```markdown
   # Instead of loading full orchestrator-protocol.md
   # Embed 5-7 key points in skill SKILL.md
   # See Technique 4: Skill-Internal Protocols
   ```

### Technique 2: Path-Conditional Loading

**When to use:** Rule is specific to certain file types or directories

**Pattern:**
```yaml
---
paths:
  - "**/*.R"
  - "**/*.py"
  - "scripts/**"
---

# Rule content here
```

**Token impact:**
- **Without paths:** Loads at startup for all sessions (always costs tokens)
- **With paths:** Loads only when working in matched files (0 cost until matched)

**Example in this framework:**

```yaml
# quality-rubrics.md - Only loads for code/documents
---
paths:
  - "**/*.R"
  - "**/*.py"
  - "**/*.tex"
  - "**/*.qmd"
  - "manuscript/**"
  - "analysis/**"
---
```

**Savings:** 3,200 tokens when working on non-code tasks (planning, session logs, meta-work)

### Technique 3: Delegate via Agent Tool

**When to use:** Skill invokes specialized agent for review/analysis

**Anti-pattern:**
```markdown
# Skill loads rules + processes task
---
name: review-paper
---

Load constitution, load review protocol, perform review.
```
**Problem:** Skill loads ~3K tokens, then if it creates agent, agent also loads ~1K tokens → 4K total, with overlap

**Pattern:**
```markdown
# Skill delegates to agent; agent loads its own rules
---
name: review-paper
disable-model-invocation: true
allowed-tools: ["Agent"]
---

Parse $ARGUMENTS, invoke domain-reviewer agent, display summary.
```
**Savings:** Prevents double-loading (skill loads 200 tokens, agent loads 1,000 tokens = 1,200 total vs 4,000)

**How to implement:**

1. Add frontmatter:
   ```yaml
   disable-model-invocation: true
   allowed-tools: ["Agent"]
   ```

2. Skill becomes minimal wrapper:
   ```markdown
   ## Implementation

   1. Parse file path from $ARGUMENTS
   2. Invoke agent: `Agent` tool with `subagent_type="domain-reviewer"`
   3. Display agent summary
   ```

3. Agent loads its own specialized rules

**Current skills to consider converting:**
- /review-paper (delegates to domain-reviewer)
- /review-r (delegates to r-reviewer)
- /proofread (delegates to proofreader)
- /presentation-review (delegates to slide-auditor)

**Trade-off:** More setup complexity vs token savings. Worth it for frequently-used review skills.

### Technique 4: Skill-Internal Protocols

**When to use:** Skill needs essential subset of full protocol to execute

**Pattern:**
```markdown
## [Protocol Name] (Essential Points)

Key requirements (embedded for self-contained execution):
1. [Essential point 1]
2. [Essential point 2]
3. [Essential point 3]
4. [Essential point 4]
5. [Essential point 5]

**Full protocol:** `.claude/rules/[protocol].md` (loads when working in relevant files)
```

**Token impact:**
- **Embedding:** ~400 tokens in skill (only when skill invoked)
- **Full protocol:** ~2,000 tokens (loads via path-conditional when working in files)
- **Benefit:** Skill works immediately without waiting for path match

**Example:**

```markdown
# Skill: /simulations

## Simulation Invariants (Essential Points)

From RESEARCH_CONSTITUTION.md §9:
1. Include stress regimes (boundary of parameter space)
2. No quiet favoritism (don't design simulations to succeed)
3. Report all results (failures + successes)
4. Reproducibility: document seed, DGP, save results
5. UQ required (uncertainty quantification for estimates)

**Full protocol:** `.claude/rules/code-paper-package-alignment.md`
```

**When to use this technique:**
- User might invoke skill before opening relevant files
- Skill needs to execute independently
- Essential subset is small (5-7 points, ~400 tokens)

**When NOT to use:**
- Full protocol is needed (just reference it)
- Protocol is too large to extract cleanly
- Duplication outweighs benefit

### Technique 5: Specialized Rules Directory

**When to use:** Rule is only needed by specific agents, not main sessions

**Pattern:**
```
.claude/rules/
├── (always-on rules)        # No YAML frontmatter
├── (path-conditional rules) # Has paths: frontmatter
└── specialized/             # Agent-specific rules
    ├── proofreading-protocol.md      (proofreader agent only)
    ├── tikz-visual-quality.md        (tikz-reviewer agent only)
    ├── domain-review-principles.md   (domain-reviewer agent only)
    └── r-code-conventions.md         (r-reviewer agent only)
```

**Token impact:**
- **If in root:** Risk of loading for main sessions (path match might be broad)
- **If in specialized/:** Only agents load it explicitly
- **Savings:** Prevents accidental loading in main sessions

**Example:**

```markdown
# r-code-conventions.md
# Used ONLY by r-reviewer agent
# Not needed by main orchestrator (has general quality-rubrics.md)
# Location: .claude/rules/specialized/r-code-conventions.md
```

**Current framework application:**

Consider moving to specialized/ if:
- Rule is agent-specific (only one agent uses it)
- Rule has narrow scope (not useful in main sessions)
- Path patterns would be too broad (risk of accidental loading)

**Candidates to review:**
- None currently (your rules are appropriately scoped)
- Future agent-specific rules should go in specialized/

---

## Measurement & Verification

### How to Measure Token Usage

**Method 1: Approximate (Quick)**

```bash
# Count words, multiply by 1.3 for token estimate
wc -w .claude/rules/error-recovery.md
# 1,923 words × 1.3 ≈ 2,500 tokens

# Or count characters, divide by 4
wc -c .claude/rules/error-recovery.md
# 10,123 chars ÷ 4 ≈ 2,531 tokens
```

**Method 2: Accurate (Use Tool)**

```python
# Using tiktoken (OpenAI tokenizer, similar to Claude)
import tiktoken
encoder = tiktoken.encoding_for_model("gpt-4")

with open(".claude/rules/error-recovery.md") as f:
    content = f.read()
    tokens = len(encoder.encode(content))
    print(f"Tokens: {tokens}")
```

**Method 3: Before/After Comparison**

1. Count tokens in old version
2. Optimize (extract, delegate, etc.)
3. Count tokens in new version
4. Calculate reduction percentage

### Target Reductions

| Optimization | Target Reduction |
|--------------|------------------|
| **Extract relevant sections** | 20-40% |
| **Delegate to agent** | 50-70% (prevents double-loading) |
| **Path-conditional loading** | 100% for non-matching sessions |
| **Skill-internal protocols** | N/A (changes when loaded, not amount) |

### Verification Checklist

After optimizing:

- [ ] **Functionality preserved:** Test that agent/skill still works correctly
- [ ] **Context still sufficient:** Agent has all info it needs
- [ ] **No broken references:** All @ references or file paths resolve
- [ ] **Token reduction achieved:** Measure actual savings
- [ ] **Documentation updated:** Update any references to moved/changed files

---

## Common Over-Loading Anti-Patterns

### ❌ Anti-Pattern 1: Loading Full Constitution for Specialized Agents

**Problem:** Agent needs principles but loads entire constitution

**Example:**
```markdown
# proofreader agent
Read: meta-spec/RESEARCH_CONSTITUTION.md (122 lines, ~3,000 tokens)
# But only uses: §13 (writing principles, ~20 lines, ~500 tokens)
```

**Fix:** Extract relevant section
```markdown
# Create: .claude/rules/specialized/writing-principles.md
# Content: Just §13 from constitution
# proofreader loads: writing-principles.md (~500 tokens)
# Savings: 2,500 tokens per proofread
```

### ❌ Anti-Pattern 2: Always-On Rules for Type-Specific Guidance

**Problem:** Rule is always-on but only applies to specific file types

**Example:**
```markdown
# r-code-conventions.md (no YAML frontmatter)
# Loads at every startup, even for LaTeX-only sessions
```

**Fix:** Add path-conditional frontmatter
```yaml
---
paths:
  - "**/*.R"
  - "R/**"
  - "tests/**"
---
```

**Your framework:** ✓ Already doing this correctly (quality-rubrics, decision-frameworks have paths)

### ❌ Anti-Pattern 3: Skills Loading Context Instead of Delegating

**Problem:** Skill loads rules, then calls agent; agent also loads rules

**Example:**
```markdown
# Skill loads 2K tokens (constitution + review protocol)
# Calls agent
# Agent loads 1K tokens (review protocol)
# Total: 3K tokens, with 1K overlap
```

**Fix:** Skill delegates without loading
```yaml
---
disable-model-invocation: true
allowed-tools: ["Agent"]
---

Invoke agent; agent loads its own context.
```

**Your framework:** ⚠️ Consider for review skills (/review-paper, /review-r, etc.)

### ❌ Anti-Pattern 4: Overly Broad Path Patterns

**Problem:** Path pattern matches more files than intended

**Example:**
```yaml
---
paths:
  - "**/*"    # Matches EVERYTHING, always loads
---
```

**Fix:** Be specific
```yaml
---
paths:
  - "**/*.R"
  - "**/*.py"
  - "scripts/**/*.sh"
---
```

### ❌ Anti-Pattern 5: Duplicating Context Across Rules

**Problem:** Same content appears in multiple rules

**Example:**
```markdown
# quality-rubrics.md: R code standards
# r-code-conventions.md: R code standards (duplicate)
# decision-frameworks.md: R code standards (duplicate)
```

**Fix:** Single source of truth, others reference it
```markdown
# quality-rubrics.md: Full R code standards
# decision-frameworks.md: "See quality-rubrics.md for standards"
# r-code-conventions.md: Specialized conventions not in quality-rubrics
```

**Your framework:** ✓ Mostly good, some overlap between decision-frameworks and quality-rubrics is acceptable for different perspectives

---

## Optimization Checklists

### When Creating New Agent

**Before creating:**
- [ ] What context does this agent actually need?
- [ ] Can I extract a subset instead of loading full document?
- [ ] Which rules are essential vs nice-to-have?
- [ ] Are any existing rules already specialized enough?

**During creation:**
- [ ] Load ONLY rules agent needs for its task
- [ ] Prefer specialized/ directory for agent-specific rules
- [ ] Don't load constitution if agent doesn't need research principles
- [ ] Don't load orchestrator rules if agent is task-specific
- [ ] Test that agent has sufficient context

**After creation:**
- [ ] Measure token usage (target: 500-1,000)
- [ ] Verify functionality (agent works correctly)
- [ ] Document what context agent loads
- [ ] Consider if any rules should be extracted for reuse

### When Creating New Skill

**Before creating:**
- [ ] Does this skill need to process task or just route to agent?
- [ ] If routing, use delegation pattern (disable-model-invocation)
- [ ] If processing, what subset of protocols needed?
- [ ] Will users invoke before opening relevant files?

**During creation:**
- [ ] Use `disable-model-invocation: true` if delegating to agent
- [ ] Embed essential protocols (5-7 points) if self-contained needed
- [ ] Reference full protocols for detailed guidance
- [ ] Test skill execution works correctly

**After creation:**
- [ ] Measure token usage (target: 100-300 if delegating, 800-1,500 if full)
- [ ] Verify no double-loading with agents
- [ ] Document skill's context loading strategy

### When Creating New Rule

**Before creating:**
- [ ] Is this always-on, path-conditional, or specialized?
- [ ] Will it be needed in >80% of sessions? (If no → path-conditional)
- [ ] Is it specific to file types? (If yes → path-conditional)
- [ ] Is it agent-specific? (If yes → specialized/)

**During creation:**
- [ ] Add YAML frontmatter if path-conditional
- [ ] Use specific path patterns (not `**/*`)
- [ ] Place in specialized/ if agent-only
- [ ] Keep focused (target: 400-1,000 tokens unless comprehensive)

**After creation:**
- [ ] Test path-conditional loading works (if applicable)
- [ ] Verify placement (root vs specialized/)
- [ ] Measure token impact
- [ ] Update CLAUDE.md if always-on rule

### When Refactoring Existing Rule

**Assessment:**
- [ ] Current token count (measure baseline)
- [ ] Current loading tier (always-on, path-conditional, specialized)
- [ ] Actual usage pattern (how often loaded? in what contexts?)
- [ ] Opportunity for extraction (any reusable subsections?)

**Optimization:**
- [ ] Can this be path-conditional instead of always-on?
- [ ] Can subsections be extracted for agents?
- [ ] Is any content duplicated elsewhere?
- [ ] Can examples be trimmed without losing clarity?

**Verification:**
- [ ] Measure new token count
- [ ] Test functionality preserved
- [ ] Update all references
- [ ] Document changes in version history

---

## Framework-Specific Considerations

### Scaffolding Rules (Always-On)

**Current rules:**
- error-recovery.md (~2,500 tokens)
- grounding-protocol.md (~2,100 tokens)
- request-handling.md (~2,700 tokens)
- scope-detection.md (~3,200 tokens)

**Why larger than budget:**
- Comprehensive (self-contained documentation)
- Includes examples (critical for clarity)
- Decision trees and tables (scannable)

**Should you optimize?**

**No, if:**
- They're frequently referenced
- Examples are essential for understanding
- Self-contained documentation is valuable
- Current total startup cost (~1,830) is acceptable

**Yes, if:**
- Token budget becomes constrained
- Notice context confusion from too much guidance
- Can extract examples to separate file

**How to optimize if needed:**
1. Extract examples to `.claude/docs/scaffolding-examples.md`
2. Keep core protocol concise in rule files
3. Reference examples file for detailed cases

### Quality Rubrics (Path-Conditional)

**quality-rubrics.md** (~3,200 tokens)

**Already optimized:**
- ✓ Path-conditional (only loads for code/documents)
- ✓ Comprehensive (5 work types with examples)
- ✓ Zero cost for planning/meta-work sessions

**Potential optimization:**
- Split by work type if token budget tight:
  - quality-rubrics-r.md (R only)
  - quality-rubrics-python.md (Python only)
  - quality-rubrics-latex.md (LaTeX only)
  - quality-rubrics-quarto.md (Quarto only)
  - quality-rubrics-analysis.md (Analysis scripts only)
- More granular path matching
- Trade-off: More files vs more specific loading

**Recommendation:** Keep unified for now. Only split if experiencing issues.

### Decision Frameworks (Path-Conditional)

**decision-frameworks.md** (~3,200 tokens)

**Already optimized:**
- ✓ Path-conditional (code files only)
- ✓ Decision trees (scannable)
- ✓ Quick reference tables

**Potential optimization:**
- Could be split into separate frameworks:
  - code-organization.md
  - testing-strategy.md
  - documentation-levels.md
  - tool-selection.md
- Trade-off: Unified reference vs granular loading

**Recommendation:** Keep unified. Decision frameworks benefit from seeing all decisions together.

---

## Token Budget Monitoring

### Current Framework Status

**Tier 1 (Always-On):**
```
CLAUDE.md:                    ~470 tokens
plan-first-workflow.md:       ~560 tokens
MEMORY.md:                    ~800 tokens
────────────────────────────────────────
Total:                       ~1,830 tokens
Target:                    1,500-2,000 tokens
Status:                              ✓ Good
```

**Tier 2 (Path-Conditional - Scaffolding):**
```
error-recovery.md:          ~2,500 tokens (when loaded)
grounding-protocol.md:      ~2,100 tokens (when loaded)
request-handling.md:        ~2,700 tokens (when loaded)
scope-detection.md:         ~3,200 tokens (when loaded)
────────────────────────────────────────
Potential max add:         ~10,500 tokens
Target per rule:            600-800 tokens
Status:             ⚠️ Comprehensive but large
```

**Note:** These never all load at once (they're always-on but not all needed simultaneously). Actual impact depends on which scaffolding rules are being used.

**Tier 2 (Path-Conditional - Type-Specific):**
```
quality-rubrics.md:         ~3,200 tokens (when R/Python/LaTeX/Quarto matched)
decision-frameworks.md:     ~3,200 tokens (when code files matched)
exploration-fast-track.md:    ~980 tokens (when explorations/ matched)
────────────────────────────────────────
Max for single session:     ~6,400 tokens (if coding in explorations/)
Target per rule:          400-3,000 tokens (varies by comprehensiveness)
Status:                              ✓ Good
```

### When to Optimize

**Trigger optimization if:**
- Startup cost exceeds 2,500 tokens (currently 1,830 ✓)
- Single session total exceeds 15,000 tokens
- Notice context confusion (irrelevant guidance interfering)
- Agents/skills are slow to invoke

**Current status:** Framework is well-optimized. No immediate action needed.

**Future monitoring:**
- Check startup cost after adding new always-on rules
- Measure actual session totals (startup + path-matched)
- User feedback on context relevance

---

## Examples

### Example 1: Optimizing Review Skill

**Before:**
```markdown
---
name: review-paper
---

# Review Paper Skill

Load RESEARCH_CONSTITUTION.md, load domain-review-principles,
perform review following constitution §9 invariants.

Process paper, check invariants, generate report.
```

**Token cost:** ~4,000 tokens (constitution + principles + review logic)

**After:**
```markdown
---
name: review-paper
disable-model-invocation: true
allowed-tools: ["Agent"]
---

# Review Paper Skill

Parse file path from $ARGUMENTS.
Invoke domain-reviewer agent with task.
Display agent summary.
```

**Token cost:** ~200 tokens (skill) + ~1,000 tokens (agent loads own context)

**Savings:** ~2,800 tokens, prevents double-loading

### Example 2: Making Rule Path-Conditional

**Before:**
```markdown
# r-code-conventions.md (no YAML frontmatter)
# Always loads at startup
# Cost: ~1,500 tokens every session
```

**After:**
```yaml
---
paths:
  - "**/*.R"
  - "R/**"
  - "tests/**"
---

# R Code Conventions
[content unchanged]
```

**Savings:** 1,500 tokens for non-R sessions (LaTeX, planning, meta-work)

### Example 3: Extracting Relevant Sections

**Before:**
```markdown
# Agent loads: meta-spec/RESEARCH_CONSTITUTION.md (122 lines)
# Needs: Only §9 (quality invariants, 30 lines)
# Cost: ~3,000 tokens
```

**After:**
```markdown
# Create: .claude/rules/specialized/quality-invariants.md
# Content: Extracted §9 from constitution
# Agent loads: quality-invariants.md
# Cost: ~750 tokens
```

**Savings:** 2,250 tokens per agent invocation

---

## Maintenance

### Monthly Review

**Checklist:**
- [ ] Measure current startup cost (target: <2,000 tokens)
- [ ] Check for new always-on rules (should they be path-conditional?)
- [ ] Review MEMORY.md size (target: <100 lines)
- [ ] Identify any duplicated context across rules
- [ ] Check path patterns are specific (not too broad)

### When Adding New Rules

**Decision tree:**
```
New rule needed
    ↓
Needed in >80% of sessions?
    ↓
   YES → Always-on (no YAML frontmatter)
    │     Warning: Increases startup cost
    │     Consider: Can it be path-conditional instead?
    ↓
   NO → Specific to file types?
        ↓
       YES → Path-conditional (add paths: frontmatter)
        │
       NO → Agent-specific?
            ↓
           YES → Specialized/ directory
            │
           NO → Re-evaluate need for rule
```

### When Splitting Rules

**Trigger:** Rule exceeds 4,000 tokens (~16 KB) and has distinct sections

**Process:**
1. Identify natural split points (by topic, work type, etc.)
2. Create separate files with appropriate path patterns
3. Update cross-references
4. Test that all paths load correctly
5. Document split in version history

**Example:**
```markdown
# If quality-rubrics.md grows too large:
quality-rubrics.md → Split into:
  - quality-rubrics-code.md (R, Python)
  - quality-rubrics-documents.md (LaTeX, Quarto)
  - quality-rubrics-analysis.md (Analysis scripts)

Each with specific paths: frontmatter
```

---

## See Also

- `.claude/ARCHITECTURE.md` - Three-tier context model overview
- `.claude/rules/memory-curation.md` - Keeping MEMORY.md under 100 lines
- `.claude/rules/meta-governance.md` - What belongs in repo vs local
- `quality_reports/plans/2026-03-31_context-refactoring.md` - Original refactoring plan

---

## Version History

- **2026-04-02**: Initial version - practical optimization guide adapted from RAND repo patterns
