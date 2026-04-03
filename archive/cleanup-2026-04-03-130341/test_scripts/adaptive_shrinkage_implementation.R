#!/usr/bin/env Rscript
# ADAPTIVE SHRINKAGE SELECTION
# Data-driven choice of shrinkage factor based on DGP characteristics

library(tidyverse)
library(here)

devtools::load_all(here("package"))

cat("=============================================================================\n")
cat("ADAPTIVE SHRINKAGE SELECTION\n")
cat("=============================================================================\n\n")

cat("GOAL: Select optimal shrinkage factor based on data characteristics\n\n")

cat("RULES FROM ROBUSTNESS TESTING:\n")
cat("  - High noise → shrinkage 0.4\n")
cat("  - Strong effects → shrinkage 0.6\n")
cat("  - Moderate cases → shrinkage 0.5\n\n")

# =============================================================================
# Adaptive Selection Functions
# =============================================================================

#' Estimate noise level from residuals
#'
#' @param data Data frame with A, S, Y, and covariates
#' @param outcome Character: "S" or "Y"
#' @return Estimated noise standard deviation
estimate_noise_level <- function(data, outcome, covariates) {
  # Fit model to get residuals
  if (outcome == "S") {
    formula_obj <- as.formula(paste("S ~", paste(c("A", covariates), collapse = " + ")))
  } else {
    formula_obj <- as.formula(paste("Y ~", paste(c("A", covariates), collapse = " + ")))
  }

  fit <- lm(formula_obj, data = data)
  residuals <- residuals(fit)

  # Robust estimate of residual SD
  sd_robust <- mad(residuals, constant = 1.4826)  # MAD estimator

  sd_robust
}

#' Estimate effect strength from concordances
#'
#' @param concordances Numeric vector of concordance estimates
#' @return Mean absolute concordance (effect strength measure)
estimate_effect_strength <- function(concordances) {
  # Use median absolute value as robust measure
  median(abs(concordances))
}

#' Select shrinkage factor adaptively
#'
#' @param data Data frame with A, S, Y, and covariates
#' @param covariates Character vector of covariate names
#' @param concordances Optional: precomputed concordances (if NULL, will compute)
#' @param method Character: "rule-based" or "continuous"
#' @return Selected shrinkage factor
#'
#' @details
#' Rule-based method:
#'   - Estimates noise level and effect strength
#'   - Applies decision rules from robustness testing
#'   - Returns 0.4, 0.5, or 0.6
#'
#' Continuous method:
#'   - Uses smooth function of noise and effect strength
#'   - Returns value in [0.4, 0.6]
select_shrinkage_adaptive <- function(data, covariates, concordances = NULL,
                                      method = c("rule-based", "continuous")) {

  method <- match.arg(method)

  # Estimate noise levels
  noise_s <- estimate_noise_level(data, "S", covariates)
  noise_y <- estimate_noise_level(data, "Y", covariates)
  noise_avg <- mean(c(noise_s, noise_y))

  # Estimate effect strength
  if (is.null(concordances)) {
    # Quick estimation without full DRO
    tau_s <- estimate_treatment_effect_function(
      data, "S", covariates, method = "kernel", cross_fit = FALSE
    )
    tau_y <- estimate_treatment_effect_function(
      data, "Y", covariates, method = "kernel", cross_fit = FALSE
    )
    concordances <- tau_s$tau_hat * tau_y$tau_hat
  }

  effect_strength <- estimate_effect_strength(concordances)

  if (method == "rule-based") {
    # Thresholds calibrated from robustness testing
    # Noise: low < 0.35, moderate 0.35-0.55, high > 0.55
    # Effect: weak < 0.08, moderate 0.08-0.15, strong > 0.15

    noise_high_threshold <- 0.55
    noise_low_threshold <- 0.35
    effect_strong_threshold <- 0.15
    effect_weak_threshold <- 0.08

    # Decision tree
    if (noise_avg > noise_high_threshold) {
      # High noise: use less shrinkage
      shrinkage <- 0.4
      reason <- "High noise detected"
    } else if (noise_avg < noise_low_threshold && effect_strength > effect_strong_threshold) {
      # Low noise + strong effects: use more shrinkage
      shrinkage <- 0.6
      reason <- "Low noise + strong effects detected"
    } else if (effect_strength > effect_strong_threshold) {
      # Strong effects with moderate noise: use more shrinkage
      shrinkage <- 0.6
      reason <- "Strong effects detected"
    } else if (effect_strength < effect_weak_threshold) {
      # Weak effects: use less shrinkage
      shrinkage <- 0.4
      reason <- "Weak effects detected"
    } else {
      # Moderate case: default
      shrinkage <- 0.5
      reason <- "Moderate noise and effects"
    }

  } else {
    # Continuous method: smooth function
    # Normalize to [0, 1] scale
    noise_norm <- pmin(pmax((noise_avg - 0.2) / 0.6, 0), 1)  # [0.2, 0.8] → [0, 1]
    effect_norm <- pmin(pmax(effect_strength / 0.3, 0), 1)  # [0, 0.3] → [0, 1]

    # Shrinkage increases with effect strength, decreases with noise
    # Base formula: 0.5 + 0.1 * (effect - noise)
    shrinkage <- 0.5 + 0.1 * (effect_norm - noise_norm)
    shrinkage <- pmin(pmax(shrinkage, 0.4), 0.6)  # Constrain to [0.4, 0.6]

    reason <- sprintf("Noise=%.3f, Effect=%.3f", noise_avg, effect_strength)
  }

  list(
    shrinkage = shrinkage,
    reason = reason,
    noise_level = noise_avg,
    effect_strength = effect_strength
  )
}

