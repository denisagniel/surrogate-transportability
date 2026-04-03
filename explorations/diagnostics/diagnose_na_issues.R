#!/usr/bin/env Rscript

#' Diagnose NA Issues in PPV/NPV Estimation

library(devtools)
library(dplyr)

while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

devtools::load_all("package/", quiet = TRUE)
source("package/R/data_generators_corrected.R")

set.seed(20260323)

cat("================================================================\n")
cat("DIAGNOSING NA ISSUES IN PPV/NPV ESTIMATION\n")
cat("================================================================\n\n")

# Test parameters
lambda <- 0.3
te_s <- c(-0.6, -0.2, 0.2, 0.6)
te_y <- c(-0.5, -0.1, 0.1, 0.5)

cat("Test Configuration:\n")
cat("  DGP: EXCELLENT (high PPV + high NPV)\n")
cat("  TE_S:", te_s, "\n")
cat("  TE_Y:", te_y, "\n")
cat("  Lambda:", lambda, "\n\n")

# Generate one baseline
baseline <- generate_study_data_no_mediation(
  n = 1000,
  n_classes = 4,
  class_probs = c(0.25, 0.25, 0.25, 0.25),
  treatment_effect_surrogate = te_s,
  treatment_effect_outcome = te_y,
  surrogate_type = "continuous",
  outcome_type = "continuous"
)

cat("Baseline Generated:\n")
cat(sprintf("  n = %d\n", nrow(baseline)))
cat(sprintf("  Overall TE_S: %.3f\n",
            mean(baseline$S[baseline$A == 1]) - mean(baseline$S[baseline$A == 0])))
cat(sprintf("  Overall TE_Y: %.3f\n",
            mean(baseline$Y[baseline$A == 1]) - mean(baseline$Y[baseline$A == 0])))

# Check class distribution
class_dist <- table(baseline$class)
cat("\n  Class distribution:\n")
for (i in 1:4) {
  cat(sprintf("    Class %d: %d (%.1f%%)\n", i, class_dist[i],
              class_dist[i] / nrow(baseline) * 100))
}

cat("\n")
cat("================================================================\n")
cat("TEST 1: Check Treatment Effect Distribution from Reweighting\n")
cat("================================================================\n\n")

# Generate innovations via IF method approach (what the method uses)
n_innovations <- 500
innovations <- MCMCpack::rdirichlet(n_innovations, rep(1, nrow(baseline)))

treatment_effects <- matrix(NA, n_innovations, 2)

for (m in 1:n_innovations) {
  p_hat <- rep(1/nrow(baseline), nrow(baseline))
  p_tilde <- innovations[m, ]
  q_weights <- (1 - lambda) * p_hat + lambda * p_tilde

  treatment_effects[m, 1] <- compute_treatment_effect_weighted(baseline, "S", q_weights)
  treatment_effects[m, 2] <- compute_treatment_effect_weighted(baseline, "Y", q_weights)
}

cat("Treatment Effects from Reweighting (IF method uses this):\n")
cat(sprintf("  ΔS: Mean=%.3f, SD=%.3f, Range=[%.3f, %.3f]\n",
            mean(treatment_effects[, 1]), sd(treatment_effects[, 1]),
            min(treatment_effects[, 1]), max(treatment_effects[, 1])))
cat(sprintf("  ΔY: Mean=%.3f, SD=%.3f, Range=[%.3f, %.3f]\n",
            mean(treatment_effects[, 2]), sd(treatment_effects[, 2]),
            min(treatment_effects[, 2]), max(treatment_effects[, 2])))

# Check distribution across zero
n_positive_s <- sum(treatment_effects[, 1] > 0)
n_negative_s <- sum(treatment_effects[, 1] <= 0)
n_positive_y <- sum(treatment_effects[, 2] > 0)
n_negative_y <- sum(treatment_effects[, 2] <= 0)

cat(sprintf("\n  ΔS > 0: %d (%.1f%%)\n", n_positive_s, n_positive_s / n_innovations * 100))
cat(sprintf("  ΔS ≤ 0: %d (%.1f%%)\n", n_negative_s, n_negative_s / n_innovations * 100))
cat(sprintf("  ΔY > 0: %d (%.1f%%)\n", n_positive_y, n_positive_y / n_innovations * 100))
cat(sprintf("  ΔY ≤ 0: %d (%.1f%%)\n", n_negative_y, n_negative_y / n_innovations * 100))

if (n_positive_s == 0 || n_negative_s == 0) {
  cat("\n⚠ WARNING: All treatment effects on same side of zero for S!\n")
  cat("  → PPV or NPV will be undefined\n")
}

if (n_positive_y == 0 || n_negative_y == 0) {
  cat("\n⚠ WARNING: All treatment effects on same side of zero for Y!\n")
  cat("  → PPV or NPV may be all 0 or all 1\n")
}

cat("\n")
cat("================================================================\n")
cat("TEST 2: Manually Compute PPV and NPV\n")
cat("================================================================\n\n")

