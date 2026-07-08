# Compute TRUE Correlation for Slides DGP (Discrete X Version)
#
# Uses slides parameters but with discrete X ∈ {-2, -1, 0, 1, 2}
# to make TV ball sampling tractable.
#
# Slides DGP characteristics:
# - High PTE (~0.7)
# - Near-zero correlation (~0.05)
# - Opposite effect modification: ΔS increases with X̄, ΔY decreases with X̄

library(dplyr)
library(ggplot2)

# Load package functions
devtools::load_all()

# =============================================================================
# DGP Function
# =============================================================================

#' Generate data from slides DGP with discrete X
#'
#' @param n Sample size
#' @param p_X K-dimensional distribution over X ∈ {-2, -1, 0, 1, 2}
#' @param params List of DGP parameters
generate_slides_discrete_x_data <- function(n, p_X, params) {
  X_levels <- c(-2, -1, 0, 1, 2)
  K <- length(X_levels)

  # Check p_X
  if (length(p_X) != K) stop("p_X must have length 5")
  if (abs(sum(p_X) - 1) > 1e-10) stop("p_X must sum to 1")

  # Sample X from categorical distribution
  X <- sample(X_levels, size = n, replace = TRUE, prob = p_X)
  A <- rbinom(n, 1, 0.5)

  # Slides parameters
  gamma_A <- params$gamma_A
  gamma_AX <- params$gamma_AX
  beta_A <- params$beta_A
  beta_AX <- params$beta_AX
  beta_S <- params$beta_S
  beta_SX <- params$beta_SX
  sigma_S <- params$sigma_S
  sigma_Y <- params$sigma_Y

  # S = (gamma_A + gamma_AX * X) * A + ε_S
  S <- (gamma_A + gamma_AX * X) * A + rnorm(n, sd = sigma_S)

  # Y = (beta_A + beta_AX * X) * A + beta_S * S + beta_SX * S * X + ε_Y
  Y <- (beta_A + beta_AX * X) * A + beta_S * S + beta_SX * S * X +
       rnorm(n, sd = sigma_Y)

  data.frame(X = X, A = A, S = S, Y = Y)
}

# =============================================================================
# Setup
# =============================================================================

cat("\n=== Computing TRUE Correlation: Slides DGP (Discrete X) ===\n\n")

# Modified slides parameters for near-zero correlation
# Goal: Both τ_S and τ_Y vary, but decorrelated (not perfectly opposite)
# Strategy: Use non-linear interaction (S×X) to create decorrelated patterns
params <- list(
  gamma_A = 1.0,      # Baseline treatment effect on S
  gamma_AX = 0.5,     # Moderate A×X: τ_S increases with X
  beta_A = 0.6,       # Moderate baseline direct effect
  beta_AX = -0.3,     # Moderate negative interaction
  beta_S = 0.6,       # Moderate mediation
  beta_SX = -0.15,    # Stronger S×X interaction creates non-linearity
  sigma_S = 0.5,
  sigma_Y = 0.5
)

# Expected effect modification:
# τ_S: linear increase with X (via γ_AX)
# τ_Y: non-linear pattern due to β_S·τ_S(X) + β_SX·τ_S(X)·X
# The S×X term creates curvature → decorrelates from linear τ_S

# Reference distribution P₀ (symmetric around 0)
p_X_0 <- c(0.05, 0.25, 0.40, 0.25, 0.05)
X_levels <- c(-2, -1, 0, 1, 2)
K <- 5
lambda <- 0.3

cat("DGP: Slides parameters with discrete X\n")
cat(sprintf("P₀ = [%s]\n", paste(sprintf("%.2f", p_X_0), collapse=", ")))
cat(sprintf("λ = %.2f\n", lambda))
cat(sprintf("K = %d categories\n\n", K))

