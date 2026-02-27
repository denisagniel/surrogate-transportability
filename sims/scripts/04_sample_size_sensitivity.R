#!/usr/bin/env Rscript

#' Sample Size Sensitivity Simulation
#'
#' Evaluates how the innovation approach performs across different sample sizes
#' to assess sensitivity and power.

# Load required packages
library(devtools)
library(dplyr)
library(tibble)
library(purrr)

# Load the surrogate transportability package
devtools::load_all("package/", quiet = TRUE)

# Source the R6 simulation classes
source("sims/classes/SurrogateSimulation.R")

# Set random seed for reproducibility
set.seed(101112)

cat("Running Sample Size Sensitivity Simulation\n")
cat("========================================\n\n")

# Sample sizes to test
sample_sizes <- c(100, 250, 500, 1000, 2000)

# Base parameters
base_params <- list(
  n_classes = 2,
  class_probs = c(0.5, 0.5),
  treatment_effect_surrogate = c(0.5, 0.8),
  treatment_effect_outcome = c(0.3, 0.6),
  surrogate_type = "continuous",
  outcome_type = "continuous",
  covariate_effects = list(
    surrogate = c(0.3, 0.3),
    outcome = c(0.1, 0.1)
  ),
  noise_sd = 0.5
)

# Storage for results
sensitivity_results <- tibble::tibble(
  sample_size = integer(),
  correlation_mean = numeric(),
  correlation_sd = numeric(),
  correlation_q025 = numeric(),
  correlation_q975 = numeric(),
  probability_mean = numeric(),
  probability_sd = numeric(),
  probability_q025 = numeric(),
  probability_q975 = numeric(),
  run_time = numeric()
)

# Run simulation for each sample size
for (n in sample_sizes) {
  cat("Running simulation for sample size:", n, "\n")
  
  # Update parameters with current sample size
  params <- base_params
  params$n <- n
  params$scenario <- paste0("sample_size_", n)
  
  # Create simulation object
  sim <- SurrogateSimulation$new(params, seed = 101112)
  
  # Record start time
  start_time <- Sys.time()
  
  # Generate data
  sim$generate_data()
  
  # Run simulation with fewer iterations for larger sample sizes
  n_outer <- if (n <= 500) 100 else 50
  n_inner <- if (n <= 500) 50 else 25
  
  sim$run(
    n_outer = n_outer,
    n_inner = n_inner,
    functional_type = "all",
    epsilon_s = 0.2,
    epsilon_y = 0.1
  )
  
  # Record end time
  end_time <- Sys.time()
  run_time <- as.numeric(difftime(end_time, start_time, units = "secs"))
  
  # Extract results
  correlation_summary <- sim$results$summary$correlation
  probability_summary <- sim$results$summary$probability
  
  # Store results
  sensitivity_results <- sensitivity_results %>%
    dplyr::add_row(
      sample_size = n,
      correlation_mean = correlation_summary$mean,
      correlation_sd = correlation_summary$sd,
      correlation_q025 = correlation_summary$q025,
      correlation_q975 = correlation_summary$q975,
      probability_mean = probability_summary$mean,
      probability_sd = probability_summary$sd,
      probability_q025 = probability_summary$q025,
      probability_q975 = probability_summary$q975,
      run_time = run_time
    )
  
  # Save individual results
  sim$save("sims/results/", paste0("sample_size_", n, "_simulation.rds"))
  
  cat("  Correlation functional:", round(correlation_summary$mean, 3), 
      "(", round(correlation_summary$q025, 3), ",", 
      round(correlation_summary$q975, 3), ")\n")
  cat("  Probability functional:", round(probability_summary$mean, 3),
      "(", round(probability_summary$q025, 3), ",", 
      round(probability_summary$q975, 3), ")\n")
  cat("  Run time:", round(run_time, 2), "seconds\n\n")
}

# Print summary table
cat("Sample Size Sensitivity Results\n")
cat("==============================\n")
print(sensitivity_results)

# Save sensitivity results
saveRDS(sensitivity_results, "sims/results/sample_size_sensitivity_results.rds")

# Create summary plots (if ggplot2 is available)
if (requireNamespace("ggplot2", quietly = TRUE)) {
  library(ggplot2)
  
  # Correlation functional plot
  p1 <- ggplot(sensitivity_results, aes(x = sample_size, y = correlation_mean)) +
    geom_point() +
    geom_errorbar(aes(ymin = correlation_q025, ymax = correlation_q975)) +
    geom_line() +
    labs(
      title = "Correlation Functional by Sample Size",
      x = "Sample Size",
      y = "Correlation Functional"
    ) +
    theme_minimal()
  
  # Probability functional plot
  p2 <- ggplot(sensitivity_results, aes(x = sample_size, y = probability_mean)) +
    geom_point() +
    geom_errorbar(aes(ymin = probability_q025, ymax = probability_q975)) +
    geom_line() +
    labs(
      title = "Probability Functional by Sample Size",
      x = "Sample Size",
      y = "Probability Functional"
    ) +
    theme_minimal()
  
  # Run time plot
  p3 <- ggplot(sensitivity_results, aes(x = sample_size, y = run_time)) +
    geom_point() +
    geom_line() +
    labs(
      title = "Run Time by Sample Size",
      x = "Sample Size",
      y = "Run Time (seconds)"
    ) +
    theme_minimal()
  
  # Save plots
  ggsave("sims/results/correlation_by_sample_size.png", p1, width = 8, height = 6)
  ggsave("sims/results/probability_by_sample_size.png", p2, width = 8, height = 6)
  ggsave("sims/results/runtime_by_sample_size.png", p3, width = 8, height = 6)
  
  cat("Plots saved to sims/results/\n")
}

# Summary statistics
cat("\nSummary Statistics\n")
cat("==================\n")
cat("Correlation functional range:", 
    round(range(sensitivity_results$correlation_mean), 3), "\n")
cat("Probability functional range:", 
    round(range(sensitivity_results$probability_mean), 3), "\n")
cat("Total run time:", 
    round(sum(sensitivity_results$run_time), 2), "seconds\n")

cat("\nSample size sensitivity simulation completed!\n")
cat("Results saved to sims/results/\n")


