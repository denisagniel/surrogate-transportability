# R Performance Optimization

*Profile before optimizing: systematic performance improvement for R code*

## Core Principle

**Profile first, optimize second.** Use profvis and bench to identify real bottlenecks rather than making assumptions about performance.

## Performance Tool Selection Guide

### Profiling Tools Decision Matrix

| Tool | Use When | Don't Use When | What It Shows |
|------|----------|----------------|---------------|
| **`profvis`** | Complex code, unknown bottlenecks | Simple functions, known issues | Time per line, call stack |
| **`bench::mark()`** | Comparing alternatives | Single approach | Relative performance, memory |
| **`system.time()`** | Quick checks | Detailed analysis | Total runtime only |
| **`Rprof()`** | Base R only environments | When profvis available | Raw profiling data |

### Step-by-Step Performance Workflow

```r
# 1. Profile first - find the actual bottlenecks
library(profvis)
profvis({
  # Your slow code here
})

# 2. Focus on the slowest parts (80/20 rule)
# Don't optimize until you know where time is spent

# 3. Benchmark alternatives for hot spots
library(bench)
bench::mark(
  current = current_approach(data),
  vectorized = vectorized_approach(data),
  parallel = map(data, in_parallel(func))
)

# 4. Consider tool trade-offs based on bottleneck type
```

## When Each Tool Helps vs Hurts

### Parallel Processing (`in_parallel()`)
```r
# Helps when:
✓ CPU-intensive computations
✓ Embarassingly parallel problems
✓ Large datasets with independent operations
✓ I/O bound operations (file reading, API calls)

# Hurts when:
✗ Simple, fast operations (overhead > benefit)
✗ Memory-intensive operations (may cause thrashing)
✗ Operations requiring shared state
✗ Small datasets

# Example decision point:
expensive_func <- function(x) Sys.sleep(0.1) # 100ms per call
fast_func <- function(x) x^2                 # microseconds per call

# Good for parallel
map(1:100, in_parallel(expensive_func))  # ~10s -> ~2.5s on 4 cores

# Bad for parallel (overhead > benefit)
map(1:100, in_parallel(fast_func))       # 100μs -> 50ms (500x slower!)
```

### vctrs Backend Tools
```r
# Use vctrs when:
✓ Type safety matters more than raw speed
✓ Building reusable package functions
✓ Complex coercion/combination logic
✓ Consistent behavior across edge cases

# Avoid vctrs when:
✗ One-off scripts where speed matters most
✗ Simple operations where base R is sufficient
✗ Memory is extremely constrained

# Decision point:
simple_combine <- function(x, y) c(x, y)           # Fast, simple
robust_combine <- function(x, y) vec_c(x, y)      # Safer, slight overhead

# Use simple for hot loops, robust for package APIs
```

### Data Backend Selection
```r
# Use data.table when:
✓ Very large datasets (>1GB)
✓ Complex grouping operations
✓ Reference semantics desired
✓ Maximum performance critical

# Use dplyr when:
✓ Readability and maintainability priority
✓ Complex joins and window functions
✓ Team familiarity with tidyverse
✓ Moderate sized data (<100MB)

# Use base R when:
✓ No dependencies allowed
✓ Simple operations
✓ Teaching/learning contexts
```

## Profiling Best Practices

```r
# 1. Profile realistic data sizes
profvis({
  # Use actual data size, not toy examples
  real_data |> your_analysis()
})

# 2. Profile multiple runs for stability
bench::mark(
  your_function(data),
  min_iterations = 10,  # Multiple runs
  max_iterations = 100
)

# 3. Check memory usage too
bench::mark(
  approach1 = method1(data),
  approach2 = method2(data),
  check = FALSE,  # If outputs differ slightly
  filter_gc = FALSE  # Include GC time
)

# 4. Profile with realistic usage patterns
# Not just isolated function calls
```

## Performance Anti-Patterns to Avoid

```r
# Don't optimize without measuring
# ✗ "This looks slow" -> immediately rewrite
# ✓ Profile first, optimize bottlenecks

# Don't over-engineer for performance
# ✗ Complex optimizations for 1% gains
# ✓ Focus on algorithmic improvements

# Don't assume - measure
# ✗ "for loops are always slow in R"
# ✓ Benchmark your specific use case

# Don't ignore readability costs
# ✗ Unreadable code for minor speedups
# ✓ Readable code with targeted optimizations
```

