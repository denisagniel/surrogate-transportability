# Simulation: Correlated Outcomes, Uncorrelated Treatment Effects
#
# Demonstrate case where S and Y are correlated, but ΔS and ΔY are not
# This represents a prognostic but not predictive surrogate

library(tidyverse)
library(MASS)  # for mvrnorm

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")

#' Generate data where outcomes are correlated but treatment effects are not
#'
#' Key idea: S and Y share common baseline variation (prognostic),
#' but treatment affects them independently
#'
#' @param n Sample size
#' @param K Number of types
#' @param rho_outcome Correlation between S and Y outcomes
#' @param rho_effect Correlation between treatment effects (target: 0)
#' @return List with data and parameters
generate_uncorrelated_effects_data <- function(
  n = 1000,
  K = 10,
  rho_outcome = 0.7,  # S and Y are correlated
  rho_effect = 0.0    # but effects are not
) {

  # Type probabilities
  P0 <- rep(1/K, K)
  types <- sample(1:K, n, replace = TRUE, prob = P0)

  # Treatment assignment
  Z <- rbinom(n, 1, 0.5)

  # Type-specific baseline values (shared variation)
  # This creates correlation between S and Y
  baseline_mean <- seq(-1, 1, length.out = K)

  # Type-specific treatment effects (independent)
  # Generate with specified correlation (0 for uncorrelated)
  set.seed(123)

  if (rho_effect == 0) {
    # Completely independent
    tau_S <- rnorm(K, mean = 0.5, sd = 0.3)
    tau_Y <- rnorm(K, mean = 0.5, sd = 0.3)
  } else {
    # Correlated effects (for comparison)
    effects <- mvrnorm(
      n = K,
      mu = c(0.5, 0.5),
      Sigma = matrix(c(0.3^2, rho_effect * 0.3^2,
                       rho_effect * 0.3^2, 0.3^2), 2, 2)
    )
    tau_S <- effects[, 1]
    tau_Y <- effects[, 2]
  }

  # Generate outcomes
  # Key: baseline creates correlation, but treatment effects are independent

  S <- numeric(n)
  Y <- numeric(n)

  for (i in 1:n) {
    type_i <- types[i]

    # Baseline (shared variation - creates outcome correlation)
    baseline_i <- baseline_mean[type_i]

    # For control: S and Y are correlated through shared baseline
    if (Z[i] == 0) {
      # Correlated outcomes in control group
      outcomes <- mvrnorm(
        n = 1,
        mu = c(baseline_i, baseline_i),
        Sigma = matrix(c(1, rho_outcome, rho_outcome, 1), 2, 2)
      )
      S[i] <- outcomes[1]
      Y[i] <- outcomes[2]
    } else {
      # Treated: add independent treatment effects
      outcomes <- mvrnorm(
        n = 1,
        mu = c(baseline_i + tau_S[type_i], baseline_i + tau_Y[type_i]),
        Sigma = matrix(c(1, rho_outcome, rho_outcome, 1), 2, 2)
      )
      S[i] <- outcomes[1]
      Y[i] <- outcomes[2]
    }
  }

  data <- tibble(
    type = types,
    Z = Z,
    S = S,
    Y = Y
  )

  # Compute empirical correlations
  cat("========================================\n")
  cat("DATA GENERATION SUMMARY\n")
  cat("========================================\n\n")

  cat(sprintf("Sample size: n = %d, K = %d types\n\n", n, K))

  cat("Outcome correlations:\n")
  cor_S_Y_overall <- cor(S, Y)
  cor_S_Y_control <- cor(S[Z == 0], Y[Z == 0])
  cor_S_Y_treated <- cor(S[Z == 1], Y[Z == 1])

  cat(sprintf("  Overall: cor(S, Y) = %.3f\n", cor_S_Y_overall))
  cat(sprintf("  Control: cor(S, Y | Z=0) = %.3f\n", cor_S_Y_control))
  cat(sprintf("  Treated: cor(S, Y | Z=1) = %.3f\n", cor_S_Y_treated))

  cat("\nType-level treatment effects:\n")
  cat(sprintf("  cor(τ_S, τ_Y) = %.3f (population parameter)\n", cor(tau_S, tau_Y)))

  # Empirical treatment effects by type
  tau_S_emp <- numeric(K)
  tau_Y_emp <- numeric(K)

  for (k in 1:K) {
    mask_k <- types == k
    if (sum(mask_k & Z == 1) > 0 && sum(mask_k & Z == 0) > 0) {
      tau_S_emp[k] <- mean(S[mask_k & Z == 1]) - mean(S[mask_k & Z == 0])
      tau_Y_emp[k] <- mean(Y[mask_k & Z == 1]) - mean(Y[mask_k & Z == 0])
    }
  }

  cat(sprintf("  cor(τ̂_S, τ̂_Y) = %.3f (empirical)\n\n",
              cor(tau_S_emp, tau_Y_emp)))

  # Return
  list(
    data = data,
    P0 = P0,
    tau_S = tau_S,
    tau_Y = tau_Y,
    tau_S_emp = tau_S_emp,
    tau_Y_emp = tau_Y_emp,
    params = list(
      rho_outcome = rho_outcome,
      rho_effect = rho_effect,
      cor_outcome = cor_S_Y_overall,
      cor_effect_pop = cor(tau_S, tau_Y),
      cor_effect_emp = cor(tau_S_emp, tau_Y_emp)
    )
  )
}

