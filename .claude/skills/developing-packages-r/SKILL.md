# R Package Development

*Modern best practices for building robust R packages using tidyverse patterns*

## Dependency Strategy

### When to Add Dependencies vs Base R

```r
# Add dependency when:
✓ Significant functionality gain
✓ Maintenance burden reduction
✓ User experience improvement
✓ Complex implementation (regex, dates, web)

# Use base R when:
✓ Simple utility functions
✓ Package will be widely used (minimize deps)
✓ Dependency is large for small benefit
✓ Base R solution is straightforward

# Example decisions:
str_detect(x, "pattern")    # Worth stringr dependency
length(x) > 0              # Don't need purrr for this
parse_dates(x)             # Worth lubridate dependency
x + 1                      # Don't need dplyr for this
```

### Tidyverse Dependency Guidelines

```r
# Core tidyverse (usually worth it):
dplyr     # Complex data manipulation
purrr     # Functional programming, parallel
stringr   # String manipulation
tidyr     # Data reshaping

# Specialized tidyverse (evaluate carefully):
lubridate # If heavy date manipulation
forcats   # If many categorical operations
readr     # If specific file reading needs
ggplot2   # If package creates visualizations

# Heavy dependencies (use sparingly):
tidyverse # Meta-package, very heavy
shiny     # Only for interactive apps
```

## API Design Patterns

### Function Design Strategy

```r
# Modern tidyverse API patterns

# 1. Use .by for per-operation grouping
my_summarise <- function(.data, ..., .by = NULL) {
  # Support modern grouped operations
}

# 2. Use {{ }} for user-provided columns
my_select <- function(.data, cols) {
  .data |> select({{ cols }})
}

# 3. Use ... for flexible arguments
my_mutate <- function(.data, ..., .by = NULL) {
  .data |> mutate(..., .by = {{ .by }})
}

# 4. Return consistent types (tibbles, not data.frames)
my_function <- function(.data) {
  result |> tibble::as_tibble()
}
```

### Input Validation Strategy

```r
# Validation level by function type:

# User-facing functions - comprehensive validation
user_function <- function(x, threshold = 0.5) {
  # Check all inputs thoroughly
  if (!is.numeric(x)) stop("x must be numeric")
  if (!is.numeric(threshold) || length(threshold) != 1) {
    stop("threshold must be a single number")
  }
  # ... function body
}

# Internal functions - minimal validation
.internal_function <- function(x, threshold) {
  # Assume inputs are valid (document assumptions)
  # Only check critical invariants
  # ... function body
}

# Package functions with vctrs - type-stable validation
safe_function <- function(x, y) {
  x <- vec_cast(x, double())
  y <- vec_cast(y, double())
  # Automatic type checking and coercion
}
```

## Error Handling Patterns

### Good Error Messages
```r
# Specific and actionable
if (length(x) == 0) {
  cli::cli_abort(
    "Input {.arg x} cannot be empty.",
    "i" = "Provide a non-empty vector."
  )
}

# Include function name in errors
validate_input <- function(x, call = caller_env()) {
  if (!is.numeric(x)) {
    cli::cli_abort("Input must be numeric", call = call)
  }
}

# Use consistent error styling
# cli package for user-friendly messages
# rlang for developer tools
```

### Error Message Principles
- **Specific** - Say what went wrong
- **Actionable** - Say how to fix it
- **Traceable** - Include function context

## Function Export Decisions

### Export Function When:
```r
✓ Users will call it directly
✓ Other packages might want to extend it
✓ Part of the core package functionality
✓ Stable API that won't change often

# Example: main data processing functions
export_these <- function(.data, ...) {
  # Comprehensive input validation
  # Full documentation required
  # Stable API contract
}
```

### Keep Function Internal When:
```r
✓ Implementation detail that may change
✓ Only used within package
✓ Complex implementation helpers
✓ Would clutter user-facing API

# Example: helper functions
.internal_helper <- function(x, y) {
  # Minimal documentation
  # Can change without breaking users
  # Assume inputs are pre-validated
}
```

## Testing Strategy

### Testing Levels

```r
# Unit tests - individual functions
test_that("function handles edge cases", {
  expect_equal(my_func(c()), expected_empty_result)
  expect_error(my_func(NULL), class = "my_error_class")
})

# Integration tests - workflow combinations
test_that("pipeline works end-to-end", {
  result <- data |>
    step1() |>
    step2() |>
    step3()
  expect_s3_class(result, "expected_class")
})

# Property-based tests for package functions
test_that("function properties hold", {
  # Test invariants across many inputs
})
```

### What to Test

```r
# Must test:
✓ Edge cases (empty input, NA, NULL)
✓ Error conditions and messages
✓ Core functionality with typical inputs
✓ Type stability (if using vctrs)
✓ Integration between components

# Can skip:
✗ Trivial getters/setters
✗ Simple wrappers with no logic
✗ Code paths that can't fail
```

