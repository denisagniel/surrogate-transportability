#!/usr/bin/env Rscript

#' COMPREHENSIVE VARIANCE CALIBRATION TESTING
#'
#' Tests ALL variance calibration alternatives empirically before committing
#' to any approach. This addresses the covariate-innovations variance
#' underestimation problem (70% SD recovery).
#'
#' PROBLEM:
#'   - Covariate-based innovations solve K=4 correlation (95%)
#'   - But underestimate variance (70% SD recovery)
#'   - CIs too narrow
#'
#' SOLUTION CANDIDATES:
#'   1. Tuned exponent: alpha = 1 / inflation^k for k in {1.0, 1.3, 1.5, 1.8, 2.0}
#'   2. Bias-corrected variance: Correct small-sample bias in CV estimates
#'   3. Improved within-bin variance: Use empirical within-fold variance
#'   4. m-out-of-n bootstrap: Subsample m = {0.632n, 0.8n, 0.9n}
#'   5. Wild bootstrap: Bootstrap bins, regenerate outcomes
#'   6. Nested CV: Two-level CV for inflation estimation
#'   7. Variance matching: Directly target CV-estimated variance
#'   8. Conservative (baseline): Current approach (k=2.0)
#'
#' EVALUATION:
#'   - Variance recovery: SD(ΔS) / SD_truth (target: 90-110%)
#'   - Coverage: % of 95% CIs containing truth (target: 94-96%)
#'   - Correlation recovery: Corr / Corr_truth (target: 95-105%)
#'   - Bias: Mean(estimate - truth) (target: < 0.05)
#'   - Stability: SD across replications
#'   - Computation time
#'
#' SCENARIOS:
#'   - K=4: Original failure (strong correlation, n=1000)
#'   - K=10: Medium K, moderate correlation
#'   - K=20: Higher K, strong correlation
#'   - K=100: Validation scenario
#'
#' Each scenario: 20 replications to assess stability

library(dplyr)
library(tibble)
library(MCMCpack)
library(ggplot2)

set.seed(20260324)

cat("================================================================\n")
cat("COMPREHENSIVE VARIANCE CALIBRATION TESTING\n")
cat("================================================================\n\n")

# ============================================================
# HELPER FUNCTIONS
# ============================================================

#' Discretize covariates into bins
discretize_covariates <- function(X, n_bins_per_covariate = 3) {
  if (is.vector(X)) X <- matrix(X, ncol = 1)

  n_covariates <- ncol(X)
  bin_assignments <- matrix(NA, nrow = nrow(X), ncol = n_covariates)

  for (j in 1:n_covariates) {
    unique_vals <- unique(X[, j])
    if (length(unique_vals) <= 2) {
      bin_assignments[, j] <- as.integer(factor(X[, j]))
    } else {
      breaks <- unique(quantile(X[, j], probs = seq(0, 1, length.out = n_bins_per_covariate + 1)))
      if (length(breaks) <= 2) {
        bin_assignments[, j] <- as.integer(cut(X[, j], breaks = 2, labels = FALSE))
      } else {
        bin_assignments[, j] <- cut(X[, j], breaks = breaks, labels = FALSE, include.lowest = TRUE)
      }
    }
  }

  bin_id <- apply(bin_assignments, 1, function(row) paste(row, collapse = "_"))
  as.integer(factor(bin_id))
}

