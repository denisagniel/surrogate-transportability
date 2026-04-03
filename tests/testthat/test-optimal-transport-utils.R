# Tests for Optimal Transport Utilities
# Phase 1: Core Wasserstein Infrastructure

test_that("compute_type_cost_matrix produces valid cost matrix", {
  # Setup: type centroids in 2D
  J <- 5
  centroids <- matrix(rnorm(J * 2), J, 2)

  # Compute Euclidean cost
  C <- compute_type_cost_matrix(centroids, cost_function = "euclidean")

  # Check properties
  expect_equal(dim(C), c(J, J))
  expect_true(all(C >= 0))  # Non-negative
  expect_equal(C, t(C))     # Symmetric
  expect_equal(diag(C), rep(0, J))  # Zero diagonal

  # Check specific distance
  dist_12_manual <- sum((centroids[1,] - centroids[2,])^2)
  expect_equal(C[1, 2], dist_12_manual, tolerance = 1e-10)
})


test_that("compute_type_cost_matrix handles edge cases", {
  # Single type
  centroids_1 <- matrix(c(1, 2), 1, 2)
  C1 <- compute_type_cost_matrix(centroids_1)
  expect_equal(dim(C1), c(1, 1))
  expect_equal(C1[1, 1], 0)

  # Two identical types (degenerate)
  centroids_dup <- matrix(c(1, 2, 1, 2), 2, 2, byrow = TRUE)
  C_dup <- compute_type_cost_matrix(centroids_dup)
  expect_equal(C_dup[1, 2], 0)
})


test_that("compute_type_cost_matrix Mahalanobis cost works", {
  J <- 5
  p <- 3
  centroids <- matrix(rnorm(J * p), J, p)

  # Compute Mahalanobis cost
  C_maha <- compute_type_cost_matrix(centroids, cost_function = "mahalanobis")

  # Check properties
  expect_equal(dim(C_maha), c(J, J))
  expect_true(all(C_maha >= 0))
  expect_equal(C_maha, t(C_maha))
  expect_equal(diag(C_maha), rep(0, J))
})


test_that("wasserstein_distance_types computes valid distance", {
  J <- 10
  centroids <- matrix(rnorm(J * 2), J, 2)
  C <- compute_type_cost_matrix(centroids)

  # Two distributions
  p0 <- rep(1/J, J)
  q <- MCMCpack::rdirichlet(1, rep(1, J))[1,]

  # Compute distance
  w_dist <- wasserstein_distance_types(q, p0, C)

  # Check properties
  expect_true(is.numeric(w_dist))
  expect_true(w_dist >= 0)
  expect_length(w_dist, 1)
})


test_that("wasserstein_distance_types satisfies W(P, P) = 0", {
  J <- 8
  centroids <- matrix(rnorm(J * 2), J, 2)
  C <- compute_type_cost_matrix(centroids)

  p <- rep(1/J, J)

  # Distance to itself
  w_self <- wasserstein_distance_types(p, p, C)

  expect_equal(w_self, 0, tolerance = 1e-10)
})


test_that("wasserstein_distance_types is symmetric", {
  J <- 10
  centroids <- matrix(rnorm(J * 2), J, 2)
  C <- compute_type_cost_matrix(centroids)

  p1 <- rep(1/J, J)
  p2 <- MCMCpack::rdirichlet(1, rep(2, J))[1,]

  w12 <- wasserstein_distance_types(p1, p2, C)
  w21 <- wasserstein_distance_types(p2, p1, C)

  expect_equal(w12, w21, tolerance = 1e-10)
})


test_that("wasserstein_distance_types validates inputs", {
  J <- 5
  centroids <- matrix(rnorm(J * 2), J, 2)
  C <- compute_type_cost_matrix(centroids)

  p <- rep(1/J, J)
  q_wrong_length <- rep(1/4, 4)

  expect_error(
    wasserstein_distance_types(p, q_wrong_length, C),
    "same length"
  )

  # Non-simplex (negative)
  q_neg <- c(-0.1, rep(1.1/(J-1), J-1))
  expect_error(
    wasserstein_distance_types(p, q_neg, C),
    "non-negative"
  )
})


test_that("project_to_simplex works correctly", {
  # Already on simplex
  p_valid <- c(0.2, 0.3, 0.5)
  p_proj <- project_to_simplex(p_valid)

  expect_equal(sum(p_proj), 1, tolerance = 1e-10)
  expect_true(all(p_proj >= 0))
  expect_equal(p_proj, p_valid, tolerance = 1e-6)

  # Not on simplex (has negative)
  x_neg <- c(0.5, -0.2, 0.3, 0.6)
  p_proj_neg <- project_to_simplex(x_neg)

  expect_equal(sum(p_proj_neg), 1, tolerance = 1e-10)
  expect_true(all(p_proj_neg >= 0))

  # Not on simplex (sums to > 1)
  x_large <- c(0.5, 0.6, 0.7)
  p_proj_large <- project_to_simplex(x_large)

  expect_equal(sum(p_proj_large), 1, tolerance = 1e-10)
  expect_true(all(p_proj_large >= 0))
})


test_that("project_to_simplex edge cases", {
  # Single element
  p1 <- project_to_simplex(0.5)
  expect_equal(p1, 1)

  # All zeros
  p_zeros <- project_to_simplex(rep(0, 5))
  expect_equal(sum(p_zeros), 1)
  expect_true(all(p_zeros >= 0))

  # Large values
  x_large <- c(100, 200, 150)
  p_large <- project_to_simplex(x_large)
  expect_equal(sum(p_large), 1, tolerance = 1e-10)
})


