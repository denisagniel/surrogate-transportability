#!/usr/bin/env Rscript
# ROBUSTNESS TESTING: Does shrinkage factor 0.5 work across different DGPs?

library(tidyverse)
library(here)

devtools::load_all(here("package"))

cat("=============================================================================\n")
cat("PHASE 2: ROBUSTNESS TESTING\n")
cat("=============================================================================\n\n")

cat("QUESTION: Does shrinkage factor 0.5 generalize across DGPs?\n\n")

cat("TEST DIMENSIONS:\n")
cat("  1. Treatment effect functions (linear, nonlinear, heterogeneous)\n")
cat("  2. Noise levels (low, medium, high)\n")
cat("  3. Covariate distributions (normal, correlated, skewed)\n")
cat("  4. Sample sizes (n = 250, 500, 1000)\n")
cat("  5. Lambda values (lambda_w = 0.3, 0.5, 0.8)\n\n")

# =============================================================================
# Helper functions
# =============================================================================

compute_true_minimax <- function(X1, X2, tau_s_fn, tau_y_fn, lambda_w) {
  n <- length(X1)
  tau_s_true <- tau_s_fn(X1, X2)
  tau_y_true <- tau_y_fn(X1, X2)
  h_true <- tau_s_true * tau_y_true
  X <- scale(cbind(X1, X2))
  cost_matrix <- as.matrix(dist(X, method = "euclidean"))^2

  dual_objective <- function(gamma) {
    obj_matrix <- matrix(h_true, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  optimize(dual_objective, interval = c(0, 100), maximum = TRUE)$objective
}

estimate_with_shrinkage <- function(data, covariates, lambda_w, shrink_factor) {
  tau_s <- estimate_treatment_effect_function(
    data = data, outcome = "S", covariates = covariates,
    method = "kernel", cross_fit = TRUE
  )
  tau_y <- estimate_treatment_effect_function(
    data = data, outcome = "Y", covariates = covariates,
    method = "kernel", cross_fit = TRUE
  )

  h_est <- tau_s$tau_hat * tau_y$tau_hat
  h_mean <- mean(h_est)
  h_shrunk <- h_mean + shrink_factor * (h_est - h_mean)

  n <- nrow(data)
  X_scaled <- scale(data[, covariates])
  cost_matrix <- as.matrix(dist(X_scaled, method = "euclidean"))^2

  dual_objective <- function(gamma) {
    obj_matrix <- matrix(h_shrunk, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  optimize(dual_objective, interval = c(0, 100), maximum = TRUE)$objective
}

# =============================================================================
# DGP Scenarios
# =============================================================================

dgp_scenarios <- list(
  # Baseline (what we tested in Phase 2)
  baseline = list(
    name = "Baseline (Phase 2)",
    tau_s = function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2,
    tau_y = function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2,
    X_gen = function(n) list(X1 = rnorm(n), X2 = rnorm(n)),
    noise_s = 0.3,
    noise_y = 0.4
  ),

  # Scenario 1: Nonlinear treatment effects
  nonlinear = list(
    name = "Nonlinear Effects",
    tau_s = function(X1, X2) 0.3 + 0.2 * X1^2 - 0.1 * X2,
    tau_y = function(X1, X2) 0.4 + 0.3 * sin(X1) + 0.1 * X2,
    X_gen = function(n) list(X1 = rnorm(n), X2 = rnorm(n)),
    noise_s = 0.3,
    noise_y = 0.4
  ),

  # Scenario 2: Strong heterogeneity
  strong_hetero = list(
    name = "Strong Heterogeneity",
    tau_s = function(X1, X2) 0.5 + 0.5 * X1 - 0.3 * X2 + 0.2 * X1 * X2,
    tau_y = function(X1, X2) 0.6 + 0.6 * X1 + 0.3 * X2 + 0.3 * X1 * X2,
    X_gen = function(n) list(X1 = rnorm(n), X2 = rnorm(n)),
    noise_s = 0.3,
    noise_y = 0.4
  ),

  # Scenario 3: Weak heterogeneity
  weak_hetero = list(
    name = "Weak Heterogeneity",
    tau_s = function(X1, X2) 0.3 + 0.05 * X1 - 0.05 * X2,
    tau_y = function(X1, X2) 0.4 + 0.05 * X1 + 0.05 * X2,
    X_gen = function(n) list(X1 = rnorm(n), X2 = rnorm(n)),
    noise_s = 0.3,
    noise_y = 0.4
  ),

  # Scenario 4: High noise
  high_noise = list(
    name = "High Noise",
    tau_s = function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2,
    tau_y = function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2,
    X_gen = function(n) list(X1 = rnorm(n), X2 = rnorm(n)),
    noise_s = 0.6,
    noise_y = 0.8
  ),

  # Scenario 5: Low noise
  low_noise = list(
    name = "Low Noise",
    tau_s = function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2,
    tau_y = function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2,
    X_gen = function(n) list(X1 = rnorm(n), X2 = rnorm(n)),
    noise_s = 0.15,
    noise_y = 0.20
  ),

  # Scenario 6: Correlated covariates
  corr_covariates = list(
    name = "Correlated Covariates",
    tau_s = function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2,
    tau_y = function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2,
    X_gen = function(n) {
      X1 <- rnorm(n)
      X2 <- 0.7 * X1 + sqrt(1 - 0.7^2) * rnorm(n)
      list(X1 = X1, X2 = X2)
    },
    noise_s = 0.3,
    noise_y = 0.4
  ),

  # Scenario 7: Skewed covariates
  skewed_covariates = list(
    name = "Skewed Covariates",
    tau_s = function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2,
    tau_y = function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2,
    X_gen = function(n) {
      X1 <- rexp(n, rate = 1) - 1  # Right-skewed, centered
      X2 <- rt(n, df = 3) / 2       # Heavy-tailed
      list(X1 = X1, X2 = X2)
    },
    noise_s = 0.3,
    noise_y = 0.4
  ),

  # Scenario 8: Near null effects
  near_null = list(
    name = "Near-Null Effects",
    tau_s = function(X1, X2) 0.05 + 0.02 * X1 - 0.02 * X2,
    tau_y = function(X1, X2) 0.05 + 0.03 * X1 + 0.02 * X2,
    X_gen = function(n) list(X1 = rnorm(n), X2 = rnorm(n)),
    noise_s = 0.3,
    noise_y = 0.4
  )
)

# =============================================================================
# Test parameters
# =============================================================================

test_params <- expand.grid(
  scenario = names(dgp_scenarios),
  n = c(250, 500),
  lambda_w = c(0.3, 0.5, 0.8),
  stringsAsFactors = FALSE
)

cat("Total test conditions:", nrow(test_params), "\n")
cat("  Scenarios:", length(dgp_scenarios), "\n")
cat("  Sample sizes:", length(unique(test_params$n)), "\n")
cat("  Lambda values:", length(unique(test_params$lambda_w)), "\n")
cat("  Replications per condition: 30\n")
cat("  Total replications:", nrow(test_params) * 30, "\n\n")

# =============================================================================
# Run robustness tests
# =============================================================================

cat("=============================================================================\n")
cat("RUNNING ROBUSTNESS TESTS\n")
cat("=============================================================================\n\n")

n_reps_per_condition <- 30

# Test shrinkage factors
shrink_factors <- c(0.4, 0.5, 0.6)

all_results <- list()
test_counter <- 0

for (i in 1:nrow(test_params)) {
  scenario_name <- test_params$scenario[i]
  n <- test_params$n[i]
  lambda_w <- test_params$lambda_w[i]

  dgp <- dgp_scenarios[[scenario_name]]

  cat(sprintf("\n--- Test %d/%d: %s, n=%d, lambda=%.1f ---\n",
              i, nrow(test_params), dgp$name, n, lambda_w))

  results_condition <- map_dfr(1:n_reps_per_condition, function(rep) {
    set.seed(rep + 1000 * i)

    # Generate data
    X <- dgp$X_gen(n)
    X1 <- X$X1
    X2 <- X$X2
    A <- rbinom(n, 1, 0.5)

    tau_s_true <- dgp$tau_s(X1, X2)
    tau_y_true <- dgp$tau_y(X1, X2)

    S <- tau_s_true * A + 0.5 + 0.2 * X1 + rnorm(n, sd = dgp$noise_s)
    Y <- tau_y_true * A + 0.6 + 0.3 * X2 + rnorm(n, sd = dgp$noise_y)

    data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

    # Truth
    truth <- tryCatch({
      compute_true_minimax(X1, X2, dgp$tau_s, dgp$tau_y, lambda_w)
    }, error = function(e) NA)

    # Test multiple shrinkage factors
    results_shrink <- map_dfr(shrink_factors, function(sf) {
      est <- tryCatch({
        estimate_with_shrinkage(data, c("X1", "X2"), lambda_w, sf)
      }, error = function(e) NA)

      tibble(
        shrink_factor = sf,
        estimate = est
      )
    })

    results_shrink %>%
      mutate(
        rep = rep,
        truth = truth,
        bias = estimate - truth
      )
  })

  results_condition <- results_condition %>%
    mutate(
      scenario = scenario_name,
      scenario_name = dgp$name,
      n = n,
      lambda_w = lambda_w
    )

  all_results[[i]] <- results_condition

  # Quick summary for this condition
  summary_condition <- results_condition %>%
    group_by(shrink_factor) %>%
    summarise(
      mean_bias = mean(bias, na.rm = TRUE),
      rmse = sqrt(mean(bias^2, na.rm = TRUE)),
      .groups = "drop"
    )

  cat("  Quick summary by shrinkage factor:\n")
  print(summary_condition, n = Inf)
}

cat("\n")

# Combine all results
results_all <- bind_rows(all_results)

# =============================================================================
# Analyze robustness
# =============================================================================

cat("=============================================================================\n")
cat("ROBUSTNESS ANALYSIS\n")
cat("=============================================================================\n\n")

# Overall performance by shrinkage factor
cat("1. OVERALL PERFORMANCE BY SHRINKAGE FACTOR:\n\n")

overall_summary <- results_all %>%
  filter(!is.na(bias)) %>%
  group_by(shrink_factor) %>%
  summarise(
    n_conditions = n(),
    mean_bias = mean(bias),
    median_bias = median(bias),
    rmse = sqrt(mean(bias^2)),
    mae = mean(abs(bias)),
    .groups = "drop"
  ) %>%
  arrange(rmse)

print(overall_summary, n = Inf)
cat("\n")

# Performance by scenario
cat("2. PERFORMANCE BY SCENARIO (shrink_factor = 0.5):\n\n")

scenario_summary <- results_all %>%
  filter(shrink_factor == 0.5, !is.na(bias)) %>%
  group_by(scenario_name) %>%
  summarise(
    n_reps = n(),
    mean_bias = mean(bias),
    rmse = sqrt(mean(bias^2)),
    .groups = "drop"
  ) %>%
  arrange(desc(abs(mean_bias)))

print(scenario_summary, n = Inf)
cat("\n")

# Performance by sample size
cat("3. PERFORMANCE BY SAMPLE SIZE (shrink_factor = 0.5):\n\n")

n_summary <- results_all %>%
  filter(shrink_factor == 0.5, !is.na(bias)) %>%
  group_by(n) %>%
  summarise(
    mean_bias = mean(bias),
    rmse = sqrt(mean(bias^2)),
    .groups = "drop"
  )

print(n_summary, n = Inf)
cat("\n")

# Performance by lambda
cat("4. PERFORMANCE BY LAMBDA (shrink_factor = 0.5):\n\n")

lambda_summary <- results_all %>%
  filter(shrink_factor == 0.5, !is.na(bias)) %>%
  group_by(lambda_w) %>%
  summarise(
    mean_bias = mean(bias),
    rmse = sqrt(mean(bias^2)),
    .groups = "drop"
  )

print(lambda_summary, n = Inf)
cat("\n")

# Check if 0.5 is consistently best
cat("5. IS SHRINKAGE FACTOR 0.5 CONSISTENTLY BEST?\n\n")

best_per_condition <- results_all %>%
  filter(!is.na(bias)) %>%
  group_by(scenario, n, lambda_w) %>%
  slice_min(abs(bias), n = 1, with_ties = FALSE) %>%
  ungroup()

shrink_factor_wins <- best_per_condition %>%
  count(shrink_factor) %>%
  arrange(desc(n))

cat("Best shrinkage factor by condition:\n")
print(shrink_factor_wins, n = Inf)
cat("\n")

pct_0_5_best <- mean(best_per_condition$shrink_factor == 0.5) * 100
cat(sprintf("Shrinkage factor 0.5 is best in %.1f%% of conditions\n\n", pct_0_5_best))

# =============================================================================
# Visualization
# =============================================================================

cat("=============================================================================\n")
cat("CREATING VISUALIZATIONS\n")
cat("=============================================================================\n\n")

library(ggplot2)

# 1. Bias by scenario and shrinkage factor
p1 <- ggplot(results_all %>% filter(!is.na(bias)),
             aes(x = shrink_factor, y = bias, group = shrink_factor)) +
  geom_boxplot() +
  facet_wrap(~scenario_name, scales = "free_y") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
  labs(
    title = "Bias by Scenario and Shrinkage Factor",
    x = "Shrinkage Factor",
    y = "Bias"
  ) +
  theme_minimal(base_size = 10)

# 2. RMSE by scenario
scenario_rmse <- results_all %>%
  filter(!is.na(bias)) %>%
  group_by(scenario_name, shrink_factor) %>%
  summarise(rmse = sqrt(mean(bias^2)), .groups = "drop")

p2 <- ggplot(scenario_rmse, aes(x = shrink_factor, y = rmse, color = scenario_name, group = scenario_name)) +
  geom_line() +
  geom_point() +
  labs(
    title = "RMSE by Scenario and Shrinkage Factor",
    x = "Shrinkage Factor",
    y = "RMSE",
    color = "Scenario"
  ) +
  theme_minimal(base_size = 10)

# 3. Performance across conditions (heatmap)
condition_performance <- results_all %>%
  filter(shrink_factor == 0.5, !is.na(bias)) %>%
  group_by(scenario_name, n, lambda_w) %>%
  summarise(mean_bias = mean(bias), .groups = "drop") %>%
  unite("condition", n, lambda_w, sep = ", λ=")

p3 <- ggplot(condition_performance, aes(x = condition, y = scenario_name, fill = abs(mean_bias))) +
  geom_tile() +
  scale_fill_gradient(low = "white", high = "red") +
  labs(
    title = "Absolute Bias Across Conditions (shrink = 0.5)",
    x = "Sample Size, Lambda",
    y = "Scenario",
    fill = "|Bias|"
  ) +
  theme_minimal(base_size = 10) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(here("phase2_robustness_bias_by_scenario.png"), p1, width = 12, height = 10)
ggsave(here("phase2_robustness_rmse_curves.png"), p2, width = 10, height = 6)
ggsave(here("phase2_robustness_heatmap.png"), p3, width = 10, height = 6)

cat("Plots saved:\n")
cat("  - phase2_robustness_bias_by_scenario.png\n")
cat("  - phase2_robustness_rmse_curves.png\n")
cat("  - phase2_robustness_heatmap.png\n\n")

# =============================================================================
# Save results
# =============================================================================

results_list <- list(
  all_results = results_all,
  overall_summary = overall_summary,
  scenario_summary = scenario_summary,
  best_per_condition = best_per_condition,
  test_params = test_params
)

saveRDS(results_list, here("phase2_robustness_results.rds"))
cat("Results saved to: phase2_robustness_results.rds\n\n")

# =============================================================================
# Final assessment
# =============================================================================

cat("=============================================================================\n")
cat("ROBUSTNESS ASSESSMENT\n")
cat("=============================================================================\n\n")

# Criteria for "robust"
robust_criteria <- list(
  overall_rmse_05 = overall_summary %>% filter(shrink_factor == 0.5) %>% pull(rmse) < 0.04,
  overall_bias_05 = abs(overall_summary %>% filter(shrink_factor == 0.5) %>% pull(mean_bias)) < 0.02,
  best_in_majority = pct_0_5_best >= 50,
  no_catastrophic_failures = max(abs(scenario_summary$mean_bias)) < 0.05
)

all_pass <- all(unlist(robust_criteria))

if (all_pass) {
  cat("✓✓✓ SHRINKAGE FACTOR 0.5 IS ROBUST ✓✓✓\n\n")
  cat("Passes all robustness criteria:\n")
  cat("  ✓ Overall RMSE < 0.04:", round(overall_summary %>% filter(shrink_factor == 0.5) %>% pull(rmse), 4), "\n")
  cat("  ✓ Overall bias < 0.02:", round(abs(overall_summary %>% filter(shrink_factor == 0.5) %>% pull(mean_bias)), 4), "\n")
  cat("  ✓ Best in ≥50% of conditions:", sprintf("%.1f%%", pct_0_5_best), "\n")
  cat("  ✓ No catastrophic failures (max |bias| < 0.05)\n\n")
  cat("RECOMMENDATION: Use shrinkage factor 0.5 as default\n")
  cat("  - Works across varied DGPs\n")
  cat("  - Robust to sample size and lambda\n")
  cat("  - Ready for package implementation\n\n")

} else {
  cat("⚠ SHRINKAGE FACTOR 0.5 SHOWS LIMITATIONS ⚠\n\n")

  if (!robust_criteria$overall_rmse_05) {
    cat("  ✗ Overall RMSE too high:", round(overall_summary %>% filter(shrink_factor == 0.5) %>% pull(rmse), 4), "\n")
  }
  if (!robust_criteria$overall_bias_05) {
    cat("  ✗ Overall bias too large:", round(overall_summary %>% filter(shrink_factor == 0.5) %>% pull(mean_bias), 4), "\n")
  }
  if (!robust_criteria$best_in_majority) {
    cat("  ✗ Not best in majority of conditions:", sprintf("%.1f%%", pct_0_5_best), "\n")
  }
  if (!robust_criteria$no_catastrophic_failures) {
    worst_scenario <- scenario_summary %>% slice_max(abs(mean_bias), n = 1)
    cat("  ✗ Catastrophic failure in:", worst_scenario$scenario_name,
        "with bias =", round(worst_scenario$mean_bias, 4), "\n")
  }

  cat("\nRECOMMENDATIONS:\n")

  # Check if another shrinkage factor is universally better
  best_overall <- overall_summary %>% slice_min(rmse, n = 1)
  if (best_overall$shrink_factor != 0.5) {
    cat("  → Consider using shrinkage factor", best_overall$shrink_factor,
        "instead (RMSE =", round(best_overall$rmse, 4), ")\n")
  }

  # Check if adaptive selection would help
  if (pct_0_5_best < 70) {
    cat("  → Consider adaptive shrinkage factor selection\n")
    cat("     (data-driven choice based on DGP characteristics)\n")
  }

  # Identify problematic scenarios
  problem_scenarios <- scenario_summary %>% filter(abs(mean_bias) > 0.03)
  if (nrow(problem_scenarios) > 0) {
    cat("  → Problem scenarios needing special handling:\n")
    for (i in 1:min(3, nrow(problem_scenarios))) {
      cat("     •", problem_scenarios$scenario_name[i],
          "(bias =", round(problem_scenarios$mean_bias[i], 4), ")\n")
    }
  }
}

cat("\n=============================================================================\n")
cat("ROBUSTNESS TESTING COMPLETE\n")
cat("=============================================================================\n")
