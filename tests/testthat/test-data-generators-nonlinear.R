# Tests for nonlinear data generators (Phase 1)

test_that("generate_nonlinear_study_data creates correct structure", {
  set.seed(111)
  data <- generate_nonlinear_study_data(n = 100, d = 3, pattern = "linear")

  # Check dimensions
  expect_s3_class(data, "data.frame")
  expect_equal(nrow(data), 100)
  expect_equal(ncol(data), 6)  # A, S, Y, X1, X2, X3

  # Check columns
  expect_true(all(c("A", "S", "Y", "X1", "X2", "X3") %in% names(data)))

  # Check types
  expect_type(data$A, "integer")
  expect_true(all(data$A %in% c(0, 1)))
  expect_type(data$S, "double")
  expect_type(data$Y, "double")
})


test_that("generate_nonlinear_study_data with linear pattern", {
  set.seed(222)
  data <- generate_nonlinear_study_data(
    n = 200, d = 2, pattern = "linear", effect_size = "medium", seed = 222
  )

  # Treatment should be randomized (approximately 50/50)
  prop_treated <- mean(data$A)
  expect_true(prop_treated > 0.4 && prop_treated < 0.6)

  # Covariates should be approximately standard normal
  expect_true(abs(mean(data$X1)) < 0.2)
  expect_true(abs(sd(data$X1) - 1) < 0.2)
})


test_that("generate_nonlinear_study_data with quadratic pattern", {
  set.seed(333)
  data <- generate_nonlinear_study_data(
    n = 300, d = 2, pattern = "quadratic", seed = 333
  )

  # Check that outcomes vary (not constant)
  expect_true(sd(data$S) > 0)
  expect_true(sd(data$Y) > 0)

  # Fit linear and quadratic models, quadratic should fit better
  # (Only test on treated group to isolate treatment effect structure)
  data_treated <- data[data$A == 1, ]

  fit_linear <- lm(S ~ X1, data = data_treated)
  fit_quadratic <- lm(S ~ X1 + I(X1^2), data = data_treated)

  R2_linear <- summary(fit_linear)$r.squared
  R2_quadratic <- summary(fit_quadratic)$r.squared

  expect_true(R2_quadratic > R2_linear,
              info = sprintf("Quadratic R² (%.3f) should exceed linear R² (%.3f)",
                             R2_quadratic, R2_linear))
})


test_that("generate_nonlinear_study_data with interaction pattern", {
  set.seed(444)
  data <- generate_nonlinear_study_data(
    n = 300, d = 3, pattern = "interaction", seed = 444
  )

  # Check structure
  expect_true("X3" %in% names(data))

  # Fit models with and without interaction
  data_treated <- data[data$A == 1, ]

  fit_additive <- lm(S ~ X1 + X2, data = data_treated)
  fit_interaction <- lm(S ~ X1 * X2, data = data_treated)

  R2_additive <- summary(fit_additive)$r.squared
  R2_interaction <- summary(fit_interaction)$r.squared

  expect_true(R2_interaction > R2_additive,
              info = sprintf("Interaction R² (%.3f) should exceed additive R² (%.3f)",
                             R2_interaction, R2_additive))
})


test_that("generate_nonlinear_study_data with threshold pattern", {
  set.seed(555)
  data <- generate_nonlinear_study_data(
    n = 400, d = 2, pattern = "threshold", seed = 555
  )

  # Treatment effects should have step function structure
  # Separate treated observations by X1 > 0 vs X1 <= 0
  data_treated <- data[data$A == 1, ]
  data_control <- data[data$A == 0, ]

  # Mean outcome should differ by X1 threshold
  mean_S_pos <- mean(data_treated$S[data_treated$X1 > 0])
  mean_S_neg <- mean(data_treated$S[data_treated$X1 <= 0])

  # Should see difference due to threshold (though noisy)
  # Just check that there's variation (not testing exact threshold value)
  expect_true(abs(mean_S_pos - mean_S_neg) > 0.1)
})


test_that("generate_nonlinear_study_data with sine pattern", {
  set.seed(666)
  data <- generate_nonlinear_study_data(
    n = 500, d = 2, pattern = "sine", seed = 666
  )

  # Sine pattern should create oscillating treatment effects
  # Check that outcomes vary smoothly with X1
  data_treated <- data[data$A == 1, ]

  # Not a strong test, just check that data was generated
  expect_true(nrow(data_treated) > 0)
  expect_true(sd(data_treated$S) > 0)
})


