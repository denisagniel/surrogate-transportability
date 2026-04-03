#!/usr/bin/env Rscript
# Quick test to verify univariate case is unchanged

source("package/R/wasserstein_minimax_IF_inference.R")

set.seed(456)

cat("========================================\n")
cat("UNIVARIATE UNCHANGED VALIDATION\n")
cat("========================================\n\n")

# Generate data with 1 covariate
generate_test_data <- function(n) {
  X <- rnorm(n)
  A <- rbinom(n, 1, 0.5)

  tau_S <- 0.3 + 0.2*X
  tau_Y <- 0.4 + 0.3*X

  S <- A*tau_S + rnorm(n, sd=0.5)
  Y <- A*tau_Y + rnorm(n, sd=0.5)

  data.frame(X=X, A=A, S=S, Y=Y)
}

# Run 50 replications to estimate coverage
cat("Running 50 replications (n=500, 1 covariate)...\n")
n_sims <- 50
results <- replicate(n_sims, {
  data <- generate_test_data(500)

  result <- tryCatch({
    wasserstein_minimax_IF_inference(
      data = data,
      covariates = "X",
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

# Compute oracle truth
large_data <- generate_test_data(10000)
X <- as.matrix(large_data[, "X", drop=FALSE])
h_oracle <- (0.3 + 0.2*large_data$X) * (0.4 + 0.3*large_data$X)
n_large <- nrow(X)
d <- ncol(X)  # Should be 1
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

# Calculate metrics
coverage <- mean(results_df[, "lower"] <= truth & results_df[, "upper"] >= truth)
mean_est <- mean(results_df[, "est"])
bias <- mean_est - truth
rel_bias <- bias / truth * 100
variance_ratio <- mean(results_df[, "se"]) / sd(results_df[, "est"])

cat("\n========================================\n")
cat("RESULTS\n")
cat("========================================\n\n")

cat(sprintf("Truth:           %.6f\n", truth))
cat(sprintf("Mean estimate:   %.6f\n", mean_est))
cat(sprintf("Bias:            %.2f%%\n", rel_bias))
cat(sprintf("Variance ratio:  %.4f\n", variance_ratio))
cat(sprintf("\n**COVERAGE:      %.1f%%**\n", coverage * 100))

cat("\n========================================\n")
if (coverage >= 0.88 && coverage <= 0.98) {
  cat("✓ UNIVARIATE COVERAGE STILL GOOD\n")
  cat("Normalization /1 has no adverse effect!\n")
} else {
  cat("⚠ UNIVARIATE COVERAGE CHANGED\n")
  cat("This is unexpected!\n")
}
cat("========================================\n")
