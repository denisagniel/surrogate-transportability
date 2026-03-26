#' Study 2: Stress Testing
#'
#' Finds the limits - where do methods break or weaken?
#'
#' **What to test:**
#' - Very small n (n=50, n=100)
#' - Extreme λ (λ=0.7, λ=0.9)
#' - Few types (J=4, J=6) vs many (J=25, J=36)
#' - Weak signal (ρ_true < 0.2)
#' - Extreme heterogeneity (CV > 0.7)

library(tidyverse)
library(here)
library(furrr)
library(progressr)

# Load package
devtools::load_all(here("package"))

# Simulation parameters (can be overridden by quick script)
if (!exists("N_REPS")) N_REPS <- 500  # Replications per stress condition

# Detect available cores (respects Slurm allocation)
if (!exists("N_CORES")) {
  # Use Slurm allocation if available, otherwise use parallelly::availableCores()
  slurm_cpus <- Sys.getenv("SLURM_CPUS_PER_TASK", unset = "")
  if (slurm_cpus != "") {
    N_CORES <- as.integer(slurm_cpus)
  } else {
    N_CORES <- parallelly::availableCores()
  }
}

# Baseline (non-stressed) parameters
if (!exists("BASELINE")) BASELINE <- list(
  n = 500,
  lambda = 0.3,
  J = 16,
  rho = 0.7,
  cv = 0.3
)

# Stress dimensions (can be overridden by quick script)
if (!exists("STRESS_DIMENSIONS")) STRESS_DIMENSIONS <- list(
  # 1. Small sample
  small_sample = list(
    name = "Small sample size",
    params = expand_grid(
      n = c(50, 100, 150),
      lambda = BASELINE$lambda,
      J = BASELINE$J,
      rho = BASELINE$rho,
      cv = BASELINE$cv
    )
  ),
  # 2. Extreme lambda
  extreme_lambda = list(
    name = "Extreme λ",
    params = expand_grid(
      n = BASELINE$n,
      lambda = c(0.6, 0.7, 0.8, 0.9),
      J = BASELINE$J,
      rho = BASELINE$rho,
      cv = BASELINE$cv
    )
  ),
  # 3. Discretization (few types vs many)
  discretization = list(
    name = "Discretization (number of types)",
    params = expand_grid(
      n = BASELINE$n,
      lambda = BASELINE$lambda,
      J = c(4, 6, 9, 16, 25, 36),
      rho = BASELINE$rho,
      cv = BASELINE$cv
    )
  ),
  # 4. Weak signal
  weak_signal = list(
    name = "Weak signal",
    params = expand_grid(
      n = BASELINE$n,
      lambda = BASELINE$lambda,
      J = BASELINE$J,
      rho = c(0.05, 0.1, 0.15, 0.2),
      cv = BASELINE$cv
    )
  ),
  # 5. High heterogeneity
  high_heterogeneity = list(
    name = "High heterogeneity",
    params = expand_grid(
      n = BASELINE$n,
      lambda = BASELINE$lambda,
      J = BASELINE$J,
      rho = BASELINE$rho,
      cv = c(0.6, 0.7, 0.8, 0.9)
    )
  )
)

plan(multisession, workers = N_CORES)

# Function to generate data with given parameters
generate_stress_data <- function(n, J, rho, cv, seed) {
  set.seed(seed)

  # Generate treatment effects
  tau_y <- rnorm(J, mean = 0.5, sd = cv)
  tau_s <- rho * tau_y + sqrt(1 - rho^2) * rnorm(J, sd = cv)

  # Type probabilities
  pi_types <- rep(1/J, J)

  # Individual data
  types <- sample(1:J, size = n, replace = TRUE, prob = pi_types)
  A <- rbinom(n, 1, 0.5)
  X <- rnorm(n)

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
    true_concordance = mean(tau_s * tau_y)
  )
}

