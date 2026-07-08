#!/usr/bin/env Rscript
#
# Generate Figure 3: Lambda Sensitivity Analysis
#
# For each DGP, plots ρ̂(λ) with 95% CIs across λ ∈ {0.1, 0.2, 0.3, 0.4, 0.5}
# Shows robust (flat profiles: DGPs 1, 4, 5) vs fragile (declining: DGP 2) transportability
#
# Output: inst/paper/figures/figure3_lambda_sensitivity.pdf
#
# Requirements:
# - Lambda sensitivity results in cluster/results/lambda_sensitivity/
# - Expects files: lambda_0.1_dgp1.rds, lambda_0.1_dgp2.rds, etc.

library(dplyr)
library(tidyr)
library(ggplot2)
library(patchwork)

cat("=== Generating Figure 3: Lambda Sensitivity ===\n\n")

# =============================================================================
# Load Results
# =============================================================================

results_dir <- "cluster/results/lambda_sensitivity"

if (!dir.exists(results_dir)) {
  stop("Lambda sensitivity results not found at: ", results_dir, "\n",
       "Run lambda sensitivity simulations first.")
}

# Define conditions
lambdas <- c(0.1, 0.2, 0.3, 0.4, 0.5)
dgps <- c("dgp1", "dgp2", "dgp4", "dgp5")

cat("Loading results from", results_dir, "\n")

# Load all results
all_results <- list()

for (dgp in dgps) {
  for (lambda in lambdas) {
    filename <- sprintf("lambda_%.1f_%s.rds", lambda, dgp)
    filepath <- file.path(results_dir, filename)

    if (!file.exists(filepath)) {
      warning(sprintf("Missing: %s", filename))
      next
    }

    data <- readRDS(filepath)

    # Extract results list
    results <- data$results

    # Convert to data frame
    df <- do.call(rbind, lapply(results, function(r) {
      data.frame(
        dgp_id = r$dgp_id,
        lambda = r$lambda,
        rep_number = r$rep_number,
        rho_hat = r$rho_hat,
        se = r$se,
        ci_lower = r$ci_lower,
        ci_upper = r$ci_upper,
        converged = r$converged,
        M_final = r$M_final,
        rho_true = r$rho_true,
        stringsAsFactors = FALSE
      )
    }))

    all_results[[length(all_results) + 1]] <- df
  }
}

# Combine all results
combined_data <- bind_rows(all_results)

cat(sprintf("\nLoaded %d replications total\n", nrow(combined_data)))
cat(sprintf("  Conditions: %d lambda × %d DGPs = %d\n",
            length(lambdas), length(dgps), length(lambdas) * length(dgps)))

# Verify coverage
conditions <- expand.grid(lambda = lambdas, dgp = dgps)
for (i in 1:nrow(conditions)) {
  lambda <- conditions$lambda[i]
  dgp <- conditions$dgp[i]
  n_reps <- sum(combined_data$lambda == lambda & combined_data$dgp_id == dgp)
  if (n_reps > 0) {
    cat(sprintf("  λ=%.1f, %s: %d reps\n", lambda, dgp, n_reps))
  } else {
    warning(sprintf("  λ=%.1f, %s: MISSING\n", lambda, dgp))
  }
}

# =============================================================================
# Compute Summary Statistics
# =============================================================================

cat("\nComputing summary statistics...\n")

summary_stats <- combined_data %>%
  group_by(dgp_id, lambda) %>%
  summarize(
    n_reps = n(),
    mean_rho_hat = mean(rho_hat, na.rm = TRUE),
    se_mean = sd(rho_hat, na.rm = TRUE) / sqrt(n()),
    ci_lower_mean = mean_rho_hat - 1.96 * se_mean,
    ci_upper_mean = mean_rho_hat + 1.96 * se_mean,
    rho_true = first(rho_true),
    coverage = mean(ci_lower <= rho_true & ci_upper >= rho_true, na.rm = TRUE),
    mean_M = mean(M_final),
    converged_pct = 100 * mean(converged),
    .groups = "drop"
  )

print(summary_stats)

# =============================================================================
# Create Plots
# =============================================================================

cat("\nCreating plots...\n")

# DGP labels with descriptions
dgp_labels <- c(
  "dgp1" = "DGP 1: High PTE, Moderate ρ",
  "dgp2" = "DGP 2: Moderate PTE, Negative ρ",
  "dgp4" = "DGP 4: Low PTE, Perfect ρ",
  "dgp5" = "DGP 5: Undefined PTE, Perfect ρ"
)

# Create individual plots for each DGP
plots <- list()

