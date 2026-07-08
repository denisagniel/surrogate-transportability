# CATE Validation for Discrete X DGP
#
# Purpose: Validate that with large sample sizes (n=2000+), we can estimate
# CATEs accurately by stratification before testing aggregation methods.
#
# Context: Previous empirical findings suggested importance weighting gave
# near-perfect correlation (0.95+) while true correlation was much lower (0.47-0.66).
# Hypothesis: Poor CATE estimation in small samples, not the importance weighting
# approach itself.
#
# Strategy: Use n=2000+ to ensure adequate observations in each stratum.

library(dplyr)
library(ggplot2)

# Source the 5-level X DGP generator
source("explorations/calibrate_5level_x_dgp.R")

# =============================================================================
# DGP Parameters (from calibrate_5level_x_dgp.R)
# =============================================================================

params <- list(
  gamma_A = 1.0,      # Baseline treatment effect on S
  gamma_AX = 0.5,     # A×X interaction for S
  beta_A = 0.25,      # Direct effect of A on Y
  beta_AX = -0.3,     # Direct A×X interaction
  beta_S = 0.9,       # Mediation (S→Y)
  beta_SX = -0.1,     # S×X interaction
  sigma_S = 0.5,      # Error SD for S
  sigma_Y = 0.5       # Error SD for Y
)

# Reference distribution P₀
p_X_0 <- c(0.05, 0.25, 0.40, 0.25, 0.05)
X_levels <- c(-2, -1, 0, 1, 2)
K <- length(X_levels)

cat("\n=== CATE Validation Study ===\n")
cat(sprintf("Reference distribution P₀: [%.2f, %.2f, %.2f, %.2f, %.2f]\n",
            p_X_0[1], p_X_0[2], p_X_0[3], p_X_0[4], p_X_0[5]))
cat(sprintf("X levels: [%d, %d, %d, %d, %d]\n",
            X_levels[1], X_levels[2], X_levels[3], X_levels[4], X_levels[5]))

# =============================================================================
# Step 1: Compute Population CATEs (True Values)
# =============================================================================

cat("\n--- Step 1: Computing Population CATEs ---\n")

# Generate very large sample to estimate population CATEs
n_large <- 100000
cat(sprintf("Generating n=%d observations for population estimates...\n", n_large))

set.seed(2026)
data_large <- generate_5level_x_data(n = n_large, p_X = p_X_0, params = params)

# Compute population CATEs by stratification
tau_S_population <- numeric(K)
tau_Y_population <- numeric(K)

for (k in 1:K) {
  x_k <- X_levels[k]
  data_k <- data_large[data_large$X == x_k, ]

  tau_S_population[k] <- mean(data_k$S[data_k$A == 1]) -
                          mean(data_k$S[data_k$A == 0])
  tau_Y_population[k] <- mean(data_k$Y[data_k$A == 1]) -
                          mean(data_k$Y[data_k$A == 0])
}

cat("\nPopulation CATEs (true values):\n")
for (k in 1:K) {
  cat(sprintf("  X=%2d: τ_S = %.4f, τ_Y = %.4f\n",
              X_levels[k], tau_S_population[k], tau_Y_population[k]))
}

# =============================================================================
# Step 2: Test CATE Estimation with n=2000
# =============================================================================

cat("\n--- Step 2: Testing CATE Estimation with n=2000 ---\n")

n_test <- 2000
cat(sprintf("Generating n=%d observations for CATE estimation...\n", n_test))

set.seed(2027)
data_test <- generate_5level_x_data(n = n_test, p_X = p_X_0, params = params)

# Count observations per stratum
n_per_stratum <- table(data_test$X)
cat("\nObservations per stratum (n=2000, P₀):\n")
for (k in 1:K) {
  x_k <- X_levels[k]
  n_k <- sum(data_test$X == x_k)
  expected_n <- p_X_0[k] * n_test
  cat(sprintf("  X=%2d: n=%4d (expected: %.0f, actual: %.2f%%)\n",
              x_k, n_k, expected_n, 100 * n_k / n_test))
}

