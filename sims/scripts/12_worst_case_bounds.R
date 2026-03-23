#!/usr/bin/env Rscript

#' Worst-Case Bounds Across Innovation Distribution Class
#'
#' Most principled robustness check:
#' We don't know the true μ, but we can bound φ(F_λ) over a CLASS of μs.
#'
#' Mathematical Setup:
#'   M = class of plausible innovation distributions
#'       (e.g., all Dirichlet(α) for α ∈ [0.1, 10])
#'
#'   For given baseline P̂_n:
#'     φ*(P̂_n) = sup_{μ ∈ M} φ(F_λ^μ | P̂_n)
#'     φ_*(P̂_n) = inf_{μ ∈ M} φ(F_λ^μ | P̂_n)
#'
#'   Worst-case bound: [φ_*, φ*]
#'
#' Research Questions:
#' 1. How wide is [φ_*, φ*] for different classes M?
#' 2. Does method's CI contain this worst-case interval?
#' 3. If we report [φ_*, φ*], do we get guaranteed coverage?
#'
#' This is a MINIMAX approach: provide bounds that hold for ALL μ ∈ M.

library(devtools)
library(dplyr)
library(tibble)
library(ggplot2)

devtools::load_all("package/", quiet = TRUE)

set.seed(20260323)

N_BASELINE <- 1000
N_REPLICATIONS <- 200    # Baselines to test
N_TRUE_STUDIES <- 2000   # For computing φ under each μ
N_INNOVATIONS <- 1000    # For method
LAMBDA <- 0.3
CONFIDENCE_LEVEL <- 0.95

# Grid search parameters
N_GRID_POINTS <- 20  # Search over 20 values of α

cat("================================================================\n")
cat("WORST-CASE BOUNDS: MINIMAX VALIDATION\n")
cat("================================================================\n\n")

cat("Approach:\n")
cat("  1. Define class M of plausible innovation distributions\n")
cat("  2. For each baseline, search M to find:\n")
cat("     - φ* = sup_{μ ∈ M} φ(F_λ^μ)\n")
cat("     - φ_* = inf_{μ ∈ M} φ(F_λ^μ)\n")
cat("  3. Compare [φ_*, φ*] to method's CI\n")
cat("  4. Report: Does CI contain worst-case interval?\n\n")

cat("Parameters:\n")
cat(sprintf("  Baseline n: %d\n", N_BASELINE))
cat(sprintf("  Replications: %d\n", N_REPLICATIONS))
cat(sprintf("  Fixed λ: %.2f\n", LAMBDA))

cat("\n")
cat("Class M: Dirichlet(α) for α ∈ [0.1, 10]\n")
cat(sprintf("  (Searching %d grid points)\n", N_GRID_POINTS))

# Define grid over α
alpha_grid <- exp(seq(log(0.1), log(10), length.out = N_GRID_POINTS))

cat("\n")
cat("Searching α ∈ {")
cat(paste(sprintf("%.2f", alpha_grid[1:5]), collapse = ", "))
cat(", ..., ")
cat(paste(sprintf("%.2f", tail(alpha_grid, 3)), collapse = ", "))
cat("}\n\n")

cat("----------------------------------------------------------------\n")
cat("Computing Worst-Case Bounds\n")
cat("----------------------------------------------------------------\n\n")

results <- tibble::tibble(
  replication = integer(),
  phi_star = numeric(),      # sup over M
  phi_star_lower = numeric(), # inf over M
  phi_star_width = numeric(), # worst-case bound width
  method_estimate = numeric(),
  method_ci_lower = numeric(),
  method_ci_upper = numeric(),
  method_ci_width = numeric(),
  ci_contains_bounds = logical(),
  bounds_contain_method = logical()
)

start_time <- Sys.time()

