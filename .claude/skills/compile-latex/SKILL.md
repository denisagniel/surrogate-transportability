---
name: compile-latex
description: Compile a LaTeX paper (manuscript) with XeLaTeX (3 passes + bibtex). Use when compiling papers (e.g. latex/main.tex or main.tex in project root). Not for slides — slides are Quarto only.
disable-model-invocation: true
argument-hint: "[path to main file or directory, e.g. latex, latex/main, main]"
allowed-tools: ["Read", "Bash", "Glob"]
---

# Compile LaTeX Paper

Compile a LaTeX manuscript using XeLaTeX with full citation resolution. For slides use `quarto render` in `slides/` or `presentation/` — this skill is for papers only.

## Steps

1. **Resolve directory and main file:**
   - If `$ARGUMENTS` is `latex` or `latex/main`: run from `latex/`; main file `main.tex` (or the only .tex in that dir).
   - If `$ARGUMENTS` is `main` or a basename: resolve in `latex/` first, then project root; main file `main.tex` or `$ARGUMENTS.tex`.
   - If path to a .tex file: use its directory and filename.

2. **From that directory**, run 3-pass sequence. Use TEXINPUTS and BIBINPUTS that include latex-dotfiles when `LATEX_DOTFILES` is set:

```bash
cd <resolved_directory>
TEXINPUTS="${LATEX_DOTFILES:+$LATEX_DOTFILES:}.:$TEXINPUTS" BIBINPUTS=".:$BIBINPUTS" xelatex -interaction=nonstopmode main.tex
BIBINPUTS=".:$BIBINPUTS" bibtex main
TEXINPUTS="${LATEX_DOTFILES:+$LATEX_DOTFILES:}.:$TEXINPUTS" BIBINPUTS=".:$BIBINPUTS" xelatex -interaction=nonstopmode main.tex
TEXINPUTS="${LATEX_DOTFILES:+$LATEX_DOTFILES:}.:$TEXINPUTS" BIBINPUTS=".:$BIBINPUTS" xelatex -interaction=nonstopmode main.tex
```

**Alternative (latexmk):** If the project has `.latexmkrc` in that directory:
```bash
cd <resolved_directory>
TEXINPUTS="${LATEX_DOTFILES:+$LATEX_DOTFILES:}.:$TEXINPUTS" BIBINPUTS=".:$BIBINPUTS" latexmk -xelatex -interaction=nonstopmode main.tex
```

3. **Check for warnings:** Grep for `Overfull \\hbox`, `undefined citations`, `Label(s) may have changed`. Report issues.

4. **Report results:** Compilation success/failure, overfull hbox count, undefined citations, PDF page count. Optionally open the PDF for visual verification.

## Why 3 passes?
1. First xelatex: Creates `.aux` with citation keys
2. bibtex: Generates `.bbl` with formatted references
3. Second xelatex: Incorporates bibliography
4. Third xelatex: Resolves cross-references and final page numbers

## Important
- **Always use XeLaTeX**, never pdflatex.
- **This skill is for LaTeX papers only.** For slides use `quarto render` in `slides/` or `presentation/`.
- **TEXINPUTS:** If `LATEX_DOTFILES` is set, it is prepended so the paper uses your shared LaTeX style. See [meta-spec/LATEX_SETUP.md](../../../meta-spec/LATEX_SETUP.md).
- **BIBINPUTS:** Set to the directory containing the main .tex (and .bib if in same dir) so citations resolve.
