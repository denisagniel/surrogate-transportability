# Workflow Quick Reference

**Model:** Contractor (you direct, the agent orchestrates)

---

## The Loop

```
Your instruction
    ↓
[PLAN] (if multi-file or unclear) → Show plan → Your approval
    ↓
[EXECUTE] Implement, verify, done
    ↓
[REPORT] Summary + what's ready
    ↓
Repeat
```

---

## I Ask You When

- **Design forks:** "Option A (fast) vs. Option B (robust). Which?"
- **Code ambiguity:** "Spec unclear on X. Assume Y?"
- **Replication edge case:** "Just missed tolerance. Investigate?"
- **Scope question:** "Also refactor Y while here, or focus on X?"

---

## I Just Execute When

- Code fix is obvious (bug, pattern application)
- Verification (tolerance checks, tests, compilation)
- Documentation (logs, commits)
- Plotting (per established standards)
- Deployment (after you approve, I ship automatically)

---

## Quality Gates (No Exceptions)

| Score | Action |
|-------|--------|
| >= 80 | Ready to commit |
| < 80  | Fix blocking issues |

---

## Project Types

See [meta-spec/PROJECT_TYPES.md](meta-spec/PROJECT_TYPES.md). Four project types: Methods paper | Applied stats (full or partial) | Applied medical/subject (full or partial) | Grant writing. **Preprints:** Methods papers yes; applied/partial often not; see `.claude/rules/preprint-protocol.md` and `templates/project-types/preprint-checklist.md`.

---

## Non-Negotiables (agent-assisted-research-meta)

- **Authority:** [meta-spec/RESEARCH_CONSTITUTION.md](meta-spec/RESEARCH_CONSTITUTION.md) and meta-spec are authoritative. All methods, claims, and outputs must align with the research constitution. See `.claude/rules/constitution-alignment.md`.
- **Path convention:** R: `here::here()`; paths relative to project root. See project spec or MEMORY.md if different.
- **Seed convention:** `set.seed()` once at top of stochastic scripts; document in README or specs.
- **Figure standards:** Publication-ready: 300 DPI or vector (PDF/SVG) for journal submission when applicable; white background unless project specifies otherwise; see RESEARCH_CONSTITUTION and project-type template.
- **R figures:** RAND house style via randplot (`theme_rand()`, `RandCatPal`, `RandGrayPal`); save vector (PDF or SVG) for paper figures. See [.claude/rules/r-code-conventions.md](.claude/rules/r-code-conventions.md).
- **Tolerance thresholds:** Document in project specs or MEMORY.md (e.g., 1e-6 for point estimates).
- **LaTeX:** Use shared style from latex-dotfiles; set `LATEX_DOTFILES` to that path (e.g. in shell profile or `.env`). See [meta-spec/LATEX_SETUP.md](meta-spec/LATEX_SETUP.md).
- **LaTeX papers:** `/compile-latex` (e.g. `latex` or `main`). **Slides:** Quarto only — `quarto render` in `slides/` or `presentation/`.

---

## Preferences

**Visual:** Publication-ready figures; polish over speed. See RESEARCH_CONSTITUTION and project-type template.
**Reporting:** Concise bullets for status; detailed prose when needed for decisions or documentation.
**Session logs:** Always (post-plan, incremental, end-of-session). Also update project `session_notes/YYYY-MM-DD.md` (what/why/remaining); feeds daily notes at `$AGENT_ASSISTED_RESEARCH_META_NOTES`.
**Replication:** Strict; flag near-misses. Reproducibility is infrastructure (constitution).

---

## Exploration Mode

For experimental work, use the **Fast-Track** workflow:
- Work in `explorations/` folder
- 60/100 quality threshold (vs. 80/100 for production)
- No plan needed — just a research value check (2 min)
- See `.claude/rules/exploration-fast-track.md`

---

## Next Step

You provide task → I plan (if needed) → Your approval → Execute → Done.
