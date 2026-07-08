#!/usr/bin/env Rscript
# Simulation Study: Verify Doubly Robust Property
#
# Tests that the DR IF gives valid coverage when:
# 1. Both outcome and PS models correct
# 2. Outcome model correct, PS model wrong
# 3. Outcome model wrong, PS model correct
# 4. Both models wrong (should fail)

library(surrogateTransportability)
library(dplyr)
library(ggplot2)

set.seed(20260408)

# Simulation parameters
n_sim <- 500  # Number of simulation replications
n_obs <- 300  # Sample size per replication
alpha <- 0.05  # Significance level

# Data generating process
# True model:
#   τ_S(X) = 0.3 + 0.4·X₁ + 0.2·X₁² (quadratic in X1)
#   τ_Y(X) = 0.4 + 0.5·X₁ + 0.3·X₁² (quadratic in X1)
#   e(X) = expit(0.5·X₂) (depends on X2, not X1)
#
# True E[τ_S·τ_Y] ≈ 0.35 (computed from DGP)

generate_dr_data <- function(n) {
  X1 <- rnorm(n)
  X2 <- rnorm(n)

  # True propensity score depends on X2
  logit_e <- 0.5 * X2
  e_true <- plogis(logit_e)
  A <- rbinom(n, 1, e_true)

  # True treatment effects (quadratic in X1)
  tau_S_true <- 0.3 + 0.4 * X1 + 0.2 * X1^2
  tau_Y_true <- 0.4 + 0.5 * X1 + 0.3 * X1^2

  # Generate outcomes
  S <- A * tau_S_true + rnorm(n, sd = 0.5)
  Y <- A * tau_Y_true + rnorm(n, sd = 0.5)

  data.frame(A = A, S = S, Y = Y, X1 = X1, X2 = X2)
}

# Compute true parameter (Monte Carlo with large sample)
cat("Computing true parameter...\n")
large_data <- generate_dr_data(10000)
tau_S_large <- 0.3 + 0.4 * large_data$X1 + 0.2 * large_data$X1^2
tau_Y_large <- 0.4 + 0.5 * large_data$X1 + 0.3 * large_data$X1^2
true_param <- mean(tau_S_large * tau_Y_large)
cat(sprintf("True E[τ_S·τ_Y] = %.4f\n\n", true_param))

# Simulation function
run_simulation <- function(use_ps, outcome_method, ps_method) {
  results <- data.frame(
    phi_star = numeric(n_sim),
    se = numeric(n_sim),
    ci_lower = numeric(n_sim),
    ci_upper = numeric(n_sim),
    covered = logical(n_sim)
  )

  for (i in 1:n_sim) {
    if (i %% 100 == 0) cat(sprintf("  Replication %d/%d\n", i, n_sim))

    # Generate data
    data <- generate_dr_data(n_obs)

    # Run inference
    tryCatch({
      result <- wasserstein_minimax_IF_inference(
        data = data,
        covariates = c("X1", "X2"),
        gamma = 0.5,
        tau = 0.1,
        K = 3,
        method = outcome_method,
        use_propensity_scores = use_ps,
        propensity_method = ps_method
      )

      results$phi_star[i] <- result$phi_star
      results$se[i] <- result$se
      results$ci_lower[i] <- result$ci_lower
      results$ci_upper[i] <- result$ci_upper
      results$covered[i] <- (true_param >= result$ci_lower & true_param <= result$ci_upper)

    }, error = function(e) {
      cat(sprintf("  Error in rep %d: %s\n", i, e$message))
      results$covered[i] <- NA
    })
  }

  results
}

# Scenario 1: Both correct (GAM for outcomes, GAM for PS)
cat("Scenario 1: Both models correct (GAM outcomes, GAM PS)...\n")
scenario1 <- run_simulation(
  use_ps = TRUE,
  outcome_method = "gam",
  ps_method = "gam"
)

# Scenario 2: Outcome correct, PS wrong (GAM for outcomes, linear PS)
cat("\nScenario 2: Outcome correct, PS wrong (GAM outcomes, logistic PS)...\n")
scenario2 <- run_simulation(
  use_ps = TRUE,
  outcome_method = "gam",
  ps_method = "logistic"  # Wrong: linear in X, but true depends nonlinearly on X2
)

# Scenario 3: Outcome wrong, PS correct (linear outcomes, GAM PS)
cat("\nScenario 3: Outcome wrong, PS correct (linear outcomes, GAM PS)...\n")
scenario3 <- run_simulation(
  use_ps = TRUE,
  outcome_method = "lm",  # Wrong: linear, but true is quadratic
  ps_method = "gam"
)

