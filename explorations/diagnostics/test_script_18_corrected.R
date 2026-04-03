#!/usr/bin/env Rscript

#' Quick Test: Script 18 Corrected (10 reps)

library(devtools)
library(dplyr)
library(tibble)

while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

devtools::load_all("package/", quiet = TRUE)
source("package/R/data_generators_corrected.R")

set.seed(20260323)

cat("================================================================\n")
cat("QUICK TEST: SCRIPT 18 CORRECTED (10 REPS)\n")
cat("================================================================\n\n")

# Test just one scenario: moderate lambda, EXCELLENT DGP
lambda <- 0.3
te_s <- c(-0.6, -0.2, 0.2, 0.6)
te_y <- c(-0.5, -0.1, 0.1, 0.5)

results <- tibble::tibble()
n_degenerate <- 0

for (rep in 1:10) {
  cat(sprintf("Rep %d/10\n", rep))

  # Generate baseline (increased n to reduce degeneracy)
  baseline <- generate_study_data_no_mediation(
    n = 2000,
    n_classes = 4,
    class_probs = c(0.25, 0.25, 0.25, 0.25),
    treatment_effect_surrogate = te_s,
    treatment_effect_outcome = te_y,
    surrogate_type = "continuous",
    outcome_type = "continuous"
  )

  # Compute TRUE functionals via independent sampling
  true_effects <- matrix(NA, 100, 2)  # Just 100 for quick test

  for (m in 1:100) {
    class_probs_m <- MCMCpack::rdirichlet(1, rep(1, 4))[1,]

    new_study <- generate_study_data_no_mediation(
      n = 2000,
      n_classes = 4,
      class_probs = class_probs_m,
      treatment_effect_surrogate = te_s,
      treatment_effect_outcome = te_y,
      surrogate_type = "continuous",
      outcome_type = "continuous"
    )

    delta_s <- mean(new_study$S[new_study$A == 1]) - mean(new_study$S[new_study$A == 0])
    delta_y <- mean(new_study$Y[new_study$A == 1]) - mean(new_study$Y[new_study$A == 0])

    true_effects[m, ] <- c(delta_s, delta_y)
  }

  # TRUE PPV
  exceed_s <- true_effects[, 1] > 0
  if (sum(exceed_s) == 0) {
    cat("  DEGENERATE: No positive S effects\n")
    n_degenerate <- n_degenerate + 1
    next
  }
  true_ppv <- sum(true_effects[, 1] > 0 & true_effects[, 2] > 0) / sum(exceed_s)

  # TRUE NPV
  not_exceed_s <- true_effects[, 1] <= 0
  if (sum(not_exceed_s) == 0) {
    cat("  DEGENERATE: No non-positive S effects\n")
    n_degenerate <- n_degenerate + 1
    next
  }
  true_npv <- sum(true_effects[, 1] <= 0 & true_effects[, 2] <= 0) / sum(not_exceed_s)

  # Check for near-degeneracy
  prop_positive_s <- mean(true_effects[, 1] > 0)
  if (prop_positive_s < 0.05 || prop_positive_s > 0.95) {
    cat(sprintf("  Near-degenerate: %.1f%% positive S\n", prop_positive_s * 100))
  }

  # Estimate PPV
  ppv_result <- tryCatch({
    surrogate_inference_if(
      baseline, lambda = lambda, n_innovations = 2000,
      functional_type = "ppv", epsilon_s = 0, epsilon_y = 0
    )
  }, error = function(e) NULL)

  if (is.null(ppv_result) || is.na(ppv_result$estimate)) {
    cat("  PPV estimation failed\n")
    n_degenerate <- n_degenerate + 1
    next
  }

  # Estimate NPV
  npv_result <- tryCatch({
    surrogate_inference_if(
      baseline, lambda = lambda, n_innovations = 2000,
      functional_type = "npv", epsilon_s = 0, epsilon_y = 0
    )
  }, error = function(e) NULL)

  if (is.null(npv_result) || is.na(npv_result$estimate)) {
    cat("  NPV estimation failed\n")
    n_degenerate <- n_degenerate + 1
    next
  }

  ppv_covered <- (true_ppv >= ppv_result$ci_lower) && (true_ppv <= ppv_result$ci_upper)
  npv_covered <- (true_npv >= npv_result$ci_lower) && (true_npv <= npv_result$ci_upper)

  cat(sprintf("  PPV: True=%.3f, Est=%.3f [%.3f, %.3f], Cov=%s\n",
              true_ppv, ppv_result$estimate,
              ppv_result$ci_lower, ppv_result$ci_upper,
              ifelse(ppv_covered, "Y", "N")))
  cat(sprintf("  NPV: True=%.3f, Est=%.3f [%.3f, %.3f], Cov=%s\n",
              true_npv, npv_result$estimate,
              npv_result$ci_lower, npv_result$ci_upper,
              ifelse(npv_covered, "Y", "N")))

  results <- rbind(results, tibble::tibble(
    rep = rep,
    true_ppv = true_ppv,
    ppv_estimate = ppv_result$estimate,
    ppv_covered = ppv_covered,
    true_npv = true_npv,
    npv_estimate = npv_result$estimate,
    npv_covered = npv_covered
  ))
}

cat("\n")
cat("================================================================\n")
cat("SUMMARY\n")
cat("================================================================\n\n")

cat(sprintf("Successful reps: %d/10\n", nrow(results)))
cat(sprintf("Degenerate cases: %d/10\n\n", n_degenerate))

if (nrow(results) == 0) {
  cat("No successful replications!\n")
  cat("================================================================\n")
  stop("All replications were degenerate")
}

cat(sprintf("PPV Coverage: %.0f%% (%d/%d)\n",
            mean(results$ppv_covered, na.rm = TRUE) * 100,
            sum(results$ppv_covered, na.rm = TRUE),
            nrow(results)))
cat(sprintf("NPV Coverage: %.0f%% (%d/%d)\n",
            mean(results$npv_covered, na.rm = TRUE) * 100,
            sum(results$npv_covered, na.rm = TRUE),
            nrow(results)))

cat(sprintf("\nMean True PPV: %.3f\n", mean(results$true_ppv)))
cat(sprintf("Mean Est PPV:  %.3f\n", mean(results$ppv_estimate)))
cat(sprintf("PPV Bias:      %.4f\n", mean(results$ppv_estimate - results$true_ppv)))

cat(sprintf("\nMean True NPV: %.3f\n", mean(results$true_npv)))
cat(sprintf("Mean Est NPV:  %.3f\n", mean(results$npv_estimate)))
cat(sprintf("NPV Bias:      %.4f\n", mean(results$npv_estimate - results$true_npv)))

if (mean(results$true_ppv) > 0.8 && mean(results$true_npv) > 0.8) {
  cat("\n✓ SUCCESS: EXCELLENT DGP produces high PPV and NPV!\n")
}

if (mean(results$ppv_covered) >= 0.7 && mean(results$npv_covered) >= 0.7) {
  cat("✓ SUCCESS: Methods achieve reasonable coverage (limited sample)\n")
}

cat("\n")
cat("================================================================\n")
cat("Test complete! Ready to run full script 18.\n")
cat("================================================================\n")
