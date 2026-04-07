test_that("compute_tv_distance returns 0 for identical distributions", {
  P0 <- c(0.3, 0.5, 0.2)

  tv_dist <- compute_tv_distance(P0, P0)

  expect_equal(tv_dist, 0)
  expect_type(tv_dist, "double")
})


test_that("compute_tv_distance returns 1 for disjoint support", {
  Q1 <- c(1, 0, 0)
  Q2 <- c(0, 1, 0)

  tv_dist <- compute_tv_distance(Q1, Q2)

  expect_equal(tv_dist, 1)
})


test_that("compute_tv_distance computes known values correctly", {
  # Example 1: Small perturbation
  P0 <- c(0.3, 0.5, 0.2)
  Q <- c(0.4, 0.4, 0.2)

  # TV = 0.5 * (|0.4-0.3| + |0.4-0.5| + |0.2-0.2|)
  #    = 0.5 * (0.1 + 0.1 + 0)
  #    = 0.1
  tv_dist <- compute_tv_distance(Q, P0)
  expect_equal(tv_dist, 0.1)

  # Example 2: Larger difference
  P0_2 <- c(0.25, 0.25, 0.25, 0.25)
  Q_2 <- c(0.5, 0.5, 0, 0)

  # TV = 0.5 * (|0.5-0.25| + |0.5-0.25| + |0-0.25| + |0-0.25|)
  #    = 0.5 * (0.25 + 0.25 + 0.25 + 0.25)
  #    = 0.5
  tv_dist_2 <- compute_tv_distance(Q_2, P0_2)
  expect_equal(tv_dist_2, 0.5)
})


test_that("compute_tv_distance is symmetric", {
  P0 <- c(0.3, 0.5, 0.2)
  Q <- c(0.4, 0.4, 0.2)

  tv_pq <- compute_tv_distance(P0, Q)
  tv_qp <- compute_tv_distance(Q, P0)

  expect_equal(tv_pq, tv_qp)
})


test_that("compute_tv_distance validates inputs correctly", {
  P0 <- c(0.3, 0.5, 0.2)

  # Different lengths
  expect_error(
    compute_tv_distance(P0, c(0.5, 0.5)),
    "same length"
  )

  # Non-numeric inputs
  expect_error(
    compute_tv_distance(P0, c("a", "b", "c")),
    "must be numeric"
  )

  # Negative probabilities
  expect_error(
    compute_tv_distance(P0, c(0.5, -0.2, 0.7)),
    "non-negative"
  )

  # Not normalized
  expect_error(
    compute_tv_distance(P0, c(0.3, 0.3, 0.3)),
    "sum to 1"
  )
})


test_that("compute_tv_distance satisfies triangle inequality", {
  P <- c(0.3, 0.5, 0.2)
  Q <- c(0.4, 0.4, 0.2)
  R <- c(0.2, 0.3, 0.5)

  tv_pq <- compute_tv_distance(P, Q)
  tv_qr <- compute_tv_distance(Q, R)
  tv_pr <- compute_tv_distance(P, R)

  # d(P, R) <= d(P, Q) + d(Q, R)
  expect_lte(tv_pr, tv_pq + tv_qr + 1e-10)
})


test_that("compute_tv_distance handles edge cases", {
  # Single-element distributions
  P_single <- 1
  tv_single <- compute_tv_distance(P_single, P_single)
  expect_equal(tv_single, 0)

  # Very small probabilities
  P_small <- c(1e-10, 1 - 1e-10)
  Q_small <- c(1 - 1e-10, 1e-10)
  tv_small <- compute_tv_distance(P_small, Q_small)
  expect_equal(tv_small, 1 - 1e-10, tolerance = 1e-9)

  # Many categories
  n <- 100
  P_many <- rep(1/n, n)
  Q_many <- c(2/n, rep((1-2/n)/(n-1), n-1))
  tv_many <- compute_tv_distance(P_many, Q_many)
  expect_gte(tv_many, 0)
  expect_lte(tv_many, 1)
})


test_that("verify_tv_constraint correctly identifies constraint satisfaction", {
  P0 <- c(0.3, 0.5, 0.2)
  P_tilde <- c(0.6, 0.1, 0.3)
  lambda <- 0.4
  Q <- (1 - lambda) * P0 + lambda * P_tilde

  result <- verify_tv_constraint(Q, P0, lambda)

  expect_true(result$satisfies_constraint)
  expect_lte(result$tv_distance, lambda + 1e-10)
  expect_equal(result$lambda, lambda)
  expect_equal(result$violation, 0)
  expect_gte(result$margin, 0)
})


test_that("verify_tv_constraint correctly identifies constraint violation", {
  P0 <- c(0.3, 0.5, 0.2)
  Q_bad <- c(0.9, 0.05, 0.05)  # Far from P0

  # This Q is far from P0, so TV distance is large
  tv_actual <- compute_tv_distance(Q_bad, P0)

  # Set lambda smaller than actual TV distance
  lambda_small <- tv_actual / 2

  result <- verify_tv_constraint(Q_bad, P0, lambda_small)

  expect_false(result$satisfies_constraint)
  expect_gt(result$tv_distance, lambda_small)
  expect_gt(result$violation, 0)
  expect_lt(result$margin, 0)
})


