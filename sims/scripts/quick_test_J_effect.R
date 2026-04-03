#!/usr/bin/env Rscript
#' Quick Test: Does Increasing J Fix the Coverage Issue?
#'
#' Tests J = 16, 32, 64 with discretization
#' 30 reps each for quick results (~20-30 minutes)

library(tidyverse)
library(here)

# Load package
devtools::load_all(here("package"))

cat("========================================\n")
cat("QUICK TEST: Effect of J on Coverage\n")
cat("========================================\n\n")

# Same worst setting from Diagnostic 1
WORST_SETTING <- list(
  n = 250,
  scenario = "low_het_high_cor",
  lambda = 0.4,
  rho = 0.9,
  cv = 0.1
)

N_REPS <- 30  # Quick test

cat("Testing J values: 16, 32, 64\n")
cat("Replications per J:", N_REPS, "\n")
cat("Setting: n=", WORST_SETTING$n, ", λ=", WORST_SETTING$lambda, "\n\n")

# Data generation function
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
    true_concordance_p0 = true_concordance_p0,
    true_min_concordance = true_min_concordance
  )
}

# Test each J value
J_values <- c(16, 32, 64)
all_results <- list()

for (J_test in J_values) {
  cat("========================================\n")
  cat("Testing J =", J_test, "\n")
  cat("========================================\n")

  results <- map_dfr(1:N_REPS, function(rep) {
    if (rep %% 10 == 0) cat("  Rep", rep, "/", N_REPS, "\n")

    dgp <- generate_data_with_true_types(
      WORST_SETTING$n, J_test,
      WORST_SETTING$rho, WORST_SETTING$cv,
      seed = rep + J_test * 1000
    )

    true_minimax <- (1 - WORST_SETTING$lambda) * dgp$true_concordance_p0 +
                    WORST_SETTING$lambda * dgp$true_min_concordance

    # Test with discretization
    est <- tryCatch({
      surrogate_inference_minimax(
        current_data = dgp$data,
        lambda = WORST_SETTING$lambda,
        functional_type = "concordance",
        discretization_schemes = c("quantiles"),  # Use one for speed
        J_target = J_test,
        n_bootstrap = 100,
        confidence_level = 0.95,
        parallel = FALSE,
        verbose = FALSE
      )
    }, error = function(e) {
      cat("  ERROR rep", rep, ":", conditionMessage(e), "\n")
      NULL
    })

    if (is.null(est) || !is.list(est)) return(NULL)

    # Extract values
    val_est <- est$phi_star
    val_ci_lower <- est$ci_lower
    val_ci_upper <- est$ci_upper

    tibble(
      J = J_test,
      rep = rep,
      estimate = val_est,
      ci_lower = val_ci_lower,
      ci_upper = val_ci_upper,
      truth = true_minimax,
      bias = val_est - true_minimax,
      covered = (true_minimax >= val_ci_lower & true_minimax <= val_ci_upper),
      ci_width = val_ci_upper - val_ci_lower
    )
  })

  results <- results %>% filter(!is.na(rep))

  summary_J <- list(
    J = J_test,
    coverage = mean(results$covered, na.rm = TRUE),
    mean_estimate = mean(results$estimate, na.rm = TRUE),
    mean_truth = mean(results$truth, na.rm = TRUE),
    bias = mean(results$bias, na.rm = TRUE),
    mean_ci_width = mean(results$ci_width, na.rm = TRUE),
    n_reps = nrow(results)
  )

  cat("\nRESULTS for J =", J_test, ":\n")
  cat("  Coverage:", round(summary_J$coverage, 3), "\n")
  cat("  Mean estimate:", round(summary_J$mean_estimate, 4), "\n")
  cat("  Mean truth:", round(summary_J$mean_truth, 4), "\n")
  cat("  Bias:", round(summary_J$bias, 4), "\n")
  cat("  Mean CI width:", round(summary_J$mean_ci_width, 4), "\n\n")

  all_results[[as.character(J_test)]] <- list(
    summary = summary_J,
    results = results
  )
}

# Overall summary
cat("========================================\n")
cat("SUMMARY: Coverage by J\n")
cat("========================================\n\n")

summary_table <- map_dfr(J_values, function(J) {
  s <- all_results[[as.character(J)]]$summary
  tibble(
    J = s$J,
    Coverage = s$coverage,
    Bias = s$bias,
    Mean_Estimate = s$mean_estimate,
    Mean_Truth = s$mean_truth,
    N_Reps = s$n_reps
  )
})

print(summary_table, n = Inf)

cat("\n========================================\n")
cat("INTERPRETATION\n")
cat("========================================\n\n")

max_coverage <- max(summary_table$Coverage, na.rm = TRUE)

if (max_coverage >= 0.90) {
  best_J <- summary_table %>% filter(Coverage >= 0.90) %>% pull(J) %>% min()
  cat("✓ SOLUTION FOUND: Increasing J fixes the issue!\n")
  cat("  Recommended J:", best_J, "(achieves", round(max_coverage * 100, 1), "% coverage)\n\n")
  cat("ACTION: Update default J_target from 16 to", best_J, "\n")
} else if (max_coverage >= 0.80) {
  cat("~ PARTIAL FIX: Increasing J helps but doesn't fully solve it\n")
  cat("  Max coverage:", round(max_coverage * 100, 1), "% (need 93-95%)\n\n")
  cat("ACTION: Increase J AND investigate other issues (formula? ensemble?)\n")
} else {
  cat("✗ NOT THE SOLUTION: Increasing J doesn't fix it\n")
  cat("  Max coverage:", round(max_coverage * 100, 1), "% even with J=64\n\n")
  cat("ACTION: The issue is NOT J size. Investigate:\n")
  cat("  - Formula implementation bug\n")
  cat("  - Discretization method (not just J)\n")
  cat("  - Ensemble minimum effect\n")
}

cat("\n")

# Save results
saveRDS(all_results, here("sims/results/quick_test_J_effect.rds"))
cat("Results saved to: sims/results/quick_test_J_effect.rds\n")
