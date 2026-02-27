# Constitutional Governance Template

**Define your immutable principles vs. user preferences.**

---

## Why Constitutional Governance?

As projects grow, some decisions become non-negotiable (to maintain quality, reproducibility, or collaboration standards). Others remain flexible based on context.

Making this distinction explicit prevents:
- Repeated debates on settled issues
- Inconsistent application of standards
- Uncertainty about when to ask vs. decide

---

## Authority

Constitutional governance aligns with and does not override [meta-spec/RESEARCH_CONSTITUTION.md](meta-spec/RESEARCH_CONSTITUTION.md). Project types are defined in [meta-spec/PROJECT_TYPES.md](meta-spec/PROJECT_TYPES.md) (Methods, Applied Statistics, Medical/Subject, Grant). When copying this template into a project, choose the type(s) that apply.

---

## How to Use This Template

1. Copy this file to `.claude/rules/constitutional-governance.md`
2. Replace bracketed examples with YOUR non-negotiables (or keep the pre-filled versions if using agent-assisted-research-meta)
3. Delete articles that don't apply to your workflow
4. Add new articles as patterns emerge
5. Keep it to 3-7 articles (more signals insufficient abstraction)

If using in agent-assisted-research-meta or a child project, the pre-filled "Your version" below matches the research constitution and quality gates.

---

## Example Articles (Customize for Your Domain)

### Article I: [Your Primary Artifact Principle]

**Example (LaTeX workflows):** Beamer `.tex` is authoritative; Quarto `.qmd` derives from it.

**Example (R workflows):** Analysis scripts are authoritative; reports derive from them.

**Example (Jupyter workflows):** Notebooks are authoritative; exported HTML derives from them.

**Example (multi-format):** Source documents (`.qmd`, `.Rmd`) are authoritative; all outputs (HTML, PDF, Word) derive from them.

**Why this matters:** Prevents circular dependencies and merge conflicts.

**Your version:** Source documents (`.qmd`, `.Rmd`) are authoritative; all outputs (HTML, PDF, Word) derive from them. For Methods/Applied: analysis scripts and literate sources are authoritative; reports and slides derive from them.

---

### Article II: Plan-First Threshold

Enter plan mode for tasks requiring multiple files, multi-step workflows, or non-trivial scope.

**Why this matters:** Prevents mid-implementation pivots and wasted effort.

**Your exceptions:** Exploration folder allows fast-track; quick fixes and single-file edits may skip planning; see exploration-folder-protocol.

**Your version:** Enter plan mode for tasks requiring multiple files, multi-step workflows, or non-trivial scope. Exceptions: exploration folder allows fast-track; quick fixes and single-file edits may skip planning.

---

### Article III: Quality Gate

Nothing commits below 80/100; PR-ready at 90; excellence at 95.

**Why this matters:** Technical debt accumulates exponentially below quality thresholds.

**Your exceptions:** WIP branches marked as such; exploratory work in explorations/ or sandbox; draft commits tagged.

**Your version:** Nothing commits below 80/100; PR-ready at 90; excellence at 95. Exceptions: WIP branches marked as such; exploratory work in explorations/ or sandbox; draft commits tagged.

---

### Article IV: Verification Standard

All artifacts must compile/render (or pass tests) before commit where applicable.

**Why this matters:** Broken builds block downstream work and collaboration.

**Your exceptions:** Known issues documented in README; explicit skip with justification; explorations/ may use lighter verification.

**Your version:** All artifacts must compile/render (or pass tests) before commit where applicable. Exceptions: known issues documented in README; explicit skip with justification; explorations/ may use lighter verification.

---

### Article V: [Your File Organization Principle]

**Example (structured projects):** Never scatter analysis docs; use `quality_reports/session_logs/` for all session documentation.

**Example (notebook users):** One notebook per analysis; no code duplication across notebooks; shared functions go in modules.

**Example (multi-language):** Language-specific subdirectories (`R/`, `python/`, `julia/`); no mixed-language files.

**Example (literate programming):** All code lives in `.qmd` or `.Rmd` files; extracted `.R` scripts are derived artifacts.

