#!/usr/bin/env Rscript

#' Minimax Method Validation Study
#'
#' Research Questions:
#' 1. Do minimax bounds [φ_*, φ*] contain TRUE φ(F_λ) in 100% of cases?
#'    (Should be YES by construction - bounds hold for ALL μ in class M)
#' 2. How do minimax bounds compare to standard method CI?
#'    - Width ratio
#'    - Coverage comparison
#' 3. Trade-off: guaranteed coverage vs. interval width
#'
#' Design:
#'   For each baseline:
#'     1. Compute TRUE φ(F_λ) using μ = Dirichlet(1,...,1)
#'     2. Compute standard method CI (assumes μ known)
#'     3. Compute minimax bounds [φ_*, φ*] (robust to μ misspecification)
#'     4. Check:
#'        - Standard CI contains TRUE φ? (expect ~95%)
#'        - Minimax bounds contain TRUE φ? (expect 100%)

library(devtools)
library(dplyr)
library(tibble)
library(ggplot2)

# Ensure we're in project root (where package/ directory is)
while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

if (!dir.exists("package")) {
  stop("Cannot find package/ directory. Please run from project root or sims/scripts/")
}

devtools::load_all("package/", quiet = TRUE)

set.seed(20260323)

# Parameters
N_BASELINE <- 1000
N_REPLICATIONS <- 50  # Balance between speed and statistical power
N_TRUE_STUDIES <- 2000  # For computing TRUE φ(F_λ)
N_INNOVATIONS <- 1000   # For both methods
CONFIDENCE_LEVEL <- 0.95

# Minimax parameters
N_DIRICHLET_GRID <- 20  # Balance speed vs. coverage
INCLUDE_VERTICES <- TRUE
MAX_VERTICES <- 30

# Test scenarios
scenarios <- tibble::tibble(
  name = c("Small λ=0.1", "Moderate λ=0.3", "Large λ=0.5"),
  lambda = c(0.1, 0.3, 0.5)
)

cat("================================================================\n")
cat("MINIMAX METHOD VALIDATION STUDY\n")
cat("================================================================\n\n")

cat("Research Questions:\n")
cat("  1. Do minimax bounds achieve 100% coverage?\n")
cat("  2. How much wider are minimax bounds vs. standard CI?\n")
cat("  3. Is the width cost acceptable for guaranteed coverage?\n\n")

cat("Parameters:\n")
cat(sprintf("  Baseline n: %d\n", N_BASELINE))
cat(sprintf("  Replications per scenario: %d\n", N_REPLICATIONS))
cat(sprintf("  Studies for TRUE φ(F_λ): %d\n", N_TRUE_STUDIES))
cat(sprintf("  Innovations (M) for methods: %d\n", N_INNOVATIONS))
cat(sprintf("  Confidence level: %.2f\n", CONFIDENCE_LEVEL))

cat("\n")
cat("Minimax Class M:\n")
cat(sprintf("  Dirichlet(α) grid: %d points\n", N_DIRICHLET_GRID))
cat(sprintf("  Vertices included: %s (max %d)\n",
            ifelse(INCLUDE_VERTICES, "YES", "NO"), MAX_VERTICES))
cat(sprintf("  Total evaluations per baseline: ~%d\n",
            N_DIRICHLET_GRID + MAX_VERTICES + 1))

cat("\n")
cat("----------------------------------------------------------------\n")
cat("Running Validation Study\n")
cat("----------------------------------------------------------------\n\n")

start_time <- Sys.time()

all_results <- tibble::tibble()

