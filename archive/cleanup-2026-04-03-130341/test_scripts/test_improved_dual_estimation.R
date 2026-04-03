#!/usr/bin/env Rscript
# Test improved dual estimation methods for moderate sample sizes
# Compare:
# 1. Empirical (current)
# 2. Leave-one-out (reduce bias)
# 3. Parametric (assume Normal covariates)
# 4. Kernel-smoothed

library(mvtnorm)  # For multivariate normal

source("package/R/wasserstein_minimax_IF_inference.R")

set.seed(2026)

cat("========================================\n")
cat("IMPROVED DUAL ESTIMATION METHODS\n")
cat("========================================\n\n")

# Generate data
generate_data <- function(n, d) {
  X <- matrix(rnorm(n * d), nrow = n, ncol = d)
  weights <- 0.2 / (2^(0:(d-1)))

  tau_S <- 0.3 + as.vector(X %*% weights)
  tau_Y <- 0.4 + as.vector(X %*% (1.5 * weights))
  h_true <- tau_S * tau_Y

  list(X = X, h_true = h_true, weights_S = weights, weights_Y = 1.5 * weights)
}

# Compute oracle truth
compute_truth <- function(d, weights_S, weights_Y, gamma = 0.5, tau = 0.1) {
  n_large <- 10000
  X <- matrix(rnorm(n_large * d), nrow = n_large, ncol = d)
  h_oracle <- (0.3 + as.vector(X %*% weights_S)) *
              (0.4 + as.vector(X %*% weights_Y))

  phi_j <- numeric(n_large)
  for (j in 1:n_large) {
    costs <- rowSums((X - matrix(X[j, ], nrow = n_large, ncol = d, byrow = TRUE))^2) / d
    values <- exp(-(h_oracle + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }

  mean(phi_j)
}

# Method 1: Standard empirical (current approach)
estimate_dual_empirical <- function(X, h, gamma = 0.5, tau = 0.1) {
  n <- nrow(X)
  d <- ncol(X)

  phi_j <- numeric(n)
  for (j in 1:n) {
    costs <- rowSums((X - matrix(X[j, ], nrow = n, ncol = d, byrow = TRUE))^2) / d
    values <- exp(-(h + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }

  mean(phi_j)
}

# Method 2: Leave-one-out (exclude j when computing m(X_j))
estimate_dual_loo <- function(X, h, gamma = 0.5, tau = 0.1) {
  n <- nrow(X)
  d <- ncol(X)

  phi_j <- numeric(n)
  for (j in 1:n) {
    # Exclude observation j from the sum
    idx_minus_j <- setdiff(1:n, j)
    X_minus_j <- X[idx_minus_j, , drop = FALSE]
    h_minus_j <- h[idx_minus_j]

    costs <- rowSums((X_minus_j - matrix(X[j, ], nrow = n-1, ncol = d, byrow = TRUE))^2) / d
    values <- exp(-(h_minus_j + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }

  mean(phi_j)
}

# Method 3: Parametric (assume X ~ N(0, Sigma), augment with MC samples)
estimate_dual_parametric <- function(X, h, gamma = 0.5, tau = 0.1, n_mc = 500) {
  n <- nrow(X)
  d <- ncol(X)

  # Estimate covariate distribution
  mu_hat <- colMeans(X)
  Sigma_hat <- cov(X)

  # Fit model for h as function of X
  # Use simple linear model
  fit_h <- lm(h ~ X)

  # Generate MC samples from fitted distribution
  X_mc <- rmvnorm(n_mc, mean = mu_hat, sigma = Sigma_hat)
  h_mc <- predict(fit_h, newdata = data.frame(X = X_mc))

  # Combine observed and MC samples
  X_augmented <- rbind(X, X_mc)
  h_augmented <- c(h, h_mc)
  n_aug <- nrow(X_augmented)

  phi_j <- numeric(n)
  for (j in 1:n) {
    costs <- rowSums((X_augmented - matrix(X[j, ], nrow = n_aug, ncol = d, byrow = TRUE))^2) / d
    values <- exp(-(h_augmented + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }

  mean(phi_j)
}

# Method 4: Kernel-smoothed (add small noise to increase effective sample size)
estimate_dual_kernel <- function(X, h, gamma = 0.5, tau = 0.1, bandwidth = 0.1) {
  n <- nrow(X)
  d <- ncol(X)

  # Add kernel noise to each observation (bootstrap-like)
  n_bootstrap <- 5  # Replicate each observation
  X_smooth <- do.call(rbind, lapply(1:n, function(i) {
    matrix(X[i, ], nrow = n_bootstrap, ncol = d, byrow = TRUE) +
      rnorm(n_bootstrap * d, sd = bandwidth)
  }))
  h_smooth <- rep(h, each = n_bootstrap)

  n_smooth <- nrow(X_smooth)

  phi_j <- numeric(n)
  for (j in 1:n) {
    costs <- rowSums((X_smooth - matrix(X[j, ], nrow = n_smooth, ncol = d, byrow = TRUE))^2) / d
    values <- exp(-(h_smooth + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }

  mean(phi_j)
}

# Test configuration
test_methods <- function(d, n, n_sims = 50) {
  cat(sprintf("\nTesting d=%d, n=%d (%d reps)...\n", d, n, n_sims))

  # Get truth
  template <- generate_data(100, d)
  truth <- compute_truth(d, template$weights_S, template$weights_Y)

  results <- list(
    empirical = numeric(n_sims),
    loo = numeric(n_sims),
    parametric = numeric(n_sims),
    kernel = numeric(n_sims)
  )

  for (i in 1:n_sims) {
    dgp <- generate_data(n, d)
    X <- dgp$X
    h <- dgp$h_true

    # Test all methods
    results$empirical[i] <- estimate_dual_empirical(X, h)
    results$loo[i] <- estimate_dual_loo(X, h)
    results$parametric[i] <- tryCatch({
      estimate_dual_parametric(X, h, n_mc = 500)
    }, error = function(e) NA)
    results$kernel[i] <- estimate_dual_kernel(X, h)

    if (i %% 10 == 0) cat(".")
  }
  cat(" done\n")

  # Analyze
  methods <- c("empirical", "loo", "parametric", "kernel")
  summary_df <- data.frame(
    d = d,
    n = n,
    method = methods,
    truth = truth,
    mean_est = sapply(methods, function(m) mean(results[[m]], na.rm = TRUE)),
    bias = sapply(methods, function(m) mean(results[[m]], na.rm = TRUE) - truth),
    rel_bias = sapply(methods, function(m) (mean(results[[m]], na.rm = TRUE) - truth) / truth * 100),
    se = sapply(methods, function(m) sd(results[[m]], na.rm = TRUE)),
    rmse = sapply(methods, function(m) sqrt(mean((results[[m]] - truth)^2, na.rm = TRUE))),
    n_valid = sapply(methods, function(m) sum(!is.na(results[[m]])))
  )

  summary_df
}

# Test configurations
cat("Testing improved dual estimation methods...\n")
cat("Focus: d=5 at n=500 (where dual has -2.18% bias)\n")

configs <- expand.grid(
  d = c(4, 5),
  n = c(500, 1000)
)

results_list <- list()
for (i in 1:nrow(configs)) {
  d <- configs$d[i]
  n <- configs$n[i]

  result <- test_methods(d, n, n_sims = 50)
  results_list[[i]] <- result
}

results_all <- do.call(rbind, results_list)

cat("\n========================================\n")
cat("COMPLETE RESULTS\n")
cat("========================================\n\n")

print(results_all, digits = 4)

cat("\n========================================\n")
cat("BIAS COMPARISON (d=5, n=500)\n")
cat("========================================\n\n")

subset_d5_n500 <- results_all[results_all$d == 5 & results_all$n == 500, ]
subset_d5_n500 <- subset_d5_n500[order(abs(subset_d5_n500$rel_bias)), ]

cat(sprintf("%-12s: %+.2f%% bias, RMSE=%.4f\n", "Method", 0, 0))
cat("---------------------------------------------\n")
for (i in 1:nrow(subset_d5_n500)) {
  row <- subset_d5_n500[i, ]
  status <- if (abs(row$rel_bias) < 1.5) "✓" else "⚠"

  improvement <- if (i > 1) {
    baseline_bias <- subset_d5_n500$rel_bias[subset_d5_n500$method == "empirical"]
    reduction <- abs(baseline_bias) - abs(row$rel_bias)
    sprintf(" (%.1fx better)", abs(baseline_bias) / abs(row$rel_bias))
  } else {
    " (baseline)"
  }

  cat(sprintf("%s %-12s: %+.2f%% bias, RMSE=%.4f%s\n",
              status, row$method, row$rel_bias, row$rmse, improvement))
}

cat("\n========================================\n")
cat("BEST METHOD BY CONFIGURATION\n")
cat("========================================\n\n")

for (i in 1:nrow(configs)) {
  d <- configs$d[i]
  n <- configs$n[i]

  subset <- results_all[results_all$d == d & results_all$n == n, ]

  # Find method with lowest absolute bias
  best_idx <- which.min(abs(subset$rel_bias))
  best <- subset[best_idx, ]

  empirical <- subset[subset$method == "empirical", ]

  improvement <- abs(empirical$rel_bias) - abs(best$rel_bias)

  cat(sprintf("d=%d, n=%d:\n", d, n))
  cat(sprintf("  Empirical: %+.2f%% bias\n", empirical$rel_bias))
  cat(sprintf("  Best (%s): %+.2f%% bias\n", best$method, best$rel_bias))

  if (improvement > 0.5) {
    cat(sprintf("  → Improvement: %.2f percentage points (%.1fx reduction)\n\n",
                improvement, abs(empirical$rel_bias) / abs(best$rel_bias)))
  } else {
    cat("  → No substantial improvement\n\n")
  }
}

cat("========================================\n")
cat("CONCLUSIONS\n")
cat("========================================\n\n")

# Check if any method consistently beats empirical
for (method in c("loo", "parametric", "kernel")) {
  subset_method <- results_all[results_all$method == method, ]
  subset_empirical <- results_all[results_all$method == "empirical", ]

  # Match by d and n
  subset_method <- subset_method[order(subset_method$d, subset_method$n), ]
  subset_empirical <- subset_empirical[order(subset_empirical$d, subset_empirical$n), ]

  bias_reduction <- mean(abs(subset_empirical$rel_bias) - abs(subset_method$rel_bias))

  if (bias_reduction > 0.5) {
    cat(sprintf("✓ %s: Average %.2f%% bias reduction\n",
                toupper(method), bias_reduction))
    cat("  → Recommended for moderate sample sizes\n\n")
  } else {
    cat(sprintf("⚠ %s: No consistent improvement (%.2f%%)\n\n",
                toupper(method), bias_reduction))
  }
}

# Save results
saveRDS(results_all, "improved_dual_estimation_results.rds")
cat("Results saved to: improved_dual_estimation_results.rds\n")
