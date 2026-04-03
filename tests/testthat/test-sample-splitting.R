test_that("split_data creates valid splits", {
  # Test basic split
  data <- data.frame(
    A = rep(c(0, 1), each = 50),
    S = rnorm(100),
    Y = rnorm(100),
    X1 = rnorm(100),
    X2 = rnorm(100)
  )

  set.seed(123)
  split_result <- split_data(data, split_ratio = 0.5)

  # Check structure
  expect_type(split_result, "list")
  expect_named(split_result, c("d1", "d2"))

  # Check sizes
  expect_equal(nrow(split_result$d1) + nrow(split_result$d2), nrow(data))
  expect_true(abs(nrow(split_result$d1) / nrow(data) - 0.5) < 0.1)

  # Check no overlap
  d1_idx <- as.numeric(rownames(split_result$d1))
  d2_idx <- as.numeric(rownames(split_result$d2))
  expect_length(intersect(d1_idx, d2_idx), 0)

  # Check all rows accounted for
  expect_setequal(c(d1_idx, d2_idx), 1:nrow(data))

  # Check stratification by treatment (approximately balanced)
  prop_treated_d1 <- mean(split_result$d1$A)
  prop_treated_d2 <- mean(split_result$d2$A)
  expect_true(abs(prop_treated_d1 - 0.5) < 0.15)
  expect_true(abs(prop_treated_d2 - 0.5) < 0.15)
})


test_that("split_data respects split_ratio", {
  data <- data.frame(
    A = rbinom(200, 1, 0.5),
    S = rnorm(200),
    Y = rnorm(200),
    X1 = rnorm(200)
  )

  # Test different split ratios
  for (ratio in c(0.3, 0.5, 0.7)) {
    set.seed(456)
    split_result <- split_data(data, split_ratio = ratio)

    actual_ratio <- nrow(split_result$d1) / nrow(data)
    expect_true(abs(actual_ratio - ratio) < 0.05)
  }
})


