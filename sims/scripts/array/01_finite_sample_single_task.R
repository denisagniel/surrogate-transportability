#!/usr/bin/env Rscript
#' Study 1: Finite Sample Performance - Single Array Task
#'
#' Runs one parameter setting for the given SLURM_ARRAY_TASK_ID
#' No parallelization - each task is one job

library(tidyverse)
library(here)

# Load package
devtools::load_all(here("package"))

# Get task ID from Slurm
task_id <- as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID", "1"))

# Simulation parameters
N_REPS <- as.integer(Sys.getenv("N_REPS", "500"))

# Define all parameter combinations (48 total)
param_grid <- expand_grid(
  sample_size = c(250, 500, 1000, 2000),
  scenario = c("low_het_high_cor", "mod_het_mod_cor", "high_het_low_cor"),
  lambda = c(0.1, 0.2, 0.3, 0.4)
) %>%
  mutate(task_id = row_number())

# Scenario parameters
scenario_params <- list(
  low_het_high_cor = list(cv = 0.1, rho = 0.9, name = "Low het, high cor"),
  mod_het_mod_cor = list(cv = 0.3, rho = 0.7, name = "Moderate het, moderate cor"),
  high_het_low_cor = list(cv = 0.5, rho = 0.4, name = "High het, low cor")
)

# Get parameters for this task
params <- param_grid %>% filter(task_id == !!task_id)

if (nrow(params) == 0) {
  stop("Invalid task_id: ", task_id)
}

cat("========================================\n")
cat("Study 1 - Task", task_id, "of", nrow(param_grid), "\n")
cat("========================================\n")
cat("Sample size:", params$sample_size, "\n")
cat("Scenario:", params$scenario, "\n")
cat("Lambda:", params$lambda, "\n")
cat("Replications:", N_REPS, "\n")
cat("\n")

# Run replications for this setting
J <- 16
scenario <- scenario_params[[params$scenario]]

generate_scenario_data <- function(n, J, scenario_params, seed) {
  set.seed(seed)

  # Generate treatment effects
  tau_y <- rnorm(J, mean = 0.5, sd = scenario_params$cv)
  tau_s <- scenario_params$rho * tau_y +
    sqrt(1 - scenario_params$rho^2) * rnorm(J, sd = scenario_params$cv)

  # Type probabilities
  pi_types <- rep(1/J, J)

  # Generate data
  types <- sample(1:J, size = n, replace = TRUE, prob = pi_types)
  A <- rbinom(n, 1, 0.5)
  X <- rnorm(n)

  S <- tau_s[types] * A + 0.3 * X + rnorm(n, sd = 0.5)
  Y <- tau_y[types] * A + 0.2 * X + rnorm(n, sd = 0.4)

  data <- tibble(type = types, A = A, X = X, S = S, Y = Y)

  list(
    data = data,
    tau_s = tau_s,
    tau_y = tau_y,
    true_concordance = mean(tau_s * tau_y)
  )
}

run_single_replication <- function(rep, n, J, scenario_params, lambda) {
  # Generate data
  dgp <- generate_scenario_data(n, J, scenario_params, seed = rep)

  # Estimate
  result <- tryCatch({
    est <- surrogate_inference_minimax(
      current_data = dgp$data,
      lambda = lambda,
      functional_type = "concordance",
      discretization_schemes = c("quantiles", "kmeans"),  # Skip RF (requires randomForest)
      n_bootstrap = 200,
      confidence_level = 0.95,
      verbose = FALSE
    )

    tibble(
      rep = rep,
      estimate = est$phi_star,
      se = NA_real_,  # Not provided by minimax
      ci_lower = est$ci_lower,
      ci_upper = est$ci_upper,
      truth = dgp$true_concordance,
      bias = est$phi_star - dgp$true_concordance,
      covered = (dgp$true_concordance >= est$ci_lower &
                   dgp$true_concordance <= est$ci_upper),
      ci_width = est$ci_upper - est$ci_lower,
      success = TRUE
    )
  }, error = function(e) {
    cat("ERROR in rep", rep, ":", conditionMessage(e), "\n")
    tibble(
      rep = rep,
      estimate = NA_real_,
      se = NA_real_,
      ci_lower = NA_real_,
      ci_upper = NA_real_,
      truth = dgp$true_concordance,
      bias = NA_real_,
      covered = NA,
      ci_width = NA_real_,
      success = FALSE,
      error_msg = conditionMessage(e)
    )
  })

  result
}

# Run all replications for this task
cat("Running", N_REPS, "replications...\n")
start_time <- Sys.time()

results <- map_dfr(
  1:N_REPS,
  ~run_single_replication(., params$sample_size, J, scenario, params$lambda),
  .progress = TRUE
)

elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
cat("\nCompleted in", round(elapsed, 1), "minutes\n")

# Add parameter info
results <- results %>%
  mutate(
    task_id = task_id,
    sample_size = params$sample_size,
    scenario = params$scenario,
    lambda = params$lambda
  )

# Save results
output_dir <- here("sims/results/study1_array")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
output_file <- file.path(output_dir, sprintf("task_%03d.rds", task_id))

saveRDS(results, output_file)

cat("\nResults saved to:", output_file, "\n")
cat("Success rate:", mean(results$success), "\n")
cat("========================================\n")
