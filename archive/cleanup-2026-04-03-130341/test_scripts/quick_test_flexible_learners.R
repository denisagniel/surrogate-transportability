#!/usr/bin/env Rscript
# Quick test: Do flexible learners help with d=5?

library(mgcv)
source("package/R/wasserstein_minimax_IF_inference.R")

set.seed(42)

cat("========================================\n")
cat("QUICK TEST: Flexible Learners for d=5\n")
cat("========================================\n\n")

# Generate data
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

# GAM-based estimation
estimate_with_gam <- function(data, covariates, gamma = 0.5, tau = 0.1, K = 5) {
  n <- nrow(data)
  fold_ids <- sample(rep(1:K, length.out = n))

  all_phi <- numeric(K)
  all_IF <- numeric(n)

  for (k in 1:K) {
    test_idx <- which(fold_ids == k)
    train_idx <- which(fold_ids != k)

    train_data <- data[train_idx, ]
    test_data <- data[test_idx, ]

    # GAM formulas
    smooth_terms <- paste0("s(", covariates, ")")
    formula_S <- as.formula(paste("S ~", paste(smooth_terms, collapse = " + "), "+ A"))
    formula_Y <- as.formula(paste("Y ~", paste(smooth_terms, collapse = " + "), "+ A"))

    fit_S <- gam(formula_S, data = train_data)
    fit_Y <- gam(formula_Y, data = train_data)

    test_A1 <- test_data; test_A1$A <- 1
    test_A0 <- test_data; test_A0$A <- 0

    tau_S_hat <- predict(fit_S, newdata = test_A1) - predict(fit_S, newdata = test_A0)
    tau_Y_hat <- predict(fit_Y, newdata = test_A1) - predict(fit_Y, newdata = test_A0)
    h_hat <- tau_S_hat * tau_Y_hat

    nuisances <- list(
      tau_S_hat = tau_S_hat,
      tau_Y_hat = tau_Y_hat,
      h_hat = h_hat,
      mu_S1_hat = predict(fit_S, newdata = test_A1),
      mu_S0_hat = predict(fit_S, newdata = test_A0),
      mu_Y1_hat = predict(fit_Y, newdata = test_A1),
      mu_Y0_hat = predict(fit_Y, newdata = test_A0)
    )

    phi_k <- estimate_dual_fold_wasserstein(test_data, h_hat, covariates, gamma, tau)
    all_phi[k] <- phi_k

    IF_k <- compute_IF_fold_wasserstein(test_data, nuisances, covariates, gamma, tau)
    IF_k <- IF_k - mean(IF_k)
    all_IF[test_idx] <- IF_k
  }

  phi_star <- mean(all_phi)
  se <- sqrt(mean(all_IF^2) / n)

  list(
    phi_star = phi_star,
    se = se,
    ci_lower = phi_star - 1.96 * se,
    ci_upper = phi_star + 1.96 * se
  )
}

# Quick test with 20 reps
cat("Testing d=5, n=1000 (20 replications)\n")
cat("Comparing Linear vs GAM\n\n")

# Compute truth
truth <- 0.557  # Approximate from previous tests

results_linear <- replicate(20, {
  data <- generate_data(1000, 5)
  result <- tryCatch({
    wasserstein_minimax_IF_inference(data, paste0("X", 1:5), gamma = 0.5, tau = 0.1, K = 5)
  }, error = function(e) NULL)
  if (is.null(result)) return(NA)
  c(result$phi_star, result$ci_lower, result$ci_upper)
})

results_gam <- replicate(20, {
  data <- generate_data(1000, 5)
  result <- tryCatch({
    estimate_with_gam(data, paste0("X", 1:5), gamma = 0.5, tau = 0.1, K = 5)
  }, error = function(e) NULL)
  if (is.null(result)) return(NA)
  c(result$phi_star, result$ci_lower, result$ci_upper)
})

# Analyze
results_linear <- t(results_linear)
results_gam <- t(results_gam)

results_linear <- results_linear[complete.cases(results_linear), ]
results_gam <- results_gam[complete.cases(results_gam), ]

coverage_linear <- mean(results_linear[,2] <= truth & results_linear[,3] >= truth)
coverage_gam <- mean(results_gam[,2] <= truth & results_gam[,3] >= truth)

bias_linear <- mean(results_linear[,1]) - truth
bias_gam <- mean(results_gam[,1]) - truth

cat("RESULTS:\n")
cat("--------\n\n")

cat("LINEAR:\n")
cat(sprintf("  Coverage: %.1f%%\n", coverage_linear * 100))
cat(sprintf("  Bias: %.2f%%\n", bias_linear / truth * 100))
cat(sprintf("  Mean estimate: %.4f (truth: %.4f)\n\n", mean(results_linear[,1]), truth))

cat("GAM:\n")
cat(sprintf("  Coverage: %.1f%%\n", coverage_gam * 100))
cat(sprintf("  Bias: %.2f%%\n", bias_gam / truth * 100))
cat(sprintf("  Mean estimate: %.4f (truth: %.4f)\n\n", mean(results_gam[,1]), truth))

cat("IMPROVEMENT:\n")
improvement <- (coverage_gam - coverage_linear) * 100
cat(sprintf("  Coverage: %+.1f percentage points\n", improvement))

bias_reduction <- abs(bias_gam) - abs(bias_linear)
cat(sprintf("  Bias: %+.2f%% (%.1fx reduction)\n",
            bias_reduction / truth * 100,
            abs(bias_linear) / abs(bias_gam)))

cat("\n")
if (coverage_gam >= 0.90 && coverage_linear < 0.80) {
  cat("✓ GAM substantially improves coverage!\n")
} else if (coverage_gam > coverage_linear) {
  cat("✓ GAM shows improvement\n")
} else {
  cat("⚠ No clear improvement from GAM\n")
}
