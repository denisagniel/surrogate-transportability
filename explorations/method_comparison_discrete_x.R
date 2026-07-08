# Method Comparison with Discrete Covariates (Final Version)
#
# Proper framework: discrete X, covariate-level TV ball, no discretization bias

library(tidyverse)
devtools::load_all(".")

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")

# ============================================================================
# DGP: Discrete Covariate with Heterogeneous Treatment Effects
# ============================================================================

#' Generate data with discrete X and heterogeneous treatment effects
#'
#' @param n Sample size
#' @param K Number of discrete types (e.g., K=5 for 5 subgroups)
#' @param scenario Which scenario (1 = high cor/low PTE, 2 = low cor/high PTE)
#' @param seed Random seed
generate_discrete_x_data <- function(n = 500, K = 5, scenario = 1, seed = NULL) {

  if (!is.null(seed)) set.seed(seed)

  # Discrete covariate (types 1 to K)
  # Could represent: age groups, disease severity, genomic subtypes, etc.
  X <- sample(1:K, size = n, replace = TRUE)

  # Treatment assignment
  A <- rbinom(n, 1, 0.5)

  if (scenario == 1) {
    # Scenario 1: High across-study correlation, Low PTE
    # Type-specific treatment effects increase with type
    # Both τ_S and τ_Y correlated across types
    # But S has minimal effect on Y (low mediation)

    tau_S <- seq(0.2, 0.8, length.out = K)  # Increases: 0.2, 0.35, 0.5, 0.65, 0.8
    tau_Y <- seq(0.1, 0.6, length.out = K)  # Increases: 0.1, 0.225, 0.35, 0.475, 0.6

    # Generate outcomes
    S_baseline <- rnorm(n, mean = 0.3, sd = 0.3)
    S_continuous <- S_baseline + tau_S[X] * A + rnorm(n, sd = 0.3)
    S <- as.numeric(S_continuous > 0.5)

    # Y: Small S effect (low mediation)
    Y_baseline <- rnorm(n, mean = 0.3, sd = 0.3)
    Y_continuous <- Y_baseline + tau_Y[X] * A + 0.05 * S + rnorm(n, sd = 0.3)
    Y <- as.numeric(Y_continuous > 0.5)

    truth <- list(
      scenario = "high_cor_low_pte",
      tau_S = tau_S,
      tau_Y = tau_Y,
      s_effect_on_y = 0.05,
      true_cor = cor(tau_S, tau_Y),
      expected_pte = 0.2
    )

  } else if (scenario == 2) {
    # Scenario 2: Low across-study correlation, High PTE
    # τ_S relatively constant or oscillating
    # τ_Y varies with type
    # Strong S→Y (high mediation)

    # τ_S oscillates or is relatively flat
    if (K == 5) {
      tau_S <- c(0.4, 0.3, 0.5, 0.35, 0.45)  # Oscillates around 0.4
    } else {
      tau_S <- 0.4 + 0.1 * sin(2 * pi * (1:K) / K)  # Oscillates
    }

    tau_Y <- seq(0.1, 0.5, length.out = K)  # Increases

    # Generate outcomes
    S_baseline <- rnorm(n, mean = 0.3, sd = 0.3)
    S_continuous <- S_baseline + tau_S[X] * A + rnorm(n, sd = 0.3)
    S <- as.numeric(S_continuous > 0.5)

    # Y: STRONG S effect (high mediation)
    Y_baseline <- rnorm(n, mean = 0.3, sd = 0.3)
    Y_continuous <- Y_baseline + tau_Y[X] * A + 0.4 * S + rnorm(n, sd = 0.3)
    Y <- as.numeric(Y_continuous > 0.5)

    truth <- list(
      scenario = "low_cor_high_pte",
      tau_S = tau_S,
      tau_Y = tau_Y,
      s_effect_on_y = 0.4,
      true_cor = cor(tau_S, tau_Y),
      expected_pte = 0.7
    )
  }

  list(
    data = tibble(X = X, A = A, S = S, Y = Y),
    K = K,
    truth = truth
  )
}

# ============================================================================
# Estimation Functions
# ============================================================================

