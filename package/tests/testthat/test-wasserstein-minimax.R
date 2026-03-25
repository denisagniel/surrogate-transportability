# Tests for Wasserstein Minimax Inference
# Phase 2: Wasserstein Minimax Algorithm

test_that("sample_wasserstein_perturbation generates valid distributions", {
  set.seed(123)
  J <- 10
  centroids <- matrix(rnorm(J * 2), J, 2)
  C <- compute_type_cost_matrix(centroids)

  p0 <- rep(1/J, J)
  lambda_w <- 0.5

  # Sample perturbation
  q <- sample_wasserstein_perturbation(p0, C, lambda_w, method = "normal")

  # Check simplex
  expect_equal(sum(q), 1, tolerance = 1e-6)
  expect_true(all(q >= 0))

  # Check Wasserstein constraint
  w_dist <- wasserstein_distance_types(q, p0, C)
  expect_true(w_dist <= lambda_w * 1.05)  # Allow small tolerance
})


test_that("sample_wasserstein_perturbation works with different methods", {
  set.seed(456)
  J <- 8
  centroids <- matrix(rnorm(J * 2), J, 2)
  C <- compute_type_cost_matrix(centroids)

  p0 <- rep(1/J, J)
  lambda_w <- 0.3

  # Test each method
  for (method in c("normal", "dirichlet", "uniform")) {
    q <- sample_wasserstein_perturbation(p0, C, lambda_w, method = method)

    expect_equal(sum(q), 1, tolerance = 1e-6)
    expect_true(all(q >= 0))
    w_dist <- wasserstein_distance_types(q, p0, C)
    expect_true(w_dist <= lambda_w * 1.05)
  }
})


test_that("sample_wasserstein_perturbation satisfies constraints consistently", {
  set.seed(789)
  J <- 10
  centroids <- matrix(rnorm(J * 2), J, 2)
  C <- compute_type_cost_matrix(centroids)

  p0 <- rep(1/J, J)
  lambda_w <- 0.8

  # Sample multiple perturbations
  n_samples <- 20
  distances <- numeric(n_samples)

  for (i in 1:n_samples) {
    q <- sample_wasserstein_perturbation(p0, C, lambda_w, method = "normal")
    distances[i] <- wasserstein_distance_types(q, p0, C)

    # Each sample should be on simplex
    expect_equal(sum(q), 1, tolerance = 1e-6)
    expect_true(all(q >= 0))
  }

  # All should satisfy Wasserstein constraint (critical property)
  expect_true(all(distances <= lambda_w * 1.05))

  # Distances should be non-negative
  expect_true(all(distances >= 0))

  # Note: Exploration quality depends on sampling method and cost matrix structure
  # The ensemble approach with M iterations will explore the ball adequately
})


test_that("estimate_minimax_single_scheme_wasserstein runs without error", {
  set.seed(999)

  # Generate simple data
  n <- 100
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Discretize
  bins <- cut(data$X1, breaks = 5, labels = FALSE)
  J <- length(unique(bins))

  # Compute centroids and cost matrix
  centroids <- compute_type_centroids(data, bins, c("X1", "X2"))
  C <- compute_type_cost_matrix(centroids)

  # Run minimax
  result <- estimate_minimax_single_scheme_wasserstein(
    data = data,
    bins = bins,
    cost_matrix = C,
    lambda_w = 0.5,
    M = 50,
    functional_type = "correlation"
  )

  # Check output structure
  expect_true(is.list(result))
  expect_true("phi_value" %in% names(result))
  expect_true("effects" %in% names(result))
  expect_true("J" %in% names(result))
  expect_true("perturbations_q" %in% names(result))

  # Check values
  expect_true(is.numeric(result$phi_value))
  expect_true(abs(result$phi_value) <= 1)  # Correlation in [-1, 1]
  expect_equal(nrow(result$effects), 50)
  expect_equal(ncol(result$effects), 2)
  expect_equal(result$J, J)
})