cat("Parameters:\n")
cat(sprintf("  γ_A = %.2f, γ_AX = %.2f (S model)\n", params$gamma_A, params$gamma_AX))
cat(sprintf("  β_A = %.2f, β_AX = %.2f (direct effect)\n", params$beta_A, params$beta_AX))
cat(sprintf("  β_S = %.2f, β_SX = %.2f (mediation + S×X)\n", params$beta_S, params$beta_SX))
cat("\nExpected CATEs:\n")
cat(sprintf("  τ_S(X) = %.2f + %.2f·X (linear increase)\n", params$gamma_A, params$gamma_AX))
cat("  τ_Y(X): non-linear due to S×X interaction\n")
cat("  Goal: decorrelated patterns → near-zero correlation\n\n")

# =============================================================================
# Step 1: Compute Population CATEs
# =============================================================================

cat("Step 1: Computing population CATEs...\n")

# Generate very large sample to get population values
set.seed(2026)
n_large <- 500000
data_large <- generate_slides_discrete_x_data(n = n_large, p_X = p_X_0, params = params)

tau_S <- numeric(K)
tau_Y <- numeric(K)

for (k in 1:K) {
  data_k <- data_large[data_large$X == X_levels[k], ]
  tau_S[k] <- mean(data_k$S[data_k$A == 1]) - mean(data_k$S[data_k$A == 0])
  tau_Y[k] <- mean(data_k$Y[data_k$A == 1]) - mean(data_k$Y[data_k$A == 0])
}

cat("\nPopulation CATEs:\n")
cat(sprintf("%-5s %10s %10s\n", "X", "τ_S", "τ_Y"))
cat(strrep("-", 27), "\n")
for (k in 1:K) {
  cat(sprintf("%2d    %10.6f %10.6f\n", X_levels[k], tau_S[k], tau_Y[k]))
}

# =============================================================================
# Step 2: Analytical Treatment Effect Functions
# =============================================================================

cat("\n\nStep 2: Defining analytical treatment effect functions...\n")

# For any distribution Q = [q₁, q₂, q₃, q₄, q₅]:
# ΔS(Q) = Σ_k q_k · τ_S(k)
# ΔY(Q) = Σ_k q_k · τ_Y(k)

compute_Delta_S <- function(Q) {
  sum(Q * tau_S)
}

compute_Delta_Y <- function(Q) {
  sum(Q * tau_Y)
}

# Test with P₀
Delta_S_P0 <- compute_Delta_S(p_X_0)
Delta_Y_P0 <- compute_Delta_Y(p_X_0)

cat(sprintf("\nTreatment effects at P₀:\n"))
cat(sprintf("  ΔS(P₀) = %.6f\n", Delta_S_P0))
cat(sprintf("  ΔY(P₀) = %.6f\n", Delta_Y_P0))

# Compute PTE at P₀
# PTE = (β_S * ΔS) / ΔY (indirect / total)
indirect_P0 <- params$beta_S * Delta_S_P0
PTE_P0 <- indirect_P0 / Delta_Y_P0

cat(sprintf("  PTE(P₀) = %.6f\n", PTE_P0))

# =============================================================================
# Step 3: Sample Uniformly from TV Ball
# =============================================================================

cat("\n\nStep 3: Sampling uniformly from TV ball...\n")

M <- 10000  # Large number for accurate correlation
set.seed(2027)

cat(sprintf("  Sampling %d distributions from TV ball...\n", M))

Q_samples <- sample_tv_ball(
  P0 = p_X_0,
  lambda = lambda,
  M = M,
  burn_in = 5000,
  thin = 20,
  verbose = FALSE
)

# Verify samples are in TV ball
tv_distances <- apply(Q_samples, 1, function(q) {
  0.5 * sum(abs(q - p_X_0))
})

cat(sprintf("  TV distances: min=%.4f, max=%.4f, mean=%.4f\n",
            min(tv_distances), max(tv_distances), mean(tv_distances)))
cat(sprintf("  All in ball? %s\n", ifelse(all(tv_distances <= lambda + 1e-6), "YES", "NO")))

# =============================================================================
# Step 4: Compute Treatment Effects for Each Q
# =============================================================================

cat("\n\nStep 4: Computing treatment effects for each Q...\n")

Delta_S_vec <- numeric(M)
Delta_Y_vec <- numeric(M)