#' Analyze TV ball geometry with uncorrelated effects
#'
#' @param dgp Output from generate_uncorrelated_effects_data()
#' @param lambda TV ball radius
#' @param M Number of Q samples
#' @return Analysis results
analyze_uncorrelated_effects <- function(
  dgp,
  lambda = 0.3,
  M = 2000
) {

  cat("========================================\n")
  cat("TV BALL GEOMETRY ANALYSIS\n")
  cat("========================================\n\n")

  cat(sprintf("Sampling %d distributions from TV ball (λ = %.2f)...\n\n", M, lambda))

  # Sample from TV ball
  Q_samples <- hit_and_run_tv_ball(
    P0 = dgp$P0,
    lambda = lambda,
    n_samples = M,
    burn_in = 1000,
    thin = 10,
    verbose = TRUE
  )

  # Compute treatment effects for each Q
  Delta_S <- Q_samples %*% dgp$tau_S
  Delta_Y <- Q_samples %*% dgp$tau_Y

  # Correlation
  cor_across_study <- cor(Delta_S, Delta_Y)

  cat("\n========================================\n")
  cat("RESULTS\n")
  cat("========================================\n\n")

  cat("Population parameters:\n")
  cat(sprintf("  cor(S, Y) = %.3f (outcomes correlated)\n",
              dgp$params$cor_outcome))
  cat(sprintf("  cor(τ_S, τ_Y) = %.3f (effects uncorrelated)\n",
              dgp$params$cor_effect_pop))

  cat("\nTV ball analysis:\n")
  cat(sprintf("  cor(ΔS(Q), ΔY(Q)) = %.3f\n", cor_across_study))

  cat("\nInterpretation:\n")
  if (abs(cor_across_study) < 0.2) {
    cat("  → Treatment effects are NOT correlated across studies\n")
    cat("  → S is PROGNOSTIC (correlated with Y)\n")
    cat("  → But S is NOT PREDICTIVE (treatment effects uncorrelated)\n")
    cat("  → Poor surrogate for transportability!\n")
  } else if (cor_across_study > 0.5) {
    cat("  → Treatment effects ARE correlated across studies\n")
    cat("  → S is both PROGNOSTIC and PREDICTIVE\n")
    cat("  → Good surrogate for transportability\n")
  } else {
    cat("  → Moderate correlation across studies\n")
    cat("  → Surrogate quality is intermediate\n")
  }

  # Scatter plot
  plot_data <- tibble(
    Delta_S = as.numeric(Delta_S),
    Delta_Y = as.numeric(Delta_Y)
  )

  p <- ggplot(plot_data, aes(x = Delta_S, y = Delta_Y)) +
    geom_point(alpha = 0.3, size = 1) +
    geom_smooth(method = "lm", se = TRUE, color = "steelblue") +
    labs(
      title = "Across-Study Treatment Effect Correlation",
      subtitle = sprintf("cor(ΔS(Q), ΔY(Q)) = %.3f", cor_across_study),
      x = "Treatment effect on S: ΔS(Q) = Q'τ_S",
      y = "Treatment effect on Y: ΔY(Q) = Q'τ_Y",
      caption = sprintf("M = %d samples from TV ball (λ = %.2f)", M, lambda)
    ) +
    theme_minimal(base_size = 12)

  list(
    cor_across_study = cor_across_study,
    Delta_S = Delta_S,
    Delta_Y = Delta_Y,
    plot = p
  )
}

