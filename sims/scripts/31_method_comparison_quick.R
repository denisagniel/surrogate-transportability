# Quick Test: Method Comparison Simulation
# Run with fewer reps for testing

library(tidyverse)
devtools::load_all(".")  # Load package functions

# Test parameters (reduced from full simulation)
N_REPS <- 50  # Quick test: 50 reps instead of 1000
N <- 500
M_FUTURE <- 100
SEED_BASE <- 2026

# Create output directory
dir.create("sims/results", showWarnings = FALSE, recursive = TRUE)

# Helper functions (from main simulation script)

compute_across_study_cor <- function(data, M = 100) {
  future_effects <- generate_future_study_effects(data, M = M)
  future_effects <- future_effects %>%
    filter(!is.na(delta_s), !is.na(delta_y))
  if (nrow(future_effects) < 10) return(NA_real_)
  cor(future_effects$delta_s, future_effects$delta_y)
}

compute_pte <- function(data) {
  E_Y_A1 <- mean(data$Y[data$A == 1])
  E_Y_A0 <- mean(data$Y[data$A == 0])
  total_effect <- E_Y_A1 - E_Y_A0
  if (abs(total_effect) < 1e-6) return(NA_real_)

  adjusted_effect <- 0
  for (s_val in sort(unique(data$S))) {
    p_s <- mean(data$S[data$A == 0] == s_val)
    y_a1_s <- data$Y[data$A == 1 & data$S == s_val]
    y_a0_s <- data$Y[data$A == 0 & data$S == s_val]
    if (length(y_a1_s) == 0 || length(y_a0_s) == 0) next
    effect_s <- mean(y_a1_s) - mean(y_a0_s)
    adjusted_effect <- adjusted_effect + p_s * effect_s
  }

  pte <- 1 - adjusted_effect / total_effect
  return(pte)
}

run_single_rep <- function(rep_id, scenario_name, dgp_function) {
  set.seed(SEED_BASE + rep_id)
  dgp <- dgp_function(n = N)
  data <- dgp$data

  across_cor <- tryCatch(compute_across_study_cor(data, M = M_FUTURE),
                          error = function(e) NA_real_)
  pte <- tryCatch(compute_pte(data), error = function(e) NA_real_)

  tibble(
    scenario = scenario_name,
    rep_id = rep_id,
    across_cor = across_cor,
    pte = pte,
    expected_across_cor = dgp$truth$expected_across_cor,
    expected_pte = dgp$truth$expected_pte
  )
}

cat("=== QUICK TEST: METHOD COMPARISON ===\n")
cat("N =", N, "| M_future =", M_FUTURE, "| Reps =", N_REPS, "(quick test)\n\n")

# Run both scenarios with reduced reps
cat("Running Scenario 1...\n")
results_scenario1 <- map_dfr(
  1:N_REPS,
  ~run_single_rep(.x, "high_cor_low_pte", generate_high_cor_low_pte)
)

cat("Running Scenario 2...\n")
results_scenario2 <- map_dfr(
  1:N_REPS,
  ~run_single_rep(.x, "moderate_cor_high_pte", generate_moderate_cor_high_pte)
)

results_all <- bind_rows(results_scenario1, results_scenario2)

# Quick summary
cat("\n=== QUICK TEST RESULTS ===\n\n")

summary_stats <- results_all %>%
  group_by(scenario) %>%
  summarize(
    n = n(),
    mean_cor = mean(across_cor, na.rm = TRUE),
    mean_pte = mean(pte, na.rm = TRUE),
    cor_gt_pte = mean(across_cor > pte, na.rm = TRUE),
    .groups = "drop"
  )

print(summary_stats)

cat("\n✓ Quick test complete. Run full simulation with 31_method_comparison.R\n")