for (m in 1:M) {
  Q_m <- Q_samples[m, ]
  Delta_S_vec[m] <- compute_Delta_S(Q_m)
  Delta_Y_vec[m] <- compute_Delta_Y(Q_m)
}

cat(sprintf("  ΔS range: [%.4f, %.4f]\n", min(Delta_S_vec), max(Delta_S_vec)))
cat(sprintf("  ΔY range: [%.4f, %.4f]\n", min(Delta_Y_vec), max(Delta_Y_vec)))

# =============================================================================
# Step 5: Compute TRUE Correlation
# =============================================================================

cat("\n\nStep 5: Computing TRUE correlation...\n\n")

true_correlation <- cor(Delta_S_vec, Delta_Y_vec)

cat(sprintf("=== TRUE CORRELATION ===\n"))
cat(sprintf("ρ_true = %.6f\n\n", true_correlation))

cat("This is the correlation between population treatment effects\n")
cat("ΔS(Q) and ΔY(Q) as Q varies uniformly over the TV ball.\n\n")

cat("Expected behavior:\n")
cat("  - τ_S increases linearly with X\n")
cat("  - τ_Y has non-linear pattern (via S×X interaction)\n")
cat("  - Decorrelated patterns → near-zero correlation\n\n")

# =============================================================================
# Step 6: Visualizations
# =============================================================================

cat("Step 6: Creating visualizations...\n")

dir.create("validation/figures", showWarnings = FALSE, recursive = TRUE)

# Plot 1: Treatment effects scatter
df_effects <- data.frame(
  Delta_S = Delta_S_vec,
  Delta_Y = Delta_Y_vec
)

p1 <- ggplot(df_effects, aes(x = Delta_S, y = Delta_Y)) +
  geom_point(alpha = 0.3, size = 0.5) +
  geom_smooth(method = "lm", color = "red", se = TRUE) +
  labs(title = sprintf("TRUE Correlation: Slides DGP (ρ = %.4f)", true_correlation),
       subtitle = sprintf("Discrete X, λ = %.2f, K = %d, M = %d samples", lambda, K, M),
       x = "ΔS(Q) - Treatment Effect on Surrogate",
       y = "ΔY(Q) - Treatment Effect on Outcome") +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

ggsave("validation/figures/true_correlation_slides_discrete.pdf", p1, width = 8, height = 6)

# Plot 2: CATE patterns
df_cates <- data.frame(
  X = X_levels,
  tau_S = tau_S,
  tau_Y = tau_Y
)

df_cates_long <- tidyr::pivot_longer(df_cates, cols = c(tau_S, tau_Y),
                                      names_to = "outcome", values_to = "cate")

p2 <- ggplot(df_cates_long, aes(x = X, y = cate, color = outcome)) +
  geom_line(size = 1) +
  geom_point(size = 3) +
  scale_color_manual(values = c("tau_S" = "blue", "tau_Y" = "red"),
                     labels = c("τ_S (Surrogate)", "τ_Y (Outcome)")) +
  labs(title = "Population CATEs: Slides DGP",
       subtitle = "Note opposite slopes → near-zero correlation",
       x = "Covariate X",
       y = "Conditional Average Treatment Effect",
       color = "") +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"),
        legend.position = "bottom")

ggsave("validation/figures/true_correlation_slides_discrete_cates.pdf", p2, width = 8, height = 6)

cat("Plots saved to validation/figures/\n")

# =============================================================================
# Step 7: Compare to Empirical Approach
# =============================================================================

cat("\n\nStep 7: Comparing to large-sample empirical approach...\n")

set.seed(2028)
M_empirical <- 100
n_per_study <- 50000

cat(sprintf("  Generating %d studies with n=%d each...\n", M_empirical, n_per_study))

Delta_S_empirical <- numeric(M_empirical)
Delta_Y_empirical <- numeric(M_empirical)

# Sample M distributions
Q_empirical <- sample_tv_ball(p_X_0, lambda, M_empirical,
                              burn_in = 1000, thin = 10, verbose = FALSE)

