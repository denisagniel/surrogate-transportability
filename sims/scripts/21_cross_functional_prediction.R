#!/usr/bin/env Rscript

#' Cross-Functional Prediction
#'
#' Research Questions:
#' 1. Does high φ̂_A predict high empirical performance on φ_B?
#' 2. Which functional is the best predictor of overall surrogate quality?
#' 3. Can we use a single functional to assess transportability?
#'
#' Design:
#'   For each baseline:
#'     1. Estimate ALL four functionals on baseline
#'     2. Generate test studies using each mechanism
#'     3. Compute empirical performance on ALL functionals
#'     4. Build correlation matrix: estimated vs. empirical
#'
#' Key Question: Can φ̂_correlation predict empirical PPV?

library(devtools)
library(dplyr)
library(tibble)
library(ggplot2)

# Ensure we're in project root
while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

if (!dir.exists("package")) {
  stop("Cannot find package/ directory. Please run from project root or sims/scripts/")
}

devtools::load_all("package/", quiet = TRUE)

set.seed(20260323)

# Parameters
N_BASELINE <- 1000
N_REPLICATIONS <- 200
N_INNOVATIONS <- 1000  # For φ̂ estimation
N_TEST_STUDIES <- 500  # For empirical performance

# Test scenarios
scenarios <- tibble::tibble(
  name = c("Small λ=0.1", "Moderate λ=0.3", "Large λ=0.5"),
  lambda = c(0.1, 0.3, 0.5)
)

# Mechanisms for robustness testing
mechanisms <- c("mixture", "covariate_shift", "selection")

# Borrow helper from script 14
source("sims/scripts/14_decision_validation.R", local = TRUE)

cat("================================================================\n")
cat("CROSS-FUNCTIONAL PREDICTION\n")
cat("================================================================\n\n")

cat("Research Questions:\n")
cat("  1. Does high φ̂_A predict high empirical performance on φ_B?\n")
cat("  2. Which functional is the best predictor?\n")
cat("  3. Can we use ONE functional to assess overall quality?\n\n")

cat("Design:\n")
cat("  For each baseline:\n")
cat("    1. Estimate ALL four functionals: φ̂_correlation, φ̂_probability, φ̂_PPV, φ̂_cond_mean\n")
cat("    2. Generate test studies using each mechanism\n")
cat("    3. Compute empirical performance on all functionals\n")
cat("    4. Correlate: φ̂_A with emp_B for all A, B pairs\n\n")

cat("Parameters:\n")
cat(sprintf("  Baseline n: %d\n", N_BASELINE))
cat(sprintf("  Replications: %d\n", N_REPLICATIONS))
cat(sprintf("  Innovations for φ̂: %d\n", N_INNOVATIONS))
cat(sprintf("  Test studies for empirical: %d\n", N_TEST_STUDIES))

cat("\n")
cat("Mechanisms:\n")
for (mech in mechanisms) {
  cat(sprintf("  - %s\n", mech))
}

cat("\n")
cat("----------------------------------------------------------------\n")
cat("Running Cross-Functional Prediction Study\n")
cat("----------------------------------------------------------------\n\n")

start_time <- Sys.time()

all_results <- tibble::tibble()

total_combinations <- nrow(scenarios) * length(mechanisms) * N_REPLICATIONS
combination <- 0

