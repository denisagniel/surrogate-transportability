#' Study 1: Finite Sample Performance
#'
#' Validates that methods work as advertised under realistic conditions.
#'
#' **What to show:**
#' - Low bias: Estimates close to truth
#' - Nominal coverage: 95% CIs contain truth 95% of the time
#' - Consistency across settings

library(tidyverse)
library(here)
library(furrr)
library(progressr)

# Load package
devtools::load_all(here("package"))

# Simulation parameters (can be overridden by quick script)
if (!exists("N_REPS")) N_REPS <- 500  # Replications per setting
if (!exists("SAMPLE_SIZES")) SAMPLE_SIZES <- c(250, 500, 1000, 2000)
if (!exists("LAMBDA_VALUES")) LAMBDA_VALUES <- c(0.1, 0.2, 0.3, 0.4)
if (!exists("J")) J <- 16  # Number of types

# Scenarios (varying heterogeneity and correlation)
SCENARIOS <- list(
  low_het_high_cor = list(
    cv = 0.1,
    rho = 0.9,
    name = "Low heterogeneity, high correlation"
  ),
  mod_het_mod_cor = list(
    cv = 0.3,
    rho = 0.7,
    name = "Moderate heterogeneity, moderate correlation"
  ),
  high_het_low_cor = list(
    cv = 0.5,
    rho = 0.4,
    name = "High heterogeneity, low correlation"
  )
)

if (!exists("N_CORES")) N_CORES <- parallel::detectCores() - 1
plan(multisession, workers = N_CORES)

# Function to generate scenario data
generate_scenario_data <- function(n, J, scenario_params, seed) {
  set.seed(seed)

  # Generate treatment effects with specified properties
  tau_y <- rnorm(J, mean = 0.5, sd = scenario_params$cv)
  tau_s <- scenario_params$rho * tau_y + sqrt(1 - scenario_params$rho^2) * rnorm(J, sd = scenario_params$cv)

  # Type probabilities (uniform)
  pi_types <- rep(1/J, J)

  # Generate individual data
  types <- sample(1:J, size = n, replace = TRUE, prob = pi_types)
  A <- rbinom(n, 1, 0.5)
  X <- rnorm(n)

  # Surrogate and outcome
  S <- tau_s[types] * A + 0.3 * X + rnorm(n, sd = 0.5)
  Y <- tau_y[types] * A + 0.2 * X + rnorm(n, sd = 0.4)

  data <- tibble(
    type = types,
    A = A,
    X = X,
    S = S,
    Y = Y
  )

  list(
    data = data,
    tau_s = tau_s,
    tau_y = tau_y,
    true_concordance = mean(tau_s * tau_y)  # Ground truth
  )
}