for (s in 1:nrow(scenarios)) {
  scenario <- scenarios[s, ]
  lambda <- scenario$lambda

  cat(sprintf("Scenario: %s\n", scenario$name))

  scenario_results <- tibble::tibble(
    replication = integer(),
    lambda = numeric(),
    scenario = character(),
    true_phi = numeric(),

    # Standard method
    method_estimate = numeric(),
    method_ci_lower = numeric(),
    method_ci_upper = numeric(),
    method_ci_width = numeric(),
    method_contains_true = logical(),

    # Minimax bounds
    minimax_upper = numeric(),
    minimax_lower = numeric(),
    minimax_width = numeric(),
    minimax_contains_true = logical(),

    # Comparison
    width_ratio = numeric(),  # minimax / method
    both_contain = logical(),
    minimax_time = numeric()
  )

  for (rep in 1:N_REPLICATIONS) {
    if (rep %% 10 == 0 || rep == 1) {
      elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
      rate <- elapsed / ((s - 1) * N_REPLICATIONS + rep)
      remaining <- rate * (nrow(scenarios) * N_REPLICATIONS - (s - 1) * N_REPLICATIONS - rep)
      cat(sprintf("  Replication %d/%d (%.2f min elapsed, %.3f min/rep, ~%.1f min remaining)\n",
                  rep, N_REPLICATIONS, elapsed, rate, remaining))
    }

    # Generate baseline
    baseline <- generate_study_data(
      n = N_BASELINE,
      treatment_effect_surrogate = c(0.3, 0.9),
      treatment_effect_outcome = c(0.2, 0.8)
    )

    # 1. Compute TRUE φ(F_λ) using μ = Dirichlet(1,...,1)
    # Use REWEIGHTING approach (same as under-model validation)
    n <- nrow(baseline)

    # Draw M Dirichlet innovations
    innovations <- MCMCpack::rdirichlet(N_TRUE_STUDIES, rep(1, n))

    # For each innovation, compute treatment effects via reweighting
    true_effects <- matrix(NA, nrow = N_TRUE_STUDIES, ncol = 2)

    for (m in 1:N_TRUE_STUDIES) {
      # Current study weights (uniform empirical)
      p0_weights <- rep(1/n, n)

      # Innovation weights
      p_tilde <- innovations[m, ]

      # Mixture: Q_m = (1-λ)P₀ + λP̃
      q_weights <- (1 - lambda) * p0_weights + lambda * p_tilde

      # Treatment effects via reweighting (same data, different weights)
      delta_s <- compute_treatment_effect_weighted(baseline, "S", q_weights)
      delta_y <- compute_treatment_effect_weighted(baseline, "Y", q_weights)

      true_effects[m, 1] <- delta_s
      true_effects[m, 2] <- delta_y
    }

    # TRUE φ(F_λ) = correlation of treatment effects under F_λ
    true_phi <- cor(true_effects[, 1], true_effects[, 2])

    # 2. Standard method CI
    method_result <- tryCatch({
      surrogate_inference_if(
        baseline,
        lambda = lambda,
        n_innovations = N_INNOVATIONS,
        functional_type = "correlation",
        alpha = 1,
        confidence_level = CONFIDENCE_LEVEL
      )
    }, error = function(e) {
      warning(sprintf("Method error in rep %d: %s", rep, e$message))
      return(NULL)
    })

    if (is.null(method_result)) next

    method_contains <- (method_result$ci_lower <= true_phi) &&
                       (true_phi <= method_result$ci_upper)

    # 3. Minimax bounds
    minimax_start <- Sys.time()

    minimax_result <- tryCatch({
      surrogate_inference_minimax(
        current_data = baseline,
        lambda = lambda,
        functional_type = "correlation",
        n_dirichlet_grid = N_DIRICHLET_GRID,
        include_vertices = INCLUDE_VERTICES,
        max_vertices = MAX_VERTICES,
        n_innovations = N_INNOVATIONS,
        n_bootstrap = 0,  # No bootstrap for speed
        parallel = FALSE,  # Sequential for stability
        verbose = FALSE
      )
    }, error = function(e) {
      warning(sprintf("Minimax error in rep %d: %s", rep, e$message))
      return(NULL)
    })

    minimax_time <- as.numeric(difftime(Sys.time(), minimax_start, units = "secs"))

    if (is.null(minimax_result)) next

    minimax_contains <- (minimax_result$phi_star_lower <= true_phi) &&
                        (true_phi <= minimax_result$phi_star)

    # Store results
    scenario_results <- rbind(scenario_results, tibble::tibble(
      replication = rep,
      lambda = lambda,
      scenario = scenario$name,
      true_phi = true_phi,

      method_estimate = method_result$estimate,
      method_ci_lower = method_result$ci_lower,
      method_ci_upper = method_result$ci_upper,
      method_ci_width = method_result$ci_upper - method_result$ci_lower,
      method_contains_true = method_contains,

      minimax_upper = minimax_result$phi_star,
      minimax_lower = minimax_result$phi_star_lower,
      minimax_width = minimax_result$bound_width,
      minimax_contains_true = minimax_contains,

      width_ratio = minimax_result$bound_width / (method_result$ci_upper - method_result$ci_lower),
      both_contain = method_contains && minimax_contains,
      minimax_time = minimax_time
    ))
  }

  cat("\n")

  all_results <- rbind(all_results, scenario_results)
}

cat("================================================================\n")
cat("RESULTS\n")
cat("================================================================\n\n")

# Coverage rates by scenario
coverage_summary <- all_results %>%
  group_by(scenario, lambda) %>%
  summarise(
    n = n(),
    method_coverage = mean(method_contains_true),
    minimax_coverage = mean(minimax_contains_true),
    mean_width_ratio = mean(width_ratio),
    mean_method_width = mean(method_ci_width),
    mean_minimax_width = mean(minimax_width),
    mean_time_sec = mean(minimax_time),
    .groups = "drop"
  ) %>%
  arrange(lambda)

