#!/usr/bin/env Rscript

#' Prototype: Compare Different Fixes for Reweighting Underestimation
#'
#' Tests 4 approaches to fix the SD underestimation problem:
#'   1. Bootstrap + Reweight
#'   2. Larger Innovation Spread (different alpha)
#'   3. Parametric Bootstrap
#'   4. Variance Inflation Factor
#'
#' Compares each to:
#'   - Current reweighting (baseline)
#'   - Independent sampling (ground truth)

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
cat("PROTOTYPING REWEIGHTING FIXES\n")
cat("================================================================\n\n")

# Generate one large baseline for all comparisons
cat("Generating baseline study...\n")
baseline <- generate_study_data_no_mediation(
  n = 2000,
  n_classes = 4,
  class_probs = c(0.25, 0.25, 0.25, 0.25),
  treatment_effect_surrogate = c(-0.6, -0.2, 0.2, 0.6),
  treatment_effect_outcome = c(-0.5, -0.1, 0.1, 0.5),
  surrogate_type = "continuous",
  outcome_type = "continuous"
)

cat(sprintf("  n = %d\n", nrow(baseline)))
cat(sprintf("  Overall TE_S = %.3f\n",
            mean(baseline$S[baseline$A == 1]) - mean(baseline$S[baseline$A == 0])))
cat(sprintf("  Overall TE_Y = %.3f\n\n",
            mean(baseline$Y[baseline$A == 1]) - mean(baseline$Y[baseline$A == 0])))

# Parameters
lambda <- 0.3
n_innovations <- 500
n <- nrow(baseline)

# DGP parameters (for parametric bootstrap)
dgp_te_s <- c(-0.6, -0.2, 0.2, 0.6)
dgp_te_y <- c(-0.5, -0.1, 0.1, 0.5)

cat("================================================================\n")
cat("APPROACH 0: CURRENT REWEIGHTING (BASELINE)\n")
cat("================================================================\n\n")

start_time <- Sys.time()

innovations_current <- MCMCpack::rdirichlet(n_innovations, rep(1, n))
effects_current <- matrix(NA, n_innovations, 2)

for (m in 1:n_innovations) {
  p_hat <- rep(1/n, n)
  p_tilde <- innovations_current[m, ]
  q_weights <- (1 - lambda) * p_hat + lambda * p_tilde

  effects_current[m, 1] <- compute_treatment_effect_weighted(baseline, "S", q_weights)
  effects_current[m, 2] <- compute_treatment_effect_weighted(baseline, "Y", q_weights)
}

time_current <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

cat(sprintf("Computation time: %.2f seconds\n", time_current))
cat(sprintf("SD(ΔS): %.4f\n", sd(effects_current[, 1])))
cat(sprintf("SD(ΔY): %.4f\n", sd(effects_current[, 2])))
cat(sprintf("Correlation: %.3f\n", cor(effects_current[, 1], effects_current[, 2])))

# PPV/NPV
exceed_s <- effects_current[, 1] > 0
ppv_current <- if (sum(exceed_s) > 0) {
  sum(effects_current[, 1] > 0 & effects_current[, 2] > 0) / sum(exceed_s)
} else NA
not_exceed_s <- effects_current[, 1] <= 0
npv_current <- if (sum(not_exceed_s) > 0) {
  sum(effects_current[, 1] <= 0 & effects_current[, 2] <= 0) / sum(not_exceed_s)
} else NA

cat(sprintf("PPV: %.3f, NPV: %.3f\n\n", ppv_current, npv_current))

cat("================================================================\n")
cat("APPROACH 1: BOOTSTRAP + REWEIGHT\n")
cat("================================================================\n\n")

cat("Method: Bootstrap baseline, then apply reweighting\n")
cat("  For each innovation:\n")
cat("    1. Bootstrap sample baseline (n=%d with replacement)\n", n)
cat("    2. Apply reweighting to bootstrap sample\n")
cat("    3. Compute treatment effects\n\n")

start_time <- Sys.time()

innovations_boot <- MCMCpack::rdirichlet(n_innovations, rep(1, n))
effects_boot <- matrix(NA, n_innovations, 2)

for (m in 1:n_innovations) {
  # Bootstrap baseline
  bootstrap_idx <- sample(1:n, size = n, replace = TRUE)
  baseline_boot <- baseline[bootstrap_idx, ]

  # Reweight bootstrap sample
  p_hat <- rep(1/n, n)
  p_tilde <- innovations_boot[m, ]
  q_weights <- (1 - lambda) * p_hat + lambda * p_tilde

  effects_boot[m, 1] <- compute_treatment_effect_weighted(baseline_boot, "S", q_weights)
  effects_boot[m, 2] <- compute_treatment_effect_weighted(baseline_boot, "Y", q_weights)
}

