# Compute PTE for DGP 1 and DGP 2 (Slides)
#
# PTE = (Indirect Effect) / (Total Effect)
# where Indirect = β_S × ΔS

library(dplyr)

devtools::load_all()

cat("\n=== Computing PTE for Both DGPs ===\n\n")

# =============================================================================
# DGP 1: Original 5-Level
# =============================================================================

cat("=== DGP 1: Original 5-Level X ===\n\n")

# Load true correlation results
results_dgp1 <- readRDS("validation/results/true_correlation_5level.rds")

params1 <- list(
  gamma_A = 1.0,
  gamma_AX = 0.5,
  beta_A = 0.25,
  beta_AX = -0.3,
  beta_S = 0.9,
  beta_SX = -0.1,
  sigma_S = 0.5,
  sigma_Y = 0.5
)

p_X_0_dgp1 <- results_dgp1$P0
tau_S_dgp1 <- results_dgp1$tau_S
tau_Y_dgp1 <- results_dgp1$tau_Y

# At P₀: ΔS(P₀) and ΔY(P₀)
Delta_S_P0_dgp1 <- sum(p_X_0_dgp1 * tau_S_dgp1)
Delta_Y_P0_dgp1 <- sum(p_X_0_dgp1 * tau_Y_dgp1)

# PTE = (β_S × ΔS) / ΔY
indirect_dgp1 <- params1$beta_S * Delta_S_P0_dgp1
direct_dgp1 <- Delta_Y_P0_dgp1 - indirect_dgp1
PTE_dgp1 <- indirect_dgp1 / Delta_Y_P0_dgp1

cat("Parameters:\n")
cat(sprintf("  β_S = %.2f (mediation strength)\n", params1$beta_S))
cat(sprintf("  β_A = %.2f (direct effect)\n\n", params1$beta_A))

cat("Treatment Effects at P₀:\n")
cat(sprintf("  ΔS(P₀) = %.4f\n", Delta_S_P0_dgp1))
cat(sprintf("  ΔY(P₀) = %.4f\n\n", Delta_Y_P0_dgp1))

cat("Mediation Analysis:\n")
cat(sprintf("  Indirect (β_S × ΔS) = %.4f\n", indirect_dgp1))
cat(sprintf("  Direct (ΔY - Indirect) = %.4f\n", direct_dgp1))
cat(sprintf("  Total = %.4f\n\n", Delta_Y_P0_dgp1))

cat(sprintf("*** PTE(P₀) = %.4f (%.1f%%) ***\n\n", PTE_dgp1, 100 * PTE_dgp1))

# Range of PTE across TV ball
Delta_S_vec_dgp1 <- results_dgp1$Delta_S_vec
Delta_Y_vec_dgp1 <- results_dgp1$Delta_Y_vec

PTE_vec_dgp1 <- (params1$beta_S * Delta_S_vec_dgp1) / Delta_Y_vec_dgp1

cat(sprintf("PTE across TV ball:\n"))
cat(sprintf("  Min: %.4f (%.1f%%)\n", min(PTE_vec_dgp1), 100 * min(PTE_vec_dgp1)))
cat(sprintf("  Q1:  %.4f (%.1f%%)\n", quantile(PTE_vec_dgp1, 0.25), 100 * quantile(PTE_vec_dgp1, 0.25)))
cat(sprintf("  Median: %.4f (%.1f%%)\n", median(PTE_vec_dgp1), 100 * median(PTE_vec_dgp1)))
cat(sprintf("  Q3:  %.4f (%.1f%%)\n", quantile(PTE_vec_dgp1, 0.75), 100 * quantile(PTE_vec_dgp1, 0.75)))
cat(sprintf("  Max: %.4f (%.1f%%)\n\n", max(PTE_vec_dgp1), 100 * max(PTE_vec_dgp1)))

cat(strrep("=", 70), "\n\n")

# =============================================================================
# DGP 2: Slides (Discrete X)
# =============================================================================

cat("=== DGP 2: Slides (Discrete X) ===\n\n")

# Load true correlation results
results_dgp2 <- readRDS("validation/results/true_correlation_slides_discrete.rds")

params2 <- results_dgp2$params

p_X_0_dgp2 <- results_dgp2$P0
tau_S_dgp2 <- results_dgp2$tau_S
tau_Y_dgp2 <- results_dgp2$tau_Y

# At P₀: ΔS(P₀) and ΔY(P₀)
Delta_S_P0_dgp2 <- sum(p_X_0_dgp2 * tau_S_dgp2)
Delta_Y_P0_dgp2 <- sum(p_X_0_dgp2 * tau_Y_dgp2)

