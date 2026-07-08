# Compute TRUE Correlation in TV Ball for 5-Level X DGP
#
# Strategy:
# 1. Compute population CATEs: τ_S(k), τ_Y(k) for each stratum k
# 2. For any Q in TV ball: ΔS(Q) = Σ_k q_k · τ_S(k) (linear in Q!)
# 3. Sample uniformly from TV ball
# 4. Compute correlation between ΔS(Q) and ΔY(Q)

library(dplyr)
library(ggplot2)

# Load package functions
devtools::load_all()

source("explorations/calibrate_5level_x_dgp.R")

# =============================================================================
# Setup
# =============================================================================

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
lambda <- 0.3

cat("\n=== Computing TRUE Correlation in TV Ball ===\n\n")
cat(sprintf("P₀ = [%s]\n", paste(sprintf("%.2f", p_X_0), collapse=", ")))
cat(sprintf("λ = %.2f\n", lambda))
cat(sprintf("K = %d categories\n\n", K))

# =============================================================================
# Step 1: Compute Population CATEs
# =============================================================================

cat("Step 1: Computing population CATEs...\n")

# Generate very large sample to get population values
set.seed(2026)
n_large <- 500000
data_large <- generate_5level_x_data(n = n_large, p_X = p_X_0, params = params)

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

# =============================================================================
# Step 3: Sample Uniformly from TV Ball
# =============================================================================

cat("\n\nStep 3: Sampling uniformly from TV ball...\n")

# Use hit-and-run sampler
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
  labs(title = sprintf("TRUE Correlation in TV Ball (ρ = %.4f)", true_correlation),
       subtitle = sprintf("λ = %.2f, K = %d, M = %d samples", lambda, K, M),
       x = "ΔS(Q) - Treatment Effect on Surrogate",
       y = "ΔY(Q) - Treatment Effect on Outcome") +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

ggsave("validation/figures/true_correlation_5level.pdf", p1, width = 8, height = 6)

# Plot 2: Marginal distributions
df_long <- tidyr::pivot_longer(df_effects,
                                cols = c(Delta_S, Delta_Y),
                                names_to = "outcome",
                                values_to = "effect")

p2 <- ggplot(df_long, aes(x = effect, fill = outcome)) +
  geom_histogram(alpha = 0.6, position = "identity", bins = 50) +
  facet_wrap(~outcome, scales = "free", ncol = 1) +
  labs(title = "Marginal Distributions of Treatment Effects",
       subtitle = sprintf("Across %d distributions in TV ball", M),
       x = "Treatment Effect",
       y = "Count") +
  theme_minimal() +
  theme(legend.position = "none",
        plot.title = element_text(face = "bold"))

ggsave("validation/figures/true_correlation_5level_marginals.pdf", p2, width = 8, height = 8)

# Plot 3: Q distributions in TV ball (visualize first 3 components)
df_Q <- as.data.frame(Q_samples)
colnames(df_Q) <- paste0("q", 1:K)

p3 <- ggplot(df_Q, aes(x = q1, y = q2)) +
  geom_point(alpha = 0.2, size = 0.5) +
  geom_point(aes(x = p_X_0[1], y = p_X_0[2]), color = "red", size = 3) +
  labs(title = "TV Ball Geometry (First 2 Components)",
       subtitle = sprintf("Red point = P₀, Cloud = sampled Q's (λ = %.2f)", lambda),
       x = sprintf("q₁ (X = %d)", X_levels[1]),
       y = sprintf("q₂ (X = %d)", X_levels[2])) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

ggsave("validation/figures/true_correlation_5level_tvball.pdf", p3, width = 8, height = 6)

cat("Plots saved to validation/figures/\n")

# =============================================================================
# Step 7: Compare to Empirical Approach
# =============================================================================

cat("\n\nStep 7: Comparing to large-sample empirical approach...\n")

# This mimics what validation scripts do: generate large studies
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
  data_m <- generate_5level_x_data(n = n_per_study, p_X = Q_m, params = params)

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
cat("SUMMARY: TRUE CORRELATION IN TV BALL\n")
cat(strrep("=", 70) %+% "\n\n")

cat(sprintf("DGP: 5-level X ∈ {-2, -1, 0, 1, 2}\n"))
cat(sprintf("P₀ = [%s]\n", paste(sprintf("%.2f", p_X_0), collapse=", ")))
cat(sprintf("λ = %.2f\n\n", lambda))

cat("Population CATEs:\n")
for (k in 1:K) {
  cat(sprintf("  X=%2d: τ_S = %.4f, τ_Y = %.4f\n", X_levels[k], tau_S[k], tau_Y[k]))
}

cat(sprintf("\nTreatment effect at P₀:\n"))
cat(sprintf("  ΔS(P₀) = %.4f\n", Delta_S_P0))
cat(sprintf("  ΔY(P₀) = %.4f\n", Delta_Y_P0))

cat(sprintf("\nRange across TV ball:\n"))
cat(sprintf("  ΔS: [%.4f, %.4f] (range: %.4f)\n",
            min(Delta_S_vec), max(Delta_S_vec),
            max(Delta_S_vec) - min(Delta_S_vec)))
cat(sprintf("  ΔY: [%.4f, %.4f] (range: %.4f)\n",
            min(Delta_Y_vec), max(Delta_Y_vec),
            max(Delta_Y_vec) - min(Delta_Y_vec)))

cat(sprintf("\n*** TRUE CORRELATION: ρ = %.6f ***\n\n", true_correlation))

cat("Interpretation:\n")
cat(sprintf("  In future studies within λ=%.2f of P₀, the correlation between\n", lambda))
cat(sprintf("  population treatment effects ΔS(Q) and ΔY(Q) is %.3f.\n\n", true_correlation))

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
  empirical_correlation = empirical_correlation
)

saveRDS(results, "validation/results/true_correlation_5level.rds")
cat("Results saved to validation/results/true_correlation_5level.rds\n")

cat("\n=== COMPLETE ===\n")