for (rep in 1:N_REPLICATIONS) {
  if (rep %% 20 == 0 || rep == 1) {
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
    rate <- elapsed / rep
    remaining <- rate * (N_REPLICATIONS - rep)
    cat(sprintf("Replication %d/%d (%.2f min elapsed, %.2f min/rep, ~%.1f min remaining)\n",
                rep, N_REPLICATIONS, elapsed, rate, remaining))
  }

  # Generate baseline
  baseline <- generate_study_data(
    n = N_BASELINE,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  # Search for sup and inf over M
  phi_values <- numeric(N_GRID_POINTS)

  for (i in seq_along(alpha_grid)) {
    alpha <- alpha_grid[i]

    # Compute φ under Dirichlet(α)
    true_studies <- generate_future_study(
      baseline,
      lambda = LAMBDA,
      n_future_studies = N_TRUE_STUDIES,
      alpha = alpha
    )

    delta_s <- true_studies$treatment_effects[, "delta_s"]
    delta_y <- true_studies$treatment_effects[, "delta_y"]
    phi_values[i] <- cor(delta_s, delta_y)
  }

  # Worst-case bounds
  phi_star <- max(phi_values)
  phi_star_lower <- min(phi_values)
  phi_star_width <- phi_star - phi_star_lower

  # Method's CI (using default α=1)
  method_result <- tryCatch({
    surrogate_inference_if(
      baseline,
      lambda = LAMBDA,
      n_innovations = N_INNOVATIONS,
      functional_type = "correlation"
    )
  }, error = function(e) {
    warning(sprintf("Error: %s", e$message))
    return(NULL)
  })

  if (is.null(method_result)) next

  # Check containment both ways
  ci_contains_bounds <- (method_result$ci_lower <= phi_star_lower) &&
                        (method_result$ci_upper >= phi_star)

  bounds_contain_method <- (phi_star_lower <= method_result$estimate) &&
                           (phi_star >= method_result$estimate)

  results <- rbind(results, tibble::tibble(
    replication = rep,
    phi_star = phi_star,
    phi_star_lower = phi_star_lower,
    phi_star_width = phi_star_width,
    method_estimate = method_result$estimate,
    method_ci_lower = method_result$ci_lower,
    method_ci_upper = method_result$ci_upper,
    method_ci_width = method_result$ci_upper - method_result$ci_lower,
    ci_contains_bounds = ci_contains_bounds,
    bounds_contain_method = bounds_contain_method
  ))
}

cat("\n")
cat("================================================================\n")
cat("RESULTS\n")
cat("================================================================\n\n")

cat("Worst-Case Bounds Statistics:\n\n")
cat(sprintf("  Mean worst-case interval: [%.4f, %.4f]\n",
            mean(results$phi_star_lower),
            mean(results$phi_star)))
cat(sprintf("  Mean bound width: %.4f\n", mean(results$phi_star_width)))
cat(sprintf("  SD bound width: %.4f\n", sd(results$phi_star_width)))

cat("\n")
cat("Method CI Statistics:\n\n")
cat(sprintf("  Mean CI: [%.4f, %.4f]\n",
            mean(results$method_ci_lower),
            mean(results$method_ci_upper)))
cat(sprintf("  Mean CI width: %.4f\n", mean(results$method_ci_width)))
cat(sprintf("  SD CI width: %.4f\n", sd(results$method_ci_width)))

cat("\n")
cat("Comparison:\n\n")
cat(sprintf("  CI width / Bound width: %.2f\n",
            mean(results$method_ci_width) / mean(results$phi_star_width)))

ci_coverage_rate <- mean(results$ci_contains_bounds)
bounds_coverage_rate <- mean(results$bounds_contain_method)

cat(sprintf("\n  CI contains [φ_*, φ*]: %.1f%% (%d/%d)\n",
            ci_coverage_rate * 100,
            sum(results$ci_contains_bounds),
            nrow(results)))

cat(sprintf("  [φ_*, φ*] contains estimate: %.1f%% (%d/%d)\n",
            bounds_coverage_rate * 100,
            sum(results$bounds_contain_method),
            nrow(results)))

cat("\n")
cat("Interpretation:\n\n")

if (ci_coverage_rate >= 0.90) {
  cat("✓ ROBUST: Method's CI covers worst-case bounds in ≥90% of cases\n")
  cat("  → CI provides robust inference across innovation distribution class\n")
} else if (ci_coverage_rate >= 0.75) {
  cat("~ PARTIAL: CI covers worst-case bounds in 75-90% of cases\n")
  cat("  → Some robustness, but not guaranteed coverage\n")
} else {
  cat("✗ NOT ROBUST: CI rarely covers worst-case bounds\n")
  cat("  → Method does not account for μ-uncertainty\n")
}

cat("\n")

if (mean(results$method_ci_width) >= 1.5 * mean(results$phi_star_width)) {
  cat("✓ CONSERVATIVE: CI is wider than worst-case bounds\n")
  cat("  → Method overestimates uncertainty (safe)\n")
} else if (mean(results$method_ci_width) >= 0.8 * mean(results$phi_star_width)) {
  cat("~ COMPARABLE: CI width similar to worst-case bound width\n")
  cat("  → Appropriate uncertainty quantification\n")
} else {
  cat("✗ OVERCONFIDENT: CI narrower than worst-case bounds\n")
  cat("  → Method underestimates uncertainty\n")
}

cat("\n")
cat("----------------------------------------------------------------\n")
cat("Visualizations\n")
cat("----------------------------------------------------------------\n\n")

if (!dir.exists("sims/results")) {
  dir.create("sims/results", recursive = TRUE)
}

# Plot 1: CI vs worst-case bounds for sample of replications
sample_reps <- results %>%
  slice_sample(n = min(100, nrow(results))) %>%
  mutate(rep_id = row_number())

p1 <- ggplot(sample_reps) +
  geom_pointrange(aes(x = rep_id, y = method_estimate,
                      ymin = method_ci_lower, ymax = method_ci_upper),
                  color = "blue", alpha = 0.5) +
  geom_errorbar(aes(x = rep_id, ymin = phi_star_lower, ymax = phi_star),
                width = 0.5, color = "red", linewidth = 0.8) +
  labs(
    title = "Method CI (blue) vs. Worst-Case Bounds (red)",
    subtitle = sprintf("Red = [φ_*, φ*] over Dirichlet(α), α ∈ [0.1, 10]; Blue = Method CI (α=1)"),
    x = "Replication (sample)",
    y = "Correlation",
    caption = "Ideally blue bars should contain red bars"
  ) +
  theme_minimal()

ggsave("sims/results/worst_case_bounds_comparison.png", p1,
       width = 12, height = 6, dpi = 300)
cat("  Saved: sims/results/worst_case_bounds_comparison.png\n")

# Plot 2: Width comparison
width_data <- tibble::tibble(
  type = c(rep("Worst-case bounds", nrow(results)),
           rep("Method CI", nrow(results))),
  width = c(results$phi_star_width, results$method_ci_width)
)

p2 <- ggplot(width_data, aes(x = type, y = width, fill = type)) +
  geom_violin() +
  geom_boxplot(width = 0.2, alpha = 0.7) +
  labs(
    title = "Distribution of Interval Widths",
    subtitle = "Comparing worst-case bounds vs. method's CI",
    x = "",
    y = "Width",
    fill = ""
  ) +
  theme_minimal() +
  theme(legend.position = "none")

ggsave("sims/results/worst_case_width_comparison.png", p2,
       width = 8, height = 6, dpi = 300)
cat("  Saved: sims/results/worst_case_width_comparison.png\n")

# Save results
saveRDS(results, "sims/results/worst_case_bounds_detailed.rds")

cat("\n")
cat("================================================================\n")
cat("PAPER IMPLICATIONS\n")
cat("================================================================\n\n")

if (ci_coverage_rate >= 0.90) {
  cat("Key Finding:\n")
  cat("  The method's CI (assuming μ = Dirichlet(1)) provides\n")
  cat("  robust inference that covers worst-case bounds across\n")
  cat("  the entire class of Dirichlet(α) distributions for\n")
  cat("  α ∈ [0.1, 10] in ≥90% of cases.\n\n")

  cat("Paper Claim:\n")
  cat("  'We validated robustness by computing worst-case bounds\n")
  cat("   for φ(F_λ) over a broad class of innovation distributions.\n")
  cat(sprintf("   The method's 95%% CI contained these bounds in %.0f%% of\n",
              ci_coverage_rate * 100))
  cat("   cases, demonstrating that our uncertainty quantification\n")
  cat("   is robust to misspecification of μ.'\n")
} else {
  cat("Finding:\n")
  cat("  Method's CI does not consistently cover worst-case bounds.\n")
  cat("  This suggests the approach may be sensitive to choice of μ.\n\n")

  cat("Options:\n")
  cat("  1. Report [φ_*, φ*] as robust bounds (instead of point estimate)\n")
  cat("  2. Develop methods that explicitly account for μ-uncertainty\n")
  cat("  3. Restrict to smaller class M where coverage is adequate\n")
}

cat("\n")
cat("================================================================\n")
cat("Worst-case analysis complete!\n")
cat("================================================================\n")
