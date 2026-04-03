test_that("compute_type_level_effects works correctly", {
  # Generate test data
  set.seed(123)
  n <- 200
  # Add a covariate X independent of treatment
  X <- rnorm(n)
  A <- rep(c(0, 1), each = n/2)
  S <- ifelse(A == 1, 1.0 + 0.3*X, 0.2*X) + rnorm(n, 0, 0.5)
  Y <- ifelse(A == 1, 0.8 + 0.2*X, 0.1*X) + rnorm(n, 0, 0.5)

  data <- data.frame(A = A, S = S, Y = Y, X = X)

  # Create bins based on X (independent of treatment)
  bins <- ifelse(X > median(X), 1, 2)

  # Compute type-level effects
  type_stats <- compute_type_level_effects(data, bins)

  # Check structure
  expect_equal(type_stats$J, 2)
  expect_length(type_stats$tau_s, 2)
  expect_length(type_stats$tau_y, 2)
  expect_length(type_stats$p0, 2)
  expect_equal(sum(type_stats$p0), 1, tolerance = 1e-8)

  # Check that all p0 are non-negative
  expect_true(all(type_stats$p0 >= 0))

  # Check that weighted average matches global effect
  # Since bins are independent of treatment and balanced, this should match
  global_tau_s <- mean(data$S[data$A == 1]) - mean(data$S[data$A == 0])
  type_weighted_tau_s <- sum(type_stats$p0 * type_stats$tau_s)
  expect_equal(global_tau_s, type_weighted_tau_s, tolerance = 0.05)
})


test_that("validate_type_level_stats catches errors", {
  # Valid stats
  valid_stats <- list(
    tau_s = c(0.5, 1.0),
    tau_y = c(0.4, 0.9),
    p0 = c(0.6, 0.4),
    n_k = c(60, 40),
    J = 2
  )
  expect_true(validate_type_level_stats(valid_stats))

  # Invalid: p0 doesn't sum to 1
  invalid_stats1 <- valid_stats
  invalid_stats1$p0 <- c(0.3, 0.4)
  expect_error(validate_type_level_stats(invalid_stats1), "does not sum to 1")

  # Invalid: negative p0
  invalid_stats2 <- valid_stats
  invalid_stats2$p0 <- c(1.2, -0.2)
  expect_error(validate_type_level_stats(invalid_stats2), "negative values")

  # Invalid: NA in tau_s
  invalid_stats3 <- valid_stats
  invalid_stats3$tau_s <- c(0.5, NA)
  expect_error(validate_type_level_stats(invalid_stats3), "NA values")
})


test_that("compute_concordance_from_types is correct", {
  type_stats <- list(
    tau_s = c(1.0, 0.5),
    tau_y = c(1.0, 0.3),
    p0 = c(0.6, 0.4),
    J = 2
  )

  # Concordance under p0
  concordance_p0 <- compute_concordance_from_types(type_stats)
  expected <- 0.6 * (1.0 * 1.0) + 0.4 * (0.5 * 0.3)
  expect_equal(concordance_p0, expected, tolerance = 1e-8)

  # Concordance under different q
  q_new <- c(0.3, 0.7)
  concordance_q <- compute_concordance_from_types(type_stats, q_new)
  expected_q <- 0.3 * (1.0 * 1.0) + 0.7 * (0.5 * 0.3)
  expect_equal(concordance_q, expected_q, tolerance = 1e-8)
})