**Why this matters:** Consistent structure enables navigation, collaboration, and automated tooling.

**Your exceptions:** scratch/ or _archive/ for legacy; project-types may add type-specific dirs.

**Your version:** Session logs in quality_reports/session_logs/; plans in quality_reports/plans/; explorations in explorations/; no scattering of analysis docs. Exceptions: scratch/ or _archive/ for legacy; project-types may add type-specific dirs.

---

## User Preferences (Override Anytime)

List patterns that ARE flexible and can vary by context:

- By project type: citation/format by target journal (Methods vs medical); plot/table style by outlet; review-agent order (e.g., domain vs structure first) by project type.
- File naming conventions (snake_case vs camelCase vs kebab-case)
- Tolerance thresholds for numerical comparisons (1e-6 vs 1e-8)
- Review agent priority order (pedagogy-first vs code-quality-first)
- Comment verbosity (minimal vs detailed)
- Plot color schemes (institutional vs publication-ready vs colorblind-safe)
- Citation style (APA vs Chicago vs domain-specific)

---

## Requesting Amendment

When a user asks to deviate from an article, ask:

> "Are you **amending Article X** (permanent change) or **overriding for this task** (one-time exception)?"

This preserves institutional memory while allowing flexibility.

**Amendment process:**
1. User proposes amendment with rationale
2. Discuss implications (what breaks? what improves?)
3. Update this file if amendment approved
4. Document the change in session log with [CONSTITUTIONAL AMENDMENT] tag

---

## When NOT to Use Articles

Don't create articles for:

- **Personal preferences** that don't affect collaboration or reproducibility
- **One-off decisions** unlikely to recur
- **Patterns still evolving** (wait until they stabilize across 3+ uses)
- **External constraints** (imposed by journals, funders, collaborators)

---

## Examples by Project Type

Constitutional-level articles or emphases to consider when a project adopts governance. See [meta-spec/PROJECT_TYPES.md](meta-spec/PROJECT_TYPES.md) and the requirements templates in `templates/project-types/` for full checklists.

### Methods / Causal Inference

- **Replication-first:** Empirical claims must have accompanying scripts; code and paper in agreement.
- **Stress-testing:** Simulations include regimes where the method should struggle; failure modes documented.
- **Software invariants:** UQ unless justified; safe defaults; APIs reflect statistical structure. Proof/writing invariants when applicable (assumptions explicit, no causal language without assumptions nearby).

### Applied Statistics

- Same replication and simulation spirit as Methods.
- **Strong application and data provenance:** Data source, date, and processing steps documented; match claims to evidence.
- **Evidence hierarchy:** Conceptual clarity and evidence-of-impact in every project; identification and theory where responsible for the method.

### Applied (Medical / Subject-Matter)

- **Clarity and audience:** Takeaway clear for intended audience; limitations stated.
- **Scope of responsibility:** Full vs partial (e.g., methods + results only)—scope claims to what your contribution supports; communication standards from research constitution §8.
- **Evidence strength:** Match strength of claim to strength of evidence; do not overstate generalizability.

### Grant Writing

- **Aims and significance:** Sharply stated and aligned with funder priorities; decision relevance and impact clear.
- **Approach and feasibility:** Methods, rationale, team, timeline, milestones; budget consistent with scope.
- **Review-criteria alignment:** Address the funder’s review criteria explicitly.

---

## Maintenance

**Review cadence:** Quarterly (or after every 10 sessions)

**Review questions:**
- Are all articles still relevant?
- Are any being violated repeatedly? (If yes, amend or delete)
- Are any new patterns emerging? (If yes, consider promoting to article)
- Are articles enabling or obstructing work?

---

## Template Checklist

Before finalizing your constitutional governance:

- [ ] 3-7 articles (not more)
- [ ] Each article has: principle, why it matters, your version, exceptions
- [ ] User preferences section populated with flexible patterns
- [ ] Authority and project-type sections reflect RESEARCH_CONSTITUTION and PROJECT_TYPES
- [ ] Amendment process understood
- [ ] Review cadence scheduled
- [ ] File saved to `.claude/rules/constitutional-governance.md`
