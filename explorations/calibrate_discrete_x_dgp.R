# Parameter Calibration for Discrete X DGP
#
# Goal: Find DGP parameters that produce:
# - High PTE (≈ 0.7) in reference study P₀
# - Near-zero correlation (≈ 0 to 0.1) across studies within TV ball
# - Binary X ∈ {0, 1}
#
# Strategy:
# 1. Start with slides DGP parameters (known to work for continuous X)
# 2. Test with binary X instead of continuous
# 3. Grid search over key parameters if needed
# 4. Validate that TV ball of radius λ covers meaningful study variation

library(dplyr)
library(ggplot2)

# =============================================================================
# Helper Functions
# =============================================================================

#' Generate RCT data with binary X
#'
#' @param n Sample size
#' @param p_X Probability that X=1 (default: 0.5 for P₀)
#' @param params Named list of DGP parameters
#' @param seed Random seed
generate_binary_x_data <- function(n, p_X = 0.5, params, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Generate binary X
  X <- rbinom(n, 1, p_X)
  A <- rbinom(n, 1, 0.5)

  # S = (gamma_A + gamma_AX * X) * A + ε_S
  S <- (params$gamma_A + params$gamma_AX * X) * A +
       rnorm(n, sd = params$sigma_S)

  # Y = (beta_A + beta_AX * X) * A + beta_S * S + beta_SX * S * X + ε_Y
  Y <- (params$beta_A + params$beta_AX * X) * A +
       params$beta_S * S +
       params$beta_SX * S * X +
       rnorm(n, sd = params$sigma_Y)

  data.frame(X = X, A = A, S = S, Y = Y)
}

#' Compute true treatment effects for a given p_X
#'
#' @param n_large Large sample size for stable estimates
#' @param p_X Probability that X=1
#' @param params DGP parameters
compute_treatment_effects <- function(n_large = 50000, p_X, params) {
  data <- generate_binary_x_data(n_large, p_X, params)

  Delta_S <- mean(data$S[data$A == 1]) - mean(data$S[data$A == 0])
  Delta_Y <- mean(data$Y[data$A == 1]) - mean(data$Y[data$A == 0])

  c(Delta_S = Delta_S, Delta_Y = Delta_Y)
}

#' Compute correlation across studies within TV ball
#'
#' @param p_X_0 Reference probability P₀(X=1)
#' @param lambda TV ball radius
#' @param params DGP parameters
#' @param n_studies Number of studies to sample
#' @param n_per_study Sample size per study
compute_correlation_in_tv_ball <- function(p_X_0 = 0.5,
                                           lambda = 0.3,
                                           params,
                                           n_studies = 100,
                                           n_per_study = 50000) {
  # TV ball for binary X: [max(0, p_X_0 - lambda), min(1, p_X_0 + lambda)]
  p_X_min <- max(0, p_X_0 - lambda)
  p_X_max <- min(1, p_X_0 + lambda)

  # Sample p_X values uniformly from TV ball
  p_X_values <- seq(p_X_min, p_X_max, length.out = n_studies)

  effects <- t(sapply(p_X_values, function(p) {
    compute_treatment_effects(n_per_study, p, params)
  }))

  correlation <- cor(effects[, "Delta_S"], effects[, "Delta_Y"])

  list(
    correlation = correlation,
    Delta_S = effects[, "Delta_S"],
    Delta_Y = effects[, "Delta_Y"],
    p_X_values = p_X_values,
    p_X_range = c(p_X_min, p_X_max)
  )
}

