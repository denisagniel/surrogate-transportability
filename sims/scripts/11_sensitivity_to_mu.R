#!/usr/bin/env Rscript

#' Sensitivity Analysis Across Innovation Distributions
#'
#' Key insight: We don't know the TRUE μ (innovation distribution).
#' The method assumes μ = Dirichlet(α,...,α), but reality might differ.
#'
#' Research Questions:
#' 1. How much does φ(F_λ) vary across different choices of μ?
#' 2. Does the method's CI width adequately capture this uncertainty?
#' 3. What's the worst-case deviation across plausible μs?
#'
#' Approach:
#' - Fix a baseline study
#' - Compute φ(F_λ) under MANY different innovation distributions:
#'   * Dirichlet(0.5,...,0.5) - concentrated on extremes
#'   * Dirichlet(1,...,1) - uniform (method default)
#'   * Dirichlet(2,...,2) - concentrated on center
#'   * Covariate shift (various class probability shifts)
#'   * Stratified resampling
#'   * etc.
#' - Compare the RANGE of φ values to the method's CI width
#'
#' Validation:
#' If CI width ≥ range of φ across plausible μs, method adequately
#' quantifies uncertainty. Otherwise, method is overconfident.

library(devtools)
library(dplyr)
library(tibble)
library(ggplot2)

devtools::load_all("package/", quiet = TRUE)

set.seed(20260323)

N_BASELINE <- 1000
N_REPLICATIONS <- 500  # Replications for each mu
N_TRUE_STUDIES <- 2000  # For computing φ under each μ
N_INNOVATIONS <- 1000   # For method
LAMBDA <- 0.3  # Fixed lambda for comparison
CONFIDENCE_LEVEL <- 0.95

cat("================================================================\n")
cat("SENSITIVITY ANALYSIS: φ(F_λ) ACROSS INNOVATION DISTRIBUTIONS\n")
cat("================================================================\n\n")

cat("Research Question:\n")
cat("  How much does φ(F_λ) vary when we use different μs?\n")
cat("  Does the method's CI adequately capture this uncertainty?\n\n")

cat("Parameters:\n")
cat(sprintf("  Baseline n: %d\n", N_BASELINE))
cat(sprintf("  Replications per μ: %d\n", N_REPLICATIONS))
cat(sprintf("  Studies per φ computation: %d\n", N_TRUE_STUDIES))
cat(sprintf("  Fixed λ: %.2f\n", LAMBDA))

cat("\n")
cat("Innovation distributions tested:\n")

# Define many innovation distributions
innovation_distributions <- list(
  # Dirichlet with different concentrations
  list(
    name = "Dirichlet(0.5)",
    type = "dirichlet",
    alpha = 0.5,
    description = "Concentrated on extremes"
  ),
  list(
    name = "Dirichlet(1) [METHOD]",
    type = "dirichlet",
    alpha = 1,
    description = "Uniform (method default)"
  ),
  list(
    name = "Dirichlet(2)",
    type = "dirichlet",
    alpha = 2,
    description = "Concentrated on center"
  ),
  list(
    name = "Dirichlet(5)",
    type = "dirichlet",
    alpha = 5,
    description = "Very concentrated on center"
  ),

  # Covariate shift scenarios (if baseline has classes)
  list(
    name = "CovarShift(0.6,0.4)",
    type = "covar_shift",
    target_probs = c(0.6, 0.4),
    description = "Small class proportion shift"
  ),
  list(
    name = "CovarShift(0.7,0.3)",
    type = "covar_shift",
    target_probs = c(0.7, 0.3),
    description = "Moderate shift"
  ),
  list(
    name = "CovarShift(0.8,0.2)",
    type = "covar_shift",
    target_probs = c(0.8, 0.2),
    description = "Large shift"
  )
)

for (i in seq_along(innovation_distributions)) {
  dist <- innovation_distributions[[i]]
  cat(sprintf("  %d. %-25s %s\n", i, dist$name, dist$description))
}

