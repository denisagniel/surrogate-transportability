#!/usr/bin/env Rscript
# Diagnose why dual has bias with oracle nuisances in high dimensions
# Test: Does bias persist with larger n?

source("package/R/wasserstein_minimax_IF_inference.R")

set.seed(1234)

cat("========================================\n")
cat("DUAL BIAS DIAGNOSTIC (Oracle Nuisances)\n")
cat("========================================\n\n")

# Generate data with known h
generate_oracle_data <- function(n, d) {
  X <- matrix(rnorm(n * d), nrow = n, ncol = d)
  weights <- 0.2 / (2^(0:(d-1)))

  h_true <- (0.3 + as.vector(X %*% weights)) *
            (0.4 + as.vector(X %*% (1.5 * weights)))

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

# Estimate dual with oracle h
estimate_dual_oracle <- function(X, h_true, gamma = 0.5, tau = 0.1) {
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

# Test dimension x sample size combinations
test_config <- function(d, n, n_sims = 100) {
  # Get truth
  template <- generate_oracle_data(100, d)
  truth <- compute_truth(d, template$weights_S, template$weights_Y)

  # Run simulations
  estimates <- replicate(n_sims, {
    dgp <- generate_oracle_data(n, d)
    estimate_dual_oracle(dgp$X, dgp$h_true)
  })

  bias <- mean(estimates) - truth
  rel_bias <- bias / truth * 100
  se <- sd(estimates)

  data.frame(
    d = d,
    n = n,
    truth = truth,
    mean_est = mean(estimates),
    bias = bias,
    rel_bias = rel_bias,
    se = se,
    n_sims = n_sims
  )
}

# Test grid: dimensions 2-5, sample sizes 200-2000
cat("Testing dual bias with oracle nuisances...\n")
cat("Dimensions: 2, 3, 4, 5\n")
cat("Sample sizes: 200, 500, 1000, 2000\n\n")

configs <- expand.grid(
  d = c(2, 3, 4, 5),
  n = c(200, 500, 1000, 2000)
)

results_list <- list()
for (i in 1:nrow(configs)) {
  d <- configs$d[i]
  n <- configs$n[i]

  cat(sprintf("d=%d, n=%d ... ", d, n))
  start_time <- Sys.time()

  result <- test_config(d, n, n_sims = 100)
  results_list[[i]] <- result

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  cat(sprintf("done (%.1f sec, bias: %.2f%%)\n", elapsed, result$rel_bias))
}

results_all <- do.call(rbind, results_list)

cat("\n========================================\n")
cat("RESULTS: DUAL BIAS BY DIMENSION & N\n")
cat("========================================\n\n")

print(results_all, digits = 4)

cat("\n========================================\n")
cat("BIAS BY DIMENSION (n=500)\n")
cat("========================================\n\n")

results_n500 <- results_all[results_all$n == 500, ]
for (i in 1:nrow(results_n500)) {
  row <- results_n500[i, ]
  status <- if (abs(row$rel_bias) < 1.5) "✓" else "⚠"
  cat(sprintf("%s d=%d: bias = %.2f%%, SE = %.4f\n",
              status, row$d, row$rel_bias, row$se))
}

cat("\n========================================\n")
cat("SAMPLE SIZE EFFECT (d=5)\n")
cat("========================================\n\n")

results_d5 <- results_all[results_all$d == 5, ]
for (i in 1:nrow(results_d5)) {
  row <- results_d5[i, ]
  status <- if (abs(row$rel_bias) < 1.5) "✓" else "⚠"
  cat(sprintf("%s n=%d: bias = %.2f%%, SE = %.4f\n",
              status, row$n, row$rel_bias, row$se))
}

cat("\n========================================\n")
cat("KEY FINDINGS\n")
cat("========================================\n\n")

# Check if bias decreases with n
for (d in unique(results_all$d)) {
  cat(sprintf("Dimension d=%d:\n", d))
  subset_d <- results_all[results_all$d == d, ]
  subset_d <- subset_d[order(subset_d$n), ]

  biases <- abs(subset_d$rel_bias)
  improving <- all(diff(biases) <= 0)

  cat(sprintf("  n=200: %.2f%% → n=2000: %.2f%%\n",
              subset_d$rel_bias[1], subset_d$rel_bias[nrow(subset_d)]))

  if (improving && abs(subset_d$rel_bias[nrow(subset_d)]) < 1) {
    cat("  ✓ Bias decreases with n and becomes negligible\n")
  } else if (improving) {
    cat("  ✓ Bias decreases with n but remains non-negligible\n")
  } else {
    cat("  ⚠ Bias does NOT consistently decrease with n\n")
  }
  cat("\n")
}

# Diagnosis
cat("DIAGNOSIS:\n")
cat("----------\n\n")

max_bias_small <- max(abs(results_all$rel_bias[results_all$n == 500 & results_all$d <= 3]))
max_bias_large <- max(abs(results_all$rel_bias[results_all$n == 2000]))

if (max_bias_large < 1.5) {
  cat("✓ DUAL BIAS IS FINITE SAMPLE ISSUE\n")
  cat("  - Bias becomes negligible with larger n\n")
  cat("  - Cost normalization is working correctly\n")
  cat("  - Solution: Use n ≥ 1000 for d ≥ 4, or n ≥ 200d as rule of thumb\n")
} else if (max_bias_small < 1.5) {
  cat("✓ DUAL BIAS ONLY ISSUE FOR d ≥ 4\n")
  cat("  - Low dimensions (d ≤ 3) work well even at n=500\n")
  cat("  - High dimensions need larger samples\n")
  cat("  - Solution: Document sample size requirements by dimension\n")
} else {
  cat("⚠ DUAL HAS SYSTEMATIC BIAS\n")
  cat("  - Bias persists even at larger n\n")
  cat("  - May indicate deeper issue with dimension scaling\n")
  cat("  - Further investigation needed\n")
}

# Save results
saveRDS(results_all, "dual_bias_diagnostic_results.rds")
cat("\nResults saved to: dual_bias_diagnostic_results.rds\n")