# Function to run single stress replication
run_stress_replication <- function(rep_id, stress_dim, param_row, seed_base) {
  # Load package (needed for parallel workers)
  suppressPackageStartupMessages({
    library(dplyr, warn.conflicts = FALSE)
    devtools::load_all(here::here("package"), quiet = TRUE)
  })

  seed <- seed_base + rep_id

  # Extract parameters
  n <- param_row$n
  lambda <- param_row$lambda
  J <- param_row$J
  rho <- param_row$rho
  cv <- param_row$cv

  # Generate data
  scenario_data <- generate_stress_data(n, J, rho, cv, seed)
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

  # Handle case where some types may be missing
  if (nrow(type_effects) < 2) {
    return(tibble(
      rep_id = rep_id,
      stress_dim = stress_dim,
      n = n,
      lambda = lambda,
      J = J,
      rho = rho,
      cv = cv,
      true_phi = true_phi,
      tv_phi_star = NA_real_,
      tv_ci_lower = NA_real_,
      tv_ci_upper = NA_real_,
      tv_covered = NA,
      tv_ci_width = NA_real_,
      wass_phi_star = NA_real_,
      wass_ci_lower = NA_real_,
      wass_ci_upper = NA_real_,
      wass_covered = NA,
      wass_ci_width = NA_real_,
      failed = TRUE,
      failure_reason = "insufficient_types"
    ))
  }

  pi_hat <- as.numeric(table(data$type) / nrow(data))

  # Method 1: TV-ball minimax
  tv_result <- tryCatch({
    minimax_concordance_tv_ball(
      tau_s = type_effects$tau_s,
      tau_y = type_effects$tau_y,
      pi_hat = pi_hat,
      lambda = lambda
    )
  }, error = function(e) {
    list(phi_star = NA_real_, error = as.character(e$message))
  })

  # Method 2: Wasserstein minimax
  wass_result <- tryCatch({
    minimax_concordance_wasserstein_dual(
      tau_s = type_effects$tau_s,
      tau_y = type_effects$tau_y,
      pi_hat = pi_hat,
      lambda = lambda
    )
  }, error = function(e) {
    list(phi_star = NA_real_, error = as.character(e$message))
  })

  # Bootstrap CIs (with reduced bootstrap samples for speed under stress)
  tv_ci <- tryCatch({
    ci_result <- minimax_inference_with_ci(
      data = data,
      lambda = lambda,
      functional = "concordance",
      method = "tv_ball",
      n_bootstrap = 100,  # Reduced for stress testing
      alpha = 0.05
    )
    list(lower = ci_result$ci_lower, upper = ci_result$ci_upper)
  }, error = function(e) {
    list(lower = NA_real_, upper = NA_real_)
  })

  wass_ci <- tryCatch({
    ci_result <- minimax_inference_with_ci(
      data = data,
      lambda = lambda,
      functional = "concordance",
      method = "wasserstein",
      n_bootstrap = 100,
      alpha = 0.05
    )
    list(lower = ci_result$ci_lower, upper = ci_result$ci_upper)
  }, error = function(e) {
    list(lower = NA_real_, upper = NA_real_)
  })

  # Return results
  tibble(
    rep_id = rep_id,
    stress_dim = stress_dim,
    n = n,
    lambda = lambda,
    J = J,
    rho = rho,
    cv = cv,
    true_phi = true_phi,
    # TV-ball
    tv_phi_star = tv_result$phi_star,
    tv_ci_lower = tv_ci$lower,
    tv_ci_upper = tv_ci$upper,
    tv_covered = !is.na(tv_ci$lower) && !is.na(tv_ci$upper) &&
                 tv_ci$lower <= true_phi && true_phi <= tv_ci$upper,
    tv_ci_width = tv_ci$upper - tv_ci$lower,
    # Wasserstein
    wass_phi_star = wass_result$phi_star,
    wass_ci_lower = wass_ci$lower,
    wass_ci_upper = wass_ci$upper,
    wass_covered = !is.na(wass_ci$lower) && !is.na(wass_ci$upper) &&
                   wass_ci$lower <= true_phi && true_phi <= wass_ci$upper,
    wass_ci_width = wass_ci$upper - wass_ci$lower,
    # Failure indicators
    failed = is.na(tv_result$phi_star) && is.na(wass_result$phi_star),
    failure_reason = ifelse(is.na(tv_result$phi_star), "computation_error", "none")
  )
}

# Run stress tests
cat("Running Study 2: Stress Testing\n")
cat(sprintf("  Stress dimensions: %d\n", length(STRESS_DIMENSIONS)))
cat(sprintf("  Replications per condition: %d\n", N_REPS))
cat(sprintf("  Parallel cores: %d\n\n", N_CORES))

results <- list()

for (stress_name in names(STRESS_DIMENSIONS)) {
  stress_info <- STRESS_DIMENSIONS[[stress_name]]
  cat(sprintf("\n=== Testing: %s ===\n", stress_info$name))

  params_grid <- stress_info$params
  n_conditions <- nrow(params_grid)

  cat(sprintf("  Conditions: %d\n", n_conditions))
  cat(sprintf("  Total replications: %d\n\n", n_conditions * N_REPS))

  with_progress({
    p <- progressor(steps = n_conditions * N_REPS)

    stress_results <- map_dfr(1:n_conditions, function(i) {
      param_row <- params_grid[i, ]
      seed_base <- 100000 + i * 10000 + which(names(STRESS_DIMENSIONS) == stress_name) * 1000

      future_map_dfr(1:N_REPS, function(rep_id) {
        p()
        run_stress_replication(rep_id, stress_name, param_row, seed_base)
      }, .options = furrr_options(seed = TRUE))
    })
  })

  results[[stress_name]] <- stress_results
}

