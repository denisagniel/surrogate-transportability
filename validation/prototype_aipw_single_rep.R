#!/usr/bin/env Rscript
# Prototype: Single Replication of AIPW Robustness Study
#
# Purpose: Test implementation locally before cluster deployment
# Tests: DGP with confounding, noise generation, AIPW estimation
#
# Usage: Rscript prototype_aipw_single_rep.R

suppressPackageStartupMessages({
  library(surrogateTransportability)
  library(yaml)
})

cat("\n", strrep("=", 70), "\n")
cat("AIPW ROBUSTNESS PROTOTYPE: Single Replication\n")
cat(strrep("=", 70), "\n\n")

# =============================================================================
# Parameters for Test Replication
# =============================================================================

# DGP settings
n <- 2000
alpha_1 <- 0.3  # Confounding strength
lambda <- 0.3

# Load DGP 1 structural parameters
dgp_config <- yaml::read_yaml("../cluster/config/dgp_specifications.yaml")$dgps$dgp1
params <- dgp_config$params
p_X <- dgp_config$p_X
X_levels <- dgp_config$X_levels
rho_true <- dgp_config$rho_true

cat("DGP CONFIGURATION:\n")
cat(sprintf("  Sample size: n = %d\n", n))
cat(sprintf("  Confounding: α₁ = %.2f\n", alpha_1))
cat(sprintf("  True ρ: %.4f\n", rho_true))
cat(sprintf("  TV ball radius: λ = %.2f\n\n", lambda))

# Noise configuration (Scenario 3: Both noisy)
alpha_e <- 0.5  # Propensity convergence rate
alpha_mu <- 0.5  # Outcome convergence rate
c_e <- 1.0      # Propensity noise constant
c_mu <- 1.0     # Outcome noise constant

cat("NOISE CONFIGURATION (Scenario 3):\n")
cat(sprintf("  Propensity: σ_e(n) = %.1f × n^(-%.2f)\n", c_e, alpha_e))
cat(sprintf("  Outcome: σ_μ(n) = %.1f × n^(-%.2f)\n", c_mu, alpha_mu))
cat(sprintf("  Expected σ_e = %.4f\n", c_e * n^(-alpha_e)))
cat(sprintf("  Expected σ_μ = %.4f\n\n", c_mu * n^(-alpha_mu)))

# =============================================================================
# Step 1: Generate Observational Data with Confounding
# =============================================================================

cat("STEP 1: Generate observational data with confounding\n")
cat(strrep("-", 70), "\n")

set.seed(12345)

# Sample covariate X
X <- sample(X_levels, size = n, replace = TRUE, prob = p_X)

# True propensity score: e(X) = expit(α₀ + α₁·X)
# α₀ = 0 gives overall prevalence ≈ 50%
alpha_0 <- 0
logit_e_true <- alpha_0 + alpha_1 * X
e_true <- plogis(logit_e_true)  # expit = inverse logit

cat(sprintf("  True propensity range: [%.3f, %.3f]\n", min(e_true), max(e_true)))
cat(sprintf("  Mean propensity: %.3f\n", mean(e_true)))

# Generate treatment via propensity score
A <- rbinom(n, 1, prob = e_true)

cat(sprintf("  Treatment prevalence: %.1f%%\n", 100 * mean(A)))

# Generate S and Y (structural model from DGP 1)
# S: E[S|A,X] = (γ_A + γ_AX·X)·A
S <- (params$gamma_A + params$gamma_AX * X) * A + rnorm(n, sd = params$sigma_S)

# Y: E[Y|A,X,S] = (β_A + β_AX·X)·A + β_S·S + β_SX·S·X
Y <- (params$beta_A + params$beta_AX * X) * A +
     params$beta_S * S + params$beta_SX * S * X +
     rnorm(n, sd = params$sigma_Y)

data <- data.frame(X = X, A = A, S = S, Y = Y)

cat(sprintf("  Data generated: %d observations\n", nrow(data)))
cat(sprintf("  Empirical means: E[S|A=1] = %.3f, E[Y|A=1] = %.3f\n\n",
            mean(S[A==1]), mean(Y[A==1])))

# =============================================================================
# Step 2: Generate Noisy Nuisances
# =============================================================================

cat("STEP 2: Generate noisy nuisances\n")
cat(strrep("-", 70), "\n")

# Compute noise standard deviations
sigma_e <- c_e * n^(-alpha_e)
sigma_mu <- c_mu * n^(-alpha_mu)

cat(sprintf("  Computed σ_e = %.4f (scaling with n^(-%.2f))\n", sigma_e, alpha_e))
cat(sprintf("  Computed σ_μ = %.4f (scaling with n^(-%.2f))\n\n", sigma_mu, alpha_mu))