#' Adaptive shrinkage minimax Wasserstein
#'
#' @param data Data frame
#' @param covariates Character vector
#' @param lambda_w Numeric: Wasserstein radius
#' @param tau_method Character: treatment effect estimation method
#' @param cross_fit Logical: use cross-fitting?
#' @param shrink_method Character: "adaptive", "rule-based", or "continuous"
#' @param fixed_shrinkage Numeric: if specified, overrides adaptive selection
#' @return List with phi_star, shrinkage used, and diagnostics
adaptive_shrinkage_minimax <- function(data, covariates, lambda_w,
                                       tau_method = "kernel",
                                       cross_fit = TRUE,
                                       shrink_method = "rule-based",
                                       fixed_shrinkage = NULL) {

  # Estimate treatment effects
  tau_s <- estimate_treatment_effect_function(
    data = data, outcome = "S", covariates = covariates,
    method = tau_method, cross_fit = cross_fit
  )

  tau_y <- estimate_treatment_effect_function(
    data = data, outcome = "Y", covariates = covariates,
    method = tau_method, cross_fit = cross_fit
  )

  # Concordances
  concordances <- tau_s$tau_hat * tau_y$tau_hat

  # Select shrinkage factor
  if (is.null(fixed_shrinkage)) {
    selection <- select_shrinkage_adaptive(
      data, covariates, concordances, method = shrink_method
    )
    shrinkage <- selection$shrinkage
    selection_reason <- selection$reason
  } else {
    shrinkage <- fixed_shrinkage
    selection_reason <- "User-specified"
    selection <- list(
      noise_level = NA,
      effect_strength = NA
    )
  }

  # Apply shrinkage
  h_mean <- mean(concordances)
  h_shrunk <- h_mean + shrinkage * (concordances - h_mean)

  # Wasserstein DRO
  n <- nrow(data)
  X_scaled <- scale(data[, covariates])
  cost_matrix <- as.matrix(dist(X_scaled, method = "euclidean"))^2

  dual_objective <- function(gamma) {
    obj_matrix <- matrix(h_shrunk, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  result_opt <- optimize(dual_objective, interval = c(0, 100), maximum = TRUE)

  list(
    phi_star = result_opt$objective,
    gamma_star = result_opt$maximum,
    shrinkage_used = shrinkage,
    selection_reason = selection_reason,
    noise_level = selection$noise_level,
    effect_strength = selection$effect_strength,
    concordances = concordances,
    concordances_shrunk = h_shrunk
  )
}

# =============================================================================
# Validation: Adaptive vs Fixed
# =============================================================================

cat("=============================================================================\n")
cat("VALIDATION: ADAPTIVE VS FIXED SHRINKAGE\n")
cat("=============================================================================\n\n")

cat("Testing on robustness scenarios to compare:\n")
cat("  1. Adaptive rule-based\n")
cat("  2. Fixed 0.5 (Phase 2 default)\n")
cat("  3. Fixed 0.6 (robustness best overall)\n\n")

# Helper: compute truth
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

# Test scenarios (subset from robustness)
test_scenarios <- list(
  baseline = list(
    name = "Baseline",
    tau_s = function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2,
    tau_y = function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2,
    X_gen = function(n) list(X1 = rnorm(n), X2 = rnorm(n)),
    noise_s = 0.3, noise_y = 0.4
  ),
  strong_hetero = list(
    name = "Strong Heterogeneity",
    tau_s = function(X1, X2) 0.5 + 0.5 * X1 - 0.3 * X2 + 0.2 * X1 * X2,
    tau_y = function(X1, X2) 0.6 + 0.6 * X1 + 0.3 * X2 + 0.3 * X1 * X2,
    X_gen = function(n) list(X1 = rnorm(n), X2 = rnorm(n)),
    noise_s = 0.3, noise_y = 0.4
  ),
  high_noise = list(
    name = "High Noise",
    tau_s = function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2,
    tau_y = function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2,
    X_gen = function(n) list(X1 = rnorm(n), X2 = rnorm(n)),
    noise_s = 0.6, noise_y = 0.8
  ),
  low_noise = list(
    name = "Low Noise",
    tau_s = function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2,
    tau_y = function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2,
    X_gen = function(n) list(X1 = rnorm(n), X2 = rnorm(n)),
    noise_s = 0.15, noise_y = 0.20
  ),
  weak_hetero = list(
    name = "Weak Heterogeneity",
    tau_s = function(X1, X2) 0.3 + 0.05 * X1 - 0.05 * X2,
    tau_y = function(X1, X2) 0.4 + 0.05 * X1 + 0.05 * X2,
    X_gen = function(n) list(X1 = rnorm(n), X2 = rnorm(n)),
    noise_s = 0.3, noise_y = 0.4
  )
)

n_reps <- 50
n <- 250
lambda_w <- 0.5

all_results <- list()

for (scenario_name in names(test_scenarios)) {
  dgp <- test_scenarios[[scenario_name]]

  cat(sprintf("\nTesting: %s\n", dgp$name))

  results_scenario <- map_dfr(1:n_reps, function(rep) {
    set.seed(rep + 1000)

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
    truth <- compute_true_minimax(X1, X2, dgp$tau_s, dgp$tau_y, lambda_w)

    # 1. Adaptive
    est_adaptive <- adaptive_shrinkage_minimax(
      data, c("X1", "X2"), lambda_w,
      shrink_method = "rule-based"
    )

    # 2. Fixed 0.5
    est_05 <- adaptive_shrinkage_minimax(
      data, c("X1", "X2"), lambda_w,
      fixed_shrinkage = 0.5
    )

    # 3. Fixed 0.6
    est_06 <- adaptive_shrinkage_minimax(
      data, c("X1", "X2"), lambda_w,
      fixed_shrinkage = 0.6
    )

    tibble(
      rep = rep,
      truth = truth,
      adaptive_est = est_adaptive$phi_star,
      adaptive_shrink = est_adaptive$shrinkage_used,
      adaptive_reason = est_adaptive$selection_reason,
      fixed_05_est = est_05$phi_star,
      fixed_06_est = est_06$phi_star
    )
  })

  results_scenario$scenario <- scenario_name
  all_results[[scenario_name]] <- results_scenario
}

results <- bind_rows(all_results)

# Compute errors
results <- results %>%
  mutate(
    adaptive_bias = adaptive_est - truth,
    fixed_05_bias = fixed_05_est - truth,
    fixed_06_bias = fixed_06_est - truth
  )

# =============================================================================
# Compare performance
# =============================================================================

cat("\n\n=============================================================================\n")
cat("COMPARISON RESULTS\n")
cat("=============================================================================\n\n")

# Overall summary
overall <- results %>%
  summarise(
    adaptive_rmse = sqrt(mean(adaptive_bias^2)),
    adaptive_mae = mean(abs(adaptive_bias)),
    adaptive_mean_bias = mean(adaptive_bias),
    fixed_05_rmse = sqrt(mean(fixed_05_bias^2)),
    fixed_05_mae = mean(abs(fixed_05_bias)),
    fixed_05_mean_bias = mean(fixed_05_bias),
    fixed_06_rmse = sqrt(mean(fixed_06_bias^2)),
    fixed_06_mae = mean(abs(fixed_06_bias)),
    fixed_06_mean_bias = mean(fixed_06_bias)
  )

cat("OVERALL PERFORMANCE:\n\n")
cat(sprintf("Adaptive:   RMSE=%.4f, MAE=%.4f, Bias=%.4f\n",
            overall$adaptive_rmse, overall$adaptive_mae, overall$adaptive_mean_bias))
cat(sprintf("Fixed 0.5:  RMSE=%.4f, MAE=%.4f, Bias=%.4f\n",
            overall$fixed_05_rmse, overall$fixed_05_mae, overall$fixed_05_mean_bias))
cat(sprintf("Fixed 0.6:  RMSE=%.4f, MAE=%.4f, Bias=%.4f\n",
            overall$fixed_06_rmse, overall$fixed_06_mae, overall$fixed_06_mean_bias))
cat("\n")

# Improvement
cat("IMPROVEMENT OVER FIXED 0.5:\n")
cat(sprintf("  Adaptive: %.1f%% RMSE reduction\n",
            (overall$fixed_05_rmse - overall$adaptive_rmse) / overall$fixed_05_rmse * 100))
cat(sprintf("  Fixed 0.6: %.1f%% RMSE reduction\n",
            (overall$fixed_05_rmse - overall$fixed_06_rmse) / overall$fixed_05_rmse * 100))
cat("\n")

# By scenario
by_scenario <- results %>%
  group_by(scenario) %>%
  summarise(
    adaptive_rmse = sqrt(mean(adaptive_bias^2)),
    fixed_05_rmse = sqrt(mean(fixed_05_bias^2)),
    fixed_06_rmse = sqrt(mean(fixed_06_bias^2)),
    .groups = "drop"
  ) %>%
  mutate(
    best = case_when(
      adaptive_rmse < fixed_05_rmse & adaptive_rmse < fixed_06_rmse ~ "Adaptive",
      fixed_06_rmse < fixed_05_rmse & fixed_06_rmse < adaptive_rmse ~ "Fixed 0.6",
      TRUE ~ "Fixed 0.5"
    )
  )

cat("PERFORMANCE BY SCENARIO:\n\n")
print(by_scenario, n = Inf)
cat("\n")

cat("BEST METHOD PER SCENARIO:\n")
table(by_scenario$best) %>% print()
cat("\n")

# Shrinkage selection distribution
cat("ADAPTIVE SHRINKAGE SELECTIONS:\n\n")
shrink_dist <- results %>%
  group_by(scenario, adaptive_shrink) %>%
  summarise(n = n(), .groups = "drop") %>%
  pivot_wider(names_from = adaptive_shrink, values_from = n, values_fill = 0)

print(shrink_dist, n = Inf)
cat("\n")

# =============================================================================
# Statistical comparison
# =============================================================================

cat("=============================================================================\n")
cat("STATISTICAL TESTS\n")
cat("=============================================================================\n\n")

# Paired t-test: Adaptive vs Fixed 0.5
test_adaptive_vs_05 <- t.test(
  abs(results$adaptive_bias),
  abs(results$fixed_05_bias),
  paired = TRUE
)

cat("Adaptive vs Fixed 0.5:\n")
cat(sprintf("  Mean |bias| difference: %.4f\n", test_adaptive_vs_05$estimate))
cat(sprintf("  p-value: %.4f\n", test_adaptive_vs_05$p.value))
if (test_adaptive_vs_05$p.value < 0.05) {
  if (test_adaptive_vs_05$estimate < 0) {
    cat("  → Adaptive is significantly better\n")
  } else {
    cat("  → Fixed 0.5 is significantly better\n")
  }
} else {
  cat("  → No significant difference\n")
}
cat("\n")

# Adaptive vs Fixed 0.6
test_adaptive_vs_06 <- t.test(
  abs(results$adaptive_bias),
  abs(results$fixed_06_bias),
  paired = TRUE
)

cat("Adaptive vs Fixed 0.6:\n")
cat(sprintf("  Mean |bias| difference: %.4f\n", test_adaptive_vs_06$estimate))
cat(sprintf("  p-value: %.4f\n", test_adaptive_vs_06$p.value))
if (test_adaptive_vs_06$p.value < 0.05) {
  if (test_adaptive_vs_06$estimate < 0) {
    cat("  → Adaptive is significantly better\n")
  } else {
    cat("  → Fixed 0.6 is significantly better\n")
  }
} else {
  cat("  → No significant difference\n")
}
cat("\n")

# =============================================================================
# Save and conclude
# =============================================================================

saveRDS(list(
  results = results,
  overall = overall,
  by_scenario = by_scenario,
  tests = list(
    adaptive_vs_05 = test_adaptive_vs_05,
    adaptive_vs_06 = test_adaptive_vs_06
  )
), here("adaptive_shrinkage_validation.rds"))

cat("Results saved to: adaptive_shrinkage_validation.rds\n\n")

cat("=============================================================================\n")
cat("CONCLUSION\n")
cat("=============================================================================\n\n")

if (overall$adaptive_rmse < overall$fixed_05_rmse &&
    overall$adaptive_rmse < overall$fixed_06_rmse) {
  cat("✓✓✓ ADAPTIVE SELECTION IS BEST ✓✓✓\n\n")
  cat(sprintf("Adaptive beats both fixed options:\n"))
  cat(sprintf("  vs Fixed 0.5: %.1f%% RMSE improvement\n",
              (overall$fixed_05_rmse - overall$adaptive_rmse) / overall$fixed_05_rmse * 100))
  cat(sprintf("  vs Fixed 0.6: %.1f%% RMSE improvement\n",
              (overall$fixed_06_rmse - overall$adaptive_rmse) / overall$fixed_06_rmse * 100))
  cat("\nRECOMMENDATION: Implement adaptive method as default\n")
} else if (overall$fixed_06_rmse < overall$adaptive_rmse &&
           overall$fixed_06_rmse < overall$fixed_05_rmse) {
  cat("~ FIXED 0.6 IS BEST ~\n\n")
  cat("Fixed 0.6 beats adaptive (simpler and better)\n")
  cat("\nRECOMMENDATION: Use fixed 0.6 as default, adaptive as option\n")
} else {
  cat("~ MIXED RESULTS ~\n\n")
  cat("Performance depends on scenario\n")
  cat("\nRECOMMENDATION: Offer both as options, document trade-offs\n")
}

cat("\n=============================================================================\n")