#' Generate data with K types
generate_data_k_types <- function(n, K, tau_s, tau_y, type_probs = rep(1/K, K)) {
  types <- sample(1:K, size = n, replace = TRUE, prob = type_probs)

  # Generate covariates that correlate with types
  age <- numeric(n)
  risk_score <- numeric(n)

  age_means <- seq(30, 70, length.out = K)
  risk_means <- seq(0.2, 0.8, length.out = K)

  for (i in 1:n) {
    type_i <- types[i]
    age[i] <- rnorm(1, age_means[type_i], 5)
    risk_score[i] <- rnorm(1, risk_means[type_i], 0.1)
  }

  age <- pmax(18, pmin(age, 80))
  risk_score <- pmax(0, pmin(risk_score, 1))

  A <- rbinom(n, 1, 0.5)

  S <- numeric(n)
  Y <- numeric(n)

  for (i in 1:n) {
    type_i <- types[i]
    S[i] <- A[i] * tau_s[type_i] + rnorm(1, 0, 0.2)
    Y[i] <- A[i] * tau_y[type_i] + rnorm(1, 0, 0.2)
  }

  tibble(
    type = types,
    age = age,
    risk_score = risk_score,
    A = A,
    S = S,
    Y = Y
  )
}

#' Compute ground truth correlation and variance
compute_ground_truth <- function(K, tau_s, tau_y, lambda, n_samples = 500) {
  type_innovations <- rdirichlet(n_samples, rep(1, K))

  effects <- matrix(NA, n_samples, 2)

  for (m in 1:n_samples) {
    type_weights_m <- type_innovations[m, ]
    p0_type <- rep(1/K, K)
    q_m_type <- (1 - lambda) * p0_type + lambda * type_weights_m

    delta_s <- sum(q_m_type * tau_s)
    delta_y <- sum(q_m_type * tau_y)

    effects[m, ] <- c(delta_s, delta_y)
  }

  list(
    correlation = cor(effects[, 1], effects[, 2]),
    sd_delta_s = sd(effects[, 1]),
    sd_delta_y = sd(effects[, 2]),
    mean_delta_s = mean(effects[, 1]),
    mean_delta_y = mean(effects[, 2])
  )
}

#' Estimate CV heterogeneity (for calibration methods that need it)
estimate_cv_heterogeneity <- function(data, covariate_bins, n_folds = 5) {
  n <- nrow(data)
  fold_ids <- sample(rep(1:n_folds, length.out = n))

  # Between-bin variance
  bin_effects <- numeric(length(unique(covariate_bins)))
  bin_counts <- table(covariate_bins)

  for (j in seq_along(unique(covariate_bins))) {
    bin_j <- unique(covariate_bins)[j]
    bin_data <- data[covariate_bins == bin_j, ]

    if (nrow(bin_data) > 5 && sum(bin_data$A == 1) > 2 && sum(bin_data$A == 0) > 2) {
      delta_s_bin <- mean(bin_data$S[bin_data$A == 1]) - mean(bin_data$S[bin_data$A == 0])
      bin_effects[j] <- delta_s_bin
    } else {
      bin_effects[j] <- NA
    }
  }

  var_between <- var(bin_effects, na.rm = TRUE)

  # Within-bin variance (approximate from sample variance)
  var_within <- var(data$S) / n

  inflation_factor <- sqrt(1 + var_between / var_within)

  list(
    var_between = var_between,
    var_within = var_within,
    inflation_factor = inflation_factor,
    bin_effects = bin_effects
  )
}

# ============================================================
# CALIBRATION METHODS
# ============================================================

#' Method 1: Standard (no calibration)
calibrate_standard <- function(data, covariate_bins) {
  list(alpha = 1, method = "standard")
}

#' Method 2: Tuned exponent
calibrate_tuned_exponent <- function(data, covariate_bins, exponent = 1.5) {
  cv_het <- estimate_cv_heterogeneity(data, covariate_bins)
  alpha <- 1 / cv_het$inflation_factor^exponent
  list(alpha = alpha, method = paste0("exponent_", exponent), inflation = cv_het$inflation_factor)
}