## Pre-Release Package Development (Pre-v1.0)

### When You Have No Users Yet

Before your package reaches v1.0, you have maximum flexibility. Use it.

```r
# Pre-v1.0: Be aggressive with breaking changes
✓ Remove functions that don't work well
✓ Rename inconsistent arguments
✓ Simplify confusing APIs
✓ Change default behaviors
✓ Restructure the package

# Post-v1.0: Deprecation cycle required
✗ Can't remove without lifecycle::deprecate_soft()
✗ Must provide migration path
✗ Breaking changes need major version bump
```

**Decision Framework: Remove vs Deprecate**

```r
# REMOVE immediately (pre-v1.0):
- Functions that don't work correctly
- APIs you regret designing
- Features nobody would miss
- Experimental code that failed

# DEPRECATE (post-v1.0 or if users exist):
- Functions with active usage
- APIs that need migration path
- Features with dependencies
```

### Testing Error Messages with Snapshots

Prefer `expect_snapshot(error = TRUE)` over `expect_error()` for testing errors, warnings, and messages. Snapshots catch unintended changes to user-facing text.

```r
# Good: Snapshot captures full error message
test_that("validate_input() errors informatively", {
  expect_snapshot(error = TRUE, {
    validate_input(NULL)
  })

  expect_snapshot(error = TRUE, {
    validate_input("not numeric")
  })
})

# Less good: Only tests that error occurs
test_that("validate_input() errors", {
  expect_error(validate_input(NULL))
  expect_error(validate_input("not numeric"))
})
```

**Why snapshots?**
- Catch unintended message changes (typos, regressions)
- Review exact user-facing text in diffs
- Force deliberate review when updating messages
- Work for errors, warnings, and messages

**Snapshot for messages and warnings too:**

```r
test_that("function warns about deprecated argument", {
  expect_snapshot({
    result <- my_function(old_arg = 10)
  })
})

test_that("function informs user of processing", {
  expect_snapshot({
    process_data(big_dataset)
  })
})
```

### Code Comment Philosophy

**Minimize comments. Let code be self-documenting.**

```r
# Bad: Comment states the obvious
# Calculate the mean
mean_value <- mean(x)

# Good: No comment needed
mean_value <- mean(x)

# Bad: Comment explains unclear code
# Loop through each element and multiply by 2
result <- numeric(length(x))
for (i in seq_along(x)) {
  result[i] <- x[i] * 2
}

# Good: Clear code needs no explanation
result <- x * 2
```

**When comments ARE appropriate:**

```r
# 1. Roxygen documentation (always)
#' Calculate summary statistics
#'
#' @param x A numeric vector
#' @return A named vector of statistics
my_summary <- function(x) { ... }

# 2. Non-obvious algorithms or formulas
# Wang-Landau algorithm for density estimation
# See: Wang & Landau (2001), DOI: 10.1103/PhysRevLett.86.2050
estimate_density <- function(x) { ... }

# 3. Workarounds for R quirks or package bugs
# Work around dplyr issue #1234: grouped mutate returns wrong type
result <- ungroup(mutate(group_by(...), ...))

# 4. Performance-critical choices
# Pre-allocate for 10x speedup vs growing vector in loop
result <- vector("list", n)
```

**Default stance:** If you're tempted to add a comment, first try:
1. Better variable names
2. Extract helper function with descriptive name
3. Simplify the logic

### Example-Driven Style Guide

Reference existing files as exemplars rather than writing style rules.

**In CONTRIBUTING.md or internal docs:**

```markdown
## Style Guide

Follow the patterns in these files:

- Function design: See `R/core-functions.R`
- Error handling: See `R/validate.R`
- Testing: See `tests/testthat/test-core.R`
- Documentation: See any `@examples` in exported functions

When in doubt, match existing code.
```

**Why this works:**
- Living examples always up-to-date
- Shows actual patterns in context
- Easier to absorb than abstract rules
- Self-maintaining (examples improve as you refactor)

**Specify exemplars by concern:**

```r
# For new contributors:
"See R/utils.R for our approach to internal helpers"
"See R/errors.R for cli error message patterns"
"See tests/testthat/test-snapshots.R for snapshot testing"
```

## Documentation Strategy

### Documentation Priorities

```r
# Must document:
✓ All exported functions
✓ Complex algorithms or formulas
✓ Non-obvious parameter interactions
✓ Examples of typical usage

# Can skip documentation:
✗ Simple internal helpers
✗ Obvious parameter meanings
✗ Functions that just call other functions
```

### Roxygen2 Patterns

```r
#' Calculate summary statistics
#'
#' @param data A data frame
#' @param var <[`data-masked`][dplyr::dplyr_data_masking]> Column to summarize
#' @param ... <[`dynamic-dots`][rlang::dyn-dots]> Additional grouping variables
#'
#' @return A tibble with summary statistics
#' @export
#'
#' @examples
#' my_summary(mtcars, mpg, cyl)
#' my_summary(mtcars, mpg, cyl, am)
my_summary <- function(data, var, ...) {
  # Function body
}
```

