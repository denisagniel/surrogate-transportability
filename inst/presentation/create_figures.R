# Create conceptual figures for presentation
# Phase 2: Essential figures

library(ggplot2)
library(dplyr)
library(tidyr)
library(patchwork)

# Set output directory
fig_dir <- "figures"
if (!dir.exists(fig_dir)) dir.create(fig_dir)

# RAND color palette
rand_darkblue <- "#01364C"
rand_blue <- "#99D9DD"
rand_yellow <- "#F4BA02"
rand_white <- "#F7F8F9"

# Common theme
theme_rand <- function() {
  theme_minimal(base_size = 14) +
    theme(
      plot.background = element_rect(fill = rand_white, color = NA),
      panel.background = element_rect(fill = rand_white, color = NA),
      text = element_text(color = rand_darkblue),
      plot.title = element_text(face = "bold", size = 16),
      axis.text = element_text(color = rand_darkblue)
    )
}

# ============================================================================
# Figure 1: Distribution of Future Studies (Slide 9)
# ============================================================================

create_future_studies_diagram <- function() {
  set.seed(123)

  # P0 in center
  p0 <- data.frame(x = 0, y = 0, label = "P₀", type = "observed")

  # Multiple Q's around it
  n_q <- 12
  angles <- seq(0, 2*pi, length.out = n_q + 1)[1:n_q]
  radius <- runif(n_q, 0.3, 0.8)

  q_points <- data.frame(
    x = radius * cos(angles),
    y = radius * sin(angles),
    label = paste0("Q", 1:n_q),
    type = "future"
  )

  # Use a more visible blue
  visible_blue <- "#0080C0"  # Medium blue, more visible than rand_blue

  # Create plot
  p <- ggplot() +
    # Cloud representing distribution μ
    annotate("path",
             x = 1.2 * cos(seq(0, 2*pi, length.out = 100)),
             y = 1.2 * sin(seq(0, 2*pi, length.out = 100)),
             color = visible_blue, linetype = "dashed", size = 1.2) +
    # Future studies
    geom_point(data = q_points, aes(x = x, y = y),
               color = visible_blue, size = 5, alpha = 0.8) +
    # P0
    geom_point(data = p0, aes(x = x, y = y),
               color = rand_yellow, size = 8) +
    geom_text(data = p0, aes(x = x, y = y, label = label),
              color = rand_darkblue, size = 6, fontface = "bold") +
    # Annotations - adjusted position to avoid cutoff
    annotate("text", x = 1.1, y = 1.35,
             label = "Distribution μ\nover future studies",
             color = visible_blue, size = 4.5, fontface = "italic") +
    annotate("text", x = 0, y = -0.3,
             label = "Observed\nstudy",
             color = rand_darkblue, size = 4) +
    coord_fixed(xlim = c(-1.5, 1.7), ylim = c(-1.5, 1.7)) +
    theme_void() +
    theme(
      plot.background = element_rect(fill = rand_white, color = NA),
      panel.background = element_rect(fill = rand_white, color = NA),
      plot.margin = margin(30, 30, 30, 30)
    )

  ggsave(file.path(fig_dir, "slide09_future_studies.png"),
         p, width = 8, height = 6, dpi = 300, bg = "white")

  return(p)
}

# ============================================================================
# Figure 2: Local Geometry Illustration (Slide 11)
# ============================================================================

