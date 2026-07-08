# Method Comparison with Continuous Covariates
#
# Uses continuous X discretized into K bins
# Proper covariate-level TV ball framework

library(tidyverse)
devtools::load_all(".")

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")

# ============================================================================
# DGP: Continuous Covariate with Varying Treatment Effects
# ============================================================================

#' Generate data with continuous X and heterogeneous treatment effects
#'
#' @param n Sample size
#' @param scenario Which scenario (1 = high cor/low PTE, 2 = low cor/high PTE)
#' @param K Number of bins for discretizing X
#' @param seed Random seed
generate_continuous_x_data <- function(n = 500, scenario = 1, K = 10, seed = NULL) {

  if (!is.null(seed)) set.seed(seed)

  # Continuous covariate (e.g., age, biomarker)
  X_continuous <- runif(n, min = 0, max = 1)

  # Discretize into K bins for analysis
  X_bins <- cut(X_continuous, breaks = K, labels = FALSE, include.lowest = TRUE)

  # Treatment assignment
  A <- rbinom(n, 1, 0.5)

  if (scenario == 1) {
    # Scenario 1: High across-study correlation, Low PTE
    # Both τ_S(x) and τ_Y(x) increase with x (correlated effects)
    # But S has minimal effect on Y (low mediation)

    # Treatment effects as smooth functions of X
    tau_S_x <- 0.2 + 0.6 * X_continuous  # Increases from 0.2 to 0.8
    tau_Y_x <- 0.1 + 0.5 * X_continuous  # Increases from 0.1 to 0.6

    # Generate outcomes
    # S: baseline + treatment effect (no confounding for simplicity)
    S_baseline <- rnorm(n, mean = 0.3, sd = 0.3)
    S_continuous <- S_baseline + A * tau_S_x + rnorm(n, sd = 0.3)
    S <- as.numeric(S_continuous > 0.5)  # Binary S

    # Y: baseline + treatment effect + SMALL S effect (low mediation)
    Y_baseline <- rnorm(n, mean = 0.3, sd = 0.3)
    Y_continuous <- Y_baseline + A * tau_Y_x + 0.05 * S + rnorm(n, sd = 0.3)
    Y <- as.numeric(Y_continuous > 0.5)  # Binary Y

    truth <- list(
      scenario = "high_cor_low_pte",
      tau_S_range = c(0.2, 0.8),
      tau_Y_range = c(0.1, 0.6),
      s_effect_on_y = 0.05,
      expected_cor = 0.9,
      expected_pte = 0.2
    )

  } else if (scenario == 2) {
    # Scenario 2: Low/moderate across-study correlation, High PTE
    # τ_S(x) relatively constant (weak effect modification)
    # τ_Y(x) varies more, strong S→Y (high mediation)

    # Treatment effects
    tau_S_x <- 0.4 + 0.1 * sin(2 * pi * X_continuous)  # Oscillates around 0.4
    tau_Y_x <- 0.1 + 0.2 * X_continuous  # Increases but less than scenario 1

    # Generate outcomes
    S_baseline <- rnorm(n, mean = 0.3, sd = 0.3)
    S_continuous <- S_baseline + A * tau_S_x + rnorm(n, sd = 0.3)
    S <- as.numeric(S_continuous > 0.5)

    # Y: STRONG S effect (high mediation)
    Y_baseline <- rnorm(n, mean = 0.3, sd = 0.3)
    Y_continuous <- Y_baseline + A * tau_Y_x + 0.4 * S + rnorm(n, sd = 0.3)
    Y <- as.numeric(Y_continuous > 0.5)

    truth <- list(
      scenario = "low_cor_high_pte",
      tau_S_range = c(0.3, 0.5),
      tau_Y_range = c(0.1, 0.3),
      s_effect_on_y = 0.4,
      expected_cor = 0.3,
      expected_pte = 0.7
    )
  }

  list(
    data = tibble(
      X_continuous = X_continuous,
      X_bin = X_bins,
      A = A,
      S = S,
      Y = Y
    ),
    K = K,
    truth = truth
  )
}

# ============================================================================
# Estimation Functions
# ============================================================================

