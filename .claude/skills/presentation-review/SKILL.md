---
name: presentation-review
description: Multi-dimensional review of paper presentation slides (job talk, seminar, conference). Runs slide-auditor (visual/layout), proofreader (grammar and consistency), and optionally domain-reviewer (substance) and tikz-reviewer (if TikZ present). Produces per-agent reports and a combined summary.
disable-model-invocation: true
argument-hint: "[.qmd filename in slides/ or presentation/]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Task"]
---

# Presentation Review (Paper Slides)

Run a multi-dimensional review of **paper presentation slides** (Quarto .qmd in `slides/` or `presentation/`). Multiple agents analyze the file; results are synthesized into a combined summary.

## Steps

### 1. Identify the File

Parse `$ARGUMENTS` for the filename. Resolve path in `slides/`, `presentation/`, or project root.

### 2. Run Review Agents

**Agent 1: Visual / Layout** (slide-auditor)
- Overflow, font consistency, box fatigue, spacing, images
- Save: `quality_reports/[FILE]_visual_audit.md`

**Agent 2: Proofreading** (proofreader)
- Grammar, typos, consistency, academic quality, citations
- Save: `quality_reports/[FILE]_proofread_report.md`

**Agent 3: Substance** (optional — domain-reviewer)
- Domain correctness, derivation and citation fidelity
- Save: `quality_reports/[FILE]_substance_review.md`

**Agent 4: TikZ** (only if file contains TikZ)
- Label overlaps, geometric accuracy, visual semantics (tikz-reviewer)
- Save: `quality_reports/[FILE]_tikz_review.md`

### 3. Synthesize Combined Summary

Produce one combined report:

```markdown
# Presentation Review: [Filename]

## Overall: [EXCELLENT / GOOD / NEEDS WORK / POOR]

| Dimension     | Critical | Medium | Low |
|---------------|----------|--------|-----|
| Visual/Layout |          |        |     |
| Proofreading  |          |        |     |
| Substance     | (if run) |        |     |
| TikZ          | (if run) |        |     |

### Critical Issues (Immediate Action)
### Medium Issues (Next Revision)
### Recommended Next Steps
```

Save to: `quality_reports/[FILE]_presentation_review.md`