for (dgp in dgps) {
  dgp_data <- summary_stats %>% filter(dgp_id == dgp)

  # Get true correlation
  rho_true_val <- unique(dgp_data$rho_true)[1]

  p <- ggplot(dgp_data, aes(x = lambda, y = mean_rho_hat)) +
    geom_hline(yintercept = rho_true_val,
               linetype = "dashed", color = "gray40", linewidth = 0.5) +
    geom_line(color = "steelblue", linewidth = 1) +
    geom_point(color = "steelblue", size = 2.5) +
    geom_errorbar(aes(ymin = ci_lower_mean, ymax = ci_upper_mean),
                  width = 0.02, color = "steelblue", linewidth = 0.7) +
    annotate("text",
             x = min(dgp_data$lambda) + 0.05,
             y = rho_true_val + 0.05,
             label = sprintf("True ρ = %.2f", rho_true_val),
             hjust = 0,
             size = 3,
             family = "serif",
             color = "gray40") +
    labs(
      title = dgp_labels[dgp],
      x = expression(lambda),
      y = expression(hat(rho)(lambda))
    ) +
    scale_x_continuous(breaks = lambdas) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold",
                               family = "serif", size = 11),
      axis.title = element_text(family = "serif", size = 10),
      axis.text = element_text(family = "serif", size = 9),
      panel.grid.minor = element_blank(),
      panel.background = element_rect(fill = "white", color = NA),
      plot.background = element_rect(fill = "white", color = NA),
      panel.border = element_rect(fill = NA, color = "gray60")
    )

  # Add ylim based on DGP (different scales for negative vs positive correlations)
  if (dgp == "dgp2") {
    p <- p + ylim(-1, -0.5)
  } else {
    p <- p + ylim(0.5, 1.05)
  }

  plots[[dgp]] <- p
}

# Combine into 2×2 grid
combined_plot <- wrap_plots(plots, ncol = 2, nrow = 2)

# Add overall title
combined_plot <- combined_plot +
  plot_annotation(
    title = "Sensitivity of Correlation to TV Ball Radius λ",
    subtitle = expression(paste(
      "Each point shows ", bar(hat(rho)), " across 1000 replications with 95% CI. ",
      "Dashed line shows true ρ. ",
      "Flat profiles indicate robust transportability."
    )),
    theme = theme(
      plot.title = element_text(hjust = 0.5, face = "bold",
                               family = "serif", size = 14),
      plot.subtitle = element_text(hjust = 0.5, family = "serif", size = 10),
      plot.background = element_rect(fill = "white", color = NA)
    )
  )

# =============================================================================
# Save Figure
# =============================================================================

dir.create("inst/paper/figures", showWarnings = FALSE, recursive = TRUE)
output_file <- "inst/paper/figures/figure3_lambda_sensitivity.pdf"

ggsave(output_file,
       plot = combined_plot,
       width = 10,
       height = 9,
       units = "in",
       device = cairo_pdf)

cat("\nFigure 3 written to:", output_file, "\n")

# Save summary statistics
saveRDS(summary_stats, "inst/paper/figures/figure3_data.rds")
cat("Summary statistics saved to: inst/paper/figures/figure3_data.rds\n")

# =============================================================================
# Print Key Insights
# =============================================================================

cat("\n=== Key Insights ===\n\n")

cat("Robust transportability (flat profiles):\n")
for (dgp in c("dgp1", "dgp4", "dgp5")) {
  dgp_data <- summary_stats %>% filter(dgp_id == dgp)
  rho_range <- max(dgp_data$mean_rho_hat) - min(dgp_data$mean_rho_hat)
  cat(sprintf("  %s: range = %.3f (ρ varies by < %.3f)\n",
              dgp, rho_range, rho_range))
}

cat("\nFragile transportability (declining profile):\n")
dgp2_data <- summary_stats %>%
  filter(dgp_id == "dgp2") %>%
  arrange(lambda)

cat(sprintf("  dgp2: ρ̂(0.1) = %.3f → ρ̂(0.5) = %.3f (decline: %.3f)\n",
            dgp2_data$mean_rho_hat[1],
            dgp2_data$mean_rho_hat[nrow(dgp2_data)],
            dgp2_data$mean_rho_hat[1] - dgp2_data$mean_rho_hat[nrow(dgp2_data)]))

cat("\nInterpretation:\n")
cat("  • DGP 1: Moderate mediation remains stable across distributional shifts\n")
cat("  • DGP 2: Opposite interactions create fragility - transportability weakens\n")
cat("  • DGP 4: Perfect transportability despite low PTE - correlation robust\n")
cat("  • DGP 5: Undefined PTE but perfect, stable transportability\n")

cat("\n=== Complete ===\n")
