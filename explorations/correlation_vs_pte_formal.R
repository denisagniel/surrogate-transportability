# Formal Analysis: When Does Across-Study Correlation Diverge from PTE?
# =========================================================================

library(tidyverse)

# Setup:
# - Δ_S(X) = E[S(1) - S(0) | X]
# - Δ_Y(X) = E[Y(1) - Y(0) | X]
# - Δ_S(Q) = E_Q[Δ_S(X)] (reweighting by Q's distribution of X)
# - Δ_Y(Q) = E_Q[Δ_Y(X)]
# - Across studies: cor(Δ_S(Q), Δ_Y(Q))
# - PTE: 1 - [E(Y | A=1, S) - E(Y | A=0, S)] / [E(Y | A=1) - E(Y | A=0)]

# Binary X ∈ {0, 1}

# ============================================================================
# SCENARIO 1: High correlation, Low PTE
# ============================================================================
#
# Design:
# - Δ_S(X=0) small, Δ_S(X=1) large
# - Δ_Y(X=0) small, Δ_Y(X=1) large
# - But S doesn't cause Y (small θ coefficient)
#
# Result: As Q changes P(X=1), both Δ_S(Q) and Δ_Y(Q) change together → high cor
#         But S doesn't mediate → low PTE

scenario_1 <- function() {
  # Binary outcomes for simplicity
  # E[S(a) | X] = P(S(a) = 1 | X)
  # E[Y(a) | X, S] = P(Y(a) = 1 | X, S)

  # Treatment effects on S by X
  # Δ_S(X=0) = 0.1
  # Δ_S(X=1) = 0.6
  delta_S <- function(x) {
    if (x == 0) return(0.1)
    if (x == 1) return(0.6)
  }

  # Treatment effects on Y by X (similar pattern)
  # Δ_Y(X=0) = 0.05
  # Δ_Y(X=1) = 0.4
  delta_Y <- function(x) {
    if (x == 0) return(0.05)
    if (x == 1) return(0.4)
  }

  # Conditional outcome model: E[Y | X, A, S]
  # Key: S has SMALL effect on Y (weak mediation)
  # Y mainly determined by X and A directly

  # P(Y = 1 | X=0, A=0, S=0) = 0.2
  # P(Y = 1 | X=0, A=0, S=1) = 0.25  (S effect = 0.05, small)
  # P(Y = 1 | X=0, A=1, S=0) = 0.25
  # P(Y = 1 | X=0, A=1, S=1) = 0.30

  # P(Y = 1 | X=1, A=0, S=0) = 0.3
  # P(Y = 1 | X=1, A=0, S=1) = 0.35  (S effect = 0.05, small)
  # P(Y = 1 | X=1, A=1, S=0) = 0.7   (large direct effect)
  # P(Y = 1 | X=1, A=1, S=1) = 0.75

  E_Y_given_XAS <- function(x, a, s) {
    if (x == 0) {
      if (a == 0) {
        if (s == 0) return(0.2)
        if (s == 1) return(0.25)
      } else {
        if (s == 0) return(0.25)
        if (s == 1) return(0.30)
      }
    } else {  # x == 1
      if (a == 0) {
        if (s == 0) return(0.3)
        if (s == 1) return(0.35)
      } else {
        if (s == 0) return(0.7)
        if (s == 1) return(0.75)
      }
    }
  }

  # Also need E[S(a) | X] to compute expectations
  # Design to match Δ_S(X)
  # If Δ_S(0) = 0.1 and Δ_S(1) = 0.6, then:
  # P(S(0)=1 | X=0) = 0.3, P(S(1)=1 | X=0) = 0.4
  # P(S(0)=1 | X=1) = 0.2, P(S(1)=1 | X=1) = 0.8

  P_S_given_XA <- function(x, a) {
    if (x == 0) {
      if (a == 0) return(0.3)  # P(S(0)=1 | X=0)
      if (a == 1) return(0.4)  # P(S(1)=1 | X=0)
    } else {  # x == 1
      if (a == 0) return(0.2)  # P(S(0)=1 | X=1)
      if (a == 1) return(0.8)  # P(S(1)=1 | X=1)
    }
  }

  list(
    name = "High correlation, Low PTE",
    delta_S = delta_S,
    delta_Y = delta_Y,
    E_Y_given_XAS = E_Y_given_XAS,
    P_S_given_XA = P_S_given_XA
  )
}

