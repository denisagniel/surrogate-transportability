# Parameter Calibration for 5-Level Discrete X DGP
#
# X ∈ {-2, -1, 0, 1, 2} approximating N(0,1)

library(dplyr)
library(ggplot2)

# =============================================================================
# Helper Functions
# =============================================================================

#' Generate RCT data with 5-level discrete X
#'
#' @param n Sample size
#' @param p_X Probability vector for X ∈ {-2, -1, 0, 1, 2}
#' @param params DGP parameters
generate_5level_x_data <- function(n, p_X = c(0.05, 0.25, 0.40, 0.25, 0.05),
                                    params, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  X_levels <- c(-2, -1, 0, 1, 2)

  # Sample X from discrete distribution
  X <- sample(X_levels, size = n, replace = TRUE, prob = p_X)
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

#' Compute treatment effects for given distribution
compute_treatment_effects_5level <- function(n_large = 50000, p_X, params) {
  data <- generate_5level_x_data(n_large, p_X, params)

  Delta_S <- mean(data$S[data$A == 1]) - mean(data$S[data$A == 0])
  Delta_Y <- mean(data$Y[data$A == 1]) - mean(data$Y[data$A == 0])

  c(Delta_S = Delta_S, Delta_Y = Delta_Y)
}

#' Compute correlation across TV ball for 5-level X
compute_correlation_5level <- function(p_X_0 = c(0.05, 0.25, 0.40, 0.25, 0.05),
                                       lambda = 0.3,
                                       params,
                                       n_studies = 50,
                                       n_per_study = 20000) {

  # Sample distributions from TV ball
  # For 5-level X, TV ball is more complex - use simple uniform sampling
  # Sample uniformly within L1 ball around P0

  library(MASS)  # For mvrnorm if needed

  # Simple approach: sample perturbations
  P_samples <- matrix(0, nrow = n_studies, ncol = 5)

  for (m in seq_len(n_studies)) {
    # Random walk on simplex
    P_m <- p_X_0

    # Add random perturbation
    perturbation <- rnorm(5, sd = lambda/3)
    P_m <- P_m + perturbation

    # Project back to simplex
    P_m <- pmax(P_m, 0.01)  # Floor at 0.01
    P_m <- P_m / sum(P_m)

    # Check TV distance
    tv_dist <- 0.5 * sum(abs(P_m - p_X_0))

    # If within ball, accept
    if (tv_dist <= lambda) {
      P_samples[m, ] <- P_m
    } else {
      # Scale back
      direction <- (P_m - p_X_0)
      scale_factor <- lambda / tv_dist
      P_samples[m, ] <- p_X_0 + scale_factor * direction
    }
  }

  # Compute treatment effects for each distribution
  effects <- t(apply(P_samples, 1, function(p) {
    compute_treatment_effects_5level(n_per_study, p, params)
  }))

  correlation <- cor(effects[, "Delta_S"], effects[, "Delta_Y"])

  list(
    correlation = correlation,
    Delta_S = effects[, "Delta_S"],
    Delta_Y = effects[, "Delta_Y"],
    P_samples = P_samples
  )
}

# =============================================================================
# Test with Slides Parameters
# =============================================================================

message("\n=== Test: 5-Level X with Slides Parameters ===\n")

params_slides <- list(
  gamma_A = 1.0,
  gamma_AX = 0.5,
  beta_A = 0.25,
  beta_AX = -0.3,    # Use calibrated value from binary X
  beta_S = 0.9,
  beta_SX = -0.1,    # Use calibrated value from binary X
  sigma_S = 0.5,
  sigma_Y = 0.5
)

# P0: approximate N(0,1) discrete distribution
p_X_0 <- c(0.05, 0.25, 0.40, 0.25, 0.05)
X_levels <- c(-2, -1, 0, 1, 2)

cat("Reference distribution P0:\n")
cat(sprintf("  P(X=%d) = %.2f\n", X_levels, p_X_0))
cat(sprintf("  E[X] = %.3f\n", sum(X_levels * p_X_0)))
cat(sprintf("  Var[X] = %.3f\n", sum((X_levels - sum(X_levels * p_X_0))^2 * p_X_0)))

# Compute correlation
message("\nComputing correlation within TV ball (λ=0.3)...")
cor_result <- compute_correlation_5level(
  p_X_0 = p_X_0,
  lambda = 0.3,
  params = params_slides,
  n_studies = 50,
  n_per_study = 20000
)

cat(sprintf("\nCorrelation: %.4f\n", cor_result$correlation))
cat(sprintf("  Delta_S range: [%.3f, %.3f]\n",
            min(cor_result$Delta_S), max(cor_result$Delta_S)))
cat(sprintf("  Delta_Y range: [%.3f, %.3f]\n",
            min(cor_result$Delta_Y), max(cor_result$Delta_Y)))

# Check variation in distributions
tv_distances <- apply(cor_result$P_samples, 1, function(p) {
  0.5 * sum(abs(p - p_X_0))
})
cat(sprintf("  TV distances: [%.3f, %.3f]\n", min(tv_distances), max(tv_distances)))

# Visualize
plot_data <- data.frame(
  Delta_S = cor_result$Delta_S,
  Delta_Y = cor_result$Delta_Y,
  tv_dist = tv_distances
)

p1 <- ggplot(plot_data, aes(x = Delta_S, y = Delta_Y, color = tv_dist)) +
  geom_point(size = 3, alpha = 0.7) +
  geom_smooth(method = "lm", se = FALSE, color = "red", linetype = "dashed") +
  scale_color_viridis_c() +
  labs(
    title = "Treatment Effects: 5-Level Discrete X",
    subtitle = sprintf("Correlation: %.3f | λ=0.3", cor_result$correlation),
    x = expression(Delta[S]),
    y = expression(Delta[Y]),
    color = "TV Distance"
  ) +
  theme_minimal()

print(p1)

# Check if correlation is reasonable (not ±1)
message("\n=== Assessment ===")
if (abs(cor_result$correlation) > 0.95) {
  message("✗ Correlation is still near ±1 (perfect dependence)")
  message("  5-level X may still be too constrained")
} else if (abs(cor_result$correlation) < 0.2) {
  message("✓ Correlation is reasonable (near-zero as desired)")
  message("  5-level X breaks perfect dependence!")
} else {
  message("~ Correlation is moderate")
  message(sprintf("  |cor| = %.3f (target was near-zero)", abs(cor_result$correlation)))
}

message("\n=== Complete ===\n")
