# Test: Observation-Level TV Ball (n-dimensional)
#
# Treat each observation as its own type
# Sample Q from TV ball in n-dimensional simplex

library(tidyverse)
devtools::load_all(".")

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")

cat("=== TESTING OBSERVATION-LEVEL TV BALL ===\n\n")

# Generate small test dataset
set.seed(2026)
n <- 100
cat(sprintf("Sample size: n = %d\n", n))
cat(sprintf("Dimension: K = %d (each observation is a type)\n\n", n))

# Simple DGP: Scenario 1 (High ρ, Low PTE)
X <- rbinom(n, 1, 0.5)
A <- rbinom(n, 1, 0.5)

logit_S <- -1.5 + 0.5*A + 0.3*X + 2.0*A*X
S <- rbinom(n, 1, plogis(logit_S))

logit_Y <- -1.5 + 0.3*A + 0.5*X + 0.1*S + 1.8*A*X
Y <- rbinom(n, 1, plogis(logit_Y))

data <- tibble(
  obs_id = 1:n,
  X = X,
  A = A,
  S = S,
  Y = Y
)

cat("Data preview:\n")
print(head(data))
cat("\n")

# Setup for observation-level TV ball
P0 <- rep(1/n, n)  # Uniform over observations

cat("P0 (first 10 elements):\n")
print(head(P0, 10))
cat(sprintf("Sum: %.6f\n\n", sum(P0)))

# Test hit-and-run sampler
cat("Testing hit-and-run sampler in n-dimensional space...\n")
cat("Parameters:\n")
cat("  lambda = 0.3\n")
cat("  n_samples = 50 (small test)\n")
cat("  burn_in = 500\n")
cat("  thin = 5\n\n")

start_time <- Sys.time()

Q_samples <- tryCatch({
  hit_and_run_tv_ball(
    P0 = P0,
    lambda = 0.3,
    n_samples = 50,
    burn_in = 500,
    thin = 5,
    verbose = TRUE
  )
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
  return(NULL)
})

end_time <- Sys.time()
elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

cat(sprintf("\nTotal time: %.1f seconds\n", elapsed))
cat(sprintf("Time per sample: %.2f seconds\n\n", elapsed / 50))

if (is.null(Q_samples)) {
  cat("✗ Sampler failed. Too high dimensional?\n")
  quit(status = 1)
}

cat("✓ Sampling successful!\n\n")

# Check samples
cat("Sample diagnostics:\n")
cat(sprintf("  Dimensions: %d × %d\n", nrow(Q_samples), ncol(Q_samples)))
cat(sprintf("  All sum to 1: %s\n",
            all(abs(rowSums(Q_samples) - 1) < 1e-6)))
cat(sprintf("  All non-negative: %s\n", all(Q_samples >= -1e-10)))

# Check TV distances
tv_distances <- apply(Q_samples, 1, function(q) {
  0.5 * sum(abs(q - P0))
})

cat(sprintf("\nTV distances from P0:\n"))
cat(sprintf("  Mean: %.4f\n", mean(tv_distances)))
cat(sprintf("  SD: %.4f\n", sd(tv_distances)))
cat(sprintf("  Min: %.4f\n", min(tv_distances)))
cat(sprintf("  Max: %.4f\n", max(tv_distances)))
cat(sprintf("  All ≤ lambda (0.3): %s\n", all(tv_distances <= 0.3 + 1e-6)))

# Test resampling with a Q sample
cat("\n=== TESTING RESAMPLING ===\n\n")

Q_test <- Q_samples[1, ]
cat("Using first Q sample...\n")
cat(sprintf("Sum of Q: %.6f\n", sum(Q_test)))
cat(sprintf("TV(Q, P0): %.4f\n", 0.5 * sum(abs(Q_test - P0))))

# Resample observations with weights Q
cat("\nResampling observations with Q weights...\n")
resampled_indices <- sample(1:n, size = n, replace = TRUE, prob = Q_test)
resampled_data <- data[resampled_indices, ]

cat(sprintf("Resampled %d observations\n", nrow(resampled_data)))

