#!/usr/bin/env Rscript

#' PPV Functional Validation
#'
#' Research Questions:
#' 1. Does the estimated PPV φ̂(F_λ) match the empirical PPV from test studies?
#' 2. Do confidence intervals achieve nominal coverage?
#' 3. Do minimax bounds contain the empirical PPV across mechanisms?

library(devtools)
library(dplyr)
library(tibble)
library(ggplot2)

# Ensure we're in project root
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
N_REPLICATIONS <- 50
N_FUTURE <- 500  # Future study size for hypothesis tests
N_TEST_STUDIES <- 200  # Test studies for empirical PPV
N_INNOVATIONS <- 1000  # For φ̂ estimation

ALPHA <- 0.05
CONFIDENCE_LEVEL <- 0.95

# Scenarios
scenarios <- tibble::tibble(
  name = c("Small λ=0.1", "Moderate λ=0.3", "Large λ=0.5"),
  lambda = c(0.1, 0.3, 0.5)
)

# Q-generation mechanisms
mechanisms <- c("mixture", "covariate_shift", "selection", "extreme")

# Borrow helper functions from 14_decision_validation.R
source("sims/scripts/14_decision_validation.R", local = TRUE)

cat("================================================================\n")
cat("PPV FUNCTIONAL VALIDATION\n")
cat("================================================================\n\n")

cat("Research Questions:\n")
cat("  1. Does estimated φ̂_PPV match empirical PPV?\n")
cat("  2. Do 95% CIs achieve nominal coverage?\n")
cat("  3. Do minimax bounds contain empirical PPV for all mechanisms?\n\n")

cat("Parameters:\n")
cat(sprintf("  Baseline n: %d\n", N_BASELINE))
cat(sprintf("  Replications: %d\n", N_REPLICATIONS))
cat(sprintf("  Test studies per replication: %d\n", N_TEST_STUDIES))
cat(sprintf("  Innovations for φ̂: %d\n", N_INNOVATIONS))

cat("\n----------------------------------------------------------------\n")
cat("Running PPV Validation\n")
cat("----------------------------------------------------------------\n\n")

start_time <- Sys.time()

all_results <- tibble::tibble()

for (s in 1:nrow(scenarios)) {
  scenario <- scenarios[s, ]
  lambda <- scenario$lambda

  cat(sprintf("Scenario: %s\n", scenario$name))

  for (rep in 1:N_REPLICATIONS) {
    if (rep %% 10 == 0 || rep == 1) {
      elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
      rate <- elapsed / ((s - 1) * N_REPLICATIONS + rep)
      remaining <- rate * (nrow(scenarios) * N_REPLICATIONS - (s - 1) * N_REPLICATIONS - rep)
      cat(sprintf("  Replication %d/%d (%.2f min elapsed)\n", rep, N_REPLICATIONS, elapsed))
    }

    # Generate baseline
    baseline <- generate_study_data(
      n = N_BASELINE,
      treatment_effect_surrogate = c(0.3, 0.9),
      treatment_effect_outcome = c(0.2, 0.8)
    )

    # Estimate φ̂_PPV using IF method
    ppv_estimate <- tryCatch({
      result <- surrogate_inference_if(
        baseline,
        lambda = lambda,
        n_innovations = N_INNOVATIONS,
        functional_type = "ppv",
        n_future = N_FUTURE,
        test_alpha = ALPHA
      )
      list(
        estimate = result$estimate,
        ci_lower = result$ci_lower,
        ci_upper = result$ci_upper
      )
    }, error = function(e) {
      list(estimate = NA_real_, ci_lower = NA_real_, ci_upper = NA_real_)
    })

    if (is.na(ppv_estimate$estimate)) next

    # Estimate minimax bounds for PPV
    minimax_bounds <- tryCatch({
      result <- surrogate_inference_minimax(
        baseline,
        lambda = lambda,
        functional_type = "ppv",
        n_innovations = N_INNOVATIONS,
        n_dirichlet_grid = 20,
        include_vertices = FALSE,
        parallel = FALSE,
        verbose = FALSE
      )
      list(
        phi_star_lower = result$phi_star_lower,
        phi_star = result$phi_star,
        bound_width = result$bound_width
      )
    }, error = function(e) {
      list(phi_star_lower = NA_real_, phi_star = NA_real_, bound_width = NA_real_)
    })

    # For each mechanism: compute empirical PPV
    for (mech in mechanisms) {
      test_results <- generate_test_studies_and_decide(
        baseline = baseline,
        lambda = lambda,
        mechanism = mech,
        n_test_studies = N_TEST_STUDIES,
        n_future = N_FUTURE,
        alpha = ALPHA
      )

      if (is.null(test_results)) next

      # Check coverage
      empirical_ppv <- test_results$ppv
      ci_contains_empirical <- !is.na(empirical_ppv) &&
                               (ppv_estimate$ci_lower <= empirical_ppv) &&
                               (empirical_ppv <= ppv_estimate$ci_upper)

      bounds_contain_empirical <- !is.na(empirical_ppv) &&
                                  !is.na(minimax_bounds$phi_star_lower) &&
                                  (minimax_bounds$phi_star_lower <= empirical_ppv) &&
                                  (empirical_ppv <= minimax_bounds$phi_star)

      # Store results
      all_results <- rbind(all_results, tibble::tibble(
        replication = rep,
        scenario = scenario$name,
        lambda = lambda,
        mechanism = mech,
        ppv_estimate = ppv_estimate$estimate,
        ppv_ci_lower = ppv_estimate$ci_lower,
        ppv_ci_upper = ppv_estimate$ci_upper,
        empirical_ppv = empirical_ppv,
        ci_coverage = ci_contains_empirical,
        minimax_lower = minimax_bounds$phi_star_lower,
        minimax_upper = minimax_bounds$phi_star,
        minimax_width = minimax_bounds$bound_width,
        minimax_coverage = bounds_contain_empirical
      ))
    }
  }
  cat("\n")
}

