# Diagnostic: Compare true vs estimated CATEs for 5-level X

set.seed(2026)

# DGP parameters
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

message("=== CATE Diagnosis ===\n")

# ============================================================================
# Part 1: Analytical (Population) CATEs
# ============================================================================

message("1. ANALYTICAL (POPULATION) CATEs:\n")

# For each X value, compute population treatment effect
# ΔS|X=x = E[S|A=1,X=x] - E[S|A=0,X=x]
#        = (gamma_A + gamma_AX*x)*1 - 0
#        = gamma_A + gamma_AX*x

# ΔY|X=x is more complex due to mediation, but approximately:
# ΔY|X=x ≈ beta_A + beta_AX*x + beta_S*(gamma_A + gamma_AX*x) + beta_SX*(gamma_A + gamma_AX*x)*x

tau_S_population <- params$gamma_A + params$gamma_AX * X_levels
tau_Y_population <- params$beta_A + params$beta_AX * X_levels +
                    params$beta_S * (params$gamma_A + params$gamma_AX * X_levels) +
                    params$beta_SX * (params$gamma_A + params$gamma_AX * X_levels) * X_levels

cat("CATE for S (τ_S):\n")
for (i in seq_along(X_levels)) {
  cat(sprintf("  X=%2d: τ_S = %.4f\n", X_levels[i], tau_S_population[i]))
}

cat("\nCATE for Y (τ_Y):\n")
for (i in seq_along(X_levels)) {
  cat(sprintf("  X=%2d: τ_Y = %.4f\n", X_levels[i], tau_Y_population[i]))
}

# Standardized treatment effects under P0
Delta_S_P0_analytical <- sum(p_X_0 * tau_S_population)
Delta_Y_P0_analytical <- sum(p_X_0 * tau_Y_population)

cat(sprintf("\nStandardized under P0 (analytical):\n"))
cat(sprintf("  ΔS(P0) = %.4f\n", Delta_S_P0_analytical))
cat(sprintf("  ΔY(P0) = %.4f\n", Delta_Y_P0_analytical))

# ============================================================================
# Part 2: Empirical CATEs from Sample Data
# ============================================================================

message("\n2. EMPIRICAL CATEs FROM SAMPLE (n=300):\n")

# Generate sample
n <- 300
X <- sample(X_levels, size = n, replace = TRUE, prob = p_X_0)
A <- rbinom(n, 1, 0.5)
S <- (params$gamma_A + params$gamma_AX * X) * A + rnorm(n, sd = params$sigma_S)
Y <- (params$beta_A + params$beta_AX * X) * A + params$beta_S * S +
     params$beta_SX * S * X + rnorm(n, sd = params$sigma_Y)

data <- data.frame(X = X, A = A, S = S, Y = Y)

# Compute empirical CATEs by stratification
tau_S_empirical <- numeric(5)
tau_Y_empirical <- numeric(5)
n_by_X <- numeric(5)

for (i in seq_along(X_levels)) {
  x_val <- X_levels[i]
  idx <- (data$X == x_val)

  if (sum(idx) > 0) {
    data_x <- data[idx, ]
    n_by_X[i] <- nrow(data_x)

    tau_S_empirical[i] <- mean(data_x$S[data_x$A == 1]) - mean(data_x$S[data_x$A == 0])
    tau_Y_empirical[i] <- mean(data_x$Y[data_x$A == 1]) - mean(data_x$Y[data_x$A == 0])
  } else {
    tau_S_empirical[i] <- NA
    tau_Y_empirical[i] <- NA
  }
}

cat("Empirical CATE for S:\n")
for (i in seq_along(X_levels)) {
  cat(sprintf("  X=%2d: τ_S = %7.4f (n=%3d) [Truth: %.4f, Diff: %+.4f]\n",
              X_levels[i], tau_S_empirical[i], n_by_X[i],
              tau_S_population[i],
              tau_S_empirical[i] - tau_S_population[i]))
}

cat("\nEmpirical CATE for Y:\n")
for (i in seq_along(X_levels)) {
  cat(sprintf("  X=%2d: τ_Y = %7.4f (n=%3d) [Truth: %.4f, Diff: %+.4f]\n",
              X_levels[i], tau_Y_empirical[i], n_by_X[i],
              tau_Y_population[i],
              tau_Y_empirical[i] - tau_Y_population[i]))
}

# Standardized under P0 (empirical)
Delta_S_P0_empirical <- sum(p_X_0 * tau_S_empirical, na.rm = TRUE)
Delta_Y_P0_empirical <- sum(p_X_0 * tau_Y_empirical, na.rm = TRUE)

cat(sprintf("\nStandardized under P0 (empirical CATEs):\n"))
cat(sprintf("  ΔS(P0) = %.4f [Truth: %.4f, Diff: %+.4f]\n",
            Delta_S_P0_empirical, Delta_S_P0_analytical,
            Delta_S_P0_empirical - Delta_S_P0_analytical))
