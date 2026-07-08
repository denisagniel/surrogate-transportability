# Validation Script: TV Ball Correlation with IF-Based Inference
#
# Demonstrates the new tv_ball_correlation_IF() function and validates
# its properties through simulation.

library(surrogateTransportability)
library(ggplot2)
library(dplyr)

set.seed(2026)

# =============================================================================
# Example 1: Simple RCT with Positive Correlation
# =============================================================================

message("\n=== Example 1: Simple RCT ===\n")

# Generate RCT data where S and Y are correlated
n <- 500
X <- rnorm(n)
A <- rbinom(n, 1, 0.5)

# Treatment effects vary with X, creating correlation
# S responds moderately to treatment
# Y responds strongly to treatment
# Both respond to X similarly → positive correlation
S <- A * (0.3 + 0.2 * X) + rnorm(n, sd = 0.5)
Y <- A * (0.4 + 0.25 * X) + rnorm(n, sd = 0.6)

data <- data.frame(X = X, A = A, S = S, Y = Y)

# Estimate correlation with IF-based inference
result <- tv_ball_correlation_IF(
  data = data,
  lambda = 0.3,
  M = 500,
  burn_in = 1000,
  thin = 10,
  alpha = 0.05,
  verbose = TRUE
)

# Display results
cat("\n--- Results ---\n")
cat(sprintf("Correlation: %.4f (SE = %.4f)\n", result$rho_hat, result$se))
cat(sprintf("95%% CI: [%.4f, %.4f]\n", result$ci_lower, result$ci_upper))
cat(sprintf("Width: %.4f\n", result$ci_upper - result$ci_lower))

# Diagnostic plot: Treatment effects across future studies
plot_data <- data.frame(
  Delta_S = result$Delta_S,
  Delta_Y = result$Delta_Y
)

p1 <- ggplot(plot_data, aes(x = Delta_S, y = Delta_Y)) +
  geom_point(alpha = 0.6, size = 2) +
  geom_smooth(method = "lm", se = FALSE, color = "red", linetype = "dashed") +
  labs(
    title = sprintf("Treatment Effects Across %d Future Studies", result$M),
    subtitle = sprintf("Correlation: %.3f [%.3f, %.3f]",
                       result$rho_hat, result$ci_lower, result$ci_upper),
    x = expression(Delta[S] * "(Q)"),
    y = expression(Delta[Y] * "(Q)")
  ) +
  theme_minimal()

print(p1)

# Diagnostic plot: Influence function distribution
plot_if <- data.frame(
  IF = result$IF_vals
)

p2 <- ggplot(plot_if, aes(x = IF)) +
  geom_histogram(bins = 40, fill = "steelblue", alpha = 0.7) +
  geom_vline(xintercept = 0, color = "red", linetype = "dashed", linewidth = 1) +
  labs(
    title = "Influence Function Distribution",
    subtitle = sprintf("Mean: %.2e, SD: %.4f", mean(result$IF_vals), sd(result$IF_vals)),
    x = expression(psi[Theta] * "(O"[i] * ")"),
    y = "Count"
  ) +
  theme_minimal()

print(p2)


# =============================================================================
# Example 2: Coverage Simulation (Small Scale)
# =============================================================================

message("\n\n=== Example 2: Coverage Simulation ===\n")
message("Running 50 replications to assess coverage...\n")

# Simulate data generation process
generate_rct_data <- function(n, rho_true = 0.6) {
  # Generate X
  X <- rnorm(n)
  A <- rbinom(n, 1, 0.5)

  # Generate correlated effects via latent common factor
  # S and Y both respond to a common latent factor Z
  Z <- rnorm(n)

  # S: moderate treatment effect + common factor
  S <- A * (0.3 + 0.2 * X + 0.3 * Z) + rnorm(n, sd = 0.4)

  # Y: stronger treatment effect + common factor
  Y <- A * (0.4 + 0.25 * X + 0.35 * Z) + rnorm(n, sd = 0.5)

  data.frame(X = X, A = A, S = S, Y = Y)
}

# Run replications
n_reps <- 50
coverage_results <- vector("list", n_reps)

