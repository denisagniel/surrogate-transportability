# Customizing Vectors with vctrs

*Building type-stable vector classes for R packages*

## Core Benefits

- **Type stability** - Predictable output types regardless of input values
- **Size stability** - Predictable output sizes from input sizes
- **Consistent coercion rules** - Single set of rules applied everywhere
- **Robust class design** - Proper S3 vector infrastructure

## When to Use vctrs

### Use vctrs when:

#### Building Custom Vector Classes
```r
# Good - vctrs-based vector class
new_percent <- function(x = double()) {
  vec_assert(x, double())
  new_vctr(x, class = "pkg_percent")
}

# Automatic data frame compatibility, subsetting, etc.
```

#### Type-Stable Functions in Packages
```r
# Good - Guaranteed output type
my_function <- function(x, y) {
  # Always returns double, regardless of input values
  vec_cast(result, double())
}

# Avoid - Type depends on data
sapply(x, function(i) if(condition) 1L else 1.0)
```

#### Consistent Coercion/Casting
```r
# Good - Explicit casting with clear rules
vec_cast(x, double())  # Clear intent, predictable behavior

# Good - Common type finding
vec_ptype_common(x, y, z)  # Finds richest compatible type

# Avoid - Base R inconsistencies
c(factor("a"), "b")  # Unpredictable behavior
```

#### Size/Length Stability
```r
# Good - Predictable sizing
vec_c(x, y)  # size = vec_size(x) + vec_size(y)
vec_rbind(df1, df2)  # size = sum of input sizes

# Avoid - Unpredictable sizing
c(env_object, function_object)  # Unpredictable length
```

## vctrs vs Base R Decision Matrix

| Use Case | Base R | vctrs | When to Choose vctrs |
|----------|--------|-------|---------------------|
| Simple combining | `c()` | `vec_c()` | Need type stability, consistent rules |
| Custom classes | S3 manually | `new_vctr()` | Want data frame compatibility, subsetting |
| Type conversion | `as.*()` | `vec_cast()` | Need explicit, safe casting |
| Finding common type | Not available | `vec_ptype_common()` | Combining heterogeneous inputs |
| Size operations | `length()` | `vec_size()` | Working with non-vector objects |

## Implementation Patterns

### Basic Vector Class
```r
# Constructor (low-level)
new_percent <- function(x = double()) {
  vec_assert(x, double())
  new_vctr(x, class = "pkg_percent")
}

# Helper (user-facing)
percent <- function(x = double()) {
  x <- vec_cast(x, double())
  new_percent(x)
}

# Format method
format.pkg_percent <- function(x, ...) {
  paste0(vec_data(x) * 100, "%")
}
```

### Coercion Methods
```r
# Self-coercion
vec_ptype2.pkg_percent.pkg_percent <- function(x, y, ...) {
  new_percent()
}

# With double
vec_ptype2.pkg_percent.double <- function(x, y, ...) double()
vec_ptype2.double.pkg_percent <- function(x, y, ...) double()

# Casting
vec_cast.pkg_percent.double <- function(x, to, ...) {
  new_percent(x)
}
vec_cast.double.pkg_percent <- function(x, to, ...) {
  vec_data(x)
}
```

### Vector-like Behavior in Data Frames
```r
# Vector-like behavior in data frames
percent <- new_vctr(0.5, class = "percentage")
data.frame(x = 1:3, pct = percent(c(0.1, 0.2, 0.3)))  # works seamlessly

# Type-stable operations
vec_c(percent(0.1), percent(0.2))  # predictable behavior
vec_cast(0.5, percent())          # explicit, safe casting
```

## Performance Considerations

### When vctrs Adds Overhead
- **Simple operations** - `vec_c(1, 2)` vs `c(1, 2)` for basic atomic vectors
- **One-off scripts** - Type safety less critical than speed
- **Small vectors** - Overhead may outweigh benefits

### When vctrs Improves Performance
- **Package functions** - Type stability prevents expensive re-computation
- **Complex classes** - Consistent behavior reduces debugging
- **Data frame operations** - Robust column type handling
- **Repeated operations** - Predictable types enable optimization

## Package Development Guidelines