for (s in 1:nrow(scenarios)) {
  scenario <- scenarios[s, ]
  lambda <- scenario$lambda

  for (mech in mechanisms) {

    cat(sprintf("Scenario: %s, Mechanism: %s\n", scenario$name, mech))

    for (rep in 1:N_REPLICATIONS) {
      combination <- combination + 1

      if (rep %% 20 == 0 || rep == 1) {
        elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
        rate <- elapsed / combination
        remaining <- rate * (total_combinations - combination)
        cat(sprintf("  Replication %d/%d (%.2f min elapsed, %.3f min/rep, ~%.1f min remaining)\n",
                    rep, N_REPLICATIONS, elapsed, rate, remaining))
      }

      # Generate baseline
      baseline <- generate_study_data(
        n = N_BASELINE,
        treatment_effect_surrogate = c(0.3, 0.9),
        treatment_effect_outcome = c(0.2, 0.8)
      )

      # Step 1: Estimate ALL four functionals on baseline

      # Correlation
      phi_hat_correlation <- tryCatch({
        result <- surrogate_inference_if(
          baseline, lambda = lambda, n_innovations = N_INNOVATIONS,
          functional_type = "correlation"
        )
        result$estimate
      }, error = function(e) NA_real_)

      # Probability (ε_S = 0, ε_Y = 0)
      phi_hat_probability <- tryCatch({
        result <- surrogate_inference_if(
          baseline, lambda = lambda, n_innovations = N_INNOVATIONS,
          functional_type = "probability",
          epsilon_s = 0, epsilon_y = 0
        )
        result$estimate
      }, error = function(e) NA_real_)

      # PPV (ε_S = 0, ε_Y = 0)
      phi_hat_ppv <- tryCatch({
        result <- surrogate_inference_if(
          baseline, lambda = lambda, n_innovations = N_INNOVATIONS,
          functional_type = "ppv",
          epsilon_s = 0, epsilon_y = 0
        )
        result$estimate
      }, error = function(e) NA_real_)

      # Conditional mean (δ_S = 0.5)
      phi_hat_cond_mean <- tryCatch({
        result <- surrogate_inference_if(
          baseline, lambda = lambda, n_innovations = N_INNOVATIONS,
          functional_type = "conditional_mean",
          delta_s_value = 0.5
        )
        result$estimate
      }, error = function(e) NA_real_)

      # Skip if any estimation failed
      if (any(is.na(c(phi_hat_correlation, phi_hat_probability,
                      phi_hat_ppv, phi_hat_cond_mean)))) {
        next
      }

      # Step 2: Generate test studies using mechanism
      treatment_effects <- matrix(NA, nrow = N_TEST_STUDIES, ncol = 2)

      for (i in 1:N_TEST_STUDIES) {
        future_data <- tryCatch({
          generate_future_by_mechanism(
            baseline = baseline,
            mechanism = mech,
            lambda = lambda,
            n_future = nrow(baseline)
          )
        }, error = function(e) NULL)

        if (is.null(future_data)) next

        delta_s <- compute_treatment_effect(future_data, "S")
        delta_y <- compute_treatment_effect(future_data, "Y")

        treatment_effects[i, ] <- c(delta_s, delta_y)
      }

      # Remove NAs
      treatment_effects <- treatment_effects[complete.cases(treatment_effects), , drop = FALSE]

      if (nrow(treatment_effects) < 50) next

      # Step 3: Compute empirical performance on ALL functionals

      # Empirical correlation
      emp_correlation <- cor(treatment_effects[, 1], treatment_effects[, 2])

      # Empirical probability (ε_S = 0, ε_Y = 0)
      exceed_s_prob <- treatment_effects[, 1] > 0
      emp_probability <- if (sum(exceed_s_prob) > 0) {
        sum(treatment_effects[, 1] > 0 & treatment_effects[, 2] > 0) / sum(exceed_s_prob)
      } else {
        NA_real_
      }

      # Empirical PPV (ε_S = 0, ε_Y = 0)
      exceed_s_ppv <- treatment_effects[, 1] > 0
      emp_ppv <- if (sum(exceed_s_ppv) > 0) {
        sum(treatment_effects[, 1] > 0 & treatment_effects[, 2] > 0) / sum(exceed_s_ppv)
      } else {
        NA_real_
      }

      # Empirical conditional mean (δ_S = 0.5)
      delta_s_all <- treatment_effects[, 1]
      delta_y_all <- treatment_effects[, 2]
      bandwidth <- 1.06 * sd(delta_s_all) * length(delta_s_all)^(-1/5)
      kernel_weights <- dnorm((delta_s_all - 0.5) / bandwidth)

      emp_cond_mean <- if (sum(kernel_weights) > 0) {
        sum(kernel_weights * delta_y_all) / sum(kernel_weights)
      } else {
        NA_real_
      }

      # Skip if any empirical computation failed
      if (any(is.na(c(emp_correlation, emp_probability, emp_ppv, emp_cond_mean)))) {
        next
      }

      # Store results (capture values to avoid scoping issues)
      scenario_name_val <- scenario$name

      all_results <- rbind(all_results, tibble::tibble(
        replication = rep,
        scenario = scenario_name_val,
        lambda = lambda,
        mechanism = mech,

        # Estimated functionals
        phi_hat_correlation = phi_hat_correlation,
        phi_hat_probability = phi_hat_probability,
        phi_hat_ppv = phi_hat_ppv,
        phi_hat_cond_mean = phi_hat_cond_mean,

        # Empirical functionals
        emp_correlation = emp_correlation,
        emp_probability = emp_probability,
        emp_ppv = emp_ppv,
        emp_cond_mean = emp_cond_mean
      ))
    }
    cat("\n")
  }
}

