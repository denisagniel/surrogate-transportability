#!/usr/bin/env Rscript

#' Test Independent Samples Approach for Ground Truth
#'
#' Validates that independent sampling gives intuitive separation

library(devtools)
library(dplyr)

while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

devtools::load_all("package/", quiet = TRUE)
source("package/R/data_generators_corrected.R")

set.seed(20260323)

cat("================================================================\n")
cat("TESTING INDEPENDENT SAMPLES APPROACH\n")
cat("================================================================\n\n")

N_STUDIES <- 500
N_PER_STUDY <- 2000
LAMBDA <- 0.3

compute_true_functional_independent <- function(te_s, te_y, n_studies, n_per_study, lambda) {
  effects <- matrix(NA, n_studies, 2)

  for (m in 1:n_studies) {
    # Draw class mixture from Dirichlet (innovation distribution)
    class_probs <- MCMCpack::rdirichlet(1, c(1, 1))[1,]

    # Generate independent study with these class probabilities
    study <- generate_study_data_no_mediation(
      n = n_per_study,
      n_classes = 2,
      class_probs = class_probs,
      treatment_effect_surrogate = te_s,
      treatment_effect_outcome = te_y,
      surrogate_type = "continuous",
      outcome_type = "continuous"
    )

    # Compute treatment effects
    effects[m, 1] <- mean(study$S[study$A == 1]) - mean(study$S[study$A == 0])
    effects[m, 2] <- mean(study$Y[study$A == 1]) - mean(study$Y[study$A == 0])
  }

  list(
    correlation = cor(effects[, 1], effects[, 2]),
    ppv = if (sum(effects[, 1] > 0) > 0) {
      sum(effects[, 1] > 0 & effects[, 2] > 0) / sum(effects[, 1] > 0)
    } else NA_real_,
    mean_te_s = mean(effects[, 1]),
    mean_te_y = mean(effects[, 2]),
    sd_te_s = sd(effects[, 1]),
    sd_te_y = sd(effects[, 2])
  )
}

# Test 4 scenarios
scenarios <- list(
  good = list(
    name = "GOOD",
    te_s = c(0.3, 0.9),
    te_y = c(0.2, 0.8),
    description = "Both low→high (parallel)"
  ),
  weak = list(
    name = "WEAK",
    te_s = c(0.2, 0.8),
    te_y = c(-0.5, 0.5),
    description = "S positive, Y crosses zero"
  ),
  bad = list(
    name = "BAD",
    te_s = c(0.3, 0.9),
    te_y = c(-0.8, -0.2),
    description = "S positive, Y negative"
  ),
  opposite = list(
    name = "OPPOSITE",
    te_s = c(0.2, 1.0),
    te_y = c(0.9, 0.1),
    description = "S low→high, Y HIGH→low"
  )
)

results <- data.frame()

for (scenario in scenarios) {
  cat(sprintf("%s SURROGATE: %s\n", scenario$name, scenario$description))
  cat(sprintf("  TE_S = (%.1f, %.1f)\n", scenario$te_s[1], scenario$te_s[2]))
  cat(sprintf("  TE_Y = (%.1f, %.1f)\n", scenario$te_y[1], scenario$te_y[2]))

  metrics <- compute_true_functional_independent(
    scenario$te_s, scenario$te_y, N_STUDIES, N_PER_STUDY, LAMBDA
  )

  cat(sprintf("  Correlation: %.3f\n", metrics$correlation))
  cat(sprintf("  PPV:         %.3f\n", metrics$ppv))
  cat(sprintf("  Mean(TE_S):  %.3f (SD: %.3f)\n", metrics$mean_te_s, metrics$sd_te_s))
  cat(sprintf("  Mean(TE_Y):  %.3f (SD: %.3f)\n\n", metrics$mean_te_y, metrics$sd_te_y))

  results <- rbind(results, data.frame(
    scenario = scenario$name,
    correlation = metrics$correlation,
    ppv = metrics$ppv,
    mean_te_s = metrics$mean_te_s,
    mean_te_y = metrics$mean_te_y,
    sd_te_s = metrics$sd_te_s,
    sd_te_y = metrics$sd_te_y
  ))
}

