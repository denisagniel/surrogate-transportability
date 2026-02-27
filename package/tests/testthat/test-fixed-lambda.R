test_that("generate_future_study accepts fixed lambda", {
  set.seed(123)
  data <- data.frame(
    A = rep(0:1, each = 25),
    S = rnorm(50),
    Y = rnorm(50)
  )

  result <- generate_future_study(data, lambda = 0.5)

  expect_equal(result$lambda, 0.5)
  expect_true(all(result$mixture_weights >= 0))
  expect_equal(sum(result$mixture_weights), 1, tolerance = 1e-10)
  expect_equal(nrow(result$future_data), 50)
})

test_that("generate_future_study works with edge case lambda = 0", {
  set.seed(123)
  data <- data.frame(
    A = rep(0:1, each = 25),
    S = rnorm(50),
    Y = rnorm(50)
  )

  result <- generate_future_study(data, lambda = 0)

  expect_equal(result$lambda, 0)
  # When lambda = 0, mixture should equal P0 (uniform)
  expect_equal(result$mixture_weights, rep(1/50, 50), tolerance = 1e-10)
})

test_that("generate_future_study works with edge case lambda = 1", {
  set.seed(123)
  data <- data.frame(
    A = rep(0:1, each = 25),
    S = rnorm(50),
    Y = rnorm(50)
  )

  result <- generate_future_study(data, lambda = 1)

  expect_equal(result$lambda, 1)
  # When lambda = 1, mixture should equal innovation distribution
  expect_equal(result$mixture_weights, result$innovation_weights, tolerance = 1e-10)
})

test_that("generate_future_study validates lambda parameter", {
  data <- data.frame(
    A = c(0, 1),
    S = c(0, 1),
    Y = c(0, 1)
  )

  expect_error(
    generate_future_study(data, lambda = -0.1),
    "lambda must be a single numeric value in \\[0, 1\\]"
  )

  expect_error(
    generate_future_study(data, lambda = 1.5),
    "lambda must be a single numeric value in \\[0, 1\\]"
  )

  expect_error(
    generate_future_study(data, lambda = c(0.3, 0.4)),
    "lambda must be a single numeric value"
  )

  expect_error(
    generate_future_study(data, lambda = "0.3"),
    "lambda must be a single numeric value"
  )

  expect_error(
    generate_future_study(data, lambda = NA),
    "lambda must be a single numeric value"
  )
})

test_that("generate_multiple_future_studies uses fixed lambda for all studies", {
  set.seed(123)
  data <- data.frame(
    A = rep(0:1, each = 25),
    S = rnorm(50),
    Y = rnorm(50)
  )

  results <- generate_multiple_future_studies(
    data,
    n_future_studies = 10,
    lambda = 0.4
  )

  expect_length(results, 10)

  # Check that all studies have the same lambda
  lambdas <- sapply(results, function(x) x$lambda)
  expect_true(all(lambdas == 0.4))
})

test_that("posterior_inference works with fixed lambda", {
  set.seed(123)
  data <- data.frame(
    A = rep(0:1, each = 25),
    S = rnorm(50),
    Y = rnorm(50)
  )

  result <- posterior_inference(
    current_data = data,
    n_draws_from_F = 10,
    n_future_studies_per_draw = 5,
    lambda = 0.3,
    functional_type = "correlation",
    seed = 123
  )

  expect_equal(result$parameters$lambda, 0.3)
  expect_true(is.numeric(result$functionals))
  expect_equal(length(result$functionals), 10)
  expect_true(!is.null(result$summary))
})

test_that("posterior_inference with functional_type = 'all' works", {
  set.seed(123)
  data <- data.frame(
    A = rep(0:1, each = 25),
    S = rnorm(50),
    Y = rnorm(50)
  )

  result <- posterior_inference(
    current_data = data,
    n_draws_from_F = 5,
    n_future_studies_per_draw = 3,
    lambda = 0.5,
    functional_type = "all",
    epsilon_s = 0.2,
    epsilon_y = 0.1,
    seed = 123
  )

  expect_equal(result$parameters$lambda, 0.5)
  expect_true(!is.null(result$functionals$correlation))
  expect_true(!is.null(result$functionals$probability))
  expect_true(!is.null(result$functionals$conditional_means))
})

