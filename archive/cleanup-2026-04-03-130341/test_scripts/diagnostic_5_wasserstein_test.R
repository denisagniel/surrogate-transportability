#!/usr/bin/env Rscript
# DIAGNOSTIC 5: Does Wasserstein work correctly?

library(tidyverse)
library(here)
library(MCMCpack)

devtools::load_all(here("package"))

# Use EXACT same DGP
generate_data_with_true_types <- function(n, J, rho, cv, seed) {
  set.seed(seed)
  tau_y <- rnorm(J, mean = 0.5, sd = cv)
  tau_s <- rho * tau_y + sqrt(1 - rho^2) * rnorm(J, sd = cv)
  pi_types <- rep(1/J, J)

  true_types <- sample(1:J, size = n, replace = TRUE, prob = pi_types)
  A <- rbinom(n, 1, 0.5)
  X <- rnorm(n)

  S <- tau_s[true_types] * A + 0.3 * X + rnorm(n, sd = 0.5)
  Y <- tau_y[true_types] * A + 0.2 * X + rnorm(n, sd = 0.4)

  data <- tibble(type = true_types, A = A, X = X, S = S, Y = Y)

  true_concordance_p0 <- sum(pi_types * tau_s * tau_y)
  true_min_concordance <- min(tau_s * tau_y)

  list(
    data = data,
    true_types = true_types,
    tau_s = tau_s,
    tau_y = tau_y,
    pi_types = pi_types,
    true_concordance_p0 = true_concordance_p0,
    true_min_concordance = true_min_concordance
  )
}

cat("========================================\n")
cat("DIAGNOSTIC 5: TV-Ball vs Wasserstein\n")
cat("========================================\n\n")

# Settings
n <- 250
J <- 16
rho <- 0.9
cv <- 0.1
lambda <- 0.4
n_reps <- 50  # Smaller for speed

cat("Testing with:\n")
cat("  n =", n, "\n")
cat("  J =", J, "\n")
cat("  rho =", rho, "\n")
cat("  lambda =", lambda, "\n")
cat("  reps =", n_reps, "\n\n")

results <- map_dfr(1:n_reps, function(rep) {
  if (rep %% 5 == 0) cat("  Rep", rep, "/", n_reps, "\n")

  dgp <- generate_data_with_true_types(n, J, rho, cv, seed = rep + 50000)

  true_minimax <- (1 - lambda) * dgp$true_concordance_p0 + lambda * dgp$true_min_concordance

  # TV-BALL (closed-form, known to be buggy)
  result_tv <- tryCatch({
    surrogate_inference_minimax(
      current_data = dgp$data,
      lambda = lambda,
      functional_type = "concordance",
      discretization_schemes = "quantiles",  # Just one for speed
      J_target = J,
      n_bootstrap = 100,
      confidence_level = 0.95,
      parallel = FALSE,
      verbose = FALSE
    )
  }, error = function(e) {
    cat("  ERROR in TV-ball rep", rep, ":", conditionMessage(e), "\n")
    NULL
  })

  # WASSERSTEIN (dual optimization)
  # Note: lambda_w scale is different from lambda (TV)
  # For concordance ~0.17, reasonable lambda_w might be 0.1-0.5
  result_wass <- tryCatch({
    surrogate_inference_minimax_wasserstein(
      current_data = dgp$data,
      lambda_w = 0.3,  # Try a reasonable value
      functional_type = "concordance",
      discretization_schemes = "quantiles",
      J_target = J,
      n_bootstrap = 100,
      confidence_level = 0.95,
      verbose = FALSE
    )
  }, error = function(e) {
    cat("  ERROR in Wasserstein rep", rep, ":", conditionMessage(e), "\n")
    NULL
  })

  if (is.null(result_tv) || is.null(result_wass)) {
    return(tibble(rep = rep, status = "error"))
  }

  tibble(
    rep = rep,
    status = "success",
    truth = true_minimax,

    # TV-ball results
    est_tv = result_tv$phi_star,
    ci_lower_tv = result_tv$ci_lower,
    ci_upper_tv = result_tv$ci_upper,
    covered_tv = (true_minimax >= result_tv$ci_lower & true_minimax <= result_tv$ci_upper),

    # Wasserstein results
    est_wass = result_wass$phi_star,
    ci_lower_wass = result_wass$ci_lower,
    ci_upper_wass = result_wass$ci_upper,
    covered_wass = (true_minimax >= result_wass$ci_lower & true_minimax <= result_wass$ci_upper)
  )
})

