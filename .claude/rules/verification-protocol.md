---
paths:
  - "latex/**/*.tex"
  - "proposal/**/*.tex"
  - "grants/**/*.tex"
  - "slides/**/*.qmd"
  - "presentation/**/*.qmd"
  - "Quarto/**/*.qmd"
  - "docs/**"
---

# Task Completion Verification Protocol

**At the end of EVERY task, the agent MUST verify the output works correctly.** This is non-negotiable.

## For LaTeX papers (non-Beamer — e.g. latex/main.tex or root main.tex):
1. From the directory containing the main .tex (e.g. `latex/` or project root), compile with xelatex. Use TEXINPUTS that includes latex-dotfiles when `LATEX_DOTFILES` is set (see meta-spec/LATEX_SETUP.md and the verifier agent).
2. Run bibtex if the project uses citations; run xelatex twice more (or use latexmk).
3. Check for errors, overfull hbox, undefined citations; verify PDF exists.

## For LaTeX proposals (grants):
1. Same as LaTeX papers: from the directory containing the main .tex (e.g. `proposal/` or `grants/`), compile with xelatex; run bibtex if citations are used; run xelatex twice more (or use latexmk).
2. Check for errors, overfull hbox, undefined citations; verify PDF exists.
3. If the project uses the grant-requirements template, confirm required sections (Aims, Significance, Approach, etc.) are present in the source.

## For Quarto/HTML slides (paper slides Quarto only):
1. **Paper slides are Quarto only.** From `slides/` or `presentation/` run `quarto render` and verify output. If project has `scripts/sync_to_docs.sh` (teaching): run it; verify HTML in `docs/slides/`.
2. Open the HTML in browser to confirm display
3. Check for render warnings

## For TikZ / SVG diagrams (when used in Quarto):
1. Browsers cannot display PDF images inline — use SVG for diagrams in HTML
2. Verify TikZ/SVG source is current when diagrams are used in Quarto; recompile or re-extract when source changes

## For R Scripts:
1. Run `Rscript scripts/R/filename.R`
2. Verify output files (PDF, RDS/parquet as applicable) were created with non-zero size
3. Spot-check estimates for reasonable magnitude

## Common Pitfalls:
- **PDF images in HTML**: Browsers don't render PDFs inline → convert to SVG
- **Relative paths**: `../Figures/` works from `Quarto/` but not from `docs/slides/` → use `sync_to_docs.sh`
- **Assuming success**: Always verify output files exist AND contain correct content
- **Stale TikZ/SVG**: if using standalone .tex or extracted SVGs for Quarto, ensure output matches current source

## Verification Checklist:
```
[ ] Output file created successfully
[ ] No compilation/render errors
[ ] Images/figures display correctly
[ ] Paths resolve in deployment location (docs/)
[ ] Opened in browser/viewer to confirm visual appearance
[ ] Reported results to user
```