# Manual PPV computation
exceed_s <- treatment_effects[, 1] > 0
if (sum(exceed_s) > 0) {
  ppv_manual <- sum(treatment_effects[, 1] > 0 & treatment_effects[, 2] > 0) / sum(exceed_s)
  cat(sprintf("Manual PPV: %.3f (%d positive S, %d also positive Y)\n",
              ppv_manual, sum(exceed_s),
              sum(treatment_effects[, 1] > 0 & treatment_effects[, 2] > 0)))
} else {
  cat("Manual PPV: NA (no positive effects on S)\n")
  ppv_manual <- NA
}

# Manual NPV computation
not_exceed_s <- treatment_effects[, 1] <= 0
if (sum(not_exceed_s) > 0) {
  npv_manual <- sum(treatment_effects[, 1] <= 0 & treatment_effects[, 2] <= 0) / sum(not_exceed_s)
  cat(sprintf("Manual NPV: %.3f (%d non-positive S, %d also non-positive Y)\n",
              npv_manual, sum(not_exceed_s),
              sum(treatment_effects[, 1] <= 0 & treatment_effects[, 2] <= 0)))
} else {
  cat("Manual NPV: NA (no non-positive effects on S)\n")
  npv_manual <- NA
}

cat("\n")
cat("================================================================\n")
cat("TEST 3: Run surrogate_inference_if() with Different M Values\n")
cat("================================================================\n\n")

m_values <- c(100, 500, 1000, 2000, 5000)

for (m in m_values) {
  cat(sprintf("Testing with M = %d innovations:\n", m))

  # PPV
  ppv_result <- tryCatch({
    surrogate_inference_if(
      baseline, lambda = lambda, n_innovations = m,
      functional_type = "ppv", epsilon_s = 0, epsilon_y = 0
    )
  }, error = function(e) {
    list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA, error = e$message)
  })

  if (is.na(ppv_result$estimate)) {
    cat(sprintf("  PPV: NA (Error: %s)\n", ppv_result$error))
  } else {
    cat(sprintf("  PPV: %.3f (SE=%.3f, CI=[%.3f, %.3f])\n",
                ppv_result$estimate, ppv_result$se,
                ppv_result$ci_lower, ppv_result$ci_upper))
  }

  # NPV
  npv_result <- tryCatch({
    surrogate_inference_if(
      baseline, lambda = lambda, n_innovations = m,
      functional_type = "npv", epsilon_s = 0, epsilon_y = 0
    )
  }, error = function(e) {
    list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA, error = e$message)
  })

  if (is.na(npv_result$estimate)) {
    cat(sprintf("  NPV: NA (Error: %s)\n", npv_result$error))
  } else {
    cat(sprintf("  NPV: %.3f (SE=%.3f, CI=[%.3f, %.3f])\n",
                npv_result$estimate, npv_result$se,
                npv_result$ci_lower, npv_result$ci_upper))
  }

  cat("\n")
}

cat("================================================================\n")
cat("TEST 4: Check Variance in Baseline Data\n")
cat("================================================================\n\n")

# Check if baseline has enough variation
s_var <- var(baseline$S)
y_var <- var(baseline$Y)
s_by_a <- baseline %>% group_by(A) %>% summarise(mean_s = mean(S), var_s = var(S))
y_by_a <- baseline %>% group_by(A) %>% summarise(mean_y = mean(Y), var_y = var(Y))

cat("Baseline Variance:\n")
cat(sprintf("  Var(S): %.3f\n", s_var))
cat(sprintf("  Var(Y): %.3f\n", y_var))

cat("\nBy Treatment Group:\n")
cat("  S:\n")
print(s_by_a)
cat("  Y:\n")
print(y_by_a)

if (s_var < 0.01 || y_var < 0.01) {
  cat("\n⚠ WARNING: Very low variance in baseline!\n")
  cat("  → May cause numerical issues\n")
}

cat("\n")
cat("================================================================\n")
cat("TEST 5: Check Gradient Computation\n")
cat("================================================================\n\n")

# Try to manually check gradient computation issues
cat("Checking if gradient computation succeeds...\n")

ppv_result_detailed <- tryCatch({
  result <- surrogate_inference_if(
    baseline, lambda = lambda, n_innovations = 1000,
    functional_type = "ppv", epsilon_s = 0, epsilon_y = 0
  )

  cat("  PPV gradient computation: SUCCESS\n")
  cat(sprintf("  Gradient: [%.4f, %.4f]\n", result$gradient[1], result$gradient[2]))
  cat(sprintf("  Variance matrix:\n"))
  print(result$variance_matrix)
  cat(sprintf("  Sigma-squared: %.6f\n", result$sigma_squared))

  result
}, error = function(e) {
  cat("  PPV gradient computation: FAILED\n")
  cat(sprintf("  Error: %s\n", e$message))
  NULL
})

cat("\n")

