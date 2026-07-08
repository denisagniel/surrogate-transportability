# Divergence Scenarios: When Do Methods Disagree?
# =================================================================

library(tidyverse)

# Goal: Create DGPs where across-study cor(θ_Y, θ_S) and within-study PTE disagree

# Key insight:
# - PTE measures: does S mediate the effect WITHIN a study?
# - Across-study cor: does knowing θ_S predict θ_Y ACROSS studies?
# - These can diverge!

# ============================================================================
# SCENARIO A: HIGH ACROSS-STUDY ρ, LOW WITHIN-STUDY PTE
# ============================================================================
#
# Mechanism: Both θ_S and θ_Y vary with X, but through INDEPENDENT pathways
#
# - Treatment effect on S depends on X (effect modification)
# - Treatment effect on Y depends on X (different effect modification)
# - But S doesn't cause Y (or causes Y weakly)
# - So: across studies, both effects vary with P(X) → high correlation
#       within study, S doesn't mediate → low PTE

dgp_high_rho_low_pte <- function() {
  list(
    name = "High ρ, Low PTE",
    description = "Both effects vary with X independently (no mediation)",

    # S(a) model: strong effect modification
    # P(S(a) = 1 | X) = 0.2 + 0.1·a + 0.05·X + 0.4·a·X
    # So: treatment effect = 0.1 + 0.4·X (much larger for X=1)
    alpha_s = 0.2,
    beta_s = 0.1,   # weak main effect
    gamma_s = 0.05,
    delta_s = 0.4,  # STRONG interaction

    # Y(a) model: effect modification through X, but S has NO effect
    # P(Y = 1 | S, X, a) = 0.2 + 0.05·a + 0.1·X + 0.3·a·X + 0.05·S
    # So: treatment effect = 0.05 + 0.3·X (much larger for X=1)
    # But S barely affects Y (coefficient 0.05)
    alpha_y = 0.2,
    beta_y = 0.05,   # weak main effect
    gamma_y = 0.1,
    theta_y = 0.05,  # WEAK S effect (KEY: no mediation)
    lambda_y = 0.3,  # strong a×X interaction (independent of S)
    kappa_y = 0.0    # no S×X interaction
  )
}

# ============================================================================
# SCENARIO B: LOW ACROSS-STUDY ρ, HIGH WITHIN-STUDY PTE
# ============================================================================
#
# Mechanism: θ_S constant, θ_Y varies, but S mediates strongly
#
# - Treatment effect on S is constant (no effect modification)
# - Treatment effect on Y varies with X through a different mechanism
# - But S strongly causes Y (high mediation)
# - So: across studies, θ_S constant → no correlation with varying θ_Y
#       within study, S mediates strongly → high PTE

dgp_low_rho_high_pte <- function() {
  list(
    name = "Low ρ, High PTE",
    description = "S effect constant, Y effect varies, but S mediates",

    # S(a) model: NO effect modification
    # P(S(a) = 1 | X) = 0.3 + 0.4·a + 0.1·X
    # So: treatment effect = 0.4 (constant across X)
    alpha_s = 0.3,
    beta_s = 0.4,   # strong main effect
    gamma_s = 0.1,
    delta_s = 0.0,  # NO interaction (KEY: constant treatment effect)

    # Y(a) model: S has strong effect, plus independent X-related variation
    # P(Y = 1 | S, X, a) = 0.1 + 0.05·a + 0.3·X + 0.5·S + 0.3·a·X
    # So: S matters a lot (0.5), plus treatment effect varies with X (0.05 + 0.3·X)
    alpha_y = 0.1,
    beta_y = 0.05,
    gamma_y = 0.3,   # X matters
    theta_y = 0.5,   # STRONG S effect (KEY: high mediation)
    lambda_y = 0.3,  # a×X interaction (varies treatment effect independently)
    kappa_y = 0.0
  )
}

# ============================================================================
# SCENARIO C: COMMON CAUSE (HIGH ρ BUT LOW PTE)
# ============================================================================
#
# Mechanism: X is common cause of both S(a) and Y(a) responses
#
# - Both θ_S and θ_Y depend on X
# - But S doesn't cause Y (or weakly)
# - X is like "severity" - more severe patients have larger responses to treatment
# - So: across studies with different severity distributions, effects co-vary
#       but within study, S doesn't mediate (it's just a marker of X)

dgp_common_cause <- function() {
  list(
    name = "Common Cause",
    description = "X drives both S and Y responses (S is marker, not mediator)",

    # S(a) model: response to treatment depends on X
    alpha_s = 0.2,
    beta_s = 0.15,
    gamma_s = 0.1,
    delta_s = 0.35,  # strong effect modification

    # Y(a) model: response to treatment depends on X, S is weak
    alpha_y = 0.2,
    beta_y = 0.1,
    gamma_y = 0.15,
    theta_y = 0.1,   # WEAK S effect
    lambda_y = 0.35, # strong effect modification (same pattern as S)
    kappa_y = 0.0
  )
}

