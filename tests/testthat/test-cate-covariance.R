# Tests for CATE covariance functional

test_that("functional_cate_covariance basic structure", {
  # Generate simple test data
  set.seed(123)
  n <- 200
  data <- data.frame(
    A = rbinom(n, 1, 0.5),
    X1 = rnorm(n),
    X2 = rnorm(n)
  )

  # Add outcomes
  data$S <- rnorm(n, mean = data$A * 0.3, sd = 1)
  data$Y <- rnorm(n, mean = data$A * 0.4, sd = 1)

  result <- functional_cate_covariance(
    data = data,
    covariates = c("X1", "X2"),
    nuisance_method = "lm",
    cross_fit = FALSE
  )

  # Check structure
  expect_type(result, "list")
  expect_true(all(c("phi", "se", "ci", "E_tau_S", "E_tau_Y", "tau_S", "tau_Y") %in% names(result)))

  # Check types
  expect_type(result$phi, "double")
  expect_length(result$phi, 1)
  expect_type(result$se, "double")
  expect_length(result$se, 1)
  expect_length(result$ci, 2)

  # Check dimensions of CATE estimates
  expect_length(result$tau_S, n)
  expect_length(result$tau_Y, n)

  # SE should be positive
  expect_true(result$se > 0)

  # CI should be ordered
  expect_true(result$ci[1] < result$ci[2])
})