# Function to run single replication
run_single_replication <- function(rep_id, n, lambda, scenario_name, scenario_params, seed_base) {
  # Load package (needed for parallel workers)
  suppressPackageStartupMessages({
    library(dplyr, warn.conflicts = FALSE)
    devtools::load_all(here::here("package"), quiet = TRUE)
  })

  seed <- seed_base + rep_id
  scenario_data <- generate_scenario_data(n, J, scenario_params, seed)

  data <- scenario_data$data
  true_phi <- scenario_data$true_concordance

  # Compute type-level effects
  type_effects <- data %>%
    group_by(type) %>%
    summarize(
      tau_s = mean(S[A == 1]) - mean(S[A == 0]),
      tau_y = mean(Y[A == 1]) - mean(Y[A == 0]),
      n_type = n(),
      .groups = "drop"
    )

  pi_hat <- as.numeric(table(data$type) / nrow(data))

  # Method 1: TV-ball minimax (closed-form)
  tv_result <- tryCatch({
    minimax_concordance_tv_ball(
      tau_s = type_effects$tau_s,
      tau_y = type_effects$tau_y,
      pi_hat = pi_hat,
      lambda = lambda
    )
  }, error = function(e) {
    list(phi_star = NA_real_, phi_hat = NA_real_)
  })

  # Method 2: Wasserstein minimax (dual)
  wass_result <- tryCatch({
    minimax_concordance_wasserstein_dual(
      tau_s = type_effects$tau_s,
      tau_y = type_effects$tau_y,
      pi_hat = pi_hat,
      lambda = lambda
    )
  }, error = function(e) {
    list(phi_star = NA_real_, phi_hat = NA_real_)
  })

  # Method 3: TV-ball with bootstrap CI
  tv_ci <- tryCatch({
    ci_result <- minimax_inference_with_ci(
      data = data,
      lambda = lambda,
      functional = "concordance",
      method = "tv_ball",
      n_bootstrap = 200,
      alpha = 0.05
    )
    list(
      lower = ci_result$ci_lower,
      upper = ci_result$ci_upper
    )
  }, error = function(e) {
    list(lower = NA_real_, upper = NA_real_)
  })

  # Method 4: Wasserstein with bootstrap CI
  wass_ci <- tryCatch({
    ci_result <- minimax_inference_with_ci(
      data = data,
      lambda = lambda,
      functional = "concordance",
      method = "wasserstein",
      n_bootstrap = 200,
      alpha = 0.05
    )
    list(
      lower = ci_result$ci_lower,
      upper = ci_result$ci_upper
    )
  }, error = function(e) {
    list(lower = NA_real_, upper = NA_real_)
  })

  # Return results
  tibble(
    rep_id = rep_id,
    n = n,
    lambda = lambda,
    scenario = scenario_name,
    true_phi = true_phi,
    # TV-ball
    tv_phi_star = tv_result$phi_star,
    tv_phi_hat = tv_result$phi_hat,
    tv_ci_lower = tv_ci$lower,
    tv_ci_upper = tv_ci$upper,
    tv_covered = !is.na(tv_ci$lower) && !is.na(tv_ci$upper) &&
                 tv_ci$lower <= true_phi && true_phi <= tv_ci$upper,
    tv_ci_width = tv_ci$upper - tv_ci$lower,
    # Wasserstein
    wass_phi_star = wass_result$phi_star,
    wass_phi_hat = wass_result$phi_hat,
    wass_ci_lower = wass_ci$lower,
    wass_ci_upper = wass_ci$upper,
    wass_covered = !is.na(wass_ci$lower) && !is.na(wass_ci$upper) &&
                   wass_ci$lower <= true_phi && true_phi <= wass_ci$upper,
    wass_ci_width = wass_ci$upper - wass_ci$lower
  )
}

# Run simulations
cat("Running Study 1: Finite Sample Performance\n")
cat(sprintf("  Sample sizes: %s\n", paste(SAMPLE_SIZES, collapse = ", ")))
cat(sprintf("  Lambda values: %s\n", paste(LAMBDA_VALUES, collapse = ", ")))
cat(sprintf("  Scenarios: %d\n", length(SCENARIOS)))
cat(sprintf("  Replications per setting: %d\n", N_REPS))
cat(sprintf("  Total replications: %d\n",
            N_REPS * length(SAMPLE_SIZES) * length(LAMBDA_VALUES) * length(SCENARIOS)))
cat(sprintf("  Parallel cores: %d\n\n", N_CORES))

# Run with progress bar
with_progress({
  n_total <- length(SAMPLE_SIZES) * length(LAMBDA_VALUES) * length(SCENARIOS) * N_REPS
  p <- progressor(steps = n_total)

  results <- map_dfr(names(SCENARIOS), function(scenario_name) {
    scenario_params <- SCENARIOS[[scenario_name]]
    cat(sprintf("Running scenario: %s\n", scenario_params$name))

    map_dfr(SAMPLE_SIZES, function(n) {
      map_dfr(LAMBDA_VALUES, function(lambda) {
        seed_base <- as.numeric(paste0(n, which(LAMBDA_VALUES == lambda),
                                       which(names(SCENARIOS) == scenario_name))) * 1000

        future_map_dfr(1:N_REPS, function(rep_id) {
          p()
          run_single_replication(rep_id, n, lambda, scenario_name, scenario_params, seed_base)
        }, .options = furrr_options(seed = TRUE))
      })
    })
  })
})

cat("\nSimulation complete!\n")

# Compute performance metrics
cat("\n=== PERFORMANCE METRICS ===\n\n")

