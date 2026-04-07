#!/usr/bin/env Rscript

#' Aggregate Results from TV Ball Coverage Cluster Simulations
#'
#' Combines all job output files into single dataset and generates summary

library(dplyr)
library(tibble)
library(ggplot2)
library(purrr)

cat("================================================================\n")
cat("AGGREGATING TV BALL COVERAGE RESULTS\n")
cat("================================================================\n\n")

# Find all result files
results_dir <- "sims/cluster/results"
result_files <- list.files(results_dir, pattern = "^job_\\d+\\.rds$", full.names = TRUE)

cat(sprintf("Found %d result files\n", length(result_files)))

if (length(result_files) == 0) {
  stop("No result files found in ", results_dir)
}

# Read parameter grid to check completeness
params_grid <- readRDS("sims/cluster/29_tv_coverage_params.rds")
expected_jobs <- nrow(params_grid)
cat(sprintf("Expected %d jobs based on parameter grid\n\n", expected_jobs))

if (length(result_files) < expected_jobs) {
  missing_jobs <- expected_jobs - length(result_files)
  cat(sprintf("WARNING: %d jobs appear to be missing\n", missing_jobs))
  cat("Proceeding with available results...\n\n")
}

# Read and combine all results
cat("Reading result files...\n")
results_list <- map(result_files, readRDS, .progress = TRUE)
results_df <- bind_rows(results_list)

cat(sprintf("\nTotal rows: %s\n", format(nrow(results_df), big.mark = ",")))
cat(sprintf("Jobs represented: %d\n", length(unique(results_df$job_id))))
cat(sprintf("Replications per job: %d\n", nrow(results_df) / length(unique(results_df$job_id))))

# Save combined results
combined_file <- "sims/results/29_tv_ball_coverage_CLUSTER_results.rds"
saveRDS(results_df, combined_file)
cat(sprintf("\nCombined results saved to: %s\n", combined_file))

# Generate summary statistics
cat("\n================================================================\n")
cat("SUMMARY STATISTICS\n")
cat("================================================================\n\n")

