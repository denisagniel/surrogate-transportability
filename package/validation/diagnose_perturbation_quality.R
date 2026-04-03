#!/usr/bin/env Rscript
#
# Diagnostic: Check perturbation quality in Wasserstein ball
#

suppressPackageStartupMessages({
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all()
  }
})

cat("========================================================\n")
cat("Diagnostic: Wasserstein Perturbation Quality\n")
cat("========================================================\n\n")

set.seed(2026)

# Generate data
n <- 200
data <- data.frame(
  X1 = rnorm(n),
  X2 = rnorm(n),
  A = rbinom(n, 1, 0.5),
  S = rnorm(n),
  Y = rnorm(n)
)

# Discretize with more types for better resolution
disc <- discretize_data(data, scheme = "kmeans",
                        covariate_cols = c("X1", "X2"), J_target = 16)

cat(sprintf("Discretized into J = %d types\n", disc$J))

# Compute centroids and cost matrix
centroids <- compute_type_centroids(data, disc$bins, c("X1", "X2"))
C <- compute_type_cost_matrix(centroids)

# Reference distribution
p0 <- as.numeric(table(disc$bins) / n)

# Test different lambda_w values
lambda_values <- c(0.1, 0.3, 0.5, 1.0, 2.0)

cat("\nTesting perturbation sampling at different lambda_w:\n")
cat("----------------------------------------------------\n\n")

for (lambda_w in lambda_values) {
  cat(sprintf("Lambda_W = %.2f:\n", lambda_w))

  # Sample multiple perturbations
  n_samples <- 30
  distances <- numeric(n_samples)
  tvs <- numeric(n_samples)

  for (i in 1:n_samples) {
    q <- sample_wasserstein_perturbation(p0, C, lambda_w, method = "normal")
    distances[i] <- wasserstein_distance_types(q, p0, C)
    tvs[i] <- sum(abs(q - p0)) / 2  # TV distance
  }

  cat(sprintf("  W_2 distances: mean = %.4f, sd = %.4f, max = %.4f\n",
              mean(distances), sd(distances), max(distances)))
  cat(sprintf("  TV distances:  mean = %.4f, sd = %.4f, max = %.4f\n",
              mean(tvs), sd(tvs), max(tvs)))
  cat(sprintf("  Exploration: %.1f%% non-trivial (W_2 > 0.01)\n",
              mean(distances > 0.01) * 100))

  # Check if exploring boundary
  boundary_samples <- sum(distances > 0.8 * lambda_w)
  cat(sprintf("  Boundary: %.1f%% near boundary (W_2 > 0.8*lambda_w)\n",
              boundary_samples / n_samples * 100))

  # Check constraint satisfaction
  violations <- sum(distances > lambda_w * 1.05)
  cat(sprintf("  Violations: %d/%d (%.1f%%)\n",
              violations, n_samples, violations / n_samples * 100))

  cat("\n")
}

# Test a realistic scenario
cat("Realistic minimax scenario:\n")
cat("---------------------------\n\n")

# Run actual minimax
result <- estimate_minimax_single_scheme_wasserstein(
  data = data,
  bins = disc$bins,
  cost_matrix = C,
  lambda_w = 0.5,
  M = 100,
  functional_type = "correlation"
)

cat(sprintf("Ran M = 100 iterations\n"))
cat(sprintf("Minimax estimate: %.4f\n", result$phi_value))
cat(sprintf("Treatment effects: %d valid pairs\n", nrow(result$effects)))

# Check perturbation quality
if (!is.null(result$perturbations_q) && nrow(result$perturbations_q) > 0) {
  distances <- numeric(nrow(result$perturbations_q))
  for (i in 1:nrow(result$perturbations_q)) {
    distances[i] <- wasserstein_distance_types(result$perturbations_q[i,], p0, C)
  }

  cat(sprintf("Perturbation W_2: mean = %.4f, sd = %.4f\n",
              mean(distances), sd(distances)))
  cat(sprintf("Exploration rate: %.1f%% non-trivial\n",
              mean(distances > 0.01) * 100))
}

cat("\n========================================================\n")
cat("Diagnostic complete.\n")
cat("\nInterpretation:\n")
cat("- If W_2 distances are all ~0: perturbations not exploring\n")
cat("- If W_2 varies: good exploration of the ball\n")
cat("- Boundary exploration indicates thorough search\n")
cat("========================================================\n")
