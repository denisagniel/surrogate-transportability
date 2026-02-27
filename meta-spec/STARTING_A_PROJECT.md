# Starting a Project

How to start a **new** project (clone + first-run-prompt) or bring an **existing** project under the agent-assisted-research-meta workflow. See also [PROJECT_TYPES.md](PROJECT_TYPES.md) for project-type templates.

---

## 1. New project (clone + first-run-prompt)

- Keep **agent-assisted-research-meta** as your private GitLab repo.
- When starting a **new** project: clone agent-assisted-research-meta into the new project directory, e.g.  
  `git clone git@code.rand.org:ai-tools1/agent-assisted-research-meta.git <new-project-name>`  
  (That URL is the maintainer's repo; use your own fork or clone URL if you adopted this template.)
- Open the cloned project in your AI coding environment (e.g. Claude Code, Cursor), start a new conversation or chat, and use [templates/first-run-prompt.md](../templates/first-run-prompt.md): fill in `[PROJECT NAME]`, 2–3 sentence description, and tools (e.g. LaTeX/Beamer, R, Quarto).
- The agent adapts the config to that project (CLAUDE.md, rules, project-type) and enters plan mode. After you approve, work proceeds with plan-first workflow.
- Create `session_notes/` at project root (and optionally a one-line README there: "Session notes here feed daily notes. Meta-project notes at $AGENT_ASSISTED_RESEARCH_META_NOTES; see meta-spec/META_PROJECT_NOTES.md.").

---

## 2. Existing project (copy in workflow + existing-project-prompt)

- For a project you've **already** started (separate repo, existing files): copy the workflow files from agent-assisted-research-meta into that project **without** overwriting existing content:
  - `CLAUDE.md`
  - `.claude/` (rules, skills, agents, hooks, WORKFLOW_QUICK_REF.md, settings.json)
  - `templates/`
  - `meta-spec/RESEARCH_CONSTITUTION.md` (and optionally `meta-spec/background.md`)
- Open the project in your AI coding environment, start a new conversation or chat, and use [templates/existing-project-prompt.md](../templates/existing-project-prompt.md). The agent adapts config to the existing project, respects current structure, and proposes integration (e.g. where to put `quality_reports/`, `session_notes/`).
- Create `session_notes/` at project root if missing (and optionally a one-line README there: "Session notes here feed daily notes. Meta-project notes at $AGENT_ASSISTED_RESEARCH_META_NOTES; see meta-spec/META_PROJECT_NOTES.md.").
- The existing project keeps its own git remote; it does not become a clone of agent-assisted-research-meta.

---

## 3. LaTeX

LaTeX-using projects: set up shared style from latex-dotfiles. See [LATEX_SETUP.md](LATEX_SETUP.md).