# Estimate CATEs by stratification
tau_S_empirical <- numeric(K)
tau_Y_empirical <- numeric(K)
se_S_empirical <- numeric(K)
se_Y_empirical <- numeric(K)

cat("\nEmpirical CATEs vs Population:\n")
cat(sprintf("%-5s %8s %8s %8s %8s %8s %8s %8s\n",
            "X", "τ_S_pop", "τ_S_emp", "Bias_S", "τ_Y_pop", "τ_Y_emp", "Bias_Y", "n"))
cat(strrep("-", 70), "\n")

for (k in 1:K) {
  x_k <- X_levels[k]
  data_k <- data_test[data_test$X == x_k, ]
  n_k <- nrow(data_k)

  # Empirical CATEs
  tau_S_empirical[k] <- mean(data_k$S[data_k$A == 1]) -
                         mean(data_k$S[data_k$A == 0])
  tau_Y_empirical[k] <- mean(data_k$Y[data_k$A == 1]) -
                         mean(data_k$Y[data_k$A == 0])

  # Standard errors (for reference)
  var_S1 <- var(data_k$S[data_k$A == 1])
  var_S0 <- var(data_k$S[data_k$A == 0])
  n1 <- sum(data_k$A == 1)
  n0 <- sum(data_k$A == 0)
  se_S_empirical[k] <- sqrt(var_S1 / n1 + var_S0 / n0)

  var_Y1 <- var(data_k$Y[data_k$A == 1])
  var_Y0 <- var(data_k$Y[data_k$A == 0])
  se_Y_empirical[k] <- sqrt(var_Y1 / n1 + var_Y0 / n0)

  # Bias
  bias_S <- tau_S_empirical[k] - tau_S_population[k]
  bias_Y <- tau_Y_empirical[k] - tau_Y_population[k]

  cat(sprintf("%2d    %8.4f %8.4f %8.4f %8.4f %8.4f %8.4f %4d\n",
              x_k,
              tau_S_population[k], tau_S_empirical[k], bias_S,
              tau_Y_population[k], tau_Y_empirical[k], bias_Y,
              n_k))
}

# =============================================================================
# Step 3: Assess CATE Estimation Quality
# =============================================================================

cat("\n--- Step 3: CATE Estimation Quality Assessment ---\n")

# Compute biases
bias_S <- tau_S_empirical - tau_S_population
bias_Y <- tau_Y_empirical - tau_Y_population

# Root mean squared bias
rmsb_S <- sqrt(mean(bias_S^2))
rmsb_Y <- sqrt(mean(bias_Y^2))

# Maximum absolute bias
max_bias_S <- max(abs(bias_S))
max_bias_Y <- max(abs(bias_Y))

cat(sprintf("Root Mean Squared Bias (RMSB):\n"))
cat(sprintf("  τ_S: %.4f\n", rmsb_S))
cat(sprintf("  τ_Y: %.4f\n", rmsb_Y))

cat(sprintf("\nMaximum Absolute Bias:\n"))
cat(sprintf("  τ_S: %.4f (stratum %d)\n", max_bias_S, X_levels[which.max(abs(bias_S))]))
cat(sprintf("  τ_Y: %.4f (stratum %d)\n", max_bias_Y, X_levels[which.max(abs(bias_Y))]))

# Success criterion: |bias| < 0.2 for all strata
success_S <- all(abs(bias_S) < 0.2)
success_Y <- all(abs(bias_Y) < 0.2)

cat(sprintf("\nSuccess Criteria (|bias| < 0.2 for all strata):\n"))
cat(sprintf("  τ_S: %s\n", ifelse(success_S, "PASS ✓", "FAIL ✗")))
cat(sprintf("  τ_Y: %s\n", ifelse(success_Y, "PASS ✓", "FAIL ✗")))