summary_stats <- results_df %>%
  group_by(n_baseline, lambda, M, functional) %>%
  summarise(
    n_reps = n(),
    mean_min_phi = mean(min_phi, na.rm = TRUE),
    sd_min_phi = sd(min_phi, na.rm = TRUE),
    mean_gap = mean(gap, na.rm = TRUE),
    sd_gap = sd(gap, na.rm = TRUE),
    mean_reachability = mean(reachability, na.rm = TRUE),
    sd_reachability = sd(reachability, na.rm = TRUE),
    se_reachability = sd(reachability, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )

# Save summary
summary_file <- "sims/results/29_tv_ball_coverage_CLUSTER_summary.rds"
saveRDS(summary_stats, summary_file)
cat(sprintf("Summary statistics saved to: %s\n\n", summary_file))

# Print key findings
cat("Summary by λ and M (averaged over functionals and sample sizes):\n\n")
summary_by_lambda_M <- summary_stats %>%
  group_by(lambda, M) %>%
  summarise(
    mean_reachability = mean(mean_reachability),
    se = sqrt(sum(se_reachability^2)) / n(),
    .groups = "drop"
  ) %>%
  arrange(lambda, M)

print(summary_by_lambda_M, n = 100)

cat("\n================================================================\n")
cat("GENERATING PLOTS\n")
cat("================================================================\n\n")

# Plot 1: Reachability vs M, faceted by λ and n_baseline
p1 <- ggplot(summary_stats, aes(x = M, y = mean_reachability, color = functional)) +
  geom_line(size = 0.8) +
  geom_point(size = 1.5) +
  geom_errorbar(aes(ymin = mean_reachability - 2*se_reachability,
                    ymax = mean_reachability + 2*se_reachability),
                width = 0.1, alpha = 0.5) +
  facet_grid(n_baseline ~ lambda,
             labeller = labeller(
               lambda = ~ paste0("λ = ", .),
               n_baseline = ~ paste0("N = ", .)
             )) +
  scale_x_log10(breaks = c(50, 100, 250, 500, 1000, 2500, 5000)) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  labs(
    title = "Dense Coverage: Reachability Increases with M",
    subtitle = "Error bars: ±2 SE (95% CI approx.)",
    x = "Number of Innovation Samples (M, log scale)",
    y = "Mean Reachability (% test points reached)",
    color = "Functional"
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    strip.text = element_text(size = 9)
  )

ggsave("sims/results/29_cluster_reachability_grid.pdf", p1, width = 12, height = 10)
cat("Saved: sims/results/29_cluster_reachability_grid.pdf\n")

# Plot 2: Convergence gap vs M
p2 <- ggplot(summary_stats, aes(x = M, y = mean_gap, color = functional)) +
  geom_line(size = 0.8) +
  geom_point(size = 1.5) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  facet_grid(n_baseline ~ lambda,
             labeller = labeller(
               lambda = ~ paste0("λ = ", .),
               n_baseline = ~ paste0("N = ", .)
             )) +
  scale_x_log10(breaks = c(50, 100, 250, 500, 1000, 2500, 5000)) +
  labs(
    title = "Convergence to Infimum: Gap Decreases with M",
    subtitle = "Gap = min φ(Q_m) - empirical inf φ(Q) over test points",
    x = "Number of Innovation Samples (M, log scale)",
    y = "Mean Gap to Infimum",
    color = "Functional"
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    strip.text = element_text(size = 9)
  )

ggsave("sims/results/29_cluster_convergence_grid.pdf", p2, width = 12, height = 10)
cat("Saved: sims/results/29_cluster_convergence_grid.pdf\n")

# Plot 3: Reachability vs M for λ=0.3 only (cleaner view)
p3 <- ggplot(summary_stats %>% filter(lambda == 0.3),
             aes(x = M, y = mean_reachability, color = functional, linetype = factor(n_baseline))) +
  geom_line(size = 1) +
  geom_point(size = 2) +
  scale_x_log10(breaks = c(50, 100, 250, 500, 1000, 2500, 5000)) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  scale_linetype_manual(values = c("solid", "dashed", "dotted", "dotdash", "longdash")) +
  labs(
    title = "Dense Coverage at Moderate Perturbation (λ = 0.3)",
    x = "Number of Innovation Samples (M, log scale)",
    y = "Mean Reachability",
    color = "Functional",
    linetype = "Sample Size"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave("sims/results/29_cluster_reachability_lambda03.pdf", p3, width = 10, height = 6)
cat("Saved: sims/results/29_cluster_reachability_lambda03.pdf\n")

# Plot 4: Effect of sample size on reachability at M=1000
p4 <- ggplot(summary_stats %>% filter(M == 1000),
             aes(x = n_baseline, y = mean_reachability, color = functional)) +
  geom_line(size = 1) +
  geom_point(size = 2) +
  facet_wrap(~ lambda, labeller = labeller(lambda = ~ paste0("λ = ", .))) +
  scale_x_log10(breaks = c(50, 100, 250, 500, 1000)) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  labs(
    title = "Effect of Baseline Sample Size on Coverage (M = 1000)",
    x = "Baseline Study Sample Size (log scale)",
    y = "Mean Reachability",
    color = "Functional"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave("sims/results/29_cluster_sample_size_effect.pdf", p4, width = 10, height = 4)
cat("Saved: sims/results/29_cluster_sample_size_effect.pdf\n")

cat("\n================================================================\n")
cat("AGGREGATION COMPLETE\n")
cat("================================================================\n\n")

cat("Files created:\n")
cat("  - Combined results: sims/results/29_tv_ball_coverage_CLUSTER_results.rds\n")
cat("  - Summary stats: sims/results/29_tv_ball_coverage_CLUSTER_summary.rds\n")
cat("  - 4 PDF plots in sims/results/\n\n")

cat("Key findings:\n")
cat("  1. Review reachability vs M plots to assess coverage\n")
cat("  2. Check if M=5000 achieves >60% reachability for λ=0.5\n")
cat("  3. Examine convergence gaps to verify theory\n")
cat("  4. Compare across sample sizes to assess method stability\n\n")
