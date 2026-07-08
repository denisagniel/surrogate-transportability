#!/usr/bin/env Rscript
#
# Generate Figure 1: Histograms of θ̂ with N(θ, σ²/n) Overlay
#
# Creates 4-panel figure showing distribution of correlation estimates
# with overlaid normal density to validate asymptotic normality
# Output: inst/paper/figures/figure1_histograms.pdf

library(ggplot2)
library(dplyr)
library(patchwork)

# Read simulation results
results <- readRDS("cluster/results/combined_results.rds")

# Extract sample size from config
n <- results$dgp1$dgp_config$n  # Should be 10000

# Prepare data for all DGPs
plot_data <- bind_rows(
  lapply(names(results), function(dgp_name) {
    dgp <- results[[dgp_name]]
    dgp_id <- gsub("dgp", "DGP ", dgp_name)

    # Extract values first to avoid lazy evaluation issues
    rho_hat_vals <- dgp$data$rho_hat
    rho_true_val <- dgp$summary$rho_true
    emp_se_val <- dgp$summary$empirical_sd_rho

    tibble(
      dgp = dgp_id,
      rho_hat = rho_hat_vals,
      rho_true = rho_true_val,
      emp_se = emp_se_val
    )
  })
)

# Create histograms with normal overlay
plots <- lapply(unique(plot_data$dgp), function(dgp_id) {
  dat <- plot_data %>% filter(dgp == dgp_id)

  # Get parameters for this DGP
  rho_true <- unique(dat$rho_true)
  emp_se <- unique(dat$emp_se)

  # Create sequence for normal density overlay
  x_seq <- seq(min(dat$rho_hat), max(dat$rho_hat), length.out = 200)
  normal_density <- dnorm(x_seq, mean = rho_true, sd = emp_se)

  # Get histogram for density scaling
  h <- hist(dat$rho_hat, breaks = 30, plot = FALSE)
  density_scale <- max(h$density)

  p <- ggplot(dat, aes(x = rho_hat)) +
    geom_histogram(aes(y = after_stat(density)),
                   bins = 30,
                   fill = "lightblue",
                   color = "black",
                   alpha = 0.7) +
    geom_line(data = data.frame(x = x_seq, y = normal_density),
              aes(x = x, y = y),
              color = "red",
              linewidth = 1) +
    geom_vline(xintercept = rho_true,
               linetype = "dashed",
               color = "darkred",
               linewidth = 0.8) +
    labs(
      title = dgp_id,
      x = expression(hat(rho)),
      y = "Density"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", family = "serif"),
      axis.title = element_text(family = "serif"),
      axis.text = element_text(family = "serif"),
      panel.grid.minor = element_blank(),
      panel.background = element_rect(fill = "white", color = NA),
      plot.background = element_rect(fill = "white", color = NA)
    )

  return(p)
})

# Combine into 2×2 grid
combined_plot <- wrap_plots(plots, ncol = 2, nrow = 2)

# Add overall title
combined_plot <- combined_plot +
  plot_annotation(
    title = "Distribution of Correlation Estimates Across 1000 Replications",
    subtitle = expression(paste(
      "Histograms with overlaid ", N(rho[true], sigma^2/n), " density (red line). ",
      "Dashed line shows true ", rho, "."
    )),
    theme = theme(
      plot.title = element_text(hjust = 0.5, face = "bold", family = "serif", size = 14),
      plot.subtitle = element_text(hjust = 0.5, family = "serif", size = 11),
      plot.background = element_rect(fill = "white", color = NA)
    )
  )

# Save to file using standard pdf device (cairo requires X11 which may not be available)
output_file <- "inst/paper/figures/figure1_histograms.pdf"
pdf(output_file, width = 10, height = 8)
print(combined_plot)
dev.off()

cat("Figure 1 written to:", output_file, "\n")

# Print summary statistics for verification
cat("\n=== Distribution Summary ===\n")
summary_stats <- plot_data %>%
  group_by(dgp) %>%
  summarise(
    rho_true = first(rho_true),
    mean_rho_hat = mean(rho_hat),
    sd_rho_hat = sd(rho_hat),
    emp_se = first(emp_se)
  )
print(summary_stats)
