# Compare True Correlation vs Observation-Level Estimate
#
# For a DGP with NO unmeasured heterogeneity (only X varies treatment effects),
# check if observation-level approach is biased

library(tidyverse)
devtools::load_all(".")

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")

cat("=== COMPARING TRUE vs OBSERVATION-LEVEL CORRELATION ===\n\n")

# Generate data
set.seed(2026)
n <- 100

X <- rbinom(n, 1, 0.5)
A <- rbinom(n, 1, 0.5)

# DGP: Only X modifies treatment effects (no unmeasured U)
logit_S <- -1.5 + 0.5*A + 0.3*X + 2.0*A*X
S <- rbinom(n, 1, plogis(logit_S))

logit_Y <- -1.5 + 0.3*A + 0.5*X + 0.1*S + 1.8*A*X
Y <- rbinom(n, 1, plogis(logit_Y))

data <- tibble(X = X, A = A, S = S, Y = Y)

cat("DGP: Treatment effects vary with X only (no unmeasured U)\n")
cat(sprintf("Sample size: n = %d\n\n", n))

# ============================================================================
# Method 1: TRUE (Covariate-Level, K=2)
# ============================================================================

cat("=== METHOD 1: TRUE CORRELATION (Covariate-Level) ===\n\n")

# Estimate treatment effects by X
tau_S_hat <- c(
  mean(data$S[data$X == 0 & data$A == 1]) - mean(data$S[data$X == 0 & data$A == 0]),
  mean(data$S[data$X == 1 & data$A == 1]) - mean(data$S[data$X == 1 & data$A == 0])
)

tau_Y_hat <- c(
  mean(data$Y[data$X == 0 & data$A == 1]) - mean(data$Y[data$X == 0 & data$A == 0]),
  mean(data$Y[data$X == 1 & data$A == 1]) - mean(data$Y[data$X == 1 & data$A == 0])
)

cat("Estimated type-specific effects:\n")
cat(sprintf("  τ_S(X=0) = %.3f\n", tau_S_hat[1]))
cat(sprintf("  τ_S(X=1) = %.3f\n", tau_S_hat[2]))
cat(sprintf("  τ_Y(X=0) = %.3f\n", tau_Y_hat[1]))
cat(sprintf("  τ_Y(X=1) = %.3f\n\n", tau_Y_hat[2]))

# P0 for covariate distribution
P0_X <- c(mean(data$X == 0), mean(data$X == 1))
cat(sprintf("P0(X): (%.3f, %.3f)\n\n", P0_X[1], P0_X[2]))

# Sample Q from TV ball (2-dimensional)
cat("Sampling Q from TV ball (K=2)...\n")
Q_samples_covariate <- hit_and_run_tv_ball(
  P0 = P0_X,
  lambda = 0.3,
  n_samples = 50,
  burn_in = 500,
  thin = 5,
  verbose = FALSE
)

# Compute treatment effects for each Q
effects_covariate <- map_dfr(1:nrow(Q_samples_covariate), function(i) {
  Q <- Q_samples_covariate[i, ]

  # Weighted average of type-specific effects
  delta_s <- sum(Q * tau_S_hat)
  delta_y <- sum(Q * tau_Y_hat)

  tibble(delta_s = delta_s, delta_y = delta_y)
})

cor_covariate <- cor(effects_covariate$delta_s, effects_covariate$delta_y)

cat(sprintf("Correlation (covariate-level): %.3f\n", cor_covariate))
cat(sprintf("Mean ΔS: %.3f (SD: %.3f)\n",
            mean(effects_covariate$delta_s), sd(effects_covariate$delta_s)))
cat(sprintf("Mean ΔY: %.3f (SD: %.3f)\n\n",
            mean(effects_covariate$delta_y), sd(effects_covariate$delta_y)))

# ============================================================================
# Method 2: OBSERVATION-LEVEL (K=n)
# ============================================================================

cat("=== METHOD 2: OBSERVATION-LEVEL (K=%d) ===\n\n", n)

# P0 for observation distribution
P0_obs <- rep(1/n, n)