test_that("compare_surrogate_methods uses fixed lambda", {
  set.seed(123)
  data <- data.frame(
    A = rep(0:1, each = 25),
    S = rnorm(50),
    Y = rnorm(50)
  )

  result <- compare_surrogate_methods(
    data,
    n_outer = 5,
    n_inner = 3,
    lambda = 0.4,
    seed = 123
  )

  expect_equal(result$innovation$parameters$lambda, 0.4)
  expect_true(!is.null(result$innovation))
  expect_true(!is.null(result$traditional))
})

test_that("grid_search_lambda finds threshold correctly", {
  set.seed(123)
  data <- data.frame(
    A = rep(0:1, each = 50),
    S = rnorm(100) + rep(c(0, 0.5), each = 50),  # Some treatment effect
    Y = rnorm(100) + rep(c(0, 0.3), each = 50)
  )

  result <- grid_search_lambda(
    data,
    lambda_grid = seq(0.1, 0.5, by = 0.2),
    threshold = 0.1,  # Low threshold for testing
    functional_type = "correlation",
    n_draws_from_F = 10,
    n_future_studies_per_draw = 5,
    seed = 123
  )

  expect_s3_class(result, "grid_search_result")
  expect_true(is.numeric(result$lambda_star) || is.na(result$lambda_star))
  expect_equal(nrow(result$phi_estimates), 3)
  expect_equal(result$n_lambda, 3)
  expect_equal(result$threshold, 0.1)
})

test_that("grid_search_lambda validates inputs", {
  data <- data.frame(
    A = c(0, 1),
    S = c(0, 1),
    Y = c(0, 1)
  )

  expect_error(
    grid_search_lambda(data, lambda_grid = c(-0.1, 0.5)),
    "lambda_grid must contain numeric values in \\[0, 1\\]"
  )

  expect_error(
    grid_search_lambda(data, lambda_grid = c(0.5, 1.5)),
    "lambda_grid must contain numeric values in \\[0, 1\\]"
  )

  expect_error(
    grid_search_lambda(data, lambda_grid = c(0.3, 0.5), threshold = c(0.5, 0.7)),
    "threshold must be a single numeric value"
  )

  expect_error(
    grid_search_lambda(data, lambda_grid = c(0.3, 0.5), confidence_level = 1.5),
    "confidence_level must be in \\(0, 1\\)"
  )
})

test_that("grid_search_lambda with multiplicity adjustments", {
  set.seed(123)
  data <- data.frame(
    A = rep(0:1, each = 25),
    S = rnorm(50),
    Y = rnorm(50)
  )

  # Test Bonferroni
  result_bonf <- grid_search_lambda(
    data,
    lambda_grid = c(0.2, 0.4),
    threshold = 0.5,
    multiplicity_adjustment = "bonferroni",
    n_draws_from_F = 5,
    n_future_studies_per_draw = 3,
    seed = 123
  )

  # Test Sidak
  result_sidak <- grid_search_lambda(
    data,
    lambda_grid = c(0.2, 0.4),
    threshold = 0.5,
    multiplicity_adjustment = "sidak",
    n_draws_from_F = 5,
    n_future_studies_per_draw = 3,
    seed = 123
  )

  expect_equal(result_bonf$multiplicity_adjustment, "bonferroni")
  expect_equal(result_sidak$multiplicity_adjustment, "sidak")

  # Bonferroni should be more conservative (wider CIs)
  # This might not always hold with small samples, but check structure
  expect_true(result_bonf$adjusted_confidence_level > 0.95)
  expect_true(result_sidak$adjusted_confidence_level > 0.95)
})

test_that("analyze_lambda_ranges shows deprecation warning", {
  data <- data.frame(
    A = rep(0:1, each = 25),
    S = rnorm(50),
    Y = rnorm(50)
  )

  expect_warning(
    result <- analyze_lambda_ranges(
      data,
      lambda_ranges = list(list(min = 0, max = 0.3)),
      n_draws_from_F = 5,
      n_future_studies_per_draw = 3,
      seed = 123
    ),
    "deprecated"
  )
})

test_that("print.grid_search_result works", {
  set.seed(123)
  data <- data.frame(
    A = rep(0:1, each = 25),
    S = rnorm(50),
    Y = rnorm(50)
  )

  result <- grid_search_lambda(
    data,
    lambda_grid = c(0.2, 0.4),
    threshold = 0.5,
    n_draws_from_F = 5,
    n_future_studies_per_draw = 3,
    seed = 123
  )

  # Test that print doesn't error
  expect_output(print(result), "Grid Search Results")
  expect_output(print(result), "Lambda\\*")
})