for (m in 1:M_empirical) {
  Q_m <- Q_empirical[m, ]

  # Generate large study from this Q
  data_m <- generate_slides_discrete_x_data(n = n_per_study, p_X = Q_m, params = params)

  # Empirical treatment effects
  Delta_S_empirical[m] <- mean(data_m$S[data_m$A == 1]) -
                          mean(data_m$S[data_m$A == 0])
  Delta_Y_empirical[m] <- mean(data_m$Y[data_m$A == 1]) -
                          mean(data_m$Y[data_m$A == 0])
}

empirical_correlation <- cor(Delta_S_empirical, Delta_Y_empirical)

cat(sprintf("\n  Analytical (M=%d): ρ = %.6f\n", M, true_correlation))
cat(sprintf("  Empirical (M=%d, n=%d): ρ = %.6f\n", M_empirical, n_per_study, empirical_correlation))
cat(sprintf("  Difference: %.6f\n", abs(true_correlation - empirical_correlation)))

# =============================================================================
# Step 8: Summary Output
# =============================================================================

cat("\n\n" %+% strrep("=", 70) %+% "\n")
cat("SUMMARY: TRUE CORRELATION - SLIDES DGP (DISCRETE X)\n")
cat(strrep("=", 70) %+% "\n\n")

cat(sprintf("DGP: Slides parameters with discrete X ∈ {-2, -1, 0, 1, 2}\n"))
cat(sprintf("P₀ = [%s]\n", paste(sprintf("%.2f", p_X_0), collapse=", ")))
cat(sprintf("λ = %.2f\n\n", lambda))

cat("Population CATEs:\n")
for (k in 1:K) {
  cat(sprintf("  X=%2d: τ_S = %.4f, τ_Y = %.4f\n", X_levels[k], tau_S[k], tau_Y[k]))
}

cat(sprintf("\nTreatment effects at P₀:\n"))
cat(sprintf("  ΔS(P₀) = %.4f\n", Delta_S_P0))
cat(sprintf("  ΔY(P₀) = %.4f\n", Delta_Y_P0))
cat(sprintf("  PTE(P₀) = %.4f\n", PTE_P0))

cat(sprintf("\nRange across TV ball:\n"))
cat(sprintf("  ΔS: [%.4f, %.4f] (range: %.4f)\n",
            min(Delta_S_vec), max(Delta_S_vec),
            max(Delta_S_vec) - min(Delta_S_vec)))
cat(sprintf("  ΔY: [%.4f, %.4f] (range: %.4f)\n",
            min(Delta_Y_vec), max(Delta_Y_vec),
            max(Delta_Y_vec) - min(Delta_Y_vec)))

cat(sprintf("\n*** TRUE CORRELATION: ρ = %.6f ***\n\n", true_correlation))

cat("Interpretation:\n")
cat("  Modified slides DGP with decorrelated effect modification:\n")
cat(sprintf("  - τ_S: %.2f at X=-2 → %.2f at X=2 (range: %.2f)\n",
            tau_S[1], tau_S[5], abs(tau_S[5] - tau_S[1])))
cat(sprintf("  - τ_Y: %.2f at X=-2 → %.2f at X=2 (range: %.2f)\n",
            tau_Y[1], tau_Y[5], abs(tau_Y[5] - tau_Y[1])))
cat(sprintf("  - Correlation between CATE vectors: %.3f\n", cor(tau_S, tau_Y)))
cat(sprintf("  - Resulting correlation in TV ball: %.3f\n\n", true_correlation))

# Save results
results <- list(
  true_correlation = true_correlation,
  lambda = lambda,
  P0 = p_X_0,
  tau_S = tau_S,
  tau_Y = tau_Y,
  Delta_S_vec = Delta_S_vec,
  Delta_Y_vec = Delta_Y_vec,
  Q_samples = Q_samples,
  M = M,
  empirical_correlation = empirical_correlation,
  params = params,
  PTE_P0 = PTE_P0
)

saveRDS(results, "validation/results/true_correlation_slides_discrete.rds")
cat("Results saved to validation/results/true_correlation_slides_discrete.rds\n")

cat("\n=== COMPLETE ===\n")