cat("\n")
cat("----------------------------------------------------------------\n")
cat("Computing φ(F_λ) Under Each μ\n")
cat("----------------------------------------------------------------\n\n")

results <- tibble::tibble(
  mu_name = character(),
  mu_type = character(),
  replication = integer(),
  phi_value = numeric()
)

start_time <- Sys.time()

for (dist_idx in seq_along(innovation_distributions)) {
  dist <- innovation_distributions[[dist_idx]]

  cat(sprintf("μ %d/%d: %s\n", dist_idx, length(innovation_distributions), dist$name))

  for (rep in 1:N_REPLICATIONS) {
    if (rep %% 50 == 0 || rep == 1) {
      cat(sprintf("  Rep %d/%d\n", rep, N_REPLICATIONS))
    }

    # Generate baseline
    baseline <- generate_study_data(
      n = N_BASELINE,
      n_classes = 2,
      class_probs = c(0.5, 0.5),
      treatment_effect_surrogate = c(0.3, 0.9),
      treatment_effect_outcome = c(0.2, 0.8)
    )

    # Compute φ(F_λ) under this μ
    if (dist$type == "dirichlet") {
      # Use Dirichlet innovations
      true_studies <- generate_future_study(
        baseline,
        lambda = LAMBDA,
        n_future_studies = N_TRUE_STUDIES,
        alpha = dist$alpha
      )

      delta_s <- true_studies$treatment_effects[, "delta_s"]
      delta_y <- true_studies$treatment_effects[, "delta_y"]
      phi <- cor(delta_s, delta_y)

    } else if (dist$type == "covar_shift") {
      # Use covariate shift
      multiple_shifted <- replicate(N_TRUE_STUDIES, {
        shift <- generate_covariate_shift_study(
          baseline,
          target_class_probs = dist$target_probs,
          n = N_BASELINE
        )
        effects <- compute_multiple_treatment_effects(shift$future_study, c("S", "Y"))
        c(delta_s = effects["S"], delta_y = effects["Y"])
      }, simplify = FALSE)

      shifted_df <- do.call(rbind, multiple_shifted) %>% as.data.frame()
      phi <- cor(shifted_df$delta_s, shifted_df$delta_y)
    }

    results <- rbind(results, tibble::tibble(
      mu_name = dist$name,
      mu_type = dist$type,
      replication = rep,
      phi_value = phi
    ))
  }

  cat("\n")
}

cat("================================================================\n")
cat("RESULTS\n")
cat("================================================================\n\n")

# Summarize φ under each μ
phi_summary <- results %>%
  group_by(mu_name, mu_type) %>%
  summarise(
    n = n(),
    mean_phi = mean(phi_value),
    sd_phi = sd(phi_value),
    min_phi = min(phi_value),
    max_phi = max(phi_value),
    .groups = "drop"
  ) %>%
  arrange(mean_phi)

cat("φ(F_λ) Under Different Innovation Distributions:\n\n")
cat(sprintf("%-30s %-10s %-10s %-12s\n",
            "Innovation Distribution μ", "Mean φ", "SD", "Range"))
cat(strrep("-", 70), "\n")

for (i in 1:nrow(phi_summary)) {
  row <- phi_summary[i, ]
  cat(sprintf("%-30s %-10.4f %-10.4f [%.4f, %.4f]\n",
              row$mu_name,
              row$mean_phi,
              row$sd_phi,
              row$min_phi,
              row$max_phi))
}

cat("\n")

# Compute range across μs
overall_min <- min(phi_summary$min_phi)
overall_max <- max(phi_summary$max_phi)
phi_range <- overall_max - overall_min

cat(sprintf("Range of φ across all μs: [%.4f, %.4f] (width = %.4f)\n",
            overall_min, overall_max, phi_range))

# Now compute method's CI width using Dirichlet(1)
cat("\n")
cat("----------------------------------------------------------------\n")
cat("Method's CI Width (Using Default μ = Dirichlet(1))\n")
cat("----------------------------------------------------------------\n\n")

