# Comparison Study: Three Approaches for TV Ball Correlation Inference
#
# Compares three methods for computing treatment effects and influence functions:
# 1. Importance weighting (explicit w_i = Q(X_i)/P₀(X_i))
# 2. Bootstrap resampling (resample with probabilities Q_m)
# 3. AIPW (augmented IPW with cross-fitted nuisances)
#
# Research question: Do the three approaches give similar results empirically?
# Theory says importance weighting and bootstrap are equivalent; AIPW adds
# robustness via outcome regression.

library(dplyr)
library(ggplot2)
library(tidyr)

# Source dependencies
devtools::load_all()
source("explorations/calibrate_5level_x_dgp.R")

# =============================================================================
# Setup: DGP and Parameters
# =============================================================================

params <- list(
  gamma_A = 1.0,
  gamma_AX = 0.5,
  beta_A = 0.25,
  beta_AX = -0.3,
  beta_S = 0.9,
  beta_SX = -0.1,
  sigma_S = 0.5,
  sigma_Y = 0.5
)

p_X_0 <- c(0.05, 0.25, 0.40, 0.25, 0.05)
X_levels <- c(-2, -1, 0, 1, 2)

# Study parameters
n <- 5000  # Use n=5000 based on CATE validation results
lambda <- 0.3
M <- 500  # Number of future studies
alpha <- 0.05

cat("\n=== Three-Method Comparison Study ===\n")
cat(sprintf("Sample size: n=%d (based on CATE validation)\n", n))
cat(sprintf("TV ball radius: λ=%.2f\n", lambda))
cat(sprintf("Number of future studies: M=%d\n", M))

# =============================================================================
# Step 1: Compute True Correlation
# =============================================================================

cat("\n--- Step 1: Computing True Correlation ---\n")

set.seed(2026)
true_cor_result <- compute_correlation_5level(
  p_X_0 = p_X_0,
  lambda = lambda,
  params = params,
  n_studies = 100,
  n_per_study = 50000
)

true_cor <- true_cor_result$correlation
cat(sprintf("True correlation: %.4f\n", true_cor))

# =============================================================================
# Step 2: Single-Dataset Comparison
# =============================================================================

cat("\n--- Step 2: Single-Dataset Comparison ---\n")
cat("Running all three methods on the same dataset...\n")

set.seed(2027)
data <- generate_5level_x_data(n = n, p_X = p_X_0, params = params)

# Method A: Importance Weighting
cat("\n  Method A: Importance Weighting\n")
time_A <- system.time({
  result_A <- tv_ball_correlation_IF(
    data = data,
    lambda = lambda,
    M = M,
    method = "importance_weighting",
    verbose = FALSE
  )
})
cat(sprintf("    ρ̂ = %.4f (SE = %.4f)\n", result_A$rho_hat, result_A$se))
cat(sprintf("    95%% CI: [%.4f, %.4f]\n", result_A$ci_lower, result_A$ci_upper))
cat(sprintf("    Time: %.2f sec\n", time_A[3]))

# Method B: Bootstrap
cat("\n  Method B: Bootstrap\n")
time_B <- system.time({
  result_B <- tv_ball_correlation_IF(
    data = data,
    lambda = lambda,
    M = M,
    method = "bootstrap",
    verbose = FALSE
  )
})
cat(sprintf("    ρ̂ = %.4f (SE = %.4f)\n", result_B$rho_hat, result_B$se))
cat(sprintf("    95%% CI: [%.4f, %.4f]\n", result_B$ci_lower, result_B$ci_upper))
cat(sprintf("    Time: %.2f sec\n", time_B[3]))

# Method C: AIPW
cat("\n  Method C: AIPW (with Q_m-specific nuisance fitting)\n")
time_C <- system.time({
  result_C <- tv_ball_correlation_IF(
    data = data,
    lambda = lambda,
    M = M,
    method = "aipw",
    n_folds = 5,
    verbose = FALSE
  )
})
cat(sprintf("    ρ̂ = %.4f (SE = %.4f)\n", result_C$rho_hat, result_C$se))
cat(sprintf("    95%% CI: [%.4f, %.4f]\n", result_C$ci_lower, result_C$ci_upper))
cat(sprintf("    Time: %.2f sec\n", time_C[3]))

# Compare estimates
cat("\n  Comparison:\n")
cat(sprintf("    |ρ̂_A - ρ̂_B| = %.4f\n", abs(result_A$rho_hat - result_B$rho_hat)))
cat(sprintf("    |ρ̂_A - ρ̂_C| = %.4f\n", abs(result_A$rho_hat - result_C$rho_hat)))
cat(sprintf("    |ρ̂_B - ρ̂_C| = %.4f\n", abs(result_B$rho_hat - result_C$rho_hat)))

