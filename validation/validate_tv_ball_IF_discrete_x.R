# Validation Script: TV Ball Correlation IF with Discrete X DGP
#
# Validates tv_ball_correlation_IF() using a DGP specifically designed for
# discrete X (required by the TV ball sampler).
#
# Key properties:
# - X is binary (required for TV ball)
# - High PTE (~0.7) in reference study
# - Near-zero correlation (~0.0 to 0.1) across TV ball
# - TV ball covers meaningful study variation

# Load development version of package
devtools::load_all(".", quiet = TRUE)

library(ggplot2)
library(dplyr)

source("validation/dgp_discrete_x.R")

set.seed(2026)

# =============================================================================
# Validation 1: Single Estimate Comparison
# =============================================================================

message("\n=== Validation 1: Single Estimate Comparison ===\n")
message("Compare estimated correlation to true correlation\n")

# Step 1: Compute true correlation over TV ball
message("Computing true correlation (100 studies, n=50k each)...")
true_result <- compute_true_correlation_discrete_x(
  p_X_0 = 0.5,
  lambda = 0.3,
  n_studies = 100,
  n_per_study = 50000
)

cat(sprintf("\nTrue correlation: %.4f\n", true_result$correlation))
cat(sprintf("  p_X range: [%.2f, %.2f]\n",
            true_result$p_X_range[1], true_result$p_X_range[2]))
cat(sprintf("  Delta_S range: [%.3f, %.3f]\n",
            min(true_result$Delta_S), max(true_result$Delta_S)))
cat(sprintf("  Delta_Y range: [%.3f, %.3f]\n",
            min(true_result$Delta_Y), max(true_result$Delta_Y)))

# Step 2: Generate reference study data
message("\nGenerating reference study (n=500)...")
data_P0 <- generate_dgp_discrete_x(n = 500, p_X = 0.5)

cat(sprintf("  Sample composition: %.1f%% X=1\n", mean(data_P0$X) * 100))
cat(sprintf("  Sample composition: %.1f%% A=1\n", mean(data_P0$A) * 100))

# Step 3: Estimate correlation with tv_ball_correlation_IF
message("\nEstimating correlation with IF-based method...")
result_IF <- tv_ball_correlation_IF(
  data = data_P0,
  lambda = 0.3,
  M = 500,
  burn_in = 1000,
  thin = 10,
  alpha = 0.05,
  verbose = TRUE
)

# Step 4: Compare
cat("\n--- Comparison ---\n")
cat(sprintf("True correlation:      %.4f\n", true_result$correlation))
cat(sprintf("Estimated correlation: %.4f (SE = %.4f)\n",
            result_IF$rho_hat, result_IF$se))
cat(sprintf("95%% CI:                [%.4f, %.4f]\n",
            result_IF$ci_lower, result_IF$ci_upper))
cat(sprintf("Contains truth?        %s\n",
            ifelse(result_IF$ci_lower <= true_result$correlation &&
                   true_result$correlation <= result_IF$ci_upper, "YES", "NO")))

bias <- result_IF$rho_hat - true_result$correlation
cat(sprintf("Bias:                  %.4f\n", bias))
cat(sprintf("Standardized bias:     %.2f SEs\n", bias / result_IF$se))

# Visualize: True vs Estimated
plot_comparison <- data.frame(
  Delta_S_true = true_result$Delta_S,
  Delta_Y_true = true_result$Delta_Y,
  Delta_S_est = result_IF$Delta_S,
  Delta_Y_est = result_IF$Delta_Y
)

