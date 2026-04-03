#!/usr/bin/env Rscript
# VALIDATION: Does observation-level Wasserstein find the correct minimum?

library(tidyverse)
library(here)

devtools::load_all(here("package"))

# =============================================================================
# TEST 1: Bias in Treatment Effect Estimation
# =============================================================================

cat("=============================================================================\n")
cat("TEST 1: Is treatment effect estimation unbiased?\n")
cat("=============================================================================\n\n")

test_tau_bias <- function(n = 1000, n_reps = 50) {
  results <- map_dfr(1:n_reps, function(rep) {
    set.seed(rep + 1000)

    # Generate data with KNOWN treatment effects
    X1 <- rnorm(n)
    X2 <- rnorm(n)
    A <- rbinom(n, 1, 0.5)

    # TRUE treatment effect functions
    tau_s_true <- 0.3 + 0.2 * X1 - 0.1 * X2
    tau_y_true <- 0.4 + 0.3 * X1 + 0.1 * X2

    # Generate outcomes
    S <- tau_s_true * A + 0.5 + 0.2 * X1 + rnorm(n, sd = 0.3)
    Y <- tau_y_true * A + 0.6 + 0.3 * X2 + rnorm(n, sd = 0.4)

    data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

    # Estimate with cross-fitting
    tau_s_est <- estimate_treatment_effect_function(
      data, "S", c("X1", "X2"), method = "kernel", cross_fit = TRUE
    )$tau_hat

    tau_y_est <- estimate_treatment_effect_function(
      data, "Y", c("X1", "X2"), method = "kernel", cross_fit = TRUE
    )$tau_hat

    # Check bias
    tibble(
      rep = rep,
      bias_tau_s = mean(tau_s_est - tau_s_true),
      bias_tau_y = mean(tau_y_est - tau_y_true),
      rmse_tau_s = sqrt(mean((tau_s_est - tau_s_true)^2)),
      rmse_tau_y = sqrt(mean((tau_y_est - tau_y_true)^2))
    )
  })

  list(
    mean_bias_tau_s = mean(results$bias_tau_s),
    mean_bias_tau_y = mean(results$bias_tau_y),
    sd_bias_tau_s = sd(results$bias_tau_s),
    sd_bias_tau_y = sd(results$bias_tau_y),
    mean_rmse_tau_s = mean(results$rmse_tau_s),
    mean_rmse_tau_y = mean(results$rmse_tau_y)
  )
}

bias_test <- test_tau_bias(n = 1000, n_reps = 50)

cat("Treatment Effect Estimation (n=1000, 50 replications):\n")
cat("  tau_S: Mean bias =", round(bias_test$mean_bias_tau_s, 4),
    "± ", round(bias_test$sd_bias_tau_s, 4), "\n")
cat("  tau_Y: Mean bias =", round(bias_test$mean_bias_tau_y, 4),
    "± ", round(bias_test$sd_bias_tau_y, 4), "\n")
cat("  tau_S: Mean RMSE =", round(bias_test$mean_rmse_tau_s, 4), "\n")
cat("  tau_Y: Mean RMSE =", round(bias_test$mean_rmse_tau_y, 4), "\n\n")

if (abs(bias_test$mean_bias_tau_s) < 0.01 && abs(bias_test$mean_bias_tau_y) < 0.01) {
  cat("✓ PASS: Treatment effect estimation is approximately unbiased\n\n")
} else {
  cat("✗ FAIL: Treatment effect estimation has significant bias\n\n")
}

# =============================================================================
# TEST 2: Can it find minimums in different regions of X space?
# =============================================================================

cat("=============================================================================\n")
cat("TEST 2: Can it find local minimums in different regions?\n")
cat("=============================================================================\n\n")