create_local_geometry_diagram <- function() {
  # P0 in center with ball around it

  # Create ball boundary
  theta <- seq(0, 2*pi, length.out = 100)
  lambda <- 0.5
  ball <- data.frame(
    x = lambda * cos(theta),
    y = lambda * sin(theta)
  )

  # P0 point
  p0 <- data.frame(x = 0, y = 0)

  # Sample points uniformly in ball
  set.seed(456)
  n_samples <- 30
  r <- sqrt(runif(n_samples)) * lambda
  angle <- runif(n_samples, 0, 2*pi)
  samples <- data.frame(
    x = r * cos(angle),
    y = r * sin(angle)
  )

  p <- ggplot() +
    # Fill ball lightly
    geom_polygon(data = ball, aes(x = x, y = y),
                 fill = rand_blue, alpha = 0.15) +
    # Ball boundary
    geom_path(data = ball, aes(x = x, y = y),
              color = rand_blue, size = 1.5) +
    # Sample points
    geom_point(data = samples, aes(x = x, y = y),
               color = rand_blue, alpha = 0.4, size = 2) +
    # P0
    geom_point(data = p0, aes(x = x, y = y),
               color = rand_yellow, size = 10) +
    geom_text(data = p0, aes(x = x, y = y, label = "P₀"),
              color = rand_darkblue, size = 6, fontface = "bold") +
    # Lambda annotation
    annotate("segment", x = 0, y = 0, xend = lambda * cos(pi/4), yend = lambda * sin(pi/4),
             color = rand_darkblue, arrow = arrow(length = unit(0.3, "cm"), ends = "both")) +
    annotate("text", x = lambda * cos(pi/4) / 2 + 0.1, y = lambda * sin(pi/4) / 2 + 0.1,
             label = "λ", color = rand_darkblue, size = 6, fontface = "italic") +
    # Ball label
    annotate("text", x = lambda + 0.15, y = 0,
             label = "U(P₀, λ)",
             color = rand_blue, size = 5, fontface = "italic") +
    # Uniform annotation
    annotate("text", x = 0, y = -lambda - 0.2,
             label = "μ = Uniform(U(P₀, λ))",
             color = rand_darkblue, size = 4.5) +
    coord_fixed(xlim = c(-0.7, 0.7), ylim = c(-0.7, 0.7)) +
    theme_void() +
    theme(
      plot.background = element_rect(fill = rand_white, color = NA),
      panel.background = element_rect(fill = rand_white, color = NA),
      plot.margin = margin(20, 20, 20, 20)
    )

  ggsave(file.path(fig_dir, "slide11_local_geometry.png"),
         p, width = 8, height = 6, dpi = 300, bg = "white")

  return(p)
}

# ============================================================================
# Figure 3: X-Level Compositional Shift (Slide 16)
# ============================================================================

create_compositional_shift_diagram <- function() {
  # Two histograms showing P0(X) vs Q(X) with constant effect functions

  set.seed(789)

  # Create X categories
  x_vals <- c("Type 1", "Type 2", "Type 3", "Type 4")

  # P0 distribution (original)
  p0_props <- c(0.15, 0.35, 0.35, 0.15)

  # Q distribution (shifted - more Type 1 and Type 2)
  q_props <- c(0.25, 0.40, 0.25, 0.10)

  # Effect sizes (constant across P0 and Q)
  effects <- c(0.3, 0.6, 0.8, 0.4)

  # Create data frames
  df_p0 <- data.frame(
    type = factor(x_vals, levels = x_vals),
    proportion = p0_props,
    study = "P₀"
  )

  df_q <- data.frame(
    type = factor(x_vals, levels = x_vals),
    proportion = q_props,
    study = "Q"
  )

  df_combined <- rbind(df_p0, df_q)

  # Histogram comparison
  p1 <- ggplot(df_combined, aes(x = type, y = proportion, fill = study)) +
    geom_col(position = "dodge", alpha = 0.8) +
    scale_fill_manual(values = c("P₀" = rand_yellow, "Q" = rand_blue),
                      name = "Distribution") +
    labs(title = "Covariate Distributions",
         x = "Type (X)", y = "Proportion") +
    theme_rand() +
    theme(legend.position = "top",
          axis.text.x = element_text(angle = 0))

  # Effect functions (constant)
  df_effects <- data.frame(
    type = factor(x_vals, levels = x_vals),
    effect = effects
  )

  p2 <- ggplot(df_effects, aes(x = type, y = effect)) +
    geom_col(fill = rand_darkblue, alpha = 0.8) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    labs(title = "Treatment Effect Functions",
         x = "Type (X)", y = "Effect Size Δ(X)") +
    annotate("text", x = 2.5, y = 0.9,
             label = "Same for P₀ and Q",
             color = rand_darkblue, fontface = "italic", size = 4) +
    theme_rand()

  # Combine
  p <- p1 / p2 +
    plot_annotation(
      title = "X-Level: Compositional Shift",
      subtitle = "Distribution P(X) changes, but effect functions Δ(X) stay constant",
      theme = theme(
        plot.title = element_text(size = 16, face = "bold", color = rand_darkblue),
        plot.subtitle = element_text(size = 12, color = rand_darkblue),
        plot.background = element_rect(fill = rand_white, color = NA)
      )
    )

  ggsave(file.path(fig_dir, "slide16_compositional_shift.png"),
         p, width = 8, height = 8, dpi = 300, bg = "white")

  return(p)
}