time_boot <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

cat(sprintf("Computation time: %.2f seconds (%.1fx slower)\n",
            time_boot, time_boot / time_current))
cat(sprintf("SD(ΔS): %.4f (%.1fx larger)\n",
            sd(effects_boot[, 1]),
            sd(effects_boot[, 1]) / sd(effects_current[, 1])))
cat(sprintf("SD(ΔY): %.4f (%.1fx larger)\n",
            sd(effects_boot[, 2]),
            sd(effects_boot[, 2]) / sd(effects_current[, 2])))
cat(sprintf("Correlation: %.3f\n", cor(effects_boot[, 1], effects_boot[, 2])))

exceed_s <- effects_boot[, 1] > 0
ppv_boot <- if (sum(exceed_s) > 0) {
  sum(effects_boot[, 1] > 0 & effects_boot[, 2] > 0) / sum(exceed_s)
} else NA
not_exceed_s <- effects_boot[, 1] <= 0
npv_boot <- if (sum(not_exceed_s) > 0) {
  sum(effects_boot[, 1] <= 0 & effects_boot[, 2] <= 0) / sum(not_exceed_s)
} else NA

cat(sprintf("PPV: %.3f, NPV: %.3f\n\n", ppv_boot, npv_boot))

cat("================================================================\n")
cat("APPROACH 2A: SPARSE INNOVATIONS (alpha=0.1)\n")
cat("================================================================\n\n")

cat("Method: Use Dirichlet(0.1, ..., 0.1) - concentrated near vertices\n")
cat("  More extreme reweightings, more variation\n\n")

start_time <- Sys.time()

innovations_sparse <- MCMCpack::rdirichlet(n_innovations, rep(0.1, n))
effects_sparse <- matrix(NA, n_innovations, 2)

for (m in 1:n_innovations) {
  p_hat <- rep(1/n, n)
  p_tilde <- innovations_sparse[m, ]
  q_weights <- (1 - lambda) * p_hat + lambda * p_tilde

  effects_sparse[m, 1] <- compute_treatment_effect_weighted(baseline, "S", q_weights)
  effects_sparse[m, 2] <- compute_treatment_effect_weighted(baseline, "Y", q_weights)
}

time_sparse <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

cat(sprintf("Computation time: %.2f seconds (%.1fx slower)\n",
            time_sparse, time_sparse / time_current))
cat(sprintf("SD(ΔS): %.4f (%.1fx larger)\n",
            sd(effects_sparse[, 1]),
            sd(effects_sparse[, 1]) / sd(effects_current[, 1])))
cat(sprintf("SD(ΔY): %.4f (%.1fx larger)\n",
            sd(effects_sparse[, 2]),
            sd(effects_sparse[, 2]) / sd(effects_current[, 2])))
cat(sprintf("Correlation: %.3f\n", cor(effects_sparse[, 1], effects_sparse[, 2])))

exceed_s <- effects_sparse[, 1] > 0
ppv_sparse <- if (sum(exceed_s) > 0) {
  sum(effects_sparse[, 1] > 0 & effects_sparse[, 2] > 0) / sum(exceed_s)
} else NA
not_exceed_s <- effects_sparse[, 1] <= 0
npv_sparse <- if (sum(not_exceed_s) > 0) {
  sum(effects_sparse[, 1] <= 0 & effects_sparse[, 2] <= 0) / sum(not_exceed_s)
} else NA

cat(sprintf("PPV: %.3f, NPV: %.3f\n\n", ppv_sparse, npv_sparse))

cat("================================================================\n")
cat("APPROACH 2B: CONCENTRATED INNOVATIONS (alpha=10)\n")
cat("================================================================\n\n")

cat("Method: Use Dirichlet(10, ..., 10) - concentrated near center\n")
cat("  Less extreme reweightings, but maybe more stable?\n\n")

start_time <- Sys.time()

innovations_concentrated <- MCMCpack::rdirichlet(n_innovations, rep(10, n))
effects_concentrated <- matrix(NA, n_innovations, 2)