#' Compare scenarios: correlated vs uncorrelated effects
#'
#' @param n Sample size
#' @param K Number of types
#' @param lambda TV ball radius
#' @param M Number of Q samples
compare_scenarios <- function(
  n = 1000,
  K = 10,
  lambda = 0.3,
  M = 2000
) {

  cat("========================================\n")
  cat("SCENARIO COMPARISON\n")
  cat("========================================\n\n")

  # Scenario 1: Correlated effects (good surrogate)
  cat("SCENARIO 1: Correlated Treatment Effects\n")
  cat("==========================================\n\n")

  dgp1 <- generate_uncorrelated_effects_data(
    n = n, K = K,
    rho_outcome = 0.7,
    rho_effect = 0.7  # Effects ARE correlated
  )

  analysis1 <- analyze_uncorrelated_effects(dgp1, lambda, M)

  # Scenario 2: Uncorrelated effects (poor surrogate)
  cat("\n\nSCENARIO 2: Uncorrelated Treatment Effects\n")
  cat("============================================\n\n")

  dgp2 <- generate_uncorrelated_effects_data(
    n = n, K = K,
    rho_outcome = 0.7,  # Outcomes still correlated
    rho_effect = 0.0    # But effects NOT correlated
  )

  analysis2 <- analyze_uncorrelated_effects(dgp2, lambda, M)

  # Comparison
  cat("\n\n========================================\n")
  cat("COMPARISON\n")
  cat("========================================\n\n")

  results <- tibble(
    scenario = c("Correlated Effects", "Uncorrelated Effects"),
    cor_outcome = c(dgp1$params$cor_outcome, dgp2$params$cor_outcome),
    cor_effect_pop = c(dgp1$params$cor_effect_pop, dgp2$params$cor_effect_pop),
    cor_across_study = c(analysis1$cor_across_study, analysis2$cor_across_study)
  )

  print(results)

  cat("\nKey insight:\n")
  cat("  Outcome correlation (prognostic) ≠ Effect correlation (predictive)\n")
  cat("  Only effect correlation predicts transportability!\n")

  # Combined plot
  plot_data <- bind_rows(
    tibble(
      scenario = "Correlated Effects\n(Good Surrogate)",
      Delta_S = as.numeric(analysis1$Delta_S),
      Delta_Y = as.numeric(analysis1$Delta_Y)
    ),
    tibble(
      scenario = "Uncorrelated Effects\n(Poor Surrogate)",
      Delta_S = as.numeric(analysis2$Delta_S),
      Delta_Y = as.numeric(analysis2$Delta_Y)
    )
  )

  p_combined <- ggplot(plot_data, aes(x = Delta_S, y = Delta_Y)) +
    geom_point(alpha = 0.2, size = 0.8) +
    geom_smooth(method = "lm", se = TRUE, color = "steelblue") +
    facet_wrap(~scenario, scales = "free") +
    labs(
      title = "Treatment Effect Correlation Across Studies",
      subtitle = "Both scenarios: S and Y are correlated (ρ = 0.7)\nBut treatment effects differ",
      x = "ΔS(Q) = Q'τ_S",
      y = "ΔY(Q) = Q'τ_Y",
      caption = sprintf("M = %d samples from TV ball (λ = %.2f)", M, lambda)
    ) +
    theme_minimal(base_size = 11) +
    theme(strip.text = element_text(face = "bold"))

  print(p_combined)
  ggsave(
    "explorations/tv_ball_geometry/figures/uncorrelated_effects_comparison.pdf",
    p_combined, width = 10, height = 5
  )

  list(
    scenario1 = list(dgp = dgp1, analysis = analysis1),
    scenario2 = list(dgp = dgp2, analysis = analysis2),
    comparison = results,
    plot = p_combined
  )
}

# Run if interactive
if (interactive()) {

  # Run comparison
  comparison <- compare_scenarios(
    n = 1000,
    K = 10,
    lambda = 0.3,
    M = 2000
  )

  cat("\n\nResults saved to:\n")
  cat("  explorations/tv_ball_geometry/figures/uncorrelated_effects_comparison.pdf\n")
}