#' Estimate type-specific treatment effects
#'
#' @param data Data with X_bin, A, S, Y
#' @param K Number of types/bins
#' @return List with tau_S_hat and tau_Y_hat vectors
estimate_bin_specific_effects <- function(data, K) {

  tau_S_hat <- numeric(K)
  tau_Y_hat <- numeric(K)

  for (k in 1:K) {
    mask_k <- data$X_bin == k

    if (sum(mask_k & data$A == 1) > 5 && sum(mask_k & data$A == 0) > 5) {
      # Enough data in this bin
      tau_S_hat[k] <- mean(data$S[mask_k & data$A == 1]) -
                      mean(data$S[mask_k & data$A == 0])
      tau_Y_hat[k] <- mean(data$Y[mask_k & data$A == 1]) -
                      mean(data$Y[mask_k & data$A == 0])
    } else {
      # Too few observations - use overall average
      tau_S_hat[k] <- mean(data$S[data$A == 1]) - mean(data$S[data$A == 0])
      tau_Y_hat[k] <- mean(data$Y[data$A == 1]) - mean(data$Y[data$A == 0])
    }
  }

  list(tau_S_hat = tau_S_hat, tau_Y_hat = tau_Y_hat)
}

#' Compute across-study correlation using TV ball
#'
#' @param data Data with X_bin, A, S, Y
#' @param K Number of types/bins
#' @param lambda TV ball radius
#' @param M Number of Q samples
#' @return List with correlation and treatment effects
compute_across_study_correlation <- function(data, K, lambda = 0.3, M = 500) {

  # Estimate bin-specific effects
  effects_hat <- estimate_bin_specific_effects(data, K)

  # Compute P0 (observed covariate distribution)
  P0 <- as.numeric(table(factor(data$X_bin, levels = 1:K))) / nrow(data)

  cat(sprintf("P0 (covariate distribution across %d bins):\n", K))
  print(round(P0, 3))
  cat("\n")

  # Sample Q from TV ball
  cat(sprintf("Sampling %d distributions from TV ball (λ=%.2f)...\n", M, lambda))
  Q_samples <- hit_and_run_tv_ball(
    P0 = P0,
    lambda = lambda,
    n_samples = M,
    burn_in = 1000,
    thin = 10,
    verbose = FALSE
  )

  # Compute treatment effects for each Q
  treatment_effects <- map_dfr(1:M, function(i) {
    if (i %% 100 == 0) cat(sprintf("  Sample %d/%d\r", i, M))

    Q <- Q_samples[i, ]

    # Weighted average of bin-specific effects
    delta_s <- sum(Q * effects_hat$tau_S_hat)
    delta_y <- sum(Q * effects_hat$tau_Y_hat)

    tibble(
      study_id = i,
      delta_s = delta_s,
      delta_y = delta_y
    )
  })

  cat("\n")

  # Compute correlation
  correlation <- functional_correlation(treatment_effects)

  list(
    correlation = correlation,
    treatment_effects = treatment_effects,
    P0 = P0,
    tau_S_hat = effects_hat$tau_S_hat,
    tau_Y_hat = effects_hat$tau_Y_hat
  )
}

#' Compute PTE (Proportion of Treatment Effect Explained)
compute_pte <- function(data) {
  # Total effect
  E_Y_A1 <- mean(data$Y[data$A == 1])
  E_Y_A0 <- mean(data$Y[data$A == 0])
  total_effect <- E_Y_A1 - E_Y_A0

  if (abs(total_effect) < 1e-6) return(NA_real_)

  # Adjusted effect (conditional on S)
  adjusted_effect <- 0
  for (s_val in sort(unique(data$S))) {
    p_s <- mean(data$S[data$A == 0] == s_val)

    y_a1_s <- data$Y[data$A == 1 & data$S == s_val]
    y_a0_s <- data$Y[data$A == 0 & data$S == s_val]

    if (length(y_a1_s) == 0 || length(y_a0_s) == 0) next

    effect_s <- mean(y_a1_s) - mean(y_a0_s)
    adjusted_effect <- adjusted_effect + p_s * effect_s
  }

  pte <- 1 - adjusted_effect / total_effect
  return(pte)
}

# ============================================================================
# Test Both Scenarios
# ============================================================================

cat("=== METHOD COMPARISON: CONTINUOUS X (K bins) ===\n\n")

# Parameters
N <- 500
K <- 10  # Number of bins for discretization
LAMBDA <- 0.3
M <- 200  # Number of future studies to sample

# ----------------------------------------------------------------------------
# Scenario 1: High correlation, Low PTE
# ----------------------------------------------------------------------------