if (success_S && success_Y) {
  cat("\n✓ CATEs are well-estimated with n=2000.\n")
  cat("  Proceeding with three-method comparison is appropriate.\n")
} else {
  cat("\n✗ CATEs are poorly estimated even with n=2000.\n")
  cat("  Consider increasing n further or investigating DGP properties.\n")
}

# =============================================================================
# Step 4: Visualization
# =============================================================================

cat("\n--- Step 4: Generating Diagnostic Plots ---\n")

# Create results data frame for plotting
results <- data.frame(
  X = X_levels,
  tau_S_pop = tau_S_population,
  tau_S_emp = tau_S_empirical,
  tau_Y_pop = tau_Y_population,
  tau_Y_emp = tau_Y_empirical,
  bias_S = bias_S,
  bias_Y = bias_Y,
  se_S = se_S_empirical,
  se_Y = se_Y_empirical,
  n = as.numeric(n_per_stratum)
)

# Plot 1: Empirical vs Population CATEs for S
p1 <- ggplot(results, aes(x = X)) +
  geom_line(aes(y = tau_S_pop), color = "black", linewidth = 1) +
  geom_point(aes(y = tau_S_pop), color = "black", size = 3, shape = 19) +
  geom_line(aes(y = tau_S_emp), color = "blue", linewidth = 1, linetype = "dashed") +
  geom_point(aes(y = tau_S_emp), color = "blue", size = 3, shape = 17) +
  geom_errorbar(aes(ymin = tau_S_emp - 1.96 * se_S,
                     ymax = tau_S_emp + 1.96 * se_S),
                color = "blue", width = 0.2, alpha = 0.5) +
  labs(title = "CATE Estimation: Surrogate (S)",
       subtitle = sprintf("n=%d, K=%d strata", n_test, K),
       x = "Covariate X",
       y = "Treatment Effect on S") +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

# Plot 2: Empirical vs Population CATEs for Y
p2 <- ggplot(results, aes(x = X)) +
  geom_line(aes(y = tau_Y_pop), color = "black", linewidth = 1) +
  geom_point(aes(y = tau_Y_pop), color = "black", size = 3, shape = 19) +
  geom_line(aes(y = tau_Y_emp), color = "red", linewidth = 1, linetype = "dashed") +
  geom_point(aes(y = tau_Y_emp), color = "red", size = 3, shape = 17) +
  geom_errorbar(aes(ymin = tau_Y_emp - 1.96 * se_Y,
                     ymax = tau_Y_emp + 1.96 * se_Y),
                color = "red", width = 0.2, alpha = 0.5) +
  labs(title = "CATE Estimation: Outcome (Y)",
       subtitle = sprintf("n=%d, K=%d strata", n_test, K),
       x = "Covariate X",
       y = "Treatment Effect on Y") +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

# Plot 3: Bias by stratum
results_long <- tidyr::pivot_longer(
  results,
  cols = c(bias_S, bias_Y),
  names_to = "outcome",
  values_to = "bias"
)
results_long$outcome <- factor(results_long$outcome,
                                levels = c("bias_S", "bias_Y"),
                                labels = c("Surrogate (S)", "Outcome (Y)"))

p3 <- ggplot(results_long, aes(x = X, y = bias, fill = outcome)) +
  geom_col(position = "dodge", alpha = 0.7) +
  geom_hline(yintercept = c(-0.2, 0.2), linetype = "dashed", color = "gray50") +
  geom_hline(yintercept = 0, color = "black") +
  labs(title = "CATE Estimation Bias by Stratum",
       subtitle = sprintf("n=%d, threshold: |bias| < 0.2", n_test),
       x = "Covariate X",
       y = "Bias (Empirical - Population)",
       fill = "Outcome") +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"),
        legend.position = "bottom")

# Save plots
dir.create("validation/figures", showWarnings = FALSE, recursive = TRUE)

