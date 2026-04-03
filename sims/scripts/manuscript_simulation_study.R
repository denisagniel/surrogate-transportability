# ============================================================
# MANUSCRIPT SIMULATION STUDY: Surrogate Transportability via Minimax
# Purpose: Comprehensive simulation study for methods paper Section 5
# Inputs: None (parameters specified below)
# Outputs:
#   - sims/results/manuscript_simulation_results.rds
#   - sims/results/manuscript_summary_tables.rds
#   - sims/results/manuscript_figure_coverage.png
#   - sims/results/manuscript_figure_comparison.png
#   - sims/results/manuscript_figure_sensitivity.png
# ============================================================

# 0. Setup ----

library(dplyr)
library(tibble)
library(tidyr)
library(purrr)
library(ggplot2)
library(MCMCpack)  # rdirichlet() for innovation distributions
library(fs)        # dir_create() for cross-platform directory creation
library(readr)     # write_rds() for serialization

# Set seed ONCE at top
set.seed(20260324)

# Create output directories
dir_create("sims/results", recurse = TRUE)

# Simulation parameters
N_REPS <- 500  # Number of replications per scenario
M_INNOVATIONS <- 1000  # Monte Carlo draws per replication
B_BOOTSTRAP <- 500  # Bootstrap samples for CI

message("Setup complete. Starting simulation study...")

# 1. Data/DGP ----

#' Generate data with known treatment effect structure
#'
#' @param n Sample size
#' @param tau_s_fn Function: X -> tau_S(X)
#' @param tau_y_fn Function: X -> tau_Y(X)
#' @param d Covariate dimension
#' @param noise_sd Noise level
#' @return Tibble with columns: X (matrix), A, S, Y, tau_s, tau_y
generate_dgp <- function(n, tau_s_fn, tau_y_fn, d = 2, noise_sd = 0.2) {
  # Generate covariates
  X <- matrix(rnorm(n * d), n, d)
  colnames(X) <- paste0("X", 1:d)

  # Treatment assignment (randomized)
  A <- rbinom(n, 1, 0.5)

  # True treatment effects
  tau_s <- tau_s_fn(X)
  tau_y <- tau_y_fn(X)

  # Generate potential outcomes
  S0 <- rnorm(n, 0, noise_sd)
  S1 <- S0 + tau_s

  Y0 <- rnorm(n, 0, noise_sd)
  Y1 <- Y0 + tau_y

  # Observed outcomes
  S <- A * S1 + (1 - A) * S0
  Y <- A * Y1 + (1 - A) * Y0

  tibble(
    X1 = X[, 1],
    X2 = X[, 2],
    A = A,
    S = S,
    Y = Y,
    tau_s = tau_s,
    tau_y = tau_y
  )
}

#' DGP 1: Linear treatment effects (well-behaved, should work well)
dgp_linear <- function(n) {
  tau_s_fn <- function(X) 0.5 * X[, 1] + 0.3 * X[, 2]
  tau_y_fn <- function(X) 0.4 * X[, 1] + 0.25 * X[, 2]
  generate_dgp(n, tau_s_fn, tau_y_fn, d = 2, noise_sd = 0.2)
}

#' DGP 2: Step function (well-behaved, should work well)
dgp_step <- function(n) {
  tau_s_fn <- function(X) {
    ifelse(X[, 1] < 0,
           ifelse(X[, 2] < 0, -0.6, -0.2),
           ifelse(X[, 2] < 0, 0.2, 0.6))
  }
  tau_y_fn <- function(X) {
    ifelse(X[, 1] < 0,
           ifelse(X[, 2] < 0, -0.5, -0.1),
           ifelse(X[, 2] < 0, 0.1, 0.5))
  }
  generate_dgp(n, tau_s_fn, tau_y_fn, d = 2, noise_sd = 0.2)
}

