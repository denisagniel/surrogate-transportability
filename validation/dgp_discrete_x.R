#' Generate data from discrete X DGP for TV ball validation
#'
#' Calibrated to produce high PTE (~0.7) but near-zero correlation (~0.0 to 0.1)
#' across studies with varying P(X=1) within TV ball.
#'
#' @param n Sample size
#' @param p_X Probability that X=1 (default: 0.5 for P₀)
#' @param params Named list of DGP parameters (if NULL, uses default)
#' @param seed Random seed
#' @return Data frame with columns X, A, S, Y
#'
#' @details
#' **Why discrete X?**
#' The TV ball correlation method requires discrete X because:
#' - TV distance is only defined between probability distributions
#' - The sampler reweights existing observations (can't generate new X values)
#' - Continuous X would require discretization or different approach
#'
#' **Binary X formulation:**
#' X ∈ {0, 1} with P₀(X=1) = 0.5
#' Studies vary by P(X=1) ∈ [0.5-λ, 0.5+λ]
#'
#' **TV ball geometry:**
#' For binary X, TV distance is TV(Q, P₀) = |q - p₀| where q = P_Q(X=1)
#' TV ball B_λ(P₀) = {Q : |q - 0.5| ≤ λ} = [0.5-λ, 0.5+λ]
#'
#' **DGP structure (from slides):**
#' S = (γ_A + γ_AX·X)·A + ε_S
#' Y = (β_A + β_AX·X)·A + β_S·S + β_SX·S·X + ε_Y
#'
#' Treatment effects as function of p = P(X=1):
#' - ΔS(p) = γ_A + γ_AX·p
#' - ΔY(p) ≈ β_A + β_S·γ_A + (β_AX + β_S·γ_AX + β_SX·γ_A)·p
#'
#' **Calibration:**
#' Parameters chosen via explorations/calibrate_discrete_x_dgp.R to achieve:
#' - PTE ≈ 0.7 in reference study (p=0.5)
#' - Correlation ≈ 0 across studies in TV ball (λ=0.3)
#'
#' @examples
#' # Generate reference study
#' data_P0 <- generate_dgp_discrete_x(n = 500, p_X = 0.5)
#'
#' # Generate study with higher P(X=1)
#' data_Q <- generate_dgp_discrete_x(n = 500, p_X = 0.7)
#'
#' # Compute treatment effects
#' Delta_S_P0 <- mean(data_P0$S[data_P0$A==1]) - mean(data_P0$S[data_P0$A==0])
#' Delta_S_Q <- mean(data_Q$S[data_Q$A==1]) - mean(data_Q$S[data_Q$A==0])
generate_dgp_discrete_x <- function(n, p_X = 0.5, params = NULL, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Default parameters (from calibration: explorations/calibrate_discrete_x_dgp.R)
  # Calibrated to achieve PTE ≈ 0.91 and correlation ≈ 0.07 (validated with n=100k)
  if (is.null(params)) {
    params <- list(
      gamma_A = 1.0,      # Baseline treatment effect on S
      gamma_AX = 0.5,     # A×X interaction for S
      beta_A = 0.25,      # Direct effect of A on Y
      beta_AX = -0.3,     # Direct A×X interaction (calibrated from -0.4)
      beta_S = 0.9,       # Mediation (S→Y)
      beta_SX = -0.1,     # S×X interaction (calibrated from -0.05)
      sigma_S = 0.5,      # Error SD for S
      sigma_Y = 0.5       # Error SD for Y
    )
  }

  # Generate binary X
  X <- rbinom(n, 1, p_X)

  # Generate treatment assignment
  A <- rbinom(n, 1, 0.5)

  # Generate S: S = (γ_A + γ_AX·X)·A + ε_S
  S <- (params$gamma_A + params$gamma_AX * X) * A +
       rnorm(n, sd = params$sigma_S)

  # Generate Y: Y = (β_A + β_AX·X)·A + β_S·S + β_SX·S·X + ε_Y
  Y <- (params$beta_A + params$beta_AX * X) * A +
       params$beta_S * S +
       params$beta_SX * S * X +
       rnorm(n, sd = params$sigma_Y)

  data.frame(X = X, A = A, S = S, Y = Y)
}