for (rep in seq_len(n_reps)) {
  if (rep %% 10 == 0) message(sprintf("  Replication %d/%d", rep, n_reps))

  # Generate data
  data_rep <- generate_rct_data(n = 300)

  # Estimate
  result_rep <- tv_ball_correlation_IF(
    data = data_rep,
    lambda = 0.3,
    M = 200,  # Smaller M for faster simulation
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

# Assess coverage (assuming true rho ≈ 0.6 based on data generation)
# Note: exact true value depends on DGP parameters
rho_true_approx <- 0.6
coverage_df$covers <- (coverage_df$ci_lower <= rho_true_approx) &
                      (coverage_df$ci_upper >= rho_true_approx)

coverage_rate <- mean(coverage_df$covers)
mean_width <- mean(coverage_df$ci_upper - coverage_df$ci_lower)

cat("\n--- Coverage Results ---\n")
cat(sprintf("True correlation (approx): %.2f\n", rho_true_approx))
cat(sprintf("Mean estimate: %.3f (SD: %.3f)\n",
            mean(coverage_df$rho_hat), sd(coverage_df$rho_hat)))
cat(sprintf("Mean SE: %.3f\n", mean(coverage_df$se)))
cat(sprintf("Coverage rate: %.1f%% (target: 95%%)\n", coverage_rate * 100))
cat(sprintf("Mean CI width: %.3f\n", mean_width))

# Plot coverage
p3 <- ggplot(coverage_df, aes(x = rep, y = rho_hat)) +
  geom_point(aes(color = covers), size = 2) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper, color = covers),
                width = 0.2, alpha = 0.5) +
  geom_hline(yintercept = rho_true_approx, color = "red",
             linetype = "dashed", linewidth = 1) +
  scale_color_manual(
    values = c("TRUE" = "steelblue", "FALSE" = "red"),
    labels = c("TRUE" = "Covers", "FALSE" = "Misses")
  ) +
  labs(
    title = sprintf("Coverage Simulation (%d replications)", n_reps),
    subtitle = sprintf("Coverage: %.0f%% | Mean width: %.3f",
                       coverage_rate * 100, mean_width),
    x = "Replication",
    y = expression(hat(rho)),
    color = "CI Status"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

print(p3)


# =============================================================================
# Example 3: Comparison of Lambda Values
# =============================================================================

message("\n\n=== Example 3: Effect of Lambda ===\n")

# Generate one dataset
data_lambda <- generate_rct_data(n = 400)

lambda_values <- c(0.1, 0.2, 0.3, 0.4, 0.5)
lambda_results <- vector("list", length(lambda_values))

for (i in seq_along(lambda_values)) {
  lambda_i <- lambda_values[i]
  message(sprintf("Testing lambda = %.1f", lambda_i))

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
    rho_hat = result_i$rho_hat,
    se = result_i$se,
    ci_lower = result_i$ci_lower,
    ci_upper = result_i$ci_upper,
    width = result_i$ci_upper - result_i$ci_lower
  )
}

lambda_df <- bind_rows(lambda_results)

cat("\n--- Effect of Lambda ---\n")
print(lambda_df, row.names = FALSE)

# Plot
p4 <- ggplot(lambda_df, aes(x = lambda, y = rho_hat)) +
  geom_line(linewidth = 1) +
  geom_point(size = 3) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.02) +
  labs(
    title = "Effect of TV Ball Radius on Correlation Estimate",
    x = expression(lambda ~ "(TV ball radius)"),
    y = expression(hat(rho) ~ "± 95% CI")
  ) +
  theme_minimal()

print(p4)

p5 <- ggplot(lambda_df, aes(x = lambda, y = width)) +
  geom_line(linewidth = 1, color = "steelblue") +
  geom_point(size = 3, color = "steelblue") +
  labs(
    title = "CI Width vs. Lambda",
    subtitle = "Larger uncertainty ball → wider confidence intervals",
    x = expression(lambda ~ "(TV ball radius)"),
    y = "95% CI Width"
  ) +
  theme_minimal()

print(p5)

message("\n=== Validation Complete ===\n")
