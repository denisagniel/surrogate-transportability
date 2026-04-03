#!/usr/bin/env Rscript

#' Test: Effect of Alpha on K=4 Coverage
#'
#' This tests whether using spikier innovation distributions (small alpha)
#' improves coverage for the K=4 Strong-Corr scenario.
#'
#' Background: K=4 with n=1000 creates a mismatch:
#'   - Ground truth uses Dirichlet(1,1,1,1) over types (spiky)
#'   - Method with alpha=1 aggregates to Dirichlet(250,250,250,250) (concentrated)
#'   - Result: Method underestimates correlation, 0% coverage
#'
#' Question: Does using alpha=K/n=0.004 fix this by matching ground truth dispersion?

library(devtools)
library(dplyr)
library(tibble)

while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

devtools::load_all("package/", quiet = TRUE)

set.seed(20260324)

cat("================================================================\n")
cat("TEST: Effect of Alpha Parameter on K=4 Scenario\n")
cat("================================================================\n\n")

# K=4 Strong-Corr scenario (from validation script)
K <- 4
tau_s <- c(-0.6, -0.2, 0.2, 0.6)
tau_y <- c(-0.5, -0.1, 0.1, 0.5)

cat("Population setup:\n")
cat(sprintf("  K = %d types\n", K))
cat(sprintf("  τ_S: %s\n", paste(tau_s, collapse=", ")))
cat(sprintf("  τ_Y: %s\n", paste(tau_y, collapse=", ")))
cat(sprintf("  Type-level correlation: %.4f\n\n", cor(tau_s, tau_y)))

# Generate sample from population function
generate_sample_from_population <- function(tau_s, tau_y, type_weights, n) {
  K <- length(tau_s)
  types <- sample(1:K, size = n, replace = TRUE, prob = type_weights)
  A <- rbinom(n, 1, 0.5)

  S <- numeric(n)
  Y <- numeric(n)

  for (i in 1:n) {
    type_i <- types[i]
    s0 <- rnorm(1, 0, 0.5)
    y0 <- rnorm(1, 0, 0.5)
    S[i] <- s0 + A[i] * tau_s[type_i] + rnorm(1, 0, 0.2)
    Y[i] <- y0 + A[i] * tau_y[type_i] + rnorm(1, 0, 0.2)
  }

  tibble(A = A, S = S, Y = Y)
}

# Parameters
N_BASELINE <- 1000
N_TRUE_STUDIES <- 500
N_INNOVATIONS <- 2000
N_REPLICATIONS <- 100  # Fewer reps for quick test
lambda <- 0.3

# Alpha values to test
alpha_values <- c(
  0.004,  # K/n - matches Dirichlet(1,1,1,1) at type level
  0.01,   # Intermediate
  0.1,    # Intermediate
  1.0     # Current default
)

cat("Alpha values to test:\n")
for (a in alpha_values) {
  cat(sprintf("  α = %.4f: ", a))
  if (a == 0.004) {
    cat("Matches ground truth dispersion (Dirichlet(1,1,1,1) at type level)\n")
  } else if (a == 1.0) {
    cat("Current default (uniform prior at observation level)\n")
  } else {
    cat("Intermediate\n")
  }
}
cat("\n")

cat("----------------------------------------------------------------\n")
cat("Computing Ground Truth\n")
cat("----------------------------------------------------------------\n\n")

cat(sprintf("Lambda: %.1f\n", lambda))
cat(sprintf("Generating %d studies from population...\n", N_TRUE_STUDIES))

# Ground truth: same as validation script
true_effects <- matrix(NA, nrow = N_TRUE_STUDIES, ncol = 2)

for (m in 1:N_TRUE_STUDIES) {
  type_weights_m <- MCMCpack::rdirichlet(1, rep(1, K))[1,]
  p0_weights <- rep(1/K, K)
  q_m_weights <- (1 - lambda) * p0_weights + lambda * type_weights_m

  new_sample <- generate_sample_from_population(
    tau_s, tau_y, q_m_weights, N_BASELINE
  )

  delta_s <- mean(new_sample$S[new_sample$A == 1]) -
             mean(new_sample$S[new_sample$A == 0])
  delta_y <- mean(new_sample$Y[new_sample$A == 1]) -
             mean(new_sample$Y[new_sample$A == 0])

  true_effects[m, ] <- c(delta_s, delta_y)
}

true_correlation <- cor(true_effects[, 1], true_effects[, 2])

cat(sprintf("Ground truth correlation: %.3f\n", true_correlation))
cat(sprintf("SD(ΔS): %.4f\n", sd(true_effects[, 1])))
cat(sprintf("SD(ΔY): %.4f\n\n", sd(true_effects[, 2])))

cat("----------------------------------------------------------------\n")
cat("Testing Different Alpha Values\n")
cat("----------------------------------------------------------------\n\n")

results_by_alpha <- tibble(
  alpha = numeric(),
  replication = integer(),
  estimate = numeric(),
  se = numeric(),
  ci_lower = numeric(),
  ci_upper = numeric(),
  covered = logical()
)

start_time <- Sys.time()

