# Simulation Study: Across-Study Correlation vs Traditional Methods
#
# Compare across-study correlation method with traditional surrogate
#evaluation methods (PTE, mediation proportion) in scenarios where they diverge.

library(tidyverse)
devtools::load_all(".")  # Load package functions

# Simulation parameters
N_REPS <- 1000
N <- 500
M_FUTURE <- 100  # Number of future studies for across-study correlation
SEED_BASE <- 2026

# Create output directory
dir.create("sims/results", showWarnings = FALSE, recursive = TRUE)

# ============================================================================
# Helper Functions
# ============================================================================

#' Compute across-study correlation
compute_across_study_cor <- function(data, M = 100) {
  future_effects <- generate_future_study_effects(data, M = M)

  # Remove any NAs (edge cases)
  future_effects <- future_effects %>%
    filter(!is.na(delta_s), !is.na(delta_y))

  if (nrow(future_effects) < 10) return(NA_real_)

  cor(future_effects$delta_s, future_effects$delta_y)
}

#' Compute PTE (Proportion of Treatment Effect Explained)
#'
#' PTE = 1 - (adjusted effect / total effect)
#' where adjusted effect = E[E[Y|A=1,S] - E[Y|A=0,S]]
compute_pte <- function(data) {
  # Total effect
  E_Y_A1 <- mean(data$Y[data$A == 1])
  E_Y_A0 <- mean(data$Y[data$A == 0])
  total_effect <- E_Y_A1 - E_Y_A0

  if (abs(total_effect) < 1e-6) return(NA_real_)

  # Adjusted effect (conditional on S)
  adjusted_effect <- 0
  for (s_val in sort(unique(data$S))) {
    # Weight by P(S|A=0) (natural course distribution)
    p_s <- mean(data$S[data$A == 0] == s_val)

    # Conditional effect
    y_a1_s <- data$Y[data$A == 1 & data$S == s_val]
    y_a0_s <- data$Y[data$A == 0 & data$S == s_val]

    if (length(y_a1_s) == 0 || length(y_a0_s) == 0) next

    effect_s <- mean(y_a1_s) - mean(y_a0_s)
    adjusted_effect <- adjusted_effect + p_s * effect_s
  }

  pte <- 1 - adjusted_effect / total_effect
  return(pte)
}

#' Compute Rsurrogate if package available
compute_rsurrogate <- function(data) {
  if (!requireNamespace("Rsurrogate", quietly = TRUE)) {
    return(NA_real_)
  }

  # Try to compute, return NA on failure
  tryCatch({
    # Rsurrogate expects specific data format
    # Note: actual implementation depends on Rsurrogate API
    NA_real_  # Placeholder - would need actual Rsurrogate call
  }, error = function(e) {
    NA_real_
  })
}

#' Compute mediation proportion using simple adjustment
compute_mediation_proportion <- function(data) {
  # Similar to PTE but using different weighting
  # Mediation proportion = indirect effect / total effect
  # where indirect effect goes through S

  # Total effect
  total_effect <- mean(data$Y[data$A == 1]) - mean(data$Y[data$A == 0])

  if (abs(total_effect) < 1e-6) return(NA_real_)

  # Natural direct effect (fixing S at natural level)
  # NDE = E[Y(A=1,S(A=0))] - E[Y(A=0,S(A=0))]
  # Approximate using conditional means

  nde <- 0
  for (s_val in sort(unique(data$S))) {
    # P(S=s|A=0)
    p_s_a0 <- mean(data$S[data$A == 0] == s_val)

    # E[Y|A=1,S=s]
    y_a1_s <- data$Y[data$A == 1 & data$S == s_val]

    # E[Y|A=0,S=s]
    y_a0_s <- data$Y[data$A == 0 & data$S == s_val]

    if (length(y_a1_s) > 0 && length(y_a0_s) > 0) {
      nde <- nde + p_s_a0 * (mean(y_a1_s) - mean(y_a0_s))
    }
  }

  # Natural indirect effect = total - direct
  nie <- total_effect - nde

  # Proportion mediated
  prop_mediated <- nie / total_effect

  return(prop_mediated)
}

# ============================================================================
# Run Single Replication
# ============================================================================