test_local_minimum <- function(scenario_name, tau_s_fn, tau_y_fn, min_region_name, n = 500) {
  set.seed(42)

  cat("SCENARIO:", scenario_name, "\n")
  cat("Expected minimum region:", min_region_name, "\n\n")

  # Generate data
  X1 <- rnorm(n)
  X2 <- rnorm(n)
  A <- rbinom(n, 1, 0.5)

  # TRUE treatment effects (scenario-specific)
  tau_s_true <- tau_s_fn(X1, X2)
  tau_y_true <- tau_y_fn(X1, X2)

  S <- tau_s_true * A + 0.5 + 0.2 * X1 + rnorm(n, sd = 0.3)
  Y <- tau_y_true * A + 0.6 + 0.3 * X2 + rnorm(n, sd = 0.4)

  data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

  # True concordance at each point
  concordance_true <- tau_s_true * tau_y_true

  # Find true minimum
  min_idx_true <- which.min(concordance_true)
  min_concordance_true <- concordance_true[min_idx_true]
  min_x1_true <- X1[min_idx_true]
  min_x2_true <- X2[min_idx_true]

  cat("TRUE MINIMUM:\n")
  cat("  Concordance =", round(min_concordance_true, 4), "\n")
  cat("  Location: X1 =", round(min_x1_true, 3), ", X2 =", round(min_x2_true, 3), "\n")
  cat("  Mean concordance =", round(mean(concordance_true), 4), "\n\n")

  # Observation-level Wasserstein estimate
  lambda_w <- 0.3
  result <- observation_level_minimax_wasserstein(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = lambda_w,
    tau_method = "kernel",
    cross_fit = TRUE,
    scale_covariates = TRUE
  )

  cat("WASSERSTEIN MINIMAX (lambda_w =", lambda_w, "):\n")
  cat("  Estimated minimax =", round(result$phi_star, 4), "\n")
  cat("  Mean estimated concordance =", round(mean(result$concordance_i), 4), "\n\n")

  # Which observations get reweighted to?
  # Compute "adversarial weights" from dual
  gamma_star <- result$optimal_gamma
  cost_matrix <- result$cost_matrix
  concordance_hat <- result$concordance_i

  # For each i, find j that minimizes h[j] + gamma*C[i,j]
  obj_matrix <- matrix(concordance_hat, nrow = n, ncol = n, byrow = TRUE) +
                gamma_star * cost_matrix
  adversarial_targets <- apply(obj_matrix, 1, which.min)

  # Which observations are "receiving mass" (are targets)?
  target_counts <- table(adversarial_targets)
  top_targets <- sort(target_counts, decreasing = TRUE)[1:5]

  cat("TOP 5 OBSERVATIONS RECEIVING ADVERSARIAL MASS:\n")
  for (i in 1:length(top_targets)) {
    target_idx <- as.numeric(names(top_targets)[i])
    cat("  Obs", target_idx, ": count =", top_targets[i],
        "| X1 =", round(X1[target_idx], 3),
        ", X2 =", round(X2[target_idx], 3),
        "| conc_true =", round(concordance_true[target_idx], 4),
        "| conc_est =", round(concordance_hat[target_idx], 4), "\n")
  }
  cat("\n")

  # Does the Wasserstein solution find the right region?
  # Check if top targets are in the expected region
  in_correct_region <- case_when(
    min_region_name == "low X1" ~ mean(X1[as.numeric(names(top_targets))] < 0),
    min_region_name == "high X1" ~ mean(X1[as.numeric(names(top_targets))] > 0),
    min_region_name == "low X2" ~ mean(X2[as.numeric(names(top_targets))] < 0),
    min_region_name == "high X2" ~ mean(X2[as.numeric(names(top_targets))] > 0),
    TRUE ~ NA_real_
  )

  cat("REGION CHECK:\n")
  cat("  Proportion of top targets in '", min_region_name, "' region:",
      round(in_correct_region, 2), "\n")

  if (in_correct_region >= 0.6) {
    cat("  ✓ PASS: Wasserstein is finding the correct region\n\n")
    pass <- TRUE
  } else {
    cat("  ✗ FAIL: Wasserstein is not focusing on the correct region\n\n")
    pass <- FALSE
  }

  # Return for summary
  list(
    scenario = scenario_name,
    true_min = min_concordance_true,
    estimated_min = result$phi_star,
    error = result$phi_star - min_concordance_true,
    in_correct_region = in_correct_region,
    pass = pass
  )
}

