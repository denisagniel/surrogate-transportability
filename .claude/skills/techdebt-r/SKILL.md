# Technical Debt Scanner for R Code

*Systematically identify and fix technical debt in R scripts, simulations, and packages*

## Purpose

Find and address technical debt in R code including duplicated simulation logic, magic numbers in DGPs, outdated patterns, vectorization failures, and code smells. Adapted from ChernyCode's techdebt skill for research-focused R workflows.

## Categories Monitored

### Code Duplication
- Similar simulation loop structures
- Copied data processing blocks
- Repeated DGP specification code
- Duplicated estimation routines
- Redundant parameter combinations in simulations

### Dead Code
- Unused R packages in library() calls
- Unused functions and helper code
- Commented-out simulation variants
- Unreachable code paths
- Deprecated tidyverse patterns still present

### Outdated R Patterns
- Using `%>%` instead of native pipe `|>` (R 4.1+)
- Old join syntax: `by = c("a" = "b")` vs `join_by(a == b)`
- `group_by() |> ... |> ungroup()` vs `.by` argument
- `subset()` / `aggregate()` vs dplyr equivalents
- Base string functions vs stringr
- `sapply()` vs type-stable `map_*()` functions
- Missing or old-style type hints in packages

### R-Specific Code Smells
- **Non-vectorized operations** - Loops where vectorization is possible
- **Magic numbers in DGPs** - Hardcoded parameters (n=1000, effect_size=0.5) without explanation
- **Long functions** (>50 lines) - Especially in simulation or estimation code
- **Deep nesting** (3+ levels) - Complex nested loops or conditionals
- **Missing set.seed()** or seed not at top
- **Non-relative paths** - Hardcoded absolute paths
- **Growing objects in loops** - `result <- c(result, new_value)` instead of pre-allocation
- **Implicit type coercion** - Relying on R's implicit conversions
- **Excessive parameters** (5+) - Functions with too many arguments

### Statistical/Simulation-Specific Smells
- **Missing parameter documentation** - DGP parameters without clear explanation
- **Hardcoded simulation settings** - n_sims, n_obs as magic numbers vs arguments
- **No progress indicators** - Long simulations without cli progress bars
- **Missing result serialization** - Heavy computations not saved with readr::write_rds()
- **Unreproducible results** - Random operations without set.seed()
- **Missing convergence checks** - Optimization/estimation without diagnostics
- **Hardcoded thresholds** - Significance levels, convergence criteria as magic numbers

### Best Practice Gaps
- **Missing Roxygen documentation** on exported functions
- **No error handling** in simulation loops (one failure kills entire run)
- **Hardcoded configuration** - Parameters that should be arguments
- **Untested critical functions** - No testthat tests for estimators
- **Missing input validation** - No checks for valid inputs
- **No figure export parameters** - ggsave() without explicit width/height
- **Missing transparent backgrounds** - Slides figures without `bg = "transparent"`
- **Non-descriptive variable names** - `data`, `temp`, `x`, `result`

### Package-Specific Issues
- **Missing NAMESPACE imports** - Using :: without importing
- **Inconsistent naming** - Mix of snake_case and camelCase
- **No package-level documentation** - Missing package.R or _PACKAGE roxygen
- **Hardcoded data paths** - Not using system.file() or package data
- **Missing examples** - Exported functions without @examples
- **No vignettes** - Complex packages without long-form documentation

## Severity Levels

**[CRITICAL]** - Breaks reproducibility, correctness, or R CMD check
- Missing set.seed() in stochastic code
- Non-relative paths
- Growing objects in hot loops (performance killer)
- Using sapply() in package code (type instability)

**[HIGH]** - Violates R conventions or best practices
- Magic numbers in DGPs or estimators
- Non-vectorized operations where vectorization is simple
- Missing documentation on exported functions
- Outdated tidyverse patterns
- No progress bars on long simulations

**[MEDIUM]** - Code smells that reduce maintainability
- Code duplication
- Long functions (>50 lines)
- Deep nesting (3+ levels)
- Missing error handling
- Non-descriptive names

**[LOW]** - Style and convention issues
- Using `%>%` instead of `|>`
- Missing input validation
- Inconsistent naming
- Missing comments on complex logic

## Workflow

### 1. Scan
Search for patterns matching the categories above, prioritizing by severity.

### 2. Document
Create a categorized inventory:
```
## Technical Debt Report: [file/directory]

### [CRITICAL] Issues
- Location: file.R:42
  Issue: Missing set.seed() before rnorm()
  Impact: Non-reproducible results
  Fix: Add set.seed(YYYYMMDD) at top of file

### [HIGH] Issues
...
```

### 3. Fix
Address issues systematically:
- Start with CRITICAL, then HIGH
- Make atomic commits per category
- Run R CMD check / testthat after each fix
- Verify no behavior changes (run tests, compare outputs)

### 4. Validate
- Run lintr if available
- Run styler if needed for consistency
- Ensure tests pass
- Check that simulations still produce same results (with same seed)

## Usage

Invoke broadly or targeted:
- `/techdebt-r` - Scan entire project
- `/techdebt-r R/` - Scan R package source
- `/techdebt-r simulations/` - Scan simulation scripts
- `/techdebt-r scripts/01-analysis.R` - Scan specific file

## Output

Session produces:
1. **Categorized inventory** of issues by severity
2. **Fix log** - What was changed and why
3. **Recommendations** - Remaining improvements for future work

## Integration with Quality Gates

Findings map to quality thresholds:
- **CRITICAL issues present** → Below 80/100 (cannot commit)
- **HIGH issues present** → 80-89/100 (can commit, should fix before PR)
- **Only MEDIUM/LOW** → 90+/100 (clean code)

## R-Specific Checks

### Check for Non-Idiomatic Tidyverse
```r
# Bad
data %>%
  group_by(category) %>%
  summarise(mean = mean(value)) %>%
  ungroup()

# Good
data |>
  summarise(mean = mean(value), .by = category)
```

### Check for Vectorization Opportunities
```r
# Bad
result <- numeric(length(x))
for(i in seq_along(x)) {
  result[i] <- x[i] * 2 + 3
}

# Good
result <- x * 2 + 3
```

### Check for Magic Numbers in DGPs
```r
# Bad
data <- tibble(
  x = rnorm(1000),
  y = 2*x + rnorm(1000, sd = 0.5)
)

# Good (with documentation)
# DGP parameters
n_obs <- 1000        # Sample size
true_effect <- 2.0   # True coefficient on x
noise_sd <- 0.5      # Standard deviation of errors

data <- tibble(
  x = rnorm(n_obs),
  y = true_effect * x + rnorm(n_obs, sd = noise_sd)
)
```

### Check for Missing Progress Bars
```r
# Bad - no feedback on long simulation
results <- map(1:1000, ~ run_simulation(...))

# Good - progress feedback
library(cli)
results <- map(1:1000, ~ run_simulation(...), .progress = TRUE)
```

## See Also

- [.claude/rules/r-code-conventions.md](../../.claude/rules/r-code-conventions.md) - Project R standards
- [writing-tidyverse-r](../writing-tidyverse-r/SKILL.md) - Modern tidyverse patterns
- [optimizing-r](../optimizing-r/SKILL.md) - Performance optimization
- [developing-packages-r](../developing-packages-r/SKILL.md) - Package best practices

## Notes

- Prioritize fixes that improve **reproducibility** (critical for research)
- Consider **readability vs performance** trade-offs (document when choosing performance)
- Always **run tests** after refactoring
- **Save results** before making large changes (git commit or RDS backup)