# ============================================================================
# Computation functions (same as before but with kappa_y parameter)
# ============================================================================

compute_treatment_effects <- function(params, p_x) {
  # E[S(a)]
  p_s0_x0 <- params$alpha_s + params$gamma_s * 0
  p_s1_x0 <- params$alpha_s + params$beta_s + params$gamma_s * 0 + params$delta_s * 0
  p_s0_x1 <- params$alpha_s + params$gamma_s * 1
  p_s1_x1 <- params$alpha_s + params$beta_s + params$gamma_s * 1 + params$delta_s * 1

  E_S0 <- (1 - p_x) * p_s0_x0 + p_x * p_s0_x1
  E_S1 <- (1 - p_x) * p_s1_x0 + p_x * p_s1_x1

  # E[Y(a)] - need to integrate over S and X
  # P(Y = 1 | S, X, a) now includes S×X term if present

  # E[Y(0) | X = 0]
  E_Y0_X0 <- p_s0_x0 * (params$alpha_y + params$theta_y + params$gamma_y * 0 +
                        ifelse(is.null(params$kappa_y), 0, params$kappa_y * 0)) +
             (1 - p_s0_x0) * (params$alpha_y + params$gamma_y * 0)

  # E[Y(1) | X = 0]
  E_Y1_X0 <- p_s1_x0 * (params$alpha_y + params$beta_y + params$theta_y +
                        params$gamma_y * 0 + params$lambda_y * 0 +
                        ifelse(is.null(params$kappa_y), 0, params$kappa_y * 0)) +
             (1 - p_s1_x0) * (params$alpha_y + params$beta_y + params$gamma_y * 0)

  # E[Y(0) | X = 1]
  E_Y0_X1 <- p_s0_x1 * (params$alpha_y + params$theta_y + params$gamma_y * 1 +
                        ifelse(is.null(params$kappa_y), 0, params$kappa_y * 1)) +
             (1 - p_s0_x1) * (params$alpha_y + params$gamma_y * 1)

  # E[Y(1) | X = 1]
  E_Y1_X1 <- p_s1_x1 * (params$alpha_y + params$beta_y + params$theta_y +
                        params$gamma_y * 1 + params$lambda_y * 1 +
                        ifelse(is.null(params$kappa_y), 0, params$kappa_y * 1)) +
             (1 - p_s1_x1) * (params$alpha_y + params$beta_y + params$gamma_y * 1)

  E_Y0 <- (1 - p_x) * E_Y0_X0 + p_x * E_Y0_X1
  E_Y1 <- (1 - p_x) * E_Y1_X0 + p_x * E_Y1_X1

  list(
    theta_S = E_S1 - E_S0,
    theta_Y = E_Y1 - E_Y0,
    E_S0 = E_S0, E_S1 = E_S1,
    E_Y0 = E_Y0, E_Y1 = E_Y1
  )
}

compute_pte_single_study <- function(params, p_x) {
  grid <- expand_grid(X = 0:1, A = 0:1, S = 0:1, Y = 0:1)

  grid$prob <- with(grid, {
    p_X = ifelse(X == 1, p_x, 1 - p_x)
    p_A = 0.5

    p_S_given_AX = params$alpha_s + params$beta_s * A + params$gamma_s * X + params$delta_s * A * X
    p_S_given_AX = pmax(0, pmin(1, p_S_given_AX))
    p_S = ifelse(S == 1, p_S_given_AX, 1 - p_S_given_AX)

    p_Y_given_SAX = params$alpha_y + params$beta_y * A + params$gamma_y * X +
                    params$theta_y * S + params$lambda_y * A * X +
                    ifelse(is.null(params$kappa_y), 0, params$kappa_y * S * X)
    p_Y_given_SAX = pmax(0, pmin(1, p_Y_given_SAX))
    p_Y = ifelse(Y == 1, p_Y_given_SAX, 1 - p_Y_given_SAX)

    p_X * p_A * p_S * p_Y
  })

  grid$prob <- grid$prob / sum(grid$prob)

  # Total effect
  E_Y_A1 <- sum(grid$Y[grid$A == 1] * grid$prob[grid$A == 1]) / sum(grid$prob[grid$A == 1])
  E_Y_A0 <- sum(grid$Y[grid$A == 0] * grid$prob[grid$A == 0]) / sum(grid$prob[grid$A == 0])
  beta_total <- E_Y_A1 - E_Y_A0

  # Adjusted effect (conditional on S)
  effects_by_s <- map_dbl(0:1, function(s) {
    dat_s <- grid[grid$S == s, ]
    if (sum(dat_s$prob) == 0) return(0)

    E_Y_A1_S <- sum(dat_s$Y[dat_s$A == 1] * dat_s$prob[dat_s$A == 1]) /
                 sum(dat_s$prob[dat_s$A == 1])
    E_Y_A0_S <- sum(dat_s$Y[dat_s$A == 0] * dat_s$prob[dat_s$A == 0]) /
                 sum(dat_s$prob[dat_s$A == 0])

    p_S <- sum(dat_s$prob)
    p_S * (E_Y_A1_S - E_Y_A0_S)
  })

  beta_adjusted <- sum(effects_by_s)

  PTE <- if (abs(beta_total) > 1e-10) (beta_total - beta_adjusted) / beta_total else NA

  list(PTE = PTE, beta_total = beta_total, beta_adjusted = beta_adjusted)
}