test_that("functional_cate_covariance detects positive covariance", {
  # Generate data with positively correlated CATEs
  set.seed(456)
  n <- 500
  X1 <- rnorm(n)
  X2 <- rnorm(n)

  # Baseline means (no treatment effect)
  baseline_S <- 0.2 + 0.1 * X2
  baseline_Y <- 0.3 + 0.1 * X2

  # CATEs that depend on X1 (both increase with X1 -> positive cov)
  tau_S_true <- 0.3 + 0.4 * X1
  tau_Y_true <- 0.4 + 0.5 * X1  # Correlated with tau_S through X1

  A <- rbinom(n, 1, 0.5)

  # Generate outcomes: outcome = baseline + A * tau + noise
  S <- baseline_S + A * tau_S_true + rnorm(n, sd = 0.5)
  Y <- baseline_Y + A * tau_Y_true + rnorm(n, sd = 0.5)

  data <- data.frame(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

  result <- functional_cate_covariance(
    data = data,
    covariates = c("X1", "X2"),
    nuisance_method = "lm",
    cross_fit = TRUE,
    K = 5
  )

  # Should detect positive covariance
  expect_true(result$phi > 0)

  # True covariance should be Cov(0.4*X1, 0.5*X1) = 0.4*0.5*Var(X1) ≈ 0.2
  # Estimate should be reasonably close
  expect_true(result$phi > 0.05)  # At least positive and meaningful
})


test_that("functional_cate_covariance detects negative covariance", {
  # Generate data with negatively correlated CATEs
  set.seed(789)
  n <- 500
  X1 <- rnorm(n)

  baseline_S <- 0.2
  baseline_Y <- 0.3

  # CATEs that move in opposite directions
  tau_S_true <- 0.3 + 0.4 * X1
  tau_Y_true <- 0.4 - 0.5 * X1  # Negatively correlated with tau_S

  A <- rbinom(n, 1, 0.5)

  S <- baseline_S + A * tau_S_true + rnorm(n, sd = 0.5)
  Y <- baseline_Y + A * tau_Y_true + rnorm(n, sd = 0.5)

  data <- data.frame(A = A, S = S, Y = Y, X1 = X1)

  result <- functional_cate_covariance(
    data = data,
    covariates = "X1",
    nuisance_method = "lm",
    cross_fit = TRUE
  )

  # Should detect negative covariance
  expect_true(result$phi < 0)

  # True covariance: Cov(0.4*X1, -0.5*X1) = -0.2*Var(X1) ≈ -0.2
  expect_true(result$phi < -0.05)
})


test_that("functional_cate_covariance detects zero covariance (independent)", {
  # Generate data with independent CATEs
  set.seed(101112)
  n <- 500
  X1 <- rnorm(n)
  X2 <- rnorm(n)

  baseline_S <- 0.2
  baseline_Y <- 0.3

  # tau_S depends on X1, tau_Y depends on X2 (independent)
  tau_S_true <- 0.3 + 0.4 * X1
  tau_Y_true <- 0.4 + 0.5 * X2

  A <- rbinom(n, 1, 0.5)

  S <- baseline_S + A * tau_S_true + rnorm(n, sd = 0.5)
  Y <- baseline_Y + A * tau_Y_true + rnorm(n, sd = 0.5)

  data <- data.frame(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

  result <- functional_cate_covariance(
    data = data,
    covariates = c("X1", "X2"),
    nuisance_method = "lm",
    cross_fit = TRUE
  )

  # Should be close to zero (within ~2 SE)
  expect_true(abs(result$phi) < 2 * result$se)

  # True covariance should be 0, so phi should be small
  expect_true(abs(result$phi) < 0.1)
})


test_that("functional_cate_covariance works without covariates (RCT)", {
  # Randomized trial: no covariates, constant treatment effects
  set.seed(131415)
  n <- 300
  A <- rbinom(n, 1, 0.5)

  # Constant treatment effects (no heterogeneity)
  S <- rnorm(n, mean = A * 0.5, sd = 1)
  Y <- rnorm(n, mean = A * 0.6, sd = 1)

  data <- data.frame(A = A, S = S, Y = Y)

  result <- functional_cate_covariance(
    data = data,
    covariates = NULL,
    nuisance_method = "lm",
    cross_fit = FALSE
  )

  # With constant treatment effects, there's no variation in CATEs
  # So covariance should be ~0 (or numerically very small)
  expect_true(abs(result$phi) < 0.2)

  # All tau estimates should be approximately constant
  expect_true(sd(result$tau_S) < 0.1)  # Nearly constant
  expect_true(sd(result$tau_Y) < 0.1)
})


test_that("functional_cate_covariance returns influence function correctly", {
  set.seed(161718)
  n <- 200
  data <- data.frame(
    A = rbinom(n, 1, 0.5),
    X1 = rnorm(n)
  )
  data$S <- rnorm(n, mean = data$A * 0.3, sd = 1)
  data$Y <- rnorm(n, mean = data$A * 0.4, sd = 1)

  result <- functional_cate_covariance(
    data = data,
    covariates = "X1",
    return_influence_function = TRUE
  )

  # Influence function should exist and have correct length
  expect_true("influence_function" %in% names(result))
  expect_length(result$influence_function, n)

  # Influence function should have mean ~0 (by construction)
  expect_true(abs(mean(result$influence_function)) < 0.1)

  # SE should match variance of influence function
  expected_se <- sqrt(var(result$influence_function) / n)
  expect_equal(result$se, expected_se, tolerance = 1e-6)
})


test_that("functional_cate_covariance works without influence function", {
  set.seed(192021)
  n <- 200
  data <- data.frame(
    A = rbinom(n, 1, 0.5),
    X1 = rnorm(n)
  )
  data$S <- rnorm(n, mean = data$A * 0.3, sd = 1)
  data$Y <- rnorm(n, mean = data$A * 0.4, sd = 1)

  result <- functional_cate_covariance(
    data = data,
    covariates = "X1",
    return_influence_function = FALSE
  )

  # Influence function should not be in result
  expect_false("influence_function" %in% names(result))

  # But SE should still be computed
  expect_true(result$se > 0)
})


test_that("functional_cate_covariance returns nuisance estimates correctly", {
  set.seed(222324)
  n <- 200
  data <- data.frame(
    A = rbinom(n, 1, 0.5),
    X1 = rnorm(n)
  )
  data$S <- rnorm(n, mean = data$A * 0.3, sd = 1)
  data$Y <- rnorm(n, mean = data$A * 0.4, sd = 1)

  result <- functional_cate_covariance(
    data = data,
    covariates = "X1",
    return_nuisance = TRUE
  )

  # Nuisance estimates should exist
  expect_true("nuisance_estimates" %in% names(result))
  expect_type(result$nuisance_estimates, "list")

  # Should contain all nuisance functions
  expect_true(all(c("mu_S1", "mu_S0", "mu_Y1", "mu_Y0", "e_X") %in%
                  names(result$nuisance_estimates)))

  # Each should have correct length
  expect_length(result$nuisance_estimates$mu_S1, n)
  expect_length(result$nuisance_estimates$e_X, n)

  # Propensity scores should be in [0,1]
  expect_true(all(result$nuisance_estimates$e_X >= 0))
  expect_true(all(result$nuisance_estimates$e_X <= 1))
})


test_that("functional_cate_covariance cross-fitting gives different results", {
  set.seed(252627)
  n <- 200
  X1 <- rnorm(n)
  tau_S <- 0.3 + 0.4 * X1
  tau_Y <- 0.4 + 0.5 * X1

  A <- rbinom(n, 1, 0.5)
  S <- 0.2 + A * tau_S + rnorm(n, sd = 0.5)
  Y <- 0.3 + A * tau_Y + rnorm(n, sd = 0.5)

  data <- data.frame(A = A, S = S, Y = Y, X1 = X1)

  # Without cross-fitting
  result_no_cf <- functional_cate_covariance(
    data = data,
    covariates = "X1",
    cross_fit = FALSE
  )

  # With cross-fitting
  result_cf <- functional_cate_covariance(
    data = data,
    covariates = "X1",
    cross_fit = TRUE,
    K = 5
  )

  # Results should differ slightly (due to cross-fitting)
  expect_false(identical(result_no_cf$phi, result_cf$phi))

  # But should be in same ballpark
  expect_true(abs(result_no_cf$phi - result_cf$phi) < 0.3)

  # Both should detect positive covariance
  expect_true(result_no_cf$phi > 0)
  expect_true(result_cf$phi > 0)
})


test_that("functional_cate_covariance works with GAM method", {
  skip_if_not_installed("mgcv")

  set.seed(282930)
  n <- 300
  X1 <- rnorm(n)

  # Nonlinear CATEs
  tau_S <- 0.3 + 0.4 * X1^2
  tau_Y <- 0.4 + 0.5 * X1^2  # Both depend on X1^2 -> correlated

  A <- rbinom(n, 1, 0.5)
  S <- 0.2 + A * tau_S + rnorm(n, sd = 0.5)
  Y <- 0.3 + A * tau_Y + rnorm(n, sd = 0.5)

  data <- data.frame(A = A, S = S, Y = Y, X1 = X1)

  result <- functional_cate_covariance(
    data = data,
    covariates = "X1",
    nuisance_method = "gam",
    cross_fit = TRUE
  )

  # Should detect positive covariance
  expect_true(result$phi > 0)

  # GAM should handle nonlinearity better than lm
  expect_type(result$phi, "double")
})


test_that("functional_cate_covariance decomposition is correct", {
  # Check that phi = E[prod] - E[tau_S] * E[tau_Y]
  set.seed(313233)
  n <- 200
  X1 <- rnorm(n)
  tau_S <- 0.3 + 0.4 * X1
  tau_Y <- 0.4 + 0.5 * X1

  A <- rbinom(n, 1, 0.5)
  S <- rnorm(n, mean = ifelse(A == 1, tau_S, 0), sd = 0.5)
  Y <- rnorm(n, mean = ifelse(A == 1, tau_Y, 0), sd = 0.5)

  data <- data.frame(A = A, S = S, Y = Y, X1 = X1)

  result <- functional_cate_covariance(
    data = data,
    covariates = "X1",
    cross_fit = FALSE
  )

  # Check decomposition: phi = E_product - E_tau_S * E_tau_Y
  expected_phi <- result$E_product - result$E_tau_S * result$E_tau_Y

  expect_equal(result$phi, expected_phi, tolerance = 1e-10)
})


test_that("functional_cate_covariance handles small sample sizes", {
  # Small sample should still work but with larger SE
  set.seed(343536)
  n <- 50
  data <- data.frame(
    A = rbinom(n, 1, 0.5),
    X1 = rnorm(n)
  )
  data$S <- rnorm(n, mean = data$A * 0.3, sd = 1)
  data$Y <- rnorm(n, mean = data$A * 0.4, sd = 1)

  result <- functional_cate_covariance(
    data = data,
    covariates = "X1",
    cross_fit = FALSE
  )

  # Should complete without error
  expect_type(result$phi, "double")
  expect_true(result$se > 0)

  # SE should be relatively large for small n
  expect_true(result$se > 0.05)
})


test_that("functional_cate_covariance confidence interval contains truth (approx)", {
  # Generate data with known covariance structure
  set.seed(373839)
  n <- 1000  # Large sample for accurate estimation

  X1 <- rnorm(n)

  baseline_S <- 0.2
  baseline_Y <- 0.3

  # CATEs with known covariance
  tau_S <- 0.3 + 0.4 * X1
  tau_Y <- 0.4 + 0.5 * X1

  # True covariance: Cov(0.4*X1, 0.5*X1) = 0.2 * Var(X1) ≈ 0.2
  true_cov <- 0.4 * 0.5 * var(X1)

  A <- rbinom(n, 1, 0.5)
  S <- baseline_S + A * tau_S + rnorm(n, sd = 0.3)
  Y <- baseline_Y + A * tau_Y + rnorm(n, sd = 0.3)

  data <- data.frame(A = A, S = S, Y = Y, X1 = X1)

  result <- functional_cate_covariance(
    data = data,
    covariates = "X1",
    nuisance_method = "lm",  # Correct model
    cross_fit = TRUE
  )

  # CI should contain true value (with high probability for large n)
  # Note: This can fail due to randomness, but should pass most of the time
  expect_true(result$ci[1] <= true_cov & true_cov <= result$ci[2],
              label = sprintf("CI [%.3f, %.3f] should contain truth %.3f",
                              result$ci[1], result$ci[2], true_cov))
})