# Bias from true correlation
cat(sprintf("\n    Bias: A=%.4f, B=%.4f, C=%.4f\n",
            result_A$rho_hat - true_cor,
            result_B$rho_hat - true_cor,
            result_C$rho_hat - true_cor))

# =============================================================================
# Step 3: Simulation Study (100 Replications)
# =============================================================================

cat("\n--- Step 3: Simulation Study (100 replications) ---\n")
cat("This will take a while (especially AIPW)...\n")

n_reps <- 100
results <- data.frame(
  rep = 1:n_reps,
  rho_A = NA, se_A = NA, ci_lower_A = NA, ci_upper_A = NA, time_A = NA,
  rho_B = NA, se_B = NA, ci_lower_B = NA, ci_upper_B = NA, time_B = NA,
  rho_C = NA, se_C = NA, ci_lower_C = NA, ci_upper_C = NA, time_C = NA
)

set.seed(2028)
for (rep in 1:n_reps) {
  if (rep %% 10 == 0) cat(sprintf("  Rep %d/%d...\n", rep, n_reps))

  # Generate data
  data_rep <- generate_5level_x_data(n = n, p_X = p_X_0, params = params)

  # Method A
  time_A_rep <- system.time({
    result_A_rep <- tv_ball_correlation_IF(
      data = data_rep,
      lambda = lambda,
      M = M,
      method = "importance_weighting",
      verbose = FALSE
    )
  })
  results[rep, c("rho_A", "se_A", "ci_lower_A", "ci_upper_A", "time_A")] <-
    c(result_A_rep$rho_hat, result_A_rep$se,
      result_A_rep$ci_lower, result_A_rep$ci_upper, time_A_rep[3])

  # Method B
  time_B_rep <- system.time({
    result_B_rep <- tv_ball_correlation_IF(
      data = data_rep,
      lambda = lambda,
      M = M,
      method = "bootstrap",
      verbose = FALSE
    )
  })
  results[rep, c("rho_B", "se_B", "ci_lower_B", "ci_upper_B", "time_B")] <-
    c(result_B_rep$rho_hat, result_B_rep$se,
      result_B_rep$ci_lower, result_B_rep$ci_upper, time_B_rep[3])

  # Method C
  time_C_rep <- system.time({
    result_C_rep <- tv_ball_correlation_IF(
      data = data_rep,
      lambda = lambda,
      M = M,
      method = "aipw",
      n_folds = 5,
      verbose = FALSE
    )
  })
  results[rep, c("rho_C", "se_C", "ci_lower_C", "ci_upper_C", "time_C")] <-
    c(result_C_rep$rho_hat, result_C_rep$se,
      result_C_rep$ci_lower, result_C_rep$ci_upper, time_C_rep[3])
}

# Save results
dir.create("validation/results", showWarnings = FALSE, recursive = TRUE)
saveRDS(results, "validation/results/three_method_comparison.rds")
cat("\nResults saved to validation/results/three_method_comparison.rds\n")

# =============================================================================
# Step 4: Summary Statistics
# =============================================================================

cat("\n--- Step 4: Summary Statistics ---\n")

summary_table <- data.frame(
  Method = c("A: Importance Weighting", "B: Bootstrap", "C: AIPW"),
  Mean_Rho = c(mean(results$rho_A), mean(results$rho_B), mean(results$rho_C)),
  Bias = c(mean(results$rho_A) - true_cor,
           mean(results$rho_B) - true_cor,
           mean(results$rho_C) - true_cor),
  Empirical_SD = c(sd(results$rho_A), sd(results$rho_B), sd(results$rho_C)),
  Mean_SE = c(mean(results$se_A), mean(results$se_B), mean(results$se_C)),
  SE_Calibration = c(sd(results$rho_A) / mean(results$se_A),
                     sd(results$rho_B) / mean(results$se_B),
                     sd(results$rho_C) / mean(results$se_C)),
  Coverage = c(mean(results$ci_lower_A <= true_cor & true_cor <= results$ci_upper_A),
               mean(results$ci_lower_B <= true_cor & true_cor <= results$ci_upper_B),
               mean(results$ci_lower_C <= true_cor & true_cor <= results$ci_upper_C)),
  Mean_Time = c(mean(results$time_A), mean(results$time_B), mean(results$time_C))
)

print(summary_table, row.names = FALSE, digits = 4)

# =============================================================================
# Step 5: Pairwise Comparison
# =============================================================================

cat("\n--- Step 5: Pairwise Comparison ---\n")

