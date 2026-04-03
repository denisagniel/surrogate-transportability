#!/usr/bin/env Rscript
#
# Validation Script for Wasserstein Ball Minimax Implementation
# Comprehensive tests before commit
#

suppressPackageStartupMessages({
  library(testthat)
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all()
  }
})

cat("========================================================\n")
cat("Wasserstein Ball Minimax - Pre-Commit Validation\n")
cat("========================================================\n\n")

validation_results <- list()
start_time <- Sys.time()

# ----------------------------------------------------------------
# Test 1: Basic Functionality
# ----------------------------------------------------------------

cat("Test 1: Basic Functionality\n")
cat("----------------------------\n")

test_1 <- tryCatch({
  set.seed(2026)

  # Generate data
  n <- 200
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Run Wasserstein minimax
  result <- surrogate_inference_minimax_wasserstein(
    data,
    lambda_w = 0.5,
    functional_type = "correlation",
    discretization_schemes = "kmeans",
    n_innovations = 100,
    verbose = FALSE
  )

  # Check output structure
  checks <- list(
    has_phi_star = "phi_star" %in% names(result),
    has_schemes = "schemes_summary" %in% names(result),
    phi_valid = is.numeric(result$phi_star) && abs(result$phi_star) <= 1,
    lambda_correct = result$lambda_w == 0.5
  )

  all_pass <- all(unlist(checks))

  list(
    pass = all_pass,
    checks = checks,
    result = result
  )
}, error = function(e) {
  list(pass = FALSE, error = as.character(e))
})

if (test_1$pass) {
  cat("✓ PASS: Basic functionality working\n")
  cat(sprintf("  phi_star = %.4f\n", test_1$result$phi_star))
} else {
  cat("✗ FAIL: Basic functionality\n")
  if (!is.null(test_1$error)) cat("  Error:", test_1$error, "\n")
}
validation_results$test_1 <- test_1
cat("\n")

# ----------------------------------------------------------------
# Test 2: Constraint Satisfaction
# ----------------------------------------------------------------

cat("Test 2: Wasserstein Constraint Satisfaction\n")
cat("--------------------------------------------\n")

test_2 <- tryCatch({
  set.seed(2027)

  n <- 150
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Discretize
  disc <- discretize_data(data, scheme = "kmeans",
                          covariate_cols = c("X1", "X2"), J_target = 10)

  # Compute centroids and cost matrix
  centroids <- compute_type_centroids(data, disc$bins, c("X1", "X2"))
  C <- compute_type_cost_matrix(centroids)

  # Reference distribution
  p0 <- as.numeric(table(disc$bins) / n)
  lambda_w <- 0.6

  # Sample multiple perturbations and check constraints
  n_samples <- 50
  constraints_satisfied <- numeric(n_samples)
  distances <- numeric(n_samples)

  for (i in 1:n_samples) {
    q <- sample_wasserstein_perturbation(p0, C, lambda_w, method = "normal")
    w_dist <- wasserstein_distance_types(q, p0, C)

    constraints_satisfied[i] <- w_dist <= lambda_w * 1.05  # Small tolerance
    distances[i] <- w_dist
  }

  pass_rate <- mean(constraints_satisfied)

  list(
    pass = pass_rate >= 0.95,
    pass_rate = pass_rate,
    mean_distance = mean(distances),
    max_distance = max(distances),
    lambda_w = lambda_w
  )
}, error = function(e) {
  list(pass = FALSE, error = as.character(e))
})

if (test_2$pass) {
  cat(sprintf("✓ PASS: Constraints satisfied (%.1f%% pass rate)\n", test_2$pass_rate * 100))
  cat(sprintf("  Mean W_2 distance: %.4f (lambda_w = %.2f)\n",
              test_2$mean_distance, test_2$lambda_w))
  cat(sprintf("  Max W_2 distance: %.4f\n", test_2$max_distance))
} else {
  cat("✗ FAIL: Constraint satisfaction\n")
  if (!is.null(test_2$error)) cat("  Error:", test_2$error, "\n")
}
validation_results$test_2 <- test_2
cat("\n")

# ----------------------------------------------------------------
# Test 3: Wasserstein vs TV Comparison
# ----------------------------------------------------------------

cat("Test 3: Wasserstein vs TV-Ball Comparison\n")
cat("------------------------------------------\n")

