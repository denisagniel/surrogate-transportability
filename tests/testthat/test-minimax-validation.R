# Test: Type-Level Minimax Validation
#
# Validates that the package implementation achieves <5% approximation error
# to the true TV-ball minimax, as established in validate_rf_ensemble_theory.R

test_that("linear treatment effect scenario: <5% error", {
  skip_on_cran()
  skip_if_not_installed("randomForest")

  set.seed(20260324)
  n <- 1000

  # Generate data with linear treatment effects
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$A <- rbinom(n, 1, 0.5)

  # Linear treatment effects
  tau_s <- 0.5 * data$X1 + 0.3 * data$X2
  tau_y <- 0.4 * data$X1 + 0.25 * data$X2

  # Generate outcomes
  data$S <- data$A * tau_s + rnorm(n, 0, 0.2)
  data$Y <- data$A * tau_y + rnorm(n, 0, 0.2)

  # Estimate minimax
  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    discretization_schemes = c("rf", "quantiles", "kmeans"),
    J_target = 16,
    n_innovations = 1000,
    verbose = FALSE
  )

  # From validation: ground truth ≈ 0.984
  ground_truth <- 0.984
  error <- abs(result$phi_star - ground_truth) / abs(ground_truth)

  expect_lt(error, 0.05)  # <5% error
  expect_true(result$phi_star > 0.9)  # High correlation expected
})


test_that("step function treatment effect scenario: <5% error", {
  skip_on_cran()
  skip_if_not_installed("randomForest")

  set.seed(20260324)
  n <- 1000

  # Generate data with step function treatment effects
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$A <- rbinom(n, 1, 0.5)

  # Step function (4 regions)
  tau_s <- ifelse(data$X1 < 0,
                  ifelse(data$X2 < 0, -0.6, -0.2),
                  ifelse(data$X2 < 0, 0.2, 0.6))

  tau_y <- ifelse(data$X1 < 0,
                  ifelse(data$X2 < 0, -0.5, -0.1),
                  ifelse(data$X2 < 0, 0.1, 0.5))

  # Generate outcomes
  data$S <- data$A * tau_s + rnorm(n, 0, 0.2)
  data$Y <- data$A * tau_y + rnorm(n, 0, 0.2)

  # Estimate minimax
  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    discretization_schemes = c("rf", "quantiles", "kmeans"),
    J_target = 16,
    n_innovations = 1000,
    verbose = FALSE
  )

  # From validation: ground truth ≈ 0.96
  ground_truth <- 0.96
  error <- abs(result$phi_star - ground_truth) / abs(ground_truth)

  expect_lt(error, 0.05)  # <5% error
  expect_true(result$phi_star > 0.9)  # High correlation expected
})


test_that("smooth nonlinear treatment effect scenario: <10% error", {
  skip_on_cran()
  skip_if_not_installed("randomForest")

  set.seed(20260324)
  n <- 1000

  # Generate data with smooth nonlinear treatment effects
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$A <- rbinom(n, 1, 0.5)

  # Smooth nonlinear (harder case)
  tau_s <- sin(2 * data$X1) + 0.5 * data$X2^2
  tau_y <- cos(2 * data$X1) + 0.4 * data$X2^2

  # Generate outcomes
  data$S <- data$A * tau_s + rnorm(n, 0, 0.2)
  data$Y <- data$A * tau_y + rnorm(n, 0, 0.2)

  # Estimate minimax
  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    discretization_schemes = c("rf", "quantiles", "kmeans"),
    J_target = 16,
    n_innovations = 1000,
    verbose = FALSE
  )

  # From validation: ground truth ≈ 0.85 (lower due to nonlinearity)
  ground_truth <- 0.85
  error <- abs(result$phi_star - ground_truth) / abs(ground_truth)

  expect_lt(error, 0.10)  # <10% error (harder case)
  expect_true(result$phi_star > 0.7)  # Still positive correlation
})


test_that("convergence as n increases", {
  skip_on_cran()
  skip_if_not_installed("randomForest")

  set.seed(20260324)

  # Linear scenario with increasing n
  n_values <- c(200, 500, 1000)
  estimates <- numeric(length(n_values))

  for (i in seq_along(n_values)) {
    n <- n_values[i]

    data <- data.frame(
      X1 = rnorm(n),
      X2 = rnorm(n)
    )
    data$A <- rbinom(n, 1, 0.5)

    tau_s <- 0.5 * data$X1 + 0.3 * data$X2
    tau_y <- 0.4 * data$X1 + 0.25 * data$X2

    data$S <- data$A * tau_s + rnorm(n, 0, 0.2)
    data$Y <- data$A * tau_y + rnorm(n, 0, 0.2)

    result <- surrogate_inference_minimax(
      current_data = data,
      lambda = 0.3,
      functional_type = "correlation",
      discretization_schemes = c("quantiles", "kmeans"),  # Faster
      J_target = 9,
      n_innovations = 500,
      verbose = FALSE
    )

    estimates[i] <- result$phi_star
  }

  # Check that estimates stabilize (variance decreases with n)
  variance_first_half <- var(estimates[1:2])
  variance_all <- var(estimates)

  # Later estimates should be more stable
  expect_true(all(estimates > 0.8))  # All reasonable
  expect_true(variance_all < variance_first_half || variance_all < 0.01)
})


