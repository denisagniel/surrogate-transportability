#!/usr/bin/env Rscript
# Quick test version of Wasserstein minimax simulation study (50 reps for speed)

library(tidyverse)
source("package/R/wasserstein_minimax_IF_inference.R")
set.seed(2026)

# DGP
generate_data_linear <- function(n) {
  X <- rnorm(n, mean = 0, sd = 1)
  A <- rbinom(n, 1, 0.5)
  tau_S <- 0.3 + 0.2 * X
  tau_Y <- 0.4 + 0.3 * X
  S <- A * tau_S + rnorm(n, sd = 0.5)
  Y <- A * tau_Y + rnorm(n, sd = 0.5)
  data.frame(X = X, A = A, S = S, Y = Y,
             tau_S_true = tau_S, tau_Y_true = tau_Y)
}

# Compute truth
compute_truth <- function(gamma, tau) {
  large_data <- generate_data_linear(10000)
  h_oracle <- large_data$tau_S_true * large_data$tau_Y_true
  X <- large_data$X
  n_large <- length(X)

  phi_j <- numeric(n_large)
  for (j in 1:n_large) {
    costs <- (X - X[j])^2
    values <- exp(-(h_oracle + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }
  mean(phi_j)
}

# Quick test
cat("Quick Test: Wasserstein Minimax IF Inference\n")
cat("==============================================\n\n")

gamma <- 0.5
tau <- 0.1
n <- 500
n_sims <- 50

truth <- compute_truth(gamma, tau)
cat(sprintf("Truth: %.6f\n\n", truth))

cat("Running 50 simulations...\n")
results <- replicate(n_sims, {
  data <- generate_data_linear(n)
  result <- wasserstein_minimax_IF_inference(
    data = data, covariates = "X", gamma = gamma, tau = tau, K = 5
  )
  covered <- (truth >= result$ci_lower && truth <= result$ci_upper)
  c(estimate = result$phi_star, se = result$se, covered = covered)
}, simplify = FALSE)

results_df <- as.data.frame(do.call(rbind, results))

cat(sprintf("\nCoverage: %.1f%%\n", 100 * mean(results_df$covered)))
cat(sprintf("Mean estimate: %.6f\n", mean(results_df$estimate)))
cat(sprintf("Bias: %.6f\n", mean(results_df$estimate) - truth))
cat(sprintf("Empirical SE: %.6f\n", sd(results_df$estimate)))
cat(sprintf("Mean IF SE: %.6f\n", mean(results_df$se)))
cat(sprintf("Variance ratio: %.3f\n", mean(results_df$se) / sd(results_df$estimate)))