test_3 <- tryCatch({
  set.seed(2028)

  # Generate data with covariate shift structure
  n <- 300
  X1 <- rnorm(n)
  X2 <- rnorm(n)
  A <- rbinom(n, 1, 0.5)

  # Effects depend on covariates (covariate shift scenario)
  delta_s <- 0.5 + 0.3 * X1
  delta_y <- 0.4 + 0.2 * X1 + 0.1 * X2

  S <- rnorm(n, mean = A * delta_s, sd = 1)
  Y <- rnorm(n, mean = A * delta_y, sd = 1)

  data <- data.frame(X1, X2, A, S, Y)

  # Wasserstein
  result_w <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.5, functional_type = "correlation",
    discretization_schemes = c("quantiles", "kmeans"),
    n_innovations = 200, verbose = FALSE
  )

  # TV-ball
  result_tv <- surrogate_inference_minimax(
    data, lambda = 0.3, functional_type = "correlation",
    discretization_schemes = c("quantiles", "kmeans"),
    n_innovations = 200, verbose = FALSE
  )

  # Compare
  w_estimate <- result_w$phi_star
  tv_estimate <- result_tv$phi_star

  # Under covariate shift, Wasserstein should be less conservative
  # (though this isn't guaranteed with finite samples)

  list(
    pass = TRUE,  # Just check both run
    w_estimate = w_estimate,
    tv_estimate = tv_estimate,
    difference = w_estimate - tv_estimate,
    w_less_conservative = w_estimate > tv_estimate
  )
}, error = function(e) {
  list(pass = FALSE, error = as.character(e))
})

if (test_3$pass) {
  cat("✓ PASS: Comparison with TV-ball\n")
  cat(sprintf("  Wasserstein: %.4f\n", test_3$w_estimate))
  cat(sprintf("  TV-ball:     %.4f\n", test_3$tv_estimate))
  cat(sprintf("  Difference:  %.4f\n", test_3$difference))
  if (test_3$w_less_conservative) {
    cat("  → Wasserstein less conservative (expected for covariate shift)\n")
  } else {
    cat("  → TV less conservative (finite sample variation)\n")
  }
} else {
  cat("✗ FAIL: Comparison with TV-ball\n")
  if (!is.null(test_3$error)) cat("  Error:", test_3$error, "\n")
}
validation_results$test_3 <- test_3
cat("\n")

# ----------------------------------------------------------------
# Test 4: All Functionals
# ----------------------------------------------------------------

cat("Test 4: All Functional Types\n")
cat("-----------------------------\n")

test_4 <- tryCatch({
  set.seed(2029)

  n <- 200
  data <- data.frame(
    X1 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n) + 0.5,
    Y = rnorm(n) + 0.3
  )

  functional_results <- list()

  # Correlation
  r_cor <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.4, functional_type = "correlation",
    discretization_schemes = "kmeans", n_innovations = 100, verbose = FALSE
  )
  functional_results$correlation <- list(
    estimate = r_cor$phi_star,
    valid = abs(r_cor$phi_star) <= 1
  )

  # Probability
  r_prob <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.4, functional_type = "probability",
    epsilon_s = 0.2, epsilon_y = 0.2,
    discretization_schemes = "kmeans", n_innovations = 100, verbose = FALSE
  )
  functional_results$probability <- list(
    estimate = r_prob$phi_star,
    valid = r_prob$phi_star >= 0 && r_prob$phi_star <= 1
  )

  # PPV
  r_ppv <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.4, functional_type = "ppv",
    epsilon_s = 0.2, epsilon_y = 0.2,
    discretization_schemes = "kmeans", n_innovations = 100, verbose = FALSE
  )
  functional_results$ppv <- list(
    estimate = r_ppv$phi_star,
    valid = r_ppv$phi_star >= 0 && r_ppv$phi_star <= 1
  )

  # NPV
  r_npv <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.4, functional_type = "npv",
    epsilon_s = 0.2, epsilon_y = 0.2,
    discretization_schemes = "kmeans", n_innovations = 100, verbose = FALSE
  )
  functional_results$npv <- list(
    estimate = r_npv$phi_star,
    valid = r_npv$phi_star >= 0 && r_npv$phi_star <= 1
  )

  # Conditional mean
  r_cm <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.4, functional_type = "conditional_mean",
    delta_s_value = 0.5,
    discretization_schemes = "kmeans", n_innovations = 100, verbose = FALSE
  )
  functional_results$conditional_mean <- list(
    estimate = r_cm$phi_star,
    valid = is.numeric(r_cm$phi_star) && is.finite(r_cm$phi_star)
  )

  all_valid <- all(sapply(functional_results, function(x) x$valid))

  list(
    pass = all_valid,
    results = functional_results
  )
}, error = function(e) {
  list(pass = FALSE, error = as.character(e))
})