#' Compute PTE in reference study
#'
#' @param params DGP parameters
#' @param p_X_0 Reference probability P₀(X=1)
#' @param n_large Large n for stable estimates
compute_pte <- function(params, p_X_0 = 0.5, n_large = 50000) {
  data <- generate_binary_x_data(n_large, p_X_0, params)

  # Simple regression-based PTE
  # Regress Y[A=1] on S[A=1]
  # Regress Y[A=0] on S[A=0]

  data_treated <- data[data$A == 1, ]
  data_control <- data[data$A == 0, ]

  fit_1 <- lm(Y ~ S, data = data_treated)
  fit_0 <- lm(Y ~ S, data = data_control)

  # Treatment effect on S
  Delta_S <- mean(data_treated$S) - mean(data_control$S)

  # Treatment effect on Y
  Delta_Y <- mean(data_treated$Y) - mean(data_control$Y)

  # PTE = (Delta_Y - direct effect) / Delta_Y
  # Direct effect ≈ beta_A + beta_AX * E[X]
  direct_effect <- params$beta_A + params$beta_AX * p_X_0

  pte <- 1 - direct_effect / Delta_Y

  list(
    pte = pte,
    Delta_S = Delta_S,
    Delta_Y = Delta_Y,
    direct_effect = direct_effect
  )
}

# =============================================================================
# Test 1: Slides Parameters with Binary X
# =============================================================================

message("\n=== Test 1: Slides Parameters with Binary X ===\n")

params_slides <- list(
  gamma_A = 1.0,
  gamma_AX = 0.5,
  beta_A = 0.25,
  beta_AX = -0.4,
  beta_S = 0.9,
  beta_SX = -0.05,
  sigma_S = 0.5,
  sigma_Y = 0.5
)

# Compute PTE in P₀
pte_result <- compute_pte(params_slides, p_X_0 = 0.5)
cat(sprintf("PTE in P₀ (p_X=0.5): %.3f\n", pte_result$pte))
cat(sprintf("  Delta_S = %.3f\n", pte_result$Delta_S))
cat(sprintf("  Delta_Y = %.3f\n", pte_result$Delta_Y))
cat(sprintf("  Direct effect = %.3f\n", pte_result$direct_effect))

# Compute correlation across TV ball
cor_result <- compute_correlation_in_tv_ball(
  p_X_0 = 0.5,
  lambda = 0.3,
  params = params_slides,
  n_studies = 50
)

cat(sprintf("\nCorrelation within TV ball (λ=0.3): %.3f\n", cor_result$correlation))
cat(sprintf("  p_X range: [%.2f, %.2f]\n",
            cor_result$p_X_range[1], cor_result$p_X_range[2]))
cat(sprintf("  Delta_S range: [%.3f, %.3f]\n",
            min(cor_result$Delta_S), max(cor_result$Delta_S)))
cat(sprintf("  Delta_Y range: [%.3f, %.3f]\n",
            min(cor_result$Delta_Y), max(cor_result$Delta_Y)))

# Visualize
plot_data <- data.frame(
  Delta_S = cor_result$Delta_S,
  Delta_Y = cor_result$Delta_Y,
  p_X = cor_result$p_X_values
)

p1 <- ggplot(plot_data, aes(x = Delta_S, y = Delta_Y, color = p_X)) +
  geom_point(size = 3, alpha = 0.7) +
  geom_smooth(method = "lm", se = FALSE, color = "red", linetype = "dashed") +
  scale_color_gradient(low = "blue", high = "orange") +
  labs(
    title = "Treatment Effects Across Studies (Binary X, Slides Parameters)",
    subtitle = sprintf("Correlation: %.3f | PTE: %.2f",
                       cor_result$correlation, pte_result$pte),
    x = expression(Delta[S]),
    y = expression(Delta[Y]),
    color = "P(X=1)"
  ) +
  theme_minimal()

print(p1)

# =============================================================================
# Test 2: Parameter Grid Search
# =============================================================================

message("\n=== Test 2: Parameter Grid Search ===\n")
message("Searching for parameters giving |correlation| < 0.15...\n")

# Grid over key parameters
beta_AX_values <- seq(-0.6, -0.2, by = 0.1)
beta_SX_values <- seq(-0.15, 0.05, by = 0.05)

grid_results <- expand.grid(
  beta_AX = beta_AX_values,
  beta_SX = beta_SX_values
)

grid_results$correlation <- NA
grid_results$pte <- NA

