# Surrogate Transportability

A complete R project implementing surrogate inference via random probability distributions, including both an R package and comprehensive simulation environment.

## Project Overview

This project implements a novel statistical method for evaluating surrogate markers by modeling future studies as draws from a random probability measure. The approach addresses the fundamental question of surrogate transportability: "Will the treatment effect on the surrogate be informative about the treatment effect on the outcome in a new study on a new population?"

## Method Summary

The innovation approach models future studies as mixtures:
**Q = (1-λ)P₀ + λP̃**

where:
- P₀ is the current study distribution
- P̃ is the innovation distribution (Bayesian bootstrap)
- λ ~ Beta(a,b) controls similarity to current study

Key functionals evaluated:
1. **Correlation**: cor(ΔS(Q), ΔY(Q))
2. **Probability**: P(ΔY > εY | ΔS > εS)  
3. **Conditional Mean**: E[ΔY(Q) | ΔS(Q) = δ]

## Project Structure

```
surrogate-transportability/
├── README.md                           # This file
├── package/                            # R package implementation
│   ├── DESCRIPTION                     # Package metadata
│   ├── NAMESPACE                       # Package exports
│   ├── R/                              # Package functions
│   │   ├── data_generators.R           # Data generation with mixture structure
│   │   ├── generate_future_study.R     # Innovation approach implementation
│   │   ├── compute_treatment_effects.R # Treatment effect estimation
│   │   ├── surrogate_functionals.R     # Surrogate quality functionals
│   │   └── posterior_inference.R       # Main inference function
│   ├── tests/                          # Unit tests
│   └── README.md                       # Package documentation
├── sims/                               # Simulation environment
│   ├── classes/                        # R6 simulation classes
│   │   ├── SurrogateSimulation.R       # Base simulation class
│   │   └── ComparisonSimulation.R      # Method comparison class
│   ├── scripts/                        # Individual scenario scripts
│   │   ├── 01_binary_surrogate.R       # Binary surrogate simulation
│   │   ├── 02_continuous_surrogate.R   # Continuous surrogate simulation
│   │   ├── 03_comparison_traditional.R # Traditional methods comparison
│   │   └── 04_sample_size_sensitivity.R # Sample size analysis
│   ├── config/                         # Configuration files
│   │   └── scenarios.yaml              # Simulation parameters
│   ├── data/                           # Generated datasets (gitignored)
│   ├── results/                        # Simulation outputs (gitignored)
│   └── run_all.R                       # Master simulation script
├── methods/                            # Method documentation
│   └── main.tex                        # LaTeX method write-up
└── .gitignore                          # Git ignore rules
```

## Quick Start

### 1. Build the Package

```r
# Install dependencies
install.packages(c("devtools", "dplyr", "tidyr", "purrr", "tibble", 
                   "ggplot2", "MCMCpack", "R6", "testthat"))

# Build and install package
devtools::document("package/")
devtools::check("package/")
devtools::install("package/")
```

### 2. Run Simulations

```r
# Run all simulations
source("sims/run_all.R")

# Or run individual scenarios
source("sims/scripts/01_binary_surrogate.R")
source("sims/scripts/02_continuous_surrogate.R")
source("sims/scripts/03_comparison_traditional.R")
source("sims/scripts/04_sample_size_sensitivity.R")
```

### 3. Basic Usage

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

## Simulation Scenarios

The simulation suite includes several key scenarios from the method paper:

### 1. Basic Scenarios
- **Binary Surrogate**: Binary S and Y variables
- **Continuous Surrogate**: Continuous S and Y variables

### 2. Comparison Scenarios
- **Good Innovation, Poor Traditional**: Low PTE but high cross-study correlation
- **Poor Innovation, Good Traditional**: High within-study correlation but low cross-study correlation
- **Mixture Structure**: Clear latent classes with varying treatment effects

### 3. Sensitivity Analysis
- **Sample Size**: n ∈ {100, 250, 500, 1000, 2000}
- **Parameter Sensitivity**: Different λ parameters and innovation types

## Key Features

### Package Features
- **Flexible Data Generation**: Binary/continuous outcomes with mixture structure
- **Innovation Approach**: Q = (1-λ)P₀ + λP̃ mixture modeling
- **Multiple Functionals**: Correlation, probability, and conditional mean
- **Uncertainty Quantification**: Nested Bayesian bootstrap
- **Comparison Framework**: Traditional surrogate evaluation methods

### Simulation Features
- **R6 Classes**: Object-oriented simulation framework
- **Configuration System**: YAML-based parameter management
- **Parallel Processing**: Optional parallel execution
- **Comprehensive Testing**: Unit tests for all core functions
- **Reproducible Results**: Seed management and result saving

## Dependencies

### Required Packages
- **Core**: dplyr, tidyr, purrr, tibble, ggplot2
- **Bayesian**: MCMCpack
- **Classes**: R6
- **Testing**: testthat
- **Development**: devtools

### Optional Packages
- **Parallel**: future (for parallel processing)
- **Configuration**: yaml (for scenario configuration)
- **Traditional Methods**: Surrogate, Rsurrogate, pseval, mediation

## Usage Examples

### Basic Inference

```r
# Generate data
data <- generate_study_data(n = 500)

# Run inference
result <- posterior_inference(data, n_outer = 100, n_inner = 50)

# Extract functionals
correlation <- result$summary$correlation$mean
probability <- result$summary$probability$mean
```

### Method Comparison

```r
# Compare approaches
comparison <- compare_surrogate_methods(data)

# View comparison
print(comparison$innovation$summary)
print(comparison$traditional)
```

### Custom Scenarios

```r
# Custom parameters
data <- generate_study_data(
  n = 1000,
  n_classes = 3,
  treatment_effect_surrogate = c(0.3, 0.6, 0.9),
  treatment_effect_outcome = c(0.2, 0.4, 0.7)
)

# High innovation scenario
result <- posterior_inference(
  data,
  lambda_params = list(a = 1, b = 2),  # Higher λ
  n_outer = 200,
  n_inner = 100
)
```

## Results and Outputs

Simulation results are saved to `sims/results/` including:
- Individual scenario results (`.rds` files)
- Comparison summaries
- Sample size sensitivity analysis
- Generated plots (if ggplot2 available)

## Development

### Running Tests

```r
# Run package tests
devtools::test("package/")

# Check package
devtools::check("package/")
```

### Adding New Scenarios

1. Add parameters to `sims/config/scenarios.yaml`
2. Create new script in `sims/scripts/`
3. Update `sims/run_all.R` if needed

### Extending the Package

1. Add new functions to `package/R/`
2. Add corresponding tests to `package/tests/testthat/`
3. Update documentation with roxygen2
4. Run `devtools::document("package/")`

## References

This project implements the method described in "Surrogate inference via random probability distributions" (in preparation). The approach addresses limitations of traditional surrogate evaluation methods by explicitly modeling uncertainty about future study populations.

## License

MIT License

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## Contact

For questions or issues, please open an issue on the project repository.