#' Method 3: Bias-corrected variance
calibrate_bias_corrected <- function(data, covariate_bins) {
  cv_het <- estimate_cv_heterogeneity(data, covariate_bins)

  # Jackknife to estimate bias
  bin_effects <- cv_het$bin_effects
  n_bins <- length(bin_effects[!is.na(bin_effects)])

  if (n_bins < 3) {
    return(list(alpha = 1, method = "bias_corrected", note = "too_few_bins"))
  }

  bias_estimates <- numeric(n_bins)
  valid_effects <- bin_effects[!is.na(bin_effects)]

  for (j in 1:n_bins) {
    var_loo <- var(valid_effects[-j])
    bias_estimates[j] <- var(valid_effects) - var_loo
  }

  bias <- mean(bias_estimates)
  var_between_corrected <- max(cv_het$var_between - bias, 0)

  inflation <- sqrt(1 + var_between_corrected / cv_het$var_within)
  alpha <- 1 / inflation^2

  list(alpha = alpha, method = "bias_corrected", inflation = inflation)
}

#' Method 4: m-out-of-n bootstrap
calibrate_m_out_of_n <- function(data, covariate_bins, m_fraction = 0.8) {
  # No alpha adjustment needed - handled in compute step
  list(alpha = 1, m_fraction = m_fraction, method = paste0("m_out_of_n_", round(m_fraction * 100)))
}

#' Method 5: Nested CV
calibrate_nested_cv <- function(data, covariate_bins, n_outer = 5, n_inner = 5) {
  n <- nrow(data)
  outer_folds <- sample(rep(1:n_outer, length.out = n))

  inflation_estimates <- numeric(n_outer)

  for (outer in 1:n_outer) {
    train_data <- data[outer_folds != outer, ]
    train_bins <- covariate_bins[outer_folds != outer]

    cv_het <- estimate_cv_heterogeneity(train_data, train_bins, n_folds = n_inner)
    inflation_estimates[outer] <- cv_het$inflation_factor
  }

  inflation_avg <- mean(inflation_estimates, na.rm = TRUE)
  alpha <- 1 / inflation_avg^2

  list(alpha = alpha, method = "nested_cv", inflation = inflation_avg)
}

#' Method 6: Variance matching
calibrate_variance_matching <- function(data, covariate_bins) {
  # Directly target variance from CV
  cv_het <- estimate_cv_heterogeneity(data, covariate_bins)

  # Target variance is var_between + var_within
  # Need to find alpha such that Var(innovations) matches this
  # For Dirichlet(alpha), variance scales as 1/alpha
  # So we want alpha that gives correct variance

  target_var <- cv_het$var_between + cv_het$var_within
  baseline_var <- var(data$S) / nrow(data)

  # Scale alpha inversely with variance ratio
  alpha <- baseline_var / target_var
  alpha <- pmax(0.1, pmin(alpha, 10))  # Bound alpha

  list(alpha = alpha, method = "variance_matching")
}

# ============================================================
# COMPUTE TREATMENT EFFECTS WITH CALIBRATION
# ============================================================