cat("Coverage Rates by Lambda:\n\n")
cat(sprintf("%-20s %5s %10s %12s %12s %10s\n",
            "Scenario", "λ", "Method", "Minimax", "Width Ratio", "Status"))
cat(strrep("-", 80), "\n")

for (i in 1:nrow(coverage_summary)) {
  row <- coverage_summary[i, ]

  # Status indicator
  method_ok <- row$method_coverage >= 0.93 && row$method_coverage <= 0.97
  minimax_ok <- row$minimax_coverage >= 0.95

  status <- if (method_ok && minimax_ok) "✓✓" else if (minimax_ok) "✓~" else "??"

  cat(sprintf("%-20s %5.2f %9.1f%% %11.1f%% %11.2fx %10s\n",
              row$scenario,
              row$lambda,
              row$method_coverage * 100,
              row$minimax_coverage * 100,
              row$mean_width_ratio,
              status))
}

cat("\n")
cat("Status: ✓✓ = both nominal; ✓~ = minimax guaranteed; ?? = check results\n")

# Overall statistics
cat("\n")
cat("Overall Statistics:\n\n")
cat(sprintf("  Standard method coverage: %.1f%% (target: 95%%)\n",
            mean(all_results$method_contains_true) * 100))
cat(sprintf("  Minimax coverage:         %.1f%% (target: 100%%)\n",
            mean(all_results$minimax_contains_true) * 100))
cat(sprintf("  Mean width ratio:         %.2fx\n",
            mean(all_results$width_ratio)))
cat(sprintf("  Minimax time per rep:     %.1f seconds\n",
            mean(all_results$minimax_time)))

cat("\n")
cat("Width Comparison:\n\n")
cat(sprintf("  Mean method CI width:   %.4f\n", mean(all_results$method_ci_width)))
cat(sprintf("  Mean minimax width:     %.4f\n", mean(all_results$minimax_width)))
cat(sprintf("  Difference:             %.4f\n",
            mean(all_results$minimax_width) - mean(all_results$method_ci_width)))

cat("\n")
cat("Interpretation:\n")

minimax_coverage <- mean(all_results$minimax_contains_true)
method_coverage <- mean(all_results$method_contains_true)

if (minimax_coverage >= 0.99) {
  cat("✓ EXCELLENT: Minimax bounds achieve near-perfect coverage (≥99%)\n")
  cat("  → Bounds hold as theoretically guaranteed\n")
} else if (minimax_coverage >= 0.95) {
  cat("✓ GOOD: Minimax bounds achieve nominal coverage (≥95%)\n")
  cat("  → Bounds provide robust inference\n")
} else {
  cat("✗ ISSUE: Minimax coverage below 95%\n")
  cat("  → May need broader class M or more grid points\n")
}

cat("\n")

mean_ratio <- mean(all_results$width_ratio)
if (mean_ratio <= 1.5) {
  cat(sprintf("✓ ACCEPTABLE COST: Minimax bounds only %.1fx wider\n", mean_ratio))
  cat("  → Small price for guaranteed coverage\n")
} else if (mean_ratio <= 2.5) {
  cat(sprintf("~ MODERATE COST: Minimax bounds %.1fx wider\n", mean_ratio))
  cat("  → Trade-off between robustness and precision\n")
} else {
  cat(sprintf("✗ HIGH COST: Minimax bounds %.1fx wider\n", mean_ratio))
  cat("  → May limit practical utility\n")
}

cat("\n")
cat("----------------------------------------------------------------\n")
cat("Creating Visualizations\n")
cat("----------------------------------------------------------------\n\n")

if (!dir.exists("sims/results")) {
  dir.create("sims/results", recursive = TRUE)
}

# Plot 1: Coverage comparison
coverage_plot_data <- coverage_summary %>%
  tidyr::pivot_longer(
    cols = c(method_coverage, minimax_coverage),
    names_to = "method",
    values_to = "coverage"
  ) %>%
  mutate(
    method = ifelse(method == "method_coverage", "Standard Method", "Minimax Bounds")
  )

