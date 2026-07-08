# Across-Study Correlation vs Traditional Methods
# =================================================================
# Goal: When does cor(E[Y_1 - Y_0], E[S_1 - S_0]) across studies
#       give different answers than PTE/mediation?

library(tidyverse)
library(Rsurrogate)  # For correct PTE computation
library(mediation)   # For mediation analysis

# 1. Define DGP with Effect Modification by X ============================

# Binary: X, A (treatment), S (surrogate), Y (outcome)
# Key: Treatment effects on both S and Y depend on X

# Potential outcome model:
# S(a) | X ~ Bernoulli(p_s(a, X))
# Y(a) | S(a), X ~ Bernoulli(p_y(s, a, X))

# Parameterization:
# p_s(a, X) = P(S(a) = 1 | X) = α_s + β_s·a + γ_s·X + δ_s·a·X
# p_y(s, a, X) = P(Y(a) = 1 | S(a) = s, X) = α_y + β_y·a + γ_y·X + θ_y·s + interaction terms

dgp_params <- function(scenario) {
  if (scenario == "baseline") {
    # Baseline: S mediates effect, no effect modification
    list(
      # S(a) model: P(S(a) = 1 | X)
      alpha_s = 0.3,   # baseline prob
      beta_s = 0.3,    # treatment effect on S
      gamma_s = 0.1,   # X effect on S
      delta_s = 0.0,   # no interaction

      # Y(a) model: P(Y = 1 | S(a), X, a)
      alpha_y = 0.2,   # baseline prob
      beta_y = 0.1,    # direct treatment effect
      gamma_y = 0.05,  # X effect on Y
      theta_y = 0.4,   # S effect on Y (key mediation parameter)
      lambda_y = 0.0   # S×a interaction
    )
  } else if (scenario == "effect_mod_both") {
    # Effect modification: both S and Y effects depend on X
    list(
      alpha_s = 0.3,
      beta_s = 0.2,    # smaller main effect
      gamma_s = 0.1,
      delta_s = 0.3,   # strong interaction: treatment effect on S larger for high X

      alpha_y = 0.2,
      beta_y = 0.1,
      gamma_y = 0.05,
      theta_y = 0.4,
      lambda_y = 0.0
    )
  } else if (scenario == "effect_mod_y_only") {
    # Effect modification on Y but not S
    # Treatment effect on Y depends on X, but S effect is constant
    list(
      alpha_s = 0.3,
      beta_s = 0.3,
      gamma_s = 0.1,
      delta_s = 0.0,

      alpha_y = 0.2,
      beta_y = 0.0,    # no main effect
      gamma_y = 0.3,   # strong X effect
      theta_y = 0.4,
      lambda_y = 0.3   # S×X interaction: S matters more for high X
    )
  }
}

# Compute treatment effects for a given X distribution
compute_treatment_effects <- function(params, p_x) {
  # p_x = P(X = 1)

  # For each X value, compute P(S(a) = 1 | X) and P(Y(a) = 1 | X)
  # Then average over X distribution

  p_s0_x0 <- params$alpha_s + params$gamma_s * 0
  p_s1_x0 <- params$alpha_s + params$beta_s + params$gamma_s * 0 + params$delta_s * 0

  p_s0_x1 <- params$alpha_s + params$gamma_s * 1
  p_s1_x1 <- params$alpha_s + params$beta_s + params$gamma_s * 1 + params$delta_s * 1

  # E[S(a)] = E_X[P(S(a) = 1 | X)]
  E_S0 <- (1 - p_x) * p_s0_x0 + p_x * p_s0_x1
  E_S1 <- (1 - p_x) * p_s1_x0 + p_x * p_s1_x1

  # For Y, need to integrate over S as well
  # E[Y(a)] = E_X[E_{S(a)|X}[P(Y = 1 | S(a), X, a)]]

  # E[Y(0) | X = 0]
  E_Y0_X0 <- p_s0_x0 * (params$alpha_y + params$theta_y + params$gamma_y * 0) +
             (1 - p_s0_x0) * (params$alpha_y + params$gamma_y * 0)

  # E[Y(1) | X = 0]
  E_Y1_X0 <- p_s1_x0 * (params$alpha_y + params$beta_y + params$theta_y + params$gamma_y * 0 + params$lambda_y * 0) +
             (1 - p_s1_x0) * (params$alpha_y + params$beta_y + params$gamma_y * 0)

  # E[Y(0) | X = 1]
  E_Y0_X1 <- p_s0_x1 * (params$alpha_y + params$theta_y + params$gamma_y * 1) +
             (1 - p_s0_x1) * (params$alpha_y + params$gamma_y * 1)

  # E[Y(1) | X = 1]
  E_Y1_X1 <- p_s1_x1 * (params$alpha_y + params$beta_y + params$theta_y + params$gamma_y * 1 + params$lambda_y * 1) +
             (1 - p_s1_x1) * (params$alpha_y + params$beta_y + params$gamma_y * 1)

  E_Y0 <- (1 - p_x) * E_Y0_X0 + p_x * E_Y0_X1
  E_Y1 <- (1 - p_x) * E_Y1_X0 + p_x * E_Y1_X1

  list(
    theta_S = E_S1 - E_S0,
    theta_Y = E_Y1 - E_Y0,
    E_S0 = E_S0,
    E_S1 = E_S1,
    E_Y0 = E_Y0,
    E_Y1 = E_Y1
  )
}