# ============================================================================
# SCENARIO 2: Low correlation, High PTE
# ============================================================================
#
# Design:
# - Δ_S(X) constant across X
# - Δ_Y(X) varies across X
# - But S strongly causes Y (large θ coefficient)
#
# Result: As Q changes, Δ_S(Q) constant, Δ_Y(Q) varies → zero cor
#         But S mediates strongly → high PTE

scenario_2 <- function() {
  # Treatment effects on S (CONSTANT)
  delta_S <- function(x) 0.4  # same for all X

  # Treatment effects on Y (VARIES)
  delta_Y <- function(x) {
    if (x == 0) return(0.25)
    if (x == 1) return(0.55)
  }

  # Conditional outcome model: S has LARGE effect on Y
  # P(Y = 1 | X, A, S) = baseline + X_effect + A_effect + S_effect
  # Where S_effect is large

  E_Y_given_XAS <- function(x, a, s) {
    baseline <- 0.1
    x_effect <- 0.15 * x  # X matters for Y
    a_effect <- 0.05 * a  # Small direct effect
    s_effect <- 0.5 * s   # LARGE S effect (key for high PTE)

    baseline + x_effect + a_effect + s_effect
  }

  # S distribution: constant treatment effect
  P_S_given_XA <- function(x, a) {
    # Design: P(S(1)=1 | X) - P(S(0)=1 | X) = 0.4 for all X
    if (a == 0) {
      return(0.2)  # P(S(0)=1) = 0.2 for all X
    } else {
      return(0.6)  # P(S(1)=1) = 0.6 for all X
    }
  }

  list(
    name = "Low correlation, High PTE",
    delta_S = delta_S,
    delta_Y = delta_Y,
    E_Y_given_XAS = E_Y_given_XAS,
    P_S_given_XA = P_S_given_XA
  )
}

# ============================================================================
# Compute across-study correlation
# ============================================================================

compute_across_study_correlation <- function(scenario) {
  # Generate sequence of studies with different P(X=1)
  p_x_seq <- seq(0.1, 0.9, length.out = 30)

  studies <- map_dfr(p_x_seq, function(p_x) {
    # Compute Δ_S(Q) = E_Q[Δ_S(X)]
    delta_S_Q <- (1 - p_x) * scenario$delta_S(0) + p_x * scenario$delta_S(1)

    # Compute Δ_Y(Q) = E_Q[Δ_Y(X)]
    delta_Y_Q <- (1 - p_x) * scenario$delta_Y(0) + p_x * scenario$delta_Y(1)

    tibble(
      p_x = p_x,
      delta_S_Q = delta_S_Q,
      delta_Y_Q = delta_Y_Q
    )
  })

  rho <- cor(studies$delta_S_Q, studies$delta_Y_Q)

  list(studies = studies, rho = rho)
}

# ============================================================================
# Compute PTE for a single study
# ============================================================================