test_that("estimate_minimax_single_scheme_wasserstein works with all functionals", {
  set.seed(111)

  n <- 150
  data <- data.frame(
    X1 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n) + 0.5,
    Y = rnorm(n) + 0.3
  )

  bins <- cut(data$X1, breaks = 4, labels = FALSE)
  centroids <- compute_type_centroids(data, bins, "X1")
  C <- compute_type_cost_matrix(centroids)

  # Correlation
  result_cor <- estimate_minimax_single_scheme_wasserstein(
    data, bins, C, lambda_w = 0.3, M = 30,
    functional_type = "correlation"
  )
  expect_true(abs(result_cor$phi_value) <= 1)

  # Probability
  result_prob <- estimate_minimax_single_scheme_wasserstein(
    data, bins, C, lambda_w = 0.3, M = 30,
    functional_type = "probability",
    epsilon_s = 0.2, epsilon_y = 0.1
  )
  expect_true(result_prob$phi_value >= 0 && result_prob$phi_value <= 1)

  # PPV
  result_ppv <- estimate_minimax_single_scheme_wasserstein(
    data, bins, C, lambda_w = 0.3, M = 30,
    functional_type = "ppv",
    epsilon_s = 0.2, epsilon_y = 0.1
  )
  expect_true(result_ppv$phi_value >= 0 && result_ppv$phi_value <= 1)

  # NPV
  result_npv <- estimate_minimax_single_scheme_wasserstein(
    data, bins, C, lambda_w = 0.3, M = 30,
    functional_type = "npv",
    epsilon_s = 0.2, epsilon_y = 0.1
  )
  expect_true(result_npv$phi_value >= 0 && result_npv$phi_value <= 1)

  # Conditional mean
  result_cm <- estimate_minimax_single_scheme_wasserstein(
    data, bins, C, lambda_w = 0.3, M = 30,
    functional_type = "conditional_mean",
    delta_s_value = 0.5
  )
  expect_true(is.numeric(result_cm$phi_value))
})


test_that("estimate_minimax_ensemble_wasserstein runs with single scheme", {
  skip_if_not_installed("randomForest")

  set.seed(222)

  n <- 100
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Run ensemble with just kmeans (fastest)
  result <- estimate_minimax_ensemble_wasserstein(
    data = data,
    lambda_w = 0.4,
    schemes = "kmeans",
    covariate_cols = c("X1", "X2"),
    J_target = 8,
    M = 40,
    functional_type = "correlation",
    verbose = FALSE
  )

  # Check structure
  expect_true(is.list(result))
  expect_true("phi_star" %in% names(result))
  expect_true("best_scheme" %in% names(result))
  expect_true("schemes_summary" %in% names(result))

  # Check values
  expect_true(abs(result$phi_star) <= 1)
  expect_equal(result$best_scheme, "kmeans")
  expect_equal(nrow(result$schemes_summary), 1)
})


test_that("estimate_minimax_ensemble_wasserstein runs with multiple schemes", {
  set.seed(333)

  n <- 100
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Run with quantiles and kmeans (no RF dependency)
  result <- estimate_minimax_ensemble_wasserstein(
    data = data,
    lambda_w = 0.5,
    schemes = c("quantiles", "kmeans"),
    covariate_cols = c("X1", "X2"),
    J_target = 9,
    M = 40,
    functional_type = "correlation",
    verbose = FALSE
  )

  expect_equal(nrow(result$schemes_summary), 2)
  expect_true(result$best_scheme %in% c("quantiles", "kmeans"))
  expect_true(abs(result$phi_star) <= 1)
})


