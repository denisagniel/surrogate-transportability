#!/usr/bin/env Rscript
#
# Generate Figure 2: Scatter Plots of (ΔS(Q), ΔY(Q)) for All DGPs
#
# For each DGP, runs one replication to get (ΔS, ΔY) pairs and creates scatter plot
# Output: inst/paper/figures/figure2_scatterplots.pdf

library(dplyr)
library(ggplot2)
library(patchwork)
library(yaml)

# Load package functions
devtools::load_all(".", quiet = TRUE)

# Define DGP data generator (matching cluster script)
generate_dgp_data <- function(n, p_X, params, X_levels) {
  X <- sample(X_levels, size = n, replace = TRUE, prob = p_X)
  A <- rbinom(n, 1, 0.5)

  S <- (params$gamma_A + params$gamma_AX * X) * A + rnorm(n, sd = params$sigma_S)
  Y <- (params$beta_A + params$beta_AX * X) * A + params$beta_S * S +
       params$beta_SX * S * X + rnorm(n, sd = params$sigma_Y)

  data.frame(X = X, A = A, S = S, Y = Y)
}

# Read DGP specifications
dgp_config <- yaml::read_yaml("cluster/config/dgp_specifications.yaml")

# Seeds for reproducibility (chosen to give good visualizations)
seeds <- c(dgp1 = 10050, dgp2 = 10100, dgp4 = 10150, dgp5 = 10200)

# Simulation parameters from config
n <- dgp_config$simulation_settings$sample_size
M_start <- dgp_config$simulation_settings$M_start
M_increment <- dgp_config$simulation_settings$M_increment
M_max <- dgp_config$simulation_settings$M_max
tolerance <- dgp_config$simulation_settings$tolerance
n_stable <- dgp_config$simulation_settings$n_stable
burn_in <- dgp_config$simulation_settings$burn_in
thin <- dgp_config$simulation_settings$thin
alpha <- dgp_config$simulation_settings$alpha
method <- dgp_config$simulation_settings$method

cat("=== Generating Scatter Plots ===\n")
cat("Sample size:", n, "\n")
cat("Method:", method, "\n\n")

# Function to generate scatter plot for one DGP
generate_dgp_scatter <- function(dgp_name, dgp_params, seed) {
  cat(sprintf("Processing %s (seed = %d)...\n", dgp_name, seed))

  # Extract parameters
  params <- dgp_params$params
  p_X <- dgp_params$p_X
  X_levels <- dgp_params$X_levels
  lambda <- dgp_params$lambda
  rho_true <- dgp_params$rho_true

  # Generate data
  set.seed(seed)
  data <- generate_dgp_data(
    n = n,
    p_X = p_X,
    params = params,
    X_levels = X_levels
  )

  # Run tv_ball_correlation_IF_adaptive
  result <- tv_ball_correlation_IF_adaptive(
    data = data,
    lambda = lambda,
    M_start = M_start,
    M_increment = M_increment,
    M_max = M_max,
    tolerance = tolerance,
    n_stable = n_stable,
    burn_in = burn_in,
    thin = thin,
    alpha = alpha,
    method = method,
    verbose = FALSE
  )

  # Extract (ΔS, ΔY) pairs
  scatter_data <- tibble(
    delta_S = result$Delta_S,
    delta_Y = result$Delta_Y
  )

  # Create scatter plot
  dgp_label <- gsub("dgp", "DGP ", dgp_name)

  p <- ggplot(scatter_data, aes(x = delta_S, y = delta_Y)) +
    geom_point(alpha = 0.4, size = 1.5, color = "steelblue") +
    geom_smooth(method = "lm", se = FALSE, color = "red", linewidth = 0.8) +
    annotate("text",
             x = min(scatter_data$delta_S) + 0.1 * diff(range(scatter_data$delta_S)),
             y = max(scatter_data$delta_Y) - 0.05 * diff(range(scatter_data$delta_Y)),
             label = sprintf("hat(rho) == %.3f", result$rho_hat),
             parse = TRUE,
             hjust = 0,
             size = 4,
             family = "serif") +
    labs(
      title = dgp_label,
      x = expression(Delta[S](Q)),
      y = expression(Delta[Y](Q))
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", family = "serif", size = 12),
      axis.title = element_text(family = "serif", size = 11),
      axis.text = element_text(family = "serif", size = 9),
      panel.grid.minor = element_blank(),
      panel.background = element_rect(fill = "white", color = NA),
      plot.background = element_rect(fill = "white", color = NA),
      panel.border = element_rect(fill = NA, color = "gray60")
    )

  cat(sprintf("  ρ̂ = %.4f, M = %d, converged = %s\n",
              result$rho_hat, result$M_final, result$converged))

  return(list(plot = p, data = scatter_data, result = result))
}

# Generate scatter plots for all DGPs
dgp_names <- c("dgp1", "dgp2", "dgp4", "dgp5")
plots <- list()
scatter_data_all <- list()

for (dgp_name in dgp_names) {
  result <- generate_dgp_scatter(
    dgp_name = dgp_name,
    dgp_params = dgp_config$dgps[[dgp_name]],
    seed = seeds[dgp_name]
  )
  plots[[dgp_name]] <- result$plot
  scatter_data_all[[dgp_name]] <- result$data
}

# Combine into 2×2 grid
combined_plot <- wrap_plots(plots, ncol = 2, nrow = 2)

# Add overall title
combined_plot <- combined_plot +
  plot_annotation(
    title = "Treatment Effect Pairs Across Future Studies",
    subtitle = expression(paste(
      "Each point represents one future study Q from the TV ball. ",
      "Red line shows linear regression fit. ",
      hat(rho), " is the estimated correlation."
    )),
    theme = theme(
      plot.title = element_text(hjust = 0.5, face = "bold", family = "serif", size = 14),
      plot.subtitle = element_text(hjust = 0.5, family = "serif", size = 11),
      plot.background = element_rect(fill = "white", color = NA)
    )
  )

# Save to file
output_file <- "inst/paper/figures/figure2_scatterplots.pdf"
ggsave(output_file,
       plot = combined_plot,
       width = 10,
       height = 9,
       units = "in",
       device = cairo_pdf)

cat("\nFigure 2 written to:", output_file, "\n")

# Save scatter data for potential reuse
saveRDS(scatter_data_all, "inst/paper/figures/figure2_data.rds")
cat("Scatter plot data saved to: inst/paper/figures/figure2_data.rds\n")
