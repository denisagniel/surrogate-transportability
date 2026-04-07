# Tests for nuisance estimation infrastructure (Phase 1)

test_that("estimate_treatment_effects works with linear method", {
  # Generate test data
  set.seed(123)
  data <- data.frame(
    A = rbinom(200, 1, 0.5),
    S = rnorm(200),
    Y = rnorm(200),
    X1 = rnorm(200),
    X2 = rnorm(200)
  )

  result <- estimate_treatment_effects(
    data = data,
    outcome = "S",
    covariates = c("X1", "X2"),
    method = "lm",
    cross_fit = FALSE
  )

  # Check structure
  expect_type(result, "list")
  expect_named(result, c("tau_hat", "mu1_hat", "mu0_hat", "method",
                          "cross_fitted", "diagnostics"))

  # Check dimensions
  expect_length(result$tau_hat, 200)
  expect_length(result$mu1_hat, 200)
  expect_length(result$mu0_hat, 200)

  # Check method
  expect_equal(result$method, "lm")
  expect_false(result$cross_fitted)

  # Check diagnostics
  expect_type(result$diagnostics, "list")
  expect_true("R_squared" %in% names(result$diagnostics))
})


test_that("estimate_treatment_effects works with cross-fitting", {
  set.seed(456)
  data <- data.frame(
    A = rbinom(250, 1, 0.5),
    S = rnorm(250),
    Y = rnorm(250),
    X1 = rnorm(250),
    X2 = rnorm(250)
  )

  result <- estimate_treatment_effects(
    data = data,
    outcome = "Y",
    covariates = c("X1", "X2"),
    method = "lm",
    cross_fit = TRUE,
    K = 5
  )

  # Check cross-fitting flag
  expect_true(result$cross_fitted)

  # Check diagnostics has cv_R_squared
  expect_true("cv_R_squared" %in% names(result$diagnostics))
  expect_false("R_squared" %in% names(result$diagnostics))
})


test_that("estimate_treatment_effects works with GAM method (if mgcv available)", {
  skip_if_not_installed("mgcv")

  set.seed(789)
  data <- generate_nonlinear_study_data(
    n = 200, d = 2, pattern = "quadratic", seed = 789
  )

  result <- estimate_treatment_effects(
    data = data,
    outcome = "S",
    covariates = c("X1", "X2"),
    method = "gam",
    cross_fit = FALSE
  )

  expect_equal(result$method, "gam")
  expect_length(result$tau_hat, 200)
})


test_that("estimate_treatment_effects works with RF method (if randomForest available)", {
  skip_if_not_installed("randomForest")

  set.seed(101112)
  data <- generate_nonlinear_study_data(
    n = 200, d = 2, pattern = "interaction", seed = 101112
  )

  result <- estimate_treatment_effects(
    data = data,
    outcome = "Y",
    covariates = c("X1", "X2"),
    method = "rf",
    cross_fit = FALSE
  )

  expect_equal(result$method, "rf")
  expect_length(result$tau_hat, 200)
})


test_that("estimate_treatment_effects works with kernel method", {
  set.seed(131415)
  data <- data.frame(
    A = rbinom(100, 1, 0.5),
    S = rnorm(100),
    Y = rnorm(100),
    X1 = rnorm(100),
    X2 = rnorm(100)
  )

  result <- estimate_treatment_effects(
    data = data,
    outcome = "S",
    covariates = c("X1", "X2"),
    method = "kernel",
    cross_fit = FALSE
  )

  expect_equal(result$method, "kernel")
  expect_length(result$tau_hat, 100)
})


test_that("estimate_treatment_effects validates inputs correctly", {
  data <- data.frame(
    A = rbinom(50, 1, 0.5),
    S = rnorm(50),
    X1 = rnorm(50)
  )

  # Missing outcome
  expect_error(
    estimate_treatment_effects(data, outcome = "Y", covariates = "X1"),
    "Outcome 'Y' not found"
  )

  # Missing treatment
  data_no_A <- data[, c("S", "X1")]
  expect_error(
    estimate_treatment_effects(data_no_A, outcome = "S", covariates = "X1"),
    "Treatment column 'A' not found"
  )

  # Missing covariates
  expect_error(
    estimate_treatment_effects(data, outcome = "S", covariates = c("X1", "X2")),
    "Covariates not found.*X2"
  )
})


test_that("validate_method_availability detects missing packages", {
  # lm and kernel always available
  result_lm <- validate_method_availability("lm")
  expect_true(result_lm$available)

  result_kernel <- validate_method_availability("kernel")
  expect_true(result_kernel$available)

  # GAM requires mgcv
  result_gam <- validate_method_availability("gam")
  if (requireNamespace("mgcv", quietly = TRUE)) {
    expect_true(result_gam$available)
  } else {
    expect_false(result_gam$available)
    expect_match(result_gam$message, "mgcv")
  }

  # RF requires randomForest
  result_rf <- validate_method_availability("rf")
  if (requireNamespace("randomForest", quietly = TRUE)) {
    expect_true(result_rf$available)
  } else {
    expect_false(result_rf$available)
    expect_match(result_rf$message, "randomForest")
  }
})


