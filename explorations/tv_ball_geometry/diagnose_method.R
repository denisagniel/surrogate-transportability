#!/usr/bin/env Rscript
# Diagnose what's happening with effect estimation

suppressPackageStartupMessages(library(tidyverse))
source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")
source("explorations/tv_ball_geometry/13_method_validation_scenarios.R")

# Generate scenario 2 (uncorrelated)
cat("DIAGNOSTICS: Uncorrelated Effects Scenario\n")
cat("===========================================\n\n")

current <- generate_current_study(n = 2000, K = 10, rho_effect = 0.0)

cat("True type-level effects:\n")
cat(sprintf("  cor(τ_S, τ_Y) = %.3f\n\n", current$true_cor))

# Estimate from data
effects <- estimate_effects(current$data, K = 10)

cat("Estimated type-level effects:\n")
cat(sprintf("  cor(τ̂_S, τ̂_Y) = %.3f\n\n", cor(effects$tau_S_hat, effects$tau_Y_hat)))

cat("Comparison of true vs estimated:\n")
comparison <- tibble(
  type = 1:10,
  tau_S_true = current$tau_S,
  tau_S_hat = effects$tau_S_hat,
  tau_Y_true = current$tau_Y,
  tau_Y_hat = effects$tau_Y_hat
)
print(comparison, n = Inf)

cat("\nEstimation error:\n")
cat(sprintf("  RMSE(τ̂_S): %.3f\n", sqrt(mean((effects$tau_S_hat - current$tau_S)^2))))
cat(sprintf("  RMSE(τ̂_Y): %.3f\n", sqrt(mean((effects$tau_Y_hat - current$tau_Y)^2))))

cat("\nScatter plots:\n")
cat(sprintf("  cor(τ_S_true, τ̂_S) = %.3f\n", cor(current$tau_S, effects$tau_S_hat)))
cat(sprintf("  cor(τ_Y_true, τ̂_Y) = %.3f\n", cor(current$tau_Y, effects$tau_Y_hat)))

# Now apply TV ball method with TRUE effects (oracle)
cat("\n\nOracle (using true effects):\n")
cat("============================\n\n")

Q_samples <- hit_and_run_tv_ball(
  P0 = current$P0,
  lambda = 0.3,
  n_samples = 1000,
  burn_in = 1000,
  thin = 10,
  verbose = FALSE
)

Delta_S_oracle <- Q_samples %*% current$tau_S
Delta_Y_oracle <- Q_samples %*% current$tau_Y

cor_oracle <- cor(Delta_S_oracle, Delta_Y_oracle)
cat(sprintf("  Across-study correlation (oracle): %.3f\n", cor_oracle))

# With estimated effects
Delta_S_est <- Q_samples %*% effects$tau_S_hat
Delta_Y_est <- Q_samples %*% effects$tau_Y_hat

cor_est <- cor(Delta_S_est, Delta_Y_est)
cat(sprintf("  Across-study correlation (estimated): %.3f\n", cor_est))

cat(sprintf("\nBias due to estimation: %.3f\n", cor_est - cor_oracle))

cat("\n\nConclusion:\n")
if (abs(cor_oracle) < 0.2) {
  cat("✓ Oracle correctly identifies uncorrelated effects\n")
} else {
  cat("✗ Oracle fails (problem with DGP)\n")
}

if (abs(cor_est - cor_oracle) < 0.1) {
  cat("✓ Estimation error is small\n")
} else {
  cat(sprintf("✗ Estimation error is large (%.3f)\n", cor_est - cor_oracle))
  cat("  → Need larger sample size or better estimates\n")
}
