#!/usr/bin/env Rscript
# Test LOO implementation for high-dimensional coverage

source("package/R/wasserstein_minimax_IF_inference.R")

set.seed(42)

cat("========================================\n")
cat("LOO IMPLEMENTATION VALIDATION\n")
cat("========================================\n\n")

# Generate data with d covariates
generate_data <- function(n, d) {
  X <- matrix(rnorm(n * d), nrow = n, ncol = d)
  colnames(X) <- paste0("X", 1:d)

  A <- rbinom(n, 1, 0.5)

  weights <- 0.2 / (2^(0:(d-1)))

  tau_S <- 0.3 + as.vector(X %*% weights) + 0.05 * X[,1]^2
  tau_Y <- 0.4 + as.vector(X %*% (1.5 * weights)) + 0.08 * X[,1]^2

  S <- A * tau_S + rnorm(n, sd = 0.5)
  Y <- A * tau_Y + rnorm(n, sd = 0.5)

  data.frame(X, A = A, S = S, Y = Y)
}

# Test configuration
test_config <- function(d, n, n_sims = 50) {
  cat(sprintf("\nTesting d=%d, n=%d (%d reps)\n", d, n, n_sims))

  # Compute approximate truth (using large sample)
  set.seed(999)
  large_data <- generate_data(10000, d)
  weights <- 0.2 / (2^(0:(d-1)))

  X_large <- as.matrix(large_data[, paste0("X", 1:d)])
  tau_S_large <- 0.3 + as.vector(X_large %*% weights) + 0.05 * X_large[,1]^2
  tau_Y_large <- 0.4 + as.vector(X_large %*% (1.5 * weights)) + 0.08 * X_large[,1]^2
  h_large <- tau_S_large * tau_Y_large

  # Compute truth with LOO
  n_large <- nrow(X_large)
  phi_j <- numeric(n_large)
  for (j in 1:n_large) {
    idx_minus_j <- setdiff(1:n_large, j)
    X_minus_j <- X_large[idx_minus_j, , drop = FALSE]
    h_minus_j <- h_large[idx_minus_j]

    costs <- rowSums((X_minus_j - matrix(X_large[j, ], nrow = n_large-1, ncol = d, byrow = TRUE))^2) / d
    values <- exp(-(h_minus_j + 0.5 * costs) / 0.1)
    m_j <- mean(values)
    phi_j[j] <- -0.1 * log(m_j)
  }
  truth <- mean(phi_j)

  cat(sprintf("Truth (LOO): %.6f\n", truth))

  # Run simulations with LOO implementation
  set.seed(123)
  results <- replicate(n_sims, {
    data <- generate_data(n, d)

    result <- tryCatch({
      wasserstein_minimax_IF_inference(
        data = data,
        covariates = paste0("X", 1:d),
        gamma = 0.5,
        tau = 0.1,
        K = 5
      )
    }, error = function(e) {
      cat("Error:", e$message, "\n")
      return(NULL)
    })

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

  cat(sprintf("Valid replications: %d/%d\n", n_valid, n_sims))
  cat(sprintf("Mean estimate: %.6f\n", mean_est))
  cat(sprintf("Bias: %.6f (%.2f%%)\n", bias, rel_bias))
  cat(sprintf("Empirical SE: %.6f\n", empirical_se))
  cat(sprintf("Mean IF SE: %.6f\n", mean_IF_se))
  cat(sprintf("Variance ratio: %.4f\n", variance_ratio))
  cat(sprintf("**COVERAGE: %.1f%%**\n", coverage * 100))

  status <- if (coverage >= 0.90 && coverage <= 0.98) "✓" else "⚠"
  cat(sprintf("%s Coverage %s target (90-98%%)\n",
              status,
              if(coverage >= 0.90 && coverage <= 0.98) "within" else "outside"))

  data.frame(
    d = d,
    n = n,
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

# Test critical configurations
cat("Testing LOO implementation...\n")
cat("Focus: d=4,5 at n=500 (where LOO should help most)\n\n")

configs <- expand.grid(
  d = c(3, 4, 5),
  n = c(500, 1000)
)

results_list <- list()
for (i in 1:nrow(configs)) {
  d <- configs$d[i]
  n <- configs$n[i]

  result <- test_config(d, n, n_sims = 50)
  results_list[[i]] <- result
}

results_all <- do.call(rbind, results_list)

cat("\n========================================\n")
cat("SUMMARY\n")
cat("========================================\n\n")

print(results_all, digits = 4)

cat("\n========================================\n")
cat("COVERAGE BY CONFIGURATION\n")
cat("========================================\n\n")

for (i in 1:nrow(results_all)) {
  row <- results_all[i, ]
  status <- if (row$coverage >= 0.90) "✓" else "⚠"

  cat(sprintf("%s d=%d, n=%d: %.1f%% coverage (bias: %+.2f%%)\n",
              status, row$d, row$n, row$coverage * 100, row$rel_bias))
}

cat("\n========================================\n")
cat("KEY FINDINGS\n")
cat("========================================\n\n")

# Compare d=5, n=500 to expected baseline
d5_n500 <- results_all[results_all$d == 5 & results_all$n == 500, ]

cat("d=5, n=500 (most challenging case):\n")
cat(sprintf("  LOO Implementation: %.1f%% coverage\n", d5_n500$coverage * 100))
cat(sprintf("  Bias: %+.2f%%\n", d5_n500$rel_bias))

if (d5_n500$coverage >= 0.85) {
  cat("  ✓ Substantial improvement from baseline (~78%)\n")
} else {
  cat("  ⚠ Coverage still below 85%\n")
}

# Check if all configs meet 90% threshold
all_good <- all(results_all$coverage >= 0.90)

cat("\nOverall:\n")
if (all_good) {
  cat("✓ ALL CONFIGURATIONS ACHIEVE 90%+ COVERAGE\n")
  cat("LOO implementation is successful!\n")
} else {
  poor_configs <- results_all[results_all$coverage < 0.90, ]
  cat(sprintf("⚠ %d/%d configurations below 90%% coverage:\n",
              nrow(poor_configs), nrow(results_all)))
  for (i in 1:nrow(poor_configs)) {
    row <- poor_configs[i, ]
    cat(sprintf("  d=%d, n=%d: %.1f%%\n", row$d, row$n, row$coverage * 100))
  }
}

# Save results
saveRDS(results_all, "loo_implementation_results.rds")
cat("\nResults saved to: loo_implementation_results.rds\n")