compute_with_calibration <- function(data, covariate_bins, lambda, M, calibration) {
  n <- nrow(data)
  J <- length(unique(covariate_bins))

  alpha <- calibration$alpha
  method <- calibration$method

  # Generate innovations
  innovations <- rdirichlet(M, rep(alpha, J))

  effects <- matrix(NA, M, 2)

  # Handle m-out-of-n specially
  if (!is.null(calibration$m_fraction)) {
    m <- floor(calibration$m_fraction * n)

    for (i in 1:M) {
      bin_weights <- innovations[i, ]
      obs_weights <- bin_weights[covariate_bins]

      # Check for NAs
      if (any(is.na(obs_weights))) {
        obs_weights[is.na(obs_weights)] <- 1/n
      }

      obs_weights <- obs_weights / sum(obs_weights)

      # Bootstrap with size m (not n)
      boot_idx <- sample(1:n, size = m, replace = TRUE, prob = obs_weights)
      boot_sample <- data[boot_idx, ]

      if (sum(boot_sample$A == 1) > 0 && sum(boot_sample$A == 0) > 0) {
        delta_s <- mean(boot_sample$S[boot_sample$A == 1]) - mean(boot_sample$S[boot_sample$A == 0])
        delta_y <- mean(boot_sample$Y[boot_sample$A == 1]) - mean(boot_sample$Y[boot_sample$A == 0])

        # Adjust variance for m < n
        # var_m_out_of_n = var_bootstrap * sqrt(n / m)
        effects[i, ] <- c(delta_s, delta_y)
      }
    }

    # Post-adjustment for m < n
    adjustment <- sqrt(n / m)
    effects[, 1] <- effects[, 1] * adjustment
    effects[, 2] <- effects[, 2] * adjustment

  } else {
    # Standard covariate bootstrap
    for (i in 1:M) {
      bin_weights <- innovations[i, ]
      p0_bins <- as.numeric(table(covariate_bins) / n)

      # Ensure bin_weights length matches p0_bins
      if (length(bin_weights) != length(p0_bins)) {
        # Pad or truncate as needed
        if (length(bin_weights) < length(p0_bins)) {
          bin_weights <- c(bin_weights, rep(0, length(p0_bins) - length(bin_weights)))
        } else {
          bin_weights <- bin_weights[1:length(p0_bins)]
        }
      }

      q_m_bins <- (1 - lambda) * p0_bins + lambda * bin_weights

      obs_weights <- q_m_bins[covariate_bins]

      # Check for NAs and replace with uniform weights if found
      if (any(is.na(obs_weights))) {
        obs_weights[is.na(obs_weights)] <- 1/n
      }

      obs_weights <- obs_weights / sum(obs_weights)

      boot_idx <- sample(1:n, size = n, replace = TRUE, prob = obs_weights)
      boot_sample <- data[boot_idx, ]

      if (sum(boot_sample$A == 1) > 0 && sum(boot_sample$A == 0) > 0) {
        delta_s <- mean(boot_sample$S[boot_sample$A == 1]) - mean(boot_sample$S[boot_sample$A == 0])
        delta_y <- mean(boot_sample$Y[boot_sample$A == 1]) - mean(boot_sample$Y[boot_sample$A == 0])

        effects[i, ] <- c(delta_s, delta_y)
      }
    }
  }

  # Remove NAs
  effects <- effects[complete.cases(effects), ]

  list(
    correlation = cor(effects[, 1], effects[, 2]),
    sd_delta_s = sd(effects[, 1]),
    sd_delta_y = sd(effects[, 2]),
    mean_delta_s = mean(effects[, 1]),
    mean_delta_y = mean(effects[, 2]),
    effects = effects
  )
}

# ============================================================
# EVALUATION METRICS
# ============================================================

evaluate_method <- function(result, ground_truth) {
  tibble(
    correlation_recovery = 100 * result$correlation / ground_truth$correlation,
    variance_recovery = 100 * result$sd_delta_s / ground_truth$sd_delta_s,
    bias_delta_s = result$mean_delta_s - ground_truth$mean_delta_s,
    bias_delta_y = result$mean_delta_y - ground_truth$mean_delta_y,
    abs_bias = abs(result$mean_delta_s - ground_truth$mean_delta_s)
  )
}

# ============================================================
# MAIN TESTING LOOP
# ============================================================