test_that("check_sample_size_adequacy warns appropriately", {
  # Adequate sample size
  result_ok <- check_sample_size_adequacy(n = 200, d = 5, method = "lm")
  expect_true(result_ok$adequate)
  expect_equal(result_ok$message, "")

  # Inadequate sample size
  result_small <- check_sample_size_adequacy(n = 50, d = 10, method = "rf")
  expect_false(result_small$adequate)
  expect_match(result_small$message, "too small")
  expect_equal(result_small$threshold, 1000)  # 100 * 10
})


test_that("compute_nuisance_diagnostics computes R² correctly", {
  observed <- c(1, 2, 3, 4, 5)
  predictions <- c(1.1, 1.9, 3.1, 3.9, 5.1)

  R2 <- compute_nuisance_diagnostics(predictions, observed, "R2")

  # Compute expected R²
  residuals <- observed - predictions
  RSS <- sum(residuals^2)
  TSS <- sum((observed - mean(observed))^2)
  expected_R2 <- 1 - RSS / TSS

  expect_equal(R2, expected_R2)
  expect_true(R2 > 0.95)  # Very good fit
})


test_that("compute_nuisance_diagnostics computes other metrics correctly", {
  observed <- c(1, 2, 3, 4, 5)
  predictions <- c(1.1, 1.9, 3.1, 3.9, 5.1)

  # MSE
  MSE <- compute_nuisance_diagnostics(predictions, observed, "MSE")
  residuals <- observed - predictions
  expected_MSE <- mean(residuals^2)
  expect_equal(MSE, expected_MSE)

  # RMSE
  RMSE <- compute_nuisance_diagnostics(predictions, observed, "RMSE")
  expect_equal(RMSE, sqrt(expected_MSE))

  # MAE
  MAE <- compute_nuisance_diagnostics(predictions, observed, "MAE")
  expected_MAE <- mean(abs(residuals))
  expect_equal(MAE, expected_MAE)
})


test_that("compute_nuisance_diagnostics handles NA values", {
  observed <- c(1, 2, NA, 4, 5)
  predictions <- c(1.1, 1.9, 3.1, 3.9, 5.1)

  expect_warning(
    result <- compute_nuisance_diagnostics(predictions, observed, "R2"),
    "NA values detected"
  )
  expect_true(is.na(result))
})


test_that("backward compatibility: method='lm' matches old behavior", {
  # This test ensures that the new infrastructure produces the same results
  # as the old hardcoded lm() approach

  set.seed(999)
  data <- data.frame(
    A = rbinom(150, 1, 0.5),
    S = rnorm(150, mean = 1 + 0.5 * rbinom(150, 1, 0.5)),
    Y = rnorm(150, mean = 2 + 0.8 * rbinom(150, 1, 0.5)),
    X1 = rnorm(150),
    X2 = rnorm(150)
  )

  # New approach
  result_new <- estimate_treatment_effects(
    data = data,
    outcome = "S",
    covariates = c("X1", "X2"),
    method = "lm",
    cross_fit = FALSE,
    return_diagnostics = FALSE
  )

  # Old approach (replicate old logic)
  formula_str <- "S ~ A + X1 + X2"
  fit_old <- lm(as.formula(formula_str), data = data)
  data_a1 <- data
  data_a1$A <- 1
  mu1_old <- predict(fit_old, newdata = data_a1)
  data_a0 <- data
  data_a0$A <- 0
  mu0_old <- predict(fit_old, newdata = data_a0)
  tau_old <- mu1_old - mu0_old

  # Should match to machine precision
  expect_equal(result_new$tau_hat, as.numeric(tau_old), tolerance = 1e-10)
  expect_equal(result_new$mu1_hat, as.numeric(mu1_old), tolerance = 1e-10)
  expect_equal(result_new$mu0_hat, as.numeric(mu0_old), tolerance = 1e-10)
})


test_that("estimate_treatment_effects with diagnostics=FALSE works", {
  set.seed(222)
  data <- data.frame(
    A = rbinom(100, 1, 0.5),
    S = rnorm(100),
    X1 = rnorm(100)
  )

  result <- estimate_treatment_effects(
    data = data,
    outcome = "S",
    covariates = "X1",
    method = "lm",
    cross_fit = FALSE,
    return_diagnostics = FALSE
  )

  expect_null(result$diagnostics)
})


test_that("flexible methods show improved fit on nonlinear data (if available)", {
  skip_if_not_installed("mgcv")

  set.seed(333)
  # Generate data with quadratic treatment effects
  data <- generate_nonlinear_study_data(
    n = 300, d = 2, pattern = "quadratic", noise_sd = 0.3, seed = 333
  )

  # Fit with lm (misspecified)
  result_lm <- estimate_treatment_effects(
    data = data, outcome = "S", covariates = c("X1", "X2"),
    method = "lm", cross_fit = FALSE
  )

  # Fit with GAM (flexible)
  result_gam <- estimate_treatment_effects(
    data = data, outcome = "S", covariates = c("X1", "X2"),
    method = "gam", cross_fit = FALSE
  )

  # GAM should have higher R² than lm on quadratic data
  R2_lm <- result_lm$diagnostics$R_squared
  R2_gam <- result_gam$diagnostics$R_squared

  expect_true(R2_gam > R2_lm,
              info = sprintf("GAM R² (%.3f) should exceed lm R² (%.3f) on quadratic data",
                             R2_gam, R2_lm))
})