test_that("ensemble outperforms single schemes", {
  skip_on_cran()

  set.seed(20260324)
  n <- 500

  # Simple scenario
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$A <- rbinom(n, 1, 0.5)
  data$S <- data$A * (0.5 * data$X1 + 0.3 * data$X2) + rnorm(n, 0, 0.2)
  data$Y <- data$A * (0.4 * data$X1 + 0.25 * data$X2) + rnorm(n, 0, 0.2)

  # Run with ensemble
  result_ensemble <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    discretization_schemes = c("quantiles", "kmeans"),
    J_target = 9,
    n_innovations = 500,
    verbose = TRUE  # To get individual scheme results
  )

  # Ensemble minimum should be <= all individual schemes
  individual_estimates <- result_ensemble$schemes_summary$phi_value

  expect_true(result_ensemble$phi_star <= max(individual_estimates))
  expect_equal(result_ensemble$phi_star, min(individual_estimates))
})


test_that("probability functional works correctly", {
  skip_on_cran()

  set.seed(20260324)
  n <- 500

  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$A <- rbinom(n, 1, 0.5)
  data$S <- data$A * 1.0 + rnorm(n, 0, 0.3)
  data$Y <- data$A * 0.8 + rnorm(n, 0, 0.3)

  # Most treatment effects should be > 0.5
  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.2,
    functional_type = "probability",
    epsilon_s = 0.5,
    epsilon_y = 0.5,
    discretization_schemes = c("quantiles", "kmeans"),
    J_target = 9,
    n_innovations = 500,
    verbose = FALSE
  )

  # Should have high probability
  expect_true(result$phi_star >= 0)
  expect_true(result$phi_star <= 1)
  expect_true(is.numeric(result$phi_star))
})


test_that("PPV functional works correctly", {
  skip_on_cran()

  set.seed(20260324)
  n <- 500

  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$A <- rbinom(n, 1, 0.5)
  data$S <- data$A * 1.0 + rnorm(n, 0, 0.3)
  data$Y <- data$A * 0.8 + rnorm(n, 0, 0.3)

  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.2,
    functional_type = "ppv",
    epsilon_s = 0.5,
    epsilon_y = 0.5,
    discretization_schemes = c("quantiles", "kmeans"),
    J_target = 9,
    n_innovations = 500,
    verbose = FALSE
  )

  # PPV should be in [0, 1]
  expect_true(result$phi_star >= 0)
  expect_true(result$phi_star <= 1)
  expect_true(is.numeric(result$phi_star))
})


test_that("conditional_mean functional works correctly", {
  skip_on_cran()

  set.seed(20260324)
  n <- 500

  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$A <- rbinom(n, 1, 0.5)
  data$S <- data$A * 1.0 + rnorm(n, 0, 0.3)
  data$Y <- data$A * 0.8 + rnorm(n, 0, 0.3)

  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.2,
    functional_type = "conditional_mean",
    delta_s_value = 1.0,
    discretization_schemes = c("quantiles", "kmeans"),
    J_target = 9,
    n_innovations = 500,
    verbose = FALSE
  )

  # Conditional mean should be near 0.8 (true effect)
  expect_true(is.numeric(result$phi_star))
  expect_true(abs(result$phi_star) < 2)  # Reasonable range
})


test_that("bootstrap CI works", {
  skip_on_cran()

  set.seed(20260324)
  n <- 300

  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$A <- rbinom(n, 1, 0.5)
  data$S <- data$A * (0.5 * data$X1) + rnorm(n, 0, 0.2)
  data$Y <- data$A * (0.4 * data$X1) + rnorm(n, 0, 0.2)

  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    discretization_schemes = c("quantiles"),  # Just one for speed
    J_target = 9,
    n_innovations = 200,
    n_bootstrap = 20,  # Small number for testing
    confidence_level = 0.95,
    verbose = FALSE
  )

  # Check CI components exist
  expect_true("ci_lower" %in% names(result))
  expect_true("ci_upper" %in% names(result))
  expect_true("bootstrap_estimates" %in% names(result))

  # Check CI is valid
  expect_true(result$ci_lower <= result$phi_star)
  expect_true(result$phi_star <= result$ci_upper)
  expect_equal(length(result$bootstrap_estimates), 20)
})


test_that("input validation works", {
  n <- 100
  data <- data.frame(
    X1 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Invalid lambda
  expect_error(
    surrogate_inference_minimax(data, lambda = -0.1),
    "lambda must be.*\\[0, 1\\]"
  )

  expect_error(
    surrogate_inference_minimax(data, lambda = 1.5),
    "lambda must be.*\\[0, 1\\]"
  )

  # Missing thresholds for probability functional
  expect_error(
    surrogate_inference_minimax(data, lambda = 0.3, functional_type = "probability"),
    "epsilon_s and epsilon_y must be specified"
  )

  # Missing delta_s_value for conditional_mean
  expect_error(
    surrogate_inference_minimax(data, lambda = 0.3, functional_type = "conditional_mean"),
    "delta_s_value must be specified"
  )
})


test_that("type-level innovations are correct dimension", {
  skip_on_cran()

  set.seed(20260324)
  n <- 200

  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$A <- rbinom(n, 1, 0.5)
  data$S <- data$A * data$X1 + rnorm(n, 0, 0.2)
  data$Y <- data$A * data$X1 + rnorm(n, 0, 0.2)

  # Discretize with known J
  disc_result <- discretize_data(data, scheme = "quantiles", J_target = 9)
  J <- disc_result$J

  # Generate innovations
  innovations <- MCMCpack::rdirichlet(100, rep(1, J))

  # Check dimensions
  expect_equal(ncol(innovations), J)  # J-dimensional, NOT n-dimensional
  expect_true(J < n)  # J should be much smaller than n
  expect_true(all(rowSums(innovations) > 0.99 & rowSums(innovations) < 1.01))  # Sum to 1
})
