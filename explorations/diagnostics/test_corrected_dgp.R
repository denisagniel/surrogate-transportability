#!/usr/bin/env Rscript

#' Test Corrected DGP Functions
#'
#' Verifies that the no-mediation DGP produces expected patterns

library(devtools)
library(dplyr)

while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

devtools::load_all("package/", quiet = TRUE)

# Source the corrected DGP
source("package/R/data_generators_corrected.R")

set.seed(20260323)

cat("================================================================\n")
cat("TESTING CORRECTED DGP (NO MEDIATION)\n")
cat("================================================================\n\n")

# Test 1: Good surrogate (S and Y effects co-vary)
cat("Test 1: GOOD SURROGATE\n")
cat("  Treatment effects on S: (0.3, 0.9) - low class, high class\n")
cat("  Treatment effects on Y: (0.2, 0.8) - also low, high\n\n")

data_good <- generate_study_data_no_mediation(
  n = 2000,
  n_classes = 2,
  class_probs = c(0.5, 0.5),
  treatment_effect_surrogate = c(0.3, 0.9),
  treatment_effect_outcome = c(0.2, 0.8),
  surrogate_type = "continuous",
  outcome_type = "continuous"
)

# Compute treatment effects overall
te_s_good <- mean(data_good$S[data_good$A == 1]) - mean(data_good$S[data_good$A == 0])
te_y_good <- mean(data_good$Y[data_good$A == 1]) - mean(data_good$Y[data_good$A == 0])

# Compute by class
te_by_class_good <- data_good %>%
  group_by(class, A) %>%
  summarise(mean_S = mean(S), mean_Y = mean(Y), .groups = "drop") %>%
  group_by(class) %>%
  summarise(te_S = mean_S[A == 1] - mean_S[A == 0],
            te_Y = mean_Y[A == 1] - mean_Y[A == 0],
            .groups = "drop")

cat("Overall Treatment Effects:\n")
cat(sprintf("  TE(S) = %.3f\n", te_s_good))
cat(sprintf("  TE(Y) = %.3f\n", te_y_good))

cat("\nBy Class:\n")
print(te_by_class_good)

# Correlation within study
cor_good <- cor(data_good$S, data_good$Y)
cat(sprintf("\nWithin-study correlation S-Y: %.3f\n", cor_good))

cat("\n" , strrep("-", 70), "\n\n")

# Test 2: Bad surrogate (opposite effects)
cat("Test 2: BAD SURROGATE (Opposite Effects)\n")
cat("  Treatment effects on S: (0.3, 0.9) - positive\n")
cat("  Treatment effects on Y: (-0.8, -0.2) - NEGATIVE!\n\n")

data_bad <- generate_study_data_no_mediation(
  n = 2000,
  n_classes = 2,
  class_probs = c(0.5, 0.5),
  treatment_effect_surrogate = c(0.3, 0.9),
  treatment_effect_outcome = c(-0.8, -0.2),
  surrogate_type = "continuous",
  outcome_type = "continuous"
)

te_s_bad <- mean(data_bad$S[data_bad$A == 1]) - mean(data_bad$S[data_bad$A == 0])
te_y_bad <- mean(data_bad$Y[data_bad$A == 1]) - mean(data_bad$Y[data_bad$A == 0])

te_by_class_bad <- data_bad %>%
  group_by(class, A) %>%
  summarise(mean_S = mean(S), mean_Y = mean(Y), .groups = "drop") %>%
  group_by(class) %>%
  summarise(te_S = mean_S[A == 1] - mean_S[A == 0],
            te_Y = mean_Y[A == 1] - mean_Y[A == 0],
            .groups = "drop")

cat("Overall Treatment Effects:\n")
cat(sprintf("  TE(S) = %.3f (should be ~0.6)\n", te_s_bad))
cat(sprintf("  TE(Y) = %.3f (should be ~-0.5, NEGATIVE!)\n", te_y_bad))

cat("\nBy Class:\n")
print(te_by_class_bad)

cor_bad <- cor(data_bad$S, data_bad$Y)
cat(sprintf("\nWithin-study correlation S-Y: %.3f\n", cor_bad))

cat("\n" , strrep("-", 70), "\n\n")

# Test 3: What matters for surrogate evaluation - CROSS-STUDY correlation
cat("Test 3: CROSS-STUDY TREATMENT EFFECT CORRELATION\n")
cat("(This is what actually matters for surrogate evaluation)\n\n")

# Simulate reweighting to get different population mixtures
lambda <- 0.3
n_studies <- 500