p1 <- ggplot(coverage_plot_data, aes(x = scenario, y = coverage, fill = method)) +
  geom_col(position = "dodge", alpha = 0.8) +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "red") +
  geom_text(aes(label = sprintf("%.1f%%", coverage * 100)),
            position = position_dodge(width = 0.9),
            vjust = -0.5, size = 3) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1.05)) +
  labs(
    title = "Coverage Comparison: Standard Method vs. Minimax Bounds",
    subtitle = sprintf("Target: 95%% (red line) | N=%d replications per scenario", N_REPLICATIONS),
    x = "Scenario",
    y = "Coverage Rate",
    fill = "Method"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave("sims/results/minimax_coverage_comparison.png", p1,
       width = 10, height = 6, dpi = 300)
cat("  Saved: sims/results/minimax_coverage_comparison.png\n")

# Plot 2: Width comparison
p2 <- ggplot(all_results, aes(x = scenario, y = width_ratio)) +
  geom_violin(fill = "skyblue", alpha = 0.5) +
  geom_boxplot(width = 0.2, alpha = 0.7) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "red") +
  stat_summary(fun = mean, geom = "point", shape = 23, size = 3,
               fill = "red", color = "darkred") +
  labs(
    title = "Width Ratio: Minimax Bounds / Standard Method CI",
    subtitle = "Red line = equal width; Red diamond = mean ratio per scenario",
    x = "Scenario",
    y = "Width Ratio (Minimax / Method)"
  ) +
  theme_minimal()

ggsave("sims/results/minimax_width_ratio.png", p2,
       width = 10, height = 6, dpi = 300)
cat("  Saved: sims/results/minimax_width_ratio.png\n")

# Plot 3: Side-by-side intervals for sample replications
sample_data <- all_results %>%
  filter(scenario == "Moderate λ=0.3") %>%
  slice_head(n = 30) %>%
  mutate(rep_id = row_number())

p3 <- ggplot(sample_data) +
  # True value
  geom_point(aes(x = rep_id, y = true_phi),
             color = "black", size = 2, shape = 4) +
  # Standard method CI
  geom_pointrange(aes(x = rep_id - 0.15, y = method_estimate,
                      ymin = method_ci_lower, ymax = method_ci_upper),
                  color = "blue", alpha = 0.6, size = 0.3) +
  # Minimax bounds
  geom_errorbar(aes(x = rep_id + 0.15,
                    ymin = minimax_lower, ymax = minimax_upper),
                color = "red", alpha = 0.6, width = 0.3, linewidth = 0.8) +
  labs(
    title = "Interval Comparison for Moderate λ=0.3 (First 30 Replications)",
    subtitle = "Black X = TRUE φ(F_λ) | Blue = Standard Method CI | Red = Minimax Bounds",
    x = "Replication",
    y = "Correlation",
    caption = "Both intervals should contain the true value (black X)"
  ) +
  theme_minimal()

ggsave("sims/results/minimax_intervals_sample.png", p3,
       width = 12, height = 6, dpi = 300)
cat("  Saved: sims/results/minimax_intervals_sample.png\n")

# Save results
saveRDS(all_results, "sims/results/minimax_validation_detailed.rds")
cat("\n  Saved: sims/results/minimax_validation_detailed.rds\n")

cat("\n")
cat("================================================================\n")
cat("PAPER IMPLICATIONS\n")
cat("================================================================\n\n")

if (minimax_coverage >= 0.99 && mean_ratio <= 2.0) {
  cat("Key Finding:\n")
  cat(sprintf("  Minimax bounds achieve %.1f%% coverage (vs. %.1f%% for\n",
              minimax_coverage * 100, method_coverage * 100))
  cat("  standard method), validating the theoretical guarantee.\n")
  cat(sprintf("  The cost is a %.1fx increase in interval width,\n", mean_ratio))
  cat("  which is acceptable for guaranteed robustness.\n\n")

  cat("Paper Claim:\n")
  cat("  'We validated that minimax bounds provide guaranteed coverage:\n")
  cat(sprintf("   across %d baseline studies and 3 λ values, minimax bounds\n",
              nrow(all_results)))
  cat(sprintf("   contained the true φ(F_λ) in %.1f%% of cases, compared\n",
              minimax_coverage * 100))
  cat(sprintf("   to %.1f%% for the standard method assuming μ known.\n",
              method_coverage * 100))
  cat(sprintf("   The %.1fx width increase is a small price for\n", mean_ratio))
  cat("   eliminating μ-misspecification risk.'\n")
} else if (minimax_coverage >= 0.95) {
  cat("Finding:\n")
  cat("  Minimax bounds achieve nominal coverage with acceptable width cost.\n")
  cat("  This validates the minimax approach for robust inference.\n")
} else {
  cat("Finding:\n")
  cat("  Minimax coverage below target. Consider:\n")
  cat("    - Increasing n_dirichlet_grid for finer search\n")
  cat("    - Expanding alpha range beyond [0.01, 100]\n")
  cat("    - Adding more vertex evaluations\n")
}

cat("\n")
cat("================================================================\n")
cat("Validation complete!\n")
cat("================================================================\n")
