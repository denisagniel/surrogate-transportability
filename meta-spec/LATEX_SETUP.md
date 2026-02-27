# LaTeX style (latex-dotfiles)

LaTeX-using projects should use your shared style from **latex-dotfiles** so `\input` and `\usepackage` resolve your preambles and style files.

- **Set the path:** Use the environment variable `LATEX_DOTFILES` pointing to your latex-dotfiles repo or directory (e.g. `export LATEX_DOTFILES=~/latex-dotfiles` in your shell profile or in a project `.env`).
- **Compilation:** The compile-latex skill and verifier prepend `$LATEX_DOTFILES` to `TEXINPUTS` when it is set, so compilation finds your style. If `LATEX_DOTFILES` is not set, compilation still works with project-local paths (e.g. `Preambles/`) only. Papers can load the house style with `\input{house-style}` (XeLaTeX; Crimson Pro, 0.75 in margins).
- **On a new machine:** Clone or symlink your latex-dotfiles repo and set `LATEX_DOTFILES` to that path.

**Tools:** Quarto for slides (paper slides in `slides/` or `presentation/`); LaTeX for papers (`latex/` or project root). See [.claude/WORKFLOW_QUICK_REF.md](../.claude/WORKFLOW_QUICK_REF.md) (LaTeX bullet) and [.claude/skills/compile-latex/SKILL.md](../.claude/skills/compile-latex/SKILL.md) for details.