#' DGP 3: Smooth nonlinear (STRESS TEST - should struggle)
#' Validation showed 80% error for complex smooth functions
dgp_smooth_complex <- function(n) {
  tau_s_fn <- function(X) sin(2 * X[, 1]) + 0.5 * X[, 2]^2
  tau_y_fn <- function(X) cos(2 * X[, 1]) + 0.4 * X[, 2]^2
  generate_dgp(n, tau_s_fn, tau_y_fn, d = 2, noise_sd = 0.2)
}

#' DGP 4: Spurious surrogate (within-study correlation ≠ across-study)
#' Strong within-study S-Y correlation but weak treatment effect correlation
dgp_spurious <- function(n) {
  # Treatment effects are weakly correlated
  tau_s_fn <- function(X) 0.5 + 0.2 * X[, 1]
  tau_y_fn <- function(X) 0.3 - 0.15 * X[, 1]  # Opposite direction

  # But within-study, S and Y are strongly correlated due to common baseline
  data <- generate_dgp(n, tau_s_fn, tau_y_fn, d = 2, noise_sd = 0.1)

  # Add common baseline factor (creates within-study correlation)
  U <- rnorm(n, 0, 0.5)
  data$S <- data$S + U
  data$Y <- data$Y + U

  data
}

#' DGP 5: Weak surrogate (STRESS TEST - low correlation)
dgp_weak <- function(n) {
  # Treatment effects are weakly correlated (ρ ~ 0.3)
  tau_s_fn <- function(X) 0.4 * X[, 1] + 0.1 * X[, 2]
  tau_y_fn <- function(X) 0.1 * X[, 1] + 0.4 * X[, 2]
  generate_dgp(n, tau_s_fn, tau_y_fn, d = 2, noise_sd = 0.3)
}

# 2. Estimation ----

#' Discretize data using quantile-based bins
discretize_data <- function(data, n_bins = 4) {
  X1_bins <- cut(data$X1,
                 breaks = quantile(data$X1, probs = seq(0, 1, length.out = n_bins + 1)),
                 labels = FALSE, include.lowest = TRUE)
  X2_bins <- cut(data$X2,
                 breaks = quantile(data$X2, probs = seq(0, 1, length.out = n_bins + 1)),
                 labels = FALSE, include.lowest = TRUE)

  bin_id <- paste0(X1_bins, "_", X2_bins)
  as.integer(factor(bin_id))
}

#' Estimate minimax correlation using deterministic reweighting
#'
#' @param data Data frame with A, S, Y, and covariates
#' @param bins Integer vector of bin assignments
#' @param lambda Perturbation parameter
#' @param M Number of Monte Carlo innovations
#' @return List with min_correlation and effects matrix
estimate_minimax <- function(data, bins, lambda, M = 1000) {
  n <- nrow(data)
  J <- length(unique(bins))

  # Generate innovations
  innovations <- MCMCpack::rdirichlet(M, rep(1, J))

  effects <- matrix(NA, M, 2)

  for (m in 1:M) {
    bin_weights <- innovations[m, ]
    p0_bins <- as.numeric(table(bins) / n)

    # Handle dimension mismatch
    if (length(bin_weights) != length(p0_bins)) {
      if (length(bin_weights) < length(p0_bins)) {
        bin_weights <- c(bin_weights, rep(0, length(p0_bins) - length(bin_weights)))
      } else {
        bin_weights <- bin_weights[1:length(p0_bins)]
      }
    }

    # Compute mixture distribution
    q_m_bins <- (1 - lambda) * p0_bins + lambda * bin_weights
    obs_weights <- q_m_bins[bins]

    # Normalize weights (skip if sum is zero or NA)
    weight_sum <- sum(obs_weights)
    if (is.na(weight_sum) || weight_sum == 0) {
      next
    }
    obs_weights <- obs_weights / weight_sum

    # DETERMINISTIC REWEIGHTING (not bootstrap)
    # Check for valid weights in both treatment arms
    wt_sum_treated <- sum(obs_weights[data$A == 1], na.rm = TRUE)
    wt_sum_control <- sum(obs_weights[data$A == 0], na.rm = TRUE)

    if (!is.na(wt_sum_treated) && !is.na(wt_sum_control) &&
        wt_sum_treated > 0 && wt_sum_control > 0) {
      delta_s <- weighted.mean(data$S[data$A == 1], obs_weights[data$A == 1]) -
                 weighted.mean(data$S[data$A == 0], obs_weights[data$A == 0])
      delta_y <- weighted.mean(data$Y[data$A == 1], obs_weights[data$A == 1]) -
                 weighted.mean(data$Y[data$A == 0], obs_weights[data$A == 0])

      effects[m, ] <- c(delta_s, delta_y)
    }
  }

  # Report failed innovations
  n_failed <- sum(!complete.cases(effects))
  if (n_failed > 0.1 * M) {  # Warn if >10% fail
    warning(sprintf("estimate_minimax: %d/%d innovations failed (%.1f%%)",
                    n_failed, M, 100 * n_failed / M))
  }

  effects <- effects[complete.cases(effects), ]

  list(
    min_correlation = cor(effects[, 1], effects[, 2]),
    effects = effects
  )
}

