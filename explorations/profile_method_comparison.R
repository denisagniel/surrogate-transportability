# Profile Method Comparison Simulation
# Test timing and sanity check for formal simulation study

library(tidyverse)

# Test parameters
N_PROFILE_REPS <- 10
N <- 500
M_FUTURE <- 100  # Number of future studies for our method

# Scenario 1 DGP: High ρ, Low PTE
generate_dgp_scenario1 <- function(n, p_x = 0.5, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  X <- rbinom(n, 1, p_x)
  A <- rbinom(n, 1, 0.5)

  # Treatment effects depend on X (effect modification)
  # Strong A×X interactions for both S and Y, but NO S→Y causality

  # S model: logit scale with A×X interaction
  logit_S <- -1.5 + 0.5*A + 0.3*X + 2.0*A*X
  S <- rbinom(n, 1, plogis(logit_S))

  # Y model: logit scale, NO S effect (separate pathway)
  logit_Y <- -1.5 + 0.3*A + 0.5*X + 0.1*S + 1.8*A*X
  Y <- rbinom(n, 1, plogis(logit_Y))

  tibble(X = X, A = A, S = S, Y = Y)
}

# Scenario 2 DGP: Undefined ρ, High PTE
generate_dgp_scenario2 <- function(n, p_x = 0.5, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  X <- rbinom(n, 1, p_x)
  A <- rbinom(n, 1, 0.5)

  # S model: CONSTANT treatment effect (no A×X, no X main effect)
  logit_S <- -1.0 + 1.5*A
  S <- rbinom(n, 1, plogis(logit_S))

  # Y model: NO direct A effect, STRONG S effect with S×X interaction
  # Treatment effect on Y is entirely through S, and varies by X
  logit_Y <- -2.0 + 0.8*X + 2.5*S + 1.2*S*X
  Y <- rbinom(n, 1, plogis(logit_Y))

  tibble(X = X, A = A, S = S, Y = Y)
}

# Our method: Across-study correlation
compute_across_study_cor <- function(data, M = 100) {
  # Sample M future studies with different P(X)
  p_x_values <- runif(M, 0.1, 0.9)

  effects <- map_dfr(p_x_values, function(px) {
    # Resample data to match new P(X)
    n_x1 <- round(nrow(data) * px)
    n_x0 <- nrow(data) - n_x1

    future_data <- bind_rows(
      data %>% filter(X == 1) %>% sample_n(n_x1, replace = TRUE),
      data %>% filter(X == 0) %>% sample_n(n_x0, replace = TRUE)
    )

    # Compute treatment effects
    delta_s <- mean(future_data$S[future_data$A == 1]) -
               mean(future_data$S[future_data$A == 0])
    delta_y <- mean(future_data$Y[future_data$A == 1]) -
               mean(future_data$Y[future_data$A == 0])

    tibble(delta_s = delta_s, delta_y = delta_y)
  })

  cor(effects$delta_s, effects$delta_y)
}

# Traditional methods (simplified for profiling)
compute_pte_simple <- function(data) {
  # Total effect
  E_Y_A1 <- mean(data$Y[data$A == 1])
  E_Y_A0 <- mean(data$Y[data$A == 0])
  total_effect <- E_Y_A1 - E_Y_A0

  if (abs(total_effect) < 1e-10) return(NA_real_)

  # Adjusted effect (conditional on S)
  adjusted_effect <- 0
  for (s in 0:1) {
    p_S <- mean(data$S[data$A == 0] == s)

    y_a1_s <- data$Y[data$A == 1 & data$S == s]
    y_a0_s <- data$Y[data$A == 0 & data$S == s]

    if (length(y_a1_s) == 0 || length(y_a0_s) == 0) next

    effect_s <- mean(y_a1_s) - mean(y_a0_s)
    adjusted_effect <- adjusted_effect + p_S * effect_s
  }

  1 - adjusted_effect / total_effect
}

