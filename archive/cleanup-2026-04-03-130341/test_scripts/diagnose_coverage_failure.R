#!/usr/bin/env Rscript
# Diagnose why coverage validation failed

library(tidyverse)
library(here)

devtools::load_all(here("package"))

cat("=============================================================================\n")
cat("DIAGNOSING COVERAGE FAILURE\n")
cat("=============================================================================\n\n")

# Load results
results <- readRDS(here("sims/results/coverage_validation_observation_level.rds"))

cat("Mean truth:    ", round(mean(results$truth), 4), "\n")
cat("Mean estimate: ", round(mean(results$estimate), 4), "\n")
cat("Bias:          ", round(mean(results$bias), 4), "\n\n")

# Pick one failed case to investigate in detail
failed_case <- results %>% filter(!covered) %>% slice(1)

cat("Investigating failed replication", failed_case$rep, ":\n")
cat("  Truth:     ", round(failed_case$truth, 4), "\n")
cat("  Estimate:  ", round(failed_case$estimate, 4), "\n")
cat("  CI:        [", round(failed_case$ci_lower, 4), ",",
    round(failed_case$ci_upper, 4), "]\n")
cat("  Bias:      ", round(failed_case$bias, 4), "\n\n")

# Regenerate this case to investigate
set.seed(failed_case$rep + 5000)

n <- 250
X1 <- rnorm(n)
X2 <- rnorm(n)
A <- rbinom(n, 1, 0.5)

tau_s_fn <- function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2
tau_y_fn <- function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2

tau_s_true <- tau_s_fn(X1, X2)
tau_y_true <- tau_y_fn(X1, X2)

S <- tau_s_true * A + 0.5 + 0.2 * X1 + rnorm(n, sd = 0.3)
Y <- tau_y_true * A + 0.6 + 0.3 * X2 + rnorm(n, sd = 0.4)

data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

lambda_w <- 0.5

cat("=============================================================================\n")
cat("HYPOTHESIS 1: Is truth computation correct?\n")
cat("=============================================================================\n\n")

# Compute truth (what coverage_validation.R does)
h_true <- tau_s_true * tau_y_true

X <- scale(cbind(X1, X2))
cost_matrix <- as.matrix(dist(X, method = "euclidean"))^2

dual_objective <- function(gamma) {
  obj_matrix <- matrix(h_true, nrow = n, ncol = n, byrow = TRUE) +
                gamma * cost_matrix
  inner_mins <- apply(obj_matrix, 1, min)
  -gamma * lambda_w^2 + mean(inner_mins)
}

result_truth <- optimize(dual_objective, interval = c(0, 100), maximum = TRUE)
truth_computed <- result_truth$objective

cat("Truth (from true tau):", round(truth_computed, 4), "\n")
cat("Matches saved value?", abs(truth_computed - failed_case$truth) < 1e-6, "\n\n")

# What's the empirical mean?
cat("Mean h_true:", round(mean(h_true), 4), "\n")
cat("Min h_true:", round(min(h_true), 4), "\n\n")

cat("Truth should be between min and mean.\n")
cat("Is it?", truth_computed >= min(h_true) && truth_computed <= mean(h_true), "\n\n")

cat("=============================================================================\n")
cat("HYPOTHESIS 2: Is estimation systematically biased?\n")
cat("=============================================================================\n\n")

# Estimate (what coverage_validation.R does)
result_est <- observation_level_minimax_wasserstein(
  data = data,
  covariates = c("X1", "X2"),
  lambda_w = lambda_w,
  tau_method = "kernel",
  cross_fit = TRUE,
  scale_covariates = TRUE
)

cat("Estimate:", round(result_est$phi_star, 4), "\n")
cat("Matches saved value?", abs(result_est$phi_star - failed_case$estimate) < 0.01, "\n\n")

# Look at estimated vs true tau
tau_s_est <- result_est$tau_s_hat
tau_y_est <- result_est$tau_y_hat

cat("Treatment effect estimation quality:\n")
cat("  tau_S: RMSE =", round(sqrt(mean((tau_s_est - tau_s_true)^2)), 4), "\n")
cat("  tau_Y: RMSE =", round(sqrt(mean((tau_y_est - tau_y_true)^2)), 4), "\n")
cat("  tau_S: Bias =", round(mean(tau_s_est - tau_s_true), 4), "\n")
cat("  tau_Y: Bias =", round(mean(tau_y_est - tau_y_true), 4), "\n\n")

# Estimated concordances
h_est <- result_est$concordance_i

cat("Concordance estimation:\n")
cat("  RMSE:", round(sqrt(mean((h_est - h_true)^2)), 4), "\n")
cat("  Bias:", round(mean(h_est - h_true), 4), "\n")
cat("  Mean est:", round(mean(h_est), 4), "\n")
cat("  Mean true:", round(mean(h_true), 4), "\n\n")

cat("=============================================================================\n")
cat("HYPOTHESIS 3: Does lambda_w reach the true minimum region?\n")
cat("=============================================================================\n\n")

# Find which observations achieve the truth
gamma_star <- result_truth$maximum
obj_matrix_truth <- matrix(h_true, nrow = n, ncol = n, byrow = TRUE) +
                    gamma_star * cost_matrix

# For each i, which j minimizes?
targets_truth <- apply(obj_matrix_truth, 1, which.min)

# Which observations receive mass?
target_counts_truth <- sort(table(targets_truth), decreasing = TRUE)