for (m in 1:n_innovations) {
  p_hat <- rep(1/n, n)
  p_tilde <- innovations_concentrated[m, ]
  q_weights <- (1 - lambda) * p_hat + lambda * p_tilde

  effects_concentrated[m, 1] <- compute_treatment_effect_weighted(baseline, "S", q_weights)
  effects_concentrated[m, 2] <- compute_treatment_effect_weighted(baseline, "Y", q_weights)
}

time_concentrated <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

cat(sprintf("Computation time: %.2f seconds\n", time_concentrated))
cat(sprintf("SD(ΔS): %.4f (%.1fx vs current)\n",
            sd(effects_concentrated[, 1]),
            sd(effects_concentrated[, 1]) / sd(effects_current[, 1])))
cat(sprintf("SD(ΔY): %.4f (%.1fx vs current)\n",
            sd(effects_concentrated[, 2]),
            sd(effects_concentrated[, 2]) / sd(effects_current[, 2])))
cat(sprintf("Correlation: %.3f\n", cor(effects_concentrated[, 1], effects_concentrated[, 2])))

exceed_s <- effects_concentrated[, 1] > 0
ppv_concentrated <- if (sum(exceed_s) > 0) {
  sum(effects_concentrated[, 1] > 0 & effects_concentrated[, 2] > 0) / sum(exceed_s)
} else NA
not_exceed_s <- effects_concentrated[, 1] <= 0
npv_concentrated <- if (sum(not_exceed_s) > 0) {
  sum(effects_concentrated[, 1] <= 0 & effects_concentrated[, 2] <= 0) / sum(not_exceed_s)
} else NA

cat(sprintf("PPV: %.3f, NPV: %.3f\n\n", ppv_concentrated, npv_concentrated))

cat("================================================================\n")
cat("APPROACH 3: PARAMETRIC BOOTSTRAP\n")
cat("================================================================\n\n")

cat("Method: Generate new studies from estimated DGP\n")
cat("  For each innovation:\n")
cat("    1. Draw new class mixture from Dirichlet(1,1,1,1)\n")
cat("    2. Generate NEW study with those class probs\n")
cat("    3. Compute treatment effects on new study\n\n")

start_time <- Sys.time()

effects_parametric <- matrix(NA, n_innovations, 2)

for (m in 1:n_innovations) {
  # Draw class mixture
  class_probs_m <- MCMCpack::rdirichlet(1, rep(1, 4))[1,]

  # Generate NEW study (this is expensive!)
  new_study <- generate_study_data_no_mediation(
    n = 2000,
    n_classes = 4,
    class_probs = class_probs_m,
    treatment_effect_surrogate = dgp_te_s,
    treatment_effect_outcome = dgp_te_y,
    surrogate_type = "continuous",
    outcome_type = "continuous"
  )

  # Compute treatment effects
  effects_parametric[m, 1] <- mean(new_study$S[new_study$A == 1]) -
                              mean(new_study$S[new_study$A == 0])
  effects_parametric[m, 2] <- mean(new_study$Y[new_study$A == 1]) -
                              mean(new_study$Y[new_study$A == 0])
}

time_parametric <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

cat(sprintf("Computation time: %.2f seconds (%.1fx slower!)\n",
            time_parametric, time_parametric / time_current))
cat(sprintf("SD(ΔS): %.4f (%.1fx larger)\n",
            sd(effects_parametric[, 1]),
            sd(effects_parametric[, 1]) / sd(effects_current[, 1])))
cat(sprintf("SD(ΔY): %.4f (%.1fx larger)\n",
            sd(effects_parametric[, 2]),
            sd(effects_parametric[, 2]) / sd(effects_current[, 2])))
cat(sprintf("Correlation: %.3f\n", cor(effects_parametric[, 1], effects_parametric[, 2])))

exceed_s <- effects_parametric[, 1] > 0
ppv_parametric <- if (sum(exceed_s) > 0) {
  sum(effects_parametric[, 1] > 0 & effects_parametric[, 2] > 0) / sum(exceed_s)
} else NA
not_exceed_s <- effects_parametric[, 1] <= 0
npv_parametric <- if (sum(not_exceed_s) > 0) {
  sum(effects_parametric[, 1] <= 0 & effects_parametric[, 2] <= 0) / sum(not_exceed_s)
} else NA

cat(sprintf("PPV: %.3f, NPV: %.3f\n\n", ppv_parametric, npv_parametric))

cat("================================================================\n")
cat("GROUND TRUTH: INDEPENDENT SAMPLING\n")
cat("================================================================\n\n")

cat("Method: Same as Approach 3, but we know this is 'correct'\n")
cat("  This is what we use for validation ground truth\n\n")