cat("================================================================\n")
cat("RESULTS\n")
cat("================================================================\n\n")

# Coverage rates
cat("Coverage Rates:\n\n")
cat(sprintf("%-20s %-8s %-15s %-15s\n",
            "Mechanism", "λ", "CI Coverage", "Minimax Coverage"))
cat(strrep("-", 70), "\n")

coverage_summary <- all_results %>%
  group_by(mechanism, lambda) %>%
  summarise(
    ci_coverage = mean(ci_coverage, na.rm = TRUE),
    minimax_coverage = mean(minimax_coverage, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  ) %>%
  arrange(lambda, mechanism)

for (i in 1:nrow(coverage_summary)) {
  row <- coverage_summary[i, ]
  cat(sprintf("%-20s %5.2f %14.1f%% %14.1f%%\n",
              row$mechanism,
              row$lambda,
              row$ci_coverage * 100,
              row$minimax_coverage * 100))
}

cat("\nOverall Coverage:\n")
cat(sprintf("  Standard CI: %.1f%% (target: 95%%)\n",
            mean(all_results$ci_coverage, na.rm = TRUE) * 100))
cat(sprintf("  Minimax bounds: %.1f%% (target: 100%%)\n",
            mean(all_results$minimax_coverage, na.rm = TRUE) * 100))

# Estimation accuracy
cat("\n")
cat("Estimation Accuracy (φ̂_PPV vs empirical PPV):\n\n")

accuracy_summary <- all_results %>%
  group_by(mechanism, lambda) %>%
  summarise(
    mean_estimate = mean(ppv_estimate, na.rm = TRUE),
    mean_empirical = mean(empirical_ppv, na.rm = TRUE),
    mean_bias = mean(ppv_estimate - empirical_ppv, na.rm = TRUE),
    rmse = sqrt(mean((ppv_estimate - empirical_ppv)^2, na.rm = TRUE)),
    .groups = "drop"
  )

cat(sprintf("%-20s %-8s %-10s %-10s %-10s\n",
            "Mechanism", "λ", "φ̂_PPV", "Empirical", "Bias"))
cat(strrep("-", 70), "\n")

for (i in 1:nrow(accuracy_summary)) {
  row <- accuracy_summary[i, ]
  cat(sprintf("%-20s %5.2f %9.3f %9.3f %+9.3f\n",
              row$mechanism,
              row$lambda,
              row$mean_estimate,
              row$mean_empirical,
              row$mean_bias))
}

# Minimax width
cat("\n")
cat("Minimax Bound Width:\n\n")

width_summary <- all_results %>%
  group_by(lambda) %>%
  summarise(
    mean_width = mean(minimax_width, na.rm = TRUE),
    median_width = median(minimax_width, na.rm = TRUE),
    .groups = "drop"
  )

for (i in 1:nrow(width_summary)) {
  row <- width_summary[i, ]
  cat(sprintf("  λ=%.1f: mean width = %.3f\n", row$lambda, row$mean_width))
}

# Save results
if (!dir.exists("sims/results")) {
  dir.create("sims/results", recursive = TRUE)
}

saveRDS(all_results, "sims/results/ppv_validation_detailed.rds")
cat("\n  Saved: sims/results/ppv_validation_detailed.rds\n")

cat("\n================================================================\n")
cat("INTERPRETATION\n")
cat("================================================================\n\n")

overall_ci_coverage <- mean(all_results$ci_coverage, na.rm = TRUE)
overall_minimax_coverage <- mean(all_results$minimax_coverage, na.rm = TRUE)
overall_bias <- mean(all_results$ppv_estimate - all_results$empirical_ppv, na.rm = TRUE)

if (overall_ci_coverage >= 0.93 && overall_ci_coverage <= 0.97) {
  cat("✓ Standard CI achieves nominal coverage (~95%)\n")
} else if (overall_ci_coverage < 0.90) {
  cat("✗ Standard CI under-covers (<90%)\n")
} else {
  cat("~ Standard CI coverage acceptable but not ideal\n")
}

if (overall_minimax_coverage >= 0.95) {
  cat("✓ Minimax bounds achieve guaranteed coverage (≥95%)\n")
} else {
  cat("✗ Minimax bounds fail to achieve guaranteed coverage\n")
}

if (abs(overall_bias) < 0.05) {
  cat("✓ Estimated φ̂_PPV is approximately unbiased (<5% bias)\n")
} else {
  cat(sprintf("~ Estimated φ̂_PPV has bias of %+.3f\n", overall_bias))
}

cat("\n")
cat("================================================================\n")
cat("PPV validation complete!\n")
cat("================================================================\n")
