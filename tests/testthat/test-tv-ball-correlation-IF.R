# Tests for TV Ball Correlation with IF-Based Inference

test_that("gradient_correlation_analytical matches numerical gradient", {
  # Generate treatment effects
  M <- 100
  set.seed(123)
  Delta_S <- rnorm(M, mean = 0.3, sd = 0.2)
  Delta_Y <- rnorm(M, mean = 0.4, sd = 0.25)

  # Analytical gradient
  grad_analytical <- gradient_correlation_analytical(Delta_S, Delta_Y)

  # Numerical gradient (for validation)
  grad_numerical <- gradient_correlation_numerical(Delta_S, Delta_Y, eps = 1e-6)

  # Validate: analytical and numerical should be highly correlated
  # (point-by-point exact match not expected due to finite difference error)
  expect_gt(cor(grad_analytical[, 1], grad_numerical[, 1]), 0.999)
  expect_gt(cor(grad_analytical[, 2], grad_numerical[, 2]), 0.999)

  # Mean absolute error should be small
  mae_grad_S <- mean(abs(grad_analytical[, 1] - grad_numerical[, 1]))
  mae_grad_Y <- mean(abs(grad_analytical[, 2] - grad_numerical[, 2]))
  expect_lt(mae_grad_S, 0.002)
  expect_lt(mae_grad_Y, 0.002)
})

test_that("gradient_correlation_analytical sums to approximately zero", {
  # Generate treatment effects
  M <- 100
  set.seed(124)
  Delta_S <- rnorm(M, mean = 0.3, sd = 0.2)
  Delta_Y <- rnorm(M, mean = 0.4, sd = 0.25)

  # Compute gradient
  grad <- gradient_correlation_analytical(Delta_S, Delta_Y)

  # Gradient should be approximately centered (sum to 0)
  # This is a property of influence functions
  expect_lt(abs(sum(grad[, 1])), 1e-10)
  expect_lt(abs(sum(grad[, 2])), 1e-10)
})

test_that("gradient_correlation_analytical handles edge cases", {
  # Case 1: Zero variance in Delta_S
  Delta_S <- rep(0.3, 100)
  Delta_Y <- rnorm(100)

  expect_warning(
    grad <- gradient_correlation_analytical(Delta_S, Delta_Y),
    "Standard deviation near zero"
  )
  expect_true(all(is.na(grad)))

  # Case 2: Too few observations
  expect_error(
    gradient_correlation_analytical(c(0.3), c(0.4)),
    "at least 2 observations"
  )
})

test_that("sample_tv_ball returns valid samples", {
  n <- 50
  P0 <- rep(1/n, n)
  lambda <- 0.3
  M <- 20  # Small M for fast test

  set.seed(125)
  Q_samples <- sample_tv_ball(P0, lambda, M,
                              burn_in = 100, thin = 5, verbose = FALSE)

  # Check dimensions
  expect_equal(dim(Q_samples), c(M, n))

  # Check all samples sum to 1
  row_sums <- rowSums(Q_samples)
  expect_true(all(abs(row_sums - 1) < 1e-6))

  # Check all samples non-negative
  expect_true(all(Q_samples >= -1e-10))

  # Check TV distances
  tv_dists <- apply(Q_samples, 1, function(q) 0.5 * sum(abs(q - P0)))
  expect_true(all(tv_dists <= lambda + 1e-6))
})

test_that("tv_ball_correlation_IF runs on simple RCT data", {
  skip_on_cran()  # Takes ~10 seconds

  # Generate simple RCT data
  set.seed(126)
  n <- 200
  data <- data.frame(
    X = rnorm(n),
    A = rbinom(n, 1, 0.5)
  )
  data$S <- data$A * 0.3 + rnorm(n, sd = 0.5)
  data$Y <- data$A * 0.4 + rnorm(n, sd = 0.6)

  # Run IF-based inference
  result <- tv_ball_correlation_IF(
    data = data,
    lambda = 0.3,
    M = 50,  # Small M for fast test
    burn_in = 100,
    thin = 5,
    verbose = FALSE
  )

  # Check structure
  expect_type(result, "list")
  expect_named(result, c("rho_hat", "se", "ci_lower", "ci_upper", "IF_vals",
                         "Delta_S", "Delta_Y", "Q_samples", "gradient",
                         "lambda", "M", "n", "alpha", "burn_in", "thin", "method"))

  # Check values are reasonable
  expect_type(result$rho_hat, "double")
  expect_length(result$rho_hat, 1)
  expect_true(result$rho_hat >= -1 && result$rho_hat <= 1)

  expect_true(result$se > 0)
  expect_true(result$ci_lower < result$ci_upper)

  # Check IF values
  expect_length(result$IF_vals, n)
  expect_type(result$IF_vals, "double")

  # IF should sum to approximately 0 (centered)
  expect_lt(abs(sum(result$IF_vals)), 0.1 * n)

  # Check treatment effects
  expect_length(result$Delta_S, result$M)
  expect_length(result$Delta_Y, result$M)

  # Check gradient
  expect_equal(dim(result$gradient), c(result$M, 2))
})

test_that("tv_ball_correlation_IF validates inputs", {
  n <- 100
  data <- data.frame(
    X = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Missing required columns
  bad_data <- data[, c("X", "A", "S")]
  expect_error(
    tv_ball_correlation_IF(bad_data, lambda = 0.3, M = 10, verbose = FALSE),
    "Required columns missing"
  )

  # Non-binary treatment
  bad_data <- data
  bad_data$A[1] <- 2
  expect_error(
    tv_ball_correlation_IF(bad_data, lambda = 0.3, M = 10, verbose = FALSE),
    "Treatment A must be binary"
  )
})

test_that("tv_ball_correlation_IF handles zero variance case", {
  # Generate data with no variation in treatment effects
  set.seed(127)
  n <- 100
  data <- data.frame(
    X = rep(1, n),  # All same covariate
    A = rbinom(n, 1, 0.5)
  )
  data$S <- rep(0.5, n)  # Constant outcome
  data$Y <- rep(0.6, n)  # Constant outcome

  # Should warn about zero variance
  expect_warning(
    result <- tv_ball_correlation_IF(
      data = data,
      lambda = 0.1,
      M = 20,
      burn_in = 50,
      thin = 2,
      verbose = FALSE
    ),
    "Gradient contains NA|zero variance"
  )

  # Should return with NA standard error
  expect_true(is.na(result$se))
})
