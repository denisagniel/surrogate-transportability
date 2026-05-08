# Create DGP 5: Small ΔY at P₀, High Correlation (PTE Fails)
#
# This DGP demonstrates PTE failure when ΔY ≈ 0 in the reference study.
#
# Strategy:
# - Use antisymmetric treatment effects: τ(X) = c × X
# - With symmetric P₀, ΔS ≈ 0 and ΔY ≈ 0
# - PTE = (β_S × 0) / 0 = undefined/unstable
# - But τ_S and τ_Y covary strongly across studies → high ρ
# - When distribution shifts (Q ≠ P₀), both ΔS and ΔY change proportionally

library(dplyr)
library(ggplot2)

devtools::load_all()

cat("\n=== Creating DGP 5: Small ΔY, High Correlation ===\n\n")

# Common settings
p_X_0 <- c(0.05, 0.25, 0.40, 0.25, 0.05)  # Symmetric
X_levels <- c(-2, -1, 0, 1, 2)            # Symmetric
K <- 5
lambda <- 0.3
n_large <- 500000
M <- 10000

# =============================================================================
# DGP 5: Small ΔY at P₀, High Correlation
# =============================================================================

cat("=== DGP 5: Small ΔY at P₀, High Correlation (PTE Fails) ===\n\n")

# Antisymmetric effects (both scale with X)
params5 <- list(
  gamma_A = 0.0,       # No effect at X=0
  gamma_AX = 0.5,      # τ_S = 0.5*X (antisymmetric)
  beta_A = 0.0,        # No direct effect at X=0
  beta_AX = 0.5,       # Direct effect scales with X
  beta_S = 0.6,        # Moderate mediation
  beta_SX = 0.0,       # No S×X interaction
  sigma_S = 0.5,
  sigma_Y = 0.5
)

cat("Parameters:\n")
cat(sprintf("  γ_A = %.2f, γ_AX = %.2f\n", params5$gamma_A, params5$gamma_AX))
cat(sprintf("  β_A = %.2f, β_AX = %.2f\n", params5$beta_A, params5$beta_AX))
cat(sprintf("  β_S = %.2f, β_SX = %.2f\n\n", params5$beta_S, params5$beta_SX))

# Generate data function
generate_dgp5_data <- function(n, p_X, params) {
  X <- sample(X_levels, size = n, replace = TRUE, prob = p_X)
  A <- rbinom(n, 1, 0.5)

  S <- (params$gamma_A + params$gamma_AX * X) * A + rnorm(n, sd = params$sigma_S)
  Y <- (params$beta_A + params$beta_AX * X) * A + params$beta_S * S + params$beta_SX * S * X +
       rnorm(n, sd = params$sigma_Y)

  data.frame(X = X, A = A, S = S, Y = Y)
}

# Compute population CATEs
set.seed(5001)
data_large5 <- generate_dgp5_data(n = n_large, p_X = p_X_0, params = params5)

tau_S_5 <- numeric(K)
tau_Y_5 <- numeric(K)

for (k in 1:K) {
  data_k <- data_large5[data_large5$X == X_levels[k], ]
  tau_S_5[k] <- mean(data_k$S[data_k$A == 1]) - mean(data_k$S[data_k$A == 0])
  tau_Y_5[k] <- mean(data_k$Y[data_k$A == 1]) - mean(data_k$Y[data_k$A == 0])
}

cat("Population CATEs:\n")
cat(sprintf("%-5s %10s %10s\n", "X", "τ_S", "τ_Y"))
cat(strrep("-", 27), "\n")
for (k in 1:K) {
  cat(sprintf("%2d    %10.6f %10.6f\n", X_levels[k], tau_S_5[k], tau_Y_5[k]))
}

# Compute effects at P₀
Delta_S_P0_5 <- sum(p_X_0 * tau_S_5)
Delta_Y_P0_5 <- sum(p_X_0 * tau_Y_5)
PTE_5 <- (params5$beta_S * Delta_S_P0_5) / Delta_Y_P0_5

cat(sprintf("\nAt P₀ (symmetric distribution):\n"))
cat(sprintf("  ΔS(P₀) = %.6f (≈ 0 by symmetry)\n", Delta_S_P0_5))
cat(sprintf("  ΔY(P₀) = %.6f (≈ 0 by symmetry)\n", Delta_Y_P0_5))
cat(sprintf("  PTE(P₀) = %.4f", PTE_5))
if (abs(Delta_Y_P0_5) < 0.01) {
  cat(" (UNDEFINED - division by ~0!)\n")
} else {
  cat(sprintf(" (%.1f%%, but unstable)\n", 100 * PTE_5))
}
cat("\n")

# Compute true correlation
cat("Computing true correlation (sampling TV ball)...\n")

compute_Delta_S_5 <- function(Q) sum(Q * tau_S_5)
compute_Delta_Y_5 <- function(Q) sum(Q * tau_Y_5)

set.seed(5002)
Q_samples_5 <- sample_tv_ball(P0 = p_X_0, lambda = lambda, M = M,
                               burn_in = 5000, thin = 20, verbose = FALSE)

Delta_S_vec_5 <- apply(Q_samples_5, 1, compute_Delta_S_5)
Delta_Y_vec_5 <- apply(Q_samples_5, 1, compute_Delta_Y_5)

rho_true_5 <- cor(Delta_S_vec_5, Delta_Y_vec_5)

