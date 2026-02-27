#!/usr/bin/env Rscript

#' Visualization of Simulation Results
#'
#' Creates diagnostic plots and summary visualizations of all simulation results.

library(ggplot2)
library(dplyr)
library(tibble)
library(purrr)
library(tidyr)

cat("Creating Diagnostic Visualizations\n")
cat("==================================\n\n")

# Create plots directory
if (!dir.exists("sims/results/plots/")) {
  dir.create("sims/results/plots/", recursive = TRUE)
}

# 1. Sample Size Sensitivity Visualization
cat("1. Sample size sensitivity plots...\n")

sensitivity_results <- readRDS("sims/results/sample_size_sensitivity_results.rds")

# Correlation by sample size
p1 <- ggplot(sensitivity_results, aes(x = sample_size, y = correlation_mean)) +
  geom_point(size = 3) +
  geom_line() +
  geom_errorbar(aes(ymin = correlation_q025, ymax = correlation_q975), width = 50) +
  scale_x_continuous(breaks = sensitivity_results$sample_size) +
  labs(
    title = "Correlation Functional by Sample Size",
    subtitle = "Error bars show 95% credible intervals",
    x = "Sample Size",
    y = "Correlation between ΔS and ΔY"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10),
    axis.title = element_text(size = 12)
  )

ggsave("sims/results/plots/correlation_by_sample_size.png", p1, width = 8, height = 6, dpi = 300)

# Standard error by sample size
p2 <- ggplot(sensitivity_results, aes(x = sample_size, y = correlation_sd)) +
  geom_point(size = 3) +
  geom_line() +
  geom_smooth(method = "lm", formula = y ~ I(1/sqrt(x)), se = FALSE, 
              linetype = "dashed", color = "red") +
  scale_x_continuous(breaks = sensitivity_results$sample_size) +
  labs(
    title = "Standard Error by Sample Size",
    subtitle = "Red dashed line shows theoretical 1/√n relationship",
    x = "Sample Size",
    y = "Standard Error of Correlation Functional"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10),
    axis.title = element_text(size = 12)
  )

ggsave("sims/results/plots/standard_error_by_sample_size.png", p2, width = 8, height = 6, dpi = 300)

# Runtime efficiency
p3 <- ggplot(sensitivity_results, aes(x = sample_size, y = run_time)) +
  geom_point(size = 3) +
  geom_line() +
  scale_x_continuous(breaks = sensitivity_results$sample_size) +
  labs(
    title = "Computational Time by Sample Size",
    x = "Sample Size",
    y = "Run Time (seconds)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    axis.title = element_text(size = 12)
  )

ggsave("sims/results/plots/runtime_by_sample_size.png", p3, width = 8, height = 6, dpi = 300)

cat("   Saved 3 sample size plots\n")

# 2. Method Comparison Visualization
cat("2. Method comparison plots...\n")

# Load comparison results
scenario1 <- readRDS("sims/results/scenario1_comparison.rds")
scenario2 <- readRDS("sims/results/scenario2_comparison.rds")
scenario3 <- readRDS("sims/results/scenario3_comparison.rds")

# Create comparison dataframe
comparison_data <- tibble(
  scenario = rep(c("Scenario 1:\nGood Innovation,\nPoor Traditional",
                   "Scenario 2:\nPoor Innovation,\nGood Traditional",
                   "Scenario 3:\nMixture\nStructure"), each = 2),
  method = rep(c("Innovation", "Traditional"), 3),
  correlation = c(
    scenario1$innovation_results$summary$correlation$mean,
    scenario1$traditional_results$correlation,
    scenario2$innovation_results$summary$correlation$mean,
    scenario2$traditional_results$correlation,
    scenario3$innovation_results$summary$correlation$mean,
    scenario3$traditional_results$correlation
  )
)

p4 <- ggplot(comparison_data, aes(x = scenario, y = correlation, fill = method)) +
  geom_bar(stat = "identity", position = "dodge", width = 0.7) +
  scale_fill_manual(values = c("Innovation" = "#2E86AB", "Traditional" = "#A23B72")) +
  labs(
    title = "Innovation vs Traditional Methods Across Scenarios",
    subtitle = "Comparing correlation-based surrogate quality measures",
    x = "Scenario",
    y = "Correlation",
    fill = "Method"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10),
    axis.title = element_text(size = 12),
    legend.position = "top",
    axis.text.x = element_text(size = 9)
  ) +
  ylim(0, 1)

