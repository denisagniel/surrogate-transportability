#!/usr/bin/env Rscript
#' Study 2: Stress Testing - Single Array Task
#'
#' Runs one stress condition for the given SLURM_ARRAY_TASK_ID

library(tidyverse)
library(here)

# Load package
devtools::load_all(here("package"))

# Get task ID from Slurm
task_id <- as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID", "1"))

# Simulation parameters
N_REPS <- as.integer(Sys.getenv("N_REPS", "500"))

# Baseline parameters
BASELINE <- list(n = 500, lambda = 0.3, J = 16, rho = 0.7, cv = 0.3)

# Define all stress conditions (21 total)
stress_conditions <- bind_rows(
  # 1. Small sample (3 conditions)
  expand_grid(
    stress_type = "small_sample",
    n = c(50, 100, 150),
    lambda = BASELINE$lambda,
    J = BASELINE$J,
    rho = BASELINE$rho,
    cv = BASELINE$cv
  ),
  # 2. Extreme lambda (4 conditions)
  expand_grid(
    stress_type = "extreme_lambda",
    n = BASELINE$n,
    lambda = c(0.6, 0.7, 0.8, 0.9),
    J = BASELINE$J,
    rho = BASELINE$rho,
    cv = BASELINE$cv
  ),
  # 3. Discretization (6 conditions)
  expand_grid(
    stress_type = "discretization",
    n = BASELINE$n,
    lambda = BASELINE$lambda,
    J = c(4, 6, 9, 16, 25, 36),
    rho = BASELINE$rho,
    cv = BASELINE$cv
  ),
  # 4. Weak signal (4 conditions)
  expand_grid(
    stress_type = "weak_signal",
    n = BASELINE$n,
    lambda = BASELINE$lambda,
    J = BASELINE$J,
    rho = c(0.05, 0.1, 0.15, 0.2),
    cv = BASELINE$cv
  ),
  # 5. High heterogeneity (4 conditions)
  expand_grid(
    stress_type = "high_heterogeneity",
    n = BASELINE$n,
    lambda = BASELINE$lambda,
    J = BASELINE$J,
    rho = BASELINE$rho,
    cv = c(0.6, 0.7, 0.8, 0.9)
  )
) %>%
  mutate(task_id = row_number())

# Get parameters for this task
params <- stress_conditions %>% filter(task_id == !!task_id)

if (nrow(params) == 0) {
  stop("Invalid task_id: ", task_id)
}

cat("========================================\n")
cat("Study 2 - Task", task_id, "of", nrow(stress_conditions), "\n")
cat("========================================\n")
cat("Stress type:", params$stress_type, "\n")
cat("n:", params$n, "| lambda:", params$lambda, "| J:", params$J, "\n")
cat("rho:", params$rho, "| cv:", params$cv, "\n")
cat("Replications:", N_REPS, "\n")
cat("\n")

# Data generation function
generate_stress_data <- function(n, J, rho, cv, seed) {
  set.seed(seed)

  tau_y <- rnorm(J, mean = 0.5, sd = cv)
  tau_s <- rho * tau_y + sqrt(1 - rho^2) * rnorm(J, sd = cv)

  pi_types <- rep(1/J, J)

  types <- sample(1:J, size = n, replace = TRUE, prob = pi_types)
  A <- rbinom(n, 1, 0.5)
  X <- rnorm(n)

  S <- tau_s[types] * A + 0.3 * X + rnorm(n, sd = 0.5)
  Y <- tau_y[types] * A + 0.2 * X + rnorm(n, sd = 0.4)

  data <- tibble(type = types, A = A, X = X, S = S, Y = Y)

  list(data = data, tau_s = tau_s, tau_y = tau_y,
       true_concordance = mean(tau_s * tau_y))
}

run_single_replication <- function(rep, params) {
  dgp <- generate_stress_data(params$n, params$J, params$rho, params$cv, seed = rep)

  result <- tryCatch({
    est <- surrogate_inference_minimax(
      current_data = dgp$data,
      lambda = params$lambda,
      functional_type = "concordance",
      discretization_schemes = c("rf", "quantiles", "kmeans"),
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
      rep = rep, estimate = NA_real_, se = NA_real_,
      ci_lower = NA_real_, ci_upper = NA_real_,
      truth = dgp$true_concordance, bias = NA_real_,
      covered = NA, ci_width = NA_real_, success = FALSE,
      error_msg = conditionMessage(e)
    )
  })

  result
}

# Run replications
cat("Running", N_REPS, "replications...\n")
start_time <- Sys.time()

results <- map_dfr(
  1:N_REPS,
  ~run_single_replication(., params),
  .progress = TRUE
)

elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
cat("\nCompleted in", round(elapsed, 1), "minutes\n")

# Add parameter info
results <- results %>%
  mutate(
    task_id = task_id,
    stress_type = params$stress_type,
    n = params$n,
    lambda = params$lambda,
    J = params$J,
    rho = params$rho,
    cv = params$cv
  )

# Save results
output_dir <- here("sims/results/study2_array")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
output_file <- file.path(output_dir, sprintf("task_%03d.rds", task_id))

saveRDS(results, output_file)

cat("\nResults saved to:", output_file, "\n")
cat("Success rate:", mean(results$success), "\n")
cat("========================================\n")
