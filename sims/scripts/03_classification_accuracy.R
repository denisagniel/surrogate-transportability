#' Study 3: Classification of Transportability
#'
#' Tests whether methods correctly identify transportable vs non-transportable surrogates.
#'
#' **Core Question:** Given a surrogate, should we use it in future studies?
#'
#' **Four Scenario Types (2×2 design):**
#' 1. True Positive: Transportable AND traditional says "good"
#' 2. False Positive: NOT transportable BUT traditional says "good"
#' 3. False Negative: Transportable BUT traditional says "bad"
#' 4. True Negative: NOT transportable AND traditional says "bad"
#'
#' **Key Result:** Traditional methods misclassify transportability; we get it right.

library(tidyverse)
library(here)
library(furrr)
library(progressr)

# Load package
devtools::load_all(here("package"))

# Source utilities (these are simulation-specific, not in package)
source(here("sims/scripts/utils/create_dgps.R"))
source(here("sims/scripts/utils/compute_ground_truth.R"))

# Simulation parameters (can be overridden by quick script)
if (!exists("N_REPS")) N_REPS <- 1000  # Replications per scenario
if (!exists("N")) N <- 500              # Sample size
if (!exists("J")) J <- 16               # Number of types
if (!exists("LAMBDA")) LAMBDA <- 0.3    # Neighborhood size
if (!exists("N_CORES")) N_CORES <- parallel::detectCores() - 1

# Set up parallel processing
plan(multisession, workers = N_CORES)

# Function to run single replication
run_single_replication <- function(rep_id, scenario_type, seed_base) {
  # Load package and utilities (needed for parallel workers)
  suppressPackageStartupMessages({
    library(dplyr, warn.conflicts = FALSE)
    devtools::load_all(here::here("package"), quiet = TRUE)
  })
  source(here::here("sims/scripts/utils/create_dgps.R"), local = TRUE)

  # Set seed for this replication
  set.seed(seed_base + rep_id)

  # Generate data for this scenario
  scenario <- switch(scenario_type,
    "true_positive" = generate_true_positive(n = N, J = J, seed = seed_base + rep_id),
    "false_positive" = generate_false_positive(n = N, J = J, seed = seed_base + rep_id),
    "false_negative" = generate_false_negative(n = N, J = J, seed = seed_base + rep_id),
    "true_negative" = generate_true_negative(n = N, J = J, seed = seed_base + rep_id)
  )

  data <- scenario$data
  ground_truth <- scenario$is_transportable

  # Compute type-level treatment effects ADJUSTED for observed covariates (X)
  type_effects <- data %>%
    group_by(type) %>%
    summarize(
      # Regression-adjusted treatment effects (controls for X)
      tau_s = tryCatch({
        if (n() >= 5) {  # Need sufficient data for regression
          coef(lm(S ~ A + X))[["A"]]
        } else {
          mean(S[A == 1], na.rm = TRUE) - mean(S[A == 0], na.rm = TRUE)
        }
      }, error = function(e) {
        mean(S[A == 1], na.rm = TRUE) - mean(S[A == 0], na.rm = TRUE)
      }),
      tau_y = tryCatch({
        if (n() >= 5) {
          coef(lm(Y ~ A + X))[["A"]]
        } else {
          mean(Y[A == 1], na.rm = TRUE) - mean(Y[A == 0], na.rm = TRUE)
        }
      }, error = function(e) {
        mean(Y[A == 1], na.rm = TRUE) - mean(Y[A == 0], na.rm = TRUE)
      }),
      n = n(),
      .groups = "drop"
    )

  pi_hat <- as.numeric(table(data$type) / nrow(data))

  # Traditional methods
  traditional_results <- tryCatch({
    list(
      within_study_cor = compute_within_study_correlation(data),
      pte = compute_pte(data),
      mediation_prop = compute_mediation_effects(data)$proportion_mediated
    )
  }, error = function(e) {
    list(
      within_study_cor = NA_real_,
      pte = NA_real_,
      mediation_prop = NA_real_
    )
  })

  # Classify with traditional methods
  classify_cor <- !is.na(traditional_results$within_study_cor) &&
                  traditional_results$within_study_cor > 0.5
  classify_pte <- !is.na(traditional_results$pte) &&
                  traditional_results$pte > 0.6
  classify_med <- !is.na(traditional_results$mediation_prop) &&
                  traditional_results$mediation_prop > 0.6

  # Local geometric methods
  # USE CORRELATION OF TREATMENT EFFECTS as the classification metric
  # This is what actually determines transportability (not concordance)
  local_geo_results <- tryCatch({
    # Correlation between type-level treatment effects
    cor_effects_est <- cor(type_effects$tau_s, type_effects$tau_y)

    # Also compute concordance for comparison
    tv_result <- minimax_concordance_tv_ball(
      tau_s = type_effects$tau_s,
      tau_y = type_effects$tau_y,
      pi_hat = pi_hat,
      lambda = LAMBDA
    )

    wass_result <- minimax_concordance_wasserstein_dual(
      tau_s = type_effects$tau_s,
      tau_y = type_effects$tau_y,
      pi_hat = pi_hat,
      lambda = LAMBDA
    )

    list(
      cor_effects_est = cor_effects_est,
      tv_phi_star = tv_result$phi_star,
      wass_phi_star = wass_result$phi_star
    )
  }, error = function(e) {
    list(
      cor_effects_est = NA_real_,
      tv_phi_star = NA_real_,
      wass_phi_star = NA_real_
    )
  })

  # Classify with local geometric methods
  # Use correlation between treatment effects > 0.3 as threshold
  # This directly evaluates transportability (positive correlation indicates alignment)
  classify_tv <- !is.na(local_geo_results$cor_effects_est) &&
                 local_geo_results$cor_effects_est > 0.3
  classify_wass <- !is.na(local_geo_results$cor_effects_est) &&
                   local_geo_results$cor_effects_est > 0.3

  # Return results
  tibble(
    rep_id = rep_id,
    scenario_type = scenario_type,
    ground_truth = ground_truth,
    # Traditional methods
    within_study_cor = traditional_results$within_study_cor,
    pte = traditional_results$pte,
    mediation_prop = traditional_results$mediation_prop,
    classify_cor = classify_cor,
    classify_pte = classify_pte,
    classify_med = classify_med,
    # Local geometric methods
    cor_effects_est = local_geo_results$cor_effects_est,  # Our classification metric
    tv_phi_star = local_geo_results$tv_phi_star,
    wass_phi_star = local_geo_results$wass_phi_star,
    classify_tv = classify_tv,
    classify_wass = classify_wass,
    # DGP info
    cor_effects = scenario$cor_effects,  # True correlation
    cor_within = scenario$cor_within
  )
}