for (i in seq_len(nrow(grid_results))) {
  if (i %% 10 == 0) {
    message(sprintf("  Testing combination %d/%d", i, nrow(grid_results)))
  }

  params_test <- params_slides
  params_test$beta_AX <- grid_results$beta_AX[i]
  params_test$beta_SX <- grid_results$beta_SX[i]

  # Compute correlation (smaller n for speed)
  cor_test <- compute_correlation_in_tv_ball(
    p_X_0 = 0.5,
    lambda = 0.3,
    params = params_test,
    n_studies = 30,
    n_per_study = 20000
  )

  pte_test <- compute_pte(params_test, p_X_0 = 0.5, n_large = 20000)

  grid_results$correlation[i] <- cor_test$correlation
  grid_results$pte[i] <- pte_test$pte
}

# Find best parameters
grid_results$abs_correlation <- abs(grid_results$correlation)
grid_results <- grid_results[order(grid_results$abs_correlation), ]

cat("\n--- Top 5 Parameter Combinations ---\n")
print(head(grid_results[, c("beta_AX", "beta_SX", "correlation", "pte")], 5))

# Visualize grid
p2 <- ggplot(grid_results, aes(x = beta_AX, y = beta_SX, fill = abs_correlation)) +
  geom_tile() +
  geom_contour(aes(z = abs_correlation), color = "white", bins = 5) +
  scale_fill_viridis_c(option = "plasma") +
  labs(
    title = "Parameter Grid Search: |Correlation| vs (β_AX, β_SX)",
    x = expression(beta[AX]),
    y = expression(beta[SX]),
    fill = "|Correlation|"
  ) +
  theme_minimal()

print(p2)

p3 <- ggplot(grid_results, aes(x = correlation, y = pte)) +
  geom_point(size = 2, alpha = 0.6) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  geom_hline(yintercept = 0.7, linetype = "dashed", color = "blue") +
  labs(
    title = "Tradeoff: Correlation vs PTE",
    x = "Correlation",
    y = "PTE"
  ) +
  theme_minimal()

print(p3)

# =============================================================================
# Test 3: Validate Best Parameters
# =============================================================================

message("\n=== Test 3: Validate Best Parameters ===\n")

best_params <- params_slides
best_params$beta_AX <- grid_results$beta_AX[1]
best_params$beta_SX <- grid_results$beta_SX[1]

cat("Best parameters found:\n")
cat(sprintf("  beta_AX = %.3f\n", best_params$beta_AX))
cat(sprintf("  beta_SX = %.3f\n", best_params$beta_SX))

# Full validation with larger n
pte_final <- compute_pte(best_params, p_X_0 = 0.5, n_large = 100000)
cor_final <- compute_correlation_in_tv_ball(
  p_X_0 = 0.5,
  lambda = 0.3,
  params = best_params,
  n_studies = 100,
  n_per_study = 100000
)

cat(sprintf("\nFinal validation (n=100,000):\n"))
cat(sprintf("  PTE: %.3f\n", pte_final$pte))
cat(sprintf("  Correlation: %.3f\n", cor_final$correlation))

# Plot final results
plot_final <- data.frame(
  Delta_S = cor_final$Delta_S,
  Delta_Y = cor_final$Delta_Y,
  p_X = cor_final$p_X_values
)

p4 <- ggplot(plot_final, aes(x = Delta_S, y = Delta_Y, color = p_X)) +
  geom_point(size = 3, alpha = 0.7) +
  geom_smooth(method = "lm", se = FALSE, color = "red", linetype = "dashed") +
  scale_color_gradient(low = "blue", high = "orange") +
  labs(
    title = "Final Calibrated DGP: Treatment Effects Across Studies",
    subtitle = sprintf("Correlation: %.3f | PTE: %.2f | λ=0.3",
                       cor_final$correlation, pte_final$pte),
    x = expression(Delta[S]),
    y = expression(Delta[Y]),
    color = "P(X=1)"
  ) +
  theme_minimal()

print(p4)

# Save best parameters
cat("\n--- Recommended DGP Parameters ---\n")
cat("Copy these to validation/dgp_discrete_x.R:\n\n")
cat("params_discrete_x <- list(\n")
for (param_name in names(best_params)) {
  cat(sprintf("  %s = %.3f%s\n",
              param_name,
              best_params[[param_name]],
              ifelse(param_name == names(best_params)[length(best_params)], "", ",")))
}
cat(")\n")

message("\n=== Calibration Complete ===\n")