# Compare distributions
cat("\nOriginal vs Resampled distributions:\n")
cat(sprintf("  P(X=1): %.3f → %.3f\n",
            mean(data$X), mean(resampled_data$X)))
cat(sprintf("  P(A=1): %.3f → %.3f\n",
            mean(data$A), mean(resampled_data$A)))
cat(sprintf("  P(S=1): %.3f → %.3f\n",
            mean(data$S), mean(resampled_data$S)))
cat(sprintf("  P(Y=1): %.3f → %.3f\n",
            mean(data$Y), mean(resampled_data$Y)))

# Compute treatment effects
cat("\n=== TREATMENT EFFECTS ===\n\n")

compute_effects <- function(d) {
  delta_s <- mean(d$S[d$A == 1]) - mean(d$S[d$A == 0])
  delta_y <- mean(d$Y[d$A == 1]) - mean(d$Y[d$A == 0])
  c(delta_s = delta_s, delta_y = delta_y)
}

effects_original <- compute_effects(data)
effects_resampled <- compute_effects(resampled_data)

cat("Original data:\n")
cat(sprintf("  ΔS = %.3f\n", effects_original["delta_s"]))
cat(sprintf("  ΔY = %.3f\n", effects_original["delta_y"]))

cat("\nResampled data (one Q):\n")
cat(sprintf("  ΔS = %.3f\n", effects_resampled["delta_s"]))
cat(sprintf("  ΔY = %.3f\n", effects_resampled["delta_y"]))

# Compute effects for all Q samples
cat("\n=== COMPUTING EFFECTS FOR ALL Q SAMPLES ===\n\n")

effects_all <- map_dfr(1:nrow(Q_samples), function(i) {
  if (i %% 10 == 0) cat(sprintf("  Sample %d/%d\r", i, nrow(Q_samples)))

  Q_i <- Q_samples[i, ]
  resampled_idx <- sample(1:n, size = n, replace = TRUE, prob = Q_i)
  resampled <- data[resampled_idx, ]

  effects <- compute_effects(resampled)
  tibble(
    sample_id = i,
    delta_s = effects["delta_s"],
    delta_y = effects["delta_y"]
  )
})

cat("\n")

# Compute correlation
cor_obs_level <- cor(effects_all$delta_s, effects_all$delta_y)

cat("Results:\n")
cat(sprintf("  Across-study correlation: %.3f\n", cor_obs_level))
cat(sprintf("  Mean ΔS: %.3f (SD: %.3f)\n",
            mean(effects_all$delta_s), sd(effects_all$delta_s)))
cat(sprintf("  Mean ΔY: %.3f (SD: %.3f)\n",
            mean(effects_all$delta_y), sd(effects_all$delta_y)))

# Timing estimate for full simulation
cat("\n=== TIMING ESTIMATES ===\n\n")

time_per_sample <- elapsed / 50
cat(sprintf("Observed: %.2f seconds per Q sample (n=%d)\n", time_per_sample, n))

# Estimate for n=500
cat("\nExtrapolation to n=500:\n")
cat("  (Rough estimate assuming O(n²) complexity)\n")
time_500_per_sample <- time_per_sample * (500/100)^2
cat(sprintf("  Estimated: %.1f seconds per Q sample\n", time_500_per_sample))
cat(sprintf("  For M=100 samples: %.1f minutes\n", time_500_per_sample * 100 / 60))
cat(sprintf("  For M=500 samples: %.1f minutes\n", time_500_per_sample * 500 / 60))

cat("\n=== TEST COMPLETE ===\n")
cat(sprintf("✓ n=%d dimensional TV ball: FEASIBLE\n", n))
cat(sprintf("✓ Correlation computed: %.3f\n", cor_obs_level))
cat(sprintf("✓ Time per sample: %.2f sec\n", time_per_sample))

if (time_500_per_sample * 500 < 1800) {  # < 30 min
  cat("\n✓ RECOMMENDATION: n=500 appears feasible (< 30 min for M=500)\n")
} else {
  cat("\n⚠ WARNING: n=500 may be slow (> 30 min for M=500)\n")
  cat("  Consider reducing M or using smaller n\n")
}
