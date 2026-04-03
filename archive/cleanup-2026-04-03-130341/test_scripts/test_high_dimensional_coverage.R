#!/usr/bin/env Rscript
# Test coverage with 3, 4, and 5 covariates to verify dimension scaling

source("package/R/wasserstein_minimax_IF_inference.R")

set.seed(789)

cat("========================================\n")
cat("HIGH-DIMENSIONAL COVERAGE VALIDATION\n")
cat("========================================\n\n")

# Helper function to generate data with d covariates
generate_data_d_covariates <- function(n, d) {
  # Generate d covariates
  X <- matrix(rnorm(n * d), nrow = n, ncol = d)
  colnames(X) <- paste0("X", 1:d)

  A <- rbinom(n, 1, 0.5)

  # Treatment effects depend on all covariates
  # Use decreasing weights: 0.2, 0.1, 0.05, 0.025, ...
  weights <- 0.2 / (2^(0:(d-1)))

  tau_S <- 0.3 + as.vector(X %*% weights)
  tau_Y <- 0.4 + as.vector(X %*% (1.5 * weights))

  S <- A * tau_S + rnorm(n, sd = 0.5)
  Y <- A * tau_Y + rnorm(n, sd = 0.5)

  data <- data.frame(X, A = A, S = S, Y = Y)

  list(data = data, weights_S = weights, weights_Y = 1.5 * weights)
}

# Compute oracle truth
compute_truth <- function(d, weights_S, weights_Y) {
  n_large <- 10000
  X <- matrix(rnorm(n_large * d), nrow = n_large, ncol = d)
  h_oracle <- (0.3 + as.vector(X %*% weights_S)) *
              (0.4 + as.vector(X %*% weights_Y))

  gamma <- 0.5
  tau <- 0.1

  phi_j <- numeric(n_large)
  for (j in 1:n_large) {
    costs <- rowSums((X - matrix(X[j, ], nrow = n_large, ncol = d, byrow = TRUE))^2) / d
    values <- exp(-(h_oracle + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }

  mean(phi_j)
}

# Test function for a given dimension
test_dimension <- function(d, n_sims = 50) {
  cat(sprintf("\n========================================\n"))
  cat(sprintf("Testing with %d covariates\n", d))
  cat(sprintf("========================================\n\n"))

  # Generate template to get weights
  template <- generate_data_d_covariates(100, d)
  weights_S <- template$weights_S
  weights_Y <- template$weights_Y

  cat("Computing oracle truth (n=10000)...\n")
  truth <- compute_truth(d, weights_S, weights_Y)
  cat(sprintf("Oracle truth: %.6f\n\n", truth))

  cat(sprintf("Running %d replications (n=500)...\n", n_sims))

  results <- replicate(n_sims, {
    dgp <- generate_data_d_covariates(500, d)
    data <- dgp$data
    covariates <- paste0("X", 1:d)

    result <- tryCatch({
      wasserstein_minimax_IF_inference(
        data = data,
        covariates = covariates,
        gamma = 0.5,
        tau = 0.1,
        K = 5
      )
    }, error = function(e) NULL)

    if (is.null(result)) return(c(est=NA, se=NA, lower=NA, upper=NA))

    c(est = result$phi_star,
      se = result$se,
      lower = result$ci_lower,
      upper = result$ci_upper)
  }, simplify = FALSE)

  results_df <- do.call(rbind, results)
  results_df <- results_df[complete.cases(results_df), ]

  n_valid <- nrow(results_df)
  coverage <- mean(results_df[, "lower"] <= truth & results_df[, "upper"] >= truth)
  mean_est <- mean(results_df[, "est"])
  bias <- mean_est - truth
  rel_bias <- bias / truth * 100
  empirical_se <- sd(results_df[, "est"])
  mean_IF_se <- mean(results_df[, "se"])
  variance_ratio <- mean_IF_se / empirical_se

  cat("\nResults:\n")
  cat(sprintf("  Valid replications: %d/%d\n", n_valid, n_sims))
  cat(sprintf("  Truth:              %.6f\n", truth))
  cat(sprintf("  Mean estimate:      %.6f\n", mean_est))
  cat(sprintf("  Bias:               %.6f (%.2f%%)\n", bias, rel_bias))
  cat(sprintf("  Empirical SE:       %.6f\n", empirical_se))
  cat(sprintf("  Mean IF SE:         %.6f\n", mean_IF_se))
  cat(sprintf("  Variance ratio:     %.4f\n", variance_ratio))
  cat(sprintf("  **COVERAGE:         %.1f%%**\n", coverage * 100))

  status <- if (coverage >= 0.88 && coverage <= 0.98) "✓" else "⚠"
  cat(sprintf("\n%s Coverage %s target range (88-98%%)\n", status,
              if(coverage >= 0.88 && coverage <= 0.98) "within" else "outside"))

  data.frame(
    d = d,
    n_valid = n_valid,
    truth = truth,
    coverage = coverage,
    bias = bias,
    rel_bias = rel_bias,
    empirical_se = empirical_se,
    mean_IF_se = mean_IF_se,
    variance_ratio = variance_ratio
  )
}

# Test dimensions 1 through 5
cat("Testing coverage across dimensions...\n")
cat("This will take ~5-10 minutes for 50 reps × 5 dimensions\n")

results_all <- do.call(rbind, lapply(1:5, function(d) {
  test_dimension(d, n_sims = 50)
}))

cat("\n========================================\n")
cat("SUMMARY ACROSS DIMENSIONS\n")
cat("========================================\n\n")

print(results_all, digits = 4)

cat("\n========================================\n")
cat("COVERAGE BY DIMENSION\n")
cat("========================================\n\n")

for (i in 1:nrow(results_all)) {
  row <- results_all[i, ]
  status <- if (row$coverage >= 0.88 && row$coverage <= 0.98) "✓" else "⚠"
  cat(sprintf("%s d=%d: %.1f%% coverage (bias: %.2f%%, var_ratio: %.3f)\n",
              status, row$d, row$coverage * 100, row$rel_bias, row$variance_ratio))
}

cat("\n========================================\n")
all_good <- all(results_all$coverage >= 0.88 & results_all$coverage <= 0.98)
if (all_good) {
  cat("✓ ALL DIMENSIONS SHOW GOOD COVERAGE\n")
  cat("Dimension normalization works correctly!\n")
} else {
  bad_dims <- results_all$d[results_all$coverage < 0.88 | results_all$coverage > 0.98]
  cat(sprintf("⚠ Coverage issues at dimensions: %s\n", paste(bad_dims, collapse = ", ")))
}
cat("========================================\n")

# Save results
saveRDS(results_all, "high_dimensional_coverage_results.rds")
cat("\nResults saved to: high_dimensional_coverage_results.rds\n")