#' Estimate type-specific treatment effects
estimate_type_specific_effects <- function(data, K) {

  tau_S_hat <- numeric(K)
  tau_Y_hat <- numeric(K)

  for (k in 1:K) {
    mask_k <- data$X == k

    if (sum(mask_k & data$A == 1) > 5 && sum(mask_k & data$A == 0) > 5) {
      tau_S_hat[k] <- mean(data$S[mask_k & data$A == 1]) -
                      mean(data$S[mask_k & data$A == 0])
      tau_Y_hat[k] <- mean(data$Y[mask_k & data$A == 1]) -
                      mean(data$Y[mask_k & data$A == 0])
    } else {
      # Sparse type - use overall average
      tau_S_hat[k] <- mean(data$S[data$A == 1]) - mean(data$S[data$A == 0])
      tau_Y_hat[k] <- mean(data$Y[data$A == 1]) - mean(data$Y[data$A == 0])
    }
  }

  list(tau_S_hat = tau_S_hat, tau_Y_hat = tau_Y_hat)
}

#' Compute across-study correlation using TV ball
compute_across_study_correlation <- function(data, K, lambda = 0.3, M = 500) {

  # Estimate type-specific effects
  effects_hat <- estimate_type_specific_effects(data, K)

  # Compute P0 (observed type distribution)
  P0 <- as.numeric(table(factor(data$X, levels = 1:K))) / nrow(data)

  cat(sprintf("P0 (type distribution, K=%d):\n", K))
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

    # Weighted average: ΔS(Q) = Σ Q(k)τ̂_S(k)
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

#' Compute PTE
compute_pte <- function(data) {
  E_Y_A1 <- mean(data$Y[data$A == 1])
  E_Y_A0 <- mean(data$Y[data$A == 0])
  total_effect <- E_Y_A1 - E_Y_A0

  if (abs(total_effect) < 1e-6) return(NA_real_)

  adjusted_effect <- 0
  for (s_val in sort(unique(data$S))) {
    p_s <- mean(data$S[data$A == 0] == s_val)
    y_a1_s <- data$Y[data$A == 1 & data$S == s_val]
    y_a0_s <- data$Y[data$A == 0 & data$S == s_val]

    if (length(y_a1_s) == 0 || length(y_a0_s) == 0) next

    effect_s <- mean(y_a1_s) - mean(y_a0_s)
    adjusted_effect <- adjusted_effect + p_s * effect_s
  }

  1 - adjusted_effect / total_effect
}

# ============================================================================
# Main Analysis
# ============================================================================

cat("=== METHOD COMPARISON: DISCRETE X (No Discretization) ===\n\n")

# Parameters
N <- 500
K <- 5  # 5 discrete types
LAMBDA <- 0.3
M <- 500  # Number of future studies

# ----------------------------------------------------------------------------
# Scenario 1: High correlation, Low PTE
# ----------------------------------------------------------------------------

cat(strrep("=", 70), "\n")
cat("SCENARIO 1: High Across-Study Correlation, Low PTE\n")
cat(strrep("=", 70), "\n\n")

set.seed(2026)
dgp1 <- generate_discrete_x_data(n = N, K = K, scenario = 1, seed = 2026)

cat("True type-specific treatment effects:\n")
cat("  τ_S: ", paste(sprintf("%.2f", dgp1$truth$tau_S), collapse = ", "), "\n")
cat("  τ_Y: ", paste(sprintf("%.2f", dgp1$truth$tau_Y), collapse = ", "), "\n")
cat(sprintf("  True cor(τ_S, τ_Y) = %.3f\n", dgp1$truth$true_cor))
cat(sprintf("  S effect on Y: %.2f (small - low mediation)\n\n",
            dgp1$truth$s_effect_on_y))

# Compute PTE
pte1 <- compute_pte(dgp1$data)
cat(sprintf("Within-study PTE: %.3f\n\n", pte1))

# Compute across-study correlation
result1 <- compute_across_study_correlation(dgp1$data, K, lambda = LAMBDA, M = M)

cat(sprintf("Estimated type-specific effects:\n"))
cat("  τ̂_S: ", paste(sprintf("%.2f", result1$tau_S_hat), collapse = ", "), "\n")
cat("  τ̂_Y: ", paste(sprintf("%.2f", result1$tau_Y_hat), collapse = ", "), "\n")
cat(sprintf("  cor(τ̂_S, τ̂_Y) = %.3f\n\n", cor(result1$tau_S_hat, result1$tau_Y_hat)))

cat(sprintf("Across-study correlation: %.3f\n\n", result1$correlation))

cat("Summary:\n")
cat(sprintf("  True cor(τ):     %.3f\n", dgp1$truth$true_cor))
cat(sprintf("  Estimated ρ:     %.3f\n", result1$correlation))
cat(sprintf("  PTE:             %.3f (low mediation)\n", pte1))
cat(sprintf("  Divergence:      %.3f (ρ > PTE)\n\n", result1$correlation - pte1))

# ----------------------------------------------------------------------------
# Scenario 2: Low correlation, High PTE
# ----------------------------------------------------------------------------

cat(strrep("=", 70), "\n")
cat("SCENARIO 2: Low Across-Study Correlation, High PTE\n")
cat(strrep("=", 70), "\n\n")

dgp2 <- generate_discrete_x_data(n = N, K = K, scenario = 2, seed = 2027)

cat("True type-specific treatment effects:\n")
cat("  τ_S: ", paste(sprintf("%.2f", dgp2$truth$tau_S), collapse = ", "), "\n")
cat("  τ_Y: ", paste(sprintf("%.2f", dgp2$truth$tau_Y), collapse = ", "), "\n")
cat(sprintf("  True cor(τ_S, τ_Y) = %.3f\n", dgp2$truth$true_cor))
cat(sprintf("  S effect on Y: %.2f (strong - high mediation)\n\n",
            dgp2$truth$s_effect_on_y))

# Compute PTE
pte2 <- compute_pte(dgp2$data)
cat(sprintf("Within-study PTE: %.3f\n\n", pte2))

# Compute across-study correlation
result2 <- compute_across_study_correlation(dgp2$data, K, lambda = LAMBDA, M = M)

cat(sprintf("Estimated type-specific effects:\n"))
cat("  τ̂_S: ", paste(sprintf("%.2f", result2$tau_S_hat), collapse = ", "), "\n")
cat("  τ̂_Y: ", paste(sprintf("%.2f", result2$tau_Y_hat), collapse = ", "), "\n")
cat(sprintf("  cor(τ̂_S, τ̂_Y) = %.3f\n\n", cor(result2$tau_S_hat, result2$tau_Y_hat)))

cat(sprintf("Across-study correlation: %.3f\n\n", result2$correlation))

cat("Summary:\n")
cat(sprintf("  True cor(τ):     %.3f\n", dgp2$truth$true_cor))
cat(sprintf("  Estimated ρ:     %.3f\n", result2$correlation))
cat(sprintf("  PTE:             %.3f (high mediation)\n", pte2))
cat(sprintf("  Divergence:      %.3f (PTE > ρ)\n\n", pte2 - result2$correlation))

# ============================================================================
# Overall Comparison
# ============================================================================

cat(strrep("=", 70), "\n")
cat("OVERALL COMPARISON\n")
cat(strrep("=", 70), "\n\n")

comparison <- tibble(
  Scenario = c("1: High ρ, Low PTE", "2: Low ρ, High PTE"),
  True_Cor = c(dgp1$truth$true_cor, dgp2$truth$true_cor),
  Estimated_Rho = c(result1$correlation, result2$correlation),
  PTE = c(pte1, pte2),
  Divergence = c(result1$correlation - pte1, pte2 - result2$correlation)
)

print(comparison, width = Inf)

cat("\n=== KEY FINDING ===\n")
cat("Across-study correlation and within-study PTE measure different properties:\n")
cat("  - Scenario 1: Good transportability without mediation (ρ > PTE)\n")
cat("  - Scenario 2: Strong mediation without reliable transportability (PTE > ρ)\n")
cat("\nBoth metrics provide complementary information about surrogate quality.\n")
cat("\nNo discretization bias - X is truly discrete.\n")
