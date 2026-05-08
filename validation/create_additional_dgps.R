# Create Additional DGPs for Cluster Simulations
#
# DGP 3: High PTE, Low Correlation (PTE Misleading)
# DGP 4: Low PTE, High Correlation (Correlation Misleading)

library(dplyr)
library(ggplot2)

devtools::load_all()

cat("\n=== Creating Additional DGPs ===\n\n")

# Common settings
p_X_0 <- c(0.05, 0.25, 0.40, 0.25, 0.05)
X_levels <- c(-2, -1, 0, 1, 2)
K <- 5
lambda <- 0.3
n_large <- 500000
M <- 10000

# =============================================================================
# DGP 3: High PTE (~80%), Low Correlation (~0.1)
# =============================================================================

cat("=== DGP 3: High PTE, Low Correlation (PTE Misleading) ===\n\n")

# Strategy: Strong mediation (β_S = 0.9) but decorrelated CATEs via S×X interaction
params3 <- list(
  gamma_A = 1.0,
  gamma_AX = 0.3,      # Moderate linear increase in τ_S
  beta_A = 0.2,        # Small direct effect
  beta_AX = 0.0,       # No direct A×X
  beta_S = 0.9,        # Strong mediation → high PTE
  beta_SX = -0.2,      # Strong S×X creates non-linear τ_Y → decorrelation
  sigma_S = 0.5,
  sigma_Y = 0.5
)

cat("Parameters:\n")
cat(sprintf("  γ_A = %.2f, γ_AX = %.2f\n", params3$gamma_A, params3$gamma_AX))
cat(sprintf("  β_A = %.2f, β_AX = %.2f\n", params3$beta_A, params3$beta_AX))
cat(sprintf("  β_S = %.2f, β_SX = %.2f\n\n", params3$beta_S, params3$beta_SX))

# Generate data function
generate_dgp3_data <- function(n, p_X, params) {
  X <- sample(X_levels, size = n, replace = TRUE, prob = p_X)
  A <- rbinom(n, 1, 0.5)

  S <- (params$gamma_A + params$gamma_AX * X) * A + rnorm(n, sd = params$sigma_S)
  Y <- (params$beta_A + params$beta_AX * X) * A + params$beta_S * S + params$beta_SX * S * X +
       rnorm(n, sd = params$sigma_Y)

  data.frame(X = X, A = A, S = S, Y = Y)
}

# Compute population CATEs
set.seed(3001)
data_large3 <- generate_dgp3_data(n = n_large, p_X = p_X_0, params = params3)

tau_S_3 <- numeric(K)
tau_Y_3 <- numeric(K)

for (k in 1:K) {
  data_k <- data_large3[data_large3$X == X_levels[k], ]
  tau_S_3[k] <- mean(data_k$S[data_k$A == 1]) - mean(data_k$S[data_k$A == 0])
  tau_Y_3[k] <- mean(data_k$Y[data_k$A == 1]) - mean(data_k$Y[data_k$A == 0])
}

cat("Population CATEs:\n")
cat(sprintf("%-5s %10s %10s\n", "X", "τ_S", "τ_Y"))
cat(strrep("-", 27), "\n")
for (k in 1:K) {
  cat(sprintf("%2d    %10.6f %10.6f\n", X_levels[k], tau_S_3[k], tau_Y_3[k]))
}

# Compute PTE at P₀
Delta_S_P0_3 <- sum(p_X_0 * tau_S_3)
Delta_Y_P0_3 <- sum(p_X_0 * tau_Y_3)
PTE_3 <- (params3$beta_S * Delta_S_P0_3) / Delta_Y_P0_3

cat(sprintf("\nAt P₀:\n"))
cat(sprintf("  ΔS(P₀) = %.4f\n", Delta_S_P0_3))
cat(sprintf("  ΔY(P₀) = %.4f\n", Delta_Y_P0_3))
cat(sprintf("  PTE(P₀) = %.4f (%.1f%%)\n\n", PTE_3, 100 * PTE_3))