#' Compute true correlation for discrete X DGP over TV ball
#'
#' Samples many distributions from TV ball B_λ(P₀) and computes true correlation
#' between ΔS and ΔY across the study distribution.
#'
#' @param p_X_0 Reference probability P₀(X=1) (default: 0.5)
#' @param lambda TV ball radius (default: 0.3)
#' @param n_studies Number of studies to sample from TV ball (default: 100)
#' @param n_per_study Sample size per study for stable effect estimates (default: 50000)
#' @param params DGP parameters (if NULL, uses default)
#' @param seed Random seed for reproducibility
#' @return List with:
#'   - correlation: Numeric, the true correlation
#'   - Delta_S: Vector of treatment effects on S
#'   - Delta_Y: Vector of treatment effects on Y
#'   - p_X_values: Vector of P(X=1) values sampled
#'   - p_X_range: TV ball bounds [p_X_0 - λ, p_X_0 + λ]
#'
#' @details
#' **TV ball for binary X:**
#' For X ∈ {0, 1} with P₀(X=1) = p₀, the TV ball is:
#' B_λ(P₀) = {Q : |P_Q(X=1) - p₀| ≤ λ}
#'         = [max(0, p₀-λ), min(1, p₀+λ)]
#'
#' **Sampling strategy:**
#' We sample P_Q(X=1) uniformly from [p₀-λ, p₀+λ] (bounded by [0,1]).
#' For each sampled q, we generate a large study with P(X=1)=q and compute
#' the true treatment effects ΔS(q) and ΔY(q).
#'
#' **Interpretation:**
#' The returned correlation is the "true" correlation that tv_ball_correlation_IF()
#' should estimate. This is the correlation between treatment effects across
#' studies in the TV ball.
#'
#' @examples
#' # Compute true correlation for λ=0.3
#' true_cor <- compute_true_correlation_discrete_x(
#'   p_X_0 = 0.5,
#'   lambda = 0.3,
#'   n_studies = 100
#' )
#' print(true_cor$correlation)
#'
#' # Plot treatment effects
#' plot(true_cor$Delta_S, true_cor$Delta_Y,
#'      xlab = "ΔS", ylab = "ΔY",
#'      main = sprintf("Correlation: %.3f", true_cor$correlation))
compute_true_correlation_discrete_x <- function(p_X_0 = 0.5,
                                               lambda = 0.3,
                                               n_studies = 100,
                                               n_per_study = 50000,
                                               params = NULL,
                                               seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # TV ball bounds for binary X
  p_X_min <- max(0, p_X_0 - lambda)
  p_X_max <- min(1, p_X_0 + lambda)

  # Sample p_X values uniformly from TV ball
  p_X_values <- seq(p_X_min, p_X_max, length.out = n_studies)

  Delta_S <- numeric(n_studies)
  Delta_Y <- numeric(n_studies)

  for (i in seq_along(p_X_values)) {
    # Generate large study with p_X = p_X_values[i]
    data_i <- generate_dgp_discrete_x(
      n = n_per_study,
      p_X = p_X_values[i],
      params = params
    )

    # True treatment effects (large n, so estimates ≈ truth)
    Delta_S[i] <- mean(data_i$S[data_i$A == 1]) - mean(data_i$S[data_i$A == 0])
    Delta_Y[i] <- mean(data_i$Y[data_i$A == 1]) - mean(data_i$Y[data_i$A == 0])
  }

  list(
    correlation = cor(Delta_S, Delta_Y),
    Delta_S = Delta_S,
    Delta_Y = Delta_Y,
    p_X_values = p_X_values,
    p_X_range = c(p_X_min, p_X_max)
  )
}

