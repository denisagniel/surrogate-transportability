---
paths:
  - "explorations/**"
---

# Exploration Fast-Track

**Purpose:** Lightweight workflow for experimental work in the explorations/ folder

---

## Core Principle

**Explorations are for learning, not production.** Lower quality bar enables faster experimentation.

Why:
- Reduce friction for "what if?" questions
- Enable rapid prototyping
- Allow dead-end exploration without guilt
- Learn through doing, not planning

**Quality threshold: 60/100** (vs 80/100 for production code)

---

## When to Use

Use exploration fast-track when:
- Testing new ideas or approaches
- Prototyping before committing to full implementation
- Learning new tools or techniques
- Investigating feasibility ("Can this even work?")
- Exploring data before formal analysis

**Don't use when:**
- Code will go into production (R package, analysis pipeline)
- Results will be in paper/grant
- Others will depend on this code
- You need reproducibility guarantees

**Rule:** If it might become production code, start at 80/100 standard.

---

## The Fast-Track Protocol

### Step 1: Research Value Check (2 minutes)

Ask: **"Will this improve the project if it works?"**

- YES → Proceed
- NO → Don't build it (avoid busywork)

This is the only gate. If it has value, explore it.

### Step 2: Create Exploration Folder

**Structure:**
```
explorations/YYYY-MM-DD_description/
├── README.md              # Goal, approach, status
├── SESSION_LOG.md         # Progress notes (append as you work)
├── R/ or scripts/         # Code
├── output/                # Results
└── notes/                 # Scratch notes (optional)
```

**README.md template:**
```markdown
# [Short Description]

**Goal:** What are you trying to learn/test?

**Approach:** How will you test it?

**Status:** [In Progress / Completed / Archived]

## Results

[What you learned]

## Decision

[Keep exploring / Graduate to production / Archive]
```

### Step 3: Code Immediately (No Planning)

**Just start coding.** No plan needed.

**60/100 minimum requirements:**
- [ ] Code runs without errors on intended inputs
- [ ] Results are correct (not buggy)
- [ ] Goal is documented in README.md

**NOT required at 60/100:**
- Documentation (roxygen2, docstrings)
- Tests (beyond smoke testing)
- Error handling for edge cases
- Code style/formatting perfection
- Optimization
- Generalization

**What this means:**
- Quick-and-dirty is fine
- Hardcoded values are fine (document them)
- Messy code is fine (as long as it works)
- Copy-paste is fine (refactor later if promoting)
- No tests needed (unless testing is the point)

### Step 4: Log Progress (Lightweight)

Append 2-3 lines to SESSION_LOG.md as you work:

```markdown
## 2026-04-02 10:30

Tested approach X with dataset Y. Found Z. Next: try W.

## 2026-04-02 14:15

Approach X works but slow. Trying approach V instead.
```

**Purpose:** Capture what you learned, not detailed documentation.

### Step 5: Decision Point

When exploration concludes, decide:

**Option A: Keep Exploring**
- More to learn
- Update README status: "In Progress"
- Continue iterating

**Option B: Graduate to Production**
- Works well, want to use in production
- Upgrade to 80/100 standard (add tests, docs, error handling)
- Move code to appropriate location (R/, analysis/, etc.)
- Archive exploration folder with note: "Graduated to [location]"

**Option C: Archive**
- Dead end, didn't work, not worth pursuing
- Update README status: "Archived"
- Add brief "## Why Archived" section (1-3 sentences)
- Move folder to `explorations/archive/` or leave in place with clear status

**No guilt on archiving.** Explorations are inherently uncertain.

---

## Kill Switch

**At any point:** Stop, archive with note, move on.

If you hit a blocker:
1. Update README: Status = "Archived"
2. Add section: "## Why Archived: [1-3 sentence explanation]"
3. Move on to next task

**Examples of valid reasons to kill:**
- "Approach requires data we don't have"
- "Performance is 100× too slow, not feasible"
- "Already implemented in existing package"
- "Method assumptions violated by our data"

**Exploration failures are learning.** Document what you learned and move on.

---

## Quality Comparison

| Aspect | Production (80/100) | Exploration (60/100) |
|--------|---------------------|----------------------|
| **Runs correctly** | ✅ Required | ✅ Required |
| **Documentation** | ✅ Full roxygen2/docstrings | ❌ Not required |
| **Tests** | ✅ Happy path + edge cases | ❌ Not required |
| **Error handling** | ✅ Edge cases handled | ❌ Only obvious cases |
| **Code style** | ✅ Follows conventions | ⚠️ Readable is enough |
| **Optimization** | ✅ Performant | ❌ "Good enough" speed |
| **Generalization** | ✅ Works for various inputs | ❌ Works for test case |

---