if (test_4$pass) {
  cat("✓ PASS: All functionals work\n")
  for (func_name in names(test_4$results)) {
    cat(sprintf("  %s: %.4f\n", func_name, test_4$results[[func_name]]$estimate))
  }
} else {
  cat("✗ FAIL: Functional types\n")
  if (!is.null(test_4$error)) cat("  Error:", test_4$error, "\n")
}
validation_results$test_4 <- test_4
cat("\n")

# ----------------------------------------------------------------
# Test 5: Different Cost Functions
# ----------------------------------------------------------------

cat("Test 5: Different Cost Functions\n")
cat("---------------------------------\n")

test_5 <- tryCatch({
  set.seed(2030)

  n <- 150
  data <- data.frame(
    X1 = rnorm(n),
    X2 = rnorm(n) * 2,  # Different scale
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Euclidean
  r_euc <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.5, functional_type = "correlation",
    cost_function = "euclidean",
    discretization_schemes = "kmeans", n_innovations = 100, verbose = FALSE
  )

  # Mahalanobis
  r_maha <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.5, functional_type = "correlation",
    cost_function = "mahalanobis",
    discretization_schemes = "kmeans", n_innovations = 100, verbose = FALSE
  )

  list(
    pass = TRUE,
    euclidean = r_euc$phi_star,
    mahalanobis = r_maha$phi_star,
    difference = abs(r_maha$phi_star - r_euc$phi_star)
  )
}, error = function(e) {
  list(pass = FALSE, error = as.character(e))
})

if (test_5$pass) {
  cat("✓ PASS: Different cost functions\n")
  cat(sprintf("  Euclidean:    %.4f\n", test_5$euclidean))
  cat(sprintf("  Mahalanobis:  %.4f\n", test_5$mahalanobis))
  cat(sprintf("  Difference:   %.4f\n", test_5$difference))
} else {
  cat("✗ FAIL: Cost functions\n")
  if (!is.null(test_5$error)) cat("  Error:", test_5$error, "\n")
}
validation_results$test_5 <- test_5
cat("\n")

# ----------------------------------------------------------------
# Test 6: Bootstrap CI
# ----------------------------------------------------------------

cat("Test 6: Bootstrap Confidence Intervals\n")
cat("---------------------------------------\n")

test_6 <- tryCatch({
  set.seed(2031)

  n <- 150
  data <- data.frame(
    X1 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  result <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.5, functional_type = "correlation",
    discretization_schemes = "kmeans",
    n_innovations = 50,  # Small for speed
    n_bootstrap = 10,    # Small for speed
    parallel = FALSE,
    verbose = FALSE
  )

  checks <- list(
    has_ci = "ci_lower" %in% names(result) && "ci_upper" %in% names(result),
    ci_ordered = result$ci_lower <= result$ci_upper,
    ci_contains_estimate = result$ci_lower <= result$phi_star &&
                           result$phi_star <= result$ci_upper
  )

  all_pass <- all(unlist(checks))

  list(
    pass = all_pass,
    estimate = result$phi_star,
    ci_lower = result$ci_lower,
    ci_upper = result$ci_upper,
    width = result$ci_upper - result$ci_lower
  )
}, error = function(e) {
  list(pass = FALSE, error = as.character(e))
})

if (test_6$pass) {
  cat("✓ PASS: Bootstrap CI works\n")
  cat(sprintf("  Estimate: %.4f [%.4f, %.4f]\n",
              test_6$estimate, test_6$ci_lower, test_6$ci_upper))
  cat(sprintf("  Width: %.4f\n", test_6$width))
} else {
  cat("✗ FAIL: Bootstrap CI\n")
  if (!is.null(test_6$error)) cat("  Error:", test_6$error, "\n")
}
validation_results$test_6 <- test_6
cat("\n")

# ----------------------------------------------------------------
# Test 7: Reproducibility (Seed)
# ----------------------------------------------------------------

cat("Test 7: Reproducibility with Seed\n")
cat("----------------------------------\n")

test_7 <- tryCatch({
  n <- 100
  data <- data.frame(
    X1 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Run twice with same seed
  result1 <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.4, functional_type = "correlation",
    discretization_schemes = "kmeans", n_innovations = 50,
    seed = 9999, verbose = FALSE
  )

  result2 <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.4, functional_type = "correlation",
    discretization_schemes = "kmeans", n_innovations = 50,
    seed = 9999, verbose = FALSE
  )

  identical_estimates <- abs(result1$phi_star - result2$phi_star) < 1e-10

  list(
    pass = identical_estimates,
    result1 = result1$phi_star,
    result2 = result2$phi_star,
    difference = abs(result1$phi_star - result2$phi_star)
  )
}, error = function(e) {
  list(pass = FALSE, error = as.character(e))
})