test_that("project_onto_wasserstein_ball maintains constraint", {
  set.seed(123)
  J <- 10
  centroids <- matrix(rnorm(J * 2), J, 2)
  C <- compute_type_cost_matrix(centroids)

  # Reference distribution
  p0 <- rep(1/J, J)

  # Target outside ball
  target <- MCMCpack::rdirichlet(1, rep(0.3, J))[1,]

  # Radius
  lambda_w <- 0.5

  # Project
  q_proj <- project_onto_wasserstein_ball(target, p0, C, lambda_w)

  # Check constraint
  w_dist <- wasserstein_distance_types(q_proj, p0, C)
  expect_true(w_dist <= lambda_w * 1.01)  # Allow small tolerance

  # Check simplex
  expect_equal(sum(q_proj), 1, tolerance = 1e-6)
  expect_true(all(q_proj >= 0))
})


test_that("project_onto_wasserstein_ball returns target if already in ball", {
  set.seed(456)
  J <- 8
  centroids <- matrix(rnorm(J * 2), J, 2)
  C <- compute_type_cost_matrix(centroids)

  p0 <- rep(1/J, J)
  target_close <- p0 + rnorm(J) * 0.01
  target_close <- project_to_simplex(target_close)

  # Large radius (target should be inside)
  lambda_w <- 2.0

  # Verify target is inside ball
  w_dist_before <- wasserstein_distance_types(target_close, p0, C)
  expect_true(w_dist_before < lambda_w)

  # Project (should return target)
  q_proj <- project_onto_wasserstein_ball(target_close, p0, C, lambda_w)

  expect_equal(q_proj, target_close, tolerance = 1e-6)
})


test_that("project_onto_wasserstein_ball boundary case", {
  set.seed(789)
  J <- 6
  centroids <- matrix(rnorm(J * 2), J, 2)
  C <- compute_type_cost_matrix(centroids)

  p0 <- rep(1/J, J)

  # Target far from reference
  target_far <- MCMCpack::rdirichlet(1, rep(0.1, J))[1,]

  # Very small radius
  lambda_w <- 0.05

  # Project
  q_proj <- project_onto_wasserstein_ball(target_far, p0, C, lambda_w)

  # Should be close to reference
  w_dist <- wasserstein_distance_types(q_proj, p0, C)
  expect_true(w_dist <= lambda_w * 1.01)

  # But not exactly equal (unless target was way outside)
  if (wasserstein_distance_types(target_far, p0, C) > lambda_w * 2) {
    expect_true(sum(abs(q_proj - p0)) > 0)
  }
})


test_that("compute_type_centroids computes correct centroids", {
  # Create simple data
  data <- data.frame(
    X1 = c(1, 1, 2, 2, 3),
    X2 = c(10, 10, 20, 20, 30),
    A = c(1, 0, 1, 0, 1),
    S = rnorm(5),
    Y = rnorm(5)
  )

  bins <- c(1, 1, 2, 2, 3)
  covariate_cols <- c("X1", "X2")

  # Compute centroids
  centroids <- compute_type_centroids(data, bins, covariate_cols)

  # Check dimensions
  expect_equal(nrow(centroids), 3)  # 3 unique bins
  expect_equal(ncol(centroids), 2)  # 2 covariates

  # Check centroid values
  expect_equal(centroids[1, 1], mean(c(1, 1)))  # Bin 1, X1
  expect_equal(centroids[1, 2], mean(c(10, 10)))  # Bin 1, X2
  expect_equal(centroids[2, 1], mean(c(2, 2)))  # Bin 2, X1
  expect_equal(centroids[2, 2], mean(c(20, 20)))  # Bin 2, X2
  expect_equal(centroids[3, 1], 3)  # Bin 3, X1 (single obs)
  expect_equal(centroids[3, 2], 30)  # Bin 3, X2 (single obs)
})


test_that("compute_type_centroids validates inputs", {
  data <- data.frame(X1 = 1:5, X2 = 6:10, A = c(1, 0, 1, 0, 1))
  bins <- c(1, 1, 2, 2, 3)

  # Wrong length bins
  expect_error(
    compute_type_centroids(data, bins[1:3], c("X1", "X2")),
    "must match length"
  )

  # Missing covariate columns
  expect_error(
    compute_type_centroids(data, bins, c("X1", "X_missing")),
    "not found"
  )

  # Empty covariate_cols
  expect_error(
    compute_type_centroids(data, bins, character(0)),
    "at least one"
  )
})


test_that("integration: discretization -> centroids -> cost matrix -> W distance", {
  skip_if_not_installed("randomForest")

  # Generate synthetic data
  set.seed(999)
  n <- 200
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Discretize
  disc_result <- discretize_data(
    data,
    scheme = "kmeans",  # Use kmeans (doesn't need randomForest)
    covariate_cols = c("X1", "X2"),
    J_target = 10
  )

  expect_true(disc_result$J <= 10)

  # Compute centroids
  centroids <- compute_type_centroids(data, disc_result$bins, c("X1", "X2"))

  expect_equal(nrow(centroids), disc_result$J)
  expect_equal(ncol(centroids), 2)

  # Cost matrix
  C <- compute_type_cost_matrix(centroids, cost_function = "euclidean")

  expect_equal(dim(C), c(disc_result$J, disc_result$J))

  # Type distributions
  p0 <- as.numeric(table(disc_result$bins) / n)
  q <- MCMCpack::rdirichlet(1, rep(1, disc_result$J))[1,]

  # Wasserstein distance
  w_dist <- wasserstein_distance_types(q, p0, C)

  expect_true(w_dist >= 0)
  expect_true(is.finite(w_dist))
})
