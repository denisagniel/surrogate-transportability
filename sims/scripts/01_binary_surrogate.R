#!/usr/bin/env Rscript

#' Binary Surrogate Simulation
#'
#' Simulates surrogate evaluation with binary surrogate and outcome variables.
#' Demonstrates the innovation approach on binary data scenarios.

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
set.seed(123)

cat("Running Binary Surrogate Simulation\n")
cat("==================================\n\n")

# Simulation parameters
sim_params <- list(
  n = 500,
  n_classes = 2,
  class_probs = c(0.6, 0.4),
  treatment_effect_surrogate = c(0.3, 0.7),
  treatment_effect_outcome = c(0.2, 0.8),
  surrogate_type = "binary",
  outcome_type = "binary",
  covariate_effects = list(
    surrogate = c(0.2, 0.3),
    outcome = c(0.1, 0.15)
  ),
  scenario = "binary_surrogate"
)

# Create simulation object
sim <- SurrogateSimulation$new(sim_params, seed = 123)

# Generate data
cat("Generating binary surrogate data...\n")
sim$generate_data()

# Check data structure
cat("Data summary:\n")
print(summary(sim$data))
cat("\nTreatment effects in current study:\n")
current_effects <- compute_multiple_treatment_effects(sim$data, c("S", "Y"))
print(current_effects)

# Run simulation with fixed lambda
cat("\nRunning innovation approach simulation with fixed lambda = 0.3...\n")
sim$run(
  n_draws_from_F = 500,
  n_future_studies_per_draw = 200,
  lambda = 0.3,  # Fixed perturbation distance
  functional_type = "all",
  epsilon_s = 0.1,
  epsilon_y = 0.05
)

# Analyze results
cat("\nAnalyzing results...\n")
analysis <- sim$analyze()

# Print summary
cat("\nSimulation Summary:\n")
cat(sim$summary())

# Save results
cat("\nSaving results...\n")
sim$save("sims/results/", "binary_surrogate_simulation.rds")

# Create comparison with traditional methods
cat("\nRunning comparison with traditional methods...\n")
comparison_sim <- ComparisonSimulation$new(sim_params, seed = 123)
comparison_sim$data <- sim$data  # Use same data

comparison_sim$run_comparison(
  n_draws_from_F = 500,
  n_future_studies_per_draw = 200,
  lambda = 0.3,  # Fixed perturbation distance
  traditional_methods = c("pte", "correlation", "mediation")
)

# Print comparison summary
cat("\nComparison Summary:\n")
cat(comparison_sim$comparison_summary())

# Save comparison results
comparison_sim$save_comparison("sims/results/", "binary_surrogate_comparison.rds")

cat("\nBinary surrogate simulation completed!\n")
cat("Results saved to sims/results/\n")