test_that("identify_worst_case_d1 returns valid results", {
  skip_if_not_installed("randomForest")

  # Generate simple data
  n <- 100
  set.seed(789)
  data <- data.frame(
    A = rbinom(n, 1, 0.5),
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$S <- 0.3 * data$A + 0.2 * data$X1 + rnorm(n, sd = 0.3)
  data$Y <- 0.4 * data$A + 0.3 * data$X1 + rnorm(n, sd = 0.4)

  result <- identify_worst_case_d1(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = 0.5,
    tau_method = "linear",
    cross_fit = FALSE,
    cost_function = "euclidean",
    scale_covariates = TRUE
  )

  # Check structure
  expect_type(result, "list")
  expect_named(result, c("optimal_gamma", "phi_star_d1", "concordance_d1",
                         "tau_s_d1", "tau_y_d1", "cost_matrix_d1"))

  # Check values
  expect_true(is.numeric(result$optimal_gamma))
  expect_true(result$optimal_gamma >= 0)
  expect_true(is.numeric(result$phi_star_d1))
  expect_length(result$concordance_d1, n)
  expect_length(result$tau_s_d1, n)
  expect_length(result$tau_y_d1, n)

  # Check cost matrix
  expect_equal(dim(result$cost_matrix_d1), c(n, n))
  expect_true(all(result$cost_matrix_d1 >= 0))
  expect_true(all(diag(result$cost_matrix_d1) == 0))  # Self-distance is 0
})


test_that("infer_on_d2 produces consistent results", {
  n <- 100
  set.seed(101)
  data <- data.frame(
    A = rbinom(n, 1, 0.5),
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$S <- 0.3 * data$A + 0.2 * data$X1 + rnorm(n, sd = 0.3)
  data$Y <- 0.4 * data$A + 0.3 * data$X1 + rnorm(n, sd = 0.4)

  # Use a fixed gamma from "D1"
  gamma_from_d1 <- 2.5

  result <- infer_on_d2(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = 0.5,
    gamma_from_d1 = gamma_from_d1,
    tau_method = "linear",
    cross_fit = FALSE,
    cost_function = "euclidean",
    scale_covariates = TRUE
  )

  # Check structure
  expect_type(result, "list")
  expect_named(result, c("phi_star", "optimal_gamma_d2", "phi_star_at_d2_gamma",
                         "concordance_d2", "tau_s_d2", "tau_y_d2",
                         "cost_matrix_d2"))

  # Check values
  expect_true(is.numeric(result$phi_star))
  expect_true(is.numeric(result$optimal_gamma_d2))
  expect_true(result$optimal_gamma_d2 >= 0)
  expect_length(result$concordance_d2, n)
  expect_length(result$tau_s_d2, n)
  expect_length(result$tau_y_d2, n)

  # Concordance should match tau_s * tau_y
  expect_equal(result$concordance_d2, result$tau_s_d2 * result$tau_y_d2)
})


test_that("sample_splitting_minimax_wasserstein produces valid output", {
  n <- 150
  set.seed(202)
  data <- data.frame(
    A = rbinom(n, 1, 0.5),
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$S <- 0.3 * data$A + 0.2 * data$X1 + rnorm(n, sd = 0.3)
  data$Y <- 0.4 * data$A + 0.3 * data$X1 + rnorm(n, sd = 0.4)

  result <- sample_splitting_minimax_wasserstein(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = 0.5,
    split_ratio = 0.5,
    tau_method = "linear",
    cross_fit = FALSE,
    seed = 202
  )

  # Check structure
  expect_type(result, "list")
  expect_true("phi_star" %in% names(result))
  expect_true("optimal_gamma_d1" %in% names(result))
  expect_true("method" %in% names(result))

  # Check values
  expect_true(is.numeric(result$phi_star))
  expect_true(is.finite(result$phi_star))
  expect_true(result$optimal_gamma_d1 >= 0)
  expect_equal(result$method, "sample_splitting")
  expect_equal(result$n_d1 + result$n_d2, n)

  # Check split ratio approximately correct
  actual_ratio <- result$n_d1 / n
  expect_true(abs(actual_ratio - 0.5) < 0.1)
})


test_that("sample_splitting is reproducible with seed", {
  n <- 100
  data <- data.frame(
    A = rbinom(n, 1, 0.5),
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$S <- 0.3 * data$A + rnorm(n, sd = 0.3)
  data$Y <- 0.4 * data$A + rnorm(n, sd = 0.4)

  # Run twice with same seed
  result1 <- sample_splitting_minimax_wasserstein(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = 0.5,
    tau_method = "linear",
    cross_fit = FALSE,
    seed = 999
  )

  result2 <- sample_splitting_minimax_wasserstein(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = 0.5,
    tau_method = "linear",
    cross_fit = FALSE,
    seed = 999
  )

  # Should get identical results
  expect_equal(result1$phi_star, result2$phi_star)
  expect_equal(result1$optimal_gamma_d1, result2$optimal_gamma_d1)
  expect_equal(result1$n_d1, result2$n_d1)
  expect_equal(result1$n_d2, result2$n_d2)
})


test_that("sample_splitting validates inputs correctly", {
  data <- data.frame(
    A = rbinom(100, 1, 0.5),
    S = rnorm(100),
    Y = rnorm(100),
    X1 = rnorm(100)
  )

  # Invalid split_ratio
  expect_error(
    sample_splitting_minimax_wasserstein(
      data = data,
      covariates = "X1",
      lambda_w = 0.5,
      split_ratio = 1.5  # Invalid
    ),
    "split_ratio must be in"
  )

  expect_error(
    sample_splitting_minimax_wasserstein(
      data = data,
      covariates = "X1",
      lambda_w = 0.5,
      split_ratio = 0  # Invalid
    ),
    "split_ratio must be in"
  )

  # Negative lambda_w
  expect_error(
    sample_splitting_minimax_wasserstein(
      data = data,
      covariates = "X1",
      lambda_w = -0.5  # Invalid
    ),
    "lambda_w must be non-negative"
  )

  # Missing columns
  expect_error(
    sample_splitting_minimax_wasserstein(
      data = data,
      covariates = c("X1", "X_missing"),
      lambda_w = 0.5
    ),
    "Required columns missing"
  )
})


test_that("bootstrap_ci_sample_splitting produces valid CI", {
  n <- 100
  set.seed(303)
  data <- data.frame(
    A = rbinom(n, 1, 0.5),
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$S <- 0.3 * data$A + 0.2 * data$X1 + rnorm(n, sd = 0.3)
  data$Y <- 0.4 * data$A + 0.3 * data$X1 + rnorm(n, sd = 0.4)

  result <- bootstrap_ci_sample_splitting(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = 0.5,
    split_ratio = 0.5,
    tau_method = "linear",
    n_bootstrap = 50,  # Small for speed
    confidence_level = 0.95,
    seed = 303,
    verbose = FALSE
  )

  # Check structure
  expect_type(result, "list")
  expect_true("phi_star" %in% names(result))
  expect_true("ci_lower" %in% names(result))
  expect_true("ci_upper" %in% names(result))
  expect_true("bootstrap_estimates" %in% names(result))

  # Check values
  expect_true(is.numeric(result$phi_star))
  expect_true(is.numeric(result$ci_lower))
  expect_true(is.numeric(result$ci_upper))
  expect_true(result$ci_lower <= result$ci_upper)

  # Point estimate should be near the middle of CI (not always, but often)
  # Just check it's within the interval
  expect_true(result$phi_star >= result$ci_lower - 0.1)
  expect_true(result$phi_star <= result$ci_upper + 0.1)

  # Bootstrap estimates
  expect_true(is.numeric(result$bootstrap_estimates))
  expect_true(length(result$bootstrap_estimates) >= 40)  # At least 80% success

  # CI width should be positive
  expect_true(result$ci_width > 0)
  expect_equal(result$ci_width, result$ci_upper - result$ci_lower)
})


test_that("bootstrap CI respects confidence level", {
  n <- 100
  set.seed(404)
  data <- data.frame(
    A = rbinom(n, 1, 0.5),
    X1 = rnorm(n)
  )
  data$S <- 0.3 * data$A + rnorm(n, sd = 0.3)
  data$Y <- 0.4 * data$A + rnorm(n, sd = 0.4)

  # 90% CI should be narrower than 95% CI
  result_90 <- bootstrap_ci_sample_splitting(
    data = data,
    covariates = "X1",
    lambda_w = 0.5,
    n_bootstrap = 50,
    confidence_level = 0.90,
    seed = 404,
    verbose = FALSE
  )

  result_95 <- bootstrap_ci_sample_splitting(
    data = data,
    covariates = "X1",
    lambda_w = 0.5,
    n_bootstrap = 50,
    confidence_level = 0.95,
    seed = 404,
    verbose = FALSE
  )

  expect_true(result_90$ci_width < result_95$ci_width)
})


test_that("sample_splitting works with different tau_methods", {
  skip_if_not_installed("mgcv")

  n <- 100
  set.seed(505)
  data <- data.frame(
    A = rbinom(n, 1, 0.5),
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$S <- 0.3 * data$A + 0.2 * data$X1 + rnorm(n, sd = 0.3)
  data$Y <- 0.4 * data$A + 0.3 * data$X1 + rnorm(n, sd = 0.4)

  methods <- c("linear", "kernel")
  if (requireNamespace("mgcv", quietly = TRUE)) {
    methods <- c(methods, "gam")
  }

  for (method in methods) {
    result <- sample_splitting_minimax_wasserstein(
      data = data,
      covariates = c("X1", "X2"),
      lambda_w = 0.5,
      tau_method = method,
      cross_fit = FALSE,
      seed = 505
    )

    expect_true(is.numeric(result$phi_star))
    expect_true(is.finite(result$phi_star))
    expect_equal(result$tau_method, method)
  }
})


test_that("sample_splitting handles edge cases", {
  # Very small lambda_w (no perturbation)
  n <- 80
  set.seed(606)
  data <- data.frame(
    A = rbinom(n, 1, 0.5),
    X1 = rnorm(n)
  )
  data$S <- 0.3 * data$A + rnorm(n, sd = 0.3)
  data$Y <- 0.4 * data$A + rnorm(n, sd = 0.4)

  result <- sample_splitting_minimax_wasserstein(
    data = data,
    covariates = "X1",
    lambda_w = 0.001,  # Very small
    tau_method = "linear",
    cross_fit = FALSE,
    seed = 606
  )

  expect_true(is.numeric(result$phi_star))
  expect_true(is.finite(result$phi_star))
  # With very small lambda_w, gamma should be small or zero
  expect_true(result$optimal_gamma_d1 < 1.0)
})


test_that("sample_splitting with cross-fitting works", {
  n <- 120
  set.seed(707)
  data <- data.frame(
    A = rbinom(n, 1, 0.5),
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$S <- 0.3 * data$A + 0.2 * data$X1 + rnorm(n, sd = 0.3)
  data$Y <- 0.4 * data$A + 0.3 * data$X1 + rnorm(n, sd = 0.4)

  result <- sample_splitting_minimax_wasserstein(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = 0.5,
    tau_method = "kernel",
    cross_fit = TRUE,  # Enable cross-fitting
    seed = 707
  )

  expect_true(is.numeric(result$phi_star))
  expect_true(is.finite(result$phi_star))
  expect_true(result$cross_fitted)
})


test_that("cost functions produce valid results", {
  n <- 100
  set.seed(808)
  data <- data.frame(
    A = rbinom(n, 1, 0.5),
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$S <- 0.3 * data$A + rnorm(n, sd = 0.3)
  data$Y <- 0.4 * data$A + rnorm(n, sd = 0.4)

  result_euclidean <- sample_splitting_minimax_wasserstein(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = 0.5,
    cost_function = "euclidean",
    tau_method = "linear",
    cross_fit = FALSE,
    seed = 808
  )

  result_manhattan <- sample_splitting_minimax_wasserstein(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = 0.5,
    cost_function = "manhattan",
    tau_method = "linear",
    cross_fit = FALSE,
    seed = 808
  )

  # Both should produce valid finite results
  expect_true(is.finite(result_euclidean$phi_star))
  expect_true(is.finite(result_manhattan$phi_star))

  # Results may differ depending on data structure
  # Just verify both methods work correctly
  expect_true(is.numeric(result_euclidean$optimal_gamma_d1))
  expect_true(is.numeric(result_manhattan$optimal_gamma_d1))
})


test_that("gamma values from D1 and D2 are similar with large n", {
  # With larger n, optimal gamma on D1 and D2 should be similar
  n <- 300
  set.seed(909)
  data <- data.frame(
    A = rbinom(n, 1, 0.5),
    X1 = rnorm(n),
    X2 = rnorm(n)
  )
  data$S <- 0.3 * data$A + 0.2 * data$X1 + rnorm(n, sd = 0.3)
  data$Y <- 0.4 * data$A + 0.3 * data$X1 + rnorm(n, sd = 0.4)

  result <- sample_splitting_minimax_wasserstein(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = 0.5,
    tau_method = "linear",
    cross_fit = FALSE,
    seed = 909
  )

  # Gamma from D1 and D2 should be within 20% of each other (typically)
  gamma_ratio <- result$optimal_gamma_d1 / result$optimal_gamma_d2
  expect_true(gamma_ratio > 0.7 && gamma_ratio < 1.3)
})
