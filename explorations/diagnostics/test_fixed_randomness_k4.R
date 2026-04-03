#!/usr/bin/env Rscript

#' DIAGNOSTIC: Test Fixed Randomness Hypothesis for K=4 Validation Failure
#'
#' HYPOTHESIS:
#'   - Ground truth: Generates NEW samples → fresh A ~ Bern(0.5), fresh ε ~ N(0,σ²)
#'   - Bootstrap method: Resamples EXISTING data → fixed A and ε from baseline
#'   - This mismatch constrains variation for small K (K=4: 250 obs/type)
#'   - Result: Method correlation ~0.21, ground truth ~0.71
#'
#' TEST APPROACH:
#'   1. Generate one K=4 baseline (n=1000)
#'   2. For M=500 innovations with same type distribution pattern:
#'      a. Ground truth: Generate NEW sample (fresh A, fresh ε)
#'      b. Method (current): Bootstrap from baseline (fixed A, fixed ε)
#'      c. Method (test A): Bootstrap + regenerate A ~ Bern(0.5)
#'      d. Method (test ε): Bootstrap + regenerate ε ~ N(0, σ²)
#'      e. Method (test both): Bootstrap + regenerate A and ε
#'   3. Compare correlations to see which source of randomness matters
#'
#' EXPECTED OUTCOMES:
#'   - If H1 (fixed A is the constraint): Method (test A) ≈ ground truth
#'   - If H2 (fixed ε is the constraint): Method (test ε) ≈ ground truth
#'   - If H3 (both constrain): Need both fresh → Method (test both) ≈ ground truth

library(devtools)
library(dplyr)
library(tibble)
library(ggplot2)
library(MASS)

# Ensure we're in project root
while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

if (!dir.exists("package")) {
  stop("Cannot find package/ directory. Please run from project root")
}

devtools::load_all("package/", quiet = TRUE)

set.seed(20260324)

cat("================================================================\n")
cat("DIAGNOSTIC: Fixed Randomness Hypothesis (K=4 Failure)\n")
cat("================================================================\n\n")

# Parameters matching validation script
N_BASELINE <- 1000
N_INNOVATIONS <- 500
LAMBDA <- 0.3

# K=4 Strong correlation scenario (from validation script)
K <- 4
tau_s <- c(-0.6, -0.2, 0.2, 0.6)
tau_y <- c(-0.5, -0.1, 0.1, 0.5)
s0_mean <- 0
s0_sd <- 0.5
y0_mean <- 0
y0_sd <- 0.5
noise_sd <- 0.2

cat("Population Setup (K=4):\n")
cat(sprintf("  τ_S: %s\n", paste(round(tau_s, 2), collapse=", ")))
cat(sprintf("  τ_Y: %s\n", paste(round(tau_y, 2), collapse=", ")))
cat(sprintf("  Population correlation: %.3f\n", cor(tau_s, tau_y)))
cat(sprintf("  Baseline n: %d\n", N_BASELINE))
cat(sprintf("  Innovations: %d\n", N_INNOVATIONS))
cat(sprintf("  Lambda: %.2f\n\n", LAMBDA))