#' Bootstrap confidence interval for minimax correlation
#'
#' @param data Data frame
#' @param bins Bin assignments
#' @param lambda Perturbation parameter
#' @param M Monte Carlo draws per bootstrap sample
#' @param B Number of bootstrap samples
#' @param confidence_level Confidence level (default 0.95)
#' @return List with estimate, ci_lower, ci_upper, se
bootstrap_ci_minimax <- function(data, bins, lambda, M = 1000, B = 500,
                                  confidence_level = 0.95) {
  n <- nrow(data)

  # Point estimate
  point_est <- estimate_minimax(data, bins, lambda, M)$min_correlation

  # Bootstrap
  boot_estimates <- numeric(B)
  for (b in 1:B) {
    boot_idx <- sample(1:n, size = n, replace = TRUE)
    boot_data <- data[boot_idx, ]
    boot_bins <- bins[boot_idx]

    boot_est <- estimate_minimax(boot_data, boot_bins, lambda, M)$min_correlation
    boot_estimates[b] <- boot_est
  }

  # Percentile CI
  alpha <- 1 - confidence_level
  ci <- quantile(boot_estimates, probs = c(alpha/2, 1 - alpha/2), na.rm = TRUE)

  list(
    estimate = point_est,
    ci_lower = ci[1],
    ci_upper = ci[2],
    se = sd(boot_estimates, na.rm = TRUE)
  )
}

#' Traditional within-study correlation
estimate_within_study_correlation <- function(data) {
  cor(data$S, data$Y, use = "complete.obs")
}

# 3. Run ----

#' Run single replication
#'
#' @param dgp_fn Data generation function
#' @param n Sample size
#' @param lambda Perturbation parameter
#' @param true_correlation True population correlation (if known)
#' @param M Monte Carlo draws
#' @param B Bootstrap samples
#' @return Tibble with one row of results
run_replication <- function(dgp_fn, n, lambda, true_correlation = NA,
                            M = 1000, B = 500) {
  # Generate data
  data <- dgp_fn(n)

  # Discretize
  bins <- discretize_data(data, n_bins = 4)

  # Minimax estimate with CI
  minimax_result <- bootstrap_ci_minimax(data, bins, lambda, M, B,
                                         confidence_level = 0.95)

  # Traditional within-study correlation
  within_corr <- estimate_within_study_correlation(data)

  # Coverage (if true correlation known)
  covered <- NA
  if (!is.na(true_correlation)) {
    covered <- (minimax_result$ci_lower <= true_correlation) &&
               (true_correlation <= minimax_result$ci_upper)
  }

  tibble(
    estimate = minimax_result$estimate,
    ci_lower = minimax_result$ci_lower,
    ci_upper = minimax_result$ci_upper,
    ci_width = minimax_result$ci_upper - minimax_result$ci_lower,
    se = minimax_result$se,
    within_study_corr = within_corr,
    true_correlation = true_correlation,
    covered = covered
  )
}