### Exports and Dependencies
```r
# DESCRIPTION - Import specific functions
Imports: vctrs

# NAMESPACE - Import what you need
importFrom(vctrs, vec_assert, new_vctr, vec_cast, vec_ptype_common)

# Or if using extensively
import(vctrs)
```

### Testing vctrs Classes
```r
# Test type stability
test_that("my_function is type stable", {
  expect_equal(vec_ptype(my_function(1:3)), vec_ptype(double()))
  expect_equal(vec_ptype(my_function(integer())), vec_ptype(double()))
})

# Test coercion
test_that("coercion works", {
  expect_equal(vec_ptype_common(new_percent(), 1.0), double())
  expect_error(vec_ptype_common(new_percent(), "a"))
})
```

## Complete Example: Percentage Class

```r
# Constructor (low-level, for internal use)
new_percent <- function(x = double()) {
  vec_assert(x, double())
  new_vctr(x, class = "pkg_percent")
}

# Helper (user-facing constructor with validation)
percent <- function(x = double()) {
  x <- vec_cast(x, double())
  if (any(x < 0 | x > 1, na.rm = TRUE)) {
    stop("Percentages must be between 0 and 1")
  }
  new_percent(x)
}

# Format method (how it displays)
format.pkg_percent <- function(x, ...) {
  out <- paste0(format(vec_data(x) * 100, digits = 2), "%")
  out[is.na(x)] <- NA
  out
}

# Coercion with itself
vec_ptype2.pkg_percent.pkg_percent <- function(x, y, ...) {
  new_percent()
}

# Coercion with double
vec_ptype2.pkg_percent.double <- function(x, y, ...) {
  double()
}
vec_ptype2.double.pkg_percent <- function(x, y, ...) {
  double()
}

# Casting from double
vec_cast.pkg_percent.double <- function(x, to, ...) {
  percent(x)
}

# Casting to double
vec_cast.double.pkg_percent <- function(x, to, ...) {
  vec_data(x)
}

# Usage
x <- percent(c(0.1, 0.5, 0.9))
print(x)  # "10%"  "50%"  "90%"

# Works in data frames
df <- data.frame(category = c("A", "B", "C"), pct = x)

# Type-stable combining
vec_c(percent(0.1), percent(0.2))  # Still percent class

# Explicit casting
vec_cast(0.5, percent())  # Cast double to percent
vec_cast(x, double())     # Cast percent to double
```

## Don't Use vctrs When:

- **Simple one-off analyses** - Base R is sufficient
- **No custom classes needed** - Standard types work fine
- **Performance critical + simple operations** - Base R may be faster
- **External API constraints** - Must return base R types

## Key Insight

**vctrs is most valuable in package development where type safety, consistency, and extensibility matter more than raw speed for simple operations.**

For data analysis scripts, base R is usually fine. For package functions that others will rely on, vctrs provides predictability and safety worth the small overhead.

## Common Patterns

### Validation in Constructor
```r
percent <- function(x = double()) {
  x <- vec_cast(x, double())
  # Validate values
  if (any(x < 0 | x > 1, na.rm = TRUE)) {
    stop("Values must be between 0 and 1")
  }
  new_percent(x)
}
```

### Attributes for Metadata
```r
new_scaled <- function(x = double(), center = 0, scale = 1) {
  vec_assert(x, double())
  new_vctr(x, center = center, scale = scale, class = "pkg_scaled")
}

# Access attributes
scaled_center <- function(x) attr(x, "center")
scaled_scale <- function(x) attr(x, "scale")
```

### Arithmetic Methods
```r
# Addition
vec_arith.pkg_percent <- function(op, x, y, ...) {
  UseMethod("vec_arith.pkg_percent", y)
}

vec_arith.pkg_percent.default <- function(op, x, y, ...) {
  stop_incompatible_op(op, x, y)
}

vec_arith.pkg_percent.numeric <- function(op, x, y, ...) {
  if (op == "+") {
    return(percent(vec_data(x) + y))
  }
  stop_incompatible_op(op, x, y)
}
```

## Resources

- vctrs documentation: `vignette("s3-vector", package = "vctrs")`
- Type stability article: `vignette("type-size-stability", package = "vctrs")`
- For general OOP decisions, see the `designing-oop-r` skill