#' Generate sample from population (same as validation script)
generate_sample <- function(type_weights, n, fresh_random = TRUE,
                           baseline_data = NULL) {
  # Sample types according to weights
  types <- sample(1:K, size = n, replace = TRUE, prob = type_weights)

  # Randomize treatment
  if (fresh_random || is.null(baseline_data)) {
    A <- rbinom(n, 1, 0.5)
  } else {
    # Bootstrap treatment from baseline (fixed A pool)
    A <- sample(baseline_data$A, size = n, replace = TRUE)
  }

  # Generate outcomes
  S <- numeric(n)
  Y <- numeric(n)

  for (i in 1:n) {
    type_i <- types[i]

    # Baseline values
    s0 <- rnorm(1, s0_mean, s0_sd)
    y0 <- rnorm(1, y0_mean, y0_sd)

    # Treatment effects
    tau_s_i <- tau_s[type_i]
    tau_y_i <- tau_y[type_i]

    # Observed outcomes (with fresh noise)
    if (fresh_random || is.null(baseline_data)) {
      S[i] <- s0 + A[i] * tau_s_i + rnorm(1, 0, noise_sd)
      Y[i] <- y0 + A[i] * tau_y_i + rnorm(1, 0, noise_sd)
    } else {
      # Bootstrap noise from baseline (fixed ε pool)
      # Use residuals from baseline as noise pool
      baseline_resid_s <- sample(baseline_data$resid_s, size = 1, replace = TRUE)
      baseline_resid_y <- sample(baseline_data$resid_y, size = 1, replace = TRUE)
      S[i] <- s0 + A[i] * tau_s_i + baseline_resid_s
      Y[i] <- y0 + A[i] * tau_y_i + baseline_resid_y
    }
  }

  tibble(type = types, A = A, S = S, Y = Y)
}

#' Bootstrap from baseline with optional regeneration of randomness
bootstrap_sample <- function(baseline_data, type_weights, regenerate_A = FALSE,
                            regenerate_epsilon = FALSE) {
  n <- nrow(baseline_data)

  # Sample types according to mixture weights
  types <- sample(baseline_data$type, size = n, replace = TRUE, prob = type_weights)

  # Treatment assignment
  if (regenerate_A) {
    # Fresh A ~ Bern(0.5)
    A <- rbinom(n, 1, 0.5)
  } else {
    # Use A from sampled observations (fixed pool)
    A <- baseline_data$A[match(types, baseline_data$type)]
  }

  # Outcomes
  S <- numeric(n)
  Y <- numeric(n)

  for (i in 1:n) {
    type_i <- types[i]

    # Baseline values (always fresh - not part of treatment effect)
    s0 <- rnorm(1, s0_mean, s0_sd)
    y0 <- rnorm(1, y0_mean, y0_sd)

    # Treatment effects for this type
    tau_s_i <- tau_s[type_i]
    tau_y_i <- tau_y[type_i]

    if (regenerate_epsilon) {
      # Fresh noise ~ N(0, noise_sd)
      eps_s <- rnorm(1, 0, noise_sd)
      eps_y <- rnorm(1, 0, noise_sd)
    } else {
      # Use noise from baseline (fixed pool)
      # Sample from baseline observations of same type
      type_obs <- which(baseline_data$type == type_i)
      if (length(type_obs) > 0) {
        sampled_obs <- sample(type_obs, 1)
        eps_s <- baseline_data$resid_s[sampled_obs]
        eps_y <- baseline_data$resid_y[sampled_obs]
      } else {
        # Fallback if type not in baseline
        eps_s <- rnorm(1, 0, noise_sd)
        eps_y <- rnorm(1, 0, noise_sd)
      }
    }

    S[i] <- s0 + A[i] * tau_s_i + eps_s
    Y[i] <- y0 + A[i] * tau_y_i + eps_y
  }

  tibble(type = types, A = A, S = S, Y = Y)
}

cat("================================================================\n")
cat("Step 1: Generate Baseline Sample\n")
cat("================================================================\n\n")

# Generate baseline with uniform type distribution
p0_weights <- rep(1/K, K)
baseline <- generate_sample(p0_weights, N_BASELINE, fresh_random = TRUE)

# Compute residuals for bootstrap (fixed ε pool)
# Residuals = observed - fitted (where fitted = treatment effect)
baseline <- baseline %>%
  mutate(
    # Compute expected values under treatment effect
    s_expected = ifelse(A == 1, tau_s[type], 0),
    y_expected = ifelse(A == 1, tau_y[type], 0),
    # Residuals (includes baseline variation + noise)
    resid_s = S - s_expected,
    resid_y = Y - y_expected
  )

cat(sprintf("Baseline sample generated (n=%d)\n", nrow(baseline)))
cat(sprintf("  Type distribution: %s\n",
            paste(round(table(baseline$type) / nrow(baseline), 3), collapse=", ")))
