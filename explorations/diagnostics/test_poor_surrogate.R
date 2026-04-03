#!/usr/bin/env Rscript

#' Quick Test: PPV with POOR SURROGATE (5 reps)
#'
#' Tests what happens when surrogate is poor (low correlation, low PPV)

library(devtools)
library(dplyr)
library(tibble)

while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

devtools::load_all("package/", quiet = TRUE)

set.seed(20260323)

# Parameters
N_BASELINE <- 500
N_REPLICATIONS <- 5  # Just 5 for quick test
N_TRUE_STUDIES <- 500
N_INNOVATIONS <- 500

cat("================================================================\n")
cat("QUICK TEST: POOR SURROGATE\n")
cat("================================================================\n\n")

cat("Testing TWO DGP scenarios:\n")
cat("  1. GOOD surrogate: TE_S = (0.3, 0.9), TE_Y = (0.2, 0.8)\n")
cat("  2. POOR surrogate: TE_S = (0.3, 0.8), TE_Y = (-0.3, 0.2)\n\n")

results <- tibble::tibble()

for (dgp_type in c("good", "poor")) {

  if (dgp_type == "good") {
    te_surrogate <- c(0.3, 0.9)
    te_outcome <- c(0.2, 0.8)
    cat("Testing GOOD SURROGATE:\n")
  } else {
    te_surrogate <- c(0.3, 0.8)
    te_outcome <- c(-0.3, 0.2)  # Can be negative!
    cat("\nTesting POOR SURROGATE:\n")
  }

  lambda <- 0.3

  for (rep in 1:N_REPLICATIONS) {

    # Generate baseline with specified DGP
    baseline <- generate_study_data(
      n = N_BASELINE,
      treatment_effect_surrogate = te_surrogate,
      treatment_effect_outcome = te_outcome,
      surrogate_type = "continuous",
      outcome_type = "continuous"
    )

    # Compute TRUE PPV
    n <- nrow(baseline)
    innovations <- MCMCpack::rdirichlet(N_TRUE_STUDIES, rep(1, n))
    true_effects <- matrix(NA, nrow = N_TRUE_STUDIES, ncol = 2)

    for (m in 1:N_TRUE_STUDIES) {
      p0_weights <- rep(1/n, n)
      p_tilde <- innovations[m, ]
      q_weights <- (1 - lambda) * p0_weights + lambda * p_tilde

      delta_s <- compute_treatment_effect_weighted(baseline, "S", q_weights)
      delta_y <- compute_treatment_effect_weighted(baseline, "Y", q_weights)
      true_effects[m, ] <- c(delta_s, delta_y)
    }

    # TRUE PPV and correlation
    true_correlation <- cor(true_effects[, 1], true_effects[, 2])

    exceed_s <- true_effects[, 1] > 0
    true_ppv <- if (sum(exceed_s) > 0) {
      sum(true_effects[, 1] > 0 & true_effects[, 2] > 0) / sum(exceed_s)
    } else {
      NA_real_
    }

    # Estimate PPV
    method_result <- tryCatch({
      surrogate_inference_if(
        baseline,
        lambda = lambda,
        n_innovations = N_INNOVATIONS,
        functional_type = "ppv",
        epsilon_s = 0,
        epsilon_y = 0
      )
    }, error = function(e) NULL)

    if (is.null(method_result)) next

    covered <- (true_ppv >= method_result$ci_lower) &&
               (true_ppv <= method_result$ci_upper)

    cat(sprintf("  Rep %d: True corr=%.3f, True PPV=%.3f, Est PPV=%.3f [%.3f, %.3f], Covered=%s\n",
                rep, true_correlation, true_ppv,
                method_result$estimate,
                method_result$ci_lower,
                method_result$ci_upper,
                ifelse(covered, "YES", "NO")))

    results <- rbind(results, tibble::tibble(
      dgp_type = dgp_type,
      replication = rep,
      true_correlation = true_correlation,
      true_ppv = true_ppv,
      method_estimate = method_result$estimate,
      method_ci_lower = method_result$ci_lower,
      method_ci_upper = method_result$ci_upper,
      covered = covered
    ))
  }
}

cat("\n")
cat("================================================================\n")
cat("SUMMARY\n")
cat("================================================================\n\n")

summary_stats <- results %>%
  group_by(dgp_type) %>%
  summarise(
    n = n(),
    mean_true_corr = mean(true_correlation),
    mean_true_ppv = mean(true_ppv),
    mean_est_ppv = mean(method_estimate),
    coverage = mean(covered),
    .groups = "drop"
  )

print(summary_stats)

cat("\n")
cat("Key Findings:\n\n")

good_stats <- summary_stats %>% filter(dgp_type == "good")
poor_stats <- summary_stats %>% filter(dgp_type == "poor")

cat(sprintf("GOOD SURROGATE:\n"))
cat(sprintf("  True correlation: %.3f\n", good_stats$mean_true_corr))
cat(sprintf("  True PPV: %.3f\n", good_stats$mean_true_ppv))
cat(sprintf("  Estimated PPV: %.3f\n", good_stats$mean_est_ppv))
cat(sprintf("  Coverage: %.0f%% (%d/%d)\n",
            good_stats$coverage * 100,
            sum(results$dgp_type == "good" & results$covered),
            good_stats$n))

cat(sprintf("\nPOOR SURROGATE:\n"))
cat(sprintf("  True correlation: %.3f\n", poor_stats$mean_true_corr))
cat(sprintf("  True PPV: %.3f\n", poor_stats$mean_true_ppv))
cat(sprintf("  Estimated PPV: %.3f\n", poor_stats$mean_est_ppv))
cat(sprintf("  Coverage: %.0f%% (%d/%d)\n",
            poor_stats$coverage * 100,
            sum(results$dgp_type == "poor" & results$covered),
            poor_stats$n))

cat("\n")
cat("Interpretation:\n")
if (poor_stats$mean_true_ppv < 0.8) {
  cat("✓ SUCCESS: Poor surrogate produces PPV < 0.8\n")
  cat("  → This tests whether methods handle low-quality surrogates\n")
} else {
  cat("~ Poor surrogate still has PPV ≥ 0.8\n")
  cat("  → May need even weaker DGP\n")
}

if (poor_stats$coverage >= 0.8) {
  cat("✓ Methods achieve reasonable coverage even with poor surrogate\n")
  cat("  → This is the key result we want!\n")
} else {
  cat("⚠ Coverage lower with poor surrogate - investigate\n")
}

cat("\n")
cat("================================================================\n")
cat("Test complete!\n")
cat("================================================================\n")
