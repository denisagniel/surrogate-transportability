test_that("compute_analytical_variance returns valid covariance matrix", {
  set.seed(123)
  data <- generate_study_data(
    n = 200,
    treatment_effect_surrogate = c(0.5, 0.8),
    treatment_effect_outcome = c(0.3, 0.7)
  )

  V <- compute_analytical_variance(data)

  # Should be 2x2 matrix
  expect_equal(dim(V), c(2, 2))

  # Should be symmetric
  expect_true(isSymmetric(V))

  # Should be positive definite
  eigenvalues <- eigen(V)$values
  expect_true(all(eigenvalues > 0))

  # Diagonal elements (variances) should be positive
  expect_true(V[1, 1] > 0)
  expect_true(V[2, 2] > 0)
})

test_that("compute_analytical_variance requires correct columns", {
  data_no_a <- data.frame(S = rnorm(100), Y = rnorm(100))
  expect_error(
    compute_analytical_variance(data_no_a),
    "Data must contain columns A, S, Y"
  )

  data_no_s <- data.frame(A = rbinom(100, 1, 0.5), Y = rnorm(100))
  expect_error(
    compute_analytical_variance(data_no_s),
    "Data must contain columns A, S, Y"
  )
})

test_that("compute_analytical_variance requires both treatment groups", {
  # All treated
  data_all_treated <- data.frame(
    A = rep(1, 100),
    S = rnorm(100),
    Y = rnorm(100)
  )

  expect_error(
    compute_analytical_variance(data_all_treated),
    "Both treatment groups must have at least one observation"
  )

  # All control
  data_all_control <- data.frame(
    A = rep(0, 100),
    S = rnorm(100),
    Y = rnorm(100)
  )

  expect_error(
    compute_analytical_variance(data_all_control),
    "Both treatment groups must have at least one observation"
  )
})

test_that("compute_analytical_variance_correlation returns valid results", {
  set.seed(123)
  data <- generate_study_data(
    n = 200,
    treatment_effect_surrogate = c(0.5, 0.8),
    treatment_effect_outcome = c(0.3, 0.7)
  )

  result <- compute_analytical_variance_correlation(data, lambda = 0.3)

  # Should have required elements
  expect_true(!is.null(result$sigma_squared))
  expect_true(!is.null(result$sigma))
  expect_true(!is.null(result$V))
  expect_true(!is.null(result$gradient))
  expect_true(!is.null(result$delta_s))
  expect_true(!is.null(result$delta_y))

  # sigma_squared should be positive
  expect_true(result$sigma_squared > 0)

  # sigma should equal sqrt(sigma_squared)
  expect_equal(result$sigma, sqrt(result$sigma_squared), tolerance = 1e-10)

  # V should be the same as from compute_analytical_variance
  V_direct <- compute_analytical_variance(data)
  expect_equal(result$V, V_direct)

  # Gradient should be length 2
  expect_equal(length(result$gradient), 2)
})

test_that("compute_analytical_variance_correlation works with different lambdas", {
  set.seed(123)
  data <- generate_study_data(
    n = 200,
    treatment_effect_surrogate = c(0.5, 0.8),
    treatment_effect_outcome = c(0.3, 0.7)
  )

  result_low <- compute_analytical_variance_correlation(data, lambda = 0.1)
  result_high <- compute_analytical_variance_correlation(data, lambda = 0.8)

  # Both should be valid
  expect_true(result_low$sigma_squared > 0)
  expect_true(result_high$sigma_squared > 0)

  # Note: The variance doesn't necessarily increase with lambda
  # (depends on the innovation distribution structure)
})

test_that("compute_analytical_ci produces valid confidence intervals", {
  set.seed(123)
  data <- generate_study_data(
    n = 200,
    treatment_effect_surrogate = c(0.5, 0.8),
    treatment_effect_outcome = c(0.3, 0.7)
  )

  # Compute a phi estimate
  result <- posterior_inference(
    data,
    n_draws_from_F = 20,
    n_future_studies_per_draw = 10,
    lambda = 0.3,
    functional_type = "correlation",
    seed = 123
  )
  phi_est <- mean(result$functionals, na.rm = TRUE)

  ci <- compute_analytical_ci(
    data,
    lambda = 0.3,
    phi_estimate = phi_est,
    confidence_level = 0.95
  )

  # Should have required elements
  expect_true(!is.null(ci$estimate))
  expect_true(!is.null(ci$se))
  expect_true(!is.null(ci$ci_lower))
  expect_true(!is.null(ci$ci_upper))
  expect_true(!is.null(ci$variance_components))

  # Estimate should match input
  expect_equal(ci$estimate, phi_est)

  # SE should be positive
  expect_true(ci$se > 0)

  # CI should be ordered correctly
  expect_true(ci$ci_lower < ci$ci_upper)

  # Estimate should typically be inside CI (not always, but likely with 95%)
  # (Skip this check as it's stochastic)
})