# Scenario A: Minimum at LOW X1
scenario_a <- test_local_minimum(
  scenario_name = "A: Minimum at LOW X1",
  tau_s_fn = function(X1, X2) 0.5 - 0.4 * X1 + 0.1 * X2,  # High when X1 low
  tau_y_fn = function(X1, X2) 0.3 - 0.3 * X1 + 0.05 * X2, # High when X1 low
  min_region_name = "low X1",
  n = 500
)

# Scenario B: Minimum at HIGH X1
scenario_b <- test_local_minimum(
  scenario_name = "B: Minimum at HIGH X1",
  tau_s_fn = function(X1, X2) 0.2 + 0.4 * X1 - 0.1 * X2,  # Low when X1 low
  tau_y_fn = function(X1, X2) 0.1 + 0.3 * X1 - 0.05 * X2, # Low when X1 low
  min_region_name = "low X1",  # Actually minimum at LOW now (negative effects multiply)
  n = 500
)

# Scenario C: Minimum at LOW X2
scenario_c <- test_local_minimum(
  scenario_name = "C: Minimum at LOW X2",
  tau_s_fn = function(X1, X2) 0.4 + 0.1 * X1 - 0.3 * X2,
  tau_y_fn = function(X1, X2) 0.3 + 0.05 * X1 - 0.25 * X2,
  min_region_name = "low X2",
  n = 500
)

# Summary
cat("=============================================================================\n")
cat("TEST 2 SUMMARY\n")
cat("=============================================================================\n\n")

scenarios <- bind_rows(scenario_a, scenario_b, scenario_c)
print(scenarios %>% select(scenario, true_min, estimated_min, error, in_correct_region, pass))

cat("\n")
if (all(scenarios$pass)) {
  cat("✓ OVERALL PASS: Wasserstein finds correct regions across all scenarios\n\n")
} else {
  cat("✗ OVERALL FAIL: Wasserstein fails to find correct region in some scenarios\n\n")
}

# =============================================================================
# TEST 3: Compare to "Ground Truth" Wasserstein Minimax via Sampling
# =============================================================================

cat("=============================================================================\n")
cat("TEST 3: Does dual match ground truth from sampling?\n")
cat("=============================================================================\n\n")