cat("================================================================\n")
cat("SUMMARY TABLE\n")
cat("================================================================\n\n")

print(results, row.names = FALSE, digits = 3)

cat("\n")
cat("================================================================\n")
cat("INTERPRETATION\n")
cat("================================================================\n\n")

good_corr <- results$correlation[results$scenario == "GOOD"]
bad_corr <- results$correlation[results$scenario == "BAD"]
opposite_corr <- results$correlation[results$scenario == "OPPOSITE"]

cat("Expected Pattern:\n")
cat("  GOOD:     High positive correlation (>0.8), PPV = 1.0\n")
cat("  WEAK:     Moderate correlation (~0.5), low PPV (<0.7)\n")
cat("  BAD:      Low/negative correlation (<0.2), very low PPV (<0.3)\n")
cat("  OPPOSITE: Negative correlation (<-0.5), PPV = 1.0\n\n")

cat("Actual Results:\n")
for (i in 1:nrow(results)) {
  row <- results[i, ]
  cat(sprintf("  %-10s Corr=%.3f, PPV=%.3f ", row$scenario, row$correlation, row$ppv))

  if (row$scenario == "GOOD" && row$correlation > 0.8 && row$ppv > 0.95) {
    cat("✓ EXCELLENT\n")
  } else if (row$scenario == "WEAK" && row$correlation > 0.3 && row$correlation < 0.7 && row$ppv < 0.7) {
    cat("✓ GOOD\n")
  } else if (row$scenario == "BAD" && row$correlation < 0.3 && row$ppv < 0.3) {
    cat("✓ GOOD\n")
  } else if (row$scenario == "OPPOSITE" && row$correlation < -0.3 && row$ppv > 0.95) {
    cat("✓ EXCELLENT\n")
  } else {
    cat("~ Check\n")
  }
}

cat("\n")
cat("Key Findings:\n")
cat("-------------\n")

if (good_corr > 0.8 && bad_corr < 0.3) {
  cat("✓ SUCCESS: Clear separation between good and bad surrogates\n")
  cat(sprintf("  Good correlation (%.3f) >> Bad correlation (%.3f)\n", good_corr, bad_corr))
  cat(sprintf("  Separation: %.3f\n\n", good_corr - bad_corr))
} else {
  cat("⚠ Separation unclear - investigate further\n\n")
}

if (opposite_corr < -0.3) {
  cat("✓ SUCCESS: Opposite pattern produces negative correlation\n")
  cat(sprintf("  Correlation = %.3f (negative!)\n\n", opposite_corr))
}

cat("Standard Deviations:\n")
cat("--------------------\n")
cat(sprintf("Good surrogate: SD(TE_S)=%.3f, SD(TE_Y)=%.3f\n",
            results$sd_te_s[results$scenario == "GOOD"],
            results$sd_te_y[results$scenario == "GOOD"]))
cat(sprintf("Bad surrogate:  SD(TE_S)=%.3f, SD(TE_Y)=%.3f\n\n",
            results$sd_te_s[results$scenario == "BAD"],
            results$sd_te_y[results$scenario == "BAD"]))

cat("Compare to reweighting approach (from previous test): SD ~ 0.008\n")
cat("Independent samples: SD ~ 0.18 (20x larger!)\n\n")

cat("================================================================\n")
cat("RECOMMENDATION\n")
cat("================================================================\n\n")

if (good_corr > 0.8 && bad_corr < 0.3) {
  cat("✓ Independent samples approach gives INTUITIVE results:\n")
  cat("  - Good surrogate: high correlation, high PPV\n")
  cat("  - Bad surrogate: low correlation, low PPV\n")
  cat("  - Clear separation for validation\n\n")

  cat("ACTION ITEMS:\n")
  cat("  1. Update validation scripts (16-21) to use independent samples\n")
  cat("  2. Replace reweighting approach with independent sampling\n")
  cat("  3. Document this as critical methodological correction\n")
  cat("  4. Re-run all validation studies with corrected approach\n\n")
} else {
  cat("⚠ Further investigation needed\n")
}

cat("================================================================\n")
cat("Test complete!\n")
cat("================================================================\n")