test_that("generate_nonlinear_study_data effect size scaling works", {
  set.seed(777)

  data_small <- generate_nonlinear_study_data(
    n = 200, d = 2, pattern = "linear", effect_size = "small", seed = 777
  )

  set.seed(777)
  data_medium <- generate_nonlinear_study_data(
    n = 200, d = 2, pattern = "linear", effect_size = "medium", seed = 777
  )

  set.seed(777)
  data_large <- generate_nonlinear_study_data(
    n = 200, d = 2, pattern = "linear", effect_size = "large", seed = 777
  )

  # Estimate treatment effects (simple difference in means)
  ate_S_small <- mean(data_small$S[data_small$A == 1]) -
                 mean(data_small$S[data_small$A == 0])
  ate_S_medium <- mean(data_medium$S[data_medium$A == 1]) -
                  mean(data_medium$S[data_medium$A == 0])
  ate_S_large <- mean(data_large$S[data_large$A == 1]) -
                 mean(data_large$S[data_large$A == 0])

  # Should see ordering (though noisy, so use loose bounds)
  expect_true(abs(ate_S_small) < abs(ate_S_large))
  expect_true(abs(ate_S_medium) < abs(ate_S_large))
})


test_that("generate_nonlinear_study_data seed reproducibility", {
  data1 <- generate_nonlinear_study_data(
    n = 100, d = 2, pattern = "quadratic", seed = 999
  )

  data2 <- generate_nonlinear_study_data(
    n = 100, d = 2, pattern = "quadratic", seed = 999
  )

  # Should be identical
  expect_equal(data1, data2)
})


test_that("generate_nonlinear_study_data validates inputs", {
  # Sample size too small
  expect_error(
    generate_nonlinear_study_data(n = 5, d = 2),
    "at least 10"
  )

  # Invalid d
  expect_error(
    generate_nonlinear_study_data(n = 100, d = 0),
    "at least 1"
  )

  # Interaction requires d >= 2
  expect_error(
    generate_nonlinear_study_data(n = 100, d = 1, pattern = "interaction"),
    "at least 2 covariates"
  )
})


test_that("all patterns generate valid data", {
  patterns <- c("linear", "quadratic", "interaction", "threshold", "sine")

  for (pattern in patterns) {
    d <- if (pattern == "interaction") 2 else 1

    data <- generate_nonlinear_study_data(
      n = 100, d = d, pattern = pattern, seed = 888
    )

    # Basic checks
    expect_equal(nrow(data), 100)
    expect_true(all(c("A", "S", "Y") %in% names(data)))
    expect_true(all(data$A %in% c(0, 1)))
    expect_true(!any(is.na(data$S)))
    expect_true(!any(is.na(data$Y)))

    info_msg <- sprintf("Pattern: %s", pattern)
    expect_true(sd(data$S) > 0, info = info_msg)
    expect_true(sd(data$Y) > 0, info = info_msg)
  }
})


test_that("compute_tau_pattern internal function works", {
  X <- matrix(rnorm(100 * 2), ncol = 2)

  # Linear pattern
  tau_linear <- compute_tau_pattern(X, "linear", "S", multiplier = 1.0)
  expect_length(tau_linear, 100)
  expect_true(all(is.finite(tau_linear)))

  # Quadratic pattern
  tau_quad <- compute_tau_pattern(X, "quadratic", "Y", multiplier = 1.5)
  expect_length(tau_quad, 100)
  expect_true(all(is.finite(tau_quad)))

  # Patterns should differ
  expect_false(identical(tau_linear, tau_quad))
})


test_that("nonlinear DGPs are suitable for testing flexible methods", {
  skip_if_not_installed("mgcv")

  set.seed(12345)

  # Generate quadratic data
  data <- generate_nonlinear_study_data(
    n = 300, d = 2, pattern = "quadratic", noise_sd = 0.4, seed = 12345
  )

  # Fit linear model (misspecified)
  result_lm <- estimate_treatment_effects(
    data = data, outcome = "S", covariates = c("X1", "X2"),
    method = "lm", cross_fit = FALSE
  )

  # Fit GAM (flexible)
  result_gam <- estimate_treatment_effects(
    data = data, outcome = "S", covariates = c("X1", "X2"),
    method = "gam", cross_fit = FALSE
  )

  R2_lm <- result_lm$diagnostics$R_squared
  R2_gam <- result_gam$diagnostics$R_squared

  # GAM should fit better on nonlinear data
  expect_true(R2_gam >= R2_lm,
              info = sprintf("GAM R²=%.3f should be >= lm R²=%.3f on quadratic data",
                             R2_gam, R2_lm))

  # Both should have reasonable fit (not perfect due to noise)
  expect_true(R2_lm > 0.3,
              info = sprintf("lm should have R² > 0.3, got %.3f", R2_lm))
  expect_true(R2_gam > 0.5,
              info = sprintf("GAM should have R² > 0.5, got %.3f", R2_gam))
})
