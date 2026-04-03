# ============================================================
# MANUSCRIPT SIMULATION STUDY (QUICK VERSION)
# Purpose: Fast prototype for testing before full run
# Inputs: None
# Outputs: Quick validation results in sims/results/
# ============================================================

# Load the full simulation functions
source("sims/scripts/manuscript_simulation_study.R", local = TRUE)

# Override parameters for quick run
N_REPS <- 50      # Reduced from 500
M_INNOVATIONS <- 200  # Reduced from 1000
B_BOOTSTRAP <- 100    # Reduced from 500

message("===============================================")
message("QUICK SIMULATION (for testing)")
message(sprintf("N_REPS: %d (full: 500)", N_REPS))
message(sprintf("M_INNOVATIONS: %d (full: 1000)", M_INNOVATIONS))
message(sprintf("B_BOOTSTRAP: %d (full: 500)", B_BOOTSTRAP))
message("===============================================\n")

# Test with just 3 scenarios (well-behaved, stress test, comparison)
scenarios <- list(
  linear_n500 = list(dgp = dgp_linear, n = 500, lambda = 0.3,
                     true_corr = NA, name = "Linear (n=500)"),
  smooth_complex_n500 = list(dgp = dgp_smooth_complex, n = 500, lambda = 0.3,
                             true_corr = NA, name = "Smooth Complex (STRESS)"),
  spurious_n500 = list(dgp = dgp_spurious, n = 500, lambda = 0.3,
                       true_corr = NA, name = "Spurious (comparison)")
)

# Run Section 3 (from main script)
results <- tibble()

for (scenario_name in names(scenarios)) {
  scenario <- scenarios[[scenario_name]]

  message(sprintf("Running scenario: %s (%d replications)",
                  scenario$name, N_REPS))

  scenario_results <- map_dfr(1:N_REPS, function(rep) {
    if (rep %% 25 == 0) {
      message(sprintf("  Progress: %d/%d", rep, N_REPS))
    }

    run_replication(
      dgp_fn = scenario$dgp,
      n = scenario$n,
      lambda = scenario$lambda,
      true_correlation = scenario$true_corr,
      M = M_INNOVATIONS,
      B = B_BOOTSTRAP
    )
  })

  scenario_results$scenario <- scenario$name
  scenario_results$scenario_id <- scenario_name
  scenario_results$n <- scenario$n
  scenario_results$replication <- 1:N_REPS

  results <- bind_rows(results, scenario_results)
}

# Summary
summary_stats <- results %>%
  group_by(scenario, n) %>%
  summarise(
    mean_estimate = mean(estimate, na.rm = TRUE),
    sd_estimate = sd(estimate, na.rm = TRUE),
    mean_ci_width = mean(ci_width, na.rm = TRUE),
    mean_within_corr = mean(within_study_corr, na.rm = TRUE),
    n_reps = n(),
    .groups = "drop"
  )

message("\n==================================================")
message("QUICK SIMULATION COMPLETE")
message("==================================================\n")

print(summary_stats, width = 120)

message("\n==================================================")
message("Results look reasonable? Run full version with:")
message("  Rscript sims/scripts/manuscript_simulation_study.R")
message("(Estimated time: 4-6 hours)")
message("==================================================\n")

# Save quick results
write_rds(results, "sims/results/manuscript_simulation_quick_results.rds")
write_rds(summary_stats, "sims/results/manuscript_simulation_quick_summary.rds")

message("Quick results saved to sims/results/manuscript_simulation_quick_*")
