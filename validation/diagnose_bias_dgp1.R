# Diagnose Bias and Coverage Issues in DGP 1
#
# Observed issues:
# 1. Negative bias: -0.076 (-11%)
# 2. Undercoverage: 89.5% vs 95%
# 3. SE calibration OK: 1.09
#
# Potential causes:
# - Small sample size (n=5000) → poor CATE estimation in rare strata
# - Too few Q samples (M=500)
# - Importance weights creating bias
# - MCMC not fully converged

library(dplyr)
library(ggplot2)

devtools::load_all()
source("explorations/calibrate_5level_x_dgp.R")

# =============================================================================
# Load Results
# =============================================================================

cat("\n=== Diagnosing Bias and Coverage Issues (DGP 1) ===\n\n")

results_main <- readRDS("validation/results/importance_weighting_vs_truth.rds")
results_true <- readRDS("validation/results/true_correlation_5level.rds")

rho_true <- results_true$true_correlation
tau_S_true <- results_true$tau_S
tau_Y_true <- results_true$tau_Y

cat(sprintf("TRUE correlation: ρ = %.6f\n\n", rho_true))

# Main results
cat("Main Results (n=5000, M=500):\n")
cat(sprintf("  Mean ρ̂ = %.4f\n", mean(results_main$results$rho_hat)))
cat(sprintf("  Bias = %.4f (%.1f%%)\n", results_main$summary$bias,
            100 * results_main$summary$bias / rho_true))
cat(sprintf("  Coverage = %.1f%%\n\n", 100 * results_main$summary$coverage))

# =============================================================================
# Hypothesis 1: Sample Size Too Small → Poor CATE Estimation
# =============================================================================

cat("=== Hypothesis 1: Poor CATE Estimation (n=5000 too small) ===\n\n")

params <- list(
  gamma_A = 1.0,
  gamma_AX = 0.5,
  beta_A = 0.25,
  beta_AX = -0.3,
  beta_S = 0.9,
  beta_SX = -0.1,
  sigma_S = 0.5,
  sigma_Y = 0.5
)

p_X_0 <- c(0.05, 0.25, 0.40, 0.25, 0.05)
X_levels <- c(-2, -1, 0, 1, 2)
K <- 5

# Compare CATE estimation quality at different sample sizes
sample_sizes <- c(2500, 5000, 10000, 20000)
set.seed(2026)

cat("CATE Estimation Quality by Sample Size:\n\n")
cat(sprintf("%-8s %-8s %-12s %-12s %-12s %-12s\n",
            "n", "Stratum", "n_stratum", "τ_S bias", "τ_Y bias", "Combined bias"))
cat(strrep("-", 70), "\n")

for (n in sample_sizes) {
  data <- generate_5level_x_data(n = n, p_X = p_X_0, params = params)

  # Estimate CATEs
  tau_S_est <- numeric(K)
  tau_Y_est <- numeric(K)
  n_strata <- numeric(K)

  for (k in 1:K) {
    data_k <- data[data$X == X_levels[k], ]
    n_strata[k] <- nrow(data_k)
    tau_S_est[k] <- mean(data_k$S[data_k$A == 1]) - mean(data_k$S[data_k$A == 0])
    tau_Y_est[k] <- mean(data_k$Y[data_k$A == 1]) - mean(data_k$Y[data_k$A == 0])
  }

  # Bias in CATEs
  bias_S <- tau_S_est - tau_S_true
  bias_Y <- tau_Y_est - tau_Y_true
  combined_bias <- sqrt(bias_S^2 + bias_Y^2)

  for (k in 1:K) {
    cat(sprintf("%-8d %-8s %-12d %-12.4f %-12.4f %-12.4f\n",
                n, sprintf("X=%d", X_levels[k]), n_strata[k],
                bias_S[k], bias_Y[k], combined_bias[k]))
  }
  cat("\n")
}

cat("Key observation: Check if rare strata (X=-2, X=2) have large CATE bias\n")
cat("that could propagate to correlation estimate.\n\n")

# =============================================================================
# Hypothesis 2: M Too Small → Not Capturing Full TV Ball
# =============================================================================

cat("=== Hypothesis 2: M=500 Too Small for TV Ball ===\n\n")

# Test with different M values
M_values <- c(100, 300, 500, 1000, 2000)
lambda <- results_true$lambda

cat("Correlation Estimates vs Number of Q Samples:\n\n")
cat(sprintf("%-8s %-12s %-12s\n", "M", "Mean ρ̂", "Bias"))
cat(strrep("-", 35), "\n")

set.seed(2028)

