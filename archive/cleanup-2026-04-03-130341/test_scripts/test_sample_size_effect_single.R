#!/usr/bin/env Rscript
# Single replication for sample size effect test (SLURM-compatible)
# Usage: Rscript test_sample_size_effect_single.R <n> <rep> <output_dir>

library(tidyverse)
library(here)

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 3) {
  stop("Usage: Rscript test_sample_size_effect_single.R <n> <rep> <output_dir>")
}

n <- as.integer(args[1])
rep <- as.integer(args[2])
output_dir <- args[3]

# Suppress package loading messages
suppressPackageStartupMessages({
  devtools::load_all(here("package"))
})

# =============================================================================
# Functions
# =============================================================================

compute_true_minimax <- function(X1, X2, tau_s_fn, tau_y_fn, lambda_w) {
  n <- length(X1)
  tau_s_true <- tau_s_fn(X1, X2)
  tau_y_true <- tau_y_fn(X1, X2)
  h_true <- tau_s_true * tau_y_true
  X <- scale(cbind(X1, X2))
  cost_matrix <- as.matrix(dist(X, method = "euclidean"))^2
  dual_objective <- function(gamma) {
    obj_matrix <- matrix(h_true, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }
  result <- optimize(dual_objective, interval = c(0, 100), maximum = TRUE, tol = 1e-6)
  result$objective
}

bootstrap_ci_observation_level <- function(data, covariates, lambda_w,
                                            tau_method = "kernel",
                                            n_bootstrap = 500,
                                            confidence_level = 0.95) {
  n <- nrow(data)
  point_est <- observation_level_minimax_wasserstein(
    data = data,
    covariates = covariates,
    lambda_w = lambda_w,
    tau_method = tau_method,
    cross_fit = TRUE,
    scale_covariates = TRUE
  )

  bootstrap_estimates <- numeric(n_bootstrap)
  for (b in 1:n_bootstrap) {
    boot_idx <- sample(1:n, size = n, replace = TRUE)
    boot_data <- data[boot_idx, ]
    boot_result <- tryCatch({
      observation_level_minimax_wasserstein(
        data = boot_data,
        covariates = covariates,
        lambda_w = lambda_w,
        tau_method = tau_method,
        cross_fit = FALSE,
        scale_covariates = TRUE
      )
    }, error = function(e) list(phi_star = NA))
    bootstrap_estimates[b] <- boot_result$phi_star
  }

  bootstrap_estimates <- bootstrap_estimates[!is.na(bootstrap_estimates)]
  alpha <- 1 - confidence_level
  ci_lower <- quantile(bootstrap_estimates, alpha/2)
  ci_upper <- quantile(bootstrap_estimates, 1 - alpha/2)

  list(
    phi_star = point_est$phi_star,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    n_bootstrap_successful = length(bootstrap_estimates)
  )
}

# =============================================================================
# Run single replication
# =============================================================================

lambda_w <- 0.5
tau_s_fn <- function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2
tau_y_fn <- function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2

set.seed(rep + 5000 + n)

# Generate data
X1 <- rnorm(n)
X2 <- rnorm(n)
A <- rbinom(n, 1, 0.5)
tau_s_true <- tau_s_fn(X1, X2)
tau_y_true <- tau_y_fn(X1, X2)
S <- tau_s_true * A + 0.5 + 0.2 * X1 + rnorm(n, sd = 0.3)
Y <- tau_y_true * A + 0.6 + 0.3 * X2 + rnorm(n, sd = 0.4)
data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

# Compute truth and estimate
truth <- compute_true_minimax(X1, X2, tau_s_fn, tau_y_fn, lambda_w)

result <- tryCatch({
  bootstrap_ci_observation_level(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = lambda_w,
    tau_method = "kernel",
    n_bootstrap = 500,
    confidence_level = 0.95
  )
}, error = function(e) NULL)

if (is.null(result)) {
  output <- tibble(n = n, rep = rep, status = "failed")
} else {
  covered <- (truth >= result$ci_lower & truth <= result$ci_upper)
  output <- tibble(
    n = n,
    rep = rep,
    status = "success",
    truth = truth,
    estimate = result$phi_star,
    ci_lower = result$ci_lower,
    ci_upper = result$ci_upper,
    covered = covered,
    ci_width = result$ci_upper - result$ci_lower,
    bias = result$phi_star - truth,
    n_bootstrap_successful = result$n_bootstrap_successful
  )
}

# Save output
output_file <- file.path(output_dir, sprintf("result_n%d_rep%03d.rds", n, rep))
saveRDS(output, output_file)
cat("Saved:", output_file, "\n")