cat(strrep("=", 70), "\n")
cat("SCENARIO 1: High Across-Study Correlation, Low PTE\n")
cat(strrep("=", 70), "\n\n")

set.seed(2026)
dgp1 <- generate_continuous_x_data(n = N, scenario = 1, K = K, seed = 2026)

cat("DGP characteristics:\n")
cat(sprintf("  τ_S(x) range: [%.2f, %.2f]\n",
            dgp1$truth$tau_S_range[1], dgp1$truth$tau_S_range[2]))
cat(sprintf("  τ_Y(x) range: [%.2f, %.2f]\n",
            dgp1$truth$tau_Y_range[1], dgp1$truth$tau_Y_range[2]))
cat(sprintf("  S effect on Y: %.2f (small - low mediation)\n",
            dgp1$truth$s_effect_on_y))
cat(sprintf("  Expected ρ: %.2f, Expected PTE: %.2f\n\n",
            dgp1$truth$expected_cor, dgp1$truth$expected_pte))

# Compute PTE
pte1 <- compute_pte(dgp1$data)
cat(sprintf("Within-study PTE: %.3f\n\n", pte1))

# Compute across-study correlation
result1 <- compute_across_study_correlation(dgp1$data, K, lambda = LAMBDA, M = M)
cat(sprintf("Across-study correlation: %.3f\n\n", result1$correlation))

cat("Summary:\n")
cat(sprintf("  PTE:         %.3f (low mediation)\n", pte1))
cat(sprintf("  Correlation: %.3f (high transportability)\n", result1$correlation))
cat(sprintf("  Divergence:  %.3f (ρ > PTE)\n\n", result1$correlation - pte1))

# ----------------------------------------------------------------------------
# Scenario 2: Low correlation, High PTE
# ----------------------------------------------------------------------------

cat(paste(rep("=", 70), collapse=""), "\\n")
cat("SCENARIO 2: Low Across-Study Correlation, High PTE\n")
cat(strrep("=", 70), "\\n\\n")

dgp2 <- generate_continuous_x_data(n = N, scenario = 2, K = K, seed = 2027)

cat("DGP characteristics:\n")
cat(sprintf("  τ_S(x) range: [%.2f, %.2f] (oscillates - weak heterogeneity)\n",
            dgp2$truth$tau_S_range[1], dgp2$truth$tau_S_range[2]))
cat(sprintf("  τ_Y(x) range: [%.2f, %.2f]\n",
            dgp2$truth$tau_Y_range[1], dgp2$truth$tau_Y_range[2]))
cat(sprintf("  S effect on Y: %.2f (strong - high mediation)\n",
            dgp2$truth$s_effect_on_y))
cat(sprintf("  Expected ρ: %.2f, Expected PTE: %.2f\n\n",
            dgp2$truth$expected_cor, dgp2$truth$expected_pte))

# Compute PTE
pte2 <- compute_pte(dgp2$data)
cat(sprintf("Within-study PTE: %.3f\n\n", pte2))

# Compute across-study correlation
result2 <- compute_across_study_correlation(dgp2$data, K, lambda = LAMBDA, M = M)
cat(sprintf("Across-study correlation: %.3f\n\n", result2$correlation))

cat("Summary:\n")
cat(sprintf("  PTE:         %.3f (high mediation)\n", pte2))
cat(sprintf("  Correlation: %.3f (moderate transportability)\n", result2$correlation))
cat(sprintf("  Divergence:  %.3f (PTE > ρ)\n\n", pte2 - result2$correlation))

# ============================================================================
# Overall Comparison
# ============================================================================

cat(paste(rep("=", 70), collapse=""), "\\n")
cat("OVERALL COMPARISON\n")
cat(strrep("=", 70), "\\n\\n")

comparison <- tibble(
  Scenario = c("1: High ρ, Low PTE", "2: Low ρ, High PTE"),
  PTE = c(pte1, pte2),
  Correlation = c(result1$correlation, result2$correlation),
  Divergence = c(result1$correlation - pte1, pte2 - result2$correlation)
)

print(comparison)

cat("\n=== KEY FINDING ===\n")
cat("Across-study correlation and within-study PTE measure different properties:\n")
cat("  - Scenario 1: Good transportability without mediation (ρ > PTE)\n")
cat("  - Scenario 2: Good mediation without reliable transportability (PTE > ρ)\n")
cat("\nBoth metrics provide complementary information about surrogate quality.\n")
