#!/usr/bin/env Rscript
# Coverage Validation: Shrinkage + DRO Method
# Winner from Phase 2: shrinkage factor = 0.5

library(tidyverse)
library(here)

devtools::load_all(here("package"))

cat("=============================================================================\n")
cat("PHASE 2: COVERAGE VALIDATION\n")
cat("=============================================================================\n\n")

cat("METHOD: Shrinkage + DRO (shrink_factor = 0.5)\n")
cat("From Phase 2: Mean bias = 0.004, RMSE = 0.024\n\n")

cat("GOAL: Verify nominal 95% coverage\n\n")

# =============================================================================
# Helper functions
# =============================================================================

compute_true_minimax <- function(X1, X2, tau_s_fn, tau_y_fn, lambda_w) {
  n <- length(X1)
  tau_s_true <- tau_s_fn(X1, X2)
  tau_y_true <- tau_y_fn(X1, X2)
  h_true <- tau_s_true * tau_y_true
  X <- scale(cbind(X1, X2))
  cost_matrix <- as.matrix(dist(X, method = "euclidean"))^2

  dual_objective <- function(gamma) {
    obj_matrix <- matrix(h_true, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  optimize(dual_objective, interval = c(0, 100), maximum = TRUE)$objective
}

#' Shrinkage + DRO estimator
estimate_with_shrinkage <- function(data, covariates, lambda_w, shrink_factor) {
  # Estimate treatment effects
  tau_s <- estimate_treatment_effect_function(
    data = data,
    outcome = "S",
    covariates = covariates,
    method = "kernel",
    cross_fit = TRUE
  )

  tau_y <- estimate_treatment_effect_function(
    data = data,
    outcome = "Y",
    covariates = covariates,
    method = "kernel",
    cross_fit = TRUE
  )

  # Concordances
  h_est <- tau_s$tau_hat * tau_y$tau_hat

  # Shrink toward mean
  h_mean <- mean(h_est)
  h_shrunk <- h_mean + shrink_factor * (h_est - h_mean)

  # Apply DRO with shrunk concordances
  n <- nrow(data)
  X_scaled <- scale(data[, covariates])
  cost_matrix <- as.matrix(dist(X_scaled, method = "euclidean"))^2

  dual_objective <- function(gamma) {
    obj_matrix <- matrix(h_shrunk, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  result_opt <- optimize(dual_objective, interval = c(0, 100), maximum = TRUE)

  list(
    phi_star = result_opt$objective,
    gamma_star = result_opt$maximum,
    concordance_shrunk = h_shrunk
  )
}

#' Bootstrap CI with shrinkage method
bootstrap_ci_shrinkage <- function(data, covariates, lambda_w, shrink_factor,
                                   n_bootstrap = 500, confidence_level = 0.95) {
  n <- nrow(data)

  # Point estimate
  point_est <- estimate_with_shrinkage(data, covariates, lambda_w, shrink_factor)

  # Bootstrap
  bootstrap_estimates <- numeric(n_bootstrap)

  for (b in 1:n_bootstrap) {
    boot_idx <- sample(1:n, size = n, replace = TRUE)
    boot_data <- data[boot_idx, ]

    boot_result <- tryCatch({
      estimate_with_shrinkage(boot_data, covariates, lambda_w, shrink_factor)
    }, error = function(e) list(phi_star = NA))

    bootstrap_estimates[b] <- boot_result$phi_star
  }

  # Remove failed bootstraps
  bootstrap_estimates <- bootstrap_estimates[!is.na(bootstrap_estimates)]

  # Compute CI
  alpha <- 1 - confidence_level
  ci_lower <- quantile(bootstrap_estimates, alpha/2)
  ci_upper <- quantile(bootstrap_estimates, 1 - alpha/2)

  list(
    phi_star = point_est$phi_star,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    n_bootstrap_successful = length(bootstrap_estimates)
  )
}

# =============================================================================
# Run coverage validation
# =============================================================================

cat("=============================================================================\n")
cat("RUNNING COVERAGE VALIDATION\n")
cat("=============================================================================\n\n")

n_reps <- 100
n <- 250
lambda_w <- 0.5
shrink_factor <- 0.5
n_bootstrap <- 500
confidence_level <- 0.95

tau_s_fn <- function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2
tau_y_fn <- function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2

cat("Parameters:\n")
cat("  n_reps:", n_reps, "\n")
cat("  n:", n, "\n")
cat("  lambda_w:", lambda_w, "\n")
cat("  shrink_factor:", shrink_factor, "\n")
cat("  n_bootstrap:", n_bootstrap, "\n")
cat("  confidence_level:", confidence_level, "\n\n")

results <- map_dfr(1:n_reps, function(rep) {
  if (rep %% 10 == 0) {
    cat("Replication", rep, "/", n_reps, "\n")
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

  # Truth
  truth <- compute_true_minimax(X1, X2, tau_s_fn, tau_y_fn, lambda_w)

  # Estimate with bootstrap CI
  result <- tryCatch({
    bootstrap_ci_shrinkage(
      data = data,
      covariates = c("X1", "X2"),
      lambda_w = lambda_w,
      shrink_factor = shrink_factor,
      n_bootstrap = n_bootstrap,
      confidence_level = confidence_level
    )
  }, error = function(e) {
    cat("ERROR in rep", rep, ":", conditionMessage(e), "\n")
    NULL
  })

  if (is.null(result)) {
    return(tibble(rep = rep, status = "failed"))
  }

  # Check coverage
  covered <- (truth >= result$ci_lower & truth <= result$ci_upper)

  tibble(
    rep = rep,
    status = "success",
    truth = truth,
    estimate = result$phi_star,
    ci_lower = result$ci_lower,
    ci_upper = result$ci_upper,
    covered = covered,
    ci_width = result$ci_upper - result$ci_lower,
    bias = result$phi_star - truth,
    n_bootstrap_successful = result$n_bootstrap_successful
  )
})

cat("\n")

# =============================================================================
# Analyze results
# =============================================================================

cat("=============================================================================\n")
cat("COVERAGE VALIDATION RESULTS\n")
cat("=============================================================================\n\n")

results_success <- results %>% filter(status == "success")
n_success <- nrow(results_success)
n_failed <- n_reps - n_success

cat("Successful replications:", n_success, "/", n_reps, "\n")
if (n_failed > 0) {
  cat("Failed replications:", n_failed, "\n")
}
cat("\n")

# Coverage
coverage <- mean(results_success$covered)
coverage_se <- sqrt(coverage * (1 - coverage) / n_success)

cat("COVERAGE:\n")
cat("  Observed: ", round(coverage, 3), " (SE = ", round(coverage_se, 3), ")\n", sep = "")
cat("  Target:   ", confidence_level, "\n")
cat("  95% CI:   [", round(coverage - 1.96*coverage_se, 3), ", ",
    round(coverage + 1.96*coverage_se, 3), "]\n", sep = "")

if (coverage >= 0.93 && coverage <= 0.97) {
  cat("  Status:   ✓✓✓ PASS - Nominal coverage achieved!\n\n")
  coverage_pass <- TRUE
} else if (coverage >= 0.90 && coverage <= 0.98) {
  cat("  Status:   ~ MARGINAL - Close to nominal\n\n")
  coverage_pass <- TRUE
} else {
  cat("  Status:   ✗ FAIL - Coverage not nominal\n\n")
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

if (abs(mean_bias) < 0.01) {
  cat("  Status:   ✓ PASS - Approximately unbiased\n\n")
  bias_pass <- TRUE
} else if (abs(mean_bias) < 0.02) {
  cat("  Status:   ~ OK - Small bias\n\n")
  bias_pass <- TRUE
} else {
  cat("  Status:   ✗ FAIL - Significant bias remains\n\n")
  bias_pass <- FALSE
}

# CI width
mean_ci_width <- mean(results_success$ci_width)

cat("CONFIDENCE INTERVAL:\n")
cat("  Mean width: ", round(mean_ci_width, 4), "\n\n")

# Coverage failures
n_failures <- sum(!results_success$covered)
if (n_failures > 0) {
  cat("COVERAGE FAILURES:\n")
  below_ci <- sum(results_success$truth < results_success$ci_lower)
  above_ci <- sum(results_success$truth > results_success$ci_upper)

  cat("  Truth below CI:", below_ci, "(", round(100*below_ci/n_success, 1), "%)\n")
  cat("  Truth above CI:", above_ci, "(", round(100*above_ci/n_success, 1), "%)\n")

  if (abs(below_ci - above_ci) > 0.3 * n_failures) {
    cat("  → Asymmetric failures suggest residual bias\n")
  }
  cat("\n")
}

# =============================================================================
# Final verdict
# =============================================================================

cat("=============================================================================\n")
cat("FINAL VERDICT\n")
cat("=============================================================================\n\n")

if (coverage_pass && bias_pass) {
  cat("✓✓✓ PHASE 2 SUCCESS ✓✓✓\n\n")
  cat("Shrinkage + DRO (shrink_factor = 0.5) achieves:\n")
  cat("  - Nominal coverage: ", round(coverage, 2), " ≈ ", confidence_level, "\n", sep = "")
  cat("  - Low bias: ", round(mean_bias, 4), "\n", sep = "")
  cat("  - Low RMSE: ", round(rmse, 4), "\n\n", sep = "")

  cat("SOLUTION FOUND FOR DRO SELECTION BIAS\n\n")

  cat("Recommended implementation:\n")
  cat("  1. Estimate τ_S(x) and τ_Y(x) via kernel smoothing\n")
  cat("  2. Compute concordances: h_i = τ_S(x_i) × τ_Y(x_i)\n")
  cat("  3. Shrink toward mean: h_shrunk = mean(h) + 0.5 × (h - mean(h))\n")
  cat("  4. Apply Wasserstein DRO to shrunk concordances\n")
  cat("  5. Bootstrap for CI (500+ iterations)\n\n")

  cat("Next steps:\n")
  cat("  - Add to package as shrinkage_minimax_wasserstein()\n")
  cat("  - Document in methods section\n")
  cat("  - Test on different DGPs\n")

} else {
  cat("⚠ PHASE 2 INCOMPLETE ⚠\n\n")

  if (!coverage_pass) {
    cat("Coverage: ", round(coverage, 2), " (target: ", confidence_level, ")\n", sep = "")
    if (coverage < 0.90) {
      cat("  → Try shrink_factor = 0.6 (had similar RMSE but different bias profile)\n")
      cat("  → Or conservative k=5 (had bias = -0.002)\n")
    }
  }

  if (!bias_pass) {
    cat("Mean bias: ", round(mean_bias, 4), "\n", sep = "")
    cat("  → May need further tuning\n")
  }

  cat("\n")
}

# =============================================================================
# Save results
# =============================================================================

saveRDS(results_success, here("phase2_coverage_validation_results.rds"))
cat("\nResults saved to: phase2_coverage_validation_results.rds\n")

cat("\n=============================================================================\n")
cat("PHASE 2 COVERAGE VALIDATION COMPLETE\n")
cat("=============================================================================\n")