# Scenario 4: Both wrong (linear outcomes, linear PS)
cat("\nScenario 4: Both models wrong (linear outcomes, logistic PS)...\n")
scenario4 <- run_simulation(
  use_ps = TRUE,
  outcome_method = "lm",
  ps_method = "logistic"
)

# Scenario 5: No PS (assumes e=0.5) with correct outcomes
cat("\nScenario 5: No PS (e=0.5), GAM outcomes...\n")
scenario5 <- run_simulation(
  use_ps = FALSE,
  outcome_method = "gam",
  ps_method = "logistic"  # Not used
)

# Scenario 6: No PS with wrong outcomes
cat("\nScenario 6: No PS (e=0.5), linear outcomes...\n")
scenario6 <- run_simulation(
  use_ps = FALSE,
  outcome_method = "lm",
  ps_method = "logistic"  # Not used
)

# Compile results
compile_results <- function(scenario_data, scenario_name) {
  valid <- !is.na(scenario_data$covered)

  data.frame(
    Scenario = scenario_name,
    Coverage = mean(scenario_data$covered[valid]),
    Mean_Estimate = mean(scenario_data$phi_star[valid]),
    Bias = mean(scenario_data$phi_star[valid]) - true_param,
    Mean_SE = mean(scenario_data$se[valid]),
    Empirical_SE = sd(scenario_data$phi_star[valid]),
    N_Valid = sum(valid)
  )
}

summary_table <- bind_rows(
  compile_results(scenario1, "1. Both correct (GAM/GAM)"),
  compile_results(scenario2, "2. Outcome correct, PS wrong (GAM/logistic)"),
  compile_results(scenario3, "3. Outcome wrong, PS correct (lm/GAM)"),
  compile_results(scenario4, "4. Both wrong (lm/logistic)"),
  compile_results(scenario5, "5. No PS, outcome correct (e=0.5/GAM)"),
  compile_results(scenario6, "6. No PS, outcome wrong (e=0.5/lm)")
)

# Print results
cat("\n")
cat("=================================================================\n")
cat("DOUBLY ROBUST VERIFICATION RESULTS\n")
cat("=================================================================\n")
cat(sprintf("True parameter: E[τ_S·τ_Y] = %.4f\n", true_param))
cat(sprintf("Sample size: n = %d, Replications: %d\n", n_obs, n_sim))
cat(sprintf("Nominal coverage: %.1f%%\n\n", 100 * (1 - alpha)))

print(summary_table, digits = 4)

# Save results
results_file <- "sims/results/30_doubly_robust_verification.rds"
saveRDS(list(
  summary = summary_table,
  scenario1 = scenario1,
  scenario2 = scenario2,
  scenario3 = scenario3,
  scenario4 = scenario4,
  scenario5 = scenario5,
  scenario6 = scenario6,
  true_param = true_param
), results_file)

cat(sprintf("\nResults saved to: %s\n", results_file))

# Create visualization
cat("\nGenerating plots...\n")

# Coverage plot
p_coverage <- ggplot(summary_table, aes(x = Scenario, y = Coverage)) +
  geom_col(fill = "steelblue") +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "red") +
  geom_hline(yintercept = 0.90, linetype = "dotted", color = "orange") +
  ylim(0, 1) +
  labs(
    title = "Coverage by Scenario",
    subtitle = sprintf("True E[τ_S·τ_Y] = %.3f, n = %d, %d replications",
                       true_param, n_obs, n_sim),
    x = "", y = "Coverage Probability"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("sims/results/30_coverage_by_scenario.pdf", p_coverage, width = 10, height = 6)

# Bias plot
p_bias <- ggplot(summary_table, aes(x = Scenario, y = Bias)) +
  geom_col(fill = "coral") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "black") +
  labs(
    title = "Bias by Scenario",
    subtitle = sprintf("True E[τ_S·τ_Y] = %.3f", true_param),
    x = "", y = "Bias (Estimate - Truth)"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("sims/results/30_bias_by_scenario.pdf", p_bias, width = 10, height = 6)

cat("Plots saved to sims/results/\n")

# Interpretation
cat("\n=================================================================\n")
cat("INTERPRETATION:\n")
cat("=================================================================\n")
cat("Doubly robust property holds if coverage is valid (≥90%) when:\n")
cat("  - EITHER outcome model is correct (Scenarios 1, 2, 5)\n")
cat("  - OR propensity score model is correct (Scenarios 1, 3)\n")
cat("\nExpected failures:\n")
cat("  - Scenario 4: Both wrong (coverage < 90%)\n")
cat("  - Scenario 6: No PS, outcome wrong (coverage < 90%)\n")
cat("\nExpected successes:\n")
cat("  - Scenarios 1, 2, 3: DR property (coverage ≥ 90%)\n")
cat("  - Scenario 5: Correct outcome, randomized (coverage ≥ 90%)\n")
cat("=================================================================\n")