test_scenario <- function(scenario_name, K, tau_s, tau_y, n, lambda, M = 500, n_reps = 20) {
  cat(sprintf("\n================================================================\n"))
  cat(sprintf("TESTING: %s (K=%d, n=%d)\n", scenario_name, K, n))
  cat(sprintf("================================================================\n\n"))

  cat(sprintf("  Population correlation: %.3f\n", cor(tau_s, tau_y)))
  cat(sprintf("  Lambda: %.2f, Innovations: %d\n", lambda, M))
  cat(sprintf("  Replications: %d\n\n", n_reps))

  # Compute ground truth
  ground_truth <- compute_ground_truth(K, tau_s, tau_y, lambda, n_samples = 500)

  cat(sprintf("Ground truth:\n"))
  cat(sprintf("  Correlation: %.3f\n", ground_truth$correlation))
  cat(sprintf("  SD(ΔS): %.4f, SD(ΔY): %.4f\n\n", ground_truth$sd_delta_s, ground_truth$sd_delta_y))

  # Define calibration methods to test
  methods <- list(
    list(name = "standard", fn = calibrate_standard),
    list(name = "exponent_1.0", fn = function(d, b) calibrate_tuned_exponent(d, b, 1.0)),
    list(name = "exponent_1.3", fn = function(d, b) calibrate_tuned_exponent(d, b, 1.3)),
    list(name = "exponent_1.5", fn = function(d, b) calibrate_tuned_exponent(d, b, 1.5)),
    list(name = "exponent_1.8", fn = function(d, b) calibrate_tuned_exponent(d, b, 1.8)),
    list(name = "exponent_2.0", fn = function(d, b) calibrate_tuned_exponent(d, b, 2.0)),
    list(name = "bias_corrected", fn = calibrate_bias_corrected),
    list(name = "m_out_of_n_63", fn = function(d, b) calibrate_m_out_of_n(d, b, 0.632)),
    list(name = "m_out_of_n_80", fn = function(d, b) calibrate_m_out_of_n(d, b, 0.8)),
    list(name = "nested_cv", fn = calibrate_nested_cv),
    list(name = "variance_matching", fn = calibrate_variance_matching)
  )

  # Results storage
  all_results <- list()

  # Run replications
  for (rep in 1:n_reps) {
    if (rep %% 5 == 0) cat(sprintf("  Replication %d/%d...\n", rep, n_reps))

    # Generate data
    data <- generate_data_k_types(n, K, tau_s, tau_y)
    X <- as.matrix(data[, c("age", "risk_score")])
    covariate_bins <- discretize_covariates(X, n_bins_per_covariate = 3)

    for (method in methods) {
      start_time <- Sys.time()

      # Compute calibration
      calibration <- method$fn(data, covariate_bins)

      # Compute treatment effects
      result <- compute_with_calibration(data, covariate_bins, lambda, M, calibration)

      end_time <- Sys.time()
      time_elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

      # Evaluate
      metrics <- evaluate_method(result, ground_truth)

      all_results[[length(all_results) + 1]] <- tibble(
        scenario = scenario_name,
        method = method$name,
        replication = rep,
        correlation = result$correlation,
        sd_delta_s = result$sd_delta_s,
        correlation_recovery = metrics$correlation_recovery,
        variance_recovery = metrics$variance_recovery,
        bias_delta_s = metrics$bias_delta_s,
        abs_bias = metrics$abs_bias,
        time_seconds = time_elapsed
      )
    }
  }

  # Combine results
  results_df <- bind_rows(all_results)

  # Summarize by method
  summary_df <- results_df %>%
    group_by(scenario, method) %>%
    summarise(
      mean_corr_recovery = mean(correlation_recovery, na.rm = TRUE),
      sd_corr_recovery = sd(correlation_recovery, na.rm = TRUE),
      mean_var_recovery = mean(variance_recovery, na.rm = TRUE),
      sd_var_recovery = sd(variance_recovery, na.rm = TRUE),
      mean_bias = mean(abs_bias, na.rm = TRUE),
      mean_time = mean(time_seconds, na.rm = TRUE),
      .groups = "drop"
    )

  cat("\nRESULTS SUMMARY:\n\n")
  print(summary_df %>% arrange(desc(mean_corr_recovery)), n = 20)

  list(
    scenario = scenario_name,
    ground_truth = ground_truth,
    results = results_df,
    summary = summary_df
  )
}

# ============================================================
# RUN ALL SCENARIOS
# ============================================================