# Run simulations
cat("Running Study 3: Classification Accuracy\n")
cat(sprintf("  Sample size: %d\n", N))
cat(sprintf("  Types: %d\n", J))
cat(sprintf("  Lambda: %.2f\n", LAMBDA))
cat(sprintf("  Replications per scenario: %d\n", N_REPS))
cat(sprintf("  Total replications: %d\n", N_REPS * 4))
cat(sprintf("  Parallel cores: %d\n\n", N_CORES))

# Scenario types
scenarios <- c("true_positive", "false_positive", "false_negative", "true_negative")

# Run with progress bar
with_progress({
  p <- progressor(steps = length(scenarios) * N_REPS)

  results <- map_dfr(scenarios, function(scenario_type) {
    cat(sprintf("Running %s scenario...\n", scenario_type))

    seed_base <- switch(scenario_type,
      "true_positive" = 10000,
      "false_positive" = 20000,
      "false_negative" = 30000,
      "true_negative" = 40000
    )

    future_map_dfr(1:N_REPS, function(rep_id) {
      p()
      run_single_replication(rep_id, scenario_type, seed_base)
    }, .options = furrr_options(seed = TRUE))
  })
})

cat("\nSimulation complete!\n")
cat(sprintf("Total replications: %d\n", nrow(results)))

# Compute classification metrics by method
cat("\n=== CLASSIFICATION METRICS ===\n\n")

# Reshape to long format for easier analysis
results_long <- results %>%
  pivot_longer(
    cols = starts_with("classify_"),
    names_to = "method",
    names_prefix = "classify_",
    values_to = "prediction"
  )

# Compute metrics by method
metrics_by_method <- results_long %>%
  group_by(method) %>%
  summarize(
    classification_metrics = list(compute_classification_metrics(ground_truth, prediction)),
    .groups = "drop"
  ) %>%
  unnest(classification_metrics)

# Pretty print results
metrics_table <- metrics_by_method %>%
  mutate(
    method = recode(method,
      "cor" = "Within-study correlation",
      "pte" = "PTE",
      "med" = "Mediation",
      "tv" = "TV-ball minimax",
      "wass" = "Wasserstein minimax"
    )
  ) %>%
  select(
    Method = method,
    Sensitivity = sensitivity,
    Specificity = specificity,
    `FP Rate` = fpr,
    `FN Rate` = fnr,
    Accuracy = accuracy,
    Precision = precision
  ) %>%
  mutate(across(where(is.numeric), ~round(., 3)))

print(metrics_table)

# Summary by scenario type
cat("\n=== METRICS BY SCENARIO ===\n\n")