# Sample Q from TV ball (n-dimensional)
cat("Sampling Q from TV ball (K=%d)...\n", n)
Q_samples_obs <- hit_and_run_tv_ball(
  P0 = P0_obs,
  lambda = 0.3,
  n_samples = 50,
  burn_in = 500,
  thin = 5,
  verbose = FALSE
)

# Compute treatment effects for each Q (by resampling)
effects_obs <- map_dfr(1:nrow(Q_samples_obs), function(i) {
  Q <- Q_samples_obs[i, ]

  # Resample observations with weights Q
  resampled_idx <- sample(1:n, size = n, replace = TRUE, prob = Q)
  resampled <- data[resampled_idx, ]

  delta_s <- mean(resampled$S[resampled$A == 1]) -
             mean(resampled$S[resampled$A == 0])
  delta_y <- mean(resampled$Y[resampled$A == 1]) -
             mean(resampled$Y[resampled$A == 0])

  tibble(delta_s = delta_s, delta_y = delta_y)
})

cor_obs <- cor(effects_obs$delta_s, effects_obs$delta_y)

cat(sprintf("Correlation (observation-level): %.3f\n", cor_obs))
cat(sprintf("Mean ΔS: %.3f (SD: %.3f)\n",
            mean(effects_obs$delta_s), sd(effects_obs$delta_s)))
cat(sprintf("Mean ΔY: %.3f (SD: %.3f)\n\n",
            mean(effects_obs$delta_y), sd(effects_obs$delta_y)))

# ============================================================================
# Comparison
# ============================================================================

cat("=== COMPARISON ===\n\n")
cat(sprintf("TRUE correlation (covariate-level):   %.3f\n", cor_covariate))
cat(sprintf("Observation-level correlation:         %.3f\n", cor_obs))
cat(sprintf("Difference:                            %.3f\n\n", cor_covariate - cor_obs))

cat("Variance of effects:\n")
cat(sprintf("  Covariate-level SD(ΔS):   %.3f\n", sd(effects_covariate$delta_s)))
cat(sprintf("  Observation-level SD(ΔS): %.3f\n", sd(effects_obs$delta_s)))
cat(sprintf("  Ratio (obs/cov):          %.2f\n\n",
            sd(effects_obs$delta_s) / sd(effects_covariate$delta_s)))

cat(sprintf("  Covariate-level SD(ΔY):   %.3f\n", sd(effects_covariate$delta_y)))
cat(sprintf("  Observation-level SD(ΔY): %.3f\n", sd(effects_obs$delta_y)))
cat(sprintf("  Ratio (obs/cov):          %.2f\n\n",
            sd(effects_obs$delta_y) / sd(effects_covariate$delta_y)))

# ============================================================================
# Diagnosis
# ============================================================================

cat("=== DIAGNOSIS ===\n\n")

if (abs(cor_covariate - cor_obs) < 0.1) {
  cat("✓ Close agreement: Observation-level captures true correlation\n")
} else if (cor_obs < cor_covariate) {
  cat("✗ Observation-level UNDERESTIMATES correlation\n")
  cat("  Likely cause: Treating sampling noise as heterogeneity\n")
  cat("  When reweighting observations, noise breaks the signal\n\n")

  cat("Interpretation:\n")
  cat("  - Covariate-level: Captures true heterogeneity in τ(X)\n")
  cat("  - Observation-level: Treats noise as heterogeneity\n")
  cat("  - For DGPs with no unmeasured U, covariate-level is correct\n")
} else {
  cat("? Observation-level OVERESTIMATES correlation\n")
  cat("  Unexpected - needs investigation\n")
}

cat("\n=== CONCLUSION ===\n\n")
cat("For this DGP (no unmeasured heterogeneity beyond X):\n")
cat(sprintf("  TRUE correlation = %.3f (covariate-level)\n", cor_covariate))
cat(sprintf("  Observation-level = %.3f (includes noise as heterogeneity)\n", cor_obs))
cat("\nObservation-level is biased downward when all heterogeneity is captured by X.\n")
cat("It would be appropriate if there were true unmeasured U varying effects within X strata.\n")
