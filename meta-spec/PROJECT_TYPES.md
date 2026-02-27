# Project Types

Project types supported by the agent-assisted-research-meta workflow. Use the matching template in `templates/project-types/` when starting or scoping a project.

---

## 1. Methods / Causal Inference

- **Target:** Top statistics/biostatistics journals.
- **Emphasis:** Identification, theory, stress-testing, software.
- **Template:** [templates/project-types/methods-paper-requirements.md](../templates/project-types/methods-paper-requirements.md)

---

## 2. Applied Statistics

- **Target:** Applied statistics outlets.
- **Emphasis:** Balance of method and application, more focus on simulation and strong application.
- **Template:** [templates/project-types/applied-paper-requirements.md](../templates/project-types/applied-paper-requirements.md)

---

## 3. Applied (Medical / Subject-Matter)

- **Target:** Top medical or subject-matter journals.
- **Emphasis:** Clarity, evidence strength, limitations, audience.
- **Scope:** Full paper or partial responsibility (e.g., methods + results). Both supported.
- **Template:** [templates/project-types/medical-subject-paper-requirements.md](../templates/project-types/medical-subject-paper-requirements.md)

---

## 4. Grant Writing

- **Target:** Funders (NIH, NSF, etc.).
- **Emphasis:** Aims, significance, approach, budget/timeline, review criteria.
- **Template:** [templates/project-types/grant-requirements.md](../templates/project-types/grant-requirements.md)

---

## Publication policy: Preprints

**Methods papers** are posted as preprints before or alongside journal submission. **Applied papers** (applied stats, medical/subject) probably will not get preprints; **partial-responsibility** papers definitely will not. When a project will post a preprint, confirm it meets the definition of finished (constitution §12) using [templates/project-types/paper-done-checklist.md](../templates/project-types/paper-done-checklist.md), then use the preprint protocol and checklist:

- **Rule:** [.claude/rules/preprint-protocol.md](../.claude/rules/preprint-protocol.md)
- **Checklist:** [templates/project-types/preprint-checklist.md](../templates/project-types/preprint-checklist.md)

---

## Adding a New Project Type

There are four project types. To add another:

1. Add a template under `templates/project-types/`.
2. Add one entry to this list (and to the Project types subsection in CLAUDE.md and WORKFLOW_QUICK_REF.md).
3. Optionally add a skill or rule for that type.
