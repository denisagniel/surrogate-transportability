#!/usr/bin/env Rscript

#' Test Better DGP Designs for Good vs Bad Surrogates

library(devtools)
library(dplyr)

while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

devtools::load_all("package/", quiet = TRUE)
source("package/R/data_generators_corrected.R")

set.seed(20260323)

cat("================================================================\n")
cat("TESTING BETTER DGP DESIGNS\n")
cat("================================================================\n\n")

compute_cross_study_metrics <- function(data, lambda, n_studies = 500) {
  effects <- matrix(NA, n_studies, 2)
  for (m in 1:n_studies) {
    p_tilde <- MCMCpack::rdirichlet(1, rep(1, nrow(data)))
    p0 <- rep(1/nrow(data), nrow(data))
    q_weights <- (1 - lambda) * p0 + lambda * p_tilde[1,]

    effects[m, 1] <- sum(q_weights * data$S * data$A) / sum(q_weights * data$A) -
                     sum(q_weights * data$S * (1 - data$A)) / sum(q_weights * (1 - data$A))
    effects[m, 2] <- sum(q_weights * data$Y * data$A) / sum(q_weights * data$A) -
                     sum(q_weights * data$Y * (1 - data$A)) / sum(q_weights * (1 - data$A))
  }

  correlation <- cor(effects[, 1], effects[, 2])

  exceed_s <- effects[, 1] > 0
  ppv <- if (sum(exceed_s) > 0) {
    sum(effects[, 1] > 0 & effects[, 2] > 0) / sum(exceed_s)
  } else {
    NA_real_
  }

  list(
    correlation = correlation,
    ppv = ppv,
    mean_te_s = mean(effects[, 1]),
    mean_te_y = mean(effects[, 2]),
    sd_te_s = sd(effects[, 1]),
    sd_te_y = sd(effects[, 2])
  )
}

# ============================================================
# Design 1: OPPOSITE PATTERNS (2 classes)
# ============================================================
cat("Design 1: OPPOSITE PATTERNS ACROSS CLASSES\n")
cat(strrep("=", 70), "\n\n")

cat("Good surrogate: Both low→high\n")
cat("  Class 1: TE_S=0.2, TE_Y=0.1\n")
cat("  Class 2: TE_S=1.0, TE_Y=0.9\n\n")

data_good_1 <- generate_study_data_no_mediation(
  n = 2000, n_classes = 2, class_probs = c(0.5, 0.5),
  treatment_effect_surrogate = c(0.2, 1.0),
  treatment_effect_outcome = c(0.1, 0.9),
  surrogate_type = "continuous", outcome_type = "continuous"
)

metrics_good_1 <- compute_cross_study_metrics(data_good_1, lambda = 0.3)

cat(sprintf("Cross-study correlation: %.3f\n", metrics_good_1$correlation))
cat(sprintf("PPV: %.3f\n", metrics_good_1$ppv))
cat(sprintf("SD(TE_S): %.3f, SD(TE_Y): %.3f\n\n",
            metrics_good_1$sd_te_s, metrics_good_1$sd_te_y))

cat("Bad surrogate: S low→high, Y HIGH→low (opposite!)\n")
cat("  Class 1: TE_S=0.2, TE_Y=0.9\n")
cat("  Class 2: TE_S=1.0, TE_Y=0.1\n\n")

data_bad_1 <- generate_study_data_no_mediation(
  n = 2000, n_classes = 2, class_probs = c(0.5, 0.5),
  treatment_effect_surrogate = c(0.2, 1.0),
  treatment_effect_outcome = c(0.9, 0.1),  # OPPOSITE pattern!
  surrogate_type = "continuous", outcome_type = "continuous"
)

metrics_bad_1 <- compute_cross_study_metrics(data_bad_1, lambda = 0.3)

cat(sprintf("Cross-study correlation: %.3f", metrics_bad_1$correlation))
if (metrics_bad_1$correlation < 0) {
  cat(" ← NEGATIVE! ✓\n")
} else if (metrics_bad_1$correlation < 0.1) {
  cat(" ← Near zero ✓\n")
} else {
  cat(" ← Still positive?\n")
}
cat(sprintf("PPV: %.3f\n", metrics_bad_1$ppv))
cat(sprintf("SD(TE_S): %.3f, SD(TE_Y): %.3f\n\n",
            metrics_bad_1$sd_te_s, metrics_bad_1$sd_te_y))

cat(strrep("-", 70), "\n\n")

# ============================================================
# Design 2: MORE CLASSES (4 classes)
# ============================================================
cat("Design 2: MORE CLASSES FOR MORE VARIATION\n")
cat(strrep("=", 70), "\n\n")

cat("Good surrogate: Monotone increasing\n")
cat("  TE_S: 0.1 → 0.4 → 0.7 → 1.0\n")
cat("  TE_Y: 0.1 → 0.3 → 0.6 → 0.9\n\n")

data_good_2 <- generate_study_data_no_mediation(
  n = 2000, n_classes = 4, class_probs = c(0.25, 0.25, 0.25, 0.25),
  treatment_effect_surrogate = c(0.1, 0.4, 0.7, 1.0),
  treatment_effect_outcome = c(0.1, 0.3, 0.6, 0.9),
  surrogate_type = "continuous", outcome_type = "continuous"
)

metrics_good_2 <- compute_cross_study_metrics(data_good_2, lambda = 0.3)

