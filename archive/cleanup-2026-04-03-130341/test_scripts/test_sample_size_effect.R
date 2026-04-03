#!/usr/bin/env Rscript
# PHASE 1: Sample Size Effect Test
# Test if selection bias decreases with larger samples (n=250 to n=2000)

library(tidyverse)
library(here)

devtools::load_all(here("package"))

cat("=============================================================================\n")
cat("PHASE 1: SAMPLE SIZE EFFECT TEST\n")
cat("=============================================================================\n\n")

cat("HYPOTHESIS: Selection bias ∝ 1/√n decreases with larger samples\n\n")

cat("TEST DESIGN:\n")
cat("  Sample sizes: n ∈ {250, 500, 1000, 2000}\n")
cat("  Replications: 50 per size\n")
cat("  lambda_w: 0.5\n")
cat("  Bootstrap: 100 iterations\n")
cat("  Confidence level: 0.95\n\n")

cat("DECISION CRITERION:\n")
cat("  - If n=2000 gives coverage ≥90%: Problem solved\n")
cat("  - If n=2000 still <85%: Proceed to Phase 2\n\n")

# =============================================================================
# Function: Compute TRUE phi*(lambda_w) from DGP
# =============================================================================

compute_true_minimax <- function(X1, X2, tau_s_fn, tau_y_fn, lambda_w) {
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
                                            confidence_level = 0.95,
                                            verbose = FALSE) {

  n <- nrow(data)

  if (verbose) cat("  Computing point estimate...\n")

  # Point estimate
  point_est <- observation_level_minimax_wasserstein(
    data = data,
    covariates = covariates,
    lambda_w = lambda_w,
    tau_method = tau_method,
    cross_fit = TRUE,
    scale_covariates = TRUE
  )

  if (verbose) cat("  Bootstrapping (", n_bootstrap, "iterations)...\n")

  # Bootstrap
  bootstrap_estimates <- numeric(n_bootstrap)

  for (b in 1:n_bootstrap) {
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
        cross_fit = FALSE,  # Faster
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
# Function: Run one replication for given sample size
# =============================================================================

run_one_replication <- function(rep, n, lambda_w, tau_s_fn, tau_y_fn,
                                 n_bootstrap = 100, verbose = FALSE) {

  set.seed(rep + 5000 + n)  # Different seed for each n to avoid correlation

  # Generate data
  X1 <- rnorm(n)
  X2 <- rnorm(n)
  A <- rbinom(n, 1, 0.5)

  tau_s_true <- tau_s_fn(X1, X2)
  tau_y_true <- tau_y_fn(X1, X2)

  S <- tau_s_true * A + 0.5 + 0.2 * X1 + rnorm(n, sd = 0.3)
  Y <- tau_y_true * A + 0.6 + 0.3 * X2 + rnorm(n, sd = 0.4)

  data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

  # Compute TRUE minimax for this realization
  truth <- compute_true_minimax(X1, X2, tau_s_fn, tau_y_fn, lambda_w)

  # Estimate with bootstrap CI
  result <- tryCatch({
    bootstrap_ci_observation_level(
      data = data,
      covariates = c("X1", "X2"),
      lambda_w = lambda_w,
      tau_method = "kernel",
      n_bootstrap = n_bootstrap,
      confidence_level = 0.95,
      verbose = verbose
    )
  }, error = function(e) {
    if (verbose) cat("  ERROR in rep", rep, ":", conditionMessage(e), "\n")
    NULL
  })

  if (is.null(result)) {
    return(tibble(n = n, rep = rep, status = "failed"))
  }

  # Check coverage
  covered <- (truth >= result$ci_lower & truth <= result$ci_upper)

  # CI width
  ci_width <- result$ci_upper - result$ci_lower

  # Bias
  bias <- result$phi_star - truth

  tibble(
    n = n,
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
}

# =============================================================================
# Simulation Setup
# =============================================================================

# DGP parameters
sample_sizes <- c(250, 500, 1000, 2000)
lambda_w <- 0.5  # Moderate shift
n_reps <- 50     # Per sample size
n_bootstrap <- 500  # Increased for stable 95% quantiles
confidence_level <- 0.95

# Treatment effect functions (same as coverage_validation.R)
tau_s_fn <- function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2
tau_y_fn <- function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2

cat("Treatment effects:\n")
cat("  tau_S(X) = 0.3 + 0.2*X1 - 0.1*X2\n")
cat("  tau_Y(X) = 0.4 + 0.3*X1 + 0.1*X2\n\n")

# =============================================================================
# Run Simulation Across Sample Sizes
# =============================================================================

cat("=============================================================================\n")
cat("RUNNING SIMULATION\n")
cat("=============================================================================\n\n")

all_results <- list()

for (n in sample_sizes) {
  cat("\n--- SAMPLE SIZE: n =", n, "---\n")
  cat("Running", n_reps, "replications...\n\n")

  results_n <- map_dfr(1:n_reps, function(rep) {
    if (rep %% 10 == 0) {
      cat("  Rep", rep, "/", n_reps, "\n")
    }

    run_one_replication(
      rep = rep,
      n = n,
      lambda_w = lambda_w,
      tau_s_fn = tau_s_fn,
      tau_y_fn = tau_y_fn,
      n_bootstrap = n_bootstrap,
      verbose = FALSE
    )
  })

  all_results[[as.character(n)]] <- results_n

  # Quick summary
  success <- results_n %>% filter(status == "success")
  n_success <- nrow(success)

  if (n_success > 0) {
    coverage <- mean(success$covered)
    mean_bias <- mean(success$bias)
    rmse <- sqrt(mean(success$bias^2))

    cat("\n  Quick summary for n =", n, ":\n")
    cat("    Successful:", n_success, "/", n_reps, "\n")
    cat("    Coverage:  ", round(coverage, 3), "\n")
    cat("    Mean bias: ", round(mean_bias, 4), "\n")
    cat("    RMSE:      ", round(rmse, 4), "\n")
  } else {
    cat("\n  All replications failed for n =", n, "\n")
  }
}

# Combine all results
results_all <- bind_rows(all_results)

# =============================================================================
# Analysis: Compare Across Sample Sizes
# =============================================================================

cat("\n\n=============================================================================\n")
cat("COMPARATIVE ANALYSIS\n")
cat("=============================================================================\n\n")

# Summary by sample size
summary_by_n <- results_all %>%
  filter(status == "success") %>%
  group_by(n) %>%
  summarise(
    n_success = n(),
    coverage = mean(covered),
    mean_bias = mean(bias),
    median_bias = median(bias),
    rmse = sqrt(mean(bias^2)),
    mean_ci_width = mean(ci_width),
    .groups = "drop"
  ) %>%
  arrange(n)

cat("SUMMARY BY SAMPLE SIZE:\n\n")
print(summary_by_n, n = Inf)
cat("\n")

# Key patterns
cat("KEY PATTERNS:\n\n")

# 1. Coverage trend
cat("1. COVERAGE TREND:\n")
for (i in 1:nrow(summary_by_n)) {
  n_val <- summary_by_n$n[i]
  cov <- summary_by_n$coverage[i]
  status <- if (cov >= 0.90) "✓ GOOD" else if (cov >= 0.80) "~ OK" else "✗ POOR"
  cat(sprintf("   n=%4d: %5.1f%% %s\n", n_val, cov*100, status))
}
cat("\n")

# 2. Bias trend
cat("2. BIAS TREND:\n")
for (i in 1:nrow(summary_by_n)) {
  n_val <- summary_by_n$n[i]
  bias <- summary_by_n$mean_bias[i]
  status <- if (abs(bias) < 0.01) "✓ LOW" else if (abs(bias) < 0.03) "~ MODERATE" else "✗ HIGH"
  cat(sprintf("   n=%4d: %7.4f %s\n", n_val, bias, status))
}
cat("\n")

# 3. RMSE trend
cat("3. RMSE TREND:\n")
for (i in 1:nrow(summary_by_n)) {
  n_val <- summary_by_n$n[i]
  rmse <- summary_by_n$rmse[i]
  cat(sprintf("   n=%4d: %6.4f\n", n_val, rmse))
}
cat("\n")

# Check if bias scales as 1/sqrt(n)
if (nrow(summary_by_n) >= 2) {
  bias_ratio <- abs(summary_by_n$mean_bias[1]) / abs(summary_by_n$mean_bias[nrow(summary_by_n)])
  n_ratio <- sqrt(summary_by_n$n[nrow(summary_by_n)] / summary_by_n$n[1])

  cat("4. BIAS SCALING:\n")
  cat("   Expected ratio (if bias ∝ 1/√n): ", round(n_ratio, 2), "\n")
  cat("   Observed ratio (bias_n=250 / bias_n=", summary_by_n$n[nrow(summary_by_n)], "): ",
      round(bias_ratio, 2), "\n")

  if (abs(bias_ratio - n_ratio) < 0.5) {
    cat("   → Bias scales roughly as 1/√n ✓\n")
  } else if (bias_ratio > n_ratio + 0.5) {
    cat("   → Bias decreases slower than 1/√n (fundamental issue)\n")
  } else {
    cat("   → Bias decreases faster than 1/√n (good news!)\n")
  }
  cat("\n")
}

# =============================================================================
# Decision
# =============================================================================

cat("=============================================================================\n")
cat("PHASE 1 DECISION\n")
cat("=============================================================================\n\n")

# Get results for n=2000
results_n2000 <- summary_by_n %>% filter(n == 2000)

if (nrow(results_n2000) == 0) {
  cat("ERROR: No successful replications for n=2000\n")
  cat("Cannot make decision - investigation failed.\n\n")
} else {
  coverage_2000 <- results_n2000$coverage
  bias_2000 <- results_n2000$mean_bias

  cat("Results for n=2000:\n")
  cat("  Coverage:  ", round(coverage_2000, 3), "\n")
  cat("  Mean bias: ", round(bias_2000, 4), "\n")
  cat("  RMSE:      ", round(results_n2000$rmse, 4), "\n\n")

  if (coverage_2000 >= 0.90) {
    cat("✓✓✓ PHASE 1: SUCCESS ✓✓✓\n\n")
    cat("Larger sample size SOLVES the problem!\n\n")
    cat("RECOMMENDATION:\n")
    cat("  - Use observation-level Wasserstein with n ≥ 1000\n")
    cat("  - Document sample size requirements\n")
    cat("  - No need for Phase 2 debiasing\n\n")
    cat("NEXT STEPS:\n")
    cat("  1. Run full coverage validation with n=2000\n")
    cat("  2. Update documentation\n")
    cat("  3. Add sample size guidance to package\n\n")

  } else if (coverage_2000 >= 0.85) {
    cat("~ PHASE 1: PARTIAL SUCCESS ~\n\n")
    cat("Larger sample size helps but insufficient.\n\n")
    cat("  Coverage improved from ", round(summary_by_n$coverage[1], 2),
        " to ", round(coverage_2000, 2), "\n")
    cat("  But still below target (0.90-0.95)\n\n")
    cat("RECOMMENDATION:\n")
    cat("  - Proceed to Phase 2 (systematic debiasing)\n")
    cat("  - Sample size helps but needs correction too\n\n")

  } else {
    cat("✗ PHASE 1: INSUFFICIENT ✗\n\n")
    cat("Larger sample size does NOT solve the problem.\n\n")
    cat("Coverage remains at ", round(coverage_2000, 2), " (target: 0.90+)\n\n")
    cat("RECOMMENDATION:\n")
    cat("  - PROCEED TO PHASE 2: Systematic debiasing approaches\n")
    cat("  - Selection bias is fundamental, not just small-sample\n\n")
    cat("PHASE 2 OPTIONS:\n")
    cat("  1. Larger conservative penalty (k > 3)\n")
    cat("  2. Shrinkage + DRO\n")
    cat("  3. Double robust estimation\n")
    cat("  4. Empirical Bayes shrinkage\n")
    cat("  5. Bayesian DRO\n\n")
  }
}

# =============================================================================
# Visualization
# =============================================================================

cat("=============================================================================\n")
cat("CREATING VISUALIZATION\n")
cat("=============================================================================\n\n")

# Create plots
library(ggplot2)

# 1. Coverage by sample size
p1 <- ggplot(summary_by_n, aes(x = n, y = coverage)) +
  geom_line(size = 1) +
  geom_point(size = 3) +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "red") +
  geom_hline(yintercept = 0.90, linetype = "dashed", color = "orange") +
  labs(
    title = "Coverage vs Sample Size",
    x = "Sample Size (n)",
    y = "Coverage",
    subtitle = "Target: 95% (dashed red), Acceptable: 90% (dashed orange)"
  ) +
  scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
  theme_minimal(base_size = 12)

# 2. Bias by sample size
p2 <- ggplot(summary_by_n, aes(x = n, y = mean_bias)) +
  geom_line(size = 1) +
  geom_point(size = 3) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
  labs(
    title = "Mean Bias vs Sample Size",
    x = "Sample Size (n)",
    y = "Mean Bias",
    subtitle = "Target: 0 (dashed gray)"
  ) +
  theme_minimal(base_size = 12)

# 3. RMSE by sample size
p3 <- ggplot(summary_by_n, aes(x = n, y = rmse)) +
  geom_line(size = 1) +
  geom_point(size = 3) +
  labs(
    title = "RMSE vs Sample Size",
    x = "Sample Size (n)",
    y = "RMSE"
  ) +
  theme_minimal(base_size = 12)

# Save plots
ggsave(here("test_sample_size_coverage.png"), p1, width = 8, height = 6)
ggsave(here("test_sample_size_bias.png"), p2, width = 8, height = 6)
ggsave(here("test_sample_size_rmse.png"), p3, width = 8, height = 6)

cat("Plots saved:\n")
cat("  - test_sample_size_coverage.png\n")
cat("  - test_sample_size_bias.png\n")
cat("  - test_sample_size_rmse.png\n\n")

# =============================================================================
# Save Results
# =============================================================================

results_list <- list(
  summary = summary_by_n,
  all_results = results_all,
  parameters = list(
    sample_sizes = sample_sizes,
    n_reps = n_reps,
    lambda_w = lambda_w,
    n_bootstrap = n_bootstrap
  )
)

saveRDS(results_list, here("test_sample_size_effect_results.rds"))
cat("Full results saved to: test_sample_size_effect_results.rds\n\n")

cat("=============================================================================\n")
cat("PHASE 1 COMPLETE\n")
cat("=============================================================================\n")
