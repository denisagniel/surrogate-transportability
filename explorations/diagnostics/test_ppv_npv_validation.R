#!/usr/bin/env Rscript

#' Test PPV and NPV Validation with 4-Class DGPs
#'
#' Shows that good surrogates need BOTH high PPV and high NPV

library(devtools)
library(dplyr)

while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

devtools::load_all("package/", quiet = TRUE)
source("package/R/data_generators_corrected.R")

set.seed(20260323)

cat("================================================================\n")
cat("PPV + NPV VALIDATION (4-Class DGPs)\n")
cat("================================================================\n\n")

cat("Key Insight: A surrogate needs BOTH:\n")
cat("  - High PPV: P(TE_Y > 0 | TE_S > 0) — positive predictions correct\n")
cat("  - High NPV: P(TE_Y ≤ 0 | TE_S ≤ 0) — negative predictions correct\n\n")

N_STUDIES <- 500
N_PER_STUDY <- 2000

compute_metrics <- function(te_s, te_y, n_classes = 4) {
  effects <- matrix(NA, N_STUDIES, 2)

  for (m in 1:N_STUDIES) {
    # Draw class mixture from Dirichlet
    class_probs <- MCMCpack::rdirichlet(1, rep(1, n_classes))[1,]

    # Generate independent study
    study <- generate_study_data_no_mediation(
      n = N_PER_STUDY,
      n_classes = n_classes,
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

  # PPV: P(TE_Y > 0 | TE_S > 0)
  positive_s <- effects[, 1] > 0
  ppv <- if (sum(positive_s) > 0) {
    sum(effects[, 1] > 0 & effects[, 2] > 0) / sum(positive_s)
  } else NA_real_

  # NPV: P(TE_Y <= 0 | TE_S <= 0)
  negative_s <- effects[, 1] <= 0
  npv <- if (sum(negative_s) > 0) {
    sum(effects[, 1] <= 0 & effects[, 2] <= 0) / sum(negative_s)
  } else NA_real_

  # Correlation
  correlation <- cor(effects[, 1], effects[, 2])

  # Proportion positive
  prop_positive_s <- mean(effects[, 1] > 0)
  prop_positive_y <- mean(effects[, 2] > 0)

  list(
    correlation = correlation,
    ppv = ppv,
    npv = npv,
    prop_positive_s = prop_positive_s,
    prop_positive_y = prop_positive_y,
    mean_te_s = mean(effects[, 1]),
    mean_te_y = mean(effects[, 2]),
    sd_te_s = sd(effects[, 1]),
    sd_te_y = sd(effects[, 2])
  )
}

# Define scenarios with 4 classes for more variation
scenarios <- list(
  excellent = list(
    name = "EXCELLENT",
    te_s = c(-0.6, -0.2, 0.2, 0.6),
    te_y = c(-0.5, -0.1, 0.1, 0.5),
    description = "Both vary neg→pos (parallel)"
  ),
  good = list(
    name = "GOOD",
    te_s = c(-0.4, 0.0, 0.4, 0.8),
    te_y = c(-0.3, 0.0, 0.3, 0.7),
    description = "Both vary around zero"
  ),
  high_ppv_low_npv = list(
    name = "HIGH_PPV_LOW_NPV",
    te_s = c(-0.5, -0.1, 0.3, 0.7),
    te_y = c(0.1, 0.2, 0.3, 0.7),  # Always positive!
    description = "S varies, Y always positive"
  ),
  low_ppv_high_npv = list(
    name = "LOW_PPV_HIGH_NPV",
    te_s = c(-0.7, -0.3, 0.1, 0.5),
    te_y = c(-0.7, -0.5, -0.3, -0.1),  # Always negative!
    description = "S varies, Y always negative"
  ),
  bad = list(
    name = "BAD",
    te_s = c(-0.6, -0.2, 0.2, 0.6),
    te_y = c(0.5, 0.1, -0.1, -0.5),  # OPPOSITE!
    description = "S and Y opposite signs"
  ),
  random = list(
    name = "RANDOM",
    te_s = c(-0.5, 0.1, 0.3, 0.6),
    te_y = c(0.2, -0.4, 0.5, -0.1),  # No pattern
    description = "Y unrelated to S"
  )
)

results <- data.frame()

for (scenario in scenarios) {
  cat(sprintf("%s: %s\n", scenario$name, scenario$description))
  cat(sprintf("  TE_S = (%.1f, %.1f, %.1f, %.1f)\n",
              scenario$te_s[1], scenario$te_s[2], scenario$te_s[3], scenario$te_s[4]))
  cat(sprintf("  TE_Y = (%.1f, %.1f, %.1f, %.1f)\n",
              scenario$te_y[1], scenario$te_y[2], scenario$te_y[3], scenario$te_y[4]))

  metrics <- compute_metrics(scenario$te_s, scenario$te_y, n_classes = 4)

  cat(sprintf("  Correlation: %.3f\n", metrics$correlation))
  cat(sprintf("  PPV:         %.3f (P(Y>0|S>0))\n", metrics$ppv))
  cat(sprintf("  NPV:         %.3f (P(Y≤0|S≤0))\n", metrics$npv))
  cat(sprintf("  Prop S>0:    %.3f\n", metrics$prop_positive_s))
  cat(sprintf("  Prop Y>0:    %.3f\n\n", metrics$prop_positive_y))

  results <- rbind(results, data.frame(
    scenario = scenario$name,
    correlation = metrics$correlation,
    ppv = metrics$ppv,
    npv = metrics$npv,
    prop_positive_s = metrics$prop_positive_s,
    prop_positive_y = metrics$prop_positive_y
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

cat("Surrogate Quality Assessment:\n")
cat("------------------------------\n\n")

for (i in 1:nrow(results)) {
  row <- results[i, ]
  cat(sprintf("%s:\n", row$scenario))
  cat(sprintf("  PPV=%.3f, NPV=%.3f, Corr=%.3f\n", row$ppv, row$npv, row$correlation))

  # Assess quality
  good_ppv <- is.finite(row$ppv) && row$ppv > 0.8
  good_npv <- is.finite(row$npv) && row$npv > 0.8

  if (good_ppv && good_npv) {
    cat("  ✓✓ EXCELLENT: Both PPV and NPV high → surrogate is reliable\n")
  } else if (good_ppv && !good_npv) {
    cat("  ⚠ HIGH PPV, LOW NPV: Good for positive predictions, bad for negatives\n")
  } else if (!good_ppv && good_npv) {
    cat("  ⚠ LOW PPV, HIGH NPV: Good for negative predictions, bad for positives\n")
  } else {
    cat("  ✗ Both PPV and NPV low → surrogate is unreliable\n")
  }

  if (abs(row$correlation) > 0.7) {
    cat(sprintf("  Correlation %.3f suggests %s relationship\n",
                row$correlation,
                ifelse(row$correlation > 0, "strong positive", "strong negative")))
  } else {
    cat("  Correlation low → weak linear relationship\n")
  }
  cat("\n")
}

cat("================================================================\n")
cat("KEY FINDINGS\n")
cat("================================================================\n\n")

excellent_row <- results[results$scenario == "EXCELLENT", ]
high_ppv_row <- results[results$scenario == "HIGH_PPV_LOW_NPV", ]
low_ppv_row <- results[results$scenario == "LOW_PPV_HIGH_NPV", ]
bad_row <- results[results$scenario == "BAD", ]

cat("1. EXCELLENT surrogate:\n")
cat(sprintf("   PPV=%.3f, NPV=%.3f, Corr=%.3f\n", excellent_row$ppv, excellent_row$npv, excellent_row$correlation))
cat("   → Both PPV and NPV high, correlation high\n")
cat("   → This is what a good surrogate looks like\n\n")

cat("2. HIGH_PPV_LOW_NPV surrogate:\n")
cat(sprintf("   PPV=%.3f, NPV=%.3f, Corr=%.3f\n", high_ppv_row$ppv, high_ppv_row$npv, high_ppv_row$correlation))
cat("   → High PPV alone doesn't mean surrogate is useful!\n")
cat("   → Low NPV means it misses negative outcomes\n\n")

cat("3. LOW_PPV_HIGH_NPV surrogate:\n")
cat(sprintf("   PPV=%.3f, NPV=%.3f, Corr=%.3f\n", low_ppv_row$ppv, low_ppv_row$npv, low_ppv_row$correlation))
cat("   → High NPV alone doesn't mean surrogate is useful!\n")
cat("   → Low PPV means it misses positive outcomes\n\n")

cat("4. BAD surrogate (opposite signs):\n")
cat(sprintf("   PPV=%.3f, NPV=%.3f, Corr=%.3f\n", bad_row$ppv, bad_row$npv, bad_row$correlation))
cat("   → Negative correlation indicates opposite relationship\n")
cat("   → Low PPV and NPV confirm surrogate is misleading\n\n")

cat("================================================================\n")
cat("RECOMMENDATION FOR VALIDATION\n")
cat("================================================================\n\n")

cat("Our validation framework should test BOTH:\n")
cat("  1. PPV functional: P(TE_Y > ε | TE_S > ε)\n")
cat("  2. NPV functional: P(TE_Y ≤ ε | TE_S ≤ ε)\n\n")

cat("Validation scenarios should include:\n")
cat("  - EXCELLENT: High PPV + high NPV (methods should detect)\n")
cat("  - HIGH_PPV_LOW_NPV: Shows PPV alone insufficient\n")
cat("  - LOW_PPV_HIGH_NPV: Shows NPV alone insufficient\n")
cat("  - BAD: Low PPV + low NPV (methods should detect)\n\n")

cat("Use 4-class DGPs to get meaningful variation in:\n")
cat("  - Sign of treatment effects (positive/negative)\n")
cat("  - Correlation patterns\n")
cat("  - PPV and NPV values\n\n")

cat("================================================================\n")
cat("Test complete!\n")
cat("================================================================\n")