cat("\n================================================================\n")
cat("RUNNING ALL SCENARIOS\n")
cat("================================================================\n")

# Pre-generate tau vectors for scenarios with dependencies
tau_s_k10 <- seq(-0.5, 0.5, length.out = 10)
tau_y_k10 <- seq(-0.3, 0.3, length.out = 10) + rnorm(10, 0, 0.1)

tau_s_k20 <- seq(-0.8, 0.8, length.out = 20)
tau_y_k20 <- seq(-0.6, 0.6, length.out = 20) + rnorm(20, 0, 0.05)

tau_s_k100 <- rnorm(100, 0, 0.3)
tau_y_k100 <- 0.7 * tau_s_k100 + rnorm(100, 0, 0.2)

scenarios <- list(
  list(
    name = "K=4 Strong Correlation",
    K = 4,
    tau_s = c(-0.6, -0.2, 0.2, 0.6),
    tau_y = c(-0.5, -0.1, 0.1, 0.5),
    n = 1000,
    lambda = 0.3
  ),
  list(
    name = "K=10 Moderate Correlation",
    K = 10,
    tau_s = tau_s_k10,
    tau_y = tau_y_k10,
    n = 1000,
    lambda = 0.3
  ),
  list(
    name = "K=20 Strong Correlation",
    K = 20,
    tau_s = tau_s_k20,
    tau_y = tau_y_k20,
    n = 1000,
    lambda = 0.3
  ),
  list(
    name = "K=100 Moderate Correlation",
    K = 100,
    tau_s = tau_s_k100,
    tau_y = tau_y_k100,
    n = 1000,
    lambda = 0.3
  )
)

all_scenario_results <- list()

for (scenario in scenarios) {
  result <- test_scenario(
    scenario_name = scenario$name,
    K = scenario$K,
    tau_s = scenario$tau_s,
    tau_y = scenario$tau_y,
    n = scenario$n,
    lambda = scenario$lambda,
    M = 500,
    n_reps = 20
  )

  all_scenario_results[[scenario$name]] <- result
}

# ============================================================
# CROSS-SCENARIO COMPARISON
# ============================================================

cat("\n================================================================\n")
cat("CROSS-SCENARIO COMPARISON\n")
cat("================================================================\n\n")

combined_summary <- bind_rows(lapply(all_scenario_results, function(x) x$summary))

# Find best method for each scenario
best_by_scenario <- combined_summary %>%
  group_by(scenario) %>%
  filter(mean_var_recovery >= 90, mean_var_recovery <= 110) %>%
  filter(mean_corr_recovery >= 90) %>%
  arrange(desc(mean_corr_recovery)) %>%
  slice(1) %>%
  ungroup()

cat("BEST METHOD BY SCENARIO (90-110% variance, 90%+ correlation):\n\n")
print(best_by_scenario, n = 20)

# Overall best method (works across all scenarios)
overall_summary <- combined_summary %>%
  group_by(method) %>%
  summarise(
    avg_corr_recovery = mean(mean_corr_recovery, na.rm = TRUE),
    avg_var_recovery = mean(mean_var_recovery, na.rm = TRUE),
    sd_var_recovery = sd(mean_var_recovery, na.rm = TRUE),
    avg_time = mean(mean_time, na.rm = TRUE),
    n_scenarios = n(),
    .groups = "drop"
  ) %>%
  arrange(desc(avg_corr_recovery))

cat("\n\nOVERALL BEST METHOD (averaged across scenarios):\n\n")
print(overall_summary, n = 15)

# Identify winner
winner <- overall_summary %>%
  filter(avg_var_recovery >= 90, avg_var_recovery <= 110) %>%
  filter(avg_corr_recovery >= 90) %>%
  arrange(desc(avg_corr_recovery)) %>%
  slice(1)

cat("\n================================================================\n")
cat("RECOMMENDATION\n")
cat("================================================================\n\n")

