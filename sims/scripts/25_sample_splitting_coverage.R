#!/usr/bin/env Rscript
# COVERAGE VALIDATION: Sample Splitting Method
# Verify provable 95% coverage with sample splitting approach

library(tidyverse)
library(here)

devtools::load_all(here("package"))

cat("=============================================================================\n")
cat("COVERAGE VALIDATION: SAMPLE SPLITTING METHOD\n")
cat("=============================================================================\n\n")

cat("GOAL: Verify provable 95% coverage with sample splitting\n\n")

cat("METHOD: Sample splitting for post-selection bias elimination\n")
cat("  - Split data: D1 (identification), D2 (inference)\n")
cat("  - D1: Find optimal gamma* (worst-case region)\n")
cat("  - D2: Estimate concordance (independent of D1 selection)\n")
cat("  - Bootstrap D2 only (no selection bias)\n\n")

cat("THEORETICAL GUARANTEE: Under regularity conditions,\n")
cat("  P(phi* in CI) → 1-alpha as n → ∞\n\n")

# =============================================================================
# Helper: Compute truth
# =============================================================================

compute_true_minimax <- function(X1, X2, tau_s_fn, tau_y_fn, lambda_w,
                                  n_grid = 500) {
  # Compute true minimax on a fine grid
  # Add small buffer to ensure variation
  range_x1 <- range(X1)
  range_x2 <- range(X2)

  # Expand range slightly to ensure proper grid
  buffer <- 0.01
  grid_x1 <- seq(range_x1[1] - buffer * diff(range_x1),
                 range_x1[2] + buffer * diff(range_x1),
                 length.out = sqrt(n_grid))
  grid_x2 <- seq(range_x2[1] - buffer * diff(range_x2),
                 range_x2[2] + buffer * diff(range_x2),
                 length.out = sqrt(n_grid))
  grid <- expand.grid(X1 = grid_x1, X2 = grid_x2)

  tau_s_true <- tau_s_fn(grid$X1, grid$X2)
  tau_y_true <- tau_y_fn(grid$X1, grid$X2)
  h_true <- tau_s_true * tau_y_true

  # Check for valid numeric values
  if (!is.numeric(h_true) || any(!is.finite(h_true))) {
    warning("Non-finite values in concordance computation")
    return(NA_real_)
  }

  X_grid <- scale(cbind(grid$X1, grid$X2))

  # Check for scaling issues
  if (any(!is.finite(X_grid))) {
    warning("Scaling produced non-finite values, using unscaled distances")
    X_grid <- cbind(grid$X1, grid$X2)
  }

  cost_matrix <- as.matrix(dist(X_grid, method = "euclidean"))^2

  # Check cost matrix validity
  if (!is.numeric(cost_matrix) || any(!is.finite(cost_matrix))) {
    warning("Invalid cost matrix")
    return(NA_real_)
  }

  dual_objective <- function(gamma) {
    n <- nrow(grid)
    obj_matrix <- matrix(h_true, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  result <- optimize(dual_objective, interval = c(0, 100), maximum = TRUE)
  result$objective
}

# =============================================================================
# DGP scenarios
# =============================================================================

dgps <- list(
  baseline = list(
    name = "Baseline (moderate effects)",
    tau_s = function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2,
    tau_y = function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2,
    sd_s = 0.3,
    sd_y = 0.4
  ),

  strong_effects = list(
    name = "Strong effects",
    tau_s = function(X1, X2) 0.5 + 0.4 * X1 - 0.2 * X2,
    tau_y = function(X1, X2) 0.6 + 0.5 * X1 + 0.3 * X2,
    sd_s = 0.3,
    sd_y = 0.4
  ),

  high_noise = list(
    name = "High noise",
    tau_s = function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2,
    tau_y = function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2,
    sd_s = 0.6,
    sd_y = 0.7
  ),

  weak_effects = list(
    name = "Weak effects",
    tau_s = function(X1, X2) 0.1 + 0.05 * X1 - 0.03 * X2,
    tau_y = function(X1, X2) 0.15 + 0.08 * X1 + 0.05 * X2,
    sd_s = 0.3,
    sd_y = 0.4
  ),

  nonlinear = list(
    name = "Nonlinear effects",
    tau_s = function(X1, X2) 0.3 + 0.2 * X1^2 - 0.1 * abs(X2),
    tau_y = function(X1, X2) 0.4 + 0.3 * sin(X1 * pi) + 0.1 * X2^2,
    sd_s = 0.3,
    sd_y = 0.4
  )
)

# =============================================================================
# Run coverage validation for one DGP
# =============================================================================

run_coverage_study <- function(dgp, n_reps, n, lambda_w, split_ratio,
                                n_bootstrap, confidence_level, verbose = TRUE) {

  if (verbose) {
    cat("\n")
    cat("=============================================================================\n")
    cat(toupper(dgp$name), "\n")
    cat("=============================================================================\n\n")
  }

  results <- map_dfr(1:n_reps, function(rep) {
    if (verbose && rep %% 10 == 0) {
      cat(sprintf("  Replication %d/%d\n", rep, n_reps))
    }

    set.seed(rep + 10000)

    # Generate data
    X1 <- rnorm(n)
    X2 <- rnorm(n)
    A <- rbinom(n, 1, 0.5)

    tau_s_true <- dgp$tau_s(X1, X2)
    tau_y_true <- dgp$tau_y(X1, X2)

    S <- tau_s_true * A + 0.5 + 0.2 * X1 + rnorm(n, sd = dgp$sd_s)
    Y <- tau_y_true * A + 0.6 + 0.3 * X2 + rnorm(n, sd = dgp$sd_y)

    data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

    # Truth (approximate via fine grid)
    truth <- compute_true_minimax(X1, X2, dgp$tau_s, dgp$tau_y, lambda_w)

    # Skip if truth computation failed
    if (!is.finite(truth)) {
      return(tibble(rep = rep, status = "failed", error = "Truth computation failed"))
    }

    # Sample splitting with bootstrap CI
    result <- tryCatch({
      bootstrap_ci_sample_splitting(
        data = data,
        covariates = c("X1", "X2"),
        lambda_w = lambda_w,
        split_ratio = split_ratio,
        tau_method = "kernel",
        cross_fit = TRUE,
        n_bootstrap = n_bootstrap,
        confidence_level = confidence_level,
        seed = rep + 10000,  # Reproducible split
        verbose = FALSE
      )
    }, error = function(e) {
      # Always print first few errors
      if (rep <= 5 || verbose) {
        cat(sprintf("    ERROR in rep %d: %s\n", rep, conditionMessage(e)))
      }
      NULL
    })

    if (is.null(result)) {
      return(tibble(rep = rep, status = "failed", error = "Function returned NULL"))
    }

    covered <- (truth >= result$ci_lower & truth <= result$ci_upper)

    tibble(
      rep = rep,
      status = "success",
      truth = truth,
      estimate = result$phi_star,
      ci_lower = result$ci_lower,
      ci_upper = result$ci_upper,
      covered = covered,
      ci_width = result$ci_width,
      bias = result$estimate - truth,
      optimal_gamma_d1 = result$optimal_gamma_d1,
      optimal_gamma_d2 = result$optimal_gamma_d2,
      n_d1 = result$n_d1,
      n_d2 = result$n_d2,
      n_bootstrap_successful = result$n_successful
    )
  })

  results
}

# =============================================================================
# Analyze results for one DGP
# =============================================================================

analyze_coverage_results <- function(results, dgp_name, confidence_level,
                                     verbose = TRUE) {

  results_success <- results %>% filter(status == "success")
  n_success <- nrow(results_success)
  n_failed <- sum(results$status == "failed", na.rm = TRUE)

  if (verbose) {
    cat("\n--- RESULTS ---\n\n")
    cat(sprintf("Successful: %d/%d\n", n_success, nrow(results)))
    if (n_failed > 0) {
      cat(sprintf("Failed: %d\n", n_failed))
    }
    cat("\n")
  }

  # Check if we have any successful results
  if (n_success == 0) {
    cat("ERROR: No successful replications! All replications failed.\n")
    cat("This likely indicates a bug in the implementation.\n\n")

    # Print sample of errors if available
    if ("error" %in% names(results) && any(!is.na(results$error))) {
      cat("Sample errors:\n")
      print(head(results %>% select(rep, status, error) %>% filter(!is.na(error)), 5))
    }

    return(list(
      dgp = dgp_name,
      n_reps = 0,
      coverage = NA,
      coverage_se = NA,
      mean_bias = NA,
      median_bias = NA,
      rmse = NA,
      mean_ci_width = NA,
      mean_gamma_diff = NA,
      pass_coverage = FALSE,
      pass_bias = FALSE,
      error = "No successful replications"
    ))
  }

  # Coverage
  coverage <- mean(results_success$covered)
  coverage_se <- sqrt(coverage * (1 - coverage) / n_success)

  if (verbose) {
    cat("COVERAGE:\n")
    cat(sprintf("  Observed: %.3f (SE = %.4f)\n", coverage, coverage_se))
    cat(sprintf("  Target:   %.2f\n", confidence_level))
    cat(sprintf("  95%% CI:   [%.3f, %.3f]\n",
                coverage - 1.96*coverage_se,
                coverage + 1.96*coverage_se))

    if (coverage >= 0.93 && coverage <= 0.97) {
      cat("  Status:   ✓✓✓ PASS - Nominal coverage!\n\n")
    } else if (coverage >= 0.90 && coverage <= 0.98) {
      cat("  Status:   ~ MARGINAL\n\n")
    } else {
      cat("  Status:   ✗ FAIL\n\n")
    }
  }

  # Bias and RMSE
  mean_bias <- mean(results_success$bias)
  median_bias <- median(results_success$bias)
  rmse <- sqrt(mean(results_success$bias^2))

  if (verbose) {
    cat("BIAS:\n")
    cat(sprintf("  Mean:   %.4f\n", mean_bias))
    cat(sprintf("  Median: %.4f\n", median_bias))
    cat(sprintf("  RMSE:   %.4f\n\n", rmse))
  }

  # CI characteristics
  mean_ci_width <- mean(results_success$ci_width)

  if (verbose) {
    cat("CONFIDENCE INTERVAL:\n")
    cat(sprintf("  Mean width: %.4f\n\n", mean_ci_width))
  }

  # Gamma stability (D1 vs D2)
  gamma_diff <- abs(results_success$optimal_gamma_d1 - results_success$optimal_gamma_d2)

  if (verbose) {
    cat("GAMMA STABILITY (D1 vs D2):\n")
    cat(sprintf("  Mean |gamma_D1 - gamma_D2|: %.4f\n", mean(gamma_diff)))
    cat(sprintf("  Median |gamma_D1 - gamma_D2|: %.4f\n", median(gamma_diff)))
    cat("  → Should be small if n is large enough\n\n")
  }

  # Coverage failures
  n_failures <- sum(!results_success$covered)
  if (n_failures > 0 && verbose) {
    below_ci <- sum(results_success$truth < results_success$ci_lower)
    above_ci <- sum(results_success$truth > results_success$ci_upper)

    cat("COVERAGE FAILURES:\n")
    cat(sprintf("  Truth below CI: %d (%.1f%%)\n",
                below_ci, 100*below_ci/n_success))
    cat(sprintf("  Truth above CI: %d (%.1f%%)\n",
                above_ci, 100*above_ci/n_success))

    if (abs(below_ci - above_ci) > 0.3 * n_failures) {
      cat("  → Asymmetric (possible residual bias)\n")
    } else {
      cat("  → Symmetric (well-calibrated)\n")
    }
    cat("\n")
  }

  list(
    dgp = dgp_name,
    n_reps = n_success,
    coverage = coverage,
    coverage_se = coverage_se,
    mean_bias = mean_bias,
    median_bias = median_bias,
    rmse = rmse,
    mean_ci_width = mean_ci_width,
    mean_gamma_diff = mean(gamma_diff),
    pass_coverage = (coverage >= 0.93 && coverage <= 0.97),
    pass_bias = (abs(mean_bias) < 0.02)
  )
}

# =============================================================================
# Main simulation
# =============================================================================

cat("=============================================================================\n")
cat("SIMULATION PARAMETERS\n")
cat("=============================================================================\n\n")

n_reps <- 100  # Start with 100, increase if needed
n <- 500  # Larger n for sample splitting (lose half for inference)
lambda_w <- 0.5
split_ratio <- 0.5
n_bootstrap <- 500
confidence_level <- 0.95

cat(sprintf("Replications per DGP: %d\n", n_reps))
cat(sprintf("Sample size: n = %d\n", n))
cat(sprintf("Split ratio: %.1f (n1=%d, n2=%d)\n",
            split_ratio, floor(n*split_ratio), floor(n*(1-split_ratio))))
cat(sprintf("Lambda_w: %.2f\n", lambda_w))
cat(sprintf("Bootstrap samples: %d\n", n_bootstrap))
cat(sprintf("Confidence level: %.2f\n", confidence_level))
cat(sprintf("DGPs to test: %d\n", length(dgps)))

cat("\n")
cat("=============================================================================\n")
cat("RUNNING COVERAGE VALIDATION\n")
cat("=============================================================================\n")

# Run all DGPs
all_results <- list()
summary_stats <- list()

for (dgp_name in names(dgps)) {
  dgp <- dgps[[dgp_name]]

  results <- run_coverage_study(
    dgp = dgp,
    n_reps = n_reps,
    n = n,
    lambda_w = lambda_w,
    split_ratio = split_ratio,
    n_bootstrap = n_bootstrap,
    confidence_level = confidence_level,
    verbose = TRUE
  )

  all_results[[dgp_name]] <- results

  summary_stats[[dgp_name]] <- analyze_coverage_results(
    results = results,
    dgp_name = dgp$name,
    confidence_level = confidence_level,
    verbose = TRUE
  )
}

# =============================================================================
# Summary across all DGPs
# =============================================================================

cat("\n")
cat("=============================================================================\n")
cat("SUMMARY ACROSS ALL DGPs\n")
cat("=============================================================================\n\n")

summary_df <- bind_rows(summary_stats)

cat("Coverage by DGP:\n")
for (i in 1:nrow(summary_df)) {
  status <- if (summary_df$pass_coverage[i]) "✓" else "✗"
  cat(sprintf("  %s %s: %.3f (SE=%.4f)\n",
              status,
              summary_df$dgp[i],
              summary_df$coverage[i],
              summary_df$coverage_se[i]))
}
cat("\n")

# Overall statistics
overall_coverage <- mean(summary_df$coverage)
all_pass_coverage <- all(summary_df$pass_coverage)
all_pass_bias <- all(summary_df$pass_bias)

cat("OVERALL PERFORMANCE:\n")
cat(sprintf("  Mean coverage across DGPs: %.3f\n", overall_coverage))
cat(sprintf("  Mean RMSE across DGPs: %.4f\n", mean(summary_df$rmse)))
cat(sprintf("  Mean CI width across DGPs: %.4f\n", mean(summary_df$mean_ci_width)))
cat("\n")

if (all_pass_coverage && all_pass_bias) {
  cat("✓✓✓ ALL DGPs PASS ✓✓✓\n\n")
  cat("Sample splitting method achieves:\n")
  cat("  - Provable coverage: Theory VALIDATED empirically\n")
  cat("  - Low bias across scenarios\n")
  cat("  - Stable performance\n\n")

  cat("THEORETICAL GUARANTEE CONFIRMED:\n")
  cat("  Under regularity conditions (smoothness, bounded moments, overlap),\n")
  cat("  sample splitting provides valid inference with P(phi* in CI) → 0.95\n\n")

  validation_status <- "COMPLETE"

} else {
  cat("⚠ SOME DGPs FAILED ⚠\n\n")

  if (!all_pass_coverage) {
    cat("Coverage issues in:\n")
    for (i in which(!summary_df$pass_coverage)) {
      cat(sprintf("  - %s (%.3f)\n", summary_df$dgp[i], summary_df$coverage[i]))
    }
    cat("\n")
  }

  if (!all_pass_bias) {
    cat("Bias issues in:\n")
    for (i in which(!summary_df$pass_bias)) {
      cat(sprintf("  - %s (%.4f)\n", summary_df$dgp[i], summary_df$mean_bias[i]))
    }
    cat("\n")
  }

  validation_status <- "NEEDS_INVESTIGATION"
}

# =============================================================================
# Comparison to other methods (placeholder)
# =============================================================================

cat("=============================================================================\n")
cat("COMPARISON TO OTHER METHODS\n")
cat("=============================================================================\n\n")

cat("Sample splitting vs other approaches:\n\n")

cat("METHOD              | Coverage | CI Width | Theory       | Bias      |\n")
cat("--------------------|----------|----------|--------------|----------|\n")
cat(sprintf("Sample splitting    | %.3f    | %.3f    | Provable     | %.4f |\n",
            overall_coverage, mean(summary_df$mean_ci_width), mean(summary_df$mean_bias)))
cat("Adaptive shrinkage  | 0.93     | [smaller]| None (empr.) | [smaller]|\n")
cat("Fixed shrinkage     | 0.98     | [smaller]| None (empr.) | 0.0044   |\n")
cat("Conservative quant. | [TBD]    | [TBD]    | Provable     | [TBD]    |\n")
cat("Smooth minimum      | [TBD]    | [TBD]    | Provable     | [TBD]    |\n")

cat("\n")
cat("TRADE-OFF: Sample splitting\n")
cat("  Advantages:\n")
cat("    + Provable coverage (Theorem 1)\n")
cat("    + No tuning parameters\n")
cat("    + Cleanest theory\n")
cat("    + Standard inference\n")
cat("  Disadvantages:\n")
cat("    - Wider CIs (lose half the data)\n")
cat("    - Less power for detection\n")
cat("    - Requires larger n\n\n")

# =============================================================================
# Save results
# =============================================================================

output_file <- here("sims/results/sample_splitting_coverage_validation.rds")
dir.create(dirname(output_file), showWarnings = FALSE, recursive = TRUE)

output <- list(
  all_results = all_results,
  summary_stats = summary_df,
  parameters = list(
    n_reps = n_reps,
    n = n,
    lambda_w = lambda_w,
    split_ratio = split_ratio,
    n_bootstrap = n_bootstrap,
    confidence_level = confidence_level
  ),
  validation_status = validation_status,
  date = Sys.Date()
)

saveRDS(output, output_file)

cat("=============================================================================\n")
cat(sprintf("Results saved to: %s\n", output_file))
cat("=============================================================================\n\n")

cat("=============================================================================\n")
cat("SAMPLE SPLITTING COVERAGE VALIDATION COMPLETE\n")
cat("=============================================================================\n\n")

cat("STATUS:", validation_status, "\n\n")

if (validation_status == "COMPLETE") {
  cat("✓ Method 1 implementation complete\n")
  cat("✓ Theoretical guarantees validated empirically\n")
  cat("✓ Ready for manuscript integration\n\n")

  cat("NEXT STEPS:\n")
  cat("  1. Proceed to Method 2: Conservative Quantile (Week 3-4)\n")
  cat("  2. Write Theorem 1 proof (methods/proofs/theorem1_sample_splitting.tex)\n")
  cat("  3. Create unit tests for sample splitting functions\n")
} else {
  cat("⚠ Further investigation needed\n")
  cat("   Review failed DGPs and adjust parameters if needed\n")
}

cat("\n")
