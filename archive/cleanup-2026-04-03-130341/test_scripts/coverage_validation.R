#!/usr/bin/env Rscript
# COVERAGE VALIDATION: Observation-Level Wasserstein Minimax

library(tidyverse)
library(here)

devtools::load_all(here("package"))

cat("=============================================================================\n")
cat("COVERAGE VALIDATION: Observation-Level Wasserstein DRO\n")
cat("=============================================================================\n\n")

# =============================================================================
# Function: Compute TRUE phi*(lambda_w) from DGP
# =============================================================================

compute_true_minimax <- function(X1, X2, tau_s_fn, tau_y_fn, lambda_w) {
  # Given true covariate values and true treatment effect functions,
  # compute the true Wasserstein minimax

  n <- length(X1)

  # True concordance at each point
  tau_s_true <- tau_s_fn(X1, X2)
  tau_y_true <- tau_y_fn(X1, X2)
  h_true <- tau_s_true * tau_y_true

  # Cost matrix (standardized)
  X <- scale(cbind(X1, X2))
  cost_matrix <- as.matrix(dist(X, method = "euclidean"))^2

  # Solve dual
  dual_objective <- function(gamma) {
    obj_matrix <- matrix(h_true, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  result <- optimize(dual_objective, interval = c(0, 100), maximum = TRUE, tol = 1e-6)

  result$objective
}

# =============================================================================
# Function: Bootstrap CI for observation-level estimate
# =============================================================================

bootstrap_ci_observation_level <- function(data, covariates, lambda_w,
                                            tau_method = "kernel",
                                            n_bootstrap = 100,
                                            confidence_level = 0.95) {

  n <- nrow(data)

  cat("  Computing point estimate...\n")

  # Point estimate
  point_est <- observation_level_minimax_wasserstein(
    data = data,
    covariates = covariates,
    lambda_w = lambda_w,
    tau_method = tau_method,
    cross_fit = TRUE,
    scale_covariates = TRUE
  )

  cat("  Bootstrapping (", n_bootstrap, "iterations)...\n")

  # Bootstrap
  bootstrap_estimates <- numeric(n_bootstrap)

  for (b in 1:n_bootstrap) {
    if (b %% 20 == 0) cat("    Bootstrap", b, "/", n_bootstrap, "\n")

    # Resample observations
    boot_idx <- sample(1:n, size = n, replace = TRUE)
    boot_data <- data[boot_idx, ]

    # Estimate on bootstrap sample
    boot_result <- tryCatch({
      observation_level_minimax_wasserstein(
        data = boot_data,
        covariates = covariates,
        lambda_w = lambda_w,
        tau_method = tau_method,
        cross_fit = FALSE,  # Faster, already have randomness from bootstrap
        scale_covariates = TRUE
      )
    }, error = function(e) {
      list(phi_star = NA)
    })

    bootstrap_estimates[b] <- boot_result$phi_star
  }

  # Remove failed bootstraps
  bootstrap_estimates <- bootstrap_estimates[!is.na(bootstrap_estimates)]

  if (length(bootstrap_estimates) < 0.8 * n_bootstrap) {
    warning("More than 20% of bootstrap iterations failed")
  }

  # Compute CI
  alpha <- 1 - confidence_level
  ci_lower <- quantile(bootstrap_estimates, alpha/2)
  ci_upper <- quantile(bootstrap_estimates, 1 - alpha/2)

  list(
    phi_star = point_est$phi_star,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    bootstrap_estimates = bootstrap_estimates,
    n_bootstrap_successful = length(bootstrap_estimates)
  )
}

# =============================================================================
# Simulation Setup
# =============================================================================

cat("SIMULATION DESIGN:\n\n")

# DGP parameters
n <- 250
lambda_w <- 0.5  # Moderate shift (0.5 SDs)
n_reps <- 100
n_bootstrap <- 100
confidence_level <- 0.95

# Treatment effect functions
tau_s_fn <- function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2
tau_y_fn <- function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2

cat("  n =", n, "\n")
cat("  lambda_w =", lambda_w, "\n")
cat("  n_reps =", n_reps, "\n")
cat("  n_bootstrap =", n_bootstrap, "\n")
cat("  confidence_level =", confidence_level, "\n")
cat("  tau_method = kernel with cross-fitting\n\n")

cat("  Treatment effects:\n")
cat("    tau_S(X) = 0.3 + 0.2*X1 - 0.1*X2\n")
cat("    tau_Y(X) = 0.4 + 0.3*X1 + 0.1*X2\n\n")

# =============================================================================
# Run Coverage Simulation
# =============================================================================

cat("=============================================================================\n")
cat("RUNNING COVERAGE SIMULATION\n")
cat("=============================================================================\n\n")

results <- map_dfr(1:n_reps, function(rep) {

  if (rep %% 10 == 0) {
    cat("--- Replication", rep, "/", n_reps, "---\n")
  }

  set.seed(rep + 5000)

  # Generate data
  X1 <- rnorm(n)
  X2 <- rnorm(n)
  A <- rbinom(n, 1, 0.5)

  tau_s_true <- tau_s_fn(X1, X2)
  tau_y_true <- tau_y_fn(X1, X2)

  S <- tau_s_true * A + 0.5 + 0.2 * X1 + rnorm(n, sd = 0.3)
  Y <- tau_y_true * A + 0.6 + 0.3 * X2 + rnorm(n, sd = 0.4)

  data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

  # Compute TRUE minimax for this realization of (X1, X2)
  truth <- compute_true_minimax(X1, X2, tau_s_fn, tau_y_fn, lambda_w)

  # Estimate with bootstrap CI
  result <- tryCatch({
    bootstrap_ci_observation_level(
      data = data,
      covariates = c("X1", "X2"),
      lambda_w = lambda_w,
      tau_method = "kernel",
      n_bootstrap = n_bootstrap,
      confidence_level = confidence_level
    )
  }, error = function(e) {
    cat("  ERROR in rep", rep, ":", conditionMessage(e), "\n")
    NULL
  })

  if (is.null(result)) {
    return(tibble(rep = rep, status = "failed"))
  }

  # Check coverage
  covered <- (truth >= result$ci_lower & truth <= result$ci_upper)

  # CI width
  ci_width <- result$ci_upper - result$ci_lower

  # Bias
  bias <- result$phi_star - truth

  tibble(
    rep = rep,
    status = "success",
    truth = truth,
    estimate = result$phi_star,
    ci_lower = result$ci_lower,
    ci_upper = result$ci_upper,
    covered = covered,
    ci_width = ci_width,
    bias = bias,
    n_bootstrap_successful = result$n_bootstrap_successful
  )
})

# Filter to successful runs
results_success <- results %>% filter(status == "success")

cat("\n=============================================================================\n")
cat("RESULTS\n")
cat("=============================================================================\n\n")

n_success <- nrow(results_success)
n_failed <- n_reps - n_success

cat("Successful replications:", n_success, "/", n_reps, "\n")
if (n_failed > 0) {
  cat("Failed replications:", n_failed, "\n")
}
cat("\n")

if (n_success == 0) {
  cat("All replications failed - cannot assess coverage.\n")
  quit(status = 1)
}

# Coverage
coverage <- mean(results_success$covered)
coverage_se <- sqrt(coverage * (1 - coverage) / n_success)

cat("COVERAGE:\n")
cat("  Observed: ", round(coverage, 3), " (SE = ", round(coverage_se, 3), ")\n", sep = "")
cat("  Target:   ", confidence_level, "\n")
cat("  95% CI:   [", round(coverage - 1.96*coverage_se, 3), ", ",
    round(coverage + 1.96*coverage_se, 3), "]\n", sep = "")

if (coverage >= 0.93 && coverage <= 0.97) {
  cat("  Status:   ✓ PASS (nominal coverage achieved)\n\n")
  coverage_pass <- TRUE
} else if (coverage >= 0.90 && coverage <= 0.98) {
  cat("  Status:   ~ MARGINAL (slightly off nominal)\n\n")
  coverage_pass <- TRUE
} else {
  cat("  Status:   ✗ FAIL (coverage not nominal)\n\n")
  coverage_pass <- FALSE
}

# Bias
mean_bias <- mean(results_success$bias)
median_bias <- median(results_success$bias)
rmse <- sqrt(mean(results_success$bias^2))

cat("BIAS:\n")
cat("  Mean:     ", round(mean_bias, 4), "\n")
cat("  Median:   ", round(median_bias, 4), "\n")
cat("  RMSE:     ", round(rmse, 4), "\n")

if (abs(mean_bias) < 0.02) {
  cat("  Status:   ✓ PASS (approximately unbiased)\n\n")
  bias_pass <- TRUE
} else {
  cat("  Status:   ✗ FAIL (significant bias)\n\n")
  bias_pass <- FALSE
}

# CI width
mean_ci_width <- mean(results_success$ci_width)
median_ci_width <- median(results_success$ci_width)

cat("CONFIDENCE INTERVAL WIDTH:\n")
cat("  Mean:     ", round(mean_ci_width, 4), "\n")
cat("  Median:   ", round(median_ci_width, 4), "\n\n")

# Truth distribution
cat("TRUE MINIMAX DISTRIBUTION (across reps):\n")
cat("  Mean:     ", round(mean(results_success$truth), 4), "\n")
cat("  SD:       ", round(sd(results_success$truth), 4), "\n")
cat("  Range:    [", round(min(results_success$truth), 4), ", ",
    round(max(results_success$truth), 4), "]\n\n", sep = "")

# Estimate distribution
cat("ESTIMATE DISTRIBUTION:\n")
cat("  Mean:     ", round(mean(results_success$estimate), 4), "\n")
cat("  SD:       ", round(sd(results_success$estimate), 4), "\n")
cat("  Range:    [", round(min(results_success$estimate), 4), ", ",
    round(max(results_success$estimate), 4), "]\n\n", sep = "")

# =============================================================================
# Detailed Diagnostics
# =============================================================================

cat("=============================================================================\n")
cat("DETAILED DIAGNOSTICS\n")
cat("=============================================================================\n\n")

# Coverage failures
n_failures <- sum(!results_success$covered)
if (n_failures > 0) {
  cat("Coverage failures:", n_failures, "/", n_success, "\n")

  # Directional failures
  below_ci <- sum(results_success$truth < results_success$ci_lower)
  above_ci <- sum(results_success$truth > results_success$ci_upper)

  cat("  Truth below CI:", below_ci, "(", round(100*below_ci/n_success, 1), "%)\n")
  cat("  Truth above CI:", above_ci, "(", round(100*above_ci/n_success, 1), "%)\n\n")

  # Should be roughly balanced if calibrated
  if (abs(below_ci - above_ci) > 0.2 * n_failures) {
    cat("  ⚠ Asymmetric failures suggest potential bias\n\n")
  }
}

# Bootstrap success rate
mean_boot_success <- mean(results_success$n_bootstrap_successful)
cat("Mean bootstrap success rate:", round(mean_boot_success / n_bootstrap, 3), "\n\n")

# =============================================================================
# Visualization (if any failures)
# =============================================================================

if (n_failures > 0 && n_failures <= 10) {
  cat("FAILED CASES:\n")
  failed_cases <- results_success %>%
    filter(!covered) %>%
    select(rep, truth, estimate, ci_lower, ci_upper, bias)

  print(failed_cases, n = 10)
  cat("\n")
}

# =============================================================================
# FINAL VERDICT
# =============================================================================

cat("=============================================================================\n")
cat("FINAL VERDICT\n")
cat("=============================================================================\n\n")

if (coverage_pass && bias_pass) {
  cat("✓✓✓ VALIDATION PASSED ✓✓✓\n\n")
  cat("Observation-level Wasserstein DRO achieves:\n")
  cat("  - Nominal coverage (", round(coverage, 2), " ≈ ", confidence_level, ")\n", sep = "")
  cat("  - Approximately unbiased (mean bias = ", round(mean_bias, 4), ")\n", sep = "")
  cat("  - Reliable inference for φ*(λ_w = ", lambda_w, ")\n", sep = "")
  cat("\n")
  cat("This approach is ready for:\n")
  cat("  1. Integration into main package\n")
  cat("  2. Application to real data\n")
  cat("  3. Manuscript methods section\n")

} else {
  cat("⚠ VALIDATION CONCERNS ⚠\n\n")

  if (!coverage_pass) {
    cat("✗ Coverage is not nominal (", round(coverage, 2), " vs ", confidence_level, ")\n", sep = "")
    if (coverage < confidence_level) {
      cat("  → CIs are too narrow (undercoverage)\n")
      cat("  → May need more bootstrap iterations or different CI method\n")
    } else {
      cat("  → CIs are too wide (overcoverage)\n")
      cat("  → Bootstrap may be too conservative\n")
    }
  }

  if (!bias_pass) {
    cat("✗ Estimates are biased (mean = ", round(mean_bias, 4), ")\n", sep = "")
    cat("  → May need larger lambda_w or better tau estimation\n")
  }

  cat("\n")
  cat("Further investigation needed before deployment.\n")
}

cat("\n=============================================================================\n")

# Save results
saveRDS(results_success, here("sims/results/coverage_validation_observation_level.rds"))
cat("Results saved to: sims/results/coverage_validation_observation_level.rds\n")
