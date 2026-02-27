#!/usr/bin/env Rscript

#' Traditional Methods Comparison Simulation
#'
#' Compares the innovation approach with traditional surrogate evaluation methods
#' using the specific scenarios mentioned in the method paper.

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
set.seed(789)

cat("Running Traditional Methods Comparison Simulation\n")
cat("===============================================\n\n")

# Scenario 1: Good by innovation method, poor by traditional
cat("Scenario 1: Good by innovation method, poor by traditional\n")
cat("--------------------------------------------------------\n")

scenario1_params <- list(
  n = 500,
  n_classes = 2,
  class_probs = c(0.6, 0.4),
  treatment_effect_surrogate = c(0.8, 0.8),  # Strong, consistent
  treatment_effect_outcome = c(0.2, 0.9),    # Varies by class
  surrogate_type = "continuous",
  outcome_type = "continuous",
  covariate_effects = list(
    surrogate = c(0.3, 0.3),
    outcome = c(0.1, 0.1)
  ),
  scenario = "good_innovation_poor_traditional"
)

# Run scenario 1
sim1 <- ComparisonSimulation$new(scenario1_params, seed = 789)
sim1$generate_data()

cat("Current study treatment effects:\n")
current_effects1 <- compute_multiple_treatment_effects(sim1$data, c("S", "Y"))
print(current_effects1)

sim1$run_comparison(
  n_outer = 100,
  n_inner = 50,
  traditional_methods = c("pte", "correlation", "mediation")
)

cat("\nScenario 1 Results:\n")
cat(sim1$comparison_summary())
sim1$save_comparison("sims/results/", "scenario1_comparison.rds")

# Scenario 2: Poor by innovation method, good by traditional
cat("\n\nScenario 2: Poor by innovation method, good by traditional\n")
cat("--------------------------------------------------------\n")

scenario2_params <- list(
  n = 500,
  n_classes = 3,
  class_probs = c(0.4, 0.3, 0.3),
  treatment_effect_surrogate = c(0.5, 0.1, 0.9),  # Varies by class
  treatment_effect_outcome = c(0.4, 0.05, 0.8),   # Varies by class
  surrogate_type = "continuous",
  outcome_type = "continuous",
  covariate_effects = list(
    surrogate = c(0.2, 0.2, 0.2),
    outcome = c(0.1, 0.1, 0.1)
  ),
  scenario = "poor_innovation_good_traditional"
)

# Run scenario 2
sim2 <- ComparisonSimulation$new(scenario2_params, seed = 789)
sim2$generate_data()

cat("Current study treatment effects:\n")
current_effects2 <- compute_multiple_treatment_effects(sim2$data, c("S", "Y"))
print(current_effects2)

sim2$run_comparison(
  n_outer = 100,
  n_inner = 50,
  traditional_methods = c("pte", "correlation", "mediation")
)

cat("\nScenario 2 Results:\n")
cat(sim2$comparison_summary())
sim2$save_comparison("sims/results/", "scenario2_comparison.rds")

# Scenario 3: Mixture structure
cat("\n\nScenario 3: Mixture structure\n")
cat("-----------------------------\n")

scenario3_params <- list(
  n = 500,
  n_classes = 2,
  class_probs = c(0.5, 0.5),
  treatment_effect_surrogate = c(0.2, 0.8),
  treatment_effect_outcome = c(0.1, 0.7),
  surrogate_type = "continuous",
  outcome_type = "continuous",
  covariate_effects = list(
    surrogate = c(0.4, 0.1),
    outcome = c(0.2, 0.05)
  ),
  scenario = "mixture_structure"
)

# Run scenario 3
sim3 <- ComparisonSimulation$new(scenario3_params, seed = 789)
sim3$generate_data()

cat("Current study treatment effects:\n")
current_effects3 <- compute_multiple_treatment_effects(sim3$data, c("S", "Y"))
print(current_effects3)

sim3$run_comparison(
  n_outer = 100,
  n_inner = 50,
  traditional_methods = c("pte", "correlation", "mediation")
)

cat("\nScenario 3 Results:\n")
cat(sim3$comparison_summary())
sim3$save_comparison("sims/results/", "scenario3_comparison.rds")

# Summary of all scenarios
cat("\n\nSummary of All Scenarios\n")
cat("========================\n")

scenarios <- list(
  "Good innovation, poor traditional" = sim1,
  "Poor innovation, good traditional" = sim2,
  "Mixture structure" = sim3
)

for (scenario_name in names(scenarios)) {
  sim <- scenarios[[scenario_name]]
  cat("\n", scenario_name, ":\n")
  cat("  Innovation correlation:", 
      round(sim$results$summary$correlation$mean, 3), "\n")
  cat("  Innovation probability:", 
      round(sim$results$summary$probability$mean, 3), "\n")
  cat("  Traditional correlation:", 
      round(sim$comparison_results$correlation, 3), "\n")
  cat("  Traditional PTE:", 
      round(sim$comparison_results$pte, 3), "\n")
}

cat("\nTraditional methods comparison completed!\n")
cat("Results saved to sims/results/\n")