# Differences between methods (on same data, so paired)
diff_A_B <- results$rho_A - results$rho_B
diff_A_C <- results$rho_A - results$rho_C
diff_B_C <- results$rho_B - results$rho_C

cat("\nMean absolute differences:\n")
cat(sprintf("  |A - B|: %.4f (SD: %.4f)\n", mean(abs(diff_A_B)), sd(abs(diff_A_B))))
cat(sprintf("  |A - C|: %.4f (SD: %.4f)\n", mean(abs(diff_A_C)), sd(abs(diff_A_C))))
cat(sprintf("  |B - C|: %.4f (SD: %.4f)\n", mean(abs(diff_B_C)), sd(abs(diff_B_C))))

cat("\nCorrelation between estimates:\n")
cat(sprintf("  cor(A, B): %.4f\n", cor(results$rho_A, results$rho_B)))
cat(sprintf("  cor(A, C): %.4f\n", cor(results$rho_A, results$rho_C)))
cat(sprintf("  cor(B, C): %.4f\n", cor(results$rho_B, results$rho_C)))

# =============================================================================
# Step 6: Visualization
# =============================================================================

cat("\n--- Step 6: Generating Plots ---\n")

dir.create("validation/figures", showWarnings = FALSE, recursive = TRUE)

# Plot 1: Point estimates comparison
results_long <- results %>%
  select(rep, rho_A, rho_B, rho_C) %>%
  pivot_longer(cols = c(rho_A, rho_B, rho_C),
               names_to = "method",
               values_to = "rho") %>%
  mutate(method = factor(method,
                         levels = c("rho_A", "rho_B", "rho_C"),
                         labels = c("Importance Weighting", "Bootstrap", "AIPW")))

p1 <- ggplot(results_long, aes(x = method, y = rho, fill = method)) +
  geom_boxplot(alpha = 0.7) +
  geom_hline(yintercept = true_cor, linetype = "dashed", color = "red", linewidth = 1) +
  labs(title = "Point Estimates Comparison",
       subtitle = sprintf("n=%d, M=%d, λ=%.2f, %d reps", n, M, lambda, n_reps),
       x = "Method",
       y = "Correlation Estimate (ρ̂)",
       caption = sprintf("Red dashed line: True correlation = %.4f", true_cor)) +
  theme_minimal() +
  theme(legend.position = "none",
        plot.title = element_text(face = "bold"))

ggsave("validation/figures/three_method_comparison_boxplot.pdf", p1, width = 8, height = 6)

# Plot 2: Scatter plots
p2 <- ggplot(results, aes(x = rho_A, y = rho_B)) +
  geom_point(alpha = 0.5) +
  geom_abline(slope = 1, intercept = 0, color = "red", linetype = "dashed") +
  labs(title = "A vs B: Importance Weighting vs Bootstrap",
       x = "Importance Weighting",
       y = "Bootstrap") +
  theme_minimal() +
  coord_equal()

p3 <- ggplot(results, aes(x = rho_A, y = rho_C)) +
  geom_point(alpha = 0.5, color = "blue") +
  geom_abline(slope = 1, intercept = 0, color = "red", linetype = "dashed") +
  labs(title = "A vs C: Importance Weighting vs AIPW",
       x = "Importance Weighting",
       y = "AIPW") +
  theme_minimal() +
  coord_equal()

p4 <- ggplot(results, aes(x = rho_B, y = rho_C)) +
  geom_point(alpha = 0.5, color = "purple") +
  geom_abline(slope = 1, intercept = 0, color = "red", linetype = "dashed") +
  labs(title = "B vs C: Bootstrap vs AIPW",
       x = "Bootstrap",
       y = "AIPW") +
  theme_minimal() +
  coord_equal()

library(gridExtra)
p_scatter <- grid.arrange(p2, p3, p4, ncol = 2)
ggsave("validation/figures/three_method_comparison_scatter.pdf", p_scatter, width = 12, height = 12)

# Plot 3: Coverage comparison
coverage_data <- data.frame(
  Method = c("Importance Weighting", "Bootstrap", "AIPW"),
  Coverage = c(mean(results$ci_lower_A <= true_cor & true_cor <= results$ci_upper_A),
               mean(results$ci_lower_B <= true_cor & true_cor <= results$ci_upper_B),
               mean(results$ci_lower_C <= true_cor & true_cor <= results$ci_upper_C))
)