compute_pte <- function(scenario, p_x) {
  # PTE = 1 - [E(Y | A=1, S, X) - E(Y | A=0, S, X)] / [E(Y | A=1, X) - E(Y | A=0, X)]

  # Denominator: Total treatment effect
  # E[Y | A=1, X] = E_S[E[Y | A=1, S, X] | A=1, X]

  E_Y_given_AX <- function(a, x) {
    p_s_1 <- scenario$P_S_given_XA(x, a)
    p_s_0 <- 1 - p_s_1

    E_Y_s0 <- scenario$E_Y_given_XAS(x, a, 0)
    E_Y_s1 <- scenario$E_Y_given_XAS(x, a, 1)

    p_s_0 * E_Y_s0 + p_s_1 * E_Y_s1
  }

  # Average over X
  E_Y_A1 <- (1 - p_x) * E_Y_given_AX(1, 0) + p_x * E_Y_given_AX(1, 1)
  E_Y_A0 <- (1 - p_x) * E_Y_given_AX(0, 0) + p_x * E_Y_given_AX(0, 1)

  total_effect <- E_Y_A1 - E_Y_A0

  # Numerator: Adjusted treatment effect
  # E[Y | A, S, X] - this is the conditional expectation
  # We need: E_{X,S}[E[Y | A=1, S, X] - E[Y | A=0, S, X]]

  # Average over X and S (where S distribution depends on A)
  adjusted_effect <- 0
  for (x in 0:1) {
    p_X <- ifelse(x == 1, p_x, 1 - p_x)

    # Under A=1, what's the S distribution?
    p_s1_given_A1 <- scenario$P_S_given_XA(x, 1)
    # Under A=0, what's the S distribution?
    p_s1_given_A0 <- scenario$P_S_given_XA(x, 0)

    # For PTE, we typically condition on the S distribution under one arm
    # Common choice: condition on control arm S distribution
    # E[Y(1, S(0)) - Y(0, S(0)) | X]

    for (s in 0:1) {
      p_S <- ifelse(s == 1, p_s1_given_A0, 1 - p_s1_given_A0)

      effect_at_sx <- scenario$E_Y_given_XAS(x, 1, s) - scenario$E_Y_given_XAS(x, 0, s)

      adjusted_effect <- adjusted_effect + p_X * p_S * effect_at_sx
    }
  }

  PTE <- 1 - adjusted_effect / total_effect

  list(
    PTE = PTE,
    total_effect = total_effect,
    adjusted_effect = adjusted_effect
  )
}

# ============================================================================
# Analysis
# ============================================================================

analyze_scenario <- function(scenario_func) {
  scenario <- scenario_func()

  cat("\n", rep("=", 75), "\n", sep = "")
  cat(scenario$name, "\n")
  cat(rep("=", 75), "\n", sep = "")

  # Across-study correlation
  across_study <- compute_across_study_correlation(scenario)

  cat("\nAcross-study correlation:\n")
  cat("  cor(Δ_S(Q), Δ_Y(Q)) = ", round(across_study$rho, 3), "\n")

  # PTE in a typical study (p_x = 0.5)
  pte_mid <- compute_pte(scenario, p_x = 0.5)

  cat("\nWithin-study PTE (P(X=1) = 0.5):\n")
  cat("  PTE = ", round(pte_mid$PTE, 3), "\n")
  cat("  Total effect = ", round(pte_mid$total_effect, 3), "\n")
  cat("  Adjusted effect = ", round(pte_mid$adjusted_effect, 3), "\n")

  # Interpretation
  cat("\n")
  if (!is.na(across_study$rho) && across_study$rho > 0.7 && pte_mid$PTE < 0.5) {
    cat("🚨 DIVERGENCE: High ρ, Low PTE\n")
    cat("   → Knowing Δ_S(Q) highly predictive of Δ_Y(Q) across studies\n")
    cat("   → But S doesn't mediate Y within a study\n")
    cat("   → Interpretation: Δ_S(X) and Δ_Y(X) co-vary with X, but S doesn't cause Y\n")
  } else if (is.na(across_study$rho) && pte_mid$PTE > 0.7) {
    cat("🚨 EXTREME DIVERGENCE: Undefined ρ (no variation in Δ_S), High PTE\n")
    cat("   → S strongly mediates Y within a study\n")
    cat("   → But Δ_S(Q) is constant across studies (no predictive value)\n")
    cat("   → Interpretation: Treatment effect on S doesn't vary with X\n")
  } else if (!is.na(across_study$rho) && abs(across_study$rho) < 0.3 && pte_mid$PTE > 0.7) {
    cat("🚨 DIVERGENCE: Low ρ, High PTE\n")
    cat("   → S strongly mediates Y within a study\n")
    cat("   → But knowing Δ_S(Q) doesn't predict Δ_Y(Q) across studies\n")
    cat("   → Interpretation: Δ_S(X) constant, so studies differ only in Δ_Y(X)\n")
  } else {
    cat("✓ Alignment: Both metrics agree\n")
  }

  # Plot: Δ_S(Q) vs Δ_Y(Q)
  p <- ggplot(across_study$studies, aes(x = delta_S_Q, y = delta_Y_Q)) +
    geom_point(aes(color = p_x), size = 3) +
    geom_smooth(method = "lm", se = FALSE, color = "black", linetype = "dashed") +
    labs(
      title = scenario$name,
      subtitle = paste0("Across-study ρ = ", round(across_study$rho, 3),
                       " | Within-study PTE = ", round(pte_mid$PTE, 3)),
      x = "Δ_S(Q) = E_Q[Δ_S(X)]",
      y = "Δ_Y(Q) = E_Q[Δ_Y(X)]",
      color = "P(X=1)"
    ) +
    theme_minimal() +
    theme(plot.title = element_text(size = 14, face = "bold")) +
    scale_color_viridis_c()

  list(
    scenario = scenario,
    rho = across_study$rho,
    pte = pte_mid$PTE,
    studies = across_study$studies,
    plot = p
  )
}