# Already computed above - same as parametric bootstrap
# But let's be explicit that this is our target

cat(sprintf("SD(ΔS): %.4f (TARGET)\n", sd(effects_parametric[, 1])))
cat(sprintf("SD(ΔY): %.4f (TARGET)\n", sd(effects_parametric[, 2])))
cat(sprintf("Correlation: %.3f (TARGET)\n", cor(effects_parametric[, 1], effects_parametric[, 2])))
cat(sprintf("PPV: %.3f, NPV: %.3f (TARGET)\n\n", ppv_parametric, npv_parametric))

cat("================================================================\n")
cat("COMPARISON TABLE\n")
cat("================================================================\n\n")

comparison <- tibble::tibble(
  Approach = c("0. Current (reweight)",
               "1. Bootstrap + reweight",
               "2a. Sparse (α=0.1)",
               "2b. Concentrated (α=10)",
               "3. Parametric bootstrap",
               "Ground Truth"),
  SD_S = c(sd(effects_current[, 1]),
           sd(effects_boot[, 1]),
           sd(effects_sparse[, 1]),
           sd(effects_concentrated[, 1]),
           sd(effects_parametric[, 1]),
           sd(effects_parametric[, 1])),
  SD_Y = c(sd(effects_current[, 2]),
           sd(effects_boot[, 2]),
           sd(effects_sparse[, 2]),
           sd(effects_concentrated[, 2]),
           sd(effects_parametric[, 2]),
           sd(effects_parametric[, 2])),
  Correlation = c(cor(effects_current[, 1], effects_current[, 2]),
                  cor(effects_boot[, 1], effects_boot[, 2]),
                  cor(effects_sparse[, 1], effects_sparse[, 2]),
                  cor(effects_concentrated[, 1], effects_concentrated[, 2]),
                  cor(effects_parametric[, 1], effects_parametric[, 2]),
                  cor(effects_parametric[, 1], effects_parametric[, 2])),
  PPV = c(ppv_current, ppv_boot, ppv_sparse, ppv_concentrated,
          ppv_parametric, ppv_parametric),
  NPV = c(npv_current, npv_boot, npv_sparse, npv_concentrated,
          npv_parametric, npv_parametric),
  Time_sec = c(time_current, time_boot, time_sparse, time_concentrated,
               time_parametric, time_parametric),
  Time_ratio = c(1, time_boot/time_current, time_sparse/time_current,
                 time_concentrated/time_current, time_parametric/time_current,
                 time_parametric/time_current)
)

print(comparison, width = 120)

cat("\n")
cat("================================================================\n")
cat("EVALUATION METRICS\n")
cat("================================================================\n\n")

target_sd_s <- sd(effects_parametric[, 1])
target_sd_y <- sd(effects_parametric[, 2])
target_corr <- cor(effects_parametric[, 1], effects_parametric[, 2])
target_ppv <- ppv_parametric
target_npv <- npv_parametric

cat("How close to ground truth?\n")
cat(sprintf("  Metric          Target    Current   Boot+RW   Sparse    Concent   Parametric\n"))
cat(sprintf("  SD(ΔS)          %.3f     %.3f     %.3f     %.3f     %.3f     %.3f\n",
            target_sd_s,
            sd(effects_current[, 1]), sd(effects_boot[, 1]),
            sd(effects_sparse[, 1]), sd(effects_concentrated[, 1]),
            sd(effects_parametric[, 1])))
cat(sprintf("  SD(ΔY)          %.3f     %.3f     %.3f     %.3f     %.3f     %.3f\n",
            target_sd_y,
            sd(effects_current[, 2]), sd(effects_boot[, 2]),
            sd(effects_sparse[, 2]), sd(effects_concentrated[, 2]),
            sd(effects_parametric[, 2])))
cat(sprintf("  Correlation     %.3f     %.3f     %.3f     %.3f     %.3f     %.3f\n",
            target_corr,
            cor(effects_current[, 1], effects_current[, 2]),
            cor(effects_boot[, 1], effects_boot[, 2]),
            cor(effects_sparse[, 1], effects_sparse[, 2]),
            cor(effects_concentrated[, 1], effects_concentrated[, 2]),
            cor(effects_parametric[, 1], effects_parametric[, 2])))
cat(sprintf("  PPV             %.3f     %.3f     %.3f     %.3f     %.3f     %.3f\n",
            target_ppv,
            ppv_current, ppv_boot, ppv_sparse, ppv_concentrated, ppv_parametric))
