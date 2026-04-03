#!/usr/bin/env Rscript
#
# Test: Corrected W_2 distance with proper OT
#

suppressPackageStartupMessages({
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all()
  }
})

cat("========================================================\n")
cat("Testing Corrected W_2 Distance Implementation\n")
cat("========================================================\n\n")

# Check if transport package is available
if (!requireNamespace("transport", quietly = TRUE)) {
  cat("⚠ WARNING: 'transport' package not installed.\n")
  cat("  Install with: install.packages('transport')\n")
  cat("  Falling back to lpSolve if available.\n\n")
}

if (!requireNamespace("lpSolve", quietly = TRUE) &&
    !requireNamespace("transport", quietly = TRUE)) {
  cat("✗ ERROR: Neither 'transport' nor 'lpSolve' package available.\n")
  cat("  Cannot proceed with validation.\n")
  quit(status = 1)
}

set.seed(2026)

# ----------------------------------------------------------------
# Test 1: Simple Case with Known Answer
# ----------------------------------------------------------------

cat("Test 1: Simple case (known ground truth)\n")
cat("-----------------------------------------\n\n")

# Two distributions on 3 types at positions 0, 1, 2
J <- 3
positions <- 0:(J-1)
C_simple <- outer(positions, positions, function(x, y) (x - y)^2)

# p0 has all mass on type 1
# q has all mass on type 3
# W_2 should be sqrt((2-0)^2) = 2

p0 <- c(1, 0, 0)
q <- c(0, 0, 1)

w2 <- wasserstein_distance_types(p0, q, C_simple)

cat(sprintf("Distributions: p0 = (1,0,0), q = (0,0,1)\n"))
cat(sprintf("Cost matrix: squared distances on [0,1,2]\n"))
cat(sprintf("Expected W_2: 2.0\n"))
cat(sprintf("Computed W_2: %.6f\n", w2))

if (abs(w2 - 2.0) < 0.01) {
  cat("✓ PASS: Matches expected value\n\n")
  test1_pass <- TRUE
} else {
  cat("✗ FAIL: Does not match expected value\n\n")
  test1_pass <- FALSE
}

# ----------------------------------------------------------------
# Test 2: Properties of W_2 Distance
# ----------------------------------------------------------------

cat("Test 2: Distance metric properties\n")
cat("-----------------------------------\n\n")

# Generate random distributions
J <- 5
positions <- rnorm(J, 0, 2)
C <- outer(positions, positions, function(x, y) (x - y)^2)

p1 <- MCMCpack::rdirichlet(1, rep(1, J))[1,]
p2 <- MCMCpack::rdirichlet(1, rep(1, J))[1,]
p3 <- MCMCpack::rdirichlet(1, rep(1, J))[1,]

# Identity: W_2(p, p) = 0
w_identity <- wasserstein_distance_types(p1, p1, C)
cat(sprintf("Identity: W_2(p1, p1) = %.6f (should be ~0)\n", w_identity))
test2a <- w_identity < 1e-6

# Symmetry: W_2(p1, p2) = W_2(p2, p1)
w_12 <- wasserstein_distance_types(p1, p2, C)
w_21 <- wasserstein_distance_types(p2, p1, C)
cat(sprintf("Symmetry: W_2(p1,p2) = %.6f, W_2(p2,p1) = %.6f\n", w_12, w_21))
test2b <- abs(w_12 - w_21) < 1e-6

# Non-negativity
test2c <- w_12 >= 0

# Triangle inequality: W_2(p1, p3) <= W_2(p1, p2) + W_2(p2, p3)
w_13 <- wasserstein_distance_types(p1, p3, C)
w_23 <- wasserstein_distance_types(p2, p3, C)
cat(sprintf("Triangle: W_2(p1,p3) = %.6f <= W_2(p1,p2) + W_2(p2,p3) = %.6f\n",
            w_13, w_12 + w_23))
test2d <- w_13 <= (w_12 + w_23) + 1e-6

if (all(c(test2a, test2b, test2c, test2d))) {
  cat("✓ PASS: All distance properties satisfied\n\n")
  test2_pass <- TRUE
} else {
  cat("✗ FAIL: Some distance properties violated\n\n")
  test2_pass <- FALSE
}

# ----------------------------------------------------------------
# Test 3: Comparison with Old Approximation
# ----------------------------------------------------------------

