# Tests for propensity score estimation

test_that("estimate_propensity_score works with logistic method", {
  # Generate test data
  set.seed(123)
  data <- data.frame(
    A = rbinom(200, 1, 0.5),
    X1 = rnorm(200),
    X2 = rnorm(200)
  )

  result <- estimate_propensity_score(
    data = data,
    covariates = c("X1", "X2"),
    method = "logistic",
    cross_fit = FALSE
  )

  # Check structure
  expect_type(result, "list")
  expect_named(result, c("e_hat", "method", "cross_fitted", "trimmed", "diagnostics"))

  # Check dimensions
  expect_length(result$e_hat, 200)

  # Check propensities are in [0,1]
  expect_true(all(result$e_hat >= 0 & result$e_hat <= 1))

  # Check method
  expect_equal(result$method, "logistic")
  expect_false(result$cross_fitted)

  # Check diagnostics
  expect_type(result$diagnostics, "list")
  expect_true(all(c("n_trimmed_lower", "n_trimmed_upper") %in% names(result$diagnostics)))
})


test_that("estimate_propensity_score works with cross-fitting", {
  set.seed(456)
  data <- data.frame(
    A = rbinom(250, 1, 0.5),
    X1 = rnorm(250),
    X2 = rnorm(250)
  )

  result <- estimate_propensity_score(
    data = data,
    covariates = c("X1", "X2"),
    method = "logistic",
    cross_fit = TRUE,
    K = 5
  )

  # Check cross-fitting flag
  expect_true(result$cross_fitted)

  # Check dimensions
  expect_length(result$e_hat, 250)

  # Check all propensities are valid
  expect_true(all(result$e_hat >= 0 & result$e_hat <= 1))
})


test_that("estimate_propensity_score handles randomized trial (no covariates)", {
  set.seed(789)
  data <- data.frame(
    A = rbinom(300, 1, 0.4),  # True propensity = 0.4
    X1 = rnorm(300)
  )

  # No covariates specified
  result <- estimate_propensity_score(
    data = data,
    covariates = NULL,
    method = "logistic"
  )

  # Should return constant propensity = mean(A)
  expect_equal(result$method, "constant")
  expect_true(all(result$e_hat == mean(data$A)))
  expect_false(result$cross_fitted)
  expect_false(result$trimmed)

  # Check value is close to true propensity
  expect_equal(mean(result$e_hat), mean(data$A))
})


test_that("estimate_propensity_score trims extreme values", {
  set.seed(101112)

  # Generate data with extreme propensities
  n <- 200
  X <- rnorm(n)
  # Create propensities that will be extreme
  logit_e <- 10 * X  # Very large coefficients
  e_true <- plogis(logit_e)
  A <- rbinom(n, 1, e_true)

  data <- data.frame(A = A, X1 = X)

  result <- estimate_propensity_score(
    data = data,
    covariates = "X1",
    method = "logistic",
    cross_fit = FALSE,
    trim = c(0.05, 0.95)
  )

  # Check all propensities are within trim bounds
  expect_true(all(result$e_hat >= 0.05))
  expect_true(all(result$e_hat <= 0.95))

  # Check trimming was detected
  if (any(e_true < 0.05) || any(e_true > 0.95)) {
    # This test is stochastic, only check if we expect trimming
    expect_type(result$diagnostics$n_trimmed_lower, "integer")
    expect_type(result$diagnostics$n_trimmed_upper, "integer")
  }
})


test_that("estimate_propensity_score works with GAM method (if mgcv available)", {
  skip_if_not_installed("mgcv")

  set.seed(131415)
  n <- 200
  X1 <- rnorm(n)
  X2 <- rnorm(n)

  # Nonlinear propensity
  e_true <- plogis(0.5 * X1^2 + 0.3 * X2)
  A <- rbinom(n, 1, e_true)

  data <- data.frame(A = A, X1 = X1, X2 = X2)

  result <- estimate_propensity_score(
    data = data,
    covariates = c("X1", "X2"),
    method = "gam",
    cross_fit = FALSE
  )

  expect_equal(result$method, "gam")
  expect_length(result$e_hat, 200)
  expect_true(all(result$e_hat >= 0 & result$e_hat <= 1))
})


