# ============================================================
# MANUSCRIPT SIMULATION COMPARISON (QUICK VERSION)
# Purpose: Fast prototype for testing before full run
# Inputs: None
# Outputs: Quick comparison results in sims/results/
# ============================================================

# Load the full comparison simulation functions
source("sims/scripts/manuscript_simulation_comparison.R", local = TRUE)

# Override parameters for quick run
N_REPS <- 25      # Reduced from 100
M_INNOVATIONS <- 200  # Reduced from 500
B_BOOTSTRAP <- 50     # Reduced from 200

message("===============================================")
message("QUICK COMPARISON SIMULATION (for testing)")
message(sprintf("N_REPS: %d (full: 100)", N_REPS))
message(sprintf("M_INNOVATIONS: %d (full: 500)", M_INNOVATIONS))
message(sprintf("B_BOOTSTRAP: %d (full: 200)", B_BOOTSTRAP))
message("===============================================\n")

# Test with just 3 scenarios (transportable, spurious, shift)
scenarios <- list(
  transportable_n500 = list(
    dgp = dgp_linear,
    n = 500,
    lambda = 0.3,
    name = "Transportable (Linear)",
    expected = "All methods work"
  ),

  spurious_n500 = list(
    dgp = dgp_spurious,
    n = 500,
    lambda = 0.3,
    name = "Spurious Surrogate",
    expected = "PTE misleading; minimax conservative"
  ),

  shift_strong_n500 = list(
    dgp = function(n) dgp_covariate_shift(n, shift_magnitude = 1.5),
    n = 500,
    lambda = 0.3,
    name = "Covariate Shift (strong)",
    expected = "Minimax robust; PTE may fail"
  )
)

# Run comparison
results <- tibble()

for (scenario_name in names(scenarios)) {
  scenario <- scenarios[[scenario_name]]

  message(sprintf("Running scenario: %s (%d replications)",
                  scenario$name, N_REPS))

  scenario_results <- map_dfr(1:N_REPS, function(rep) {
    if (rep %% 10 == 0) {
      message(sprintf("  Progress: %d/%d", rep, N_REPS))
    }

    run_comparison_replication(
      dgp_fn = scenario$dgp,
      n = scenario$n,
      lambda = scenario$lambda
    )
  })

  scenario_results$scenario <- scenario$name
  scenario_results$scenario_id <- scenario_name
  scenario_results$expected_behavior <- scenario$expected
  scenario_results$n <- scenario$n
  scenario_results$replication <- 1:N_REPS

  results <- bind_rows(results, scenario_results)
}

# Summary
summary_stats <- results %>%
  pivot_longer(
    cols = c(minimax_est, pte_est, within_est, princ_strat_est, mediation_est),
    names_to = "method_raw",
    values_to = "estimate"
  ) %>%
  mutate(
    method = case_when(
      method_raw == "minimax_est" ~ "Minimax",
      method_raw == "pte_est" ~ "PTE",
      method_raw == "within_est" ~ "Within-Study",
      method_raw == "princ_strat_est" ~ "Principal Strat.",
      method_raw == "mediation_est" ~ "Mediation"
    )
  ) %>%
  group_by(scenario, method) %>%
  summarise(
    mean_estimate = mean(estimate, na.rm = TRUE),
    mean_true = mean(true_correlation, na.rm = TRUE),
    bias = mean(estimate - true_correlation, na.rm = TRUE),
    rmse = sqrt(mean((estimate - true_correlation)^2, na.rm = TRUE)),
    n_reps = n(),
    .groups = "drop"
  )

message("\n=================================================")
message("QUICK COMPARISON COMPLETE")
message("=================================================\n")

print(summary_stats, width = 120)

message("\n=================================================")
message("Results look reasonable? Run full version with:")
message("  Rscript sims/scripts/manuscript_simulation_comparison.R")
message("(Estimated time: 1-2 hours)")
message("=================================================\n")

# Save quick results
write_rds(results, "sims/results/comparison_results_quick.rds")
write_rds(summary_stats, "sims/results/comparison_summary_quick.rds")

message("Quick results saved to sims/results/comparison_*_quick.rds")