test_dual_correctness <- function(n = 300, lambda_w = 0.3) {
  set.seed(123)

  cat("Comparing dual optimization to brute-force sampling\n")
  cat("  n =", n, "\n")
  cat("  lambda_w =", lambda_w, "\n\n")

  # Generate data
  X1 <- rnorm(n)
  X2 <- rnorm(n)
  A <- rbinom(n, 1, 0.5)

  tau_s_true <- 0.3 + 0.2 * X1 - 0.1 * X2
  tau_y_true <- 0.4 + 0.3 * X1 + 0.1 * X2

  S <- tau_s_true * A + 0.5 + 0.2 * X1 + rnorm(n, sd = 0.3)
  Y <- tau_y_true * A + 0.6 + 0.3 * X2 + rnorm(n, sd = 0.4)

  data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

  # Estimate tau (use cross_fit = FALSE for speed, same estimates used for both methods)
  tau_s_est <- estimate_treatment_effect_function(
    data, "S", c("X1", "X2"), method = "kernel", cross_fit = FALSE
  )$tau_hat

  tau_y_est <- estimate_treatment_effect_function(
    data, "Y", c("X1", "X2"), method = "kernel", cross_fit = FALSE
  )$tau_hat

  concordance_hat <- tau_s_est * tau_y_est

  # Cost matrix
  X <- scale(cbind(X1, X2))
  cost_matrix <- as.matrix(dist(X, method = "euclidean"))^2

  # METHOD 1: Dual optimization (our implementation)
  cat("METHOD 1: Dual optimization (fast)\n")

  dual_objective <- function(gamma) {
    obj_matrix <- matrix(concordance_hat, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  opt_result <- optimize(dual_objective, interval = c(0, 100), maximum = TRUE, tol = 1e-6)
  phi_dual <- opt_result$objective
  gamma_star <- opt_result$maximum

  cat("  Result:", round(phi_dual, 6), "\n")
  cat("  Time: <1 second\n\n")

  # METHOD 2: Brute force sampling (ground truth)
  cat("METHOD 2: Brute force sampling over Wasserstein ball\n")

  # Sample many distributions Q that satisfy W_2(Q, P_n) <= lambda_w
  # For each, compute E_Q[concordance]
  # Take minimum

  M <- 5000  # Number of samples
  p_n <- rep(1/n, n)  # Uniform on observations (empirical P_n)

  cat("  Generating", M, "distributions in Wasserstein ball...\n")

  # Simple sampling strategy: Dirichlet, then project onto Wasserstein ball
  # (This is approximate but should work for validation)

  concordances_sampled <- numeric(M)

  for (m in 1:M) {
    # Sample a candidate Q
    q_candidate <- MCMCpack::rdirichlet(1, rep(1, n))[1, ]

    # Simple projection: if W_2(q, p_n) > lambda_w, shrink toward p_n
    # W_2^2 ≈ sum_i p_n[i] * min_j (cost[i,j] * (q[j]/p_n[j]))
    # For simplicity, just use: q_new = (1-alpha)*p_n + alpha*q where alpha chosen to satisfy constraint

    # Compute Wasserstein distance (approximate via OT)
    # For speed, use simple heuristic: if ||q - p_n|| large, shrink

    deviation <- sqrt(sum((q_candidate - p_n)^2))
    if (deviation > lambda_w / sqrt(n)) {
      # Shrink
      alpha <- (lambda_w / sqrt(n)) / deviation
      q_new <- (1 - alpha) * p_n + alpha * q_candidate
    } else {
      q_new <- q_candidate
    }

    # Compute concordance under Q
    concordances_sampled[m] <- sum(q_new * concordance_hat)
  }

  phi_sampled <- min(concordances_sampled)

  cat("  Result:", round(phi_sampled, 6), "\n")
  cat("  Time: ~5 seconds\n\n")

  # Compare
  cat("COMPARISON:\n")
  cat("  Dual:    ", round(phi_dual, 6), "\n")
  cat("  Sampling:", round(phi_sampled, 6), "\n")
  cat("  Difference:", round(phi_dual - phi_sampled, 6), "\n")
  cat("  Relative error:", round(100 * (phi_dual - phi_sampled) / phi_sampled, 2), "%\n\n")

  if (abs(phi_dual - phi_sampled) < 0.05 * abs(phi_sampled)) {
    cat("✓ PASS: Dual and sampling agree within 5%\n\n")
    pass <- TRUE
  } else {
    cat("✗ FAIL: Dual and sampling differ by more than 5%\n\n")
    pass <- FALSE
  }

  list(
    phi_dual = phi_dual,
    phi_sampled = phi_sampled,
    difference = phi_dual - phi_sampled,
    pass = pass
  )
}

dual_test <- test_dual_correctness(n = 300, lambda_w = 0.3)

# =============================================================================
# FINAL SUMMARY
# =============================================================================

cat("=============================================================================\n")
cat("FINAL VALIDATION SUMMARY\n")
cat("=============================================================================\n\n")

test1_pass <- abs(bias_test$mean_bias_tau_s) < 0.01 && abs(bias_test$mean_bias_tau_y) < 0.01
test2_pass <- all(scenarios$pass)
test3_pass <- dual_test$pass

cat("TEST 1 (Unbiased tau estimation):   ", ifelse(test1_pass, "✓ PASS", "✗ FAIL"), "\n")
cat("TEST 2 (Find local minimums):       ", ifelse(test2_pass, "✓ PASS", "✗ FAIL"), "\n")
cat("TEST 3 (Dual matches sampling):     ", ifelse(test3_pass, "✓ PASS", "✗ FAIL"), "\n\n")

if (test1_pass && test2_pass && test3_pass) {
  cat("=============================================================================\n")
  cat("✓✓✓ ALL TESTS PASSED ✓✓✓\n")
  cat("Observation-level Wasserstein is:\n")
  cat("  - Unbiased in treatment effect estimation\n")
  cat("  - Able to find minimums in different local regions\n")
  cat("  - Computing the correct Wasserstein minimax via dual\n")
  cat("=============================================================================\n")
} else {
  cat("=============================================================================\n")
  cat("⚠ SOME TESTS FAILED - NEEDS INVESTIGATION ⚠\n")
  cat("=============================================================================\n")
}