# 2. Generate Sequence of Studies with Different X Distributions ========

generate_study_sequence <- function(scenario, n_studies = 20) {
  params <- dgp_params(scenario)

  # Vary P(X = 1) from 0.1 to 0.9
  p_x_values <- seq(0.1, 0.9, length.out = n_studies)

  studies <- map_dfr(p_x_values, function(px) {
    effects <- compute_treatment_effects(params, px)
    tibble(
      p_x = px,
      theta_S = effects$theta_S,
      theta_Y = effects$theta_Y,
      E_S0 = effects$E_S0,
      E_S1 = effects$E_S1,
      E_Y0 = effects$E_Y0,
      E_Y1 = effects$E_Y1
    )
  })

  studies
}

# 3. Compute Across-Study Correlation ===================================

compute_across_study_correlation <- function(studies) {
  cor(studies$theta_Y, studies$theta_S)
}

# 4. Compute PTE for a Single Study =====================================
# Following Rsurrogate methodology

compute_pte_single_study <- function(params, p_x, method = "freedman") {
  # Generate data for single study
  # Need full joint distribution to compute PTE properly

  # For binary DGP, enumerate all possibilities
  grid <- expand_grid(
    X = 0:1,
    A = 0:1,
    S = 0:1,
    Y = 0:1
  )

  # Compute P(X, A, S, Y)
  # Factorize as: P(X) · P(A | X) · P(S | A, X) · P(Y | S, A, X)

  # For simplicity: A randomized, so P(A | X) = 0.5
  # P(X) given by p_x
  # P(S | A, X) from S(a) model
  # P(Y | S, A, X) from Y model

  grid$prob <- with(grid, {
    # P(X)
    p_X = ifelse(X == 1, p_x, 1 - p_x)

    # P(A | X) = 0.5 (randomized)
    p_A = 0.5

    # P(S | A, X) from potential outcome model
    p_S_given_AX = params$alpha_s + params$beta_s * A + params$gamma_s * X + params$delta_s * A * X
    p_S = ifelse(S == 1, p_S_given_AX, 1 - p_S_given_AX)

    # P(Y | S, A, X)
    p_Y_given_SAX = params$alpha_y + params$beta_y * A + params$gamma_y * X +
                    params$theta_y * S + params$lambda_y * A * S
    p_Y = ifelse(Y == 1, p_Y_given_SAX, 1 - p_Y_given_SAX)

    p_X * p_A * p_S * p_Y
  })

  # Normalize (might have clipping issues)
  grid$prob <- pmax(0, pmin(1, grid$prob))
  grid$prob <- grid$prob / sum(grid$prob)

  # Compute PTE via Freedman et al. (2008) approach
  # PTE = (β_total - β_adjusted) / β_total
  # where β_total = E[Y | A=1] - E[Y | A=0]
  # and β_adjusted = E[Y | A=1, S] - E[Y | A=0, S] averaged over S

  # β_total
  E_Y_A1 <- sum(grid$Y[grid$A == 1] * grid$prob[grid$A == 1]) / sum(grid$prob[grid$A == 1])
  E_Y_A0 <- sum(grid$Y[grid$A == 0] * grid$prob[grid$A == 0]) / sum(grid$prob[grid$A == 0])
  beta_total <- E_Y_A1 - E_Y_A0

  # β_adjusted: regress Y on A adjusting for S
  # For binary, this is weighted average of A effects within S strata

  # E[Y | A=1, S=0]
  E_Y_A1_S0 <- sum(grid$Y[grid$A == 1 & grid$S == 0] * grid$prob[grid$A == 1 & grid$S == 0]) /
                sum(grid$prob[grid$A == 1 & grid$S == 0])
  # E[Y | A=0, S=0]
  E_Y_A0_S0 <- sum(grid$Y[grid$A == 0 & grid$S == 0] * grid$prob[grid$A == 0 & grid$S == 0]) /
                sum(grid$prob[grid$A == 0 & grid$S == 0])

  # E[Y | A=1, S=1]
  E_Y_A1_S1 <- sum(grid$Y[grid$A == 1 & grid$S == 1] * grid$prob[grid$A == 1 & grid$S == 1]) /
                sum(grid$prob[grid$A == 1 & grid$S == 1])
  # E[Y | A=0, S=1]
  E_Y_A0_S1 <- sum(grid$Y[grid$A == 0 & grid$S == 1] * grid$prob[grid$A == 0 & grid$S == 1]) /
                sum(grid$prob[grid$A == 0 & grid$S == 1])

  # P(S = s)
  p_S0 <- sum(grid$prob[grid$S == 0])
  p_S1 <- sum(grid$prob[grid$S == 1])

  # Adjusted effect
  beta_adjusted <- p_S0 * (E_Y_A1_S0 - E_Y_A0_S0) + p_S1 * (E_Y_A1_S1 - E_Y_A0_S1)

  # PTE
  if (abs(beta_total) > 1e-10) {
    PTE <- (beta_total - beta_adjusted) / beta_total
  } else {
    PTE <- NA
  }

  list(
    PTE = PTE,
    beta_total = beta_total,
    beta_adjusted = beta_adjusted,
    proportion_explained = PTE
  )
}

