#!/usr/bin/env Rscript
# Analyze and visualize Wasserstein minimax simulation study results

library(tidyverse)
library(gridExtra)

# Load results
results <- readRDS("sims/results/wasserstein_minimax_simulation_study.rds")

# ==============================================================================
# STUDY 1: Coverage by Sample Size
# ==============================================================================

cat("========================================\n")
cat("STUDY 1: Coverage by Sample Size\n")
cat("========================================\n\n")

study1 <- results$coverage_by_n
print(study1, digits = 4)

p1 <- ggplot(study1, aes(x = n, y = coverage)) +
  geom_line(size = 1) +
  geom_point(size = 3) +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "red") +
  geom_ribbon(aes(ymin = 0.95 - 1.96*sqrt(0.95*0.05/n_valid),
                   ymax = 0.95 + 1.96*sqrt(0.95*0.05/n_valid)),
              alpha = 0.2) +
  scale_y_continuous(limits = c(0.85, 1.0), labels = scales::percent_format()) +
  labs(title = "Coverage Rate by Sample Size",
       x = "Sample Size (n)",
       y = "Coverage Rate",
       subtitle = "Target: 95% (dashed line)") +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

p2 <- ggplot(study1, aes(x = n, y = variance_ratio)) +
  geom_line(size = 1) +
  geom_point(size = 3) +
  geom_hline(yintercept = 1.0, linetype = "dashed", color = "red") +
  scale_y_continuous(limits = c(0.8, 1.3)) +
  labs(title = "Variance Ratio by Sample Size",
       x = "Sample Size (n)",
       y = "IF-based SE / Empirical SE",
       subtitle = "Target: 1.0 (dashed line)") +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

# ==============================================================================
# STUDY 2: DGP Comparison
# ==============================================================================

cat("\n========================================\n")
cat("STUDY 2: Performance Across DGPs\n")
cat("========================================\n\n")

study2 <- results$dgp_comparison
print(study2, digits = 4)

p3 <- ggplot(study2, aes(x = reorder(dgp, coverage), y = coverage)) +
  geom_col(fill = "steelblue", alpha = 0.7) +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "red") +
  scale_y_continuous(limits = c(0, 1), labels = scales::percent_format()) +
  labs(title = "Coverage Rate Across DGPs",
       x = "Data Generating Process",
       y = "Coverage Rate",
       subtitle = "Target: 95% (dashed line)") +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"),
        axis.text.x = element_text(angle = 45, hjust = 1))

p4 <- ggplot(study2, aes(x = reorder(dgp, variance_ratio), y = variance_ratio)) +
  geom_col(fill = "steelblue", alpha = 0.7) +
  geom_hline(yintercept = 1.0, linetype = "dashed", color = "red") +
  scale_y_continuous(limits = c(0, 1.5)) +
  labs(title = "Variance Ratio Across DGPs",
       x = "Data Generating Process",
       y = "IF-based SE / Empirical SE",
       subtitle = "Target: 1.0 (dashed line)") +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"),
        axis.text.x = element_text(angle = 45, hjust = 1))

# ==============================================================================
# STUDY 3: Gamma Sensitivity
# ==============================================================================

cat("\n========================================\n")
cat("STUDY 3: Sensitivity to Gamma\n")
cat("========================================\n\n")

study3 <- results$gamma_sensitivity
print(study3, digits = 4)

p5 <- ggplot(study3, aes(x = gamma, y = coverage)) +
  geom_line(size = 1) +
  geom_point(size = 3) +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "red") +
  scale_y_continuous(limits = c(0.85, 1.0), labels = scales::percent_format()) +
  labs(title = "Coverage Rate by Gamma (Wasserstein Penalty)",
       x = "Gamma",
       y = "Coverage Rate",
       subtitle = "Target: 95% (dashed line)") +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

p6 <- ggplot(study3, aes(x = gamma, y = mean_estimate)) +
  geom_line(size = 1, color = "steelblue") +
  geom_point(size = 3, color = "steelblue") +
  geom_line(aes(y = truth), linetype = "dashed", color = "red", size = 1) +
  labs(title = "Estimate vs Truth by Gamma",
       x = "Gamma",
       y = "Minimax Concordance",
       subtitle = "Truth (dashed line) varies with gamma") +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

# ==============================================================================
# STUDY 4: Tau Sensitivity
# ==============================================================================

cat("\n========================================\n")
cat("STUDY 4: Sensitivity to Tau\n")
cat("========================================\n\n")

study4 <- results$tau_sensitivity
print(study4, digits = 4)

p7 <- ggplot(study4, aes(x = tau, y = coverage)) +
  geom_line(size = 1) +
  geom_point(size = 3) +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "red") +
  scale_y_continuous(limits = c(0.85, 1.0), labels = scales::percent_format()) +
  labs(title = "Coverage Rate by Tau (Temperature)",
       x = "Tau",
       y = "Coverage Rate",
       subtitle = "Target: 95% (dashed line)") +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

p8 <- ggplot(study4, aes(x = tau, y = variance_ratio)) +
  geom_line(size = 1) +
  geom_point(size = 3) +
  geom_hline(yintercept = 1.0, linetype = "dashed", color = "red") +
  scale_y_continuous(limits = c(0.8, 1.3)) +
  labs(title = "Variance Ratio by Tau",
       x = "Tau",
       y = "IF-based SE / Empirical SE",
       subtitle = "Target: 1.0 (dashed line)") +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

# ==============================================================================
# SAVE PLOTS
# ==============================================================================

# Combined figure 1: Coverage and variance by n
pdf("sims/results/wasserstein_sim_figure1_sample_size.pdf", width = 12, height = 5)
grid.arrange(p1, p2, ncol = 2)
dev.off()

# Combined figure 2: DGP comparison
pdf("sims/results/wasserstein_sim_figure2_dgp_comparison.pdf", width = 12, height = 5)
grid.arrange(p3, p4, ncol = 2)
dev.off()

# Combined figure 3: Parameter sensitivity
pdf("sims/results/wasserstein_sim_figure3_gamma_sensitivity.pdf", width = 12, height = 5)
grid.arrange(p5, p6, ncol = 2)
dev.off()

# Combined figure 4: Tau sensitivity
pdf("sims/results/wasserstein_sim_figure4_tau_sensitivity.pdf", width = 12, height = 5)
grid.arrange(p7, p8, ncol = 2)
dev.off()

cat("\n========================================\n")
cat("SUMMARY\n")
cat("========================================\n\n")

# Overall coverage
all_coverage <- c(
  study1$coverage,
  study2$coverage,
  study3$coverage,
  study4$coverage
)
cat(sprintf("Overall coverage range: [%.1f%%, %.1f%%]\n",
            100*min(all_coverage), 100*max(all_coverage)))
cat(sprintf("Mean coverage: %.1f%%\n", 100*mean(all_coverage)))

# Variance ratios
all_var_ratios <- c(
  study1$variance_ratio,
  study2$variance_ratio,
  study3$variance_ratio,
  study4$variance_ratio
)
cat(sprintf("\nVariance ratio range: [%.3f, %.3f]\n",
            min(all_var_ratios, na.rm = TRUE),
            max(all_var_ratios, na.rm = TRUE)))
cat(sprintf("Mean variance ratio: %.3f\n", mean(all_var_ratios, na.rm = TRUE)))

cat("\nFigures saved to sims/results/\n")
