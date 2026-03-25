# Tests for User-Facing Wasserstein Minimax API
# Phase 3: User Interface

test_that("surrogate_inference_minimax_wasserstein runs with defaults", {
  set.seed(123)

  # Generate data
  n <- 100
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Run with defaults (no bootstrap)
  result <- surrogate_inference_minimax_wasserstein(
    data,
    lambda_w = 0.5,
    discretization_schemes = "kmeans",  # Fast
    n_innovations = 50,
    verbose = FALSE
  )

  # Check output structure
  expect_true(is.list(result))
  expect_true(all(c("phi_star", "phi_star_lower", "best_scheme",
                     "schemes_summary", "lambda_w", "functional_type",
                     "n", "call") %in% names(result)))

  # Check values
  expect_true(is.numeric(result$phi_star))
  expect_true(abs(result$phi_star) <= 1)  # Correlation
  expect_equal(result$best_scheme, "kmeans")
  expect_equal(result$lambda_w, 0.5)
  expect_equal(result$functional_type, "correlation")
  expect_equal(result$n, n)
})


test_that("surrogate_inference_minimax_wasserstein works with all functionals", {
  set.seed(456)

  n <- 100
  data <- data.frame(
    X1 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n) + 0.3,
    Y = rnorm(n) + 0.2
  )

  # Correlation
  result_cor <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.3, functional_type = "correlation",
    discretization_schemes = "kmeans", n_innovations = 30,
    verbose = FALSE
  )
  expect_true(abs(result_cor$phi_star) <= 1)

  # Probability
  result_prob <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.3, functional_type = "probability",
    epsilon_s = 0.1, epsilon_y = 0.1,
    discretization_schemes = "kmeans", n_innovations = 30,
    verbose = FALSE
  )
  expect_true(result_prob$phi_star >= 0 && result_prob$phi_star <= 1)

  # PPV
  result_ppv <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.3, functional_type = "ppv",
    epsilon_s = 0.1, epsilon_y = 0.1,
    discretization_schemes = "kmeans", n_innovations = 30,
    verbose = FALSE
  )
  expect_true(result_ppv$phi_star >= 0 && result_ppv$phi_star <= 1)

  # NPV
  result_npv <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.3, functional_type = "npv",
    epsilon_s = 0.1, epsilon_y = 0.1,
    discretization_schemes = "kmeans", n_innovations = 30,
    verbose = FALSE
  )
  expect_true(result_npv$phi_star >= 0 && result_npv$phi_star <= 1)

  # Conditional mean
  result_cm <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.3, functional_type = "conditional_mean",
    delta_s_value = 0.5,
    discretization_schemes = "kmeans", n_innovations = 30,
    verbose = FALSE
  )
  expect_true(is.numeric(result_cm$phi_star))
})


test_that("surrogate_inference_minimax_wasserstein validates inputs", {
  n <- 50
  data <- data.frame(
    X1 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Missing required columns
  data_incomplete <- data[, c("X1", "A", "S")]
  expect_error(
    surrogate_inference_minimax_wasserstein(data_incomplete, lambda_w = 0.5),
    "Required columns missing"
  )

  # Invalid lambda_w
  expect_error(
    surrogate_inference_minimax_wasserstein(data, lambda_w = -0.1),
    "non-negative"
  )

  expect_error(
    surrogate_inference_minimax_wasserstein(data, lambda_w = c(0.3, 0.5)),
    "single"
  )

  # Missing epsilon for probability functional
  expect_error(
    surrogate_inference_minimax_wasserstein(
      data, lambda_w = 0.5, functional_type = "probability"
    ),
    "epsilon_s and epsilon_y must be specified"
  )

  # Missing delta_s_value for conditional_mean
  expect_error(
    surrogate_inference_minimax_wasserstein(
      data, lambda_w = 0.5, functional_type = "conditional_mean"
    ),
    "delta_s_value must be specified"
  )
})


test_that("surrogate_inference_minimax_wasserstein auto-detects covariates", {
  set.seed(789)

  n <- 80
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    X3 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Should auto-detect X1, X2, X3
  result <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.4,
    discretization_schemes = "kmeans", n_innovations = 30,
    verbose = FALSE
  )

  expect_true(is.numeric(result$phi_star))
})


test_that("surrogate_inference_minimax_wasserstein works with specified covariates", {
  set.seed(111)

  n <- 80
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    extra = rnorm(n),  # Should be ignored
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Specify only X1, X2
  result <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.4,
    covariate_cols = c("X1", "X2"),
    discretization_schemes = "kmeans", n_innovations = 30,
    verbose = FALSE
  )

  expect_true(is.numeric(result$phi_star))
})