test_that("verify_tv_constraint validates lambda input", {
  P0 <- c(0.3, 0.5, 0.2)

  expect_error(
    verify_tv_constraint(P0, P0, lambda = -0.1),
    "lambda must be in"
  )

  expect_error(
    verify_tv_constraint(P0, P0, lambda = 1.5),
    "lambda must be in"
  )

  expect_error(
    verify_tv_constraint(P0, P0, lambda = c(0.3, 0.4)),
    "single numeric value"
  )
})


test_that("verify_tv_constraint returns correct structure", {
  P0 <- c(0.3, 0.5, 0.2)
  result <- verify_tv_constraint(P0, P0, lambda = 0.5)

  expect_type(result, "list")
  expect_named(result, c("satisfies_constraint", "tv_distance", "lambda",
                         "violation", "margin"))
  expect_type(result$satisfies_constraint, "logical")
  expect_type(result$tv_distance, "double")
  expect_type(result$lambda, "double")
  expect_type(result$violation, "double")
  expect_type(result$margin, "double")
})


test_that("generate_tv_ball_point successfully reconstructs target in TV ball", {
  P0 <- c(0.3, 0.5, 0.2)
  Q_target <- c(0.4, 0.4, 0.2)

  result <- generate_tv_ball_point(P0, Q_target, lambda_max = 0.5)

  expect_true(result$satisfies_constraint)
  expect_true(result$algorithm_successful)
  expect_lt(result$reconstruction_error, 1e-9)

  # Verify Q_reconstructed matches Q_target
  expect_equal(result$Q_reconstructed, Q_target, tolerance = 1e-9)

  # Verify P_tilde is a valid distribution
  expect_true(all(result$P_tilde >= 0))
  expect_equal(sum(result$P_tilde), 1, tolerance = 1e-10)

  # Verify the mixture formula
  Q_check <- (1 - result$lambda_actual) * P0 + result$lambda_actual * result$P_tilde
  expect_equal(Q_check, Q_target, tolerance = 1e-9)
})


test_that("generate_tv_ball_point handles special case Q = P0", {
  P0 <- c(0.3, 0.5, 0.2)

  result <- generate_tv_ball_point(P0, Q_target = P0, lambda_max = 0.5)

  expect_equal(result$lambda_actual, 0)
  expect_equal(result$tv_distance, 0)
  expect_equal(result$P_tilde, P0)
  expect_equal(result$Q_reconstructed, P0)
  expect_equal(result$reconstruction_error, 0)
  expect_true(result$satisfies_constraint)
  expect_true(result$algorithm_successful)
})


test_that("generate_tv_ball_point detects target outside TV ball", {
  P0 <- c(0.3, 0.5, 0.2)
  Q_far <- c(0.9, 0.05, 0.05)

  # This Q is far from P0
  tv_actual <- compute_tv_distance(Q_far, P0)

  # Set lambda_max smaller than actual distance
  lambda_max <- tv_actual / 2

  result <- generate_tv_ball_point(P0, Q_far, lambda_max = lambda_max)

  expect_false(result$satisfies_constraint)
  expect_gt(result$tv_distance, lambda_max)
})


test_that("generate_tv_ball_point validates inputs", {
  P0 <- c(0.3, 0.5, 0.2)

  # Different lengths
  expect_error(
    generate_tv_ball_point(P0, c(0.5, 0.5), lambda_max = 0.5),
    "same length"
  )

  # P0 with zero entries (not invertible)
  P0_zero <- c(0.5, 0.5, 0)
  Q <- c(0.6, 0.4, 0)
  expect_error(
    generate_tv_ball_point(P0_zero, Q, lambda_max = 0.5),
    "strictly positive"
  )

  # Negative probabilities
  expect_error(
    generate_tv_ball_point(P0, c(0.5, -0.2, 0.7), lambda_max = 0.5),
    "non-negative"
  )

  # Invalid lambda_max
  expect_error(
    generate_tv_ball_point(P0, P0, lambda_max = -0.1),
    "lambda_max must be in"
  )

  expect_error(
    generate_tv_ball_point(P0, P0, lambda_max = 1.5),
    "lambda_max must be in"
  )
})


test_that("generate_tv_ball_point returns correct structure", {
  P0 <- c(0.3, 0.5, 0.2)
  Q <- c(0.4, 0.4, 0.2)

  result <- generate_tv_ball_point(P0, Q, lambda_max = 0.5)

  expect_type(result, "list")
  expect_named(result, c("P_tilde", "lambda_actual", "Q_reconstructed",
                         "reconstruction_error", "tv_distance",
                         "satisfies_constraint", "algorithm_successful"))

  expect_type(result$P_tilde, "double")
  expect_type(result$lambda_actual, "double")
  expect_type(result$Q_reconstructed, "double")
  expect_type(result$reconstruction_error, "double")
  expect_type(result$tv_distance, "double")
  expect_type(result$satisfies_constraint, "logical")
  expect_type(result$algorithm_successful, "logical")
})


test_that("generate_tv_ball_point works with different lambda values", {
  P0 <- c(0.25, 0.25, 0.25, 0.25)

  # Test with various lambda values
  lambda_values <- c(0.1, 0.3, 0.5, 0.7, 0.9)

  for (lambda in lambda_values) {
    # Generate Q using innovation mechanism
    P_tilde <- c(0.4, 0.3, 0.2, 0.1)
    Q <- (1 - lambda) * P0 + lambda * P_tilde

    result <- generate_tv_ball_point(P0, Q, lambda_max = 1)

    expect_true(result$algorithm_successful,
                label = sprintf("algorithm_successful for lambda = %.2f", lambda))
    expect_lt(result$reconstruction_error, 1e-9)
  }
})