### Documentation Tags for rlang Functions

```r
#' @param var <[`data-masked`][dplyr::dplyr_data_masking]> Column to summarize
#' @param ... <[`dynamic-dots`][rlang::dyn-dots]> Additional grouping variables
#' @param cols <[`tidy-select`][dplyr::dplyr_tidy_select]> Columns to select
```

## Package Structure Best Practices

### File Organization

```
pkg/
├── R/
│   ├── package.R          # Package documentation, imports
│   ├── core-functions.R   # Main exported functions
│   ├── utils.R            # Internal helpers
│   ├── data.R             # Data documentation
│   └── zzz.R              # .onLoad, .onAttach hooks
├── man/                   # Generated documentation
├── tests/
│   └── testthat/
│       ├── test-core.R
│       └── test-utils.R
├── vignettes/             # Long-form documentation
├── data/                  # Package datasets
├── DESCRIPTION
├── NAMESPACE              # Generated by roxygen2
└── README.md
```

### DESCRIPTION Best Practices

```r
# Version numbering
# x.y.z where:
# x = major (breaking changes)
# y = minor (new features, backwards compatible)
# z = patch (bug fixes)

# Imports vs Suggests
Imports:      # Required for package to work
  dplyr,
  rlang
Suggests:     # Optional, for vignettes/examples
  testthat,
  knitr
```

## Common Package Patterns

### Prefix for Internal Functions
```r
# Internal functions start with .
.internal_helper <- function(x) {
  # Not exported, can change freely
}

# Or use consistent naming
pkg_internal_helper <- function(x) {
  # Clear it's internal even if exported for testing
}
```

### Package-Level Documentation
```r
#' @keywords internal
"_PACKAGE"

# Package-level imports
#' @importFrom rlang := !! !!!
#' @import dplyr
NULL
```

### Data Documentation
```r
#' Example dataset
#'
#' A dataset containing...
#'
#' @format A data frame with X rows and Y variables:
#' \describe{
#'   \item{var1}{Description}
#'   \item{var2}{Description}
#' }
"dataset_name"
```

## Development Workflow

### Typical Development Cycle

```r
# 1. Write function
# 2. Document with roxygen2
usethis::use_r("function-name")

# 3. Document all exports
devtools::document()

# 4. Test interactively
devtools::load_all()

# 5. Write tests
usethis::use_test("function-name")

# 6. Run checks
devtools::test()
devtools::check()

# 7. Update NEWS.md
# 8. Commit
```

### usethis Helpers

```r
# Setup
usethis::create_package("pkg")
usethis::use_git()
usethis::use_mit_license()

# Add functionality
usethis::use_r("function-name")
usethis::use_test("function-name")
usethis::use_vignette("intro")

# Dependencies
usethis::use_package("dplyr")
usethis::use_package("testthat", "Suggests")

# Data
usethis::use_data(dataset)
usethis::use_data_raw("dataset")
```

## Advanced Patterns

### S3 Method Registration

```r
# In package.R or utils.R
#' @export
#' @importFrom generics method_name
method_name <- function(x, ...) {
  UseMethod("method_name")
}

# Method implementations
#' @export
method_name.class1 <- function(x, ...) {
  # Implementation
}
```

### Package Options

```r
# Define in zzz.R
.onLoad <- function(libname, pkgname) {
  op <- options()
  op.pkg <- list(
    pkg.option1 = TRUE,
    pkg.option2 = 10
  )
  toset <- !(names(op.pkg) %in% names(op))
  if(any(toset)) options(op.pkg[toset])
  invisible()
}

# Access in functions
get_option <- function(name, default = NULL) {
  getOption(paste0("pkg.", name), default)
}
```

### Package State Management

```r
# Use package environment for state
pkg_env <- new.env(parent = emptyenv())

# Getters/setters
set_state <- function(name, value) {
  pkg_env[[name]] <- value
  invisible(value)
}

get_state <- function(name, default = NULL) {
  if (exists(name, envir = pkg_env)) {
    pkg_env[[name]]
  } else {
    default
  }
}
```

## Quality Checklist

```
[ ] All exported functions documented
[ ] Examples provided and working
[ ] Tests cover main functionality and edge cases
[ ] R CMD check passes with no errors/warnings
[ ] NEWS.md updated
[ ] README.md explains package purpose
[ ] Vignette for main use case (optional but recommended)
[ ] Dependencies justified and minimal
[ ] Consistent API design (snake_case, .by, {{ }})
[ ] Error messages are helpful
[ ] Type stability considered (vctrs if appropriate)
```

## Resources

- R Packages book: https://r-pkgs.org/
- tidyverse design guide: https://design.tidyverse.org/
- For rlang patterns: see `metaprogramming-rlang` skill
- For vctrs: see `customizing-vectors-r` skill
- For OOP decisions: see `designing-oop-r` skill