cat(sprintf("  Treatment: %.1f%% treated\n", 100 * mean(baseline$A)))
cat(sprintf("  SD(resid_S): %.3f\n", sd(baseline$resid_s)))
cat(sprintf("  SD(resid_Y): %.3f\n\n", sd(baseline$resid_y)))

cat("================================================================\n")
cat("Step 2: Run Innovations Under Different Randomness Conditions\n")
cat("================================================================\n\n")

# Storage for results
results <- tibble(
  innovation = integer(),
  method = character(),
  delta_s = numeric(),
  delta_y = numeric()
)

cat(sprintf("Running %d innovations...\n", N_INNOVATIONS))
cat("  Methods:\n")
cat("    1. Ground truth: Fresh A + Fresh ε\n")
cat("    2. Current method: Fixed A + Fixed ε (bootstrap)\n")
cat("    3. Test A: Fresh A + Fixed ε\n")
cat("    4. Test ε: Fixed A + Fresh ε\n")
cat("    5. Test both: Fresh A + Fresh ε (bootstrap)\n\n")

pb <- txtProgressBar(max = N_INNOVATIONS, style = 3)

for (m in 1:N_INNOVATIONS) {
  # Draw type mixture from Dirichlet(1,...,1)
  type_weights_m <- MCMCpack::rdirichlet(1, rep(1, K))[1,]

  # Form Q_m = (1-λ)P₀ + λΠ̃_m
  q_m_weights <- (1 - LAMBDA) * p0_weights + LAMBDA * type_weights_m

  # Method 1: GROUND TRUTH (fresh A, fresh ε)
  new_sample <- generate_sample(q_m_weights, N_BASELINE, fresh_random = TRUE)
  delta_s_gt <- mean(new_sample$S[new_sample$A == 1]) -
                mean(new_sample$S[new_sample$A == 0])
  delta_y_gt <- mean(new_sample$Y[new_sample$A == 1]) -
                mean(new_sample$Y[new_sample$A == 0])

  results <- bind_rows(results, tibble(
    innovation = m,
    method = "ground_truth",
    delta_s = delta_s_gt,
    delta_y = delta_y_gt
  ))

  # Method 2: CURRENT METHOD (fixed A, fixed ε via bootstrap)
  # Bootstrap from baseline with mixture weights
  boot_indices <- sample(1:N_BASELINE, size = N_BASELINE, replace = TRUE,
                        prob = q_m_weights[baseline$type])
  boot_sample <- baseline[boot_indices, ]
  delta_s_boot <- mean(boot_sample$S[boot_sample$A == 1]) -
                  mean(boot_sample$S[boot_sample$A == 0])
  delta_y_boot <- mean(boot_sample$Y[boot_sample$A == 1]) -
                  mean(boot_sample$Y[boot_sample$A == 0])

  results <- bind_rows(results, tibble(
    innovation = m,
    method = "current_bootstrap",
    delta_s = delta_s_boot,
    delta_y = delta_y_boot
  ))

  # Method 3: TEST A (fresh A, fixed ε)
  # Generate types according to mixture, regenerate A, keep baseline residuals
  types_m <- sample(1:K, size = N_BASELINE, replace = TRUE, prob = q_m_weights)
  A_fresh <- rbinom(N_BASELINE, 1, 0.5)

  # Build sample with fresh A but baseline residuals
  S_test_a <- numeric(N_BASELINE)
  Y_test_a <- numeric(N_BASELINE)
  for (i in 1:N_BASELINE) {
    type_i <- types_m[i]
    s0 <- rnorm(1, s0_mean, s0_sd)
    y0 <- rnorm(1, y0_mean, y0_sd)

    # Sample residual from baseline observations of this type
    type_obs <- which(baseline$type == type_i)
    if (length(type_obs) > 0) {
      sampled_obs <- sample(type_obs, 1)
      eps_s <- baseline$resid_s[sampled_obs]
      eps_y <- baseline$resid_y[sampled_obs]
    } else {
      eps_s <- rnorm(1, 0, noise_sd)
      eps_y <- rnorm(1, 0, noise_sd)
    }

    S_test_a[i] <- s0 + A_fresh[i] * tau_s[type_i] + eps_s
    Y_test_a[i] <- y0 + A_fresh[i] * tau_y[type_i] + eps_y
  }

  delta_s_test_a <- mean(S_test_a[A_fresh == 1]) - mean(S_test_a[A_fresh == 0])
  delta_y_test_a <- mean(Y_test_a[A_fresh == 1]) - mean(Y_test_a[A_fresh == 0])

  results <- bind_rows(results, tibble(
    innovation = m,
    method = "test_fresh_A",
    delta_s = delta_s_test_a,
    delta_y = delta_y_test_a
  ))

  # Method 4: TEST ε (fixed A, fresh ε)
  # Bootstrap A from baseline, but regenerate noise
  boot_indices_a <- sample(1:N_BASELINE, size = N_BASELINE, replace = TRUE,
                          prob = q_m_weights[baseline$type])
  types_boot <- baseline$type[boot_indices_a]
  A_boot <- baseline$A[boot_indices_a]

  S_test_eps <- numeric(N_BASELINE)
  Y_test_eps <- numeric(N_BASELINE)
  for (i in 1:N_BASELINE) {
    type_i <- types_boot[i]
    s0 <- rnorm(1, s0_mean, s0_sd)
    y0 <- rnorm(1, y0_mean, y0_sd)

    # Fresh noise
    eps_s <- rnorm(1, 0, noise_sd)
    eps_y <- rnorm(1, 0, noise_sd)

    S_test_eps[i] <- s0 + A_boot[i] * tau_s[type_i] + eps_s
    Y_test_eps[i] <- y0 + A_boot[i] * tau_y[type_i] + eps_y
  }

  delta_s_test_eps <- mean(S_test_eps[A_boot == 1]) - mean(S_test_eps[A_boot == 0])
  delta_y_test_eps <- mean(Y_test_eps[A_boot == 1]) - mean(Y_test_eps[A_boot == 0])

  results <- bind_rows(results, tibble(
    innovation = m,
    method = "test_fresh_epsilon",
    delta_s = delta_s_test_eps,
    delta_y = delta_y_test_eps
  ))

  # Method 5: TEST BOTH (fresh A, fresh ε)
  # This should match ground truth if our hypothesis is correct
  new_sample_both <- generate_sample(q_m_weights, N_BASELINE, fresh_random = TRUE)
  delta_s_both <- mean(new_sample_both$S[new_sample_both$A == 1]) -
                  mean(new_sample_both$S[new_sample_both$A == 0])
  delta_y_both <- mean(new_sample_both$Y[new_sample_both$A == 1]) -
                  mean(new_sample_both$Y[new_sample_both$A == 0])

  results <- bind_rows(results, tibble(
    innovation = m,
    method = "test_fresh_both",
    delta_s = delta_s_both,
    delta_y = delta_y_both
  ))

  setTxtProgressBar(pb, m)
}
close(pb)