cat(sprintf("TRUE correlation: ρ = %.6f\n\n", rho_true_5))

# Visualize the issue
cat("Creating diagnostic plot...\n")

plot_data <- data.frame(
  X = X_levels,
  tau_S = tau_S_5,
  tau_Y = tau_Y_5
)

p1 <- ggplot(plot_data, aes(x = X)) +
  geom_line(aes(y = tau_S, color = "τ_S"), size = 1) +
  geom_point(aes(y = tau_S, color = "τ_S"), size = 3) +
  geom_line(aes(y = tau_Y, color = "τ_Y"), size = 1) +
  geom_point(aes(y = tau_Y, color = "τ_Y"), size = 3) +
  geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.3) +
  scale_color_manual(values = c("τ_S" = "blue", "τ_Y" = "red")) +
  labs(title = "DGP 5: Antisymmetric Treatment Effects",
       subtitle = "Both τ_S and τ_Y scale with X (high correlation across studies)",
       x = "X", y = "Treatment Effect", color = "Effect") +
  theme_minimal()

# Show distribution weighting
p2 <- ggplot(data.frame(X = X_levels, P0 = p_X_0), aes(x = X, y = P0)) +
  geom_col(fill = "steelblue", alpha = 0.6) +
  geom_text(aes(label = sprintf("%.2f", P0)), vjust = -0.5) +
  labs(title = "Reference Distribution P₀",
       subtitle = "Symmetric → ΔS ≈ 0 and ΔY ≈ 0 at P₀",
       x = "X", y = "Probability") +
  theme_minimal()

# Show correlation across TV ball
p3 <- ggplot(data.frame(Delta_S = Delta_S_vec_5, Delta_Y = Delta_Y_vec_5),
             aes(x = Delta_S, y = Delta_Y)) +
  geom_point(alpha = 0.3, size = 1) +
  geom_smooth(method = "lm", color = "red", se = FALSE) +
  geom_vline(xintercept = Delta_S_P0_5, linetype = "dashed", color = "blue") +
  geom_hline(yintercept = Delta_Y_P0_5, linetype = "dashed", color = "blue") +
  annotate("text", x = Delta_S_P0_5, y = max(Delta_Y_vec_5) * 0.9,
           label = sprintf("P₀: (%.3f, %.3f)", Delta_S_P0_5, Delta_Y_P0_5),
           color = "blue", hjust = -0.1) +
  labs(title = sprintf("Treatment Effects Across TV Ball (λ = %.1f)", lambda),
       subtitle = sprintf("ρ = %.3f (high correlation despite ΔY ≈ 0 at P₀)", rho_true_5),
       x = "ΔS(Q)", y = "ΔY(Q)") +
  theme_minimal()

dir.create("validation/figures", showWarnings = FALSE, recursive = TRUE)

pdf("validation/figures/dgp5_small_delta_y.pdf", width = 12, height = 4)
gridExtra::grid.arrange(p1, p2, p3, ncol = 3)
dev.off()

cat("Plot saved: validation/figures/dgp5_small_delta_y.pdf\n\n")

cat(sprintf("*** DGP 5: ΔY ≈ 0 at P₀ (%.4f), High ρ (%.3f) ***\n", Delta_Y_P0_5, rho_true_5))
cat("This demonstrates PTE failure: PTE is undefined or highly unstable\n")
cat("when ΔY ≈ 0, but correlation remains well-defined and high.\n")
cat("Both effects scale with X, giving perfect transportability despite\n")
cat("near-zero effects at the reference distribution.\n\n")

cat(strrep("=", 70), "\n\n")

# =============================================================================
# Save Results
# =============================================================================

dir.create("validation/results", showWarnings = FALSE, recursive = TRUE)

results_dgp5 <- list(
  true_correlation = rho_true_5,
  lambda = lambda,
  P0 = p_X_0,
  tau_S = tau_S_5,
  tau_Y = tau_Y_5,
  Delta_S_vec = Delta_S_vec_5,
  Delta_Y_vec = Delta_Y_vec_5,
  Q_samples = Q_samples_5,
  M = M,
  params = params5,
  Delta_S_P0 = Delta_S_P0_5,
  Delta_Y_P0 = Delta_Y_P0_5,
  PTE_P0 = PTE_5
)

saveRDS(results_dgp5, "validation/results/true_correlation_dgp5.rds")

cat("Results saved: validation/results/true_correlation_dgp5.rds\n\n")

# =============================================================================
# Summary Table: All 5 DGPs
# =============================================================================

cat("=== ALL FIVE DGPs ===\n\n")

summary_table <- data.frame(
  DGP = c("DGP 1", "DGP 2", "DGP 4", "DGP 5"),
  Description = c("Moderate ρ, High PTE",
                  "Strong negative ρ, Moderate PTE",
                  "High ρ, Low PTE (ρ misleading)",
                  "High ρ, ΔY≈0 (PTE fails)"),
  rho_true = c(0.691, -0.884, 1.000, rho_true_5),
  Delta_Y_P0 = c(1.045, 1.128, 1.000, Delta_Y_P0_5),
  PTE_P0 = c(0.816, 0.531, 0.300, PTE_5),
  beta_S = c(0.9, 0.6, 0.3, params5$beta_S)
)

print(summary_table, row.names = FALSE, digits = 3)

cat("\n=== COMPLETE ===\n")