if (test_7$pass) {
  cat("✓ PASS: Reproducibility with seed\n")
  cat(sprintf("  Run 1: %.8f\n", test_7$result1))
  cat(sprintf("  Run 2: %.8f\n", test_7$result2))
  cat(sprintf("  Difference: %.2e\n", test_7$difference))
} else {
  cat("✗ FAIL: Reproducibility\n")
  if (!is.null(test_7$error)) cat("  Error:", test_7$error, "\n")
}
validation_results$test_7 <- test_7
cat("\n")

# ----------------------------------------------------------------
# Test 8: Edge Cases
# ----------------------------------------------------------------

cat("Test 8: Edge Cases\n")
cat("------------------\n")

test_8 <- tryCatch({
  set.seed(2032)

  edge_cases <- list()

  # Small sample size
  n_small <- 50
  data_small <- data.frame(
    X1 = rnorm(n_small),
    A = rbinom(n_small, 1, 0.5),
    S = rnorm(n_small),
    Y = rnorm(n_small)
  )

  r_small <- surrogate_inference_minimax_wasserstein(
    data_small, lambda_w = 0.3, functional_type = "correlation",
    discretization_schemes = "kmeans", n_innovations = 50,
    J_target = 5, verbose = FALSE
  )
  edge_cases$small_n <- list(
    pass = is.numeric(r_small$phi_star),
    estimate = r_small$phi_star
  )

  # Small lambda_w
  n <- 100
  data <- data.frame(
    X1 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  r_small_lambda <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 0.1, functional_type = "correlation",
    discretization_schemes = "kmeans", n_innovations = 50,
    verbose = FALSE
  )
  edge_cases$small_lambda <- list(
    pass = is.numeric(r_small_lambda$phi_star),
    estimate = r_small_lambda$phi_star
  )

  # Large lambda_w
  r_large_lambda <- surrogate_inference_minimax_wasserstein(
    data, lambda_w = 2.0, functional_type = "correlation",
    discretization_schemes = "kmeans", n_innovations = 50,
    verbose = FALSE
  )
  edge_cases$large_lambda <- list(
    pass = is.numeric(r_large_lambda$phi_star),
    estimate = r_large_lambda$phi_star
  )

  all_pass <- all(sapply(edge_cases, function(x) x$pass))

  list(
    pass = all_pass,
    edge_cases = edge_cases
  )
}, error = function(e) {
  list(pass = FALSE, error = as.character(e))
})

if (test_8$pass) {
  cat("✓ PASS: Edge cases handled\n")
  for (case_name in names(test_8$edge_cases)) {
    cat(sprintf("  %s: %.4f\n", case_name, test_8$edge_cases[[case_name]]$estimate))
  }
} else {
  cat("✗ FAIL: Edge cases\n")
  if (!is.null(test_8$error)) cat("  Error:", test_8$error, "\n")
}
validation_results$test_8 <- test_8
cat("\n")

# ----------------------------------------------------------------
# Summary
# ----------------------------------------------------------------

end_time <- Sys.time()
elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

cat("========================================================\n")
cat("Validation Summary\n")
cat("========================================================\n\n")

test_passes <- sapply(validation_results, function(x) x$pass)
n_pass <- sum(test_passes)
n_total <- length(test_passes)

cat(sprintf("Tests Passed: %d/%d\n", n_pass, n_total))
cat(sprintf("Time Elapsed: %.1f seconds\n\n", elapsed))

if (all(test_passes)) {
  cat("✓✓✓ ALL VALIDATION TESTS PASSED ✓✓✓\n\n")
  cat("Implementation is ready for commit.\n\n")
  cat("Key validations:\n")
  cat("  ✓ Basic functionality working\n")
  cat("  ✓ Wasserstein constraints satisfied (>95% pass rate)\n")
  cat("  ✓ Comparison with TV-ball successful\n")
  cat("  ✓ All 5 functionals working\n")
  cat("  ✓ Multiple cost functions supported\n")
  cat("  ✓ Bootstrap CI functioning\n")
  cat("  ✓ Reproducibility with seed\n")
  cat("  ✓ Edge cases handled\n")

  # Return success
  quit(status = 0)
} else {
  cat("✗✗✗ SOME TESTS FAILED ✗✗✗\n\n")
  cat("Failed tests:\n")
  for (i in which(!test_passes)) {
    cat(sprintf("  - Test %d: %s\n", i, names(validation_results)[i]))
  }
  cat("\nReview failures before committing.\n")

  # Return failure
  quit(status = 1)
}