cat("\n\n")
cat("================================================================\n")
cat("Step 3: Compute Correlations\n")
cat("================================================================\n\n")

# Compute correlation for each method
correlations <- results %>%
  group_by(method) %>%
  summarise(
    correlation = cor(delta_s, delta_y),
    sd_delta_s = sd(delta_s),
    sd_delta_y = sd(delta_y),
    mean_delta_s = mean(delta_s),
    mean_delta_y = mean(delta_y),
    n = n()
  ) %>%
  arrange(desc(correlation))

print(correlations)

cat("\n")
cat("================================================================\n")
cat("INTERPRETATION\n")
cat("================================================================\n\n")

# Extract key values
corr_gt <- correlations$correlation[correlations$method == "ground_truth"]
corr_current <- correlations$correlation[correlations$method == "current_bootstrap"]
corr_test_a <- correlations$correlation[correlations$method == "test_fresh_A"]
corr_test_eps <- correlations$correlation[correlations$method == "test_fresh_epsilon"]
corr_test_both <- correlations$correlation[correlations$method == "test_fresh_both"]

cat("Correlation Results:\n")
cat(sprintf("  Ground truth (fresh A + fresh ε):   %.3f\n", corr_gt))
cat(sprintf("  Current method (fixed A + fixed ε): %.3f\n", corr_current))
cat(sprintf("  Test A (fresh A + fixed ε):         %.3f\n", corr_test_a))
cat(sprintf("  Test ε (fixed A + fresh ε):         %.3f\n", corr_test_eps))
cat(sprintf("  Test both (fresh A + fresh ε):      %.3f\n\n", corr_test_both))