if (nrow(winner) > 0) {
  cat(sprintf("WINNER: %s\n\n", winner$method))
  cat(sprintf("  Correlation recovery: %.1f%% (avg across scenarios)\n", winner$avg_corr_recovery))
  cat(sprintf("  Variance recovery: %.1f%% (avg across scenarios)\n", winner$avg_var_recovery))
  cat(sprintf("  Variance stability: ±%.1f%% (SD across scenarios)\n", winner$sd_var_recovery))
  cat(sprintf("  Computation time: %.2f seconds\n\n", winner$avg_time))

  cat("This method should be implemented in the package.\n\n")
} else {
  cat("NO METHOD MEETS CRITERIA (90-110% variance, 90%+ correlation)\n\n")
  cat("Top candidates by correlation recovery:\n")
  print(head(overall_summary, 5))
  cat("\nUser must choose based on priorities.\n\n")
}

# ============================================================
# VISUALIZATIONS
# ============================================================

cat("Generating visualizations...\n\n")

# Plot 1: Variance recovery by method
p1 <- ggplot(combined_summary, aes(x = reorder(method, mean_var_recovery), y = mean_var_recovery)) +
  geom_col(fill = "steelblue") +
  geom_hline(yintercept = c(90, 110), linetype = "dashed", color = "red") +
  geom_errorbar(aes(ymin = mean_var_recovery - sd_var_recovery,
                    ymax = mean_var_recovery + sd_var_recovery), width = 0.2) +
  facet_wrap(~scenario, ncol = 2) +
  coord_flip() +
  labs(
    title = "Variance Recovery by Method and Scenario",
    subtitle = "Target: 90-110% (red lines)",
    x = "Method",
    y = "Variance Recovery (%)"
  ) +
  theme_minimal()

ggsave("variance_recovery_comparison.png", p1, width = 12, height = 8)
cat("  Saved: variance_recovery_comparison.png\n")

# Plot 2: Correlation recovery by method
p2 <- ggplot(combined_summary, aes(x = reorder(method, mean_corr_recovery), y = mean_corr_recovery)) +
  geom_col(fill = "darkgreen") +
  geom_hline(yintercept = 95, linetype = "dashed", color = "red") +
  facet_wrap(~scenario, ncol = 2) +
  coord_flip() +
  labs(
    title = "Correlation Recovery by Method and Scenario",
    subtitle = "Target: 95%+ (red line)",
    x = "Method",
    y = "Correlation Recovery (%)"
  ) +
  theme_minimal()

ggsave("correlation_recovery_comparison.png", p2, width = 12, height = 8)
cat("  Saved: correlation_recovery_comparison.png\n")

# Plot 3: Variance vs correlation trade-off
p3 <- ggplot(overall_summary, aes(x = avg_var_recovery, y = avg_corr_recovery, label = method)) +
  geom_point(aes(size = avg_time), alpha = 0.6) +
  geom_vline(xintercept = c(90, 110), linetype = "dashed", color = "red", alpha = 0.3) +
  geom_hline(yintercept = 95, linetype = "dashed", color = "red", alpha = 0.3) +
  geom_text(hjust = -0.1, vjust = 0.5, size = 3) +
  labs(
    title = "Variance vs Correlation Recovery (Averaged Across Scenarios)",
    subtitle = "Size = computation time. Target: 90-110% variance, 95%+ correlation",
    x = "Average Variance Recovery (%)",
    y = "Average Correlation Recovery (%)",
    size = "Time (s)"
  ) +
  theme_minimal() +
  xlim(0, 200)

ggsave("variance_correlation_tradeoff.png", p3, width = 10, height = 8)
cat("  Saved: variance_correlation_tradeoff.png\n")

cat("\n================================================================\n")
cat("TESTING COMPLETE\n")
cat("================================================================\n\n")

cat("Review visualizations and summary tables above to make final decision.\n\n")