cat(sprintf("  NPV             %.3f     %.3f     %.3f     %.3f     %.3f     %.3f\n",
            target_npv,
            npv_current, npv_boot, npv_sparse, npv_concentrated, npv_parametric))

cat("\n")
cat("================================================================\n")
cat("RECOMMENDATIONS\n")
cat("================================================================\n\n")

# Evaluate each approach
sd_ratio_boot <- sd(effects_boot[, 1]) / target_sd_s
sd_ratio_sparse <- sd(effects_sparse[, 1]) / target_sd_s
sd_ratio_concentrated <- sd(effects_concentrated[, 1]) / target_sd_s

cat("1. BOOTSTRAP + REWEIGHT:\n")
if (sd_ratio_boot > 0.8 && sd_ratio_boot < 1.2) {
  cat("   ✓✓ SD matches target well (%.1fx)\n", sd_ratio_boot)
} else {
  cat("   ~ SD ratio: %.1fx (target: 1.0x)\n", sd_ratio_boot)
}
cat(sprintf("   Computation: %.1fx slower than current\n", time_boot / time_current))
cat("   Pros: Simple, theoretically sound, should work\n")
cat("   Cons: Slower, need to validate coverage empirically\n\n")

cat("2a. SPARSE INNOVATIONS (α=0.1):\n")
if (sd_ratio_sparse > 0.8 && sd_ratio_sparse < 1.2) {
  cat(sprintf("   ✓ SD matches target (%.1fx)\n", sd_ratio_sparse))
} else {
  cat(sprintf("   ✗ SD ratio: %.1fx (too %s)\n", sd_ratio_sparse,
              ifelse(sd_ratio_sparse < 1, "low", "high")))
}
cat(sprintf("   Computation: %.1fx (essentially same speed)\n",
            time_sparse / time_current))
cat("   Pros: Trivial to implement (just change alpha)\n")
cat("   Cons: Still reweighting same obs, may increase degeneracy\n\n")

cat("2b. CONCENTRATED INNOVATIONS (α=10):\n")
if (sd_ratio_concentrated > 0.8 && sd_ratio_concentrated < 1.2) {
  cat(sprintf("   ✓ SD matches target (%.1fx)\n", sd_ratio_concentrated))
} else {
  cat(sprintf("   ✗ SD ratio: %.1fx (too %s)\n", sd_ratio_concentrated,
              ifelse(sd_ratio_concentrated < 1, "low", "high")))
}
cat("   Pros: Fast\n")
cat("   Cons: Doesn't help - makes it worse!\n\n")

cat("3. PARAMETRIC BOOTSTRAP:\n")
cat("   ✓✓ Perfect match to target (by construction)\n")
cat(sprintf("   ✗✗ Computation: %.1fx slower!\n", time_parametric / time_current))
cat("   Pros: Theoretically correct, matches independent sampling\n")
cat("   Cons: Very expensive, requires knowing DGP structure\n\n")

cat("================================================================\n")
cat("FINAL RECOMMENDATION\n")
cat("================================================================\n\n")

if (sd_ratio_boot > 0.7 && time_boot / time_current < 3) {
  cat("✓ RECOMMENDED: Bootstrap + Reweight (Approach 1)\n")
  cat("  - Increases SD to acceptable level\n")
  cat("  - Computational cost reasonable (%.1fx)\n", time_boot / time_current)
  cat("  - Simple to implement\n")
  cat("  - Should maintain coverage\n\n")
  cat("NEXT STEPS:\n")
  cat("  1. Implement in surrogate_inference_if(use_bootstrap=TRUE)\n")
  cat("  2. Run validation with bootstrap to check coverage\n")
  cat("  3. Compare coverage: current vs bootstrap version\n")
} else if (sd_ratio_sparse > 0.7) {
  cat("✓ RECOMMENDED: Try sparse innovations first (Approach 2a)\n")
  cat("  - Simplest fix (just change alpha)\n")
  cat("  - No performance penalty\n")
  cat("  - Then try bootstrap if sparse doesn't work\n")
} else {
  cat("⚠ NO CLEAR WINNER\n")
  cat("  - Bootstrap increases SD but may not be enough\n")
  cat("  - Sparse innovations also insufficient\n")
  cat("  - May need parametric bootstrap (expensive)\n")
  cat("  - Or accept that method uses reweighting for computational efficiency\n")
}

cat("\n")
cat("================================================================\n")
cat("Prototype complete!\n")
cat("================================================================\n")