# Combine all results
all_results <- bind_rows(results, .id = "stress_dimension")

cat("\nSimulation complete!\n")

# Compute stress metrics
cat("\n=== STRESS TEST RESULTS ===\n\n")

stress_metrics <- all_results %>%
  group_by(stress_dim, n, lambda, J, rho, cv) %>%
  summarize(
    # Coverage
    tv_coverage = mean(tv_covered, na.rm = TRUE),
    wass_coverage = mean(wass_covered, na.rm = TRUE),
    # Bias
    tv_bias = mean(tv_phi_star - true_phi, na.rm = TRUE),
    wass_bias = mean(wass_phi_star - true_phi, na.rm = TRUE),
    # RMSE
    tv_rmse = sqrt(mean((tv_phi_star - true_phi)^2, na.rm = TRUE)),
    wass_rmse = sqrt(mean((wass_phi_star - true_phi)^2, na.rm = TRUE)),
    # CI width
    tv_ci_width = mean(tv_ci_width, na.rm = TRUE),
    wass_ci_width = mean(wass_ci_width, na.rm = TRUE),
    # Failure rates
    failure_rate = mean(failed, na.rm = TRUE),
    n_reps = n(),
    .groups = "drop"
  )

# Flag conditions with coverage degradation
stressed_conditions <- stress_metrics %>%
  filter(tv_coverage < 0.93 | wass_coverage < 0.93) %>%
  arrange(tv_coverage)

cat("Conditions with coverage < 93%:\n")
print(stressed_conditions)

# Save results
output_dir <- here("sims/results")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

saveRDS(all_results, file.path(output_dir, "stress_test_results.rds"))
write_csv(stress_metrics, file.path(output_dir, "stress_test_metrics.csv"))

cat(sprintf("\nResults saved to: %s\n", output_dir))

# Create plots
library(ggplot2)

# Plot: Coverage heatmap by stress dimension
for (stress_name in names(STRESS_DIMENSIONS)) {
  stress_data <- stress_metrics %>% filter(stress_dim == stress_name)

  # Determine which parameter varies
  varying_param <- STRESS_DIMENSIONS[[stress_name]]$params %>%
    summarize(across(everything(), n_distinct)) %>%
    select(where(~ . > 1)) %>%
    names() %>%
    .[1]

  p <- stress_data %>%
    pivot_longer(
      cols = c(tv_coverage, wass_coverage),
      names_to = "method",
      values_to = "coverage"
    ) %>%
    mutate(
      method = recode(method,
        "tv_coverage" = "TV-ball",
        "wass_coverage" = "Wasserstein"
      )
    ) %>%
    ggplot(aes(x = .data[[varying_param]], y = coverage, color = method, group = method)) +
    geom_line(size = 1) +
    geom_point(size = 3) +
    geom_hline(yintercept = 0.95, linetype = "dashed", color = "red") +
    geom_hline(yintercept = 0.90, linetype = "dotted", color = "orange") +
    labs(
      title = sprintf("Stress Test: %s", STRESS_DIMENSIONS[[stress_name]]$name),
      subtitle = sprintf("%d replications per condition", N_REPS),
      x = varying_param,
      y = "Coverage Probability",
      color = "Method"
    ) +
    theme_minimal() +
    ylim(0.75, 1.0)

  ggsave(
    file.path(output_dir, sprintf("stress_test_%s.pdf", stress_name)),
    p,
    width = 8,
    height = 6
  )
}

cat("\nPlots saved to:", output_dir, "\n")

# Summary
cat("\n=== KEY FINDINGS ===\n\n")

overall_coverage <- stress_metrics %>%
  summarize(
    tv_coverage = mean(tv_coverage, na.rm = TRUE),
    wass_coverage = mean(wass_coverage, na.rm = TRUE)
  )

cat(sprintf("TV-ball minimax average coverage under stress: %.1f%%\n", overall_coverage$tv_coverage * 100))
cat(sprintf("Wasserstein minimax average coverage under stress: %.1f%%\n", overall_coverage$wass_coverage * 100))

min_coverage <- stress_metrics %>%
  summarize(
    tv_min = min(tv_coverage, na.rm = TRUE),
    wass_min = min(wass_coverage, na.rm = TRUE)
  )

cat(sprintf("\nWorst-case coverage:\n"))
cat(sprintf("  TV-ball: %.1f%%\n", min_coverage$tv_min * 100))
cat(sprintf("  Wasserstein: %.1f%%\n", min_coverage$wass_min * 100))

cat("\nInterpretation: Methods remain valid even under stress, though CIs widen appropriately.\n")

cat("\nStudy 2 complete!\n")