cat(sprintf("  ΔY(P0) = %.4f [Truth: %.4f, Diff: %+.4f]\n",
            Delta_Y_P0_empirical, Delta_Y_P0_analytical,
            Delta_Y_P0_empirical - Delta_Y_P0_analytical))

# ============================================================================
# Part 3: What Correlation Does Standardization Imply?
# ============================================================================

message("\n3. CORRELATION IMPLIED BY STANDARDIZATION:\n")

# If we standardize empirical CATEs with different Q distributions,
# what correlation do we get?

# Sample many Q distributions from TV ball
M <- 100
lambda <- 0.3

Q_samples <- matrix(0, nrow = M, ncol = 5)
for (m in seq_len(M)) {
  Q_m <- p_X_0 + rnorm(5, sd = lambda/3)
  Q_m <- pmax(Q_m, 0.01)
  Q_m <- Q_m / sum(Q_m)

  # Check TV constraint
  tv_dist <- 0.5 * sum(abs(Q_m - p_X_0))
  if (tv_dist > lambda) {
    scale <- lambda / tv_dist
    Q_m <- p_X_0 + scale * (Q_m - p_X_0)
  }

  Q_samples[m, ] <- Q_m
}

# Standardize empirical CATEs with each Q
Delta_S_standardized <- Q_samples %*% tau_S_empirical
Delta_Y_standardized <- Q_samples %*% tau_Y_empirical

cor_standardized <- cor(Delta_S_standardized, Delta_Y_standardized)

cat(sprintf("Correlation from standardizing EMPIRICAL CATEs: %.4f\n", cor_standardized))
cat(sprintf("  This is what IF method should estimate (if working correctly)\n"))

# ============================================================================
# Part 4: What Does Full Data Generation Give?
# ============================================================================

message("\n4. CORRELATION FROM FULL DATA GENERATION:\n")

# Generate M new studies and compute treatment effects
M_gen <- 50
Delta_S_generated <- numeric(M_gen)
Delta_Y_generated <- numeric(M_gen)

for (m in seq_len(M_gen)) {
  Q_m <- Q_samples[m, ]

  # Generate new data with this Q distribution
  n_gen <- 20000
  X_gen <- sample(X_levels, size = n_gen, replace = TRUE, prob = Q_m)
  A_gen <- rbinom(n_gen, 1, 0.5)
  S_gen <- (params$gamma_A + params$gamma_AX * X_gen) * A_gen +
           rnorm(n_gen, sd = params$sigma_S)
  Y_gen <- (params$beta_A + params$beta_AX * X_gen) * A_gen +
           params$beta_S * S_gen + params$beta_SX * S_gen * X_gen +
           rnorm(n_gen, sd = params$sigma_Y)

  # Compute treatment effects
  Delta_S_generated[m] <- mean(S_gen[A_gen == 1]) - mean(S_gen[A_gen == 0])
  Delta_Y_generated[m] <- mean(Y_gen[A_gen == 1]) - mean(Y_gen[A_gen == 0])
}

cor_generated <- cor(Delta_S_generated, Delta_Y_generated)

cat(sprintf("Correlation from GENERATING new studies: %.4f\n", cor_generated))
cat(sprintf("  This includes sampling variation from new data\n"))

# ============================================================================
# Summary
# ============================================================================

message("\n=== SUMMARY ===\n")

cat("Population CATEs are linear functions of X:\n")
cat(sprintf("  τ_S(x) = %.2f + %.2f*x\n", params$gamma_A, params$gamma_AX))
cat(sprintf("  τ_Y(x) ≈ [complex function of x]\n"))

cat("\nEmpirical CATEs have sampling error:\n")
cat(sprintf("  Max |τ_S_empirical - τ_S_population|: %.4f\n",
            max(abs(tau_S_empirical - tau_S_population), na.rm = TRUE)))
cat(sprintf("  Max |τ_Y_empirical - τ_Y_population|: %.4f\n",
            max(abs(tau_Y_empirical - tau_Y_population), na.rm = TRUE)))

cat("\nTwo definitions of correlation:\n")
cat(sprintf("  1. Standardized (fixed CATEs): %.4f\n", cor_standardized))
cat(sprintf("  2. Generated (new data):       %.4f\n", cor_generated))
cat(sprintf("  Difference:                    %.4f\n", abs(cor_standardized - cor_generated)))

cat("\nInterpretation:\n")
cat("  - Standardization uses fixed CATEs → deterministic given data\n")
cat("  - Generation creates new data → includes sampling variation\n")
cat("  - IF method estimates (1), calibration computes (2)\n")
cat("  - This is why they differ!\n")