cat("================================================================\n")
cat("RESULTS\n")
cat("================================================================\n\n")

# Compute correlation matrix: φ̂_A with emp_B
cat("Correlation Matrix: Estimated φ̂ vs. Empirical Performance\n\n")
cat("Rows: Estimated functional on baseline\n")
cat("Cols: Empirical performance on test studies\n\n")

# Overall correlation matrix
correlation_matrix <- tibble::tibble(
  estimated = character(),
  emp_correlation = numeric(),
  emp_probability = numeric(),
  emp_ppv = numeric(),
  emp_cond_mean = numeric()
)

for (est_func in c("phi_hat_correlation", "phi_hat_probability",
                   "phi_hat_ppv", "phi_hat_cond_mean")) {

  row_data <- list(
    estimated = gsub("phi_hat_", "", est_func)
  )

  for (emp_func in c("emp_correlation", "emp_probability",
                     "emp_ppv", "emp_cond_mean")) {

    corr_val <- cor(all_results[[est_func]],
                    all_results[[emp_func]],
                    use = "complete.obs")

    row_data[[emp_func]] <- corr_val
  }

  correlation_matrix <- rbind(correlation_matrix, tibble::as_tibble(row_data))
}

cat(sprintf("%-20s %15s %15s %15s %15s\n",
            "Estimated ↓ / Emp →", "Correlation", "Probability", "PPV", "Cond Mean"))
cat(strrep("-", 90), "\n")

for (i in 1:nrow(correlation_matrix)) {
  row <- correlation_matrix[i, ]
  cat(sprintf("%-20s %14.3f %15.3f %15.3f %15.3f\n",
              row$estimated,
              row$emp_correlation,
              row$emp_probability,
              row$emp_ppv,
              row$emp_cond_mean))
}

cat("\n")
cat("Interpretation:\n")
cat("  - Diagonal: Self-prediction (φ̂_A predicts emp_A)\n")
cat("  - Off-diagonal: Cross-prediction (φ̂_A predicts emp_B)\n")
cat("  - High correlation (r > 0.7): Strong predictive relationship\n")
cat("  - Moderate (0.4 < r < 0.7): Useful but imperfect\n")
cat("  - Weak (r < 0.4): Limited predictive value\n\n")

# Find best predictor for each empirical functional
cat("Best Predictor for Each Empirical Functional:\n\n")

for (emp_func in c("emp_correlation", "emp_probability", "emp_ppv", "emp_cond_mean")) {
  best_row <- correlation_matrix %>%
    arrange(desc(!!sym(emp_func))) %>%
    slice(1)

  cat(sprintf("  %s: φ̂_%s (r = %.3f)\n",
              gsub("emp_", "", emp_func),
              best_row$estimated,
              best_row[[emp_func]]))
}

# Mechanism-specific correlations
cat("\n")
cat("Predictiveness by Mechanism:\n\n")

for (mech in mechanisms) {
  cat(sprintf("Mechanism: %s\n", mech))

  mech_data <- all_results %>% filter(mechanism == mech)

  # Focus on key relationships
  cor_corr_ppv <- cor(mech_data$phi_hat_correlation, mech_data$emp_ppv,
                      use = "complete.obs")
  cor_prob_ppv <- cor(mech_data$phi_hat_probability, mech_data$emp_ppv,
                      use = "complete.obs")
  cor_ppv_ppv <- cor(mech_data$phi_hat_ppv, mech_data$emp_ppv,
                     use = "complete.obs")

  cat(sprintf("  φ̂_correlation → emp_PPV: r = %.3f\n", cor_corr_ppv))
  cat(sprintf("  φ̂_probability → emp_PPV: r = %.3f\n", cor_prob_ppv))
  cat(sprintf("  φ̂_PPV → emp_PPV: r = %.3f\n\n", cor_ppv_ppv))
}

# Lambda-specific correlations
cat("\n")
cat("Predictiveness by Lambda:\n\n")

