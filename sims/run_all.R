#!/usr/bin/env Rscript

#' Master Script for Surrogate Transportability Simulations
#'
#' This script runs all simulation scenarios defined in the configuration.
#' It can be run from the command line or sourced in R.

# Load required packages
library(devtools)
library(dplyr)
library(tibble)
library(purrr)

# Check if yaml package is available
if (!requireNamespace("yaml", quietly = TRUE)) {
  cat("Warning: yaml package not available. Using default parameters.\n")
  use_yaml <- FALSE
} else {
  library(yaml)
  use_yaml <- TRUE
}

# Load the surrogate transportability package
devtools::load_all("package/", quiet = TRUE)

# Source the R6 simulation classes
source("sims/classes/SurrogateSimulation.R")
source("sims/classes/ComparisonSimulation.R")

# Function to run a single scenario
run_scenario <- function(scenario_name, scenario_params, sim_settings, seed = NULL) {
  
  cat("Running scenario:", scenario_name, "\n")
  cat("================================\n")
  
  # Set seed for reproducibility
  if (!is.null(seed)) {
    set.seed(seed)
  }
  
  # Add scenario name to parameters
  scenario_params$scenario <- scenario_name
  
  # Create simulation object
  sim <- SurrogateSimulation$new(scenario_params, seed = seed)
  
  # Generate data
  sim$generate_data()
  
  # Run simulation
  sim$run(
    n_outer = sim_settings$n_outer,
    n_inner = sim_settings$n_inner,
    functional_type = sim_settings$functional_type,
    epsilon_s = scenario_params$epsilon_s,
    epsilon_y = scenario_params$epsilon_y,
    lambda_params = sim_settings$lambda_params,
    innovation_type = sim_settings$innovation_type,
    study_type = sim_settings$study_type
  )
  
  # Save results
  sim$save("sims/results/", paste0(scenario_name, "_simulation.rds"))
  
  # Print summary
  cat(sim$summary())
  
  return(sim)
}

# Function to run comparison scenario
run_comparison_scenario <- function(scenario_name, scenario_params, sim_settings, seed = NULL) {
  
  cat("Running comparison scenario:", scenario_name, "\n")
  cat("=====================================\n")
  
  # Set seed for reproducibility
  if (!is.null(seed)) {
    set.seed(seed)
  }
  
  # Add scenario name to parameters
  scenario_params$scenario <- scenario_name
  
  # Create comparison simulation object
  sim <- ComparisonSimulation$new(scenario_params, seed = seed)
  
  # Generate data
  sim$generate_data()
  
  # Run comparison
  sim$run_comparison(
    n_outer = sim_settings$n_outer,
    n_inner = sim_settings$n_inner,
    traditional_methods = sim_settings$traditional_methods
  )
  
  # Save results
  sim$save_comparison("sims/results/", paste0(scenario_name, "_comparison.rds"))
  
  # Print summary
  cat(sim$comparison_summary())
  
  return(sim)
}

