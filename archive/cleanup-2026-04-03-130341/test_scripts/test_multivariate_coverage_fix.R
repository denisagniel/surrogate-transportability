#!/usr/bin/env Rscript
# Quick test to verify multivariate coverage fix

source("package/R/wasserstein_minimax_IF_inference.R")

set.seed(123)

cat("========================================\n")
cat("MULTIVARIATE COVERAGE FIX VALIDATION\n")
cat("========================================\n\n")

# Generate data with 2 covariates
generate_test_data <- function(n) {
  X1 <- rnorm(n)
  X2 <- rnorm(n)
  A <- rbinom(n, 1, 0.5)

  tau_S <- 0.3 + 0.2*X1 + 0.1*X2
  tau_Y <- 0.4 + 0.3*X1 + 0.15*X2

  S <- A*tau_S + rnorm(n, sd=0.5)
  Y <- A*tau_Y + rnorm(n, sd=0.5)

  data.frame(X1=X1, X2=X2, A=A, S=S, Y=Y)
}

# Compute oracle truth with large sample
cat("Computing oracle truth (large sample)...\n")
large_data <- generate_test_data(10000)
X <- as.matrix(large_data[, c("X1", "X2")])
h_oracle <- (0.3 + 0.2*large_data$X1 + 0.1*large_data$X2) *
            (0.4 + 0.3*large_data$X1 + 0.15*large_data$X2)
n_large <- nrow(X)
d <- ncol(X)
gamma <- 0.5
tau <- 0.1

phi_j <- numeric(n_large)
for (j in 1:n_large) {
  costs <- rowSums((X - matrix(X[j, ], nrow = n_large, ncol = ncol(X), byrow = TRUE))^2) / d
  values <- exp(-(h_oracle + gamma * costs) / tau)
  m_j <- mean(values)
  phi_j[j] <- -tau * log(m_j)
}
truth <- mean(phi_j)
cat(sprintf("Oracle truth: %.6f\n\n", truth))

# Run 100 replications to estimate coverage
cat("Running 100 replications (n=500, 2 covariates)...\n")
n_sims <- 100
results <- replicate(n_sims, {
  data <- generate_test_data(500)

  result <- tryCatch({
    wasserstein_minimax_IF_inference(
      data = data,
      covariates = c("X1", "X2"),
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

# Calculate metrics
coverage <- mean(results_df[, "lower"] <= truth & results_df[, "upper"] >= truth)
mean_est <- mean(results_df[, "est"])
bias <- mean_est - truth
rel_bias <- bias / truth * 100
empirical_se <- sd(results_df[, "est"])
mean_IF_se <- mean(results_df[, "se"])
variance_ratio <- mean_IF_se / empirical_se

cat("\n========================================\n")
cat("RESULTS\n")
cat("========================================\n\n")

cat(sprintf("Truth:           %.6f\n", truth))
cat(sprintf("Mean estimate:   %.6f\n", mean_est))
cat(sprintf("Bias:            %.6f (%.2f%%)\n", bias, rel_bias))
cat(sprintf("Empirical SE:    %.6f\n", empirical_se))
cat(sprintf("Mean IF SE:      %.6f\n", mean_IF_se))
cat(sprintf("Variance ratio:  %.4f\n", variance_ratio))
cat(sprintf("\n**COVERAGE:      %.1f%%**\n", coverage * 100))

cat("\n========================================\n")
if (coverage >= 0.92 && coverage <= 0.98) {
  cat("✓ COVERAGE WITHIN TARGET RANGE (92-98%)\n")
  cat("Fix appears successful!\n")
} else {
  cat("⚠ COVERAGE OUTSIDE TARGET RANGE\n")
  cat("Expected: 92-98%, Got: %.1f%%\n", coverage * 100)
}
cat("========================================\n")