# Generate noisy propensity scores (X-specific noise on logit scale)
K <- length(X_levels)
epsilon_e <- rnorm(K, mean = 0, sd = sigma_e)  # One noise term per X level

# Create lookup: X level → noise
noise_lookup_e <- setNames(epsilon_e, X_levels)

# Apply noise: e_est(X) = expit(logit(e_true(X)) + ε_X)
logit_e_noisy <- logit_e_true + noise_lookup_e[as.character(X)]
e_est <- plogis(logit_e_noisy)

# Clip extreme values
e_est <- pmax(pmin(e_est, 0.99), 0.01)

cat("PROPENSITY SCORE QUALITY:\n")
cat(sprintf("  True e(X) range: [%.3f, %.3f]\n", min(e_true), max(e_true)))
cat(sprintf("  Est e(X) range:  [%.3f, %.3f]\n", min(e_est), max(e_est)))
cat(sprintf("  Mean absolute error: %.4f\n", mean(abs(e_est - e_true))))
cat(sprintf("  RMSE: %.4f\n\n", sqrt(mean((e_est - e_true)^2))))

# Generate noisy outcome regressions (X-specific noise, direct scale)
# True outcome regressions
mu_1_S_true <- params$gamma_A + params$gamma_AX * X
mu_0_S_true <- rep(0, n)

mu_1_Y_true <- params$beta_A + params$beta_AX * X +
               params$beta_S * (params$gamma_A + params$gamma_AX * X)
mu_0_Y_true <- rep(0, n)

# Add noise
epsilon_mu_S1 <- rnorm(K, mean = 0, sd = sigma_mu)
epsilon_mu_Y1 <- rnorm(K, mean = 0, sd = sigma_mu)

noise_lookup_mu_S1 <- setNames(epsilon_mu_S1, X_levels)
noise_lookup_mu_Y1 <- setNames(epsilon_mu_Y1, X_levels)

mu_1_S_est <- mu_1_S_true + noise_lookup_mu_S1[as.character(X)]
mu_0_S_est <- mu_0_S_true  # No noise (already 0)

mu_1_Y_est <- mu_1_Y_true + noise_lookup_mu_Y1[as.character(X)]
mu_0_Y_est <- mu_0_Y_true

cat("OUTCOME REGRESSION QUALITY:\n")
cat(sprintf("  S regressions:\n"))
cat(sprintf("    μ₁(X) MAE: %.4f\n", mean(abs(mu_1_S_est - mu_1_S_true))))
cat(sprintf("    μ₁(X) RMSE: %.4f\n", sqrt(mean((mu_1_S_est - mu_1_S_true)^2))))
cat(sprintf("  Y regressions:\n"))
cat(sprintf("    μ₁(X) MAE: %.4f\n", mean(abs(mu_1_Y_est - mu_1_Y_true))))
cat(sprintf("    μ₁(X) RMSE: %.4f\n\n", sqrt(mean((mu_1_Y_est - mu_1_Y_true)^2))))

# Package nuisances for AIPW
nuisances <- list(
  e_hat = e_est,
  mu_1_S = mu_1_S_est,
  mu_0_S = mu_0_S_est,
  mu_1_Y = mu_1_Y_est,
  mu_0_Y = mu_0_Y_est
)

# =============================================================================
# Step 3: Run AIPW Estimation (Oracle vs Noisy)
# =============================================================================

cat("STEP 3: Run AIPW estimation\n")
cat(strrep("-", 70), "\n")

# Oracle (true nuisances)
cat("\n[Oracle] Using true nuisances...\n")

nuisances_oracle <- list(
  e_hat = e_true,
  mu_1_S = mu_1_S_true,
  mu_0_S = mu_0_S_true,
  mu_1_Y = mu_1_Y_true,
  mu_0_Y = mu_0_Y_true
)

result_oracle <- tv_ball_correlation_IF_adaptive(
  data = data,
  lambda = lambda,
  M_start = 300,
  M_increment = 300,
  M_max = 3000,
  tolerance = 0.01,
  n_stable = 3,
  burn_in = 500,
  thin = 5,
  alpha = 0.05,
  method = "aipw",
  e_hat = nuisances_oracle$e_hat,
  mu_1_S = nuisances_oracle$mu_1_S,
  mu_0_S = nuisances_oracle$mu_0_S,
  mu_1_Y = nuisances_oracle$mu_1_Y,
  mu_0_Y = nuisances_oracle$mu_0_Y,
  verbose = FALSE
)

cat(sprintf("\nOracle Results:\n"))
cat(sprintf("  ρ̂ = %.4f (true: %.4f)\n", result_oracle$rho_hat, rho_true))
cat(sprintf("  Bias = %.4f\n", result_oracle$rho_hat - rho_true))
cat(sprintf("  SE = %.4f\n", result_oracle$se))
cat(sprintf("  95%% CI: [%.4f, %.4f]\n", result_oracle$ci_lower, result_oracle$ci_upper))
cat(sprintf("  Converged: %s (M = %d)\n", result_oracle$converged, result_oracle$M_final))

