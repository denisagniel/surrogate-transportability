test_that("surrogate_inference_if returns valid structure", {
  set.seed(123)
  data <- generate_study_data(n = 200,
                               treatment_effect_surrogate = c(0.3, 0.9),
                               treatment_effect_outcome = c(0.2, 0.8))

  result <- surrogate_inference_if(data, lambda = 0.3, n_innovations = 100)

  # Check structure
  expect_type(result, "list")
  expect_named(result, c("estimate", "se", "ci_lower", "ci_upper", "gradient",
                         "variance_matrix", "sigma_squared", "treatment_effects",
                         "parameters"))

  # Check values are finite and reasonable
  expect_true(is.finite(result$estimate))
  expect_true(result$se > 0)
  expect_true(result$ci_lower < result$ci_upper)

  # Correlation should be in [-1, 1]
  expect_true(result$estimate >= -1 && result$estimate <= 1)

  # Gradient should be non-zero
  expect_true(any(abs(result$gradient) > 1e-10))

  # Variance matrix should be 2x2 and symmetric
  expect_equal(dim(result$variance_matrix), c(2, 2))
  expect_equal(result$variance_matrix[1,2], result$variance_matrix[2,1])
})

test_that("gradient computation produces reasonable values", {
  set.seed(456)
  data <- generate_study_data(n = 300,
                               treatment_effect_surrogate = c(0.3, 0.9),
                               treatment_effect_outcome = c(0.2, 0.8))

  result <- surrogate_inference_if(data, lambda = 0.3, n_innovations = 200,
                                   epsilon_gradient = 0.01)

  # Gradient magnitude should be O(1), not O(1000) or O(0.001)
  grad_mag <- sqrt(sum(result$gradient^2))
  expect_true(grad_mag > 0.1 && grad_mag < 100)
})

test_that("influence function variance is positive definite", {
  set.seed(789)
  data <- generate_study_data(n = 250,
                               treatment_effect_surrogate = c(0.3, 0.9),
                               treatment_effect_outcome = c(0.2, 0.8))

  result <- surrogate_inference_if(data, lambda = 0.2, n_innovations = 100)

  # Check positive definiteness
  eigenvalues <- eigen(result$variance_matrix, only.values = TRUE)$values
  expect_true(all(eigenvalues > 0))

  # Sigma squared should be positive
  expect_true(result$sigma_squared > 0)
})

test_that("confidence intervals have reasonable width", {
  skip_on_cran()  # Takes ~30 seconds

  set.seed(999)
  n_sim <- 50  # Reduced for faster testing
  lambda <- 0.3
  ci_widths <- numeric(n_sim)

  for (i in 1:n_sim) {
    data <- generate_study_data(n = 400,
                                 treatment_effect_surrogate = c(0.3, 0.9),
                                 treatment_effect_outcome = c(0.2, 0.8))

    result <- surrogate_inference_if(data, lambda = lambda, n_innovations = 200)
    ci_widths[i] <- result$ci_upper - result$ci_lower
  }

  # Median CI width should be reasonable
  expect_true(median(ci_widths) < 0.6)

  # Mean CI width should be moderate
  expect_true(mean(ci_widths) < 0.8)

  # No extremely wide CIs (e.g., > 2 for correlation in [-1,1])
  expect_true(all(ci_widths < 2.0))
})

test_that("results are stable across runs", {
  set.seed(111)
  data <- generate_study_data(n = 300,
                               treatment_effect_surrogate = c(0.3, 0.9),
                               treatment_effect_outcome = c(0.2, 0.8))

  # Run 5 times with same data but different innovations
  estimates <- numeric(5)
  for (i in 1:5) {
    result <- surrogate_inference_if(data, lambda = 0.3, n_innovations = 300)
    estimates[i] <- result$estimate
  }

  # Coefficient of variation should be < 10%
  cv <- sd(estimates) / mean(estimates)
  expect_true(cv < 0.10)
})
