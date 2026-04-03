#!/usr/bin/env Rscript
#
# Debug: Why is W_2 distance always 0?
#

suppressPackageStartupMessages({
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all()
  }
})

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

# Discretize
disc <- discretize_data(data, scheme = "kmeans",
                        covariate_cols = c("X1", "X2"), J_target = 16)

cat(sprintf("J = %d types\n\n", disc$J))

# Compute centroids
centroids <- compute_type_centroids(data, disc$bins, c("X1", "X2"))

cat("Centroids (first 5 rows):\n")
print(head(centroids, 5))
cat("\n")

# Compute cost matrix
C <- compute_type_cost_matrix(centroids)

cat("Cost matrix statistics:\n")
cat(sprintf("  Mean: %.4f\n", mean(C[upper.tri(C)])))
cat(sprintf("  SD:   %.4f\n", sd(C[upper.tri(C)])))
cat(sprintf("  Min:  %.4f\n", min(C[upper.tri(C)])))
cat(sprintf("  Max:  %.4f\n", max(C[upper.tri(C)])))
cat(sprintf("  Median: %.4f\n", median(C[upper.tri(C)])))
cat("\n")

# Reference distribution
p0 <- as.numeric(table(disc$bins) / n)

cat("Reference distribution p0:\n")
cat(sprintf("  Min: %.4f\n", min(p0)))
cat(sprintf("  Max: %.4f\n", max(p0)))
cat(sprintf("  Mean: %.4f\n", mean(p0)))
cat(sprintf("  SD: %.4f\n", sd(p0)))
cat("\n")

# Sample a few Dirichlet distributions
cat("Testing W_2 distance calculation:\n")
cat("---------------------------------\n\n")

for (i in 1:5) {
  q <- MCMCpack::rdirichlet(1, rep(1, disc$J))[1,]

  # Manual W_2 calculation
  diff <- q - p0
  w2_squared <- as.numeric(t(diff) %*% C %*% diff)
  w2 <- sqrt(max(0, w2_squared))

  # Using function
  w2_func <- wasserstein_distance_types(q, p0, C)

  # TV distance for comparison
  tv <- sum(abs(q - p0)) / 2

  cat(sprintf("Sample %d:\n", i))
  cat(sprintf("  W_2 (manual):   %.6f\n", w2))
  cat(sprintf("  W_2 (function): %.6f\n", w2_func))
  cat(sprintf("  TV distance:    %.6f\n", tv))
  cat(sprintf("  ||q-p0||_2:     %.6f\n", sqrt(sum((q-p0)^2))))
  cat("\n")
}

cat("Diagnosis:\n")
cat("----------\n")
if (max(C[upper.tri(C)]) < 1e-6) {
  cat("⚠ Cost matrix has very small values!\n")
  cat("  This means types are very close in covariate space.\n")
  cat("  W_2 distance will be near zero even for different distributions.\n")
  cat("\nPossible causes:\n")
  cat("  - Covariates not varying much\n")
  cat("  - Clustering produced tight clusters\n")
  cat("  - Need to scale/standardize covariates\n")
} else if (all(abs(p0 - 1/disc$J) < 0.01)) {
  cat("⚠ Reference distribution is nearly uniform!\n")
  cat("  When p0 ≈ uniform, Dirichlet(1,...,1) samples will be close to p0.\n")
} else {
  cat("Cost matrix and reference distribution look reasonable.\n")
  cat("The issue may be with the approximation W_2^2 ≈ (q-p0)'C(q-p0).\n")
}
