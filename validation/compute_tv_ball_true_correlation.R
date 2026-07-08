#!/usr/bin/env Rscript
# Compute true correlation over TV ball for validation
#
# The estimand for tv_ball_correlation_IF() is:
#   ρ(μ_λ) = cor(ΔS(Q), ΔY(Q)) where Q ~ Uniform(B_λ(P₀))
#
# This is different from correlation across a broad range of studies!
# We need to compute the truth with very large n to compare against estimates.

library(tidyverse)
devtools::load_all()
source("validation/dgp_slides_pte_misleading.R")

compute_tv_ball_true_correlation <- function(lambda = 0.3,
                                              M_truth = 10000,
                                                n_per_study = 50000,
                                              seed = 20260508) {
  set.seed(seed)

  cat("Computing true correlation over TV ball...\n")
  cat(sprintf("  λ = %.2f\n", lambda))
  cat(sprintf("  M = %d (studies from TV ball)\n", M_truth))
  cat(sprintf("  n = %d (per study for stable effects)\n\n", n_per_study))

  # Generate P₀ data to define the ball center
  P0_data <- generate_dgp_slides(n_per_study, X_mean = 0, seed = seed)
  P0 <- table(P0_data$X) / nrow(P0_data)  # Empirical distribution (discretized)

  # Sample M distributions from TV ball
  cat("Step 1: Sampling distributions from TV ball...\n")
  Q_samples <- sample_tv_ball(
    P0 = P0,
    lambda = lambda,
    M = M_truth,
    burn_in = 2000,
    thin = 20,
    verbose = FALSE
  )

  # Compute treatment effects in each sampled study
  cat("Step 2: Computing treatment effects in each study...\n")
  Delta_S <- numeric(M_truth)
  Delta_Y <- numeric(M_truth)

  for (m in 1:M_truth) {
    if (m %% 1000 == 0) cat(sprintf("  Study %d / %d\n", m, M_truth))

    # Sample from Q_m with large n for stable effects
    Q_m <- Q_samples[m, ]

    # Generate data from this distribution
    # For slides DGP, Q is just P₀ with different X distribution
    # We approximate by sampling X from Q's implied X distribution

    # Q_m is a probability distribution over discretized X
    # Sample X according to Q_m weights
    X_bins <- as.numeric(names(Q_m))
    X_samples <- sample(X_bins, size = n_per_study, replace = TRUE, prob = Q_m)
    A_samples <- rbinom(n_per_study, 1, 0.5)

    # Generate S and Y given X and A (same DGP mechanism)
    gamma_A <- 1.0
    gamma_AX <- 0.5
    beta_A <- 0.25
    beta_AX <- -0.4
    beta_S <- 0.9
    beta_SX <- -0.05
    sigma_S <- 0.5
    sigma_Y <- 0.5

    S_samples <- (gamma_A + gamma_AX * X_samples) * A_samples +
                 rnorm(n_per_study, sd = sigma_S)
    Y_samples <- (beta_A + beta_AX * X_samples) * A_samples +
                 beta_S * S_samples + beta_SX * S_samples * X_samples +
                 rnorm(n_per_study, sd = sigma_Y)

    # Compute treatment effects
    Delta_S[m] <- mean(S_samples[A_samples == 1]) - mean(S_samples[A_samples == 0])
    Delta_Y[m] <- mean(Y_samples[A_samples == 1]) - mean(Y_samples[A_samples == 0])
  }

  # Compute correlation
  rho_true <- cor(Delta_S, Delta_Y)

  cat("\n=== TRUE CORRELATION OVER TV BALL ===\n")
  cat(sprintf("λ = %.2f\n", lambda))
  cat(sprintf("ρ_true = %.4f\n", rho_true))
  cat(sprintf("Mean ΔS = %.4f (SD: %.4f)\n", mean(Delta_S), sd(Delta_S)))
  cat(sprintf("Mean ΔY = %.4f (SD: %.4f)\n", mean(Delta_Y), sd(Delta_Y)))
  cat("\n")

  list(
    rho_true = rho_true,
    Delta_S = Delta_S,
    Delta_Y = Delta_Y,
    lambda = lambda,
    M = M_truth,
    n_per_study = n_per_study
  )
}

# Compute for validation
result <- compute_tv_ball_true_correlation(lambda = 0.3, M_truth = 5000)
saveRDS(result, "validation/results/tv_ball_true_correlation_lambda03.rds")
