# Test: Discretization Functions

test_that("discretize_quantiles works correctly", {
  set.seed(20260324)
  n <- 100

  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  bins <- discretize_quantiles(data, c("X1", "X2"), n_bins = 3)

  # Check output
  expect_type(bins, "integer")
  expect_equal(length(bins), n)
  expect_true(all(bins >= 1))

  # Number of unique bins should be <= 3^2 = 9
  J <- length(unique(bins))
  expect_true(J <= 9)
  expect_true(J >= 1)
})


test_that("discretize_kmeans works correctly", {
  set.seed(20260324)
  n <- 100

  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  bins <- discretize_kmeans(data, c("X1", "X2"), k = 5)

  # Check output
  expect_type(bins, "integer")
  expect_equal(length(bins), n)
  expect_true(all(bins >= 1))

  # Number of unique bins should be <= k
  J <- length(unique(bins))
  expect_true(J <= 5)
  expect_true(J >= 1)
})


test_that("train_rf_partition works correctly", {
  skip_if_not_installed("randomForest")

  set.seed(20260324)
  n <- 100

  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n) + rnorm(n, 0, 0.1),
    Y = rnorm(n) + rnorm(n, 0, 0.1)
  )

  bins <- train_rf_partition(data, c("X1", "X2"), ntree = 100, maxnodes = 5, n_bins = 3)

  # Check output
  expect_type(bins, "integer")
  expect_equal(length(bins), n)
  expect_true(all(bins >= 1))

  # Should have some bins
  J <- length(unique(bins))
  expect_true(J >= 1)
  expect_true(J <= 25)  # n_bins^2 = 9, but RF may create fewer
})


test_that("train_rf_partition errors with too few treated units", {
  skip_if_not_installed("randomForest")

  set.seed(20260324)
  n <- 20

  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    A = c(rep(1, 5), rep(0, 15)),  # Only 5 treated
    S = rnorm(n),
    Y = rnorm(n)
  )

  expect_error(
    train_rf_partition(data, c("X1", "X2")),
    "Need at least 10 treated units"
  )
})


test_that("discretize_data works with auto-detected covariates", {
  set.seed(20260324)
  n <- 100

  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    X3 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Auto-detect covariates (should find X1, X2, X3)
  result <- discretize_data(data, scheme = "quantiles", J_target = 9)

  expect_equal(result$scheme, "quantiles")
  expect_type(result$bins, "integer")
  expect_equal(length(result$bins), n)
  expect_equal(result$J, length(unique(result$bins)))
  expect_true("X1" %in% result$covariate_cols)
  expect_true("X2" %in% result$covariate_cols)
  expect_true("X3" %in% result$covariate_cols)
  expect_false("A" %in% result$covariate_cols)
  expect_false("S" %in% result$covariate_cols)
  expect_false("Y" %in% result$covariate_cols)
})


test_that("discretize_data works with manual covariate specification", {
  set.seed(20260324)
  n <- 100

  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    X3 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Manually specify only X1 and X2
  result <- discretize_data(data, scheme = "quantiles",
                             covariate_cols = c("X1", "X2"),
                             J_target = 9)

  expect_equal(result$covariate_cols, c("X1", "X2"))
  expect_type(result$bins, "integer")
  expect_equal(length(result$bins), n)
})


test_that("discretize_data handles all schemes", {
  skip_if_not_installed("randomForest")

  set.seed(20260324)
  n <- 100

  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Test each scheme
  schemes <- c("rf", "quantiles", "kmeans")

  for (scheme in schemes) {
    result <- discretize_data(data, scheme = scheme, J_target = 9)

    expect_equal(result$scheme, scheme)
    expect_type(result$bins, "integer")
    expect_equal(length(result$bins), n)
    expect_true(result$J >= 1)
  }
})


test_that("discretize_data adapts J_target to scheme", {
  set.seed(20260324)
  n <- 200

  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # K-means should create exactly J_target (or close) clusters
  result_kmeans <- discretize_data(data, scheme = "kmeans", J_target = 16)
  expect_true(abs(result_kmeans$J - 16) <= 2)  # Allow small deviation

  # Quantiles: J ≈ n_bins^p where p=2
  result_quant <- discretize_data(data, scheme = "quantiles", J_target = 16)
  expect_true(result_quant$J >= 9)  # At least 3^2
  expect_true(result_quant$J <= 25)  # At most 5^2
})


test_that("discretization handles constant columns", {
  set.seed(20260324)
  n <- 100

  data <- data.frame(
    X1 = rep(1, n),  # Constant
    X2 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # K-means should handle constant columns
  result <- discretize_data(data, scheme = "kmeans", J_target = 9)

  expect_type(result$bins, "integer")
  expect_equal(length(result$bins), n)
  expect_true(result$J >= 1)
})


test_that("discretization errors with missing covariate columns", {
  set.seed(20260324)
  n <- 100

  data <- data.frame(
    X1 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  expect_error(
    discretize_data(data, scheme = "quantiles", covariate_cols = c("X1", "X_missing")),
    "Covariate columns not found"
  )
})


test_that("discretization errors with no covariates", {
  set.seed(20260324)
  n <- 100

  data <- data.frame(
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  expect_error(
    discretize_data(data, scheme = "quantiles"),
    "No covariate columns found"
  )
})


test_that("bin assignments are stable", {
  set.seed(123)
  n <- 100

  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Run same discretization twice
  set.seed(456)
  bins1 <- discretize_data(data, scheme = "kmeans", J_target = 9)$bins

  set.seed(456)
  bins2 <- discretize_data(data, scheme = "kmeans", J_target = 9)$bins

  # Should get same bins with same seed
  expect_equal(bins1, bins2)
})


test_that("RF discretization errors appropriately when package unavailable", {
  skip_if(requireNamespace("randomForest", quietly = TRUE),
          "randomForest is installed, cannot test unavailable behavior")

  n <- 100
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  expect_error(
    discretize_data(data, scheme = "rf", J_target = 9),
    "randomForest.*required"
  )
})
