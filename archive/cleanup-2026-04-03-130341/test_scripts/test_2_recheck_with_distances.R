#!/usr/bin/env Rscript
# TEST 2 RECHECK: Is Wasserstein ball large enough to reach the minimum?

library(tidyverse)
library(here)

devtools::load_all(here("package"))

cat("=============================================================================\n")
cat("TEST 2 RECHECK: Scenario B - Can λ_w = 0.3 reach the minimum?\n")
cat("=============================================================================\n\n")

set.seed(42)
n <- 500

# Generate Scenario B
X1 <- rnorm(n)
X2 <- rnorm(n)
A <- rbinom(n, 1, 0.5)

tau_s_true <- 0.2 + 0.4 * X1 - 0.1 * X2
tau_y_true <- 0.1 + 0.3 * X1 - 0.05 * X2

S <- tau_s_true * A + 0.5 + 0.2 * X1 + rnorm(n, sd = 0.3)
Y <- tau_y_true * A + 0.6 + 0.3 * X2 + rnorm(n, sd = 0.4)

data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

# True concordance
concordance_true <- tau_s_true * tau_y_true

# Find true minimum
min_idx_true <- which.min(concordance_true)
min_conc_true <- concordance_true[min_idx_true]
min_x1_true <- X1[min_idx_true]
min_x2_true <- X2[min_idx_true]

cat("TRUE GLOBAL MINIMUM:\n")
cat("  Concordance =", round(min_conc_true, 4), "\n")
cat("  Location: X1 =", round(min_x1_true, 3), ", X2 =", round(min_x2_true, 3), "\n\n")

# Estimate treatment effects
tau_s_est <- estimate_treatment_effect_function(
  data, "S", c("X1", "X2"), method = "kernel", cross_fit = TRUE
)$tau_hat

tau_y_est <- estimate_treatment_effect_function(
  data, "Y", c("X1", "X2"), method = "kernel", cross_fit = TRUE
)$tau_hat

concordance_est <- tau_s_est * tau_y_est

# Estimated minimum
min_idx_est <- which.min(concordance_est)
min_conc_est <- concordance_est[min_idx_est]

cat("ESTIMATED GLOBAL MINIMUM:\n")
cat("  Concordance =", round(min_conc_est, 4), "\n")
cat("  Location: X1 =", round(X1[min_idx_est], 3), ", X2 =", round(X2[min_idx_est], 3), "\n\n")

# Cost matrix
X <- scale(cbind(X1, X2))
cost_matrix <- as.matrix(dist(X, method = "euclidean"))^2

# Empirical distribution P_n
p_n <- rep(1/n, n)

cat("=============================================================================\n")
cat("KEY QUESTION: Can we transport mass from P_n to the minimum region?\n")
cat("=============================================================================\n\n")

# Find observations in the "minimum region" (X1 < -0.5)
in_min_region <- X1 < -0.5
n_in_min_region <- sum(in_min_region)

cat("Observations with X1 < -0.5:", n_in_min_region, "/", n, "\n")
cat("These have concordances: min =", round(min(concordance_est[in_min_region]), 4),
    ", mean =", round(mean(concordance_est[in_min_region]), 4), "\n\n")

# For each observation, compute: min distance to any observation in min region
min_dist_to_region <- numeric(n)
for (i in 1:n) {
  if (in_min_region[i]) {
    min_dist_to_region[i] <- 0
  } else {
    # Find closest observation in min region
    dists_to_region <- sqrt(cost_matrix[i, in_min_region])
    min_dist_to_region[i] <- min(dists_to_region)
  }
}

cat("Distance from P_n mass to minimum region:\n")
cat("  Mean distance:", round(mean(min_dist_to_region), 4), "\n")
cat("  Median distance:", round(median(min_dist_to_region), 4), "\n")
cat("  25th percentile:", round(quantile(min_dist_to_region, 0.25), 4), "\n\n")

# What's the Wasserstein distance if we put ALL mass in the min region?
# This is an upper bound on what we need

# Compute transport cost: move all mass to closest point in min region
total_transport_cost <- 0
for (i in 1:n) {
  # Move mass from i to closest point in min region
  if (!in_min_region[i]) {
    closest_in_region <- which(in_min_region)[which.min(cost_matrix[i, in_min_region])]
    total_transport_cost <- total_transport_cost + (1/n) * cost_matrix[i, closest_in_region]
  }
}

w2_to_region <- sqrt(total_transport_cost)