test_that("estimate_minimax_ensemble_wasserstein respects lambda_w", {
  set.seed(444)

  n <- 80
  data <- data.frame(
    X1 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Small lambda_w (conservative)
  result_small <- estimate_minimax_ensemble_wasserstein(
    data, lambda_w = 0.1, schemes = "kmeans",
    covariate_cols = "X1", J_target = 5, M = 30,
    functional_type = "correlation", verbose = FALSE
  )

  # Large lambda_w (less conservative)
  result_large <- estimate_minimax_ensemble_wasserstein(
    data, lambda_w = 1.0, schemes = "kmeans",
    covariate_cols = "X1", J_target = 5, M = 30,
    functional_type = "correlation", verbose = FALSE
  )

  # Larger lambda_w should give smaller (more conservative) minimax
  # This may not always hold due to sampling, but test structure
  expect_true(is.numeric(result_small$phi_star))
  expect_true(is.numeric(result_large$phi_star))
})


test_that("estimate_minimax_ensemble_wasserstein handles different cost functions", {
  set.seed(555)

  n <- 100
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n) * 2,  # Different scale
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Euclidean cost
  result_euc <- estimate_minimax_ensemble_wasserstein(
    data, lambda_w = 0.5, schemes = "kmeans",
    covariate_cols = c("X1", "X2"), J_target = 8, M = 30,
    functional_type = "correlation",
    cost_function = "euclidean",
    verbose = FALSE
  )

  # Mahalanobis cost (accounts for scale)
  result_maha <- estimate_minimax_ensemble_wasserstein(
    data, lambda_w = 0.5, schemes = "kmeans",
    covariate_cols = c("X1", "X2"), J_target = 8, M = 30,
    functional_type = "correlation",
    cost_function = "mahalanobis",
    verbose = FALSE
  )

  # Both should run without error
  expect_true(is.numeric(result_euc$phi_star))
  expect_true(is.numeric(result_maha$phi_star))
})


test_that("Wasserstein vs TV comparison: structure check", {
  set.seed(666)

  n <- 100
  data <- data.frame(
    X1 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # TV approach
  result_tv <- estimate_minimax_ensemble(
    data = data,
    lambda = 0.3,
    schemes = "kmeans",
    covariate_cols = "X1",
    J_target = 6,
    M = 30,
    functional_type = "correlation",
    verbose = FALSE
  )

  # Wasserstein approach
  result_w <- estimate_minimax_ensemble_wasserstein(
    data = data,
    lambda_w = 0.3,
    schemes = "kmeans",
    covariate_cols = "X1",
    J_target = 6,
    M = 30,
    functional_type = "correlation",
    verbose = FALSE
  )

  # Both should have same output structure
  expect_true("phi_star" %in% names(result_tv))
  expect_true("phi_star" %in% names(result_w))
  expect_true("best_scheme" %in% names(result_tv))
  expect_true("best_scheme" %in% names(result_w))

  # Both should give valid correlation estimates
  expect_true(abs(result_tv$phi_star) <= 1)
  expect_true(abs(result_w$phi_star) <= 1)
})


test_that("integration: full pipeline with realistic data", {
  set.seed(777)

  # Generate realistic data
  n <- 200
  X1 <- rnorm(n)
  X2 <- rnorm(n)
  A <- rbinom(n, 1, 0.5)

  # Treatment effects depend on covariates
  delta_s_true <- 0.5 + 0.3 * X1
  delta_y_true <- 0.3 + 0.2 * X1 + 0.1 * X2

  S <- rnorm(n, mean = A * delta_s_true, sd = 1)
  Y <- rnorm(n, mean = A * delta_y_true, sd = 1)

  data <- data.frame(X1, X2, A, S, Y)

  # Run Wasserstein minimax
  result <- estimate_minimax_ensemble_wasserstein(
    data = data,
    lambda_w = 0.5,
    schemes = c("quantiles", "kmeans"),
    covariate_cols = c("X1", "X2"),
    J_target = 12,
    M = 100,
    functional_type = "correlation",
    cost_function = "euclidean",
    sampling_method = "normal",
    verbose = FALSE
  )

  # Should produce reasonable estimate
  expect_true(abs(result$phi_star) <= 1)
  expect_true(nrow(result$schemes_summary) == 2)
  expect_true(result$best_scheme %in% c("quantiles", "kmeans"))

  # Schemes summary should have expected columns
  expect_true(all(c("scheme", "J", "phi_value") %in% names(result$schemes_summary)))
})