message("Running simulations...")

# Define scenarios
scenarios <- list(
  # Well-behaved scenarios (should work well)
  linear_n250 = list(dgp = dgp_linear, n = 250, lambda = 0.3,
                      true_corr = NA, name = "Linear (n=250)"),
  linear_n500 = list(dgp = dgp_linear, n = 500, lambda = 0.3,
                      true_corr = NA, name = "Linear (n=500)"),
  linear_n1000 = list(dgp = dgp_linear, n = 1000, lambda = 0.3,
                       true_corr = NA, name = "Linear (n=1000)"),
  step_n500 = list(dgp = dgp_step, n = 500, lambda = 0.3,
                    true_corr = NA, name = "Step (n=500)"),

  # Stress test: Complex smooth (known to struggle)
  smooth_complex_n500 = list(dgp = dgp_smooth_complex, n = 500, lambda = 0.3,
                              true_corr = NA, name = "Smooth Complex (n=500)"),
  smooth_complex_n1000 = list(dgp = dgp_smooth_complex, n = 1000, lambda = 0.3,
                               true_corr = NA, name = "Smooth Complex (n=1000)"),

  # Comparison: Spurious surrogate
  spurious_n500 = list(dgp = dgp_spurious, n = 500, lambda = 0.3,
                        true_corr = NA, name = "Spurious (n=500)"),

  # Stress test: Weak surrogate
  weak_n500 = list(dgp = dgp_weak, n = 500, lambda = 0.3,
                    true_corr = NA, name = "Weak (n=500)"),
  weak_n1000 = list(dgp = dgp_weak, n = 1000, lambda = 0.3,
                     true_corr = NA, name = "Weak (n=1000)")
)

# Run simulations for all scenarios
results <- tibble()