# Compute true correlation
cat("Computing true correlation (sampling TV ball)...\n")

compute_Delta_S_3 <- function(Q) sum(Q * tau_S_3)
compute_Delta_Y_3 <- function(Q) sum(Q * tau_Y_3)

set.seed(3002)
Q_samples_3 <- sample_tv_ball(P0 = p_X_0, lambda = lambda, M = M,
                               burn_in = 5000, thin = 20, verbose = FALSE)

Delta_S_vec_3 <- apply(Q_samples_3, 1, compute_Delta_S_3)
Delta_Y_vec_3 <- apply(Q_samples_3, 1, compute_Delta_Y_3)

rho_true_3 <- cor(Delta_S_vec_3, Delta_Y_vec_3)

cat(sprintf("TRUE correlation: ρ = %.6f\n\n", rho_true_3))

cat(sprintf("*** DGP 3: High PTE (%.1f%%), Low ρ (%.3f) ***\n", 100 * PTE_3, rho_true_3))
cat("This demonstrates PTE misleading: high mediation but low transportability\n\n")

cat(strrep("=", 70), "\n\n")

# =============================================================================
# DGP 4: Low PTE (~30%), High Correlation (~0.7)
# =============================================================================

cat("=== DGP 4: Low PTE, High Correlation (Correlation Misleading) ===\n\n")

# Strategy: Weak mediation (β_S = 0.3) but correlated CATEs (both increase with X)
params4 <- list(
  gamma_A = 1.0,
  gamma_AX = 0.5,      # Linear increase in τ_S
  beta_A = 0.7,        # Strong direct effect (not through S)
  beta_AX = 0.4,       # Strong direct A×X → τ_Y increases with X
  beta_S = 0.3,        # Weak mediation → low PTE
  beta_SX = 0.0,       # No S×X
  sigma_S = 0.5,
  sigma_Y = 0.5
)

cat("Parameters:\n")
cat(sprintf("  γ_A = %.2f, γ_AX = %.2f\n", params4$gamma_A, params4$gamma_AX))
cat(sprintf("  β_A = %.2f, β_AX = %.2f\n", params4$beta_A, params4$beta_AX))
cat(sprintf("  β_S = %.2f, β_SX = %.2f\n\n", params4$beta_S, params4$beta_SX))

# Generate data function
generate_dgp4_data <- function(n, p_X, params) {
  X <- sample(X_levels, size = n, replace = TRUE, prob = p_X)
  A <- rbinom(n, 1, 0.5)

  S <- (params$gamma_A + params$gamma_AX * X) * A + rnorm(n, sd = params$sigma_S)
  Y <- (params$beta_A + params$beta_AX * X) * A + params$beta_S * S + params$beta_SX * S * X +
       rnorm(n, sd = params$sigma_Y)

  data.frame(X = X, A = A, S = S, Y = Y)
}

# Compute population CATEs
set.seed(4001)
data_large4 <- generate_dgp4_data(n = n_large, p_X = p_X_0, params = params4)

tau_S_4 <- numeric(K)
tau_Y_4 <- numeric(K)

for (k in 1:K) {
  data_k <- data_large4[data_large4$X == X_levels[k], ]
  tau_S_4[k] <- mean(data_k$S[data_k$A == 1]) - mean(data_k$S[data_k$A == 0])
  tau_Y_4[k] <- mean(data_k$Y[data_k$A == 1]) - mean(data_k$Y[data_k$A == 0])
}

cat("Population CATEs:\n")
cat(sprintf("%-5s %10s %10s\n", "X", "τ_S", "τ_Y"))
cat(strrep("-", 27), "\n")
for (k in 1:K) {
  cat(sprintf("%2d    %10.6f %10.6f\n", X_levels[k], tau_S_4[k], tau_Y_4[k]))
}