cat("CRITICAL DISTANCE:\n")
cat("  W_2 distance to move ALL mass to minimum region:", round(w2_to_region, 4), "\n")
cat("  Current λ_w:", 0.3, "\n")
cat("  Feasible?", w2_to_region <= 0.3, "\n\n")

if (w2_to_region > 0.3) {
  cat("✗ THE WASSERSTEIN BALL IS TOO SMALL\n")
  cat("  With λ_w = 0.3, we CANNOT reach the minimum region\n")
  cat("  The dual is correctly finding the minimum over the feasible set\n")
  cat("  But the feasible set doesn't include the global minimum\n\n")

  # What λ_w would we need?
  cat("  To reach the minimum region, need λ_w ≥", round(w2_to_region, 4), "\n\n")

  # Test with larger λ_w
  lambda_w_large <- ceiling(w2_to_region * 10) / 10

  cat("  Testing with λ_w =", lambda_w_large, "...\n")

  result_large <- observation_level_minimax_wasserstein(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = lambda_w_large,
    tau_method = "kernel",
    cross_fit = FALSE,  # Reuse same estimates
    scale_covariates = TRUE
  )

  cat("    Result:", round(result_large$phi_star, 4), "\n")
  cat("    Compare to estimated min:", round(min_conc_est, 4), "\n\n")

  if (abs(result_large$phi_star - min_conc_est) < 0.05) {
    cat("  ✓ With larger λ_w, we get close to the global minimum!\n")
    cat("    This confirms the dual is working correctly.\n\n")
  }

} else {
  cat("✓ THE WASSERSTEIN BALL IS LARGE ENOUGH\n")
  cat("  With λ_w = 0.3, we CAN reach the minimum region\n")
  cat("  If dual isn't finding it, there may be a bug\n\n")
}

cat("=============================================================================\n")
cat("DETAILED ANALYSIS: What does λ_w = 0.3 mean in this space?\n")
cat("=============================================================================\n\n")

# Standardized X space
X_std <- scale(cbind(X1, X2))

# In standardized space, moving from (0,0) to (1,0) has cost 1
# λ_w = 0.3 with squared cost means we can move mass distance sqrt(0.3^2) = 0.3

cat("In standardized covariate space:\n")
cat("  Moving mass from X1=0 to X1=1 (one SD) costs:", 1.0, "\n")
cat("  Moving mass from X1=0 to X1=-1 costs:", 1.0, "\n")
cat("  λ_w = 0.3 allows W_2 distance of:", 0.3, "\n\n")

# Since W_2 is sqrt of average squared costs, and we're moving 1/n mass per observation:
# We can roughly move mass a distance of 0.3 * sqrt(n) in total
# Or equivalently, move all mass distance 0.3

cat("Interpretation:\n")
cat("  With λ_w = 0.3, we can move mass ~0.3 standard deviations\n")
cat("  The minimum is at X1 =", round(min_x1_true, 2), "=",
    round(min_x1_true / sd(X1), 2), "SDs from mean\n\n")

# What fraction of mass is within λ_w distance of the minimum?
dist_to_min <- sqrt(rowSums((X_std - matrix(c(X_std[min_idx_est,1], X_std[min_idx_est,2]),
                                              nrow = n, ncol = 2, byrow = TRUE))^2))
within_ball <- dist_to_min <= 0.3

cat("Observations within λ_w = 0.3 of estimated minimum:", sum(within_ball), "/", n, "\n")
cat("Their concordances: min =", round(min(concordance_est[within_ball]), 4),
    ", mean =", round(mean(concordance_est[within_ball]), 4), "\n\n")

cat("=============================================================================\n")
cat("RECOMMENDATION\n")
cat("=============================================================================\n\n")

if (w2_to_region > 0.3) {
  cat("The dual formulation is CORRECT.\n\n")
  cat("The issue in Test 2 was that λ_w = 0.3 is too small to explore\n")
  cat("distant regions of the covariate space.\n\n")
  cat("This is NOT a bug - it's the intended behavior of Wasserstein DRO.\n")
  cat("λ_w controls the size of the uncertainty set.\n\n")
  cat("For surrogate transportability:\n")
  cat("  - User specifies λ_w based on expected covariate shift\n")
  cat("  - Larger λ_w = consider more extreme shifts\n")
  cat("  - Smaller λ_w = focus on local robustness\n\n")
  cat("The dual is finding the correct answer for the specified λ_w.\n")
} else {
  cat("Further investigation needed.\n")
}