# Run scenarios
result_1 <- analyze_scenario(scenario_1)
result_2 <- analyze_scenario(scenario_2)

# Verify treatment effects match design
cat("\n", rep("=", 75), "\n", sep = "")
cat("VERIFICATION: Check that specified Δ_S(X), Δ_Y(X) match computed values\n")
cat(rep("=", 75), "\n", sep = "")

verify_scenario <- function(scenario) {
  cat("\nScenario:", scenario$name, "\n")

  for (x in 0:1) {
    # Compute actual Δ_S(X) from model
    p_s1 <- scenario$P_S_given_XA(x, 1)
    p_s0 <- scenario$P_S_given_XA(x, 0)
    delta_s_computed <- p_s1 - p_s0
    delta_s_specified <- scenario$delta_S(x)

    cat("  X=", x, ": Δ_S specified=", delta_s_specified,
        " computed=", delta_s_computed, "\n", sep = "")

    # Compute actual Δ_Y(X) from model
    E_Y1 <- 0
    E_Y0 <- 0
    for (s in 0:1) {
      p_s_under_1 <- ifelse(s == 1, p_s1, 1 - p_s1)
      p_s_under_0 <- ifelse(s == 1, p_s0, 1 - p_s0)

      E_Y1 <- E_Y1 + p_s_under_1 * scenario$E_Y_given_XAS(x, 1, s)
      E_Y0 <- E_Y0 + p_s_under_0 * scenario$E_Y_given_XAS(x, 0, s)
    }

    delta_y_computed <- E_Y1 - E_Y0
    delta_y_specified <- scenario$delta_Y(x)

    cat("  X=", x, ": Δ_Y specified=", delta_y_specified,
        " computed=", round(delta_y_computed, 4), "\n", sep = "")
  }
}

verify_scenario(result_1$scenario)
verify_scenario(result_2$scenario)

# Save plots
dir.create("explorations/figures", showWarnings = FALSE, recursive = TRUE)
ggsave("explorations/figures/formal_high_rho_low_pte.png", result_1$plot,
       width = 8, height = 6)
ggsave("explorations/figures/formal_low_rho_high_pte.png", result_2$plot,
       width = 8, height = 6)

# Summary
cat("\n", rep("=", 75), "\n", sep = "")
cat("SUMMARY\n")
cat(rep("=", 75), "\n", sep = "")

summary_tbl <- tibble(
  Scenario = c(result_1$scenario$name, result_2$scenario$name),
  `Across-study ρ` = round(c(result_1$rho, result_2$rho), 3),
  `Within-study PTE` = round(c(result_1$pte, result_2$pte), 3),
  Divergence = c(
    (!is.na(result_1$rho) && result_1$rho > 0.7 && result_1$pte < 0.5),
    (is.na(result_2$rho) && result_2$pte > 0.7) || (!is.na(result_2$rho) && abs(result_2$rho) < 0.3 && result_2$pte > 0.7)
  )
)

print(summary_tbl)

cat("\n\nKEY MATHEMATICAL INSIGHT:\n")
cat("- Δ_S(Q) and Δ_Y(Q) are linear functionals of Q (reweightings)\n")
cat("- Across-study cor depends on: Cov(Δ_S(X), Δ_Y(X)) across X values\n")
cat("- PTE depends on: how much of E[Y | A, X] is explained by E[Y | A, S, X]\n")
cat("- These CAN diverge when:\n")
cat("    1. Δ_S(X) and Δ_Y(X) co-vary, but S doesn't cause Y (common driver X)\n")
cat("    2. S causes Y strongly, but Δ_S(X) is constant (no heterogeneity)\n")
