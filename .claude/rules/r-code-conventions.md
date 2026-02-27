---
paths:
  - "**/*.R"
  - "Figures/**/*.R"
  - "scripts/**/*.R"
---

# R Code Standards

**Standard:** Senior Principal Data Engineer + PhD researcher quality

**Modern R Patterns:** See `.claude/skills/` for comprehensive modular guidance:

**Custom skills (general R):**
- `writing-tidyverse-r` - Modern pipes, joins, grouping, stringr, purrr
- `metaprogramming-rlang` - Data masking, `{{}}`, `!!`, `.data`/`.env`
- `optimizing-r` - Performance profiling, parallelization
- `designing-oop-r` - S7/S3/S4/vctrs decision framework
- `customizing-vectors-r` - vctrs for type-stable vectors
- `developing-packages-r` - Package development, API design, testing

**Posit skills (R packages & Quarto):**
- `testing-r-packages` - testthat 3+ best practices (official Posit)
- `cli-r` - Professional CLI with progress bars
- `critical-code-reviewer` - Adversarial code review (multi-language)
- `quarto-authoring` - Quarto documents, R Markdown migration

See `.claude/skills/README.md` for full details. This file adds project-specific conventions on top of those patterns.

---

## 1. Reproducibility

- `set.seed()` called ONCE at top (YYYYMMDD format)
- All packages loaded at top via `library()` (not `require()`)
- All paths relative to repository root
- Use `fs::dir_create()` for output directories (from package `fs`)

## 2. Function Design

- `snake_case` naming, verb-noun pattern
- Roxygen-style documentation
- Default parameters, no magic numbers
- Prefer **tibble** returns (easier to work with); use named lists only when the object is non-tabular (e.g. fitted model + metadata)

### Style & performance

- Prefer **tidyverse** style (dplyr, tidyr, readr, etc.).
- Prioritize **speed/efficiency**; trade a little efficiency for major gains in **readability/maintainability** when reasonable.
- Prefer **fs::path()** for constructing paths (cross-platform); `file.path()` is acceptable.
- Prefer **native pipe `|>`** (R ≥ 4.1); magrittr `%>%` acceptable for older R or readability in complex pipelines.

### Long computations

- **Prototype** on a small subset or fewer iterations first.
- **Estimate run time** (e.g. `system.time()`, `tictoc::tic()/toc()`, or `bench::mark()`); document or comment if long (e.g. > 1 min).
- **Consider parallelization** (e.g. `future` + `furrr`, or `parallel::mclapply`) for embarrassingly parallel loops (replications, bootstrap); offer as an option and document backend in comments.
- **Plan for summary updates and/or progress bars:** Long-running loops or batch jobs should provide either periodic summary updates (e.g. every N iterations or at milestones) or a progress bar (e.g. `progressr`, `cli::cli_progress_*`, or `utils::txtProgressBar()`); choose based on context (non-interactive vs interactive, parallel vs sequential).
- If a script or function is expected to run > ~1 minute, add a short comment or doc line with approximate run time (or "run time: long — consider parallelization").

## 3. Domain Correctness

<!-- Customize for your field's known pitfalls -->
- Verify estimator implementations match slide formulas
- Check known package bugs (document below in Common Pitfalls)

## 4. Visual Identity (RAND house style)

Use the [randplot](https://github.com/RANDCorporation/randplot) package for all ggplot2 figures. Install from GitHub (not on CRAN): `devtools::install_github("RANDCorporation/randplot")`.

- **Theme:** Use `theme_rand()` for all plots. Default font is Helvetica (RAND.org); for printed reports use `theme_rand("Helvetica Neue")`. Fallback when Helvetica is missing: Arial (metrically similar).
- **Categorical palette:** `RandCatPal` (nine colorblind-safe colors). Use with `scale_color_manual(values = RandCatPal)` or `scale_fill_manual(values = RandCatPal)`.
- **Sequential/grayscale:** `RandGrayPal` (nine grays). Use for grid lines, "total" fills, text (e.g. `RandGrayPal[9]` for text). Preview: `show_rand_pal("RandCatPal")` / `show_rand_pal("RandGrayPal")`.
- **Continuous scales:** randplot does not provide RAND-branded continuous scales; use `scale_fill_viridis_c()` / `scale_color_viridis_c()` (or similar) as in randplot README.

### Figure export

- **Dimensions:** Always specify `width` and `height` in `ggsave()`.
- **Slides:** Use `bg = "transparent"` and explicit dimensions: `ggsave(filepath, width = 12, height = 5, bg = "transparent")`.
- **Vector graphics for submission:** Many journals require vector graphics (PDF, EPS, or SVG). For figures intended for papers, **save a vector version** (primary or secondary): e.g. `ggsave(..., device = "pdf", width = ..., height = ...)` for LaTeX/submission; PDF is the usual choice for LaTeX papers. Optionally also save PNG for quick previews or Word drafts. Generate the vector file (PDF or SVG) as the submission-ready asset; add a second `ggsave(..., device = "png", ...)` in the same script if you need raster previews. Document in script comments when a figure is for a paper so the vector export is not missed.

## 5. Serialization & data I/O

**Heavy computations saved for reuse; slide rendering loads pre-computed data.**

- **RDS (arbitrary R objects):** Use **readr::write_rds()** and **readr::read_rds()** (not base `saveRDS`/`readRDS`) for model fits, lists, and other non-tabular objects. Example: `readr::write_rds(result, fs::path(out_dir, "descriptive_name.rds"))`.
- **Tabular/large data:** Prefer **Parquet** (arrow) for efficiency: `arrow::write_parquet(tbl, path)` / `arrow::read_parquet(path)`.
- **When to use what:** Parquet for tabular (especially large) data; readr::write_rds for arbitrary R objects (models, nested lists, single vectors).

## 6. Common Pitfalls

<!-- Add your field-specific pitfalls here -->
| Pitfall | Impact | Prevention |
|---------|--------|------------|
| Missing `bg = "transparent"` | White boxes on slides | Always include in ggsave() |
| Hardcoded paths | Breaks on other machines | Use relative paths |

## 7. Line Length & Mathematical Exceptions

**Standard:** Keep lines <= 100 characters.

**Exception: Mathematical Formulas** -- lines may exceed 100 chars **if and only if:**

1. Breaking the line would harm readability of the math (influence functions, matrix ops, finite-difference approximations, formula implementations matching paper equations)
2. An inline comment explains the mathematical operation:
   ```r
   # Sieve projection: inner product of residuals onto basis functions P_k
   alpha_k <- sum(r_i * basis[, k]) / sum(basis[, k]^2)
   ```
3. The line is in a numerically intensive section (simulation loops, estimation routines, inference calculations)

**Quality Gate Impact:**
- Long lines in non-mathematical code: minor penalty (-1 to -2 per line)
- Long lines in documented mathematical sections: no penalty

## 8. Code Quality Checklist

```
[ ] Packages at top via library()
[ ] set.seed() once at top
[ ] All paths relative
[ ] Functions documented (Roxygen)
[ ] Figures: transparent bg, explicit dimensions; vector (PDF/SVG) for paper figures
[ ] Serialization: heavy objects saved (readr::write_rds or arrow parquet as appropriate)
[ ] Comments explain WHY not WHAT
```
