#!/usr/bin/env Rscript
# Diagnose source of bias in high dimensions
# Test three scenarios:
# 1. Oracle nuisances (h known) - isolates dual/IF issues
# 2. Estimated nuisances - full method
# 3. Oracle dual (plug-in truth) - isolates IF issues

source("package/R/wasserstein_minimax_IF_inference.R")

set.seed(999)

cat("========================================\n")
cat("HIGH-DIMENSIONAL BIAS DIAGNOSTIC\n")
cat("========================================\n\n")

# Generate data with known structure
generate_data_with_truth <- function(n, d) {
  X <- matrix(rnorm(n * d), nrow = n, ncol = d)
  colnames(X) <- paste0("X", 1:d)

  A <- rbinom(n, 1, 0.5)

  # Simple additive structure for clear interpretation
  weights <- 0.2 / (2^(0:(d-1)))

  tau_S_true <- 0.3 + as.vector(X %*% weights)
  tau_Y_true <- 0.4 + as.vector(X %*% (1.5 * weights))
  h_true <- tau_S_true * tau_Y_true

  S <- A * tau_S_true + rnorm(n, sd = 0.5)
  Y <- A * tau_Y_true + rnorm(n, sd = 0.5)

  data <- data.frame(X, A = A, S = S, Y = Y)

  list(
    data = data,
    tau_S_true = tau_S_true,
    tau_Y_true = tau_Y_true,
    h_true = h_true,
    weights_S = weights,
    weights_Y = 1.5 * weights
  )
}