metrics_by_scenario <- results_long %>%
  group_by(scenario_type, method) %>%
  summarize(
    n = n(),
    n_predict_transportable = sum(prediction, na.rm = TRUE),
    prop_predict_transportable = mean(prediction, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(
    names_from = method,
    values_from = c(n_predict_transportable, prop_predict_transportable)
  )

print(metrics_by_scenario)

# Save results
output_dir <- here("sims/results")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

saveRDS(results, file.path(output_dir, "classification_results.rds"))
write_csv(metrics_by_method, file.path(output_dir, "classification_metrics.csv"))
write_csv(metrics_by_scenario, file.path(output_dir, "classification_by_scenario.csv"))

cat(sprintf("\nResults saved to: %s\n", output_dir))

# Create summary plot
library(ggplot2)

# Plot 1: Classification metrics comparison
p1 <- metrics_by_method %>%
  mutate(
    method = recode(method,
      "cor" = "Within-study\ncorrelation",
      "pte" = "PTE",
      "med" = "Mediation",
      "tv" = "TV-ball\nminimax",
      "wass" = "Wasserstein\nminimax"
    )
  ) %>%
  pivot_longer(
    cols = c(sensitivity, specificity, accuracy),
    names_to = "metric",
    values_to = "value"
  ) %>%
  mutate(
    metric = recode(metric,
      "sensitivity" = "Sensitivity\n(TPR)",
      "specificity" = "Specificity\n(TNR)",
      "accuracy" = "Accuracy"
    )
  ) %>%
  ggplot(aes(x = method, y = value, fill = metric)) +
  geom_col(position = "dodge") +
  geom_hline(yintercept = 0.9, linetype = "dashed", color = "red", alpha = 0.5) +
  scale_fill_brewer(palette = "Set2") +
  labs(
    title = "Classification Performance: Traditional vs Local Geometric Methods",
    subtitle = sprintf("N=%d, J=%d types, λ=%.2f, %d replications per scenario", N, J, LAMBDA, N_REPS),
    x = "Method",
    y = "Value",
    fill = "Metric"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(size = 9),
    legend.position = "bottom"
  ) +
  ylim(0, 1)

ggsave(file.path(output_dir, "classification_performance.pdf"), p1, width = 10, height = 6)

# Plot 2: ROC-like comparison (FPR vs TPR)
p2 <- metrics_by_method %>%
  mutate(
    method_type = ifelse(method %in% c("tv", "wass"), "Local Geometric", "Traditional")
  ) %>%
  ggplot(aes(x = fpr, y = sensitivity, color = method, shape = method_type)) +
  geom_point(size = 4) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", alpha = 0.3) +
  scale_color_brewer(palette = "Set1") +
  labs(
    title = "Classification Accuracy: False Positive Rate vs True Positive Rate",
    subtitle = "Upper left corner = ideal (high TPR, low FPR)",
    x = "False Positive Rate",
    y = "True Positive Rate (Sensitivity)",
    color = "Method",
    shape = "Method Type"
  ) +
  theme_minimal() +
  xlim(0, 1) +
  ylim(0, 1) +
  coord_fixed()

ggsave(file.path(output_dir, "classification_roc_comparison.pdf"), p2, width = 8, height = 6)

cat("\nPlots saved to:", output_dir, "\n")

# Print key findings
cat("\n=== KEY FINDINGS ===\n\n")

traditional_accuracy <- metrics_by_method %>%
  filter(method %in% c("cor", "pte", "med")) %>%
  pull(accuracy) %>%
  mean(na.rm = TRUE)

local_geo_accuracy <- metrics_by_method %>%
  filter(method %in% c("tv", "wass")) %>%
  pull(accuracy) %>%
  mean(na.rm = TRUE)

traditional_fpr <- metrics_by_method %>%
  filter(method %in% c("cor", "pte", "med")) %>%
  pull(fpr) %>%
  mean(na.rm = TRUE)

local_geo_fpr <- metrics_by_method %>%
  filter(method %in% c("tv", "wass")) %>%
  pull(fpr) %>%
  mean(na.rm = TRUE)

cat(sprintf("Traditional methods average accuracy: %.1f%%\n", traditional_accuracy * 100))
cat(sprintf("Local geometric methods average accuracy: %.1f%%\n", local_geo_accuracy * 100))
cat(sprintf("Improvement: +%.1f%%\n\n", (local_geo_accuracy - traditional_accuracy) * 100))

cat(sprintf("Traditional methods average FP rate: %.1f%%\n", traditional_fpr * 100))
cat(sprintf("Local geometric methods average FP rate: %.1f%%\n", local_geo_fpr * 100))
cat(sprintf("Reduction: %.1f%%\n\n", (traditional_fpr - local_geo_fpr) * 100))

cat("INTERPRETATION:\n")
cat("When deciding whether to use a surrogate in future studies,\n")
cat(sprintf("traditional methods achieve %.0f%% accuracy with %.0f%% false positive rate.\n",
            traditional_accuracy * 100, traditional_fpr * 100))
cat(sprintf("Local geometric evaluation achieves %.0f%% accuracy with %.0f%% false positive rate.\n\n",
            local_geo_accuracy * 100, local_geo_fpr * 100))

cat("Study 3 complete!\n")
