---
name: proofread
description: Run the proofreading protocol on academic prose (papers and research presentation slides). Checks grammar, typos, overflow (slides), consistency, and academic quality. Produces a report without editing files.
disable-model-invocation: true
argument-hint: "[filename or path, e.g. latex/main.tex, slides/talk.qmd]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Task"]
---

# Proofread Academic Files (Papers and Slides)

Run the proofreading protocol on academic prose: manuscripts (e.g. latex/main.tex, main.tex) or research presentation slides (e.g. slides/talk.qmd, presentation/talk.qmd). Slides are Quarto only. Produces a report of all issues found WITHOUT editing any source files.

## Steps

1. **Identify files to review:**
   - If `$ARGUMENTS` is a specific path (e.g. latex/main.tex, slides/talk.qmd): review that file only
   - If `$ARGUMENTS` is "all": review papers and slides in project (e.g. latex/*.tex, slides/*.qmd, presentation/*.qmd; or Quarto/ if present)

2. **For each file, launch the proofreader agent** that checks for:

   **GRAMMAR:** Subject-verb agreement, articles, prepositions, tense consistency
   **TYPOS:** Misspellings, duplicated words, punctuation
   **OVERFLOW:** (Slides only — Quarto .qmd) Content exceeding slide boundaries
   **CONSISTENCY:** Citation format, notation, terminology; section/equation/figure refs (papers)
   **ACADEMIC QUALITY:** Informal language, missing words, awkward constructions, citation fidelity

3. **Produce a detailed report** for each file listing every finding with:
   - Location (line number or section/slide title)
   - Current text (what's wrong)
   - Proposed fix (what it should be)
   - Category and severity

4. **Save each report** to `quality_reports/` (e.g. `quality_reports/FILENAME_proofread_report.md`).

5. **IMPORTANT: Do NOT edit any source files.** Only produce the report. Fixes are applied separately after user review.

6. **Present summary** to the user: total issues per file, breakdown by category, most critical issues highlighted.