p5 <- ggplot(coverage_data, aes(x = Method, y = Coverage, fill = Method)) +
  geom_col(alpha = 0.7) +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "red") +
  geom_text(aes(label = sprintf("%.1f%%", Coverage * 100)), vjust = -0.5) +
  ylim(0, 1) +
  labs(title = "Coverage Comparison",
       subtitle = "Nominal 95% coverage",
       y = "Empirical Coverage",
       x = "") +
  theme_minimal() +
  theme(legend.position = "none",
        plot.title = element_text(face = "bold"))

ggsave("validation/figures/three_method_comparison_coverage.pdf", p5, width = 8, height = 6)

# Plot 4: Computation time
time_data <- data.frame(
  Method = c("Importance Weighting", "Bootstrap", "AIPW"),
  Mean_Time = c(mean(results$time_A), mean(results$time_B), mean(results$time_C))
)

p6 <- ggplot(time_data, aes(x = Method, y = Mean_Time, fill = Method)) +
  geom_col(alpha = 0.7) +
  geom_text(aes(label = sprintf("%.1f sec", Mean_Time)), vjust = -0.5) +
  labs(title = "Computation Time Comparison",
       y = "Mean Time (seconds)",
       x = "") +
  theme_minimal() +
  theme(legend.position = "none",
        plot.title = element_text(face = "bold"))

ggsave("validation/figures/three_method_comparison_time.pdf", p6, width = 8, height = 6)

cat("Plots saved to validation/figures/\n")

# =============================================================================
# Step 7: Decision Criteria and Recommendations
# =============================================================================

cat("\n--- Step 7: Decision Criteria and Recommendations ---\n")

# Define pass/fail criteria
bias_threshold <- 0.05
coverage_min <- 0.93
coverage_max <- 0.97
se_calibration_min <- 0.90
se_calibration_max <- 1.10

decisions <- data.frame(
  Method = c("Importance Weighting", "Bootstrap", "AIPW"),
  Bias_Pass = c(
    abs(summary_table$Bias[1]) < bias_threshold,
    abs(summary_table$Bias[2]) < bias_threshold,
    abs(summary_table$Bias[3]) < bias_threshold
  ),
  Coverage_Pass = c(
    summary_table$Coverage[1] >= coverage_min & summary_table$Coverage[1] <= coverage_max,
    summary_table$Coverage[2] >= coverage_min & summary_table$Coverage[2] <= coverage_max,
    summary_table$Coverage[3] >= coverage_min & summary_table$Coverage[3] <= coverage_max
  ),
  SE_Calibration_Pass = c(
    summary_table$SE_Calibration[1] >= se_calibration_min &
      summary_table$SE_Calibration[1] <= se_calibration_max,
    summary_table$SE_Calibration[2] >= se_calibration_min &
      summary_table$SE_Calibration[2] <= se_calibration_max,
    summary_table$SE_Calibration[3] >= se_calibration_min &
      summary_table$SE_Calibration[3] <= se_calibration_max
  )
)

decisions$Overall_Pass <- decisions$Bias_Pass & decisions$Coverage_Pass &
                           decisions$SE_Calibration_Pass

cat("\nPass/Fail Summary:\n")
print(decisions, row.names = FALSE)

# Recommendation
cat("\n=== Recommendation ===\n")

if (all(decisions$Overall_Pass)) {
  cat("✓ All three methods pass validation criteria.\n")
  cat("\nSpeed ranking:\n")
  cat(sprintf("  1. %s (%.1f sec)\n",
              time_data$Method[which.min(time_data$Mean_Time)],
              min(time_data$Mean_Time)))
  cat(sprintf("  2. %s (%.1f sec)\n",
              time_data$Method[order(time_data$Mean_Time)[2]],
              time_data$Mean_Time[order(time_data$Mean_Time)[2]]))
  cat(sprintf("  3. %s (%.1f sec)\n",
              time_data$Method[which.max(time_data$Mean_Time)],
              max(time_data$Mean_Time)))

  fastest <- time_data$Method[which.min(time_data$Mean_Time)]
  cat(sprintf("\n→ Recommended: %s (fastest, equally valid)\n", fastest))

} else if (sum(decisions$Overall_Pass) > 0) {
  passing_methods <- decisions$Method[decisions$Overall_Pass]
  cat(sprintf("⚠ %d method(s) pass validation:\n", sum(decisions$Overall_Pass)))
  for (m in passing_methods) {
    cat(sprintf("  - %s\n", m))
  }
  cat(sprintf("\n→ Use one of the passing methods.\n"))

} else {
  cat("✗ No methods pass all criteria.\n")
  cat("→ Further investigation needed:\n")
  cat("  - Increase sample size (n > 5000)?\n")
  cat("  - Check DGP properties?\n")
  cat("  - Revisit theoretical assumptions?\n")
}

cat("\n=== Three-Method Comparison Complete ===\n")