run_single_rep <- function(rep_id, scenario_name, dgp_function) {
  set.seed(SEED_BASE + rep_id)

  # Generate data
  dgp <- dgp_function(n = N)
  data <- dgp$data

  # Compute across-study correlation
  across_cor <- tryCatch({
    compute_across_study_cor(data, M = M_FUTURE)
  }, error = function(e) {
    NA_real_
  })

  # Compute PTE
  pte <- tryCatch({
    compute_pte(data)
  }, error = function(e) {
    NA_real_
  })

  # Compute mediation proportion
  mediation_prop <- tryCatch({
    compute_mediation_proportion(data)
  }, error = function(e) {
    NA_real_
  })

  # Compute Rsurrogate (if available)
  rsurrogate <- tryCatch({
    compute_rsurrogate(data)
  }, error = function(e) {
    NA_real_
  })

  tibble(
    scenario = scenario_name,
    rep_id = rep_id,
    across_cor = across_cor,
    pte = pte,
    mediation_prop = mediation_prop,
    rsurrogate = rsurrogate,
    expected_across_cor = dgp$truth$expected_across_cor,
    expected_pte = dgp$truth$expected_pte,
    is_transportable = dgp$truth$is_transportable
  )
}

# ============================================================================
# Run Simulation
# ============================================================================

cat("=== METHOD COMPARISON SIMULATION ===\n")
cat("N =", N, "| M_future =", M_FUTURE, "| Reps =", N_REPS, "\n\n")

# Scenario 1: High across-study correlation, Low PTE
cat("Running Scenario 1: High ρ, Low PTE...\n")
results_scenario1 <- map_dfr(
  1:N_REPS,
  ~run_single_rep(.x, "high_cor_low_pte", generate_high_cor_low_pte),
  .progress = TRUE
)

# Scenario 2: Moderate across-study correlation, High PTE
cat("\nRunning Scenario 2: Moderate ρ, High PTE...\n")
results_scenario2 <- map_dfr(
  1:N_REPS,
  ~run_single_rep(.x, "moderate_cor_high_pte", generate_moderate_cor_high_pte),
  .progress = TRUE
)

# Combine results
results_all <- bind_rows(results_scenario1, results_scenario2)

# Save raw results
saveRDS(results_all, "sims/results/31_method_comparison_raw.rds")
write_csv(results_all, "sims/results/31_method_comparison_raw.csv")

# ============================================================================
# Summarize Results
# ============================================================================

cat("\n=== RESULTS SUMMARY ===\n\n")

summary_stats <- results_all %>%
  group_by(scenario) %>%
  summarize(
    n_reps = n(),
    # Across-study correlation
    mean_across_cor = mean(across_cor, na.rm = TRUE),
    sd_across_cor = sd(across_cor, na.rm = TRUE),
    # PTE
    mean_pte = mean(pte, na.rm = TRUE),
    sd_pte = sd(pte, na.rm = TRUE),
    # Mediation proportion
    mean_mediation = mean(mediation_prop, na.rm = TRUE),
    sd_mediation = sd(mediation_prop, na.rm = TRUE),
    # Expected values
    expected_cor = first(expected_across_cor),
    expected_pte = first(expected_pte),
    is_transportable = first(is_transportable),
    .groups = "drop"
  )

print(summary_stats)

# Divergence analysis
cat("\n=== DIVERGENCE ANALYSIS ===\n\n")

divergence <- results_all %>%
  group_by(scenario) %>%
  summarize(
    cor_pte_diff = mean(across_cor - pte, na.rm = TRUE),
    cor_gt_pte_pct = mean(across_cor > pte, na.rm = TRUE) * 100,
    .groups = "drop"
  )

print(divergence)

cat("\nScenario 1 (high_cor_low_pte):\n")
cat(sprintf("  Across-study ρ > PTE in %.1f%% of replications\n",
            divergence$cor_gt_pte_pct[1]))

cat("\nScenario 2 (moderate_cor_high_pte):\n")
cat(sprintf("  PTE > Across-study ρ in %.1f%% of replications\n",
            100 - divergence$cor_gt_pte_pct[2]))

# Save summary
saveRDS(summary_stats, "sims/results/31_method_comparison_summary.rds")
write_csv(summary_stats, "sims/results/31_method_comparison_summary.csv")

cat("\n=== SIMULATION COMPLETE ===\n")
cat("Results saved to sims/results/31_method_comparison_*.{rds,csv}\n")