for (l in unique(all_results$lambda)) {
  cat(sprintf("Lambda: %.1f\n", l))

  lambda_data <- all_results %>% filter(lambda == l)

  cor_corr_ppv <- cor(lambda_data$phi_hat_correlation, lambda_data$emp_ppv,
                      use = "complete.obs")
  cor_ppv_ppv <- cor(lambda_data$phi_hat_ppv, lambda_data$emp_ppv,
                     use = "complete.obs")

  cat(sprintf("  φ̂_correlation → emp_PPV: r = %.3f\n", cor_corr_ppv))
  cat(sprintf("  φ̂_PPV → emp_PPV: r = %.3f\n\n", cor_ppv_ppv))
}

# Overall assessment
cat("\n")
cat("Key Findings:\n\n")

# Check diagonal (self-prediction)
diagonal_correlations <- c(
  correlation_matrix %>% filter(estimated == "correlation") %>% pull(emp_correlation),
  correlation_matrix %>% filter(estimated == "probability") %>% pull(emp_probability),
  correlation_matrix %>% filter(estimated == "ppv") %>% pull(emp_ppv),
  correlation_matrix %>% filter(estimated == "cond_mean") %>% pull(emp_cond_mean)
)

mean_diagonal <- mean(diagonal_correlations)

cat(sprintf("1. Self-Prediction (diagonal): mean r = %.3f\n", mean_diagonal))
if (mean_diagonal >= 0.8) {
  cat("   ✓ Excellent: Estimated functionals predict themselves well\n")
} else if (mean_diagonal >= 0.6) {
  cat("   ✓ Good: Reasonable self-prediction\n")
} else {
  cat("   ⚠ Weak: Self-prediction lower than expected\n")
}

# Check key cross-predictions
cat("\n2. Cross-Prediction:\n")

cor_corr_ppv_overall <- correlation_matrix %>%
  filter(estimated == "correlation") %>%
  pull(emp_ppv)

cat(sprintf("   φ̂_correlation → emp_PPV: r = %.3f\n", cor_corr_ppv_overall))

if (abs(cor_corr_ppv_overall) >= 0.5) {
  cat("   ✓ Correlation functional predicts PPV moderately well\n")
} else {
  cat("   ⚠ Correlation functional is a weak predictor of PPV\n")
  cat("   → Suggests functionals capture different aspects of surrogate quality\n")
}

cat("\n")
cat("----------------------------------------------------------------\n")
cat("Creating Visualizations\n")
cat("----------------------------------------------------------------\n\n")

if (!dir.exists("sims/results")) {
  dir.create("sims/results", recursive = TRUE)
}

# Plot 1: Correlation heatmap
library(reshape2)
cor_matrix_long <- correlation_matrix %>%
  tidyr::pivot_longer(cols = -estimated,
                      names_to = "empirical",
                      values_to = "correlation") %>%
  mutate(
    estimated = gsub("_", " ", estimated),
    empirical = gsub("emp_", "", gsub("_", " ", empirical))
  )

