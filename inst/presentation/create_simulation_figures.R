# Create Simulation Figures for Presentation
# Purpose: Generate scatter plots for DGP 4 and DGP 5 showing (ΔS, ΔY) relationships

library(surrogateTransportability)
library(ggplot2)
library(yaml)

# Load DGP specifications
dgp_specs <- yaml::read_yaml("../../cluster/config/dgp_specifications.yaml")

# Color scheme matching slides (from custom.scss)
BACKGROUND_COLOR <- "#01364C"  # Dark blue background
TEXT_COLOR <- "#F7F8F9"        # Light gray text
ACCENT_COLOR <- "#FFD700"      # Yellow accent
GRID_COLOR <- "#0A5A7F"        # Lighter blue for grid

# DGP data generation function (matches cluster scripts)
generate_dgp_data <- function(n, p_X, params, X_levels) {
  X <- sample(X_levels, size = n, replace = TRUE, prob = p_X)
  A <- rbinom(n, 1, 0.5)

  S <- (params$gamma_A + params$gamma_AX * X) * A + rnorm(n, sd = params$sigma_S)
  Y <- (params$beta_A + params$beta_AX * X) * A + params$beta_S * S +
       params$beta_SX * S * X + rnorm(n, sd = params$sigma_Y)

  data.frame(X = X, A = A, S = S, Y = Y)
}

# Function to run one replication and extract (ΔS, ΔY) pairs
run_dgp_for_scatter <- function(dgp_name, seed = 12345) {
  cat("\nRunning", dgp_name, "to generate scatter data...\n")

  spec <- dgp_specs$dgps[[dgp_name]]
  params <- spec$params
  p_X <- spec$p_X
  X_levels <- spec$X_levels
  lambda <- spec$lambda
  n <- dgp_specs$simulation_settings$sample_size

  set.seed(seed)

  # Generate data using the DGP function
  data <- generate_dgp_data(
    n = n,
    p_X = p_X,
    params = params,
    X_levels = X_levels
  )

  # Run the method
  result <- tv_ball_correlation_IF_adaptive(
    data = data,
    lambda = lambda,
    M_start = 300,
    M_increment = 300,
    M_max = 3000,
    tolerance = 0.01,
    n_stable = 3,
    burn_in = 500,
    thin = 5,
    alpha = 0.05
  )

  # Extract (ΔS, ΔY) pairs from sampled studies
  Delta_S <- result$Delta_S
  Delta_Y <- result$Delta_Y

  # Compute correlation for annotation
  rho_obs <- cor(Delta_S, Delta_Y)

  list(
    Delta_S = Delta_S,
    Delta_Y = Delta_Y,
    rho_obs = rho_obs,
    M = length(Delta_S)
  )
}

# Create scatter plot
create_scatter_plot <- function(dgp_data, dgp_name, spec, output_file) {
  Delta_S <- dgp_data$Delta_S
  Delta_Y <- dgp_data$Delta_Y
  rho_obs <- dgp_data$rho_obs

  # Create data frame
  plot_data <- data.frame(
    Delta_S = Delta_S,
    Delta_Y = Delta_Y
  )

  # Create title and annotation based on DGP
  if (dgp_name == "dgp4") {
    title_text <- "Perfect Correlation Despite Low PTE"
    pte_text <- sprintf("PTE = %.0f%%", 100*spec$PTE_P0)
    annotation_text <- sprintf("ρ = %.3f\n%s", rho_obs, pte_text)
  } else if (dgp_name == "dgp5") {
    title_text <- "Correlation Well-Defined Despite PTE = NaN"
    annotation_text <- sprintf("ρ = %.3f\nPTE = NaN", rho_obs)
  }

  # Compute position for annotation (upper left)
  x_range <- range(Delta_S)
  y_range <- range(Delta_Y)
  annot_x <- x_range[1] + 0.05 * diff(x_range)
  annot_y <- y_range[2] - 0.05 * diff(y_range)

  # Create plot
  p <- ggplot(plot_data, aes(x = Delta_S, y = Delta_Y)) +
    geom_point(color = TEXT_COLOR, alpha = 0.6, size = 2) +
    geom_smooth(method = "lm", se = FALSE, color = ACCENT_COLOR, linewidth = 1.5) +
    labs(
      x = "ΔS(Q)",
      y = "ΔY(Q)",
      title = title_text
    ) +
    annotate(
      "text",
      x = annot_x,
      y = annot_y,
      label = annotation_text,
      color = ACCENT_COLOR,
      size = 6,
      hjust = 0,
      vjust = 1,
      fontface = "bold"
    ) +
    theme_minimal() +
    theme(
      plot.background = element_rect(fill = BACKGROUND_COLOR, color = NA),
      panel.background = element_rect(fill = BACKGROUND_COLOR, color = NA),
      text = element_text(color = TEXT_COLOR, size = 14, family = "sans"),
      axis.text = element_text(color = TEXT_COLOR, size = 12),
      axis.title = element_text(size = 14, face = "bold"),
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      panel.grid.major = element_line(color = GRID_COLOR, linewidth = 0.3),
      panel.grid.minor = element_line(color = GRID_COLOR, linewidth = 0.15)
    )

  # Save figure
  ggsave(
    output_file,
    plot = p,
    width = 8,
    height = 6,
    dpi = 300,
    bg = BACKGROUND_COLOR
  )

  cat("  Saved:", output_file, "\n")
}

# Main execution
cat("\n", strrep("=", 70), "\n")
cat("GENERATING SIMULATION FIGURES\n")
cat(strrep("=", 70), "\n")

# Create figures directory if it doesn't exist
if (!dir.exists("figures")) {
  dir.create("figures")
}

# Generate DGP 4 figure
dgp4_data <- run_dgp_for_scatter("dgp4", seed = 12345)
create_scatter_plot(
  dgp4_data,
  "dgp4",
  dgp_specs$dgps$dgp4,
  "figures/slide23_dgp4_perfect_correlation.png"
)

# Generate DGP 5 figure
dgp5_data <- run_dgp_for_scatter("dgp5", seed = 12346)
create_scatter_plot(
  dgp5_data,
  "dgp5",
  dgp_specs$dgps$dgp5,
  "figures/slide24_dgp5_pte_undefined.png"
)

cat("\n", strrep("=", 70), "\n")
cat("FIGURES COMPLETE\n")
cat(strrep("=", 70), "\n\n")