#' Compute analytical treatment effects as function of P(X=1)
#'
#' For the discrete X DGP, treatment effects can be computed analytically
#' as functions of p = P(X=1).
#'
#' @param p_X Probability that X=1
#' @param params DGP parameters (if NULL, uses default)
#' @return Named vector with Delta_S and Delta_Y
#'
#' @details
#' **Analytical formulas:**
#' Given X ∈ {0, 1} with P(X=1) = p:
#'
#' E[X] = p
#' E[X²] = p
#'
#' Treatment effect on S:
#' ΔS(p) = E[S|A=1] - E[S|A=0]
#'       = γ_A + γ_AX·E[X]
#'       = γ_A + γ_AX·p
#'
#' Treatment effect on Y (approximate, ignoring error terms):
#' ΔY(p) ≈ E[(β_A + β_AX·X)·A + β_S·S + β_SX·S·X | A=1]
#'         - E[(β_A + β_AX·X)·A + β_S·S + β_SX·S·X | A=0]
#'       = (β_A + β_AX·p) + β_S·ΔS(p) + β_SX·E[S·X|A=1]
#'       ≈ β_A + β_AX·p + β_S·(γ_A + γ_AX·p) + β_SX·(γ_A + γ_AX·p)·p
#'
#' Simplifying:
#' ΔY(p) ≈ (β_A + β_S·γ_A) + (β_AX + β_S·γ_AX + β_SX·γ_A)·p + β_SX·γ_AX·p²
#'
#' For near-zero correlation between ΔS and ΔY, we need the linear terms
#' in p to approximately cancel.
#'
#' @examples
#' # Compute effects at p=0.5
#' effects <- compute_analytical_effects(0.5)
#' print(effects)
#'
#' # Compare to empirical estimates
#' data <- generate_dgp_discrete_x(n = 100000, p_X = 0.5)
#' empirical_Delta_S <- mean(data$S[data$A==1]) - mean(data$S[data$A==0])
#' empirical_Delta_Y <- mean(data$Y[data$A==1]) - mean(data$Y[data$A==0])
#' cat(sprintf("Analytical: ΔS=%.3f, ΔY=%.3f\n",
#'             effects["Delta_S"], effects["Delta_Y"]))
#' cat(sprintf("Empirical:  ΔS=%.3f, ΔY=%.3f\n",
#'             empirical_Delta_S, empirical_Delta_Y))
compute_analytical_effects <- function(p_X, params = NULL) {
  if (is.null(params)) {
    params <- list(
      gamma_A = 1.0,
      gamma_AX = 0.5,
      beta_A = 0.25,
      beta_AX = -0.3,     # Calibrated
      beta_S = 0.9,
      beta_SX = -0.1      # Calibrated
    )
  }

  # ΔS(p) = γ_A + γ_AX·p
  Delta_S <- params$gamma_A + params$gamma_AX * p_X

  # ΔY(p) ≈ (β_A + β_S·γ_A) + (β_AX + β_S·γ_AX + β_SX·γ_A)·p + β_SX·γ_AX·p²
  Delta_Y <- (params$beta_A + params$beta_S * params$gamma_A) +
             (params$beta_AX + params$beta_S * params$gamma_AX +
              params$beta_SX * params$gamma_A) * p_X +
             params$beta_SX * params$gamma_AX * p_X^2

  c(Delta_S = Delta_S, Delta_Y = Delta_Y)
}

#' Validate discrete X DGP properties
#'
#' Checks that the DGP satisfies required properties:
#' - PTE ≈ 0.7 in reference study
#' - Correlation near zero within TV ball
#' - Effects vary meaningfully across TV ball
#'
#' @param params DGP parameters (if NULL, uses default)
#' @param p_X_0 Reference probability (default: 0.5)
#' @param lambda TV ball radius (default: 0.3)
#' @param n_large Large sample size for stable estimates
#' @return List with validation results
#'
#' @examples
#' validation <- validate_dgp_discrete_x()
#' print(validation)
validate_dgp_discrete_x <- function(params = NULL,
                                   p_X_0 = 0.5,
                                   lambda = 0.3,
                                   n_large = 100000) {
  # Compute correlation across TV ball
  cor_result <- compute_true_correlation_discrete_x(
    p_X_0 = p_X_0,
    lambda = lambda,
    n_studies = 100,
    n_per_study = n_large,
    params = params
  )

  # Generate reference study for PTE
  data_P0 <- generate_dgp_discrete_x(n_large, p_X = p_X_0, params = params)

  # Compute PTE (simple version)
  Delta_S_P0 <- mean(data_P0$S[data_P0$A == 1]) - mean(data_P0$S[data_P0$A == 0])
  Delta_Y_P0 <- mean(data_P0$Y[data_P0$A == 1]) - mean(data_P0$Y[data_P0$A == 0])

  # Direct effect (from parameters)
  if (is.null(params)) {
    params <- list(beta_A = 0.25, beta_AX = -0.4)
  }
  direct_effect <- params$beta_A + params$beta_AX * p_X_0
  pte <- 1 - direct_effect / Delta_Y_P0

  # Check variation across TV ball
  Delta_S_range <- max(cor_result$Delta_S) - min(cor_result$Delta_S)
  Delta_Y_range <- max(cor_result$Delta_Y) - min(cor_result$Delta_Y)

  list(
    pte = pte,
    correlation = cor_result$correlation,
    Delta_S_P0 = Delta_S_P0,
    Delta_Y_P0 = Delta_Y_P0,
    Delta_S_range = Delta_S_range,
    Delta_Y_range = Delta_Y_range,
    p_X_range = cor_result$p_X_range,
    checks = list(
      pte_high = abs(pte - 0.7) < 0.15,  # PTE within 0.15 of target
      correlation_low = abs(cor_result$correlation) < 0.15,  # Near zero
      meaningful_variation = Delta_S_range > 0.1 && Delta_Y_range > 0.05
    )
  )
}
