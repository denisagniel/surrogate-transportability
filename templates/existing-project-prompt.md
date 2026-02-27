This is an **existing** project I've already been working on. I've added my agent-assisted-research-meta workflow files (CLAUDE.md or your environment's agent-instruction file, .claude/, templates/, RESEARCH_CONSTITUTION). Adapt the configuration to **this** project: project name is [X], we're doing [Y], tools are [Z]. Do not overwrite or remove existing project structure or content; integrate the workflow with what's here.

If this project uses LaTeX, ensure compilation uses my shared style from latex-dotfiles (set `LATEX_DOTFILES` and prepend it to TEXINPUTS; see meta-spec/LATEX_SETUP.md).

Then enter plan mode and propose any project-specific tweaks (e.g. CLAUDE.md placeholders, which project-type template applies, where to put quality_reports/, session_notes/). Integrate session notes (project-root `session_notes/`, same triggers as session logs) so work is memorialized and daily notes can be built from them.