test_that("surrogate_inference_minimax_wasserstein works with multiple schemes", {
  set.seed(222)

  n <- 100
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  result <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.5,
    discretization_schemes = c("quantiles", "kmeans"),
    n_innovations = 40,
    verbose = FALSE
  )

  expect_equal(nrow(result$schemes_summary), 2)
  expect_true(result$best_scheme %in% c("quantiles", "kmeans"))
})


test_that("surrogate_inference_minimax_wasserstein supports different cost functions", {
  set.seed(333)

  n <- 80
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n) * 2,  # Different scale
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Euclidean
  result_euc <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.4,
    cost_function = "euclidean",
    discretization_schemes = "kmeans", n_innovations = 30,
    verbose = FALSE
  )
  expect_equal(result_euc$cost_function, "euclidean")

  # Mahalanobis
  result_maha <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.4,
    cost_function = "mahalanobis",
    discretization_schemes = "kmeans", n_innovations = 30,
    verbose = FALSE
  )
  expect_equal(result_maha$cost_function, "mahalanobis")
})


test_that("surrogate_inference_minimax_wasserstein supports different sampling methods", {
  set.seed(444)

  n <- 80
  data <- data.frame(
    X1 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  for (method in c("normal", "dirichlet", "uniform")) {
    result <- surrogate_inference_minimax_wasserstein(
      data, lambda_w = 0.4,
      sampling_method = method,
      discretization_schemes = "kmeans", n_innovations = 30,
      verbose = FALSE
    )

    expect_equal(result$sampling_method, method)
    expect_true(is.numeric(result$phi_star))
  }
})


test_that("surrogate_inference_minimax_wasserstein bootstrap CI works", {
  set.seed(555)

  n <- 60
  data <- data.frame(
    X1 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  result <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.4,
    discretization_schemes = "kmeans",
    n_innovations = 30,
    n_bootstrap = 5,  # Small for speed
    confidence_level = 0.90,
    parallel = FALSE,
    verbose = FALSE
  )

  # Check CI components exist
  expect_true("ci_lower" %in% names(result))
  expect_true("ci_upper" %in% names(result))
  expect_true("bootstrap_estimates" %in% names(result))
  expect_true("confidence_level" %in% names(result))

  # Check values
  expect_true(is.numeric(result$ci_lower))
  expect_true(is.numeric(result$ci_upper))
  expect_equal(length(result$bootstrap_estimates), 5)
  expect_equal(result$confidence_level, 0.90)

  # CI should contain estimate (usually)
  # This can fail due to sampling, so just check it's reasonable
  expect_true(result$ci_lower <= result$ci_upper)
})


test_that("surrogate_inference_minimax_wasserstein seed works", {
  n <- 80
  data <- data.frame(
    X1 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Same seed should give same result
  result1 <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.4,
    discretization_schemes = "kmeans", n_innovations = 30,
    seed = 777, verbose = FALSE
  )

  result2 <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.4,
    discretization_schemes = "kmeans", n_innovations = 30,
    seed = 777, verbose = FALSE
  )

  expect_equal(result1$phi_star, result2$phi_star)
})


test_that("surrogate_inference_minimax_wasserstein call attribute works", {
  n <- 50
  data <- data.frame(
    X1 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  result <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.5,
    discretization_schemes = "kmeans", n_innovations = 20,
    verbose = FALSE
  )

  expect_true("call" %in% names(result))
  expect_true(is.language(result$call) || is.call(result$call))
})


test_that("API consistency: Wasserstein vs TV output structure", {
  set.seed(888)

  n <- 100
  data <- data.frame(
    X1 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # TV-ball
  result_tv <- surrogate_inference_minimax(
    data, lambda = 0.3,
    discretization_schemes = "kmeans",
    n_innovations = 30,
    verbose = FALSE
  )

  # Wasserstein ball
  result_w <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.3,
    discretization_schemes = "kmeans",
    n_innovations = 30,
    verbose = FALSE
  )

  # Should have same core components
  core_names <- c("phi_star", "phi_star_lower", "best_scheme",
                  "schemes_summary", "functional_type", "n", "call")
  expect_true(all(core_names %in% names(result_tv)))
  expect_true(all(core_names %in% names(result_w)))

  # Wasserstein-specific
  expect_true("lambda_w" %in% names(result_w))
  expect_true("cost_function" %in% names(result_w))
  expect_true("sampling_method" %in% names(result_w))

  # TV-specific
  expect_true("lambda" %in% names(result_tv))
})