ggsave("validation/figures/cate_validation_S.pdf", p1, width = 8, height = 6)
ggsave("validation/figures/cate_validation_Y.pdf", p2, width = 8, height = 6)
ggsave("validation/figures/cate_validation_bias.pdf", p3, width = 8, height = 6)

cat("Plots saved to validation/figures/\n")

# =============================================================================
# Step 5: Sample Size Sensitivity
# =============================================================================

cat("\n--- Step 5: Sample Size Sensitivity Analysis ---\n")

# Test multiple sample sizes
n_values <- c(500, 1000, 2000, 5000, 10000)
sensitivity_results <- list()

for (i in seq_along(n_values)) {
  n_i <- n_values[i]
  cat(sprintf("\nTesting n=%d...\n", n_i))

  set.seed(2028 + i)
  data_i <- generate_5level_x_data(n = n_i, p_X = p_X_0, params = params)

  # Estimate CATEs
  bias_S_i <- numeric(K)
  bias_Y_i <- numeric(K)

  for (k in 1:K) {
    x_k <- X_levels[k]
    data_k <- data_i[data_i$X == x_k, ]

    if (nrow(data_k) > 10) {  # Skip if too few observations
      tau_S_emp <- mean(data_k$S[data_k$A == 1]) - mean(data_k$S[data_k$A == 0])
      tau_Y_emp <- mean(data_k$Y[data_k$A == 1]) - mean(data_k$Y[data_k$A == 0])

      bias_S_i[k] <- tau_S_emp - tau_S_population[k]
      bias_Y_i[k] <- tau_Y_emp - tau_Y_population[k]
    } else {
      bias_S_i[k] <- NA
      bias_Y_i[k] <- NA
    }
  }

  # Compute metrics
  rmsb_S_i <- sqrt(mean(bias_S_i^2, na.rm = TRUE))
  rmsb_Y_i <- sqrt(mean(bias_Y_i^2, na.rm = TRUE))
  max_bias_S_i <- max(abs(bias_S_i), na.rm = TRUE)
  max_bias_Y_i <- max(abs(bias_Y_i), na.rm = TRUE)

  sensitivity_results[[i]] <- data.frame(
    n = n_i,
    rmsb_S = rmsb_S_i,
    rmsb_Y = rmsb_Y_i,
    max_bias_S = max_bias_S_i,
    max_bias_Y = max_bias_Y_i
  )

  cat(sprintf("  RMSB: τ_S=%.4f, τ_Y=%.4f\n", rmsb_S_i, rmsb_Y_i))
  cat(sprintf("  Max |bias|: τ_S=%.4f, τ_Y=%.4f\n", max_bias_S_i, max_bias_Y_i))
}

sensitivity_df <- do.call(rbind, sensitivity_results)

cat("\n=== Sample Size Sensitivity Summary ===\n")
print(sensitivity_df, row.names = FALSE)

# Plot sensitivity
p4 <- ggplot(sensitivity_df, aes(x = n)) +
  geom_line(aes(y = max_bias_S, color = "S"), linewidth = 1) +
  geom_point(aes(y = max_bias_S, color = "S"), size = 3) +
  geom_line(aes(y = max_bias_Y, color = "Y"), linewidth = 1) +
  geom_point(aes(y = max_bias_Y, color = "Y"), size = 3) +
  geom_hline(yintercept = 0.2, linetype = "dashed", color = "gray50") +
  labs(title = "CATE Estimation: Sample Size Sensitivity",
       subtitle = "Maximum absolute bias across strata",
       x = "Sample Size (n)",
       y = "Maximum |Bias|",
       color = "Outcome") +
  scale_x_log10() +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"),
        legend.position = "bottom")

ggsave("validation/figures/cate_validation_sensitivity.pdf", p4, width = 8, height = 6)

cat("\n=== CATE Validation Complete ===\n")
cat(sprintf("Recommendation: n >= %d for adequate CATE estimation\n",
            min(sensitivity_df$n[sensitivity_df$max_bias_S < 0.2 &
                                   sensitivity_df$max_bias_Y < 0.2])))
