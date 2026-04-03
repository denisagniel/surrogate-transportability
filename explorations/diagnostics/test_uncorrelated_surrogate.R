#!/usr/bin/env Rscript

#' Quick Test: UNCORRELATED SURROGATE (5 reps)
#'
#' Tests with surrogate that provides NO information about outcome

library(devtools)
library(dplyr)
library(tibble)

while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

devtools::load_all("package/", quiet = TRUE)
source("package/R/data_generators_corrected.R")

set.seed(20260323)

N_BASELINE <- 500
N_REPLICATIONS <- 5
N_TRUE_STUDIES <- 500
N_INNOVATIONS <- 500

cat("================================================================\n")
cat("QUICK TEST: UNCORRELATED SURROGATE\n")
cat("================================================================\n\n")

cat("Testing THREE DGP scenarios:\n")
cat("  1. GOOD:        TE_S = (0.3, 0.9), TE_Y = (0.2, 0.8)\n")
cat("  2. UNCORRELATED: TE_S = (0.2, 0.8), TE_Y = (-0.5, 0.5)\n")
cat("  3. ANTI-CORRELATED: TE_S = (0.3, 0.9), TE_Y = (-0.8, -0.2)\n\n")

results <- tibble::tibble()

dgp_configs <- list(
  good = list(te_s = c(0.3, 0.9), te_y = c(0.2, 0.8)),
  uncorr = list(te_s = c(0.2, 0.8), te_y = c(-0.5, 0.5)),
  anti = list(te_s = c(0.3, 0.9), te_y = c(-0.8, -0.2))
)

for (dgp_type in names(dgp_configs)) {

  config <- dgp_configs[[dgp_type]]
  cat(sprintf("Testing %s surrogate:\n", toupper(dgp_type)))

  lambda <- 0.3

  for (rep in 1:N_REPLICATIONS) {

    baseline <- generate_study_data_no_mediation(
      n = N_BASELINE,
      treatment_effect_surrogate = config$te_s,
      treatment_effect_outcome = config$te_y,
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

    cat(sprintf("  Rep %d: Corr=%.3f, PPV=%.3f, Est=%.3f [%.3f, %.3f], Cov=%s\n",
                rep, true_correlation, true_ppv,
                method_result$estimate,
                method_result$ci_lower,
                method_result$ci_upper,
                ifelse(covered, "Y", "N")))

    results <- rbind(results, tibble::tibble(
      dgp_type = dgp_type,
      replication = rep,
      true_correlation = true_correlation,
      true_ppv = true_ppv,
      method_estimate = method_result$estimate,
      method_ci_lower = method_result$ci_lower,
      method_ci_upper = method_result$ci_upper,
      ci_width = method_result$ci_upper - method_result$ci_lower,
      covered = covered
    ))
  }
  cat("\n")
}

cat("================================================================\n")
cat("SUMMARY\n")
cat("================================================================\n\n")

summary_stats <- results %>%
  group_by(dgp_type) %>%
  summarise(
    n = n(),
    mean_corr = mean(true_correlation),
    mean_ppv = mean(true_ppv),
    mean_est = mean(method_estimate),
    mean_ci_width = mean(ci_width),
    coverage = mean(covered),
    .groups = "drop"
  ) %>%
  arrange(desc(mean_corr))

print(summary_stats, width = 100)

cat("\n")
cat("Detailed Comparison:\n\n")

for (i in 1:nrow(summary_stats)) {
  row <- summary_stats[i, ]
  cat(sprintf("%s SURROGATE:\n", toupper(row$dgp_type)))
  cat(sprintf("  Correlation: %.3f\n", row$mean_corr))
  cat(sprintf("  True PPV:    %.3f\n", row$mean_ppv))
  cat(sprintf("  Est PPV:     %.3f\n", row$mean_est))
  cat(sprintf("  CI Width:    %.3f\n", row$mean_ci_width))
  cat(sprintf("  Coverage:    %.0f%% (%d/%d)\n",
              row$coverage * 100,
              sum(results$dgp_type == row$dgp_type & results$covered),
              row$n))
  cat("\n")
}

cat("Key Findings:\n\n")

uncorr_row <- summary_stats %>% filter(dgp_type == "uncorr")
anti_row <- summary_stats %>% filter(dgp_type == "anti")

if (nrow(uncorr_row) > 0 && uncorr_row$mean_ppv < 0.7) {
  cat("✓ SUCCESS: Uncorrelated DGP produces PPV < 0.7\n")
  cat("  → Now testing whether methods handle uninformative surrogates\n")
}

if (nrow(anti_row) > 0 && anti_row$mean_corr < 0) {
  cat("✓ SUCCESS: Anti-correlated DGP produces negative correlation\n")
  cat("  → Testing worst-case scenario (misleading surrogate)\n")
}

if (nrow(uncorr_row) > 0 && uncorr_row$coverage >= 0.8) {
  cat("✓ CRITICAL: Methods maintain coverage even with uninformative surrogate\n")
  cat("  → This is the key validation result!\n")
}

cat("\n")
cat("================================================================\n")
cat("Test complete!\n")
cat("================================================================\n")