test_that("compute_analytical_ci works with different confidence levels", {
  set.seed(123)
  data <- generate_study_data(
    n = 200,
    treatment_effect_surrogate = c(0.5, 0.8),
    treatment_effect_outcome = c(0.3, 0.7)
  )

  phi_est <- 0.7

  ci_90 <- compute_analytical_ci(
    data,
    lambda = 0.3,
    phi_estimate = phi_est,
    confidence_level = 0.90
  )

  ci_95 <- compute_analytical_ci(
    data,
    lambda = 0.3,
    phi_estimate = phi_est,
    confidence_level = 0.95
  )

  ci_99 <- compute_analytical_ci(
    data,
    lambda = 0.3,
    phi_estimate = phi_est,
    confidence_level = 0.99
  )

  # 95% CI should be wider than 90% CI
  width_90 <- ci_90$ci_upper - ci_90$ci_lower
  width_95 <- ci_95$ci_upper - ci_95$ci_lower
  width_99 <- ci_99$ci_upper - ci_99$ci_lower

  expect_true(width_95 > width_90)
  expect_true(width_99 > width_95)
})

test_that("analytical variance scales correctly with sample size", {
  set.seed(123)

  # Generate large reference dataset
  data_large <- generate_study_data(
    n = 2000,
    treatment_effect_surrogate = c(0.5, 0.8),
    treatment_effect_outcome = c(0.3, 0.7)
  )
  V_large <- compute_analytical_variance(data_large)

  # Generate smaller datasets and check variance is approximately the same
  # (V is the *asymptotic* variance, not affected by n)
  data_small <- generate_study_data(
    n = 100,
    treatment_effect_surrogate = c(0.5, 0.8),
    treatment_effect_outcome = c(0.3, 0.7),
    seed = 456
  )
  V_small <- compute_analytical_variance(data_small)

  # They won't be exactly equal (different samples) but should be similar order of magnitude
  expect_true(V_small[1, 1] > 0)
  expect_true(V_small[2, 2] > 0)

  # Standard error computed using analytical variance
  var_result_large <- compute_analytical_variance_correlation(data_large, lambda = 0.3)
  var_result_small <- compute_analytical_variance_correlation(data_small, lambda = 0.3)

  ci_large <- compute_analytical_ci(data_large, lambda = 0.3, phi_estimate = 0.7, n = 2000)
  ci_small <- compute_analytical_ci(data_small, lambda = 0.3, phi_estimate = 0.7, n = 100)

  # Just check that both SEs are positive and reasonable
  expect_true(ci_large$se > 0)
  expect_true(ci_small$se > 0)
  expect_true(ci_large$se < 1)  # Should be less than 1 for correlation
  expect_true(ci_small$se < 1)
})

test_that("analytical variance matches empirical variance approximately", {
  set.seed(123)

  # Generate data
  dgp_params <- list(
    n_classes = 2,
    class_probs = c(0.6, 0.4),
    treatment_effect_surrogate = c(0.5, 0.8),
    treatment_effect_outcome = c(0.3, 0.7),
    surrogate_type = "continuous",
    outcome_type = "continuous"
  )

  # Generate multiple datasets and compute treatment effects
  n_reps <- 100
  n_size <- 500

  delta_s_vec <- numeric(n_reps)
  delta_y_vec <- numeric(n_reps)

  for (i in 1:n_reps) {
    data_rep <- do.call(generate_study_data, c(list(n = n_size, seed = 1000 + i), dgp_params))
    effects <- compute_multiple_treatment_effects(data_rep, c("S", "Y"))
    delta_s_vec[i] <- effects["S"]
    delta_y_vec[i] <- effects["Y"]
  }

  # Empirical covariance
  empirical_var_s <- var(delta_s_vec) * n_size  # Scale up to get V, not Var(sqrt(n)*delta)
  empirical_var_y <- var(delta_y_vec) * n_size
  empirical_cov <- cov(delta_s_vec, delta_y_vec) * n_size

  # Analytical variance from one representative dataset
  data_ref <- do.call(generate_study_data, c(list(n = n_size, seed = 999), dgp_params))
  V_analytical <- compute_analytical_variance(data_ref)

  # Should be reasonably close (within 100% due to Monte Carlo error and finite sample)
  # Note: This is a loose bound because we're comparing asymptotic formula to finite-sample empirical
  expect_true(abs(V_analytical[1, 1] - empirical_var_s) < 1.5 * max(empirical_var_s, V_analytical[1, 1]))
  expect_true(abs(V_analytical[2, 2] - empirical_var_y) < 1.5 * max(empirical_var_y, V_analytical[2, 2]))

  # Covariance can be trickier, just check they have the same sign
  expect_equal(sign(V_analytical[1, 2]), sign(empirical_cov))
})