# 5. Compute Mediation for a Single Study ===============================

compute_mediation_single_study <- function(params, p_x) {
  # Mediation: decompose total effect into NDE and NIE
  # Need cross-world counterfactual Y(a, s)

  # From potential outcome model:
  # Y(a, s) | X ~ Bernoulli(α_y + β_y·a + γ_y·X + θ_y·s + λ_y·a·s)

  # E[Y(1, S(1)) - Y(0, S(0))] = total effect
  # E[Y(1, S(0)) - Y(0, S(0))] = NDE
  # E[Y(1, S(1)) - Y(1, S(0))] = NIE

  # Need to compute E[Y(a, S(a'))] by integrating over X and S(a')

  # E[Y(1, S(1))]
  E_Y_1_S1 <- 0
  for (x in 0:1) {
    p_X <- ifelse(x == 1, p_x, 1 - p_x)
    p_S1_X <- params$alpha_s + params$beta_s + params$gamma_s * x + params$delta_s * x

    for (s in 0:1) {
      p_S1_equals_s <- ifelse(s == 1, p_S1_X, 1 - p_S1_X)
      p_Y <- params$alpha_y + params$beta_y + params$gamma_y * x + params$theta_y * s + params$lambda_y * s

      E_Y_1_S1 <- E_Y_1_S1 + p_X * p_S1_equals_s * p_Y
    }
  }

  # E[Y(0, S(0))]
  E_Y_0_S0 <- 0
  for (x in 0:1) {
    p_X <- ifelse(x == 1, p_x, 1 - p_x)
    p_S0_X <- params$alpha_s + params$gamma_s * x

    for (s in 0:1) {
      p_S0_equals_s <- ifelse(s == 1, p_S0_X, 1 - p_S0_X)
      p_Y <- params$alpha_y + params$gamma_y * x + params$theta_y * s

      E_Y_0_S0 <- E_Y_0_S0 + p_X * p_S0_equals_s * p_Y
    }
  }

  # E[Y(1, S(0))] - cross-world
  E_Y_1_S0 <- 0
  for (x in 0:1) {
    p_X <- ifelse(x == 1, p_x, 1 - p_x)
    p_S0_X <- params$alpha_s + params$gamma_s * x  # S(0) distribution

    for (s in 0:1) {
      p_S0_equals_s <- ifelse(s == 1, p_S0_X, 1 - p_S0_X)
      p_Y <- params$alpha_y + params$beta_y + params$gamma_y * x + params$theta_y * s + params$lambda_y * s
      # ^ Y(1, s) with A = 1

      E_Y_1_S0 <- E_Y_1_S0 + p_X * p_S0_equals_s * p_Y
    }
  }

  # Effects
  TE <- E_Y_1_S1 - E_Y_0_S0
  NDE <- E_Y_1_S0 - E_Y_0_S0
  NIE <- E_Y_1_S1 - E_Y_1_S0

  # Proportion mediated
  if (abs(TE) > 1e-10) {
    prop_mediated <- NIE / TE
  } else {
    prop_mediated <- NA
  }

  list(
    TE = TE,
    NDE = NDE,
    NIE = NIE,
    prop_mediated = prop_mediated
  )
}

# 6. Compare Across Different Scenarios =================================

