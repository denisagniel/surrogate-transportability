#!/usr/bin/env Rscript

#' Test nested bootstrap implementation
#' Reduced parameters for quick verification

library(devtools)
library(dplyr)
library(tibble)

devtools::load_all("package/", quiet = TRUE)

set.seed(20260313)

N_BASELINE <- 500
N_REPS <- 10  # Just 10 to test
N_TRUE_STUDIES <- 100
N_BASELINE_RESAMPLES <- 20  # Reduced from 100
N_BOOTSTRAP <- 50  # Reduced from 100
N_MC_DRAWS <- 20  # Reduced from 50

cat("================================================================\n")
cat("NESTED BOOTSTRAP TEST\n")
cat("================================================================\n\n")

cat("Parameters (reduced for testing):\n")
cat(sprintf("  Replications: %d\n", N_REPS))
cat(sprintf("  Baseline resamples: %d\n", N_BASELINE_RESAMPLES))
cat(sprintf("  Bootstrap samples: %d\n", N_BOOTSTRAP))
cat(sprintf("  MC draws: %d\n", N_MC_DRAWS))
cat(sprintf("  Total studies/rep: %d\n",
            N_TRUE_STUDIES + N_BASELINE_RESAMPLES * N_BOOTSTRAP * N_MC_DRAWS))

start_time <- Sys.time()

results <- tibble()

for (rep in 1:N_REPS) {
  cat(sprintf("Rep %d/%d...\n", rep, N_REPS))

  baseline <- generate_study_data(
    n = N_BASELINE,
    n_classes = 2,
    class_probs = c(0.5, 0.5),
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8),
    surrogate_type = "continuous",
    outcome_type = "continuous"
  )

  shifted_study <- generate_covariate_shift_study(
    baseline,
    target_class_probs = c(0.6, 0.4),
    n = 500
  )

  # Compute TRUE correlation
  multiple_shifted <- replicate(N_TRUE_STUDIES, {
    shift <- generate_covariate_shift_study(
      baseline,
      target_class_probs = c(0.6, 0.4),
      n = 500
    )
    effects <- compute_multiple_treatment_effects(shift$future_study, c("S", "Y"))
    c(delta_s = effects["S"], delta_y = effects["Y"])
  }, simplify = FALSE)

  shifted_effects_df <- do.call(rbind, multiple_shifted) %>% as.data.frame()
  true_correlation <- cor(shifted_effects_df$delta_s, shifted_effects_df$delta_y)

  # Apply method with nested bootstrap
  method_result <- posterior_inference(
    baseline,
    n_draws_from_F = N_BOOTSTRAP,
    n_future_studies_per_draw = N_MC_DRAWS,
    n_baseline_resamples = N_BASELINE_RESAMPLES,
    lambda = shifted_study$tv_distance,
    functional_type = "correlation",
    innovation_type = "bayesian_bootstrap"
  )

  results <- rbind(results, tibble(
    replication = rep,
    true_correlation = true_correlation,
    method_estimate = method_result$summary$mean,
    method_se = method_result$summary$se,
    ci_lower = method_result$summary$ci_lower,
    ci_upper = method_result$summary$ci_upper,
    q025 = method_result$summary$q025,
    q975 = method_result$summary$q975,
    covered_ci = (true_correlation >= method_result$summary$ci_lower) &&
                 (true_correlation <= method_result$summary$ci_upper),
    covered_quantile = (true_correlation >= method_result$summary$q025) &&
                       (true_correlation <= method_result$summary$q975)
  ))
}

elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
per_rep <- elapsed / N_REPS

cat("\n================================================================\n")
cat("RESULTS\n")
cat("================================================================\n\n")

cat(sprintf("Time: %.2f min total, %.2f min/rep\n\n", elapsed, per_rep))

cat(sprintf("Coverage (CI): %.0f%%\n", mean(results$covered_ci) * 100))
cat(sprintf("Coverage (Quantiles): %.0f%%\n", mean(results$covered_quantile) * 100))

cat("\nCI widths:\n")
cat(sprintf("  Mean CI width: %.3f\n", mean(results$ci_upper - results$ci_lower)))
cat(sprintf("  Mean quantile width: %.3f\n", mean(results$q975 - results$q025)))

cat("\nScaling estimate:\n")
cat(sprintf("  Current: %.2f min/rep with %d total studies\n",
            per_rep, N_TRUE_STUDIES + N_BASELINE_RESAMPLES * N_BOOTSTRAP * N_MC_DRAWS))
cat(sprintf("  Full scale (500,500 studies/rep): ~%.1f min/rep\n",
            per_rep * 500500 / (N_TRUE_STUDIES + N_BASELINE_RESAMPLES * N_BOOTSTRAP * N_MC_DRAWS)))

cat("\n================================================================\n")