cat(sprintf("Cross-study correlation: %.3f", metrics_good_2$correlation))
if (metrics_good_2$correlation > 0.5) {
  cat(" ← HIGH! ✓\n")
} else {
  cat(" ← Lower than expected\n")
}
cat(sprintf("PPV: %.3f\n", metrics_good_2$ppv))
cat(sprintf("SD(TE_S): %.3f, SD(TE_Y): %.3f\n\n",
            metrics_good_2$sd_te_s, metrics_good_2$sd_te_y))

cat("Bad surrogate: No pattern\n")
cat("  TE_S: 0.1 → 0.4 → 0.7 → 1.0 (increasing)\n")
cat("  TE_Y: 0.5 → 0.2 → 0.8 → 0.3 (random!)\n\n")

data_bad_2 <- generate_study_data_no_mediation(
  n = 2000, n_classes = 4, class_probs = c(0.25, 0.25, 0.25, 0.25),
  treatment_effect_surrogate = c(0.1, 0.4, 0.7, 1.0),
  treatment_effect_outcome = c(0.5, 0.2, 0.8, 0.3),  # No pattern!
  surrogate_type = "continuous", outcome_type = "continuous"
)

metrics_bad_2 <- compute_cross_study_metrics(data_bad_2, lambda = 0.3)

cat(sprintf("Cross-study correlation: %.3f", metrics_bad_2$correlation))
if (abs(metrics_bad_2$correlation) < 0.2) {
  cat(" ← Near zero! ✓\n")
} else {
  cat("\n")
}
cat(sprintf("PPV: %.3f\n", metrics_bad_2$ppv))
cat(sprintf("SD(TE_S): %.3f, SD(TE_Y): %.3f\n\n",
            metrics_bad_2$sd_te_s, metrics_bad_2$sd_te_y))

cat(strrep("-", 70), "\n\n")

# ============================================================
# Design 3: LARGER LAMBDA (more perturbation)
# ============================================================
cat("Design 3: LARGER LAMBDA FOR MORE VARIATION\n")
cat(strrep("=", 70), "\n\n")

cat("Testing same DGPs with λ=0.5 instead of 0.3\n\n")

cat("Good surrogate (opposite pattern design, λ=0.5):\n")
metrics_good_3 <- compute_cross_study_metrics(data_good_1, lambda = 0.5)
cat(sprintf("  Correlation: %.3f (was %.3f at λ=0.3)\n",
            metrics_good_3$correlation, metrics_good_1$correlation))
cat(sprintf("  SD(TE_S): %.3f, SD(TE_Y): %.3f\n\n",
            metrics_good_3$sd_te_s, metrics_good_3$sd_te_y))

cat("Bad surrogate (opposite pattern design, λ=0.5):\n")
metrics_bad_3 <- compute_cross_study_metrics(data_bad_1, lambda = 0.5)
cat(sprintf("  Correlation: %.3f (was %.3f at λ=0.3)\n",
            metrics_bad_3$correlation, metrics_bad_1$correlation))
cat(sprintf("  SD(TE_S): %.3f, SD(TE_Y): %.3f\n\n",
            metrics_bad_3$sd_te_s, metrics_bad_3$sd_te_y))

cat(strrep("-", 70), "\n\n")

# ============================================================
# SUMMARY
# ============================================================
cat("SUMMARY OF DESIGNS\n")
cat(strrep("=", 70), "\n\n")

results <- data.frame(
  Design = c("Design 1: Opposite (λ=0.3)",
             "Design 1: Opposite (λ=0.3)",
             "Design 2: 4-class (λ=0.3)",
             "Design 2: 4-class (λ=0.3)",
             "Design 3: Opposite (λ=0.5)",
             "Design 3: Opposite (λ=0.5)"),
  Type = rep(c("Good", "Bad"), 3),
  Correlation = c(metrics_good_1$correlation, metrics_bad_1$correlation,
                  metrics_good_2$correlation, metrics_bad_2$correlation,
                  metrics_good_3$correlation, metrics_bad_3$correlation),
  PPV = c(metrics_good_1$ppv, metrics_bad_1$ppv,
          metrics_good_2$ppv, metrics_bad_2$ppv,
          metrics_good_3$ppv, metrics_bad_3$ppv),
  SD_TE_S = c(metrics_good_1$sd_te_s, metrics_bad_1$sd_te_s,
              metrics_good_2$sd_te_s, metrics_bad_2$sd_te_s,
              metrics_good_3$sd_te_s, metrics_bad_3$sd_te_s)
)

print(results, row.names = FALSE)

cat("\n")
cat("RECOMMENDATION:\n\n")

best_good_corr <- max(c(metrics_good_1$correlation, metrics_good_2$correlation, metrics_good_3$correlation))
worst_bad_corr <- min(c(metrics_bad_1$correlation, metrics_bad_2$correlation, metrics_bad_3$correlation))

cat(sprintf("Best good surrogate correlation: %.3f\n", best_good_corr))
cat(sprintf("Worst bad surrogate correlation: %.3f\n", worst_bad_corr))
cat(sprintf("Separation: %.3f\n\n", best_good_corr - worst_bad_corr))

if (best_good_corr > 0.6 && worst_bad_corr < 0.2) {
  cat("✓ EXCELLENT: Clear separation between good and bad surrogates\n")
  cat("  Use this design for validation studies!\n")
} else if (best_good_corr > 0.4 && worst_bad_corr < 0.3) {
  cat("✓ GOOD: Moderate separation\n")
  cat("  Acceptable for validation\n")
} else {
  cat("⚠ WEAK: Limited separation between good and bad\n")
  cat("  Consider: more classes, larger λ, or more extreme TE differences\n")
}

cat("\n")
cat("================================================================\n")
cat("Test complete!\n")
cat("================================================================\n")
