#!/usr/bin/env Rscript
# Lambda Sensitivity Local Test
#
# Quick test with reduced replications to verify code works before cluster submission
# Runs 10 reps per condition (vs 1000 for full study) for rapid testing
#
# Usage: Rscript lambda_sensitivity_local_test.R

library(dplyr)
library(yaml)

cat("=== Lambda Sensitivity Local Test ===\n")
cat("Purpose: Verify code works before cluster submission\n")
cat("Using: 10 reps per condition (vs 1000 for full study)\n\n")

# Load package
suppressMessages(library(surrogateTransportability))

# Load config
config <- yaml::read_yaml("cluster/config/dgp_specifications.yaml")
sim_settings <- config$simulation_settings

# Test configuration
lambdas <- c(0.1, 0.3, 0.5)  # Subset for testing
dgps <- c("dgp1", "dgp2")     # Subset for testing
n_reps <- 10                  # Reduced for testing

cat(sprintf("Testing %d conditions (3 lambda × 2 DGPs)\n", length(lambdas) * length(dgps)))
cat(sprintf("Replications per condition: %d\n", n_reps))
cat(sprintf("Total replications: %d\n\n", length(lambdas) * length(dgps) * n_reps))

# DGP function
generate_dgp_data <- function(n, p_X, params, X_levels) {
  X <- sample(X_levels, size = n, replace = TRUE, prob = p_X)
  A <- rbinom(n, 1, 0.5)
  S <- (params$gamma_A + params$gamma_AX * X) * A + rnorm(n, sd = params$sigma_S)
  Y <- (params$beta_A + params$beta_AX * X) * A + params$beta_S * S +
       params$beta_SX * S * X + rnorm(n, sd = params$sigma_Y)
  data.frame(X = X, A = A, S = S, Y = Y)
}

# Run test
test_start <- Sys.time()

for (lambda in lambdas) {
  for (dgp_id in dgps) {
    cat(sprintf("\n--- Testing lambda=%.1f, %s ---\n", lambda, dgp_id))

    dgp_config <- config$dgps[[dgp_id]]
    results_list <- list()

    for (rep in 1:n_reps) {
      set.seed(30000 + rep + lambda * 1000 + match(dgp_id, dgps) * 100)

      data <- generate_dgp_data(
        n = sim_settings$sample_size,
        p_X = unlist(dgp_config$p_X),
        params = dgp_config$params,
        X_levels = unlist(dgp_config$X_levels)
      )

      result <- tv_ball_correlation_IF_adaptive(
        data = data,
        lambda = lambda,
        M_start = sim_settings$M_start,
        M_increment = sim_settings$M_increment,
        M_max = sim_settings$M_max,
        tolerance = sim_settings$tolerance,
        n_stable = sim_settings$n_stable,
        burn_in = sim_settings$burn_in,
        thin = sim_settings$thin,
        alpha = sim_settings$alpha,
        method = sim_settings$method,
        verbose = FALSE
      )

      results_list[[rep]] <- result$rho_hat
    }

    cat(sprintf("  Mean ρ̂ = %.3f (SD = %.3f)\n",
                mean(unlist(results_list)),
                sd(unlist(results_list))))
  }
}

test_time <- as.numeric(difftime(Sys.time(), test_start, units = "mins"))

cat(sprintf("\n=== Test Complete ===\n"))
cat(sprintf("Total time: %.1f minutes\n", test_time))
cat(sprintf("Time per condition: %.1f minutes\n",
            test_time / (length(lambdas) * length(dgps))))
cat(sprintf("Estimated full study time (local, 8 cores): %.1f hours\n",
            test_time / (length(lambdas) * length(dgps)) * 20 * (1000 / n_reps) / 8))
cat("\nIf test successful, submit to cluster:\n")
cat("  bash cluster/slurm/launch_lambda_sensitivity.sh\n")