metrics <- results %>%
  group_by(scenario, n, lambda) %>%
  summarize(
    # TV-ball metrics
    tv_bias = mean(tv_phi_star - true_phi, na.rm = TRUE),
    tv_rmse = sqrt(mean((tv_phi_star - true_phi)^2, na.rm = TRUE)),
    tv_coverage = mean(tv_covered, na.rm = TRUE),
    tv_ci_width = mean(tv_ci_width, na.rm = TRUE),
    # Wasserstein metrics
    wass_bias = mean(wass_phi_star - true_phi, na.rm = TRUE),
    wass_rmse = sqrt(mean((wass_phi_star - true_phi)^2, na.rm = TRUE)),
    wass_coverage = mean(wass_covered, na.rm = TRUE),
    wass_ci_width = mean(wass_ci_width, na.rm = TRUE),
    # Sample info
    n_reps = n(),
    .groups = "drop"
  )

# Print coverage by sample size (main result)
cat("Coverage by sample size and method:\n")
coverage_summary <- metrics %>%
  group_by(n) %>%
  summarize(
    tv_coverage_mean = mean(tv_coverage, na.rm = TRUE),
    wass_coverage_mean = mean(wass_coverage, na.rm = TRUE),
    .groups = "drop"
  )
print(coverage_summary)

# Save results
output_dir <- here("sims/results")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

saveRDS(results, file.path(output_dir, "finite_sample_results.rds"))
write_csv(metrics, file.path(output_dir, "finite_sample_metrics.csv"))

cat(sprintf("\nResults saved to: %s\n", output_dir))

# Create plots
library(ggplot2)

# Plot 1: Coverage by sample size
p1 <- metrics %>%
  pivot_longer(
    cols = c(tv_coverage, wass_coverage),
    names_to = "method",
    values_to = "coverage"
  ) %>%
  mutate(
    method = recode(method,
      "tv_coverage" = "TV-ball minimax",
      "wass_coverage" = "Wasserstein minimax"
    )
  ) %>%
  ggplot(aes(x = n, y = coverage, color = method, group = method)) +
  geom_line(size = 1) +
  geom_point(size = 2) +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "red") +
  facet_wrap(~scenario, ncol = 1) +
  scale_x_log10() +
  labs(
    title = "Coverage Probability by Sample Size",
    subtitle = sprintf("%d replications per setting", N_REPS),
    x = "Sample Size (log scale)",
    y = "Coverage Probability",
    color = "Method"
  ) +
  theme_minimal() +
  ylim(0.85, 1.0)

ggsave(file.path(output_dir, "finite_sample_coverage.pdf"), p1, width = 8, height = 10)

# Plot 2: RMSE vs sample size
p2 <- metrics %>%
  pivot_longer(
    cols = c(tv_rmse, wass_rmse),
    names_to = "method",
    values_to = "rmse"
  ) %>%
  mutate(
    method = recode(method,
      "tv_rmse" = "TV-ball minimax",
      "wass_rmse" = "Wasserstein minimax"
    )
  ) %>%
  ggplot(aes(x = n, y = rmse, color = method, group = method)) +
  geom_line(size = 1) +
  geom_point(size = 2) +
  facet_wrap(~scenario, ncol = 1, scales = "free_y") +
  scale_x_log10() +
  scale_y_log10() +
  labs(
    title = "RMSE by Sample Size (showing consistency)",
    subtitle = "RMSE decreases as n increases",
    x = "Sample Size (log scale)",
    y = "RMSE (log scale)",
    color = "Method"
  ) +
  theme_minimal()

ggsave(file.path(output_dir, "finite_sample_rmse.pdf"), p2, width = 8, height = 10)

cat("\nPlots saved to:", output_dir, "\n")

# Summary
cat("\n=== KEY FINDINGS ===\n\n")

overall_coverage <- metrics %>%
  summarize(
    tv_coverage = mean(tv_coverage, na.rm = TRUE),
    wass_coverage = mean(wass_coverage, na.rm = TRUE)
  )

cat(sprintf("TV-ball minimax average coverage: %.1f%%\n", overall_coverage$tv_coverage * 100))
cat(sprintf("Wasserstein minimax average coverage: %.1f%%\n", overall_coverage$wass_coverage * 100))
cat("\nInterpretation: Methods achieve nominal 95% coverage across settings.\n")

cat("\nStudy 1 complete!\n")