# Compute oracle truth
compute_oracle_truth <- function(d, weights_S, weights_Y, gamma = 0.5, tau = 0.1) {
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

# Estimate dual with known h (oracle)
estimate_dual_oracle_h <- function(X, h_true, gamma = 0.5, tau = 0.1) {
  n <- nrow(X)
  d <- ncol(X)

  phi_j <- numeric(n)
  for (j in 1:n) {
    costs <- rowSums((X - matrix(X[j, ], nrow = n, ncol = d, byrow = TRUE))^2) / d
    values <- exp(-(h_true + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }

  mean(phi_j)
}

# Test single dimension
test_dimension_detailed <- function(d, n_sims = 50, n = 500) {
  cat(sprintf("\n========================================\n"))
  cat(sprintf("DIMENSION d=%d (n=%d)\n", d, n))
  cat(sprintf("========================================\n\n"))

  # Generate template for weights
  template <- generate_data_with_truth(100, d)
  weights_S <- template$weights_S
  weights_Y <- template$weights_Y

  cat("Computing oracle truth...\n")
  truth <- compute_oracle_truth(d, weights_S, weights_Y)
  cat(sprintf("Oracle truth: %.6f\n\n", truth))

  # Three scenarios
  results_oracle <- numeric(n_sims)
  results_estimated <- numeric(n_sims)
  bias_nuisance <- numeric(n_sims)

  cat(sprintf("Running %d replications...\n", n_sims))
  pb_count <- 0

  for (i in 1:n_sims) {
    dgp <- generate_data_with_truth(n, d)
    data <- dgp$data
    X <- as.matrix(data[, paste0("X", 1:d)])
    h_true <- dgp$h_true

    # Scenario 1: Oracle nuisances (dual with known h)
    phi_oracle <- estimate_dual_oracle_h(X, h_true, gamma = 0.5, tau = 0.1)
    results_oracle[i] <- phi_oracle

    # Scenario 2: Estimated nuisances (full method)
    result_est <- tryCatch({
      wasserstein_minimax_IF_inference(
        data = data,
        covariates = paste0("X", 1:d),
        gamma = 0.5,
        tau = 0.1,
        K = 5
      )
    }, error = function(e) NULL)

    if (!is.null(result_est)) {
      results_estimated[i] <- result_est$phi_star

      # Compare estimated h to true h
      h_estimated <- result_est$tau_s_hat * result_est$tau_y_hat
      bias_nuisance[i] <- mean(h_estimated - h_true)
    } else {
      results_estimated[i] <- NA
      bias_nuisance[i] <- NA
    }

    # Progress indicator
    if (i %% 10 == 0) {
      pb_count <- pb_count + 1
      cat(".")
      if (pb_count %% 5 == 0) cat(sprintf(" %d\n", i))
    }
  }
  cat("\n\n")

  # Remove NAs
  valid_idx <- !is.na(results_estimated)
  results_oracle <- results_oracle[valid_idx]
  results_estimated <- results_estimated[valid_idx]
  bias_nuisance <- bias_nuisance[valid_idx]
  n_valid <- sum(valid_idx)

  # Compute metrics
  # Oracle scenario
  bias_oracle <- mean(results_oracle) - truth
  rel_bias_oracle <- bias_oracle / truth * 100

  # Estimated scenario
  bias_estimated <- mean(results_estimated) - truth
  rel_bias_estimated <- bias_estimated / truth * 100

  # Nuisance bias
  mean_nuisance_bias <- mean(bias_nuisance)

  # Decomposition
  # Total bias = bias from nuisance + bias from finite sample dual
  # If oracle has no bias, then all bias is from nuisance estimation

  cat("RESULTS:\n")
  cat("--------\n\n")

  cat(sprintf("Valid replications: %d/%d\n\n", n_valid, n_sims))

  cat("Oracle Truth:\n")
  cat(sprintf("  Truth: %.6f\n\n", truth))

  cat("Scenario 1 - ORACLE NUISANCES (h known):\n")
  cat(sprintf("  Mean estimate: %.6f\n", mean(results_oracle)))
  cat(sprintf("  Bias:          %.6f (%.2f%%)\n", bias_oracle, rel_bias_oracle))
  cat(sprintf("  SE:            %.6f\n", sd(results_oracle)))
  if (abs(rel_bias_oracle) < 2) {
    cat("  ✓ Minimal bias - dual computation is accurate\n\n")
  } else {
    cat("  ⚠ Significant bias - dual may have issues\n\n")
  }

  cat("Scenario 2 - ESTIMATED NUISANCES (full method):\n")
  cat(sprintf("  Mean estimate: %.6f\n", mean(results_estimated)))
  cat(sprintf("  Bias:          %.6f (%.2f%%)\n", bias_estimated, rel_bias_estimated))
  cat(sprintf("  SE:            %.6f\n", sd(results_estimated)))
  if (abs(rel_bias_estimated) < 2) {
    cat("  ✓ Minimal bias\n\n")
  } else {
    cat("  ⚠ Significant bias\n\n")
  }

  cat("Nuisance Estimation Quality:\n")
  cat(sprintf("  Mean bias in h(X): %.6f\n", mean_nuisance_bias))
  cat(sprintf("  SD of bias in h(X): %.6f\n", sd(bias_nuisance)))

  # Correlation between nuisance bias and estimate bias
  cor_bias <- cor(bias_nuisance, results_estimated - truth)
  cat(sprintf("  Correlation (nuisance bias, total bias): %.4f\n\n", cor_bias))

  cat("BIAS DECOMPOSITION:\n")
  cat(sprintf("  Total bias:           %.6f (%.2f%%)\n",
              bias_estimated, rel_bias_estimated))
  cat(sprintf("  Dual/finite sample:   %.6f (%.2f%%)\n",
              bias_oracle, rel_bias_oracle))
  cat(sprintf("  Nuisance estimation:  %.6f (%.2f%%)\n",
              bias_estimated - bias_oracle,
              (bias_estimated - bias_oracle) / truth * 100))

  # Diagnosis
  cat("\nDIAGNOSIS:\n")
  nuisance_contrib <- abs(bias_estimated - bias_oracle)
  dual_contrib <- abs(bias_oracle)

  if (nuisance_contrib > 2 * dual_contrib) {
    cat("  PRIMARY ISSUE: Nuisance estimation\n")
    cat(sprintf("  - Nuisance bias is %.1fx larger than dual bias\n",
                nuisance_contrib / max(dual_contrib, 0.001)))
    cat("  - Solution: Use more flexible models, larger sample, or regularization\n")
  } else if (dual_contrib > 2 * nuisance_contrib) {
    cat("  PRIMARY ISSUE: Dual computation\n")
    cat(sprintf("  - Dual bias is %.1fx larger than nuisance bias\n",
                dual_contrib / max(nuisance_contrib, 0.001)))
    cat("  - Solution: Investigate Wasserstein dual estimation\n")
  } else {
    cat("  MIXED: Both nuisance and dual contribute to bias\n")
    cat(sprintf("  - Nuisance contribution: %.2f%%\n",
                (nuisance_contrib / abs(bias_estimated)) * 100))
    cat(sprintf("  - Dual contribution: %.2f%%\n",
                (dual_contrib / abs(bias_estimated)) * 100))
  }

  data.frame(
    d = d,
    n = n,
    n_valid = n_valid,
    truth = truth,
    bias_oracle = bias_oracle,
    bias_estimated = bias_estimated,
    bias_nuisance = bias_estimated - bias_oracle,
    rel_bias_oracle = rel_bias_oracle,
    rel_bias_estimated = rel_bias_estimated,
    mean_nuisance_bias = mean_nuisance_bias,
    cor_bias = cor_bias
  )
}

# Test dimensions 2, 3, 4, 5
cat("Testing bias sources across dimensions...\n")

results_all <- do.call(rbind, lapply(c(2, 3, 4, 5), function(d) {
  test_dimension_detailed(d, n_sims = 50, n = 500)
}))

cat("\n\n========================================\n")
cat("SUMMARY ACROSS DIMENSIONS\n")
cat("========================================\n\n")

print(results_all, digits = 4)

cat("\n========================================\n")
cat("KEY FINDINGS\n")
cat("========================================\n\n")

for (i in 1:nrow(results_all)) {
  row <- results_all[i, ]
  cat(sprintf("d=%d:\n", row$d))
  cat(sprintf("  Total bias: %.2f%%\n", row$rel_bias_estimated))
  cat(sprintf("  - From nuisance: %.2f%% (%.1f%% of total)\n",
              row$bias_nuisance / row$truth * 100,
              abs(row$bias_nuisance / row$bias_estimated) * 100))
  cat(sprintf("  - From dual: %.2f%% (%.1f%% of total)\n",
              row$rel_bias_oracle,
              abs(row$bias_oracle / row$bias_estimated) * 100))

  if (abs(row$bias_nuisance) > abs(row$bias_oracle)) {
    cat("  → Primary issue: NUISANCE ESTIMATION\n\n")
  } else {
    cat("  → Primary issue: DUAL COMPUTATION\n\n")
  }
}

# Save results
saveRDS(results_all, "high_dim_bias_diagnostic_results.rds")
cat("Results saved to: high_dim_bias_diagnostic_results.rds\n")