cat("Test 3: Comparison with old (broken) approximation\n")
cat("--------------------------------------------------\n\n")

# Generate data
n <- 200
data <- data.frame(
  X1 = rnorm(n),
  X2 = rnorm(n),
  A = rbinom(n, 1, 0.5),
  S = rnorm(n),
  Y = rnorm(n)
)

disc <- discretize_data(data, scheme = "kmeans",
                        covariate_cols = c("X1", "X2"), J_target = 10)

centroids <- compute_type_centroids(data, disc$bins, c("X1", "X2"))
C_data <- compute_type_cost_matrix(centroids)

p0_data <- as.numeric(table(disc$bins) / n)
q_data <- MCMCpack::rdirichlet(1, rep(1, disc$J))[1,]

# Correct W_2
w2_correct <- wasserstein_distance_types(p0_data, q_data, C_data)

# Old approximation
diff <- q_data - p0_data
quad_form <- as.numeric(t(diff) %*% C_data %*% diff)
w2_approx <- sqrt(max(0, quad_form))

cat(sprintf("Correct W_2:     %.6f\n", w2_correct))
cat(sprintf("Old approx:      %.6f (was always 0)\n", w2_approx))
cat(sprintf("TV distance:     %.6f\n", sum(abs(q_data - p0_data)) / 2))

if (w2_correct > 0.01) {
  cat("✓ PASS: Correct W_2 is now non-trivial\n\n")
  test3_pass <- TRUE
} else {
  cat("✗ FAIL: Correct W_2 still near zero\n\n")
  test3_pass <- FALSE
}

# ----------------------------------------------------------------
# Test 4: Perturbation Exploration
# ----------------------------------------------------------------

cat("Test 4: Perturbation sampling now explores\n")
cat("-------------------------------------------\n\n")

lambda_w <- 0.5
n_samples <- 20
distances <- numeric(n_samples)

for (i in 1:n_samples) {
  q_pert <- sample_wasserstein_perturbation(p0_data, C_data, lambda_w, method = "dirichlet")
  distances[i] <- wasserstein_distance_types(q_pert, p0_data, C_data)
}

cat(sprintf("Lambda_W = %.2f\n", lambda_w))
cat(sprintf("Sampled %d perturbations:\n", n_samples))
cat(sprintf("  Mean W_2: %.4f\n", mean(distances)))
cat(sprintf("  SD W_2:   %.4f\n", sd(distances)))
cat(sprintf("  Min W_2:  %.4f\n", min(distances)))
cat(sprintf("  Max W_2:  %.4f\n", max(distances)))
cat(sprintf("  Exploration rate: %.1f%% non-trivial (W_2 > 0.01)\n",
            mean(distances > 0.01) * 100))
cat(sprintf("  Constraint violations: %d (W_2 > %.2f * 1.05)\n",
            sum(distances > lambda_w * 1.05), lambda_w))

if (mean(distances > 0.01) >= 0.5 && all(distances <= lambda_w * 1.1)) {
  cat("✓ PASS: Perturbations explore and satisfy constraints\n\n")
  test4_pass <- TRUE
} else {
  cat("✗ FAIL: Poor exploration or constraint violations\n\n")
  test4_pass <- FALSE
}

# ----------------------------------------------------------------
# Summary
# ----------------------------------------------------------------

cat("========================================================\n")
cat("Validation Summary\n")
cat("========================================================\n\n")

all_tests <- c(test1_pass, test2_pass, test3_pass, test4_pass)
test_names <- c("Simple case", "Metric properties", "Vs old approx", "Perturbation")

for (i in seq_along(all_tests)) {
  status <- if (all_tests[i]) "✓ PASS" else "✗ FAIL"
  cat(sprintf("%s: %s\n", status, test_names[i]))
}

cat("\n")

if (all(all_tests)) {
  cat("✓✓✓ ALL TESTS PASSED ✓✓✓\n\n")
  cat("Corrected W_2 implementation is working correctly!\n")
  cat("Ready to proceed with full validation.\n")
  quit(status = 0)
} else {
  cat("✗✗✗ SOME TESTS FAILED ✗✗✗\n\n")
  n_fail <- sum(!all_tests)
  cat(sprintf("%d/%d tests failed.\n", n_fail, length(all_tests)))
  quit(status = 1)
}