# ============================================================================
# Figure 4: X-Level vs Observation-Level Schematic (Slide 18) - HIGH PRIORITY
# ============================================================================

create_xlevel_vs_obslevel_schematic <- function() {
  # Side-by-side comparison showing the fundamental difference

  set.seed(101)

  # Common parameters
  n_types <- 4
  n_per_type <- 8
  type_weights_p0 <- c(2, 5, 5, 2)  # P₀ weights by type
  type_weights_q <- c(4, 6, 3, 2)   # Q weights by type (DIFFERENT pattern)

  # Create fixed x positions (grid within each type)
  x_positions <- c()
  for (i in 1:n_types) {
    x_positions <- c(x_positions, seq(i - 0.3, i + 0.3, length.out = n_per_type))
  }

  # X-Level panel: Uniform within type, varies across types
  xlevel_data <- data.frame()
  for (i in 1:n_types) {
    idx_start <- (i - 1) * n_per_type + 1
    idx_end <- i * n_per_type
    x_pos <- x_positions[idx_start:idx_end]

    # P₀: all same size within type (but varies by type)
    p0_obs <- data.frame(
      x = x_pos,
      y = 2,  # P₀ level
      study = "P₀",
      type = i,
      weight = type_weights_p0[i]
    )
    # Q: SAME x positions, same size within type (but varies by type, DIFFERENT from P₀)
    q_obs <- data.frame(
      x = x_pos,  # SAME x positions as P₀
      y = 1,  # Q level
      study = "Q",
      type = i,
      weight = type_weights_q[i]
    )
    xlevel_data <- rbind(xlevel_data, p0_obs, q_obs)
  }

  p1 <- ggplot(xlevel_data, aes(x = x, y = y, size = weight, color = study)) +
    geom_point(alpha = 0.7) +
    scale_size_continuous(range = c(1.5, 7), guide = "none") +
    scale_color_manual(values = c("P₀" = rand_yellow, "Q" = rand_blue)) +
    # Vertical lines to separate types
    geom_vline(xintercept = seq(0.5, 4.5, 1), color = "gray80", linetype = "dotted", alpha = 0.3) +
    # Labels
    annotate("text", x = 0.3, y = 2, label = "P₀",
             color = rand_yellow, size = 6, fontface = "bold") +
    annotate("text", x = 0.3, y = 1, label = "Q",
             color = rand_blue, size = 6, fontface = "bold") +
    annotate("text", x = 2.5, y = 0.4, label = "Uniform within type",
             color = rand_darkblue, size = 4, fontface = "italic") +
    labs(title = "X-Level: Uniform Within Type") +
    scale_x_continuous(breaks = 1:n_types, labels = paste0("T", 1:n_types)) +
    coord_cartesian(xlim = c(0.2, 4.8), ylim = c(0.3, 2.5)) +
    theme_void() +
    theme(
      plot.title = element_text(hjust = 0.5, size = 14, face = "bold", color = rand_darkblue),
      plot.background = element_rect(fill = rand_white, color = NA),
      axis.text.x = element_text(color = rand_darkblue, size = 10),
      legend.position = "none"
    )

  # Observation-Level panel: P₀ all uniform, Q all individual
  # Use SAME x_positions as left panel for correspondence
  obslevel_data <- data.frame()
  for (i in 1:n_types) {
    idx_start <- (i - 1) * n_per_type + 1
    idx_end <- i * n_per_type
    x_pos <- x_positions[idx_start:idx_end]

    # P₀: all same size (uniform within AND across types)
    p0_obs <- data.frame(
      x = x_pos,
      y = 2,  # P₀ level
      study = "P₀",
      type = i,
      weight = 3.5  # SAME for everyone
    )
    # Q: SAME x positions, all different sizes (individual weights)
    q_obs <- data.frame(
      x = x_pos,  # SAME x positions as P₀
      y = 1,  # Q level
      study = "Q",
      type = i,
      weight = runif(n_per_type, 2, 6)  # DIFFERENT for everyone, larger range
    )
    obslevel_data <- rbind(obslevel_data, p0_obs, q_obs)
  }

  p2 <- ggplot(obslevel_data, aes(x = x, y = y, size = weight, color = study)) +
    geom_point(alpha = 0.7) +
    scale_size_continuous(range = c(1.5, 7), guide = "none") +
    scale_color_manual(values = c("P₀" = rand_yellow, "Q" = rand_blue)) +
    # Vertical lines to separate types
    geom_vline(xintercept = seq(0.5, 4.5, 1), color = "gray80", linetype = "dotted", alpha = 0.3) +
    # Labels
    annotate("text", x = 0.3, y = 2, label = "P₀",
             color = rand_yellow, size = 6, fontface = "bold") +
    annotate("text", x = 0.3, y = 1, label = "Q",
             color = rand_blue, size = 6, fontface = "bold") +
    annotate("text", x = 2.5, y = 0.4, label = "Individual weights",
             color = rand_darkblue, size = 4, fontface = "italic") +
    labs(title = "Observation-Level: Individual Weights") +
    scale_x_continuous(breaks = 1:n_types, labels = paste0("T", 1:n_types)) +
    coord_cartesian(xlim = c(0.2, 4.8), ylim = c(0.3, 2.5)) +
    theme_void() +
    theme(
      plot.title = element_text(hjust = 0.5, size = 14, face = "bold", color = rand_darkblue),
      plot.background = element_rect(fill = rand_white, color = NA),
      axis.text.x = element_text(color = rand_darkblue, size = 10),
      legend.position = "none"
    )

  # Combine side-by-side
  p <- p1 + p2 +
    plot_annotation(
      title = "X-Level vs Observation-Level",
      subtitle = "X-level: Uniform within type (type-specific weights)  |  Observation-Level: Individual weights (observation-specific)",
      theme = theme(
        plot.title = element_text(size = 16, face = "bold", color = rand_darkblue, hjust = 0.5),
        plot.subtitle = element_text(size = 11, color = rand_darkblue, hjust = 0.5),
        plot.background = element_rect(fill = rand_white, color = NA)
      )
    )

  ggsave(file.path(fig_dir, "slide18_xlevel_vs_obslevel.png"),
         p, width = 10, height = 5, dpi = 300, bg = "white")

  return(p)
}