# PTE = (β_S × ΔS) / ΔY
indirect_dgp2 <- params2$beta_S * Delta_S_P0_dgp2
direct_dgp2 <- Delta_Y_P0_dgp2 - indirect_dgp2
PTE_dgp2 <- indirect_dgp2 / Delta_Y_P0_dgp2

cat("Parameters:\n")
cat(sprintf("  β_S = %.2f (mediation strength)\n", params2$beta_S))
cat(sprintf("  β_A = %.2f (direct effect)\n", params2$beta_A))
cat(sprintf("  β_SX = %.2f (S×X interaction)\n\n", params2$beta_SX))

cat("Treatment Effects at P₀:\n")
cat(sprintf("  ΔS(P₀) = %.4f\n", Delta_S_P0_dgp2))
cat(sprintf("  ΔY(P₀) = %.4f\n\n", Delta_Y_P0_dgp2))

cat("Mediation Analysis:\n")
cat(sprintf("  Indirect (β_S × ΔS) = %.4f\n", indirect_dgp2))
cat(sprintf("  Direct (ΔY - Indirect) = %.4f\n", direct_dgp2))
cat(sprintf("  Total = %.4f\n\n", Delta_Y_P0_dgp2))

cat(sprintf("*** PTE(P₀) = %.4f (%.1f%%) ***\n\n", PTE_dgp2, 100 * PTE_dgp2))

# Range of PTE across TV ball
Delta_S_vec_dgp2 <- results_dgp2$Delta_S_vec
Delta_Y_vec_dgp2 <- results_dgp2$Delta_Y_vec

PTE_vec_dgp2 <- (params2$beta_S * Delta_S_vec_dgp2) / Delta_Y_vec_dgp2

cat(sprintf("PTE across TV ball:\n"))
cat(sprintf("  Min: %.4f (%.1f%%)\n", min(PTE_vec_dgp2), 100 * min(PTE_vec_dgp2)))
cat(sprintf("  Q1:  %.4f (%.1f%%)\n", quantile(PTE_vec_dgp2, 0.25), 100 * quantile(PTE_vec_dgp2, 0.25)))
cat(sprintf("  Median: %.4f (%.1f%%)\n", median(PTE_vec_dgp2), 100 * median(PTE_vec_dgp2)))
cat(sprintf("  Q3:  %.4f (%.1f%%)\n", quantile(PTE_vec_dgp2, 0.75), 100 * quantile(PTE_vec_dgp2, 0.75)))
cat(sprintf("  Max: %.4f (%.1f%%)\n\n", max(PTE_vec_dgp2), 100 * max(PTE_vec_dgp2)))

cat(strrep("=", 70), "\n\n")

# =============================================================================
# Summary Comparison
# =============================================================================

cat("=== SUMMARY COMPARISON ===\n\n")

comparison <- data.frame(
  DGP = c("DGP 1: Original", "DGP 2: Slides"),
  rho_true = c(results_dgp1$true_correlation, results_dgp2$true_correlation),
  PTE_P0 = c(PTE_dgp1, PTE_dgp2),
  PTE_min = c(min(PTE_vec_dgp1), min(PTE_vec_dgp2)),
  PTE_max = c(max(PTE_vec_dgp1), max(PTE_vec_dgp2)),
  beta_S = c(params1$beta_S, params2$beta_S)
)

print(comparison, row.names = FALSE)

cat("\n")

cat("Key Characteristics:\n\n")

cat("DGP 1 (Original):\n")
cat(sprintf("  - Moderate positive correlation: ρ = %.3f\n", results_dgp1$true_correlation))
cat(sprintf("  - High PTE: %.1f%%\n", 100 * PTE_dgp1))
cat(sprintf("  - Strong mediation: β_S = %.2f\n", params1$beta_S))
cat(sprintf("  - PTE fairly stable across TV ball: %.1f%% to %.1f%%\n\n",
            100 * min(PTE_vec_dgp1), 100 * max(PTE_vec_dgp1)))

cat("DGP 2 (Slides):\n")
cat(sprintf("  - Strong negative correlation: ρ = %.3f\n", results_dgp2$true_correlation))
cat(sprintf("  - Moderate PTE: %.1f%%\n", 100 * PTE_dgp2))
cat(sprintf("  - Moderate mediation: β_S = %.2f\n", params2$beta_S))
cat(sprintf("  - PTE moderately variable: %.1f%% to %.1f%%\n\n",
            100 * min(PTE_vec_dgp2), 100 * max(PTE_vec_dgp2)))

cat("=== COMPLETE ===\n")