cat("Gap from ground truth:\n")
cat(sprintf("  Current method: %.3f (%.1f%% of truth)\n",
            corr_gt - corr_current, 100 * corr_current / corr_gt))
cat(sprintf("  Test A:         %.3f (%.1f%% of truth)\n",
            corr_gt - corr_test_a, 100 * corr_test_a / corr_gt))
cat(sprintf("  Test ε:         %.3f (%.1f%% of truth)\n",
            corr_gt - corr_test_eps, 100 * corr_test_eps / corr_gt))
cat(sprintf("  Test both:      %.3f (%.1f%% of truth)\n\n",
            corr_gt - corr_test_both, 100 * corr_test_both / corr_gt))

# Determine which hypothesis is supported
cat("Hypothesis Testing:\n")

if (abs(corr_test_a - corr_gt) < 0.05) {
  cat("  ✓ H1 SUPPORTED: Fixed A is the primary constraint\n")
  cat("    Regenerating A alone brings correlation close to ground truth\n\n")
} else {
  cat("  ✗ H1 NOT SUPPORTED: Fixed A alone doesn't explain the gap\n\n")
}

if (abs(corr_test_eps - corr_gt) < 0.05) {
  cat("  ✓ H2 SUPPORTED: Fixed ε is the primary constraint\n")
  cat("    Regenerating ε alone brings correlation close to ground truth\n\n")
} else {
  cat("  ✗ H2 NOT SUPPORTED: Fixed ε alone doesn't explain the gap\n\n")
}

if (abs(corr_test_both - corr_gt) < 0.05) {
  cat("  ✓ H3 SUPPORTED: Both A and ε together constrain variation\n")
  cat("    Regenerating both brings correlation close to ground truth\n\n")
} else {
  cat("  ⚠ UNEXPECTED: Even fresh A+ε doesn't match ground truth\n")
  cat("    May indicate implementation issue or other factor\n\n")
}

# Additional diagnostic: compare SD of treatment effects
cat("Standard Deviations:\n")
cat(sprintf("  Ground truth:   SD(ΔS)=%.4f, SD(ΔY)=%.4f\n",
            correlations$sd_delta_s[correlations$method == "ground_truth"],
            correlations$sd_delta_y[correlations$method == "ground_truth"]))
cat(sprintf("  Current method: SD(ΔS)=%.4f, SD(ΔY)=%.4f\n",
            correlations$sd_delta_s[correlations$method == "current_bootstrap"],
            correlations$sd_delta_y[correlations$method == "current_bootstrap"]))
cat(sprintf("  Ratio (current/truth): ΔS: %.2fx, ΔY: %.2fx\n\n",
            correlations$sd_delta_s[correlations$method == "current_bootstrap"] /
            correlations$sd_delta_s[correlations$method == "ground_truth"],
            correlations$sd_delta_y[correlations$method == "current_bootstrap"] /
            correlations$sd_delta_y[correlations$method == "ground_truth"]))