for (alpha_val in alpha_values) {
  cat(sprintf("Testing α = %.4f\n", alpha_val))
  cat(sprintf("  Running %d replications...\n", N_REPLICATIONS))

  for (rep in 1:N_REPLICATIONS) {
    if (rep %% 20 == 0) {
      elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
      cat(sprintf("    Rep %d/%d (%.1f sec elapsed)\n", rep, N_REPLICATIONS, elapsed))
    }

    # Generate observed baseline (uniform type weights)
    p0_weights <- rep(1/K, K)
    observed_baseline <- generate_sample_from_population(
      tau_s, tau_y, p0_weights, N_BASELINE
    )

    # Estimate with current alpha
    result <- tryCatch({
      surrogate_inference_if(
        observed_baseline,
        lambda = lambda,
        n_innovations = N_INNOVATIONS,
        functional_type = "correlation",
        alpha = alpha_val,  # KEY: Test different alphas
        use_bootstrap = TRUE
      )
    }, error = function(e) {
      list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
    })

    if (is.na(result$estimate)) next

    covered <- (true_correlation >= result$ci_lower) &&
               (true_correlation <= result$ci_upper)

    results_by_alpha <- bind_rows(results_by_alpha, tibble(
      alpha = alpha_val,
      replication = rep,
      estimate = result$estimate,
      se = result$se,
      ci_lower = result$ci_lower,
      ci_upper = result$ci_upper,
      covered = covered
    ))
  }

  cat("\n")
}

cat("================================================================\n")
cat("RESULTS\n")
cat("================================================================\n\n")

summary_by_alpha <- results_by_alpha %>%
  group_by(alpha) %>%
  summarize(
    n = n(),
    coverage = mean(covered),
    mean_estimate = mean(estimate),
    bias = mean(estimate - true_correlation),
    mean_se = mean(se),
    empirical_sd = sd(estimate),
    se_ratio = mean(se) / sd(estimate)
  ) %>%
  arrange(alpha)

print(summary_by_alpha)

cat("\n")
cat("Ground truth correlation: ", round(true_correlation, 3), "\n\n")

# Detailed interpretation
cat("INTERPRETATION:\n")
cat("===============\n\n")

for (i in 1:nrow(summary_by_alpha)) {
  row <- summary_by_alpha[i, ]
  cat(sprintf("α = %.4f:\n", row$alpha))
  cat(sprintf("  Coverage:        %.1f%% ", row$coverage * 100))
  if (row$coverage >= 0.90) {
    cat("✓ (target: 90-98%)\n")
  } else {
    cat("✗ (below target)\n")
  }
  cat(sprintf("  Mean estimate:   %.3f\n", row$mean_estimate))
  cat(sprintf("  Bias:            %.3f ", row$bias))
  if (abs(row$bias) < 0.05) {
    cat("✓ (essentially unbiased)\n")
  } else {
    cat("✗ (notable bias)\n")
  }
  cat(sprintf("  SE/SD ratio:     %.2fx ", row$se_ratio))
  if (row$se_ratio >= 0.9 && row$se_ratio <= 1.3) {
    cat("✓ (well-calibrated)\n")
  } else if (row$se_ratio > 1.3) {
    cat("(conservative)\n")
  } else {
    cat("(anti-conservative)\n")
  }
  cat("\n")
}

# Check if small alpha fixes K=4
best_alpha <- summary_by_alpha %>% filter(coverage == max(coverage)) %>% pull(alpha) %>% first()
best_coverage <- summary_by_alpha %>% filter(coverage == max(coverage)) %>% pull(coverage) %>% first()

cat("CONCLUSION:\n")
cat("===========\n\n")

if (best_coverage >= 0.90) {
  cat(sprintf("✓✓ Best coverage: %.1f%% with α = %.4f\n\n", best_coverage * 100, best_alpha))

  if (best_alpha < 0.01) {
    cat("Using spikier distributions (α < 0.01) FIXES the K=4 problem!\n\n")
    cat("This suggests:\n")
    cat("  • α controls the type-level dispersion after aggregation\n")
    cat("  • For K=4 with n=1000, α=K/n≈0.004 matches ground truth\n")
    cat("  • Users should tune α based on:\n")
    cat("    - How many latent types K they expect\n")
    cat("    - How extreme the population shifts they anticipate\n\n")

    cat("RECOMMENDATION: Add α as user-tunable parameter\n")
    cat("  • Default: α = 1 (uninformative at observation level)\n")
    cat("  • Guidance: Use α ≈ K/n if you know K\n")
    cat("  • Document: Smaller α → more extreme shifts expected\n")
  } else {
    cat("Moderate α values work for K=4.\n\n")
    cat("This suggests the original default α=1 may be too concentrated.\n")
  }
} else {
  cat(sprintf("✗ Best coverage only %.1f%% (target: ≥90%%)\n\n", best_coverage * 100))
  cat("Even with spikier distributions, K=4 coverage remains poor.\n\n")
  cat("Possible reasons:\n")
  cat("  • K=4 with n=1000 still too concentrated (250 obs/type)\n")
  cat("  • Need even smaller α (< 0.004)?\n")
  cat("  • Fundamental limitation of finite samples for small K?\n\n")

  cat("RECOMMENDATION: Focus validation on K ≥ 100\n")
  cat("  • K=4 may be too small for this validation approach\n")
  cat("  • Real applications likely have K >> 4\n")
  cat("  • Document: Method requires sufficient type diversity\n")
}

cat("================================================================\n")
cat("Test complete!\n")
cat("================================================================\n")