# For GOOD surrogate
effects_good <- matrix(NA, n_studies, 2)
for (m in 1:n_studies) {
  # Draw innovation (mixture weights)
  p_tilde <- MCMCpack::rdirichlet(1, rep(1, nrow(data_good)))
  p0 <- rep(1/nrow(data_good), nrow(data_good))
  q_weights <- (1 - lambda) * p0 + lambda * p_tilde[1,]

  # Compute weighted treatment effects
  effects_good[m, 1] <- sum(q_weights * data_good$S * data_good$A) / sum(q_weights * data_good$A) -
                        sum(q_weights * data_good$S * (1 - data_good$A)) / sum(q_weights * (1 - data_good$A))
  effects_good[m, 2] <- sum(q_weights * data_good$Y * data_good$A) / sum(q_weights * data_good$A) -
                        sum(q_weights * data_good$Y * (1 - data_good$A)) / sum(q_weights * (1 - data_good$A))
}

cor_cross_good <- cor(effects_good[, 1], effects_good[, 2])

# For BAD surrogate
effects_bad <- matrix(NA, n_studies, 2)
for (m in 1:n_studies) {
  p_tilde <- MCMCpack::rdirichlet(1, rep(1, nrow(data_bad)))
  p0 <- rep(1/nrow(data_bad), nrow(data_bad))
  q_weights <- (1 - lambda) * p0 + lambda * p_tilde[1,]

  effects_bad[m, 1] <- sum(q_weights * data_bad$S * data_bad$A) / sum(q_weights * data_bad$A) -
                       sum(q_weights * data_bad$S * (1 - data_bad$A)) / sum(q_weights * (1 - data_bad$A))
  effects_bad[m, 2] <- sum(q_weights * data_bad$Y * data_bad$A) / sum(q_weights * data_bad$A) -
                       sum(q_weights * data_bad$Y * (1 - data_bad$A)) / sum(q_weights * (1 - data_bad$A))
}

cor_cross_bad <- cor(effects_bad[, 1], effects_bad[, 2])

cat("GOOD surrogate:\n")
cat(sprintf("  Cross-study correlation of treatment effects: %.3f\n", cor_cross_good))
cat(sprintf("  Mean TE(S) across studies: %.3f\n", mean(effects_good[, 1])))
cat(sprintf("  Mean TE(Y) across studies: %.3f\n", mean(effects_good[, 2])))

# Compute PPV
exceed_s_good <- effects_good[, 1] > 0
ppv_good <- sum(effects_good[, 1] > 0 & effects_good[, 2] > 0) / sum(exceed_s_good)
cat(sprintf("  PPV (P(TE_Y > 0 | TE_S > 0)): %.3f\n", ppv_good))

cat("\nBAD surrogate:\n")
cat(sprintf("  Cross-study correlation of treatment effects: %.3f\n", cor_cross_bad))
cat(sprintf("  Mean TE(S) across studies: %.3f\n", mean(effects_bad[, 1])))
cat(sprintf("  Mean TE(Y) across studies: %.3f\n", mean(effects_bad[, 2])))

exceed_s_bad <- effects_bad[, 1] > 0
ppv_bad <- sum(effects_bad[, 1] > 0 & effects_bad[, 2] > 0) / sum(exceed_s_bad)
cat(sprintf("  PPV (P(TE_Y > 0 | TE_S > 0)): %.3f\n", ppv_bad))

cat("\n" , strrep("-", 70), "\n\n")

cat("INTERPRETATION:\n\n")

cat("Good Surrogate:\n")
cat(sprintf("  - Within-study S-Y correlation: %.3f (moderate from shared class)\n", cor_good))
cat(sprintf("  - Cross-study TE correlation: %.3f (HIGH - this is what matters!)\n", cor_cross_good))
cat(sprintf("  - PPV: %.3f (S predicts Y well)\n\n", ppv_good))

cat("Bad Surrogate:\n")
cat(sprintf("  - Within-study S-Y correlation: %.3f (moderate from shared class)\n", cor_bad))
cat(sprintf("  - Cross-study TE correlation: %.3f ", cor_cross_bad))
if (cor_cross_bad < 0) {
  cat("(NEGATIVE - S anti-predicts Y!)\n")
} else if (cor_cross_bad < 0.3) {
  cat("(LOW - S doesn't predict Y)\n")
} else {
  cat("(still positive? check DGP)\n")
}
cat(sprintf("  - PPV: %.3f ", ppv_bad))
if (ppv_bad < 0.3) {
  cat("(VERY LOW - S is uninformative or misleading!)\n")
} else if (ppv_bad < 0.6) {
  cat("(LOW - S is poor predictor)\n")
} else {
  cat("(higher than expected - check DGP)\n")
}

cat("\n")
cat("✓ If cross-study correlation is HIGH for good surrogate and LOW/NEGATIVE for bad,\n")
cat("  then the corrected DGP is working as intended!\n\n")

cat("================================================================\n")
cat("Test complete!\n")
cat("================================================================\n")
