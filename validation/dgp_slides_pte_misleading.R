#' Generate data from slides DGP (PTE Misleading Example)
#'
#' Calibrated to produce high PTE (~0.7) but near-zero correlation (~0.05)
#' across studies with varying mean covariate X̄.
#'
#' @param n Sample size
#' @param X_mean Mean of covariate X (default: 0 for P₀)
#' @param seed Random seed
#' @return Data frame with columns X, A, S, Y
#'
#' @details
#' Treatment effect on S: ΔS = 1.0 + 0.5·X̄ (increases with X̄)
#' Treatment effect on Y: ΔY ≈ 0.6 - 0.4·X̄ (decreases with X̄)
#' This creates opposite effect modification → near-zero correlation
#'
#' Parameters from inst/presentation/create_figures.R:
#' - gamma_A = 1.0, gamma_AX = 0.5 (treatment effect on S)
#' - beta_A = 0.25, beta_AX = -0.4 (direct effect)
#' - beta_S = 0.9, beta_SX = -0.05 (mediation)
#' - sigma_S = sigma_Y = 0.5 (error SDs)
generate_dgp_slides <- function(n, X_mean = 0, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Parameters from slides (inst/presentation/create_figures.R lines 393-438)
  gamma_0 <- 0
  gamma_A <- 1.0      # Baseline treatment effect on S
  gamma_AX <- 0.5     # Moderate A×X interaction

  beta_0 <- 0
  beta_A <- 0.25      # Small direct effect (for higher PTE)
  beta_AX <- -0.4     # Negative interaction (creates opposite effect modification)
  beta_S <- 0.9       # Strong mediation (for higher PTE)
  beta_SX <- -0.05    # Small negative S×X

  sigma_S <- 0.5
  sigma_Y <- 0.5

  # Generate data
  X <- rnorm(n, mean = X_mean, sd = 1)
  A <- rbinom(n, 1, 0.5)

  # S = (gamma_A + gamma_AX * X) * A + ε_S
  S <- (gamma_A + gamma_AX * X) * A + rnorm(n, sd = sigma_S)

  # Y = beta_A * A + beta_AX * X * A + beta_S * S + beta_SX * S * X + ε_Y
  Y <- (beta_A + beta_AX * X) * A + beta_S * S + beta_SX * S * X +
       rnorm(n, sd = sigma_Y)

  data.frame(X = X, A = A, S = S, Y = Y)
}

#' Compute true correlation for slides DGP
#'
#' Simulates many studies with varying X̄ and computes true correlation
#' between ΔS and ΔY across the study distribution.
#'
#' @param n_studies Number of studies to simulate (default: 100)
#' @param n_per_study Sample size per study (default: 10000 for stability)
#' @param X_mean_range Range of X̄ values across studies (default: [-1.5, 1.5])
#' @param seed Random seed for reproducibility
#' @return Numeric: true correlation
#'
#' @note TV ball radius needed to cover X̄ ∈ [-1.5, 1.5]:
#'   - For X ~ N(X̄, 1), TV distance ≈ 2*Φ(|X̄|/2) - 1
#'   - X̄ = ±1.5 → TV ≈ 0.547
#'   - Therefore use λ ≥ 0.55 to cover this range
#'
#' @details
#' This function computes the "true" correlation that our inference method
#' should estimate. It generates many studies with varying X̄, computes
#' the true treatment effects ΔS and ΔY in each, and returns their correlation.
#'
#' For the slides DGP, this should be near-zero (≈ 0.0 to 0.1) because:
#' - ΔS increases with X̄ (positive slope)
#' - ΔY decreases with X̄ (negative slope)
#' - Creates opposite effect modification → near-zero correlation
compute_true_correlation_slides <- function(n_studies = 100,
                                           n_per_study = 10000,
                                           X_mean_range = c(-1.5, 1.5),
                                           seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  X_means <- seq(X_mean_range[1], X_mean_range[2], length.out = n_studies)

  Delta_S <- numeric(n_studies)
  Delta_Y <- numeric(n_studies)

  for (i in seq_along(X_means)) {
    data_i <- generate_dgp_slides(n_per_study, X_mean = X_means[i])

    # True treatment effects (large n, so estimates ≈ truth)
    Delta_S[i] <- mean(data_i$S[data_i$A == 1]) - mean(data_i$S[data_i$A == 0])
    Delta_Y[i] <- mean(data_i$Y[data_i$A == 1]) - mean(data_i$Y[data_i$A == 0])
  }

  cor(Delta_S, Delta_Y)
}