# Main execution function
main <- function() {
  
  cat("Surrogate Transportability Simulation Suite\n")
  cat("==========================================\n\n")
  
  # Load configuration
  if (use_yaml && file.exists("sims/config/scenarios.yaml")) {
    cat("Loading configuration from scenarios.yaml...\n")
    config <- yaml::read_yaml("sims/config/scenarios.yaml")
    scenarios <- config[names(config) != "simulation_settings"]
    sim_settings <- config$simulation_settings
  } else {
    cat("Using default configuration...\n")
    # Default scenarios
    scenarios <- list(
      binary_surrogate = list(
        n = 500,
        n_classes = 2,
        class_probs = c(0.6, 0.4),
        treatment_effect_surrogate = c(0.3, 0.7),
        treatment_effect_outcome = c(0.2, 0.8),
        surrogate_type = "binary",
        outcome_type = "binary",
        covariate_effects = list(surrogate = c(0.2, 0.3), outcome = c(0.1, 0.15)),
        epsilon_s = 0.1,
        epsilon_y = 0.05
      ),
      continuous_surrogate = list(
        n = 500,
        n_classes = 2,
        class_probs = c(0.5, 0.5),
        treatment_effect_surrogate = c(0.5, 1.2),
        treatment_effect_outcome = c(0.3, 0.9),
        surrogate_type = "continuous",
        outcome_type = "continuous",
        covariate_effects = list(surrogate = c(0.3, 0.4), outcome = c(0.1, 0.2)),
        epsilon_s = 0.2,
        epsilon_y = 0.1
      )
    )
    
    # Default simulation settings
    sim_settings <- list(
      n_outer = 100,
      n_inner = 50,
      functional_type = "all",
      lambda_params = list(a = 2, b = 5),
      innovation_type = "bayesian_bootstrap",
      study_type = "randomized",
      traditional_methods = c("pte", "correlation", "mediation")
    )
  }
  
  # Create results directory
  if (!dir.exists("sims/results/")) {
    dir.create("sims/results/", recursive = TRUE)
  }
  
  # Run scenarios
  results <- list()
  
  # Basic scenarios (innovation approach only)
  basic_scenarios <- c("binary_surrogate", "continuous_surrogate")
  
  for (scenario_name in basic_scenarios) {
    if (scenario_name %in% names(scenarios)) {
      results[[scenario_name]] <- run_scenario(
        scenario_name, 
        scenarios[[scenario_name]], 
        sim_settings, 
        seed = 123
      )
      cat("\n")
    }
  }
  
  # Comparison scenarios
  comparison_scenarios <- c(
    "good_innovation_poor_traditional",
    "poor_innovation_good_traditional", 
    "mixture_structure"
  )
  
  for (scenario_name in comparison_scenarios) {
    if (scenario_name %in% names(scenarios)) {
      results[[scenario_name]] <- run_comparison_scenario(
        scenario_name,
        scenarios[[scenario_name]],
        sim_settings,
        seed = 456
      )
      cat("\n")
    }
  }
  
  # Sample size sensitivity
  sample_size_scenarios <- names(scenarios)[grepl("^sample_size_", names(scenarios))]
  
  if (length(sample_size_scenarios) > 0) {
    cat("Running sample size sensitivity analysis...\n")
    cat("==========================================\n")
    
    sensitivity_results <- tibble::tibble(
      sample_size = integer(),
      correlation_mean = numeric(),
      correlation_sd = numeric(),
      probability_mean = numeric(),
      probability_sd = numeric(),
      run_time = numeric()
    )
    
    for (scenario_name in sample_size_scenarios) {
      start_time <- Sys.time()
      
      sim <- run_scenario(
        scenario_name,
        scenarios[[scenario_name]],
        sim_settings,
        seed = 789
      )
      
      end_time <- Sys.time()
      run_time <- as.numeric(difftime(end_time, start_time, units = "secs"))
      
      # Extract results
      correlation_summary <- sim$results$summary$correlation
      probability_summary <- sim$results$summary$probability
      
      # Extract sample size from scenario name
      sample_size <- as.integer(gsub("sample_size_", "", scenario_name))
      
      sensitivity_results <- sensitivity_results %>%
        dplyr::add_row(
          sample_size = sample_size,
          correlation_mean = correlation_summary$mean,
          correlation_sd = correlation_summary$sd,
          probability_mean = probability_summary$mean,
          probability_sd = probability_summary$sd,
          run_time = run_time
        )
      
      results[[scenario_name]] <- sim
    }
    
    # Save sensitivity results
    saveRDS(sensitivity_results, "sims/results/sample_size_sensitivity_summary.rds")
    
    cat("Sample size sensitivity results:\n")
    print(sensitivity_results)
    cat("\n")
  }
  
  # Create summary report
  cat("Simulation Suite Summary\n")
  cat("=======================\n")
  cat("Total scenarios run:", length(results), "\n")
  cat("Results saved to: sims/results/\n")
  
  # Save overall results
  saveRDS(results, "sims/results/all_simulation_results.rds")
  
  cat("\nAll simulations completed successfully!\n")
}

# Run main function if script is executed directly
if (!interactive()) {
  main()
}