test_that("estimate_propensity_score works with RF method (if randomForest available)", {
  skip_if_not_installed("randomForest")

  set.seed(161718)
  n <- 200
  X1 <- rnorm(n)
  X2 <- rnorm(n)

  # Interaction propensity
  e_true <- plogis(0.5 * X1 + 0.5 * X2 + 0.3 * X1 * X2)
  A <- rbinom(n, 1, e_true)

  data <- data.frame(A = A, X1 = X1, X2 = X2)

  result <- estimate_propensity_score(
    data = data,
    covariates = c("X1", "X2"),
    method = "rf",
    cross_fit = FALSE
  )

  expect_equal(result$method, "rf")
  expect_length(result$e_hat, 200)
  expect_true(all(result$e_hat >= 0 & result$e_hat <= 1))
})


test_that("estimate_propensity_score handles missing covariates error", {
  data <- data.frame(
    A = rbinom(100, 1, 0.5),
    X1 = rnorm(100)
  )

  expect_error(
    estimate_propensity_score(data, covariates = c("X1", "X_missing")),
    "Covariates not found"
  )
})


test_that("estimate_propensity_score handles missing treatment error", {
  data <- data.frame(
    X1 = rnorm(100),
    X2 = rnorm(100)
  )

  expect_error(
    estimate_propensity_score(data, covariates = c("X1", "X2")),
    "Treatment column 'A' not found"
  )
})


test_that("estimate_propensity_score diagnostics are correct", {
  set.seed(192021)
  n <- 150
  X <- rnorm(n)
  e_true <- plogis(2 * X)
  A <- rbinom(n, 1, e_true)

  data <- data.frame(A = A, X1 = X)

  result <- estimate_propensity_score(
    data = data,
    covariates = "X1",
    method = "logistic",
    cross_fit = FALSE,
    return_diagnostics = TRUE
  )

  # Check diagnostics structure
  expect_type(result$diagnostics, "list")
  expect_true("range_before_trim" %in% names(result$diagnostics))
  expect_true("range_after_trim" %in% names(result$diagnostics))

  # Range should make sense
  expect_length(result$diagnostics$range_before_trim, 2)
  expect_length(result$diagnostics$range_after_trim, 2)
})


test_that("estimate_propensity_score works without diagnostics", {
  set.seed(222324)
  data <- data.frame(
    A = rbinom(100, 1, 0.5),
    X1 = rnorm(100)
  )

  result <- estimate_propensity_score(
    data = data,
    covariates = "X1",
    return_diagnostics = FALSE
  )

  expect_null(result$diagnostics)
  expect_length(result$e_hat, 100)
})


test_that("estimate_propensity_score produces different results with/without cross-fitting", {
  set.seed(252627)
  n <- 200
  X <- rnorm(n)
  e_true <- plogis(X)
  A <- rbinom(n, 1, e_true)

  data <- data.frame(A = A, X1 = X)

  # Without cross-fitting
  result_no_cf <- estimate_propensity_score(
    data = data,
    covariates = "X1",
    cross_fit = FALSE
  )

  # With cross-fitting
  result_cf <- estimate_propensity_score(
    data = data,
    covariates = "X1",
    cross_fit = TRUE,
    K = 5
  )

  # Results should differ (cross-fitting uses out-of-fold predictions)
  expect_false(identical(result_no_cf$e_hat, result_cf$e_hat))

  # Both should be valid
  expect_true(all(result_no_cf$e_hat >= 0 & result_no_cf$e_hat <= 1))
  expect_true(all(result_cf$e_hat >= 0 & result_cf$e_hat <= 1))
})