cat("Top 5 observations in TRUE solution:\n")
for (i in 1:min(5, length(target_counts_truth))) {
  j <- as.numeric(names(target_counts_truth)[i])
  cat("  Obs", j, ": h_true =", round(h_true[j], 4),
      ", X1 =", round(X1[j], 3), ", X2 =", round(X2[j], 3), "\n")
}
cat("\n")

# Same for estimated
gamma_star_est <- result_est$optimal_gamma
obj_matrix_est <- matrix(h_est, nrow = n, ncol = n, byrow = TRUE) +
                  gamma_star_est * cost_matrix

targets_est <- apply(obj_matrix_est, 1, which.min)
target_counts_est <- sort(table(targets_est), decreasing = TRUE)

cat("Top 5 observations in ESTIMATED solution:\n")
for (i in 1:min(5, length(target_counts_est))) {
  j <- as.numeric(names(target_counts_est)[i])
  cat("  Obs", j, ": h_est =", round(h_est[j], 4),
      ", h_true =", round(h_true[j], 4),
      ", X1 =", round(X1[j], 3), ", X2 =", round(X2[j], 3), "\n")
}
cat("\n")

# Are they targeting the same regions?
overlap <- length(intersect(names(target_counts_truth)[1:10],
                           names(target_counts_est)[1:10]))
cat("Overlap in top 10 targets:", overlap, "/10\n\n")

cat("=============================================================================\n")
cat("HYPOTHESIS 4: Is there noise amplification in min?\n")
cat("=============================================================================\n\n")

# The estimated dual finds min over estimated concordances
# But estimated concordances are NOISY
# Does taking min over noisy estimates create downward bias?

# Let's check: if we solve dual with TRUE h, what do we get?
result_oracle <- observation_level_minimax_wasserstein(
  data = data,
  covariates = c("X1", "X2"),
  lambda_w = lambda_w,
  tau_method = "kernel",
  cross_fit = FALSE,  # Use same estimates
  scale_covariates = TRUE
)

# Now manually replace h with true h and re-solve
obj_matrix_oracle <- matrix(h_true, nrow = n, ncol = n, byrow = TRUE) +
                     result_oracle$optimal_gamma * cost_matrix

# No wait, I need to re-optimize gamma with true h
dual_obj_oracle <- function(gamma) {
  obj_matrix <- matrix(h_true, nrow = n, ncol = n, byrow = TRUE) +
                gamma * result_oracle$cost_matrix
  inner_mins <- apply(obj_matrix, 1, min)
  -gamma * lambda_w^2 + mean(inner_mins)
}

result_oracle2 <- optimize(dual_obj_oracle, interval = c(0, 100), maximum = TRUE)

cat("Using SAME cost matrix as estimate, but TRUE h:\n")
cat("  Result:", round(result_oracle2$objective, 4), "\n")
cat("  Compare to truth:", round(truth_computed, 4), "\n")
cat("  Difference:", round(result_oracle2$objective - truth_computed, 4), "\n\n")

# The difference should be small (cost matrix is from data)
# If it's large, problem is in cost matrix construction

cat("=============================================================================\n")
cat("HYPOTHESIS 5: Do we need more bootstrap iterations?\n")
cat("=============================================================================\n\n")

cat("Current CI width:", round(failed_case$ci_width, 4), "\n")
cat("Current bias:   ", round(failed_case$bias, 4), "\n\n")

cat("If bias is -0.064 and CI width is ~0.10, then:\n")
cat("  CI = [", round(failed_case$estimate - 0.05, 3), ",",
    round(failed_case$estimate + 0.05, 3), "]\n")
cat("  Truth =", round(failed_case$truth, 3), "\n\n")

cat("Even with perfect CI, bias dominates the failure.\n\n")

cat("=============================================================================\n")
cat("DIAGNOSIS\n")
cat("=============================================================================\n\n")

if (abs(mean(h_est - h_true)) > 0.02) {
  cat("✗ CONCORDANCE ESTIMATION IS BIASED\n")
  cat("  Mean(h_est - h_true) =", round(mean(h_est - h_true), 4), "\n")
  cat("  This propagates to the minimax estimate\n\n")
}

if (overlap < 5) {
  cat("✗ ESTIMATED AND TRUE SOLUTIONS TARGET DIFFERENT REGIONS\n")
  cat("  Overlap in top 10:", overlap, "/10\n")
  cat("  Estimation noise causes wrong region selection\n\n")
}

if (abs(result_oracle2$objective - truth_computed) > 0.01) {
  cat("✗ COST MATRIX ISSUE\n")
  cat("  Even with true h, using estimated cost matrix gives different answer\n\n")
}

cat("MOST LIKELY CAUSE:\n")
cat("The observation-level approach STILL has a selection problem:\n")
cat("  1. Estimate tau_S(x), tau_Y(x) from data (noisy)\n")
cat("  2. Compute h_i = tau_S(x_i) * tau_Y(x_i) (products amplify noise)\n")
cat("  3. Dual finds min over h_i via optimal transport\n")
cat("  4. Selection of minimum regions is noise-driven\n")
cat("  5. Result: Systematic underestimation\n\n")

cat("This is SIMILAR to type-level, just at a finer scale!\n")
cat("  Type-level: select min over J=16 noisy types → bias -0.06\n")
cat("  Obs-level:  select min over n=250 noisy concordances → bias -0.06\n\n")

cat("Lambda_w doesn't fully protect us because estimation noise\n")
cat("is present at ALL observations, not just distant ones.\n")