## Backend Tools for Performance

### When to Consider Lower-Level Tools
- **vctrs** for type-stable vector operations in packages
- **rlang** for metaprogramming in package functions
- **data.table** for large data operations (>1GB)

```r
# For packages - consider backend tools
# vctrs for type-stable vector operations
# rlang for metaprogramming
# data.table for large data operations
```

### Performance Considerations by Use Case

#### One-off Scripts
- Optimize for development time, not runtime
- Simple, readable code preferred
- Only optimize if runtime is painful

#### Package Functions
- Optimize for predictability and safety
- Type stability prevents expensive re-computation
- Consider vctrs/rlang for robustness

#### Large-scale Data Processing
- Optimize for throughput
- Consider data.table for >1GB datasets
- Profile to find algorithmic improvements

## Common Performance Patterns

### Pre-allocation vs Growing Objects
```r
# Slow - growing vector in loop
result <- c()
for(i in 1:n) {
  result <- c(result, compute(i))  # Reallocates every iteration
}

# Fast - pre-allocate
result <- vector("list", n)
for(i in 1:n) {
  result[[i]] <- compute(i)
}

# Even better - use purrr
result <- map(1:n, compute)
```

### Vectorization
```r
# Slow - element-wise operations in loop
for(i in seq_along(x)) {
  y[i] <- x[i] * 2 + 3
}

# Fast - vectorized
y <- x * 2 + 3

# When loops are actually fine:
# - Complex logic that doesn't vectorize easily
# - Operations with side effects
# - When the loop is not the bottleneck (profile first!)
```

### Memory-Efficient Operations
```r
# Memory-heavy - loads entire dataset
data <- read.csv("large_file.csv")
result <- data |> filter(condition) |> summarise(mean(x))

# Memory-efficient - read only what you need
result <- arrow::read_csv_arrow("large_file.csv") |>
  filter(condition) |>
  summarise(mean(x)) |>
  collect()

# Or use data.table fread for speed + efficiency
```

## Parallel Processing Guidelines

### When to Parallelize
```r
# Good candidates:
# - Simulations with independent runs
# - Bootstrap resampling
# - Cross-validation folds
# - File processing (reading/writing many files)
# - API calls

# Poor candidates:
# - Fast operations (<1ms per iteration)
# - Memory-intensive operations
# - Operations requiring shared state
# - Small number of iterations (<100)
```

### Modern Parallel Patterns (purrr 1.1+)
```r
# Using mirai backend
library(mirai)
library(purrr)

# Setup
daemons(4)  # 4 parallel workers

# Run in parallel
results <- large_datasets |>
  map(in_parallel(expensive_computation))

# Cleanup
daemons(0)

# Alternative: future backend
library(future)
library(furrr)

plan(multisession, workers = 4)
results <- future_map(large_datasets, expensive_computation)
plan(sequential)  # Reset to sequential
```

## Benchmarking Guidelines

```r
# Basic benchmark
bench::mark(
  approach1 = method1(data),
  approach2 = method2(data),
  check = TRUE  # Verify outputs are identical
)

# Advanced benchmark options
bench::mark(
  current = current_method(data),
  optimized = optimized_method(data),
  min_iterations = 10,      # At least 10 runs
  max_iterations = 1000,    # Stop after 1000 runs
  check = FALSE,            # Don't check equality
  filter_gc = FALSE,        # Include GC time
  memory = TRUE             # Track memory allocation
)

# Compare across data sizes
bench::press(
  n = c(100, 1000, 10000),
  {
    data <- generate_data(n)
    bench::mark(
      method1 = method1(data),
      method2 = method2(data)
    )
  }
)
```

## Decision Framework

### Optimization Priority Order
1. **Algorithmic improvements** - Often 10-1000x speedup
2. **Vectorization** - 10-100x speedup for applicable operations
3. **Parallelization** - 2-8x speedup (depending on cores)
4. **Low-level optimizations** - 10-50% speedup, costs readability

### When to Stop Optimizing
- Profiling shows no clear bottleneck
- Runtime is acceptable for your use case
- Further optimization requires significant code complexity
- You're hitting fundamental R/system limits

Remember: **Premature optimization is the root of all evil.** Profile first, optimize judiciously, measure improvements.