method_results <- tibble::tibble(
  replication = integer(),
  estimate = numeric(),
  ci_lower = numeric(),
  ci_upper = numeric(),
  ci_width = numeric()
)

for (rep in 1:N_REPLICATIONS) {
  if (rep %% 50 == 0 || rep == 1) {
    cat(sprintf("  Rep %d/%d\n", rep, N_REPLICATIONS))
  }

  baseline <- generate_study_data(
    n = N_BASELINE,
    n_classes = 2,
    class_probs = c(0.5, 0.5),
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  result <- surrogate_inference_if(
    baseline,
    lambda = LAMBDA,
    n_innovations = N_INNOVATIONS,
    functional_type = "correlation"
  )

  method_results <- rbind(method_results, tibble::tibble(
    replication = rep,
    estimate = result$estimate,
    ci_lower = result$ci_lower,
    ci_upper = result$ci_upper,
    ci_width = result$ci_upper - result$ci_lower
  ))
}

mean_ci_width <- mean(method_results$ci_width)

cat(sprintf("\nMethod's mean CI width: %.4f\n", mean_ci_width))
cat(sprintf("Range of φ across μs: %.4f\n", phi_range))
cat(sprintf("Ratio (CI width / φ range): %.2f\n", mean_ci_width / phi_range))

cat("\n")
cat("Interpretation:\n")
if (mean_ci_width >= phi_range) {
  cat("✓ ADEQUATE: CI width covers variability across μs\n")
  cat("  The method's uncertainty quantification accounts for\n")
  cat("  not knowing the exact innovation distribution.\n")
} else if (mean_ci_width >= 0.5 * phi_range) {
  cat("~ PARTIAL: CI width covers ~50% of variability\n")
  cat("  Method captures some but not all μ-uncertainty.\n")
} else {
  cat("✗ INADEQUATE: CI width too narrow\n")
  cat("  Method is overconfident - doesn't account for\n")
  cat("  uncertainty in innovation distribution.\n")
}

cat("\n")
cat("----------------------------------------------------------------\n")
cat("Visualizations\n")
cat("----------------------------------------------------------------\n\n")

if (!dir.exists("sims/results")) {
  dir.create("sims/results", recursive = TRUE)
}

# Plot 1: Distribution of φ under each μ
p1 <- ggplot(results, aes(x = phi_value, fill = mu_name)) +
  geom_density(alpha = 0.5) +
  labs(
    title = "Distribution of φ(F_λ) Across Innovation Distributions",
    subtitle = sprintf("λ = %.2f, %d replications per μ", LAMBDA, N_REPLICATIONS),
    x = "Correlation φ(F_λ)",
    y = "Density",
    fill = "Innovation μ"
  ) +
  theme_minimal()

ggsave("sims/results/sensitivity_phi_distributions.png", p1,
       width = 10, height = 6, dpi = 300)
cat("  Saved: sims/results/sensitivity_phi_distributions.png\n")

# Plot 2: Range comparison
comparison_data <- tibble::tibble(
  type = c("φ range across μs", "Method CI width"),
  value = c(phi_range, mean_ci_width)
)

p2 <- ggplot(comparison_data, aes(x = type, y = value, fill = type)) +
  geom_col() +
  labs(
    title = "Uncertainty Quantification Adequacy",
    subtitle = "Does method's CI cover variability in φ across different μs?",
    x = "",
    y = "Width",
    fill = ""
  ) +
  theme_minimal() +
  theme(legend.position = "none")

ggsave("sims/results/sensitivity_uncertainty_comparison.png", p2,
       width = 8, height = 6, dpi = 300)
cat("  Saved: sims/results/sensitivity_uncertainty_comparison.png\n")

# Save results
saveRDS(results, "sims/results/sensitivity_phi_values.rds")
saveRDS(phi_summary, "sims/results/sensitivity_summary.rds")
saveRDS(method_results, "sims/results/sensitivity_method_cis.rds")

cat("\n")
cat("================================================================\n")
cat("Sensitivity analysis complete!\n")
cat("================================================================\n")