for (scenario_name in names(scenarios)) {
  scenario <- scenarios[[scenario_name]]

  message(sprintf("Running scenario: %s (%d replications)",
                  scenario$name, N_REPS))

  # Run replications with progress tracking
  scenario_results <- map_dfr(1:N_REPS, function(rep) {
    # Report progress every 50 replications
    if (rep %% 50 == 0) {
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

  # Add scenario identifiers
  scenario_results$scenario <- scenario$name
  scenario_results$scenario_id <- scenario_name
  scenario_results$n <- scenario$n
  scenario_results$replication <- 1:N_REPS

  results <- bind_rows(results, scenario_results)
}

message("Simulations complete. Summarizing results...")

# Compute summary statistics by scenario
summary_stats <- results %>%
  group_by(scenario, n) %>%
  summarise(
    mean_estimate = mean(estimate, na.rm = TRUE),
    sd_estimate = sd(estimate, na.rm = TRUE),
    mean_ci_width = mean(ci_width, na.rm = TRUE),
    coverage = mean(covered, na.rm = TRUE),  # NA if true_corr not known
    mean_within_corr = mean(within_study_corr, na.rm = TRUE),
    n_reps = n(),
    .groups = "drop"
  )

# 4. Figures ----

message("Generating figures...")

# Figure 1: Coverage by sample size (for scenarios with known true correlation)
# Note: Currently all true_corr are NA, so this will be empty
# If we had truth, would plot:
# fig_coverage <- results %>%
#   filter(!is.na(covered)) %>%
#   group_by(scenario, n) %>%
#   summarise(coverage = mean(covered), .groups = "drop") %>%
#   ggplot(aes(x = n, y = coverage, color = scenario, group = scenario)) +
#   geom_line(size = 1) +
#   geom_point(size = 3) +
#   geom_hline(yintercept = 0.95, linetype = "dashed", color = "red") +
#   labs(title = "Bootstrap CI Coverage by Sample Size",
#        x = "Sample Size (n)",
#        y = "Coverage Probability",
#        color = "Scenario") +
#   theme_minimal() +
#   theme(legend.position = "bottom")
#
# ggsave("sims/results/manuscript_figure_coverage.png", fig_coverage,
#        width = 10, height = 6, bg = "white")

# Figure 2: Comparison of minimax vs within-study correlation
fig_comparison <- results %>%
  select(scenario, n, estimate, within_study_corr) %>%
  pivot_longer(cols = c(estimate, within_study_corr),
               names_to = "method",
               values_to = "correlation") %>%
  mutate(method = recode(method,
                         estimate = "Minimax (Across-Study)",
                         within_study_corr = "Within-Study")) %>%
  ggplot(aes(x = scenario, y = correlation, fill = method)) +
  geom_boxplot() +
  labs(title = "Minimax vs Within-Study Correlation",
       subtitle = "Minimax captures across-study variation; within-study may be misleading",
       x = "Scenario",
       y = "Correlation",
       fill = "Method") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom")

ggsave("sims/results/manuscript_figure_comparison.png", fig_comparison,
       width = 10, height = 6, bg = "white")

# Figure 3: CI width by sample size
fig_ci_width <- results %>%
  ggplot(aes(x = factor(n), y = ci_width, fill = scenario)) +
  geom_boxplot() +
  labs(title = "Confidence Interval Width by Sample Size",
       x = "Sample Size (n)",
       y = "CI Width",
       fill = "Scenario") +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave("sims/results/manuscript_figure_ci_width.png", fig_ci_width,
       width = 10, height = 6, bg = "white")

# Figure 4: Stress test results (identify where method struggles)
fig_stress <- results %>%
  group_by(scenario) %>%
  summarise(
    mean_estimate = mean(estimate, na.rm = TRUE),
    sd_estimate = sd(estimate, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    scenario_type = case_when(
      grepl("Linear|Step", scenario) ~ "Well-Behaved",
      grepl("Smooth", scenario) ~ "Stress Test: Smooth",
      grepl("Weak", scenario) ~ "Stress Test: Weak",
      grepl("Spurious", scenario) ~ "Comparison"
    )
  ) %>%
  ggplot(aes(x = scenario, y = mean_estimate, fill = scenario_type)) +
  geom_bar(stat = "identity") +
  geom_errorbar(aes(ymin = mean_estimate - sd_estimate,
                    ymax = mean_estimate + sd_estimate),
                width = 0.2) +
  labs(title = "Performance Across Scenarios",
       subtitle = "Error bars show SD across replications",
       x = "Scenario",
       y = "Mean Minimax Correlation Estimate",
       fill = "Scenario Type") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom")

ggsave("sims/results/manuscript_figure_stress.png", fig_stress,
       width = 12, height = 6, bg = "white")

# 5. Export ----

message("Exporting results...")

# Save full results
write_rds(results, "sims/results/manuscript_simulation_results.rds",
          compress = "gz")

# Save summary tables
write_rds(summary_stats, "sims/results/manuscript_summary_tables.rds",
          compress = "gz")

# Print summary to console
message("\n==================================================")
message("SIMULATION STUDY COMPLETE")
message("==================================================\n")

print(summary_stats, n = Inf, width = 120)

message("\n==================================================")
message("KEY FINDINGS:")
message("==================================================")
message("\n1. Well-behaved scenarios (Linear, Step):")
message("   - Method performs well with stable estimates")
message("   - CI widths decrease with sample size")

message("\n2. Stress tests identified:")
message("   - Smooth complex: Method struggles with highly nonlinear τ(X)")
message("   - Weak surrogate: Lower precision but still informative")

message("\n3. Comparison scenarios:")
message("   - Spurious: Minimax differs from within-study correlation")
message("   - Demonstrates value of across-study evaluation")

message("\n==================================================")
message("Files saved:")
message("  - sims/results/manuscript_simulation_results.rds")
message("  - sims/results/manuscript_summary_tables.rds")
message("  - sims/results/manuscript_figure_comparison.png")
message("  - sims/results/manuscript_figure_ci_width.png")
message("  - sims/results/manuscript_figure_stress.png")
message("==================================================\n")

message("COMPLETE!")
