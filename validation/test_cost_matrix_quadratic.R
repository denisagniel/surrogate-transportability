#!/usr/bin/env Rscript
#
# Test: Is (q-p)'C(q-p) = 0 always, or specific to our case?
#

suppressPackageStartupMessages({
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all()
  }
})

set.seed(2026)

# Simple test with known cost matrix
J <- 4

# Cost matrix: squared Euclidean distances on a line
# Types at positions: 0, 1, 2, 3
positions <- 0:(J-1)
C_simple <- outer(positions, positions, function(x, y) (x - y)^2)

cat("Simple cost matrix (squared distances on line):\n")
print(C_simple)
cat("\n")

# Two distributions
p0 <- rep(1/J, J)
q <- c(0.4, 0.3, 0.2, 0.1)  # Shifted toward first types

cat("Distributions:\n")
cat("  p0:", p0, "\n")
cat("  q: ", q, "\n\n")

# Compute (q-p0)'C(q-p0)
diff <- q - p0
quad_form <- as.numeric(t(diff) %*% C_simple %*% diff)

cat(sprintf("(q-p0)'C(q-p0) = %.6f\n", quad_form))
cat(sprintf("sqrt of that   = %.6f\n", sqrt(max(0, quad_form))))
cat(sprintf("TV(q, p0)     = %.6f\n\n", sum(abs(q - p0)) / 2))

# Now test with our actual cost matrix
cat("Testing with actual data:\n")
cat("-------------------------\n\n")

n <- 100
data <- data.frame(
  X1 = rnorm(n),
  X2 = rnorm(n),
  A = rbinom(n, 1, 0.5),
  S = rnorm(n),
  Y = rnorm(n)
)

disc <- discretize_data(data, scheme = "kmeans",
                        covariate_cols = c("X1", "X2"), J_target = 6)

centroids <- compute_type_centroids(data, disc$bins, c("X1", "X2"))
C <- compute_type_cost_matrix(centroids)

p0_data <- as.numeric(table(disc$bins) / n)
q_data <- MCMCpack::rdirichlet(1, rep(1, disc$J))[1,]

diff_data <- q_data - p0_data
quad_form_data <- as.numeric(t(diff_data) %*% C %*% diff_data)

cat(sprintf("(q-p0)'C(q-p0) = %.6f\n", quad_form_data))
cat(sprintf("||q-p0||_2     = %.6f\n", sqrt(sum((q_data - p0_data)^2))))
cat(sprintf("TV(q, p0)     = %.6f\n\n", sum(abs(q_data - p0_data)) / 2))

# Check if cost matrix is positive semi-definite
eigenvalues <- eigen(C, only.values = TRUE)$values
cat("Cost matrix eigenvalues (first 5):\n")
print(head(eigenvalues, 5))
cat("\n")

if (any(eigenvalues < -1e-10)) {
  cat("⚠ Cost matrix is NOT positive semi-definite!\n")
  cat("  This explains why (q-p0)'C(q-p0) can be zero or negative.\n")
  cat("  The cost matrix C[i,j] = ||centroid_i - centroid_j||^2\n")
  cat("  is NOT guaranteed to be PSD in general.\n\n")
  cat("SOLUTION: We need to use actual optimal transport, not this approximation.\n")
} else {
  cat("✓ Cost matrix is positive semi-definite.\n")
  cat("  The issue must be elsewhere.\n")
}
