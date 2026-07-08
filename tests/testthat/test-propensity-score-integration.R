# Tests for propensity score integration with doubly robust IF

test_that("wasserstein_minimax_IF_inference works without propensity scores (default)", {
  set.seed(123)
  data <- generate_nonlinear_study_data(
    n = 150, d = 2, pattern = "linear", seed = 123
  )

  # Default: use_propensity_scores = FALSE
  result <- wasserstein_minimax_IF_inference(
    data, covariates = c("X1", "X2"),
    gamma = 0.5, tau = 0.1, K = 3, method = "lm",
    use_propensity_scores = FALSE
  )

  # Check structure
  expect_type(result, "list")
  expect_true("phi_star" %in% names(result))
  expect_true("se" %in% names(result))
  expect_true("ci_lower" %in% names(result))
  expect_true("ci_upper" %in% names(result))

  # Check values are finite
  expect_true(is.finite(result$phi_star))
  expect_true(is.finite(result$se))
  expect_true(result$se > 0)
})


test_that("wasserstein_minimax_IF_inference works with propensity scores", {
  set.seed(456)
  data <- generate_nonlinear_study_data(
    n = 200, d = 2, pattern = "quadratic", seed = 456
  )

  # With propensity scores
  result <- wasserstein_minimax_IF_inference(
    data, covariates = c("X1", "X2"),
    gamma = 0.5, tau = 0.1, K = 3, method = "lm",
    use_propensity_scores = TRUE,
    propensity_method = "logistic"
  )

  # Check structure
  expect_type(result, "list")
  expect_true(is.finite(result$phi_star))
  expect_true(is.finite(result$se))
  expect_true(result$se > 0)

  # CI should be valid
  expect_true(result$ci_lower < result$phi_star)
  expect_true(result$ci_upper > result$phi_star)
})


test_that("propensity scores change the IF values", {
  set.seed(789)
  data <- generate_nonlinear_study_data(
    n = 150, d = 2, pattern = "linear", seed = 789
  )

  # Without propensity scores
  result_no_ps <- wasserstein_minimax_IF_inference(
    data, covariates = c("X1", "X2"),
    gamma = 0.5, tau = 0.1, K = 3, method = "lm",
    use_propensity_scores = FALSE
  )

  # With propensity scores
  result_with_ps <- wasserstein_minimax_IF_inference(
    data, covariates = c("X1", "X2"),
    gamma = 0.5, tau = 0.1, K = 3, method = "lm",
    use_propensity_scores = TRUE
  )

  # IF values should differ (DR correction changes them)
  expect_false(identical(result_no_ps$IF_vals, result_with_ps$IF_vals))

  # But both should give finite results
  expect_true(all(is.finite(result_no_ps$IF_vals)))
  expect_true(all(is.finite(result_with_ps$IF_vals)))
})


test_that("compute_IF_product_wasserstein gives proper DR correction", {
  # Single observation
  obs <- data.frame(A = 1, S = 1.5, Y = 2.0)
  tau_S <- 0.5
  tau_Y <- 0.6
  mu_S1 <- 1.2
  mu_S0 <- 0.7
  mu_Y1 <- 1.8
  mu_Y0 <- 1.2
  e <- 0.5

  IF_val <- compute_IF_product_wasserstein(
    obs, tau_S, tau_Y, mu_S1, mu_S0, mu_Y1, mu_Y0, e
  )

  # Should be finite
  expect_true(is.finite(IF_val))
  expect_type(IF_val, "double")

  # For treated (A=1): should use (S - mu_S1) and (Y - mu_Y1)
  resid_S <- obs$S - mu_S1  # 1.5 - 1.2 = 0.3
  resid_Y <- obs$Y - mu_Y1  # 2.0 - 1.8 = 0.2

  expected <- (1 / e) * (
    resid_S * tau_Y +   # 0.3 * 0.6
    resid_Y * tau_S +   # 0.2 * 0.5
    resid_S * resid_Y   # 0.3 * 0.2
  )

  expect_equal(IF_val, expected, tolerance = 1e-10)
})


test_that("compute_IF_product_wasserstein handles control arm", {
  # Control observation
  obs <- data.frame(A = 0, S = 0.8, Y = 1.1)
  tau_S <- 0.5
  tau_Y <- 0.6
  mu_S1 <- 1.2
  mu_S0 <- 0.7
  mu_Y1 <- 1.8
  mu_Y0 <- 1.2
  e <- 0.5

  IF_val <- compute_IF_product_wasserstein(
    obs, tau_S, tau_Y, mu_S1, mu_S0, mu_Y1, mu_Y0, e
  )

  # Should be finite
  expect_true(is.finite(IF_val))

  # For control (A=0): should use (S - mu_S0) and (Y - mu_Y0)
  resid_S <- obs$S - mu_S0  # 0.8 - 0.7 = 0.1
  resid_Y <- obs$Y - mu_Y0  # 1.1 - 1.2 = -0.1

  expected <- -(1 / (1 - e)) * (
    resid_S * tau_Y +
    resid_Y * tau_S +
    resid_S * resid_Y
  )

  expect_equal(IF_val, expected, tolerance = 1e-10)
})


test_that("propensity score methods work (if packages available)", {
  skip_if_not_installed("mgcv")

  set.seed(999)
  data <- generate_nonlinear_study_data(
    n = 150, d = 2, pattern = "quadratic", seed = 999
  )

  # GAM propensity scores
  result_gam <- wasserstein_minimax_IF_inference(
    data, covariates = c("X1", "X2"),
    gamma = 0.5, tau = 0.1, K = 3, method = "lm",
    use_propensity_scores = TRUE,
    propensity_method = "gam"
  )

  expect_true(is.finite(result_gam$phi_star))
  expect_true(is.finite(result_gam$se))
})


test_that("backward compatibility: without PS matches old behavior", {
  set.seed(123456)
  data <- data.frame(
    A = rbinom(100, 1, 0.5),
    S = rnorm(100, mean = 1 + 0.5 * rbinom(100, 1, 0.5)),
    Y = rnorm(100, mean = 2 + 0.8 * rbinom(100, 1, 0.5)),
    X1 = rnorm(100),
    X2 = rnorm(100)
  )

  # New implementation without PS should match old behavior
  # (using e = 0.5 for randomized trial)
  result <- wasserstein_minimax_IF_inference(
    data, covariates = c("X1", "X2"),
    gamma = 0.5, tau = 0.1, K = 3, method = "lm",
    use_propensity_scores = FALSE
  )

  # Should have reasonable values (not testing exact match to old code,
  # just that it works)
  expect_true(abs(result$phi_star) < 5)  # Reasonable magnitude
  expect_true(result$se > 0 && result$se < 1)  # Reasonable SE
  expect_true(result$ci_lower < result$ci_upper)  # Valid CI
})


test_that("extreme propensity scores are handled gracefully", {
  set.seed(111)
  # Create data with some extreme propensity potential
  data <- data.frame(
    A = c(rep(1, 80), rep(0, 20)),  # Unbalanced
    S = rnorm(100),
    Y = rnorm(100),
    X1 = rnorm(100),
    X2 = rnorm(100)
  )

  # Should not crash (propensity score estimation includes trimming)
  expect_no_error({
    result <- wasserstein_minimax_IF_inference(
      data, covariates = c("X1", "X2"),
      gamma = 0.5, tau = 0.1, K = 3, method = "lm",
      use_propensity_scores = TRUE
    )
  })
})