# ============================================================================
# Figure 5: PTE Misleading Example (Slide 13)
# ============================================================================

create_pte_misleading_example <- function() {
  # Scenario: Opposite-signed effect modification
  # Based on explorations/theoretical_pte_effect_modification_v2.R

  set.seed(123)

  # DGP Parameters - calibrated for PTE > 0.5 with near-zero correlation
  # Target: High PTE (~0.65-0.70), low cor(ΔS, ΔY) (~0)
  # Balance condition at X̄=0: β_AX + β_S·γ_AX + β_SX·γ_A ≈ 0
  gamma_0 <- 0
  gamma_A <- 1.0      # Baseline treatment effect on S
  gamma_AX <- 0.5     # Moderate A×X: ΔS = 1 + 0.5·X̄

  beta_0 <- 0
  beta_A <- 0.25      # Small direct effect (for higher PTE)
  beta_AX <- -0.4     # Stronger negative interaction (to balance increased β_S)
  beta_S <- 0.9       # Strong mediation (for higher PTE)
  beta_SX <- -0.05    # Small negative S×X to fine-tune balance

  sigma_S <- 0.5
  sigma_Y <- 0.5

  # Simulate 20 studies with varying X̄
  X_means <- seq(-1.5, 1.5, length.out = 20)
  n_sim <- 500

  Delta_S_all <- numeric(20)
  Delta_Y_all <- numeric(20)
  PTE_all <- numeric(20)

  for (i in 1:20) {
    X_mean_i <- X_means[i]

    # Generate study data
    X <- rnorm(n_sim, mean = X_mean_i, sd = 1)
    A <- rbinom(n_sim, 1, 0.5)

    S <- gamma_0 + (gamma_A + gamma_AX * X) * A + rnorm(n_sim, sd = sigma_S)
    Y <- beta_0 + (beta_A + beta_AX * X) * A + beta_S * S + beta_SX * S * X +
      rnorm(n_sim, sd = sigma_Y)

    # Treatment effects
    Delta_S_all[i] <- mean(S[A == 1]) - mean(S[A == 0])
    Delta_Y_all[i] <- mean(Y[A == 1]) - mean(Y[A == 0])

    # PTE from regression Y ~ A + S
    model_i <- lm(Y ~ A + S)
    total <- Delta_Y_all[i]
    direct <- coef(model_i)["A"]
    indirect <- total - direct
    PTE_all[i] <- indirect / total
  }

  # Correlation across studies
  cor_transport <- cor(Delta_S_all, Delta_Y_all)

  # P₀ is the study with X̄ ≈ 0
  idx_p0 <- which.min(abs(X_means))
  pte_p0 <- PTE_all[idx_p0]

  # Create plot data
  plot_data <- data.frame(
    X_mean = X_means,
    Delta_S = Delta_S_all,
    Delta_Y = Delta_Y_all,
    is_p0 = seq_along(X_means) == idx_p0
  )

  # Scatter plot with color gradient
  p <- ggplot(plot_data, aes(x = Delta_S, y = Delta_Y, color = X_mean)) +
    geom_smooth(method = "lm", se = FALSE, color = "gray60",
                linetype = "dashed", linewidth = 0.8) +
    geom_point(size = 4, alpha = 0.8) +
    # Highlight P₀
    geom_point(data = plot_data[plot_data$is_p0, ],
               aes(x = Delta_S, y = Delta_Y),
               color = rand_darkblue, size = 6, shape = 17) +
    scale_color_gradient(low = rand_blue, high = rand_yellow,
                        name = "Mean\ncovariate X̄") +
    # Annotations
    annotate("text", x = min(Delta_S_all) + 0.05, y = max(Delta_Y_all) - 0.05,
             label = sprintf("cor(ΔS, ΔY) = %.2f", cor_transport),
             hjust = 0, vjust = 1, size = 5.5, color = rand_darkblue,
             fontface = "bold") +
    annotate("text", x = Delta_S_all[idx_p0], y = Delta_Y_all[idx_p0] - 0.15,
             label = sprintf("P₀: PTE = %.2f", pte_p0),
             hjust = 0.5, vjust = 1, size = 4.5, color = rand_darkblue) +
    # Arrow to P₀
    annotate("segment",
             x = Delta_S_all[idx_p0], y = Delta_Y_all[idx_p0] - 0.12,
             xend = Delta_S_all[idx_p0], yend = Delta_Y_all[idx_p0] - 0.02,
             arrow = arrow(length = unit(0.2, "cm")),
             color = rand_darkblue, linewidth = 0.8) +
    labs(
      x = "Treatment Effect on Surrogate (ΔS)",
      y = "Treatment Effect on Outcome (ΔY)"
    ) +
    theme_rand() +
    theme(
      legend.position = c(0.85, 0.25),
      legend.background = element_rect(fill = rand_white, color = rand_darkblue),
      legend.key.height = unit(1, "cm")
    )

  ggsave(file.path(fig_dir, "slide13_pte_misleading.png"),
         p, width = 8, height = 6, dpi = 300, bg = "white")

  return(p)
}

# ============================================================================
# Generate all figures
# ============================================================================

cat("Creating Figure 1: Distribution of Future Studies...\n")
fig1 <- create_future_studies_diagram()

cat("Creating Figure 2: Local Geometry...\n")
fig2 <- create_local_geometry_diagram()

cat("Creating Figure 3: Compositional Shift...\n")
fig3 <- create_compositional_shift_diagram()

cat("Creating Figure 4: X-Level vs Observation-Level...\n")
fig4 <- create_xlevel_vs_obslevel_schematic()

cat("Creating Figure 5: PTE Misleading Example...\n")
fig5 <- create_pte_misleading_example()

cat("\nAll figures created successfully in", fig_dir, "\n")