## Examples

### Example 1: Testing New Estimator

**Goal:** See if method X works on our data

**Fast-track approach:**
```r
# explorations/2026-04-02_test-method-x/R/test.R

# Quick implementation - no error handling
estimate_x <- function(y, z) {
  # Hardcoded for test dataset
  n <- 100
  result <- some_calculation(y, z, n)
  return(result)
}

# Run on test data
data <- load_test_data()
result <- estimate_x(data$y, data$z)
print(result)

# Works! Coverage is 0.94, close to nominal 0.95
# Next: test with larger n
```

**Decision:** Works! Graduate to production (upgrade to 80/100).

### Example 2: Exploring Visualization Approach

**Goal:** Find best way to visualize complex results

**Fast-track approach:**
```r
# explorations/2026-04-02_viz-ideas/R/plots.R

# Try 3 approaches quickly
library(ggplot2)

# Approach 1: Faceted
ggplot(data) + geom_point() + facet_wrap(~group)
# Too cluttered

# Approach 2: Colored
ggplot(data) + geom_point(aes(color = group))
# Better but hard to distinguish

# Approach 3: Small multiples with annotations
# [... code ...]
# This works!
```

**Decision:** Keep approach 3, implement properly in analysis/ with 80/100 standard.

### Example 3: Dead End

**Goal:** Use package X for faster computation

**Fast-track approach:**
```r
# explorations/2026-04-02_test-package-x/R/test.R

library(packageX)

# Try basic usage
result <- packageX::fast_function(data)
# Error: package expects different data format

# Try reformatting
formatted_data <- reformat(data)
result <- packageX::fast_function(formatted_data)
# Error: package doesn't support our use case
```

**README - Why Archived:**
"Package X doesn't support our data structure (needs matrix, we have list). Reformatting would negate performance gains. Not pursuing further."

**Decision:** Archive. Learned that package X won't work for us.

---

## Integration with Main Workflow

### When Exploration Graduates

If promoting to production:

1. **Create plan** for upgrading to 80/100
   - Add documentation
   - Add tests
   - Add error handling
   - Refactor for production use

2. **Move code** to appropriate location:
   - R package code → `R/`
   - Analysis scripts → `analysis/`
   - Simulation code → `simulations/`

3. **Archive exploration** with note:
   ```markdown
   Status: Graduated to production

   Code moved to: R/method_x.R
   Tests added to: tests/testthat/test-method-x.R
   See: quality_reports/plans/2026-04-02_productionize-method-x.md
   ```

### When to Skip Fast-Track

If you know the code will be production (paper results, package code), start at 80/100:
- Follow plan-first workflow
- Write tests as you go
- Document properly from start

**Fast-track is for exploration only**, not for shortcuts on production work.

---

## Anti-Patterns

❌ **Don't use fast-track to avoid quality standards**
```
"This code is messy but I'll call it an 'exploration'"
→ If it's going in the paper, it's production work
→ Use 80/100 standard
```

❌ **Don't let explorations sit indefinitely**
```
Status: "In Progress" for 3 months
→ Make decision: graduate, archive, or keep exploring with timeline
```

❌ **Don't commit exploration code directly to production**
```
Copy from explorations/ to R/ without upgrading quality
→ Upgrade to 80/100 first (tests, docs, error handling)
```

✅ **Do treat explorations as learning**
```
Try idea → Learn → Decide → Archive or graduate
→ Clean decision process
```

---

## Quick Reference

### Quality Threshold

| | Production | Exploration |
|---|---|---|
| **Threshold** | 80/100 | 60/100 |
| **Planning** | Required for substantial tasks | Not required |
| **Tests** | Required | Optional |
| **Documentation** | Required | Goal in README only |

### Decision Framework

```
Exploration complete
    ↓
Did it work?
    ↓
   YES → Want to use in production?
    │       ↓
    │      YES → Graduate (upgrade to 80/100)
    │       ↓
    │      NO → Archive (note what learned)
    ↓
   NO → Archive (note why didn't work)
```

### File Structure

```
explorations/YYYY-MM-DD_description/
├── README.md         # Goal, status, decision
├── SESSION_LOG.md    # Progress notes
├── R/ or scripts/    # Code
└── output/          # Results
```

---

## See Also

- `.claude/rules/quality-philosophy.md` - Why quality matters (but exploration is exception)
- `.claude/rules/quality-rubrics.md` - 80/100 standards for production code
- `.claude/rules/plan-first-workflow.md` - For production work (explorations skip this)
- `templates/exploration-readme.md` - README template for explorations

---

## Version History

- **2026-04-02**: Expanded from minimal version - full protocol, examples, anti-patterns, quality comparison table
- **2026-02-16**: Initial minimal version - basic fast-track steps