# Compute PTE at P₀
Delta_S_P0_4 <- sum(p_X_0 * tau_S_4)
Delta_Y_P0_4 <- sum(p_X_0 * tau_Y_4)
PTE_4 <- (params4$beta_S * Delta_S_P0_4) / Delta_Y_P0_4

cat(sprintf("\nAt P₀:\n"))
cat(sprintf("  ΔS(P₀) = %.4f\n", Delta_S_P0_4))
cat(sprintf("  ΔY(P₀) = %.4f\n", Delta_Y_P0_4))
cat(sprintf("  PTE(P₀) = %.4f (%.1f%%)\n\n", PTE_4, 100 * PTE_4))

# Compute true correlation
cat("Computing true correlation (sampling TV ball)...\n")

compute_Delta_S_4 <- function(Q) sum(Q * tau_S_4)
compute_Delta_Y_4 <- function(Q) sum(Q * tau_Y_4)

set.seed(4002)
Q_samples_4 <- sample_tv_ball(P0 = p_X_0, lambda = lambda, M = M,
                               burn_in = 5000, thin = 20, verbose = FALSE)

Delta_S_vec_4 <- apply(Q_samples_4, 1, compute_Delta_S_4)
Delta_Y_vec_4 <- apply(Q_samples_4, 1, compute_Delta_Y_4)

rho_true_4 <- cor(Delta_S_vec_4, Delta_Y_vec_4)

cat(sprintf("TRUE correlation: ρ = %.6f\n\n", rho_true_4))

cat(sprintf("*** DGP 4: Low PTE (%.1f%%), High ρ (%.3f) ***\n", 100 * PTE_4, rho_true_4))
cat("This demonstrates correlation misleading: high transportability but low mediation\n\n")

cat(strrep("=", 70), "\n\n")

# =============================================================================
# Save Results
# =============================================================================

dir.create("validation/results", showWarnings = FALSE, recursive = TRUE)

results_dgp3 <- list(
  true_correlation = rho_true_3,
  lambda = lambda,
  P0 = p_X_0,
  tau_S = tau_S_3,
  tau_Y = tau_Y_3,
  Delta_S_vec = Delta_S_vec_3,
  Delta_Y_vec = Delta_Y_vec_3,
  Q_samples = Q_samples_3,
  M = M,
  params = params3,
  PTE_P0 = PTE_3
)

results_dgp4 <- list(
  true_correlation = rho_true_4,
  lambda = lambda,
  P0 = p_X_0,
  tau_S = tau_S_4,
  tau_Y = tau_Y_4,
  Delta_S_vec = Delta_S_vec_4,
  Delta_Y_vec = Delta_Y_vec_4,
  Q_samples = Q_samples_4,
  M = M,
  params = params4,
  PTE_P0 = PTE_4
)

saveRDS(results_dgp3, "validation/results/true_correlation_dgp3.rds")
saveRDS(results_dgp4, "validation/results/true_correlation_dgp4.rds")

cat("Results saved:\n")
cat("  validation/results/true_correlation_dgp3.rds\n")
cat("  validation/results/true_correlation_dgp4.rds\n\n")

# =============================================================================
# Summary Table
# =============================================================================

cat("=== ALL FOUR DGPs ===\n\n")

summary_table <- data.frame(
  DGP = c("DGP 1", "DGP 2", "DGP 3", "DGP 4"),
  Description = c("Moderate ρ, High PTE",
                  "Strong negative ρ, Moderate PTE",
                  "Low ρ, High PTE (PTE misleading)",
                  "High ρ, Low PTE (ρ misleading)"),
  rho_true = c(0.691, -0.884, rho_true_3, rho_true_4),
  PTE_P0 = c(0.816, 0.531, PTE_3, PTE_4),
  beta_S = c(0.9, 0.6, params3$beta_S, params4$beta_S)
)

print(summary_table, row.names = FALSE)

cat("\n=== COMPLETE ===\n")
