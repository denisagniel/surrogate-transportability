#!/usr/bin/env Rscript

#' Continuous Surrogate Simulation
#'
#' Simulates surrogate evaluation with continuous surrogate and outcome variables.
#' Demonstrates the innovation approach on continuous data scenarios.

# Load required packages
library(devtools)
library(dplyr)
library(tibble)
library(purrr)

# Load the surrogate transportability package
devtools::load_all("package/", quiet = TRUE)

# Source the R6 simulation classes
source("sims/classes/SurrogateSimulation.R")
source("sims/classes/ComparisonSimulation.R")

# Set random seed for reproducibility
set.seed(456)

cat("Running Continuous Surrogate Simulation\n")
cat("======================================\n\n")

# Simulation parameters for continuous data
sim_params <- list(
  n = 500,
  n_classes = 2,
  class_probs = c(0.5, 0.5),
  treatment_effect_surrogate = c(0.5, 1.2),
  treatment_effect_outcome = c(0.3, 0.9),
  surrogate_type = "continuous",
  outcome_type = "continuous",
  covariate_effects = list(
    surrogate = c(0.3, 0.4),
    outcome = c(0.1, 0.2)
  ),
  noise_sd = 0.5,
  scenario = "continuous_surrogate"
)

# Create simulation object
sim <- SurrogateSimulation$new(sim_params, seed = 456)

# Generate data
cat("Generating continuous surrogate data...\n")
sim$generate_data()

# Check data structure
cat("Data summary:\n")
print(summary(sim$data))
cat("\nTreatment effects in current study:\n")
current_effects <- compute_multiple_treatment_effects(sim$data, c("S", "Y"))
print(current_effects)

# Run simulation
cat("\nRunning innovation approach simulation...\n")
sim$run(
  n_outer = 100,
  n_inner = 50,
  functional_type = "all",
  epsilon_s = 0.2,
  epsilon_y = 0.1
)

# Analyze results
cat("\nAnalyzing results...\n")
analysis <- sim$analyze()

# Print summary
cat("\nSimulation Summary:\n")
cat(sim$summary())

# Save results
cat("\nSaving results...\n")
sim$save("sims/results/", "continuous_surrogate_simulation.rds")

# Create comparison with traditional methods
cat("\nRunning comparison with traditional methods...\n")
comparison_sim <- ComparisonSimulation$new(sim_params, seed = 456)
comparison_sim$data <- sim$data  # Use same data

comparison_sim$run_comparison(
  n_outer = 100,
  n_inner = 50,
  traditional_methods = c("pte", "correlation", "mediation")
)

# Print comparison summary
cat("\nComparison Summary:\n")
cat(comparison_sim$comparison_summary())

# Save comparison results
comparison_sim$save_comparison("sims/results/", "continuous_surrogate_comparison.rds")

cat("\nContinuous surrogate simulation completed!\n")
cat("Results saved to sims/results/\n")