npv_result_detailed <- tryCatch({
  result <- surrogate_inference_if(
    baseline, lambda = lambda, n_innovations = 1000,
    functional_type = "npv", epsilon_s = 0, epsilon_y = 0
  )

  cat("  NPV gradient computation: SUCCESS\n")
  cat(sprintf("  Gradient: [%.4f, %.4f]\n", result$gradient[1], result$gradient[2]))
  cat(sprintf("  Variance matrix:\n"))
  print(result$variance_matrix)
  cat(sprintf("  Sigma-squared: %.6f\n", result$sigma_squared))

  result
}, error = function(e) {
  cat("  NPV gradient computation: FAILED\n")
  cat(sprintf("  Error: %s\n", e$message))
  NULL
})

cat("\n")
cat("================================================================\n")
cat("DIAGNOSIS SUMMARY\n")
cat("================================================================\n\n")

issues_found <- c()

if (!is.na(ppv_manual) && ppv_manual > 0.9) {
  cat("✓ True PPV is high (%.3f) - DGP is working correctly\n", ppv_manual)
} else if (is.na(ppv_manual)) {
  cat("✗ PPV undefined - all ΔS on same side of threshold\n")
  issues_found <- c(issues_found, "PPV undefined due to no variation across threshold")
}

if (!is.na(npv_manual) && npv_manual > 0.9) {
  cat(sprintf("✓ True NPV is high (%.3f) - DGP is working correctly\n", npv_manual))
} else if (is.na(npv_manual)) {
  cat("✗ NPV undefined - all ΔS on same side of threshold\n")
  issues_found <- c(issues_found, "NPV undefined due to no variation across threshold")
}

if (sd(treatment_effects[, 1]) < 0.01 || sd(treatment_effects[, 2]) < 0.01) {
  cat("⚠ Very low SD in treatment effects from reweighting\n")
  issues_found <- c(issues_found, "Low variation in reweighted treatment effects")
}

if (!is.null(ppv_result_detailed) && is.na(ppv_result_detailed$estimate)) {
  cat("✗ PPV estimation returns NA\n")
  issues_found <- c(issues_found, "PPV estimation fails")
}

if (!is.null(npv_result_detailed) && is.na(npv_result_detailed$estimate)) {
  cat("✗ NPV estimation returns NA\n")
  issues_found <- c(issues_found, "NPV estimation fails")
}

if (!is.null(ppv_result_detailed) && !is.na(ppv_result_detailed$se) &&
    ppv_result_detailed$se > 1) {
  cat(sprintf("⚠ Very large PPV SE (%.3f)\n", ppv_result_detailed$se))
  issues_found <- c(issues_found, "Unstable PPV standard error")
}

if (!is.null(npv_result_detailed) && !is.na(npv_result_detailed$se) &&
    npv_result_detailed$se > 1) {
  cat(sprintf("⚠ Very large NPV SE (%.3f)\n", npv_result_detailed$se))
  issues_found <- c(issues_found, "Unstable NPV standard error")
}

cat("\n")
if (length(issues_found) == 0) {
  cat("✓ No major issues detected\n")
  cat("  → NAs in quick test may be random variation\n")
  cat("  → Consider increasing M for more stable estimates\n")
} else {
  cat("Issues Found:\n")
  for (i in seq_along(issues_found)) {
    cat(sprintf("  %d. %s\n", i, issues_found[i]))
  }
}

cat("\n")
cat("RECOMMENDATIONS:\n")
cat("-----------------\n")

if (sd(treatment_effects[, 1]) < 0.01) {
  cat("1. CRITICAL: Reweighting produces very little variation in ΔS\n")
  cat("   → This is the fundamental problem we identified!\n")
  cat("   → Must use independent sampling for ground truth\n")
  cat("   → Method estimation may still have issues with reweighting\n\n")
}

if (n_positive_s < 50 || n_negative_s < 50) {
  cat("2. Imbalanced ΔS distribution (too few on one side)\n")
  cat(sprintf("   → Positive: %d, Negative: %d (out of %d)\n",
              n_positive_s, n_negative_s, n_innovations))
  cat("   → Consider: larger M, or DGP with more balanced class probs\n\n")
}

if (!is.null(ppv_result_detailed) &&
    !is.na(ppv_result_detailed$se) && ppv_result_detailed$se > 0.5) {
  cat("3. Large standard errors indicate estimation instability\n")
  cat("   → Try: M = 2000 or 5000 instead of 1000\n")
  cat("   → Or: Use bootstrap instead of delta method for threshold functionals\n\n")
}

cat("4. FUNDAMENTAL ISSUE: Method still uses reweighting internally\n")
cat("   → Even though we compute TRUE functionals via independent sampling,\n")
cat("   → the METHOD (surrogate_inference_if) still uses reweighting\n")
cat("   → This explains why we get low SD and estimation issues\n\n")

cat("SOLUTION: Either\n")
cat("  (a) Modify surrogate_inference_if to use independent sampling, OR\n")
cat("  (b) Document that method's reweighting is for computational efficiency,\n")
cat("      and validate that it still produces correct coverage\n")

cat("\n")
cat("================================================================\n")
cat("Diagnosis complete!\n")
cat("================================================================\n")