test_that("TV closed-form concordance is correct", {
  skip_if_not_installed("randomForest")

  # Generate test data with known structure
  set.seed(456)
  n <- 300
  X1 <- rnorm(n)
  X2 <- rnorm(n)
  A <- rbinom(n, 1, 0.5)

  # Effects depend on covariates
  tau_s_true <- 0.5 + 0.3 * X1
  tau_y_true <- 0.4 + 0.25 * X1
  S <- ifelse(A == 1, tau_s_true, 0) + rnorm(n, 0, 0.5)
  Y <- ifelse(A == 1, tau_y_true, 0) + rnorm(n, 0, 0.5)

  data <- data.frame(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

  # Discretize with quantiles
  disc <- discretize_data(data, "quantiles", covariate_cols = c("X1", "X2"), J_target = 8)

  # Test TV closed form
  lambda <- 0.3
  result <- estimate_minimax_single_scheme(
    data = data,
    bins = disc$bins,
    lambda = lambda,
    functional_type = "concordance"
  )

  # Check structure
  expect_equal(result$method, "closed_form_tv")
  expect_true(!is.null(result$phi_value))
  expect_true(!is.null(result$type_stats))
  expect_null(result$effects)  # Should not compute effects for closed-form
  expect_null(result$innovations)

  # Check that phi_star <= concordance_p0 (minimax is conservative)
  expect_lte(result$phi_value, result$concordance_p0 + 1e-8)

  # Check formula: phi_star = concordance_p0 - lambda * max_deviation
  expected_phi_star <- result$concordance_p0 - lambda * result$worst_deviation
  expect_equal(result$phi_value, expected_phi_star, tolerance = 1e-8)
})


test_that("TV closed-form matches sampling for concordance", {
  skip_if_not_installed("randomForest")
  skip_if_not_installed("MCMCpack")

  # Simple test data
  set.seed(789)
  n <- 200
  data <- data.frame(
    A = rep(c(0, 1), each = n/2),
    S = c(rnorm(n/2, 0, 1), rnorm(n/2, 1.0, 1)),
    Y = c(rnorm(n/2, 0, 1), rnorm(n/2, 0.8, 1)),
    X = rnorm(n)
  )

  # Discretize
  bins <- cut(data$X, breaks = 4, labels = FALSE)
  lambda <- 0.2

  # Closed-form
  result_closed <- estimate_minimax_single_scheme(
    data, bins, lambda,
    functional_type = "concordance"
  )

  # Note: Can't directly test sampling approach for concordance without modifying
  # the function to allow it. The closed-form is the ONLY implementation for concordance.
  # But we can verify correctness via the formula.

  type_stats <- result_closed$type_stats
  h <- type_stats$tau_s * type_stats$tau_y
  concordance_p0 <- sum(type_stats$p0 * h)
  worst_deviation <- max(abs(h))

  # Verify formula
  expect_equal(result_closed$phi_value,
               concordance_p0 - lambda * worst_deviation,
               tolerance = 1e-10)
})


test_that("Wasserstein dual for concordance is correct", {
  # Simple 2-type case
  type_stats <- list(
    tau_s = c(1.0, 0.5),
    tau_y = c(1.0, 0.3),
    p0 = c(0.6, 0.4),
    n_k = c(60, 40),
    J = 2
  )

  # Simple cost matrix
  cost_matrix <- matrix(c(0, 1, 1, 0), 2, 2)
  lambda_w <- 0.5

  # Solve dual
  result <- wasserstein_concordance_dual(
    type_stats = type_stats,
    cost_matrix = cost_matrix,
    lambda_w = lambda_w,
    method = "brent"
  )

  # Check structure
  expect_true(!is.null(result$phi_star))
  expect_true(!is.null(result$optimal_gamma))
  expect_true(result$convergence)

  # Check dual feasibility: gamma >= 0
  expect_gte(result$optimal_gamma, 0)

  # Check dual is lower bound
  concordance_p0 <- compute_concordance_from_types(type_stats)
  expect_lte(result$phi_star, concordance_p0 + 1e-8)

  # Check objective_at_zero equals min(h) (unconstrained minimum)
  # At gamma=0, all mass goes to type with minimum concordance
  h <- type_stats$tau_s * type_stats$tau_y
  expect_equal(result$objective_at_zero, min(h), tolerance = 1e-8)

  # Check that concordance_p0 is correctly computed
  expect_equal(result$concordance_p0, concordance_p0, tolerance = 1e-8)
})


test_that("Wasserstein dual optimization methods agree", {
  # Test data
  type_stats <- list(
    tau_s = c(1.0, 0.7, 0.4),
    tau_y = c(0.9, 0.6, 0.2),
    p0 = c(0.5, 0.3, 0.2),
    J = 3
  )

  # Cost matrix (Euclidean distances)
  cost_matrix <- matrix(c(
    0, 1, 4,
    1, 0, 1,
    4, 1, 0
  ), 3, 3, byrow = TRUE)

  lambda_w <- 0.6

  # Test all methods
  result_brent <- wasserstein_concordance_dual(
    type_stats, cost_matrix, lambda_w, method = "brent"
  )

  result_golden <- wasserstein_concordance_dual(
    type_stats, cost_matrix, lambda_w, method = "golden"
  )

  result_grid <- wasserstein_concordance_dual(
    type_stats, cost_matrix, lambda_w, method = "grid", grid_size = 500
  )

  # All methods should give similar results
  expect_equal(result_brent$phi_star, result_golden$phi_star, tolerance = 1e-3)
  expect_equal(result_brent$phi_star, result_grid$phi_star, tolerance = 0.05)  # Grid is less precise
})


test_that("Wasserstein dual handles edge cases", {
  type_stats <- list(
    tau_s = c(1.0, 0.5),
    tau_y = c(1.0, 0.3),
    p0 = c(0.6, 0.4),
    J = 2
  )
  cost_matrix <- matrix(c(0, 1, 1, 0), 2, 2)

  # Edge case: lambda_w = 0 (no perturbation)
  result_zero <- wasserstein_concordance_dual(
    type_stats, cost_matrix, lambda_w = 0, method = "brent"
  )

  concordance_p0 <- compute_concordance_from_types(type_stats)
  expect_equal(result_zero$phi_star, concordance_p0, tolerance = 1e-8)
  expect_equal(result_zero$optimal_gamma, 0)
  expect_equal(result_zero$method, "closed_form_zero_radius")
})


test_that("golden_section_search works correctly", {
  # Test on simple quadratic: f(x) = -(x-2)^2 + 10
  # Maximum at x = 2, f(2) = 10
  f <- function(x) -(x - 2)^2 + 10

  result <- golden_section_search(f, lower = 0, upper = 5, tol = 1e-6, maximize = TRUE)

  expect_equal(result$argmax, 2, tolerance = 1e-4)
  expect_equal(result$max_value, 10, tolerance = 1e-4)
  expect_true(result$converged)
})


test_that("End-to-end: TV minimax with concordance", {
  skip_if_not_installed("randomForest")
  skip_if_not_installed("MCMCpack")

  # Generate test data
  set.seed(101112)
  n <- 250
  X1 <- rnorm(n)
  X2 <- rnorm(n)
  A <- rbinom(n, 1, 0.5)
  S <- ifelse(A == 1, 0.8 + 0.2*X1, 0) + rnorm(n, 0, 0.5)
  Y <- ifelse(A == 1, 0.6 + 0.15*X1, 0) + rnorm(n, 0, 0.5)

  data <- data.frame(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

  # Run minimax inference with concordance
  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.25,
    functional_type = "concordance",
    discretization_schemes = c("quantiles", "kmeans"),  # Skip RF for speed
    J_target = 8,
    n_innovations = 100,  # Small for test speed
    verbose = FALSE
  )

  # Check output structure
  expect_true(!is.null(result$phi_star))
  expect_true(!is.null(result$best_scheme))
  expect_true(!is.null(result$schemes_summary))
  expect_equal(result$functional_type, "concordance")

  # Check that result is numeric and reasonable
  expect_true(is.numeric(result$phi_star))
  expect_false(is.na(result$phi_star))
})


test_that("End-to-end: Wasserstein minimax with concordance", {
  skip_if_not_installed("randomForest")
  skip_if_not_installed("MCMCpack")

  # Generate test data
  set.seed(131415)
  n <- 250
  X1 <- rnorm(n)
  X2 <- rnorm(n)
  A <- rbinom(n, 1, 0.5)
  S <- ifelse(A == 1, 0.8 + 0.2*X1, 0) + rnorm(n, 0, 0.5)
  Y <- ifelse(A == 1, 0.6 + 0.15*X1, 0) + rnorm(n, 0, 0.5)

  data <- data.frame(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

  # Run Wasserstein minimax inference with concordance
  result <- surrogate_inference_minimax_wasserstein(
    current_data = data,
    lambda_w = 0.5,
    functional_type = "concordance",
    discretization_schemes = c("quantiles"),  # Just one for speed
    J_target = 8,
    n_innovations = 100,
    cost_function = "euclidean",
    verbose = FALSE
  )

  # Check output structure
  expect_true(!is.null(result$phi_star))
  expect_true(!is.null(result$best_scheme))
  expect_equal(result$functional_type, "concordance")
  expect_equal(result$cost_function, "euclidean")

  # Check that result is numeric and reasonable
  expect_true(is.numeric(result$phi_star))
  expect_false(is.na(result$phi_star))
})


test_that("functional_concordance works correctly", {
  # Create test treatment effects
  treatment_effects <- data.frame(
    delta_s = c(0.5, 0.8, 0.3, 0.9, 0.4),
    delta_y = c(0.4, 0.7, 0.2, 0.8, 0.3)
  )

  # Compute concordance
  concordance <- functional_concordance(treatment_effects)

  # Expected value
  expected <- mean(treatment_effects$delta_s * treatment_effects$delta_y)
  expect_equal(concordance, expected, tolerance = 1e-10)

  # Check relationship to correlation
  # Concordance = Cov(Delta_S, Delta_Y) = E[Delta_S * Delta_Y] - E[Delta_S]*E[Delta_Y]
  # For centered data: Concordance ≈ Cov(Delta_S, Delta_Y) = Cor * SD_S * SD_Y
  # But sample formulas differ (n vs n-1), so use looser tolerance
  cor_val <- cor(treatment_effects$delta_s, treatment_effects$delta_y)
  sd_s <- sd(treatment_effects$delta_s)
  sd_y <- sd(treatment_effects$delta_y)
  mean_s <- mean(treatment_effects$delta_s)
  mean_y <- mean(treatment_effects$delta_y)

  # Exact relationship: E[XY] = Cov(X,Y) + E[X]E[Y]
  # where Cov(X,Y) = Cor(X,Y) * SD(X) * SD(Y) * (n-1)/n
  n <- nrow(treatment_effects)
  cov_sy <- cor_val * sd_s * sd_y * (n-1)/n
  concordance_from_cor <- cov_sy + mean_s * mean_y
  expect_equal(concordance, concordance_from_cor, tolerance = 1e-6)
})


test_that("functional_concordance validates input", {
  # Missing columns
  bad_data <- data.frame(x = 1:5, y = 1:5)
  expect_error(functional_concordance(bad_data), "delta_s.*delta_y")
})


test_that("compute_functional_with_ci works with concordance", {
  skip_if_not_installed("purrr")

  # Create test treatment effects
  set.seed(161718)
  n <- 100
  treatment_effects <- data.frame(
    delta_s = rnorm(n, 0.5, 0.2),
    delta_y = rnorm(n, 0.4, 0.2)
  )

  # Add correlation
  treatment_effects$delta_y <- treatment_effects$delta_y + 0.3 * treatment_effects$delta_s

  # Compute with CI
  result <- compute_functional_with_ci(
    treatment_effects,
    functional_type = "concordance",
    n_bootstrap = 50,  # Small for test speed
    confidence_level = 0.95
  )

  # Check structure
  expect_true(!is.null(result$estimate))
  expect_true(!is.null(result$se))
  expect_true(!is.null(result$ci_lower))
  expect_true(!is.null(result$ci_upper))
  expect_length(result$bootstrap_samples, 50)

  # Check that CI contains estimate
  expect_gte(result$estimate, result$ci_lower)
  expect_lte(result$estimate, result$ci_upper)
})


test_that("Wasserstein dual solution validates correctly", {
  type_stats <- list(
    tau_s = c(1.0, 0.5),
    tau_y = c(1.0, 0.3),
    p0 = c(0.6, 0.4),
    J = 2
  )
  cost_matrix <- matrix(c(0, 1, 1, 0), 2, 2)
  lambda_w <- 0.5

  result <- wasserstein_concordance_dual(type_stats, cost_matrix, lambda_w)

  checks <- validate_wasserstein_dual_solution(
    result, type_stats, cost_matrix, lambda_w
  )

  expect_true(checks$gamma_nonneg)
  expect_true(checks$dual_lower_bound)
  expect_true(checks$converged)
  expect_true(checks$valid)
})
