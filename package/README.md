# surrogateTransportability

An R package implementing surrogate inference via random probability distributions for evaluating surrogate markers across future studies.

## Overview

This package implements a novel approach to surrogate marker evaluation that models future studies as draws from a random probability measure. The method addresses the key question: "Will the treatment effect on the surrogate be informative about the treatment effect on the outcome in a new study on a new population?"

## Key Features

- **Innovation Approach**: Models future studies as mixtures of current study and innovation distributions
- **Multiple Functionals**: Computes correlation, probability, and conditional mean functionals
- **Uncertainty Quantification**: Nested Bayesian bootstrap for posterior inference
- **Flexible Data Generation**: Supports binary and continuous surrogates/outcomes with mixture structure
- **Comparison Framework**: Compare with traditional surrogate evaluation methods

## Installation

```r
# Install from local source
devtools::install("package/")
```

## Quick Start

```r
library(surrogateTransportability)

# Generate study data
data <- generate_study_data(
  n = 500,
  treatment_effect_surrogate = c(0.5, 0.8),
  treatment_effect_outcome = c(0.3, 0.6),
  surrogate_type = "continuous",
  outcome_type = "continuous"
)

# Run posterior inference
result <- posterior_inference(
  data,
  n_outer = 100,
  n_inner = 50,
  functional_type = "all"
)

# View results
print(result$summary)
```

## Core Functions

### Data Generation
- `generate_study_data()`: Create study data with mixture structure
- `generate_comparison_scenario()`: Generate specific comparison scenarios

### Future Study Generation
- `generate_future_study()`: Generate single future study using innovation approach
- `generate_multiple_future_studies()`: Generate multiple future studies

### Treatment Effect Estimation
- `compute_treatment_effect()`: Calculate treatment effects for randomized/observational studies
- `compute_multiple_treatment_effects()`: Compute effects for multiple outcomes

### Surrogate Functionals
- `functional_correlation()`: Correlation between treatment effects across studies
- `functional_probability()`: P(ΔY > εY | ΔS > εS)
- `functional_conditional_mean()`: E[ΔY | ΔS = δ]

### Inference
- `posterior_inference()`: Main inference function with nested Bayesian bootstrap
- `compare_surrogate_methods()`: Compare innovation approach with traditional methods

## Method Details

The innovation approach models future studies as:

Q = (1-λ)P₀ + λP̃

where:
- P₀ is the current study distribution
- P̃ is the innovation distribution (Bayesian bootstrap)
- λ ~ Beta(a,b) controls similarity to current study

Key functionals evaluated:
1. **Correlation**: cor(ΔS(Q), ΔY(Q))
2. **Probability**: P(ΔY > εY | ΔS > εS)
3. **Conditional Mean**: E[ΔY(Q) | ΔS(Q) = δ]

## Examples

### Basic Usage

```r
# Generate data
data <- generate_study_data(n = 500)

# Run inference
result <- posterior_inference(data, n_outer = 100, n_inner = 50)

# Extract correlation functional
correlation <- result$summary$correlation$mean
```

### Comparison Scenarios

```r
# Good by innovation, poor by traditional
data1 <- generate_comparison_scenario("good_innovation_poor_traditional", n = 500)
result1 <- posterior_inference(data1)

# Poor by innovation, good by traditional  
data2 <- generate_comparison_scenario("poor_innovation_good_traditional", n = 500)
result2 <- posterior_inference(data2)
```

### Custom Parameters

```r
# Custom lambda parameters for more innovation
result <- posterior_inference(
  data,
  lambda_params = list(a = 1, b = 2),  # Higher λ on average
  n_outer = 100,
  n_inner = 50
)
```

## Dependencies

- dplyr, tidyr, purrr, tibble (data manipulation)
- ggplot2 (visualization)
- MCMCpack (Bayesian bootstrap)
- R6 (simulation classes)

## References

This package implements the method described in "Surrogate inference via random probability distributions" (in preparation).

## License

MIT License