# Profile single replication
profile_single_rep <- function(rep_id, scenario) {
  t_start <- Sys.time()

  # Generate data
  data <- if (scenario == 1) {
    generate_dgp_scenario1(N, seed = 2026 + rep_id)
  } else {
    generate_dgp_scenario2(N, seed = 2026 + rep_id)
  }

  # Our method
  t1 <- Sys.time()
  across_cor <- compute_across_study_cor(data, M = M_FUTURE)
  t2 <- Sys.time()
  time_our_method <- as.numeric(difftime(t2, t1, units = "secs"))

  # PTE (simplified)
  t3 <- Sys.time()
  pte <- compute_pte_simple(data)
  t4 <- Sys.time()
  time_pte <- as.numeric(difftime(t4, t3, units = "secs"))

  t_end <- Sys.time()
  total_time <- as.numeric(difftime(t_end, t_start, units = "secs"))

  list(
    scenario = scenario,
    rep_id = rep_id,
    total_time = total_time,
    time_our_method = time_our_method,
    time_pte = time_pte,
    across_cor = across_cor,
    pte = pte
  )
}

# Run profiling
cat("=== PROFILING METHOD COMPARISON ===\n")
cat("N =", N, "| M_future =", M_FUTURE, "| Reps =", N_PROFILE_REPS, "\n\n")

cat("Profiling Scenario 1 (High ρ, Low PTE)...\n")
results_1 <- map_dfr(1:N_PROFILE_REPS, ~profile_single_rep(.x, scenario = 1))

cat("\nProfiling Scenario 2 (Undefined ρ, High PTE)...\n")
results_2 <- map_dfr(1:N_PROFILE_REPS, ~profile_single_rep(.x, scenario = 2))

# Summary
results_all <- bind_rows(results_1, results_2)

cat("\n=== PROFILING RESULTS ===\n")
cat("\nPer-replication timing (seconds):\n")
timing_summary <- results_all %>%
  group_by(scenario) %>%
  summarize(
    mean_total = mean(total_time),
    sd_total = sd(total_time),
    mean_our_method = mean(time_our_method),
    mean_pte = mean(time_pte),
    .groups = "drop"
  )
print(timing_summary)

cat("\n\nEstimated time for 1000 reps per scenario:\n")
mean_time_per_rep <- mean(results_all$total_time)
total_time_minutes <- (mean_time_per_rep * 1000) / 60
total_time_both <- total_time_minutes * 2
cat(sprintf("  Per scenario: %.1f minutes\n", total_time_minutes))
cat(sprintf("  Both scenarios: %.1f minutes (%.2f hours)\n",
            total_time_both, total_time_both / 60))

if (total_time_both <= 30) {
  cat("\n✓ RECOMMENDATION: Run locally (< 30 min total)\n")
} else if (total_time_both <= 120) {
  cat("\n⚠ RECOMMENDATION: Consider cluster for convenience (30-120 min)\n")
} else {
  cat("\n✗ RECOMMENDATION: Use cluster (> 2 hours)\n")
}

cat("\n\nEstimates (sanity check):\n")
estimate_summary <- results_all %>%
  group_by(scenario) %>%
  summarize(
    mean_across_cor = mean(across_cor, na.rm = TRUE),
    sd_across_cor = sd(across_cor, na.rm = TRUE),
    mean_pte = mean(pte, na.rm = TRUE),
    sd_pte = sd(pte, na.rm = TRUE),
    .groups = "drop"
  )
print(estimate_summary)

cat("\n\nDivergence check:\n")
cat("Expected patterns:\n")
cat("  Scenario 1: High ρ (>0.6), Low PTE (<0.4)\n")
cat("  Scenario 2: Low ρ (<0.3) or undefined, High PTE (>0.6)\n")

cat("\nObserved patterns:\n")
scenario1_results <- results_all %>% filter(scenario == 1)
scenario2_results <- results_all %>% filter(scenario == 2)

s1_cor_mean <- mean(scenario1_results$across_cor, na.rm = TRUE)
s1_pte_mean <- mean(scenario1_results$pte, na.rm = TRUE)
s2_cor_mean <- mean(scenario2_results$across_cor, na.rm = TRUE)
s2_pte_mean <- mean(scenario2_results$pte, na.rm = TRUE)

cat(sprintf("  Scenario 1: ρ = %.2f, PTE = %.2f", s1_cor_mean, s1_pte_mean))
if (s1_cor_mean > 0.6 && s1_pte_mean < 0.4) {
  cat(" ✓\n")
} else {
  cat(" ✗ (unexpected pattern)\n")
}

cat(sprintf("  Scenario 2: ρ = %.2f, PTE = %.2f", s2_cor_mean, s2_pte_mean))
if ((is.na(s2_cor_mean) || s2_cor_mean < 0.3) && s2_pte_mean > 0.6) {
  cat(" ✓\n")
} else {
  cat(" ✗ (unexpected pattern)\n")
}

cat("\n=== PROFILING COMPLETE ===\n")
