#!/usr/bin/env Rscript
# Test observation-level Wasserstein minimax (no discretization)

library(tidyverse)
library(here)

devtools::load_all(here("package"))

# Generate data with known treatment effect functions
generate_test_data <- function(n, seed = 123) {
  set.seed(seed)

  # Two covariates
  X1 <- rnorm(n)
  X2 <- rnorm(n)

  # Treatment assignment
  A <- rbinom(n, 1, 0.5)

  # TRUE treatment effect functions (heterogeneous by X)
  tau_s_true <- 0.3 + 0.2 * X1 - 0.1 * X2
  tau_y_true <- 0.4 + 0.3 * X1 + 0.1 * X2

  # Generate outcomes
  S <- tau_s_true * A + 0.5 + 0.2 * X1 + rnorm(n, sd = 0.3)
  Y <- tau_y_true * A + 0.6 + 0.3 * X2 + rnorm(n, sd = 0.4)

  data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

  # True concordance function
  concordance_true <- tau_s_true * tau_y_true
  true_mean_concordance <- mean(concordance_true)
  true_min_concordance <- min(concordance_true)

  list(
    data = data,
    tau_s_true = tau_s_true,
    tau_y_true = tau_y_true,
    concordance_true = concordance_true,
    true_mean_concordance = true_mean_concordance,
    true_min_concordance = true_min_concordance
  )
}

cat("========================================\n")
cat("TEST: Observation-Level Wasserstein\n")
cat("========================================\n\n")

# Generate test data
n <- 500
lambda_w <- 0.3

cat("Generating data with n =", n, "...\n")
test_data <- generate_test_data(n, seed = 42)

cat("\nTRUE PARAMETERS:\n")
cat("  Mean concordance: ", round(test_data$true_mean_concordance, 4), "\n")
cat("  Min concordance:  ", round(test_data$true_min_concordance, 4), "\n")
cat("  SD concordance:   ", round(sd(test_data$concordance_true), 4), "\n\n")

# Test observation-level approach
cat("TESTING OBSERVATION-LEVEL WASSERSTEIN:\n")
cat("  lambda_w =", lambda_w, "\n")
cat("  Method: kernel (default)\n")
cat("  Cross-fitting: TRUE\n\n")

result <- observation_level_minimax_wasserstein(
  data = test_data$data,
  covariates = c("X1", "X2"),
  lambda_w = lambda_w,
  tau_method = "kernel",
  cross_fit = TRUE,
  scale_covariates = TRUE
)

cat("\nRESULTS:\n")
cat("  Minimax estimate:  ", round(result$phi_star, 4), "\n")
cat("  Optimal gamma:     ", round(result$optimal_gamma, 4), "\n\n")

# Compare estimated tau to true tau
cat("TREATMENT EFFECT ESTIMATION QUALITY:\n")

rmse_tau_s <- sqrt(mean((result$tau_s_hat - test_data$tau_s_true)^2))
rmse_tau_y <- sqrt(mean((result$tau_y_hat - test_data$tau_y_true)^2))
cor_tau_s <- cor(result$tau_s_hat, test_data$tau_s_true)
cor_tau_y <- cor(result$tau_y_hat, test_data$tau_y_true)

cat("  tau_S: RMSE =", round(rmse_tau_s, 4), "| Cor =", round(cor_tau_s, 3), "\n")
cat("  tau_Y: RMSE =", round(rmse_tau_y, 4), "| Cor =", round(cor_tau_y, 3), "\n\n")

# Compare estimated concordance to true concordance
rmse_conc <- sqrt(mean((result$concordance_i - test_data$concordance_true)^2))
cor_conc <- cor(result$concordance_i, test_data$concordance_true)

cat("  Concordance: RMSE =", round(rmse_conc, 4), "| Cor =", round(cor_conc, 3), "\n\n")

# Theoretical check: what should the minimax be?
cat("THEORETICAL ANALYSIS:\n")

# For Wasserstein ball, the minimax depends on lambda_w and the cost structure
# A rough approximation: φ* ≈ E[h] - sqrt(2*lambda_w^2 * Var[h])
# (This is approximate and depends on the geometry)

empirical_mean <- mean(result$concordance_i)
empirical_var <- var(result$concordance_i)

cat("  Empirical mean(concordance): ", round(empirical_mean, 4), "\n")
cat("  Empirical var(concordance):  ", round(empirical_var, 4), "\n")
cat("  Estimated minimax:           ", round(result$phi_star, 4), "\n\n")

# How much did the adversary shift from P_n?
shift_amount <- result$phi_star - empirical_mean
cat("  Shift from mean: ", round(shift_amount, 4), "\n")
cat("  As % of mean:    ", round(100 * shift_amount / empirical_mean, 1), "%\n\n")

# Compare to naive minimum
naive_min <- min(result$concordance_i)
cat("  Naive minimum (min over obs): ", round(naive_min, 4), "\n")
cat("  Wasserstein minimum:          ", round(result$phi_star, 4), "\n")
cat("  Difference:                   ", round(result$phi_star - naive_min, 4), "\n\n")

cat("INTERPRETATION:\n")
if (abs(shift_amount) < 0.05 * empirical_mean) {
  cat("  - Small shift from mean → Wasserstein constraint is binding\n")
  cat("  - lambda_w =", lambda_w, "restricts adversary's power\n")
} else {
  cat("  - Large shift from mean → Adversary found bad region\n")
  cat("  - Consider increasing lambda_w for tighter constraint\n")
}

if (result$phi_star > naive_min + 0.01) {
  cat("  - Wasserstein minimum > naive minimum\n")
  cat("  - Cost matrix prevents putting all mass on worst observation\n")
  cat("  - This is the regularization effect we want!\n")
} else {
  cat("  - Wasserstein ≈ naive minimum\n")
  cat("  - Cost matrix not providing much regularization\n")
}

cat("\n")

# Test with multiple lambda_w values
cat("========================================\n")
cat("TESTING MULTIPLE lambda_w VALUES:\n")
cat("========================================\n\n")

lambda_w_values <- c(0.1, 0.2, 0.3, 0.5, 0.7, 1.0)

results_lambda <- map_dfr(lambda_w_values, function(lw) {
  res <- observation_level_minimax_wasserstein(
    data = test_data$data,
    covariates = c("X1", "X2"),
    lambda_w = lw,
    tau_method = "kernel",
    cross_fit = FALSE,  # Reuse same tau estimates for speed
    scale_covariates = TRUE
  )

  tibble(
    lambda_w = lw,
    phi_star = res$phi_star,
    gamma_star = res$optimal_gamma
  )
})

print(results_lambda)

cat("\nPattern:\n")
cat("  - As lambda_w increases, phi_star should decrease (looser constraint)\n")
cat("  - gamma_star should also change to balance the dual objective\n\n")

# Plot if interactive
if (interactive()) {
  library(ggplot2)

  p <- ggplot(results_lambda, aes(x = lambda_w, y = phi_star)) +
    geom_line() +
    geom_point() +
    labs(
      title = "Minimax Concordance vs Wasserstein Radius",
      x = "Wasserstein Radius (lambda_w)",
      y = "Minimax Concordance"
    ) +
    theme_minimal()

  print(p)
}

cat("========================================\n")
cat("TEST COMPLETE\n")
cat("========================================\n")