ggsave("sims/results/plots/method_comparison.png", p4, width = 10, height = 6, dpi = 300)

cat("   Saved method comparison plot\n")

# 3. Posterior Distributions
cat("3. Posterior distribution plots...\n")

# Load continuous surrogate results for detailed posterior
continuous_results <- readRDS("sims/results/continuous_surrogate_simulation.rds")

# Extract posterior samples
if (!is.null(continuous_results$results$functionals$correlation)) {
  correlation_samples <- continuous_results$results$functionals$correlation
  
  # Posterior density plot
  p5 <- ggplot(tibble(correlation = correlation_samples), aes(x = correlation)) +
    geom_histogram(aes(y = after_stat(density)), bins = 30, 
                   fill = "#2E86AB", alpha = 0.7) +
    geom_density(color = "#A23B72", size = 1.2) +
    geom_vline(xintercept = mean(correlation_samples), 
               linetype = "dashed", color = "red", size = 1) +
    labs(
      title = "Posterior Distribution of Correlation Functional",
      subtitle = "Continuous Surrogate Scenario (Red line = posterior mean)",
      x = "Correlation between ΔS and ΔY",
      y = "Density"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 10),
      axis.title = element_text(size = 12)
    )
  
  ggsave("sims/results/plots/posterior_distribution.png", p5, width = 8, height = 6, dpi = 300)
  
  # Trace plot
  p6 <- ggplot(tibble(iteration = 1:length(correlation_samples), 
                     correlation = correlation_samples), 
              aes(x = iteration, y = correlation)) +
    geom_line(alpha = 0.6) +
    geom_smooth(se = TRUE, color = "#A23B72") +
    labs(
      title = "Trace Plot of Correlation Functional",
      subtitle = "Monitoring convergence across bootstrap iterations",
      x = "Bootstrap Iteration",
      y = "Correlation"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 10),
      axis.title = element_text(size = 12)
    )
  
  ggsave("sims/results/plots/trace_plot.png", p6, width = 8, height = 6, dpi = 300)
  
  cat("   Saved 2 posterior distribution plots\n")
}

# 4. Summary Table
cat("4. Creating summary table...\n")

summary_table <- tibble(
  Scenario = c("Binary Surrogate", "Continuous Surrogate", 
               "Scenario 1", "Scenario 2", "Scenario 3"),
  `Sample Size` = c(500, 500, 500, 500, 500),
  `Correlation Mean` = c(
    readRDS("sims/results/binary_surrogate_simulation.rds")$results$summary$correlation$mean,
    readRDS("sims/results/continuous_surrogate_simulation.rds")$results$summary$correlation$mean,
    scenario1$innovation_results$summary$correlation$mean,
    scenario2$innovation_results$summary$correlation$mean,
    scenario3$innovation_results$summary$correlation$mean
  ),
  `Correlation 95% CI` = c(
    paste0("(", 
           round(readRDS("sims/results/binary_surrogate_simulation.rds")$results$summary$correlation$q025, 3),
           ", ",
           round(readRDS("sims/results/binary_surrogate_simulation.rds")$results$summary$correlation$q975, 3),
           ")"),
    paste0("(", 
           round(readRDS("sims/results/continuous_surrogate_simulation.rds")$results$summary$correlation$q025, 3),
           ", ",
           round(readRDS("sims/results/continuous_surrogate_simulation.rds")$results$summary$correlation$q975, 3),
           ")"),
    paste0("(", 
           round(scenario1$innovation_results$summary$correlation$q025, 3),
           ", ",
           round(scenario1$innovation_results$summary$correlation$q975, 3),
           ")"),
    paste0("(", 
           round(scenario2$innovation_results$summary$correlation$q025, 3),
           ", ",
           round(scenario2$innovation_results$summary$correlation$q975, 3),
           ")"),
    paste0("(", 
           round(scenario3$innovation_results$summary$correlation$q025, 3),
           ", ",
           round(scenario3$innovation_results$summary$correlation$q975, 3),
           ")")
  )
)

# Print summary table
cat("\nSimulation Results Summary\n")
cat("=========================\n")
print(summary_table, n = Inf)

# Save summary table
saveRDS(summary_table, "sims/results/summary_table.rds")
write.csv(summary_table, "sims/results/summary_table.csv", row.names = FALSE)

cat("\n\nVisualization complete!\n")
cat("Plots saved to: sims/results/plots/\n")
cat("Summary table saved to: sims/results/summary_table.csv\n")