for (M in M_values) {
  # Generate one dataset
  data_test <- generate_5level_x_data(n = 5000, p_X = p_X_0, params = params)

  # Run with different M
  result <- tv_ball_correlation_IF_v2(
    data = data_test,
    lambda = lambda,
    M = M,
    burn_in = 500,
    thin = 5,
    method = "importance_weighting",
    verbose = FALSE
  )

  bias_M <- result$rho_hat - rho_true

  cat(sprintf("%-8d %-12.4f %-12.4f\n", M, result$rho_hat, bias_M))
}

cat("\nKey observation: Does bias decrease as M increases?\n")
cat("If yes, M=500 may be too small.\n\n")

# =============================================================================
# Hypothesis 3: Importance Weights Creating Bias
# =============================================================================

cat("=== Hypothesis 3: Extreme Importance Weights ===\n\n")

# Generate one dataset and look at weight distribution
set.seed(2029)
data_test <- generate_5level_x_data(n = 5000, p_X = p_X_0, params = params)

# Sample one Q far from P0
Q_samples <- sample_tv_ball(
  P0 = p_X_0,
  lambda = lambda,
  M = 10,
  burn_in = 500,
  thin = 5,
  verbose = FALSE
)

cat("Distribution of Importance Weights:\n\n")
cat(sprintf("%-10s %-12s %-12s %-12s\n", "Q index", "Max weight", "Mean weight", "% extreme"))
cat(strrep("-", 50), "\n")

for (m in 1:10) {
  Q_m <- Q_samples[m, ]

  # Compute weights
  w_i <- numeric(nrow(data_test))
  for (i in 1:nrow(data_test)) {
    k_i <- which(X_levels == data_test$X[i])
    w_i[i] <- Q_m[k_i] / p_X_0[k_i]
  }

  max_w <- max(w_i)
  mean_w <- mean(w_i)
  pct_extreme <- 100 * mean(w_i > 3)  # Weights > 3

  cat(sprintf("%-10d %-12.2f %-12.2f %-12.1f%%\n", m, max_w, mean_w, pct_extreme))
}

cat("\nKey observation: Are weights extremely large (>5) frequently?\n")
cat("Large weights can amplify estimation noise.\n\n")

# =============================================================================
# Hypothesis 4: Bias Varies by CI Width
# =============================================================================

cat("=== Hypothesis 4: Relationship Between Bias and Uncertainty ===\n\n")

df_results <- results_main$results
df_results$ci_width <- df_results$ci_upper - df_results$ci_lower
df_results$bias <- df_results$rho_hat - rho_true

# Quartiles of SE
se_quartiles <- quantile(df_results$se, c(0.25, 0.5, 0.75))

cat("Bias by SE Quartile:\n\n")
cat(sprintf("%-20s %-12s %-12s\n", "SE Range", "Mean Bias", "Coverage"))
cat(strrep("-", 45), "\n")

q1 <- df_results$se <= se_quartiles[1]
q2 <- df_results$se > se_quartiles[1] & df_results$se <= se_quartiles[2]
q3 <- df_results$se > se_quartiles[2] & df_results$se <= se_quartiles[3]
q4 <- df_results$se > se_quartiles[3]

for (q in list(q1, q2, q3, q4)) {
  mean_bias <- mean(df_results$bias[q])
  coverage <- mean(df_results$contains_truth[q])
  se_range <- sprintf("[%.3f, %.3f]", min(df_results$se[q]), max(df_results$se[q]))

  cat(sprintf("%-20s %-12.4f %-12.1f%%\n", se_range, mean_bias, 100 * coverage))
}

cat("\nKey observation: Is bias worse when SE is high?\n")
cat("This would suggest estimation quality issues.\n\n")

# =============================================================================
# Summary and Recommendations
# =============================================================================

cat("=== Summary ===\n\n")

cat("Possible causes of bias and undercoverage:\n\n")

cat("1. **Sample size (n=5000)**\n")
cat("   - Rare strata (X=-2, X=2) have only ~250 obs each\n")
cat("   - Poor CATE estimation → biased correlation\n")
cat("   → Test: Run with n=10000 or n=20000\n\n")

cat("2. **M too small (M=500)**\n")
cat("   - May not fully explore TV ball\n")
cat("   → Test: Run with M=1000 or M=2000\n\n")

cat("3. **Extreme importance weights**\n")
cat("   - When Q far from P₀, weights can be 5-10x\n")
cat("   - Amplifies estimation noise\n")
cat("   → Consider: Trimming extreme weights or using bootstrap\n\n")

cat("4. **Non-normality**\n")
cat("   - Even with good SE calibration, distribution may be skewed\n")
cat("   → Test: Bootstrap CIs instead of normal approximation\n\n")

cat("=== COMPLETE ===\n")