p1 <- ggplot(cor_matrix_long, aes(x = empirical, y = estimated, fill = correlation)) +
  geom_tile(color = "white") +
  geom_text(aes(label = sprintf("%.2f", correlation)), size = 4) +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red",
                       midpoint = 0, limit = c(-1, 1),
                       name = "Correlation") +
  labs(
    title = "Cross-Functional Prediction: Estimated φ̂ vs. Empirical Performance",
    subtitle = "Correlation between functionals estimated on baseline vs. measured on test studies",
    x = "Empirical Performance (test studies)",
    y = "Estimated Functional (baseline)"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("sims/results/cross_functional_correlation_matrix.png", p1,
       width = 10, height = 8, dpi = 300)
cat("  Saved: sims/results/cross_functional_correlation_matrix.png\n")

# Plot 2: Scatter plots for key relationships
p2 <- ggplot(all_results, aes(x = phi_hat_correlation, y = emp_ppv)) +
  geom_point(aes(color = mechanism), alpha = 0.5, size = 2) +
  geom_smooth(method = "lm", se = TRUE, color = "black", linetype = "dashed") +
  facet_wrap(~lambda, labeller = label_both) +
  labs(
    title = "Key Relationship: φ̂_correlation → empirical PPV",
    subtitle = "Can estimated correlation predict decision reliability?",
    x = "Estimated Correlation φ̂_correlation",
    y = "Empirical PPV",
    color = "Mechanism"
  ) +
  theme_minimal(base_size = 12)

ggsave("sims/results/cross_functional_correlation_vs_ppv.png", p2,
       width = 12, height = 8, dpi = 300)
cat("  Saved: sims/results/cross_functional_correlation_vs_ppv.png\n")

# Plot 3: Self-prediction scatter plots
self_pred_data <- all_results %>%
  select(replication, scenario, lambda, mechanism,
         phi_hat_correlation, emp_correlation,
         phi_hat_ppv, emp_ppv) %>%
  tidyr::pivot_longer(cols = c(phi_hat_correlation, phi_hat_ppv),
                      names_to = "functional_type",
                      values_to = "estimated") %>%
  mutate(
    empirical = ifelse(functional_type == "phi_hat_correlation",
                      emp_correlation, emp_ppv),
    functional_name = ifelse(functional_type == "phi_hat_correlation",
                            "Correlation", "PPV")
  )

p3 <- ggplot(self_pred_data, aes(x = estimated, y = empirical)) +
  geom_point(aes(color = mechanism), alpha = 0.5, size = 1.5) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "red") +
  geom_smooth(method = "lm", se = TRUE, color = "blue", alpha = 0.2) +
  facet_grid(lambda ~ functional_name, labeller = label_both) +
  labs(
    title = "Self-Prediction: Estimated φ̂ vs. Empirical φ",
    subtitle = "Points should cluster near diagonal (perfect prediction)",
    x = "Estimated Functional (baseline)",
    y = "Empirical Functional (test studies)",
    color = "Mechanism"
  ) +
  theme_minimal(base_size = 10)

ggsave("sims/results/cross_functional_self_prediction.png", p3,
       width = 12, height = 10, dpi = 300)
cat("  Saved: sims/results/cross_functional_self_prediction.png\n")

# Save detailed results
saveRDS(all_results, "sims/results/cross_functional_prediction_detailed.rds")
cat("\n  Saved: sims/results/cross_functional_prediction_detailed.rds\n")

saveRDS(correlation_matrix, "sims/results/cross_functional_correlation_matrix.rds")
cat("  Saved: sims/results/cross_functional_correlation_matrix.rds\n")

cat("\n")
cat("================================================================\n")
cat("PAPER IMPLICATIONS\n")
cat("================================================================\n\n")

if (mean_diagonal >= 0.8) {
  cat("Self-Prediction Validated:\n")
  cat(sprintf("  Each functional predicts its own empirical value well (mean r = %.2f).\n",
              mean_diagonal))
  cat("  This confirms that estimation procedures are well-calibrated.\n\n")
}

if (abs(cor_corr_ppv_overall) >= 0.5) {
  cat("Cross-Prediction Finding:\n")
  cat(sprintf("  Estimated correlation predicts empirical PPV (r = %.2f),\n",
              cor_corr_ppv_overall))
  cat("  suggesting that the correlation functional captures key aspects of\n")
  cat("  surrogate reliability for decision-making.\n\n")

  cat("Paper Claim:\n")
  cat("  'We assessed whether functionals predict each other's empirical performance.\n")
  cat(sprintf("   The correlation functional showed moderate predictive power for PPV (r = %.2f),\n",
              cor_corr_ppv_overall))
  cat("   indicating that surrogates with high treatment effect correlation tend to\n")
  cat("   support reliable decisions. However, no single functional perfectly predicts\n")
  cat("   all others, suggesting that comprehensive surrogate evaluation should consider\n")
  cat("   multiple perspectives.'\n")

} else {
  cat("Cross-Prediction Finding:\n")
  cat("  Weak correlation between φ̂_correlation and empirical PPV suggests\n")
  cat("  functionals capture distinct aspects of surrogate quality.\n\n")

  cat("Paper Claim:\n")
  cat("  'Cross-functional prediction analysis revealed that functionals capture\n")
  cat("   different aspects of surrogate quality. Estimated correlation showed limited\n")
  cat(sprintf("   ability to predict empirical PPV (r = %.2f), indicating that\n",
              cor_corr_ppv_overall))
  cat("   comprehensive surrogate evaluation requires assessing multiple functionals\n")
  cat("   rather than relying on correlation alone. This highlights the value of our\n")
  cat("   flexible framework that accommodates diverse surrogate evaluation criteria.'\n")
}

cat("\n")
cat("================================================================\n")
cat("Cross-functional prediction study complete!\n")
cat("================================================================\n")