# Filter to successful runs
results_success <- results %>% filter(status == "success")

if (nrow(results_success) == 0) {
  cat("\n*** ALL REPLICATIONS FAILED ***\n")
  cat("Cannot compare methods.\n")
  quit(status = 1)
}

cat("\n==== RESULTS (", nrow(results_success), "successful reps) ====\n\n")

# Summary statistics
cat("TV-BALL (closed-form):\n")
cat("  Mean estimate:", round(mean(results_success$est_tv), 4), "\n")
cat("  Mean truth:   ", round(mean(results_success$truth), 4), "\n")
cat("  Bias:         ", round(mean(results_success$est_tv - results_success$truth), 4), "\n")
cat("  Coverage:     ", round(mean(results_success$covered_tv), 3), "\n")
cat("  Mean CI width:", round(mean(results_success$ci_upper_tv - results_success$ci_lower_tv), 4), "\n\n")

cat("WASSERSTEIN (dual optimization):\n")
cat("  Mean estimate:", round(mean(results_success$est_wass), 4), "\n")
cat("  Mean truth:   ", round(mean(results_success$truth), 4), "\n")
cat("  Bias:         ", round(mean(results_success$est_wass - results_success$truth), 4), "\n")
cat("  Coverage:     ", round(mean(results_success$covered_wass), 3), "\n")
cat("  Mean CI width:", round(mean(results_success$ci_upper_wass - results_success$ci_lower_wass), 4), "\n\n")

cat("==== DIAGNOSIS ====\n")

tv_coverage <- mean(results_success$covered_tv)
wass_coverage <- mean(results_success$covered_wass)

tv_bias <- abs(mean(results_success$est_tv - results_success$truth))
wass_bias <- abs(mean(results_success$est_wass - results_success$truth))

if (wass_coverage >= 0.90 && tv_coverage < 0.70) {
  cat("✓ WASSERSTEIN WORKS! TV-ball is the problem.\n")
  cat("  Wasserstein coverage:", round(wass_coverage, 2), "(good)\n")
  cat("  TV-ball coverage:    ", round(tv_coverage, 2), "(bad)\n\n")
  cat("RECOMMENDATION: Use Wasserstein for concordance functional.\n")
  cat("The cost matrix preserves covariate structure → more robust.\n")

} else if (wass_coverage >= 0.90 && tv_coverage >= 0.90) {
  cat("✓ BOTH WORK with quantiles only.\n")
  cat("  Problem was likely the ensemble minimum (taking min over RF/quantiles/kmeans).\n\n")
  cat("RECOMMENDATION: Use single scheme (quantiles) for both metrics.\n")

} else if (wass_coverage < 0.70 && tv_coverage < 0.70) {
  cat("✗ BOTH FAIL. Problem is not TV vs Wasserstein geometry.\n")
  cat("  Wasserstein coverage:", round(wass_coverage, 2), "\n")
  cat("  TV-ball coverage:    ", round(tv_coverage, 2), "\n\n")
  cat("RECOMMENDATION: Need observation-level approach (no discretization).\n")

} else {
  cat("MIXED RESULTS:\n")
  cat("  Wasserstein coverage:", round(wass_coverage, 2), "\n")
  cat("  TV-ball coverage:    ", round(tv_coverage, 2), "\n")
  cat("  Wasserstein bias:    ", round(wass_bias, 4), "\n")
  cat("  TV-ball bias:        ", round(tv_bias, 4), "\n\n")

  if (wass_bias < tv_bias - 0.02) {
    cat("Wasserstein has lower bias → preferred.\n")
  } else if (tv_bias < wass_bias - 0.02) {
    cat("TV-ball has lower bias → preferred.\n")
  } else {
    cat("Similar bias. Need further investigation.\n")
  }
}

cat("\n==== SAMPLE OF RESULTS ====\n")
print(results_success %>% select(rep, truth, est_tv, est_wass, covered_tv, covered_wass) %>% head(10))

# Save results
saveRDS(results_success, here("sims/results/diagnostic_5_wasserstein.rds"))
cat("\nResults saved to: sims/results/diagnostic_5_wasserstein.rds\n")