p1 <- ggplot() +
  geom_point(data = plot_comparison,
             aes(x = Delta_S_true, y = Delta_Y_true),
             color = "blue", alpha = 0.5, size = 2) +
  geom_point(data = plot_comparison,
             aes(x = Delta_S_est, y = Delta_Y_est),
             color = "red", alpha = 0.5, size = 2) +
  geom_smooth(data = plot_comparison,
              aes(x = Delta_S_true, y = Delta_Y_true),
              method = "lm", se = FALSE, color = "blue", linetype = "dashed") +
  geom_smooth(data = plot_comparison,
              aes(x = Delta_S_est, y = Delta_Y_est),
              method = "lm", se = FALSE, color = "red", linetype = "dashed") +
  labs(
    title = "True vs Estimated Treatment Effects",
    subtitle = sprintf("True cor: %.3f | Estimated cor: %.3f [%.3f, %.3f]",
                       true_result$correlation,
                       result_IF$rho_hat,
                       result_IF$ci_lower,
                       result_IF$ci_upper),
    x = expression(Delta[S]),
    y = expression(Delta[Y])
  ) +
  scale_color_manual(
    values = c("True" = "blue", "Estimated" = "red"),
    labels = c("True (n=50k)", "Estimated (n=500)")
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

print(p1)

# =============================================================================
# Validation 2: Coverage Simulation
# =============================================================================

message("\n\n=== Validation 2: Coverage Simulation ===\n")
message("Running 50 replications to assess coverage...\n")

n_reps <- 50
coverage_results <- vector("list", n_reps)

# True correlation (computed once, used for all reps)
rho_true <- true_result$correlation

for (rep in seq_len(n_reps)) {
  if (rep %% 10 == 0) message(sprintf("  Replication %d/%d", rep, n_reps))

  # Generate reference study
  data_rep <- generate_dgp_discrete_x(n = 400, p_X = 0.5)

  # Estimate correlation
  result_rep <- tv_ball_correlation_IF(
    data = data_rep,
    lambda = 0.3,
    M = 300,  # Smaller M for faster simulation
    burn_in = 500,
    thin = 5,
    verbose = FALSE
  )

  coverage_results[[rep]] <- data.frame(
    rep = rep,
    rho_hat = result_rep$rho_hat,
    se = result_rep$se,
    ci_lower = result_rep$ci_lower,
    ci_upper = result_rep$ci_upper
  )
}

# Combine results
coverage_df <- bind_rows(coverage_results)

# Assess coverage
coverage_df$covers <- (coverage_df$ci_lower <= rho_true) &
                      (coverage_df$ci_upper >= rho_true)

coverage_rate <- mean(coverage_df$covers)
mean_width <- mean(coverage_df$ci_upper - coverage_df$ci_lower)

cat("\n--- Coverage Results ---\n")
cat(sprintf("True correlation:      %.4f\n", rho_true))
cat(sprintf("Mean estimate:         %.4f (SD: %.4f)\n",
            mean(coverage_df$rho_hat), sd(coverage_df$rho_hat)))
cat(sprintf("Mean SE:               %.4f\n", mean(coverage_df$se)))
cat(sprintf("Empirical SD:          %.4f\n", sd(coverage_df$rho_hat)))
cat(sprintf("SE calibration:        %.2f (SD/mean_SE, should be ≈1)\n",
            sd(coverage_df$rho_hat) / mean(coverage_df$se)))
cat(sprintf("Coverage rate:         %.1f%% (target: 95%%)\n",
            coverage_rate * 100))
cat(sprintf("Mean CI width:         %.4f\n", mean_width))

# Plot coverage
p2 <- ggplot(coverage_df, aes(x = rep, y = rho_hat)) +
  geom_point(aes(color = covers), size = 2) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper, color = covers),
                width = 0.2, alpha = 0.5) +
  geom_hline(yintercept = rho_true, color = "red",
             linetype = "dashed", linewidth = 1) +
  scale_color_manual(
    values = c("TRUE" = "steelblue", "FALSE" = "red"),
    labels = c("TRUE" = "Covers", "FALSE" = "Misses")
  ) +
  labs(
    title = sprintf("Coverage Simulation (%d replications)", n_reps),
    subtitle = sprintf("Coverage: %.0f%% | Mean width: %.3f | True cor: %.3f",
                       coverage_rate * 100, mean_width, rho_true),
    x = "Replication",
    y = expression(hat(rho)),
    color = "CI Status"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

print(p2)

# =============================================================================
# Validation 3: DGP Properties Check
# =============================================================================

message("\n\n=== Validation 3: DGP Properties Check ===\n")

validation <- validate_dgp_discrete_x(
  params = NULL,  # Use defaults
  p_X_0 = 0.5,
  lambda = 0.3,
  n_large = 100000
)

cat("--- DGP Validation ---\n")
cat(sprintf("PTE in P₀:             %.3f (target: ≈0.7)\n", validation$pte))
cat(sprintf("Correlation in TV ball: %.3f (target: ≈0)\n", validation$correlation))
cat(sprintf("ΔS in P₀:              %.3f\n", validation$Delta_S_P0))
cat(sprintf("ΔY in P₀:              %.3f\n", validation$Delta_Y_P0))
cat(sprintf("ΔS range in ball:      %.3f\n", validation$Delta_S_range))
cat(sprintf("ΔY range in ball:      %.3f\n", validation$Delta_Y_range))
cat(sprintf("p_X range:             [%.2f, %.2f]\n",
            validation$p_X_range[1], validation$p_X_range[2]))

cat("\n--- Property Checks ---\n")
cat(sprintf("✓ High PTE:            %s (|PTE - 0.7| < 0.15)\n",
            ifelse(validation$checks$pte_high, "PASS", "FAIL")))
cat(sprintf("✓ Low correlation:     %s (|cor| < 0.15)\n",
            ifelse(validation$checks$correlation_low, "PASS", "FAIL")))
cat(sprintf("✓ Meaningful variation: %s (effects vary across ball)\n",
            ifelse(validation$checks$meaningful_variation, "PASS", "FAIL")))

# =============================================================================
# Validation 4: Sensitivity to Lambda
# =============================================================================

message("\n\n=== Validation 4: Sensitivity to Lambda ===\n")

lambda_values <- c(0.1, 0.2, 0.3, 0.4, 0.5)
lambda_results <- vector("list", length(lambda_values))

# Generate one dataset for all lambda tests
data_lambda <- generate_dgp_discrete_x(n = 500, p_X = 0.5)

for (i in seq_along(lambda_values)) {
  lambda_i <- lambda_values[i]
  message(sprintf("Testing lambda = %.1f", lambda_i))

  # True correlation for this lambda
  true_i <- compute_true_correlation_discrete_x(
    p_X_0 = 0.5,
    lambda = lambda_i,
    n_studies = 50,
    n_per_study = 30000
  )

  # Estimated correlation
  result_i <- tv_ball_correlation_IF(
    data = data_lambda,
    lambda = lambda_i,
    M = 300,
    burn_in = 500,
    thin = 5,
    verbose = FALSE
  )

  lambda_results[[i]] <- data.frame(
    lambda = lambda_i,
    rho_true = true_i$correlation,
    rho_hat = result_i$rho_hat,
    se = result_i$se,
    ci_lower = result_i$ci_lower,
    ci_upper = result_i$ci_upper,
    width = result_i$ci_upper - result_i$ci_lower,
    p_X_min = true_i$p_X_range[1],
    p_X_max = true_i$p_X_range[2]
  )
}

lambda_df <- bind_rows(lambda_results)

cat("\n--- Effect of Lambda ---\n")
print(lambda_df[, c("lambda", "rho_true", "rho_hat", "se", "width", "p_X_min", "p_X_max")],
      row.names = FALSE, digits = 3)

# Plot: True vs Estimated
p3 <- ggplot(lambda_df, aes(x = lambda)) +
  geom_line(aes(y = rho_true, color = "True"), linewidth = 1) +
  geom_line(aes(y = rho_hat, color = "Estimated"), linewidth = 1) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.2) +
  geom_point(aes(y = rho_true, color = "True"), size = 3) +
  geom_point(aes(y = rho_hat, color = "Estimated"), size = 3) +
  scale_color_manual(values = c("True" = "blue", "Estimated" = "red")) +
  labs(
    title = "Effect of TV Ball Radius on Correlation",
    subtitle = "Discrete X DGP: Binary X with varying P(X=1)",
    x = expression(lambda ~ "(TV ball radius)"),
    y = "Correlation",
    color = NULL
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

print(p3)

# Plot: CI width
p4 <- ggplot(lambda_df, aes(x = lambda, y = width)) +
  geom_line(linewidth = 1, color = "steelblue") +
  geom_point(size = 3, color = "steelblue") +
  labs(
    title = "CI Width vs. Lambda",
    subtitle = "Larger uncertainty ball → wider confidence intervals",
    x = expression(lambda ~ "(TV ball radius)"),
    y = "95% CI Width"
  ) +
  theme_minimal()

print(p4)

# =============================================================================
# Validation 5: Compare Analytical vs Empirical Effects
# =============================================================================

message("\n\n=== Validation 5: Analytical vs Empirical Effects ===\n")

p_X_test <- seq(0.2, 0.8, by = 0.1)
analytical_vs_empirical <- vector("list", length(p_X_test))

for (i in seq_along(p_X_test)) {
  p_X_i <- p_X_test[i]

  # Analytical
  analytical_i <- compute_analytical_effects(p_X_i)

  # Empirical
  data_i <- generate_dgp_discrete_x(n = 50000, p_X = p_X_i)
  empirical_Delta_S <- mean(data_i$S[data_i$A == 1]) - mean(data_i$S[data_i$A == 0])
  empirical_Delta_Y <- mean(data_i$Y[data_i$A == 1]) - mean(data_i$Y[data_i$A == 0])

  analytical_vs_empirical[[i]] <- data.frame(
    p_X = p_X_i,
    Delta_S_analytical = analytical_i["Delta_S"],
    Delta_S_empirical = empirical_Delta_S,
    Delta_Y_analytical = analytical_i["Delta_Y"],
    Delta_Y_empirical = empirical_Delta_Y
  )
}

comparison_df <- bind_rows(analytical_vs_empirical)

cat("\n--- Analytical vs Empirical ---\n")
print(comparison_df, row.names = FALSE, digits = 3)

# Plot
p5 <- ggplot(comparison_df, aes(x = p_X)) +
  geom_line(aes(y = Delta_S_analytical, color = "ΔS Analytical"), linewidth = 1) +
  geom_point(aes(y = Delta_S_empirical, color = "ΔS Empirical"), size = 2) +
  geom_line(aes(y = Delta_Y_analytical, color = "ΔY Analytical"), linewidth = 1) +
  geom_point(aes(y = Delta_Y_empirical, color = "ΔY Empirical"), size = 2) +
  scale_color_manual(
    values = c(
      "ΔS Analytical" = "blue",
      "ΔS Empirical" = "lightblue",
      "ΔY Analytical" = "red",
      "ΔY Empirical" = "pink"
    )
  ) +
  labs(
    title = "Analytical vs Empirical Treatment Effects",
    subtitle = "Validation that DGP matches theoretical formulas",
    x = "P(X = 1)",
    y = "Treatment Effect",
    color = NULL
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

print(p5)

# =============================================================================
# Summary
# =============================================================================

message("\n\n=== Validation Summary ===\n")

cat("1. Single Estimate:\n")
cat(sprintf("   - True correlation: %.4f\n", true_result$correlation))
cat(sprintf("   - Estimated:        %.4f [%.4f, %.4f]\n",
            result_IF$rho_hat, result_IF$ci_lower, result_IF$ci_upper))
cat(sprintf("   - Contains truth:   %s\n",
            ifelse(result_IF$ci_lower <= true_result$correlation &&
                   true_result$correlation <= result_IF$ci_upper, "YES", "NO")))

cat("\n2. Coverage:\n")
cat(sprintf("   - Coverage rate:    %.1f%% (target: 95%%)\n",
            coverage_rate * 100))
cat(sprintf("   - SE calibration:   %.2f (should be ≈1)\n",
            sd(coverage_df$rho_hat) / mean(coverage_df$se)))

cat("\n3. DGP Properties:\n")
cat(sprintf("   - PTE:              %.3f (target: ≈0.7)\n", validation$pte))
cat(sprintf("   - Correlation:      %.3f (target: ≈0)\n", validation$correlation))

cat("\n4. Key Findings:\n")
if (coverage_rate >= 0.90 && coverage_rate <= 1.0) {
  cat("   ✓ Coverage is acceptable\n")
} else {
  cat("   ✗ Coverage is off (investigate SE estimation or sampler)\n")
}

if (abs(sd(coverage_df$rho_hat) / mean(coverage_df$se) - 1) < 0.2) {
  cat("   ✓ Standard errors are well-calibrated\n")
} else {
  cat("   ✗ Standard errors need adjustment\n")
}

if (validation$checks$pte_high && validation$checks$correlation_low) {
  cat("   ✓ DGP has desired properties (high PTE, low correlation)\n")
} else {
  cat("   ✗ DGP needs recalibration (run explorations/calibrate_discrete_x_dgp.R)\n")
}

message("\n=== Validation Complete ===\n")