compare_scenario <- function(scenario_name) {
  cat("\n========================================\n")
  cat("Scenario:", scenario_name, "\n")
  cat("========================================\n\n")

  # Generate study sequence
  studies <- generate_study_sequence(scenario_name, n_studies = 20)

  # Across-study correlation
  rho <- compute_across_study_correlation(studies)
  cat("Across-study correlation cor(θ_Y, θ_S):", round(rho, 3), "\n\n")

  # Plot treatment effects across studies
  p1 <- ggplot(studies, aes(x = p_x)) +
    geom_line(aes(y = theta_Y, color = "Treatment effect on Y")) +
    geom_line(aes(y = theta_S, color = "Treatment effect on S")) +
    geom_point(aes(y = theta_Y, color = "Treatment effect on Y")) +
    geom_point(aes(y = theta_S, color = "Treatment effect on S")) +
    labs(
      title = paste0("Treatment Effects Across Studies (", scenario_name, ")"),
      subtitle = paste0("cor(θ_Y, θ_S) = ", round(rho, 3)),
      x = "P(X = 1) in study",
      y = "Treatment Effect",
      color = "Effect"
    ) +
    theme_minimal()

  # Scatterplot: θ_S vs θ_Y
  p2 <- ggplot(studies, aes(x = theta_S, y = theta_Y)) +
    geom_point(aes(color = p_x), size = 3) +
    geom_smooth(method = "lm", se = FALSE, color = "black", linetype = "dashed") +
    labs(
      title = paste0("Across-Study Correlation (", scenario_name, ")"),
      subtitle = paste0("cor = ", round(rho, 3)),
      x = "E[S₁ - S₀] (treatment effect on surrogate)",
      y = "E[Y₁ - Y₀] (treatment effect on outcome)",
      color = "P(X=1)"
    ) +
    theme_minimal() +
    scale_color_viridis_c()

  # For comparison: compute PTE and mediation for a "typical" study (p_x = 0.5)
  params <- dgp_params(scenario_name)
  pte_results <- compute_pte_single_study(params, p_x = 0.5)
  med_results <- compute_mediation_single_study(params, p_x = 0.5)

  cat("Within-study evaluation (p_x = 0.5):\n")
  cat("  PTE:", round(pte_results$PTE, 3), "\n")
  cat("  Proportion mediated:", round(med_results$prop_mediated, 3), "\n\n")

  # Key insight: compare across-study correlation to within-study measures
  cat("COMPARISON:\n")
  if (rho > 0.7 && pte_results$PTE < 0.5) {
    cat("  ⚠️  DIVERGENCE: High across-study correlation but low PTE!\n")
    cat("      → S is informative about θ_Y across studies, but poor surrogate within study\n")
  } else if (rho < 0.3 && pte_results$PTE > 0.7) {
    cat("  ⚠️  DIVERGENCE: Low across-study correlation but high PTE!\n")
    cat("      → S is good surrogate within study, but not informative across studies\n")
  } else {
    cat("  ✓ Agreement: Both methods give similar conclusion\n")
  }

  list(
    scenario = scenario_name,
    studies = studies,
    rho = rho,
    pte = pte_results,
    mediation = med_results,
    plots = list(p1 = p1, p2 = p2)
  )
}

# 7. Run All Scenarios ==================================================

scenarios <- c("baseline", "effect_mod_both", "effect_mod_y_only")
results <- map(scenarios, compare_scenario)
names(results) <- scenarios

# Save plots
dir.create("explorations/figures", showWarnings = FALSE, recursive = TRUE)

for (scenario in scenarios) {
  ggsave(
    paste0("explorations/figures/", scenario, "_effects_across_studies.png"),
    results[[scenario]]$plots$p1,
    width = 8, height = 5
  )
  ggsave(
    paste0("explorations/figures/", scenario, "_correlation_scatter.png"),
    results[[scenario]]$plots$p2,
    width = 7, height = 6
  )
}

cat("\n\nPlots saved to explorations/figures/\n")

# 8. Summary Table ======================================================

summary_table <- map_dfr(scenarios, function(scenario) {
  r <- results[[scenario]]
  tibble(
    Scenario = scenario,
    `Across-study ρ` = round(r$rho, 3),
    `PTE (p_x=0.5)` = round(r$pte$PTE, 3),
    `Prop. Mediated` = round(r$mediation$prop_mediated, 3),
    Interpretation = case_when(
      abs(r$rho) > 0.7 & r$pte$PTE < 0.5 ~ "High ρ, Low PTE: Divergence!",
      abs(r$rho) < 0.3 & r$pte$PTE > 0.7 ~ "Low ρ, High PTE: Divergence!",
      TRUE ~ "Agreement"
    )
  )
})

cat("\n========================================\n")
cat("SUMMARY TABLE\n")
cat("========================================\n")
print(summary_table)

# Save results
saveRDS(results, "explorations/across_study_vs_traditional_results.rds")
cat("\n\nResults saved to explorations/across_study_vs_traditional_results.rds\n")
