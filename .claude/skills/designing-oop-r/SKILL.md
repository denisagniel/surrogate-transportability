# R Object-Oriented Programming Design

*Choosing the right OOP system: S7, S3, S4, or vctrs*

## Decision Framework

**Start here:** What are you building?

### 1. Vector-like Objects (things that behave like atomic vectors)

```
Use vctrs when:
✓ Need data frame integration (columns/rows)
✓ Want type-stable vector operations
✓ Building factor-like, date-like, or numeric-like classes
✓ Need consistent coercion/casting behavior
✓ Working with existing tidyverse infrastructure

Examples: custom date classes, units, categorical data
```

See the `customizing-vectors-r` skill for vctrs details.

### 2. General Objects (complex data structures, not vector-like)

```
Use S7 when:
✓ NEW projects that need formal classes
✓ Want property validation and safe property access (@)
✓ Need multiple dispatch (beyond S3's double dispatch)
✓ Converting from S3 and want better structure
✓ Building class hierarchies with inheritance
✓ Want better error messages and discoverability

Use S3 when:
✓ Simple classes with minimal structure needs
✓ Maximum compatibility and minimal dependencies
✓ Quick prototyping or internal classes
✓ Contributing to existing S3-based ecosystems
✓ Performance is absolutely critical (minimal overhead)

Use S4 when:
✓ Working in Bioconductor ecosystem
✓ Need complex multiple inheritance (S7 doesn't support this)
✓ Existing S4 codebase that works well
```

## S7: Modern OOP for New Projects

### Core Benefits
- **S7 combines S3 simplicity with S4 structure**
- **Formal class definitions with automatic validation**
- **Compatible with existing S3 code**

### Basic S7 Class
```r
# S7 class definition
Range <- new_class("Range",
  properties = list(
    start = class_double,
    end = class_double
  ),
  validator = function(self) {
    if (self@end < self@start) {
      "@end must be >= @start"
    }
  }
)

# Usage - constructor and property access
x <- Range(start = 1, end = 10)
x@start  # 1
x@end <- 20  # automatic validation

# Methods
inside <- new_generic("inside", "x")
method(inside, Range) <- function(x, y) {
  y >= x@start & y <= x@end
}
```

### S7 Use Cases
```r
# Complex validation needs
Range <- new_class("Range",
  properties = list(start = class_double, end = class_double),
  validator = function(self) {
    if (self@end < self@start) "@end must be >= @start"
  }
)

# Multiple dispatch needs
method(generic, list(ClassA, ClassB)) <- function(x, y) ...

# Class hierarchies with clear inheritance
Child <- new_class("Child", parent = Parent)
```

## S7 vs S3 Comparison

| Feature | S3 | S7 | When S7 wins |
|---------|----|----|---------------|
| **Class definition** | Informal (convention) | Formal (`new_class()`) | Need guaranteed structure |
| **Property access** | `$` or `attr()` (unsafe) | `@` (safe, validated) | Property validation matters |
| **Validation** | Manual, inconsistent | Built-in validators | Data integrity important |
| **Method discovery** | Hard to find methods | Clear method printing | Developer experience matters |
| **Multiple dispatch** | Limited (base generics) | Full multiple dispatch | Complex method dispatch needed |
| **Inheritance** | Informal, `NextMethod()` | Explicit `super()` | Predictable inheritance needed |
| **Migration cost** | - | Low (1-2 hours) | Want better structure |
| **Performance** | Fastest | ~Same as S3 | Performance difference negligible |
| **Compatibility** | Full S3 | Full S3 + S7 | Need both old and new patterns |

## S3: Simple and Compatible

### When S3 is the Right Choice
- Simple classes without complex needs
- Maximum performance needs (rare)
- Existing S3 ecosystem contributions
- Quick prototyping

### Basic S3 Pattern
```r
# Simple S3 class
new_simple <- function(x) {
  structure(x, class = "simple")
}

# Print method
print.simple <- function(x, ...) {
  cat("Simple:", x, "\n")
}

# Usage
obj <- new_simple(42)
print(obj)
```

## S4: Bioconductor and Complex Needs

### When to Use S4
- Working in Bioconductor ecosystem (required)
- Need complex multiple inheritance (rare)
- Existing S4 codebase that works well

### S4 vs S7 Note
S7 is designed as a modern successor to S4, but S4 remains necessary for:
- Bioconductor packages (ecosystem requirement)
- Complex multiple inheritance scenarios
- Existing S4 codebases with significant investment

## Migration Strategy

### 1. S3 → S7 (Usually 1-2 hours)
- Keeps full compatibility
- Minimal breaking changes
- Adds validation and structure

```r
# Before (S3)
new_range <- function(start, end) {
  structure(list(start = start, end = end), class = "range")
}

# After (S7)
Range <- new_class("Range",
  properties = list(
    start = class_double,
    end = class_double
  )
)
```

### 2. S4 → S7 (More Complex)
- Evaluate if S4 features are actually needed
- Complex multiple inheritance may require staying with S4
- Most S4 features have S7 equivalents

### 3. Base R → vctrs (For Vector-like Classes)
- Significant benefits for vector classes
- Automatic data frame integration
- Type-stable operations

### 4. Combining Approaches
- S7 classes can use vctrs principles internally
- vctrs vectors can be properties of S7 objects
- Mix based on needs

## Decision Tree Summary

```
What are you building?
├─ Vector-like (factor, date, numeric)?
│  └─ Use vctrs
└─ General object?
   ├─ New project?
   │  ├─ Need formal structure/validation?
   │  │  └─ Use S7
   │  └─ Simple, quick prototype?
   │     └─ Use S3
   ├─ Existing codebase?
   │  ├─ S3 codebase?
   │  │  ├─ Want better structure? (1-2 hr migration)
   │  │  │  └─ Migrate to S7
   │  │  └─ Works fine?
   │  │     └─ Keep S3
   │  └─ S4 codebase?
   │     ├─ Using complex multiple inheritance?
   │     │  └─ Keep S4
   │     └─ Could simplify?
   │        └─ Consider S7
   └─ Bioconductor package?
      └─ Use S4 (ecosystem requirement)
```

## Practical Guidelines

### Choose S7 for:
- New projects requiring formal classes
- Property validation and safety
- Clear class hierarchies
- Better developer experience

### Choose S3 for:
- Simple, lightweight classes
- Maximum compatibility
- Performance-critical base cases
- Contributing to S3 ecosystems

### Choose S4 for:
- Bioconductor packages
- Complex multiple inheritance
- Existing successful S4 code

### Choose vctrs for:
- Vector-like objects
- Data frame integration
- Type-stable operations
- See `customizing-vectors-r` skill

## Key Insight

**For new projects with general objects (not vector-like), default to S7 unless you have specific reasons for S3 (simplicity) or S4 (Bioconductor/complex inheritance).**

Migration from S3 to S7 is low-cost (1-2 hours) and provides significant benefits in safety, validation, and developer experience with negligible performance impact.