# ============================================================================
# Analysis
# ============================================================================

analyze_scenario <- function(dgp_func) {
  params <- dgp_func()

  cat("\n" , rep("=", 70), "\n", sep = "")
  cat(params$name, "\n")
  cat(rep("=", 70), "\n", sep = "")
  cat(params$description, "\n\n")

  # Generate study sequence
  p_x_values <- seq(0.1, 0.9, length.out = 20)
  studies <- map_dfr(p_x_values, function(px) {
    effects <- compute_treatment_effects(params, px)
    tibble(
      p_x = px,
      theta_S = effects$theta_S,
      theta_Y = effects$theta_Y
    )
  })

  # Across-study correlation
  rho <- cor(studies$theta_Y, studies$theta_S)

  # Within-study PTE (at p_x = 0.5)
  pte <- compute_pte_single_study(params, p_x = 0.5)

  cat("Across-study correlation cor(θ_Y, θ_S):", round(rho, 3), "\n")
  cat("Within-study PTE (p_x = 0.5):         ", round(pte$PTE, 3), "\n\n")

  # Interpretation
  cat("INTERPRETATION:\n")
  if (rho > 0.7 && pte$PTE < 0.5) {
    cat("🚨 DIVERGENCE: High across-study ρ but low within-study PTE\n")
    cat("   → S predicts Y across studies (useful for external validity)\n")
    cat("   → But S doesn't mediate within study (poor mechanistic surrogate)\n")
  } else if (rho < 0.3 && pte$PTE > 0.7) {
    cat("🚨 DIVERGENCE: Low across-study ρ but high within-study PTE\n")
    cat("   → S mediates strongly within study (good mechanistic surrogate)\n")
    cat("   → But S doesn't predict Y across studies (poor external validity)\n")
  } else {
    cat("✓ Agreement: Both metrics aligned\n")
  }

  # Plot
  p <- ggplot(studies, aes(x = theta_S, y = theta_Y)) +
    geom_point(aes(color = p_x), size = 3) +
    geom_smooth(method = "lm", se = FALSE, color = "black", linetype = "dashed") +
    labs(
      title = params$name,
      subtitle = paste0("Across-study ρ = ", round(rho, 3),
                       ", Within-study PTE = ", round(pte$PTE, 3)),
      x = "E[S₁ - S₀] (treatment effect on surrogate)",
      y = "E[Y₁ - Y₀] (treatment effect on outcome)",
      color = "P(X=1)"
    ) +
    theme_minimal() +
    scale_color_viridis_c()

  list(
    name = params$name,
    rho = rho,
    pte = pte$PTE,
    studies = studies,
    plot = p
  )
}

# Run scenarios
scenario_A <- analyze_scenario(dgp_high_rho_low_pte)
scenario_B <- analyze_scenario(dgp_low_rho_high_pte)
scenario_C <- analyze_scenario(dgp_common_cause)

# Save plots
dir.create("explorations/figures", showWarnings = FALSE, recursive = TRUE)
ggsave("explorations/figures/divergence_high_rho_low_pte.png", scenario_A$plot, width = 7, height = 6)
ggsave("explorations/figures/divergence_low_rho_high_pte.png", scenario_B$plot, width = 7, height = 6)
ggsave("explorations/figures/divergence_common_cause.png", scenario_C$plot, width = 7, height = 6)

# Summary table
summary <- tibble(
  Scenario = c(scenario_A$name, scenario_B$name, scenario_C$name),
  `Across-study ρ` = round(c(scenario_A$rho, scenario_B$rho, scenario_C$rho), 3),
  `Within-study PTE` = round(c(scenario_A$pte, scenario_B$pte, scenario_C$pte), 3),
  Divergence = c(
    scenario_A$rho > 0.7 & scenario_A$pte < 0.5,
    scenario_B$rho < 0.3 & scenario_B$pte > 0.7,
    scenario_C$rho > 0.7 & scenario_C$pte < 0.5
  )
)

cat("\n", rep("=", 70), "\n", sep = "")
cat("SUMMARY\n")
cat(rep("=", 70), "\n", sep = "")
print(summary)

cat("\n\nKEY INSIGHT:\n")
cat("Traditional methods (PTE, mediation) evaluate WITHIN-study surrogate quality.\n")
cat("Our correlation functional evaluates ACROSS-study predictive value.\n")
cat("These can diverge when:\n")
cat("  1. Common cause: X drives both effects independently\n")
cat("  2. Constant surrogate effect but varying outcome effect\n")