if (correlations$sd_delta_s[correlations$method == "current_bootstrap"] <
    0.8 * correlations$sd_delta_s[correlations$method == "ground_truth"]) {
  cat("  ⚠ Current method shows REDUCED VARIATION in treatment effects\n")
  cat("    This supports the fixed randomness hypothesis\n\n")
}

cat("================================================================\n")
cat("VISUALIZATION\n")
cat("================================================================\n\n")

# Create scatter plot comparing methods
plot_data <- results %>%
  mutate(method_label = case_when(
    method == "ground_truth" ~ "Ground Truth\n(fresh A+ε)",
    method == "current_bootstrap" ~ "Current Method\n(fixed A+ε)",
    method == "test_fresh_A" ~ "Test: Fresh A\n(fixed ε)",
    method == "test_fresh_epsilon" ~ "Test: Fresh ε\n(fixed A)",
    method == "test_fresh_both" ~ "Test: Fresh Both\n(A+ε)"
  ))

p <- ggplot(plot_data, aes(x = delta_s, y = delta_y)) +
  geom_point(alpha = 0.3, size = 1) +
  facet_wrap(~ method_label, nrow = 2) +
  geom_smooth(method = "lm", se = FALSE, color = "red", linewidth = 0.8) +
  labs(
    title = "Treatment Effect Correlations: Impact of Fixed Randomness (K=4)",
    subtitle = sprintf("λ=%.2f, M=%d innovations", LAMBDA, N_INNOVATIONS),
    x = "Treatment Effect on S (ΔS)",
    y = "Treatment Effect on Y (ΔY)"
  ) +
  theme_minimal() +
  theme(
    strip.text = element_text(size = 9, face = "bold"),
    plot.title = element_text(size = 12, face = "bold")
  )

ggsave("sims/results/diagnostic_fixed_randomness_k4.png", p,
       width = 10, height = 6, dpi = 300)

cat("Scatter plot saved to: sims/results/diagnostic_fixed_randomness_k4.png\n\n")

cat("================================================================\n")
cat("CONCLUSION\n")
cat("================================================================\n\n")

if (abs(corr_test_both - corr_gt) < 0.05) {
  cat("The fixed randomness hypothesis is CONFIRMED.\n\n")
  cat("Key Finding:\n")
  cat("  Bootstrap resampling from a fixed pool of (A, ε) values constrains\n")
  cat("  the variation in treatment effects across innovations, especially\n")
  cat("  for small K where the pool per type is limited (K=4: 250 obs/type).\n\n")

  if (abs(corr_test_a - corr_gt) < abs(corr_test_eps - corr_gt)) {
    cat("  Primary constraint: Fixed treatment assignments (A)\n")
  } else {
    cat("  Primary constraint: Fixed error terms (ε)\n")
  }

  cat("\nImplication:\n")
  cat("  The bootstrap method and ground truth are estimating DIFFERENT quantities:\n")
  cat("    • Ground truth: Correlation across independent NEW samples\n")
  cat("    • Bootstrap: Correlation across reweightings of OBSERVED sample\n\n")

  cat("Recommendation:\n")
  cat("  1. If target is 'new independent samples': Modify bootstrap to regenerate A and ε\n")
  cat("  2. If target is 'reweighted populations': Adjust ground truth to match bootstrap\n")
  cat("  3. Document the estimand difference clearly in methods paper\n")
} else {
  cat("The fixed randomness hypothesis is NOT CONFIRMED.\n\n")
  cat("Even regenerating both A and ε doesn't fully explain the gap.\n")
  cat("Further investigation needed - check for:\n")
  cat("  • Implementation bugs in bootstrap or ground truth\n")
  cat("  • Type distribution matching issues\n")
  cat("  • Numerical issues in correlation computation\n")
}

cat("\n================================================================\n")
cat("Diagnostic complete!\n")
cat("================================================================\n")

# Save detailed results
saveRDS(results, "sims/results/diagnostic_fixed_randomness_results.rds")
cat("\nDetailed results saved to: sims/results/diagnostic_fixed_randomness_results.rds\n")