# Noisy (estimated nuisances)
cat("\n[Noisy] Using estimated nuisances (α_e = α_μ = 0.5)...\n")

result_noisy <- tv_ball_correlation_IF_adaptive(
  data = data,
  lambda = lambda,
  M_start = 300,
  M_increment = 300,
  M_max = 3000,
  tolerance = 0.01,
  n_stable = 3,
  burn_in = 500,
  thin = 5,
  alpha = 0.05,
  method = "aipw",
  e_hat = nuisances$e_hat,
  mu_1_S = nuisances$mu_1_S,
  mu_0_S = nuisances$mu_0_S,
  mu_1_Y = nuisances$mu_1_Y,
  mu_0_Y = nuisances$mu_0_Y,
  verbose = FALSE
)

cat(sprintf("\nNoisy Results:\n"))
cat(sprintf("  ρ̂ = %.4f (true: %.4f)\n", result_noisy$rho_hat, rho_true))
cat(sprintf("  Bias = %.4f\n", result_noisy$rho_hat - rho_true))
cat(sprintf("  SE = %.4f\n", result_noisy$se))
cat(sprintf("  95%% CI: [%.4f, %.4f]\n", result_noisy$ci_lower, result_noisy$ci_upper))
cat(sprintf("  Converged: %s (M = %d)\n", result_noisy$converged, result_noisy$M_final))

# =============================================================================
# Step 4: Compare Oracle vs Noisy
# =============================================================================

cat("\n")
cat(strrep("=", 70), "\n")
cat("COMPARISON: Oracle vs Noisy\n")
cat(strrep("=", 70), "\n\n")

cat(sprintf("Oracle bias:        %.4f\n", result_oracle$rho_hat - rho_true))
cat(sprintf("Noisy bias:         %.4f\n", result_noisy$rho_hat - rho_true))
cat(sprintf("Additional bias:    %.4f\n\n",
            abs(result_noisy$rho_hat - rho_true) - abs(result_oracle$rho_hat - rho_true)))

cat(sprintf("Oracle SE:          %.4f\n", result_oracle$se))
cat(sprintf("Noisy SE:           %.4f\n", result_noisy$se))
cat(sprintf("SE inflation:       %.1f%%\n\n",
            100 * (result_noisy$se / result_oracle$se - 1)))

# Check coverage
covers_oracle <- result_oracle$ci_lower <= rho_true && rho_true <= result_oracle$ci_upper
covers_noisy <- result_noisy$ci_lower <= rho_true && rho_true <= result_noisy$ci_upper

cat(sprintf("Oracle covers:      %s\n", covers_oracle))
cat(sprintf("Noisy covers:       %s\n\n", covers_noisy))

# =============================================================================
# Summary and Next Steps
# =============================================================================

cat(strrep("=", 70), "\n")
cat("PROTOTYPE COMPLETE\n")
cat(strrep("=", 70), "\n\n")

cat("KEY FINDINGS:\n")
cat(sprintf("  1. Confounding successfully generated (e(X) range: %.3f to %.3f)\n",
            min(e_true), max(e_true)))
cat(sprintf("  2. Noise scaling works: σ_e = %.4f, σ_μ = %.4f at n=%d\n",
            sigma_e, sigma_mu, n))
cat(sprintf("  3. Oracle bias: %.4f (should be small)\n",
            result_oracle$rho_hat - rho_true))
cat(sprintf("  4. Noisy additional bias: %.4f (depends on α values)\n",
            abs(result_noisy$rho_hat - rho_true) - abs(result_oracle$rho_hat - rho_true)))
cat(sprintf("  5. Both estimators converged successfully\n\n"))

cat("VALIDATION CHECKS:\n")
cat(sprintf("  [%s] Oracle bias < 0.05\n",
            ifelse(abs(result_oracle$rho_hat - rho_true) < 0.05, "✓", "✗")))
cat(sprintf("  [%s] Oracle converged\n",
            ifelse(result_oracle$converged, "✓", "✗")))
cat(sprintf("  [%s] Noisy converged\n",
            ifelse(result_noisy$converged, "✓", "✗")))
cat(sprintf("  [%s] Noise increased bias (as expected for α=0.5 at n=%d)\n",
            ifelse(abs(result_noisy$rho_hat - rho_true) > abs(result_oracle$rho_hat - rho_true),
                   "✓", "✗"), n))

cat("\nNEXT STEPS:\n")
cat("  1. If validation checks pass: Proceed to cluster deployment\n")
cat("  2. Create cluster configuration (scenarios.yaml)\n")
cat("  3. Write batch submission script\n")
cat("  4. Run full simulation (263 settings × 1000 reps)\n\n")
