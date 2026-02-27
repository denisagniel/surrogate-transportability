# Meta-Governance: Agent-Assisted-Research-Meta as Personal Meta-Workflow

**This repository is your master workflow repo.** It governs how you work across project types. Deciding what to commit here vs what stays local keeps the repo useful and portable.

---

## What to Commit vs What Stays Local

### Commit to repo (syncs across machines and cloned projects)

- **Workflow patterns** — Plan-first, spec-then-plan, quality gates, project-type templates. Goes in MEMORY.md as [LEARN] entries when refined.
- **Templates** — requirements-spec, session-log, project-types, constitutional-governance. Live in `templates/`.
- **Rules, skills, agents, hooks** — In `.claude/`. Keep them framework-oriented so they work for any of your project types.
- **Plans and session logs** — `quality_reports/plans/`, `quality_reports/session_logs/` when that structure exists.
- **Meta-spec** — RESEARCH_CONSTITUTION, PROJECT_TYPES, background. Authoritative; commit amendments.

### Keep local (gitignored or machine-specific)

- **Machine setup** — Paths like `TEXINPUTS`, `LATEX_DOTFILES`, local bibliography paths. Use `.claude/state/personal-memory.md` (gitignored).
- **Tool versions / workarounds** — Quarto or R version quirks; local build commands. personal-memory.md.
- **API keys, credentials** — Never commit.
- **Project-specific overrides** — When you use a cloned agent-assisted-research-meta for a specific project, that project’s CLAUDE.md and specs hold project-specific choices; the clone is its own repo.

---

## Memory: Two Tiers

### MEMORY.md (root, committed)

**Purpose:** Learnings that apply across your workflow and project types.

**What goes here:** [LEARN:workflow], [LEARN:design], [LEARN:documentation], [LEARN:quality], [LEARN:governance], etc. — patterns that help in any project (e.g. spec-then-plan reduces rework; 80/90/95 thresholds).

**Size:** Keep under ~200 lines so it stays usable in context.

### .claude/state/personal-memory.md (gitignored)

**Purpose:** Machine-specific and private learnings.

**What goes here:** Local paths, tool quirks, machine-specific LaTeX or R setup, personal quality thresholds for specific project types.

---

## Dogfooding: Follow the Workflow Yourself

- **Plan-first:** Enter plan mode for non-trivial tasks; save plans to `quality_reports/plans/`.
- **Spec-then-plan:** For complex/ambiguous work, use requirements specs (MUST/SHOULD/MAY, clarity status) before drafting the plan.
- **Quality gates:** Nothing commits below 80/100; verify before commit.
- **Context survival:** Update MEMORY.md with [LEARN] after sessions; save active plans to disk; keep session logs current so context survives compression.

---

## Amendment Process

When meta-governance needs to change:

1. Propose change in session log or plan with rationale.
2. Update this file after you approve.
3. Document with [LEARN:meta-governance] in MEMORY.md if it affects how you use the repo.

---

## Quick Reference

| Content type              | Commit? | Where                          |
|---------------------------|--------|---------------------------------|
| Workflow learnings        | Yes    | MEMORY.md                      |
| Machine-specific setup    | No     | .claude/state/personal-memory.md |
| Templates, rules, skills  | Yes    | templates/, .claude/           |
| Plans, session logs       | Yes    | quality_reports/               |
| Meta-spec (constitution, PROJECT_TYPES) | Yes | meta-spec/            |
| Local settings / state    | No     | .claude/state/, settings.local.json |
