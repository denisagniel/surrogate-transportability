# Claude Skills for Research Workflow

This directory contains both custom skills and official Posit skills for research-oriented development.

## Custom Skills (Modern R Patterns)

These skills provide comprehensive modern R development patterns based on Sarah Johnson's guide and Jeremy Allen's modular skill structure.

### writing-tidyverse-r
Modern tidyverse patterns for R 4.3+ and dplyr 1.1+
- Native pipe `|>`, modern joins with `join_by()`
- Per-operation grouping with `.by`
- Modern purrr patterns (`list_rbind()`, `walk()`, `in_parallel()`)
- stringr string manipulation
- Migration guides (base R → tidyverse, old → new patterns)

### metaprogramming-rlang
Data-masking and rlang metaprogramming for building tidyverse-compatible functions
- Embracing `{{}}`, injection `!!`, splicing `!!!`
- `.data`/`.env` pronouns for disambiguation
- Dynamic dots and name injection
- Bridge patterns between data-masking and tidy selection
- Package development with rlang

### optimizing-r
Performance optimization for R code
- Profiling workflow (profvis, bench::mark)
- Parallelization decision matrix
- Data backend selection (data.table vs dplyr)
- Performance anti-patterns
- Benchmarking guidelines

### designing-oop-r
Object-oriented programming system selection in R
- S7 vs S3 vs S4 vs vctrs decision tree
- When to use each OOP system
- Migration strategies
- S7 examples and patterns

### customizing-vectors-r
Building type-stable vector classes with vctrs
- Custom vector class implementation
- Coercion and casting methods
- Performance considerations
- Complete examples (percentage class)

### developing-packages-r
Modern R package development best practices
- Dependency strategy
- API design patterns (`.by`, `{{}}`, `...`)
- Error handling with cli
- Export decisions, testing, documentation
- Pre-release flexibility (remove vs deprecate, snapshot testing, code comments)
- usethis workflow

### techdebt-r
Systematic technical debt scanning for R code, simulations, and packages
- Code duplication in simulation loops and DGPs
- Magic numbers without documentation
- Outdated tidyverse patterns (pipes, joins, grouping)
- Vectorization failures, non-idiomatic code
- Missing documentation, error handling, tests
- R-specific smells (growing objects in loops, missing set.seed())
- Package-specific issues (NAMESPACE, exports, examples)
- Severity levels: CRITICAL, HIGH, MEDIUM, LOW
- Integration with quality gates (80/90/95 thresholds)

## Posit Skills (Official r-lib Ecosystem)

Official skills from the Posit/tidyverse team for R package development and Quarto authoring.

### testing-r-packages
Best practices for R package testing with testthat 3+
- Test structure (standard vs BDD-style with `describe()`/`it()`)
- Self-sufficient tests with withr for cleanup
- Expectations (equality, errors, patterns, snapshots)
- Fixtures with `test_path()`
- Modern testthat 3 patterns

### cli-r
Professional command-line interfaces for R packages
- Semantic messaging (`cli_abort()`, `cli_warn()`, `cli_inform()`)
- Inline markup (`{.fn}`, `{.file}`, `{.pkg}`, `{.code}`)
- Pluralization patterns with `{?}`
- Progress bars (`cli_progress_bar()`, `cli_progress_step()`)
- Headers, alerts, lists, code blocks

### critical-code-reviewer
Rigorous, adversarial code review across languages
- Multi-language support (Python, R, JS/TS, SQL, front-end)
- Security holes, edge cases, performance issues
- Type safety, error handling, accessibility
- Three severity tiers: Blocking, Required, Suggestions
- Language-specific anti-patterns

### quarto-authoring
Writing and authoring Quarto documents
- Code cell options, figure/table captions
- Cross-references, callout blocks
- Citations and bibliography
- Page layout and columns, Mermaid diagrams
- R Markdown migration (bookdown, blogdown, xaringan, distill)
- Quarto websites, books, presentations, reports

## Usage

### Automatic Activation
Skills load automatically when relevant to your task. Claude detects the context and engages appropriate skills without explicit invocation.

### Explicit Invocation
You can explicitly invoke skills using the Skill tool if needed, but this is rarely necessary.

### Complementary Patterns

**Custom R skills** provide foundational modern R patterns for all R work (tidyverse, rlang, performance, OOP).

**Posit skills** provide specialized patterns for R package development (testing, CLI, CRAN) and Quarto authoring.

Use both together:
- Custom skills for general R coding, data analysis, simulations
- Posit skills for R package development, testing, releases, and Quarto documents

## Token Efficiency

Skills are modular and load on-demand, saving tokens compared to monolithic CLAUDE.md files:
- Each custom skill: 300-600 lines
- Each Posit skill: 200-400 lines
- Load only what you need per session

## Source

**Custom skills:** Based on Sarah Johnson's "Modern R Development Guide" (August 2025), organized following Jeremy Allen's modular skill structure.

**Posit skills:** Official skills from [posit-dev/skills](https://github.com/posit-dev/skills) repository, MIT licensed.

## See Also

- [.claude/rules/r-code-conventions.md](../rules/r-code-conventions.md) - Project-specific R standards (RAND style, reproducibility)
- [CLAUDE.md](../../CLAUDE.md) - Main project instructions
- [meta-spec/RESEARCH_CONSTITUTION.md](../../meta-spec/RESEARCH_CONSTITUTION.md) - Research principles and non-negotiables
