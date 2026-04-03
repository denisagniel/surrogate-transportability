#!/usr/bin/env Rscript

#' Minimax Validation: All Functionals
#'
#' Research Questions:
#' 1. Do minimax bounds [φ_*, φ*] contain TRUE φ(F_λ^μ) for ALL μ ∈ M?
#' 2. How does bound width vary by functional?
#' 3. Which functionals are most sensitive to μ?
#'
#' This extends script 13 (correlation only) to test ALL four functionals:
#'   - Correlation
#'   - Probability (ε_S = 0, ε_Y = 0)
#'   - Conditional mean (δ_S = 0.5)
#'   - PPV (ε_S = 0, ε_Y = 0)
#'
#' Expected Result: 100% coverage by construction (minimax guarantee)

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
N_REPLICATIONS <- 50  # Balance speed and power
N_TRUE_STUDIES <- 2000
N_INNOVATIONS <- 1000
CONFIDENCE_LEVEL <- 0.95

# Minimax parameters
N_DIRICHLET_GRID <- 20
INCLUDE_VERTICES <- TRUE
MAX_VERTICES <- 30

# Test scenarios
scenarios <- tibble::tibble(
  name = c("Small λ=0.1", "Moderate λ=0.3", "Large λ=0.5"),
  lambda = c(0.1, 0.3, 0.5)
)

# Functionals to test
functionals <- list(
  correlation = list(name = "Correlation", type = "correlation",
                    params = list()),
  probability = list(name = "Probability", type = "probability",
                    params = list(epsilon_s = 0, epsilon_y = 0)),
  conditional_mean = list(name = "Conditional Mean", type = "conditional_mean",
                         params = list(delta_s_value = 0.5)),
  ppv = list(name = "PPV", type = "ppv",
            params = list(epsilon_s = 0, epsilon_y = 0))
)

# Test μ values (Dirichlet concentrations to test coverage)
test_mu_alphas <- c(0.01, 0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 100.0)

cat("================================================================\n")
cat("MINIMAX VALIDATION: ALL FUNCTIONALS\n")
cat("================================================================\n\n")

cat("Research Questions:\n")
cat("  1. Do minimax bounds contain TRUE φ for ALL μ ∈ M?\n")
cat("  2. How does bound width vary by functional?\n")
cat("  3. Which functionals are most μ-sensitive?\n\n")

cat("Parameters:\n")
cat(sprintf("  Baseline n: %d\n", N_BASELINE))
cat(sprintf("  Replications per (λ, functional): %d\n", N_REPLICATIONS))
cat(sprintf("  Studies for TRUE φ(F_λ^μ): %d\n", N_TRUE_STUDIES))
cat(sprintf("  Innovations (M) for methods: %d\n", N_INNOVATIONS))

cat("\n")
cat("Minimax Class M:\n")
cat(sprintf("  Dirichlet(α) grid: %d points\n", N_DIRICHLET_GRID))
cat(sprintf("  Vertices included: %s (max %d)\n",
            ifelse(INCLUDE_VERTICES, "YES", "NO"), MAX_VERTICES))

cat("\n")
cat("Test μ values (Dirichlet concentrations):\n")
cat("  α =", paste(test_mu_alphas, collapse = ", "), "\n")

cat("\n")
cat("Functionals:\n")
for (func_name in names(functionals)) {
  func <- functionals[[func_name]]
  cat(sprintf("  - %s\n", func$name))
}

cat("\n")
cat("----------------------------------------------------------------\n")
cat("Running Validation Study\n")
cat("----------------------------------------------------------------\n\n")

start_time <- Sys.time()

all_results <- tibble::tibble()

total_combinations <- nrow(scenarios) * length(functionals) * N_REPLICATIONS
combination <- 0

for (s in 1:nrow(scenarios)) {
  scenario <- scenarios[s, ]
  lambda <- scenario$lambda

  for (func_name in names(functionals)) {
    func <- functionals[[func_name]]

    cat(sprintf("Scenario: %s, Functional: %s\n", scenario$name, func$name))

    for (rep in 1:N_REPLICATIONS) {
      combination <- combination + 1

      if (rep %% 10 == 0 || rep == 1) {
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

      # Compute minimax bounds for this functional
      minimax_result <- tryCatch({
        do.call(surrogate_inference_minimax, c(
          list(
            current_data = baseline,
            lambda = lambda,
            functional_type = func$type,
            n_dirichlet_grid = N_DIRICHLET_GRID,
            include_vertices = INCLUDE_VERTICES,
            max_vertices = MAX_VERTICES,
            n_innovations = N_INNOVATIONS,
            n_bootstrap = 0,
            parallel = FALSE,
            verbose = FALSE
          ),
          func$params
        ))
      }, error = function(e) {
        warning(sprintf("Minimax error in rep %d: %s", rep, e$message))
        return(NULL)
      })

      if (is.null(minimax_result)) next

      # For each test μ: compute TRUE φ(F_λ^μ) and check containment
      for (test_alpha in test_mu_alphas) {

        # Compute TRUE φ(F_λ^μ) using this test μ
        n <- nrow(baseline)

        # Draw M innovations from Dirichlet(test_alpha, ..., test_alpha)
        innovations <- MCMCpack::rdirichlet(N_TRUE_STUDIES, rep(test_alpha, n))

        # Compute treatment effects
        true_effects <- matrix(NA, nrow = N_TRUE_STUDIES, ncol = 2)

        for (m in 1:N_TRUE_STUDIES) {
          p0_weights <- rep(1/n, n)
          p_tilde <- innovations[m, ]
          q_weights <- (1 - lambda) * p0_weights + lambda * p_tilde

          delta_s <- compute_treatment_effect_weighted(baseline, "S", q_weights)
          delta_y <- compute_treatment_effect_weighted(baseline, "Y", q_weights)

          true_effects[m, ] <- c(delta_s, delta_y)
        }

        # Compute functional from treatment effects
        true_phi <- switch(func$type,
          "correlation" = cor(true_effects[, 1], true_effects[, 2]),

          "probability" = {
            exceed_s <- true_effects[, 1] > func$params$epsilon_s
            if (sum(exceed_s) == 0) {
              NA_real_
            } else {
              sum(true_effects[, 1] > func$params$epsilon_s &
                  true_effects[, 2] > func$params$epsilon_y) / sum(exceed_s)
            }
          },

          "conditional_mean" = {
            delta_s_all <- true_effects[, 1]
            delta_y_all <- true_effects[, 2]
            bandwidth <- 1.06 * sd(delta_s_all) * length(delta_s_all)^(-1/5)
            kernel_weights <- dnorm((delta_s_all - func$params$delta_s_value) / bandwidth)

            if (sum(kernel_weights) == 0) {
              NA_real_
            } else {
              sum(kernel_weights * delta_y_all) / sum(kernel_weights)
            }
          },

          "ppv" = {
            exceed_s <- true_effects[, 1] > func$params$epsilon_s
            if (sum(exceed_s) == 0) {
              NA_real_
            } else {
              sum(true_effects[, 1] > func$params$epsilon_s &
                  true_effects[, 2] > func$params$epsilon_y) / sum(exceed_s)
            }
          }
        )

        if (is.na(true_phi)) next

        # Check: does [φ_*, φ*] contain true_phi?
        contained <- (minimax_result$phi_star_lower <= true_phi) &&
                     (true_phi <= minimax_result$phi_star)

        # Store results (capture values to avoid scoping issues)
        scenario_name_val <- scenario$name
        func_name_val <- func$name
        func_type_val <- func$type

        all_results <- rbind(all_results, tibble::tibble(
          replication = rep,
          scenario = scenario_name_val,
          lambda = lambda,
          functional = func_name_val,
          functional_type = func_type_val,
          test_mu_alpha = test_alpha,
          true_phi = true_phi,
          minimax_lower = minimax_result$phi_star_lower,
          minimax_upper = minimax_result$phi_star,
          minimax_width = minimax_result$bound_width,
          contained = contained
        ))
      }
    }
    cat("\n")
  }
}

cat("================================================================\n")
cat("RESULTS\n")
cat("================================================================\n\n")

# Coverage rates by functional and lambda
coverage_summary <- all_results %>%
  group_by(functional, lambda) %>%
  summarise(
    n_tests = n(),
    coverage = mean(contained),
    mean_width = mean(minimax_width),
    mean_phi = mean(true_phi),
    .groups = "drop"
  ) %>%
  arrange(lambda, functional)

cat("Minimax Coverage by Functional and Lambda:\n\n")
cat(sprintf("%-20s %-6s %-10s %-15s %-15s %-10s\n",
            "Functional", "λ", "Coverage", "Mean Width", "Mean φ", "Status"))
cat(strrep("-", 85), "\n")

for (i in 1:nrow(coverage_summary)) {
  row <- coverage_summary[i, ]

  # Status: should be 100% (or very close) by construction
  status <- if (row$coverage >= 0.99) {
    "✓✓"
  } else if (row$coverage >= 0.95) {
    "✓~"
  } else {
    "✗✗"
  }

  cat(sprintf("%-20s %5.2f %9.1f%% %14.4f %14.3f %10s\n",
              row$functional,
              row$lambda,
              row$coverage * 100,
              row$mean_width,
              row$mean_phi,
              status))
}

cat("\n")
cat("Status: ✓✓ = near-perfect (≥99%); ✓~ = nominal (≥95%); ✗✗ = failure\n")

# Overall statistics
cat("\n")
cat("Overall Statistics:\n\n")
cat(sprintf("  Mean coverage across all functionals: %.1f%%\n",
            mean(all_results$contained) * 100))
cat(sprintf("  Number of coverage failures: %d / %d tests\n",
            sum(!all_results$contained), nrow(all_results)))

# Coverage by μ (test alpha)
cat("\n")
cat("Coverage by Test μ (Dirichlet concentration):\n\n")

coverage_by_mu <- all_results %>%
  group_by(test_mu_alpha) %>%
  summarise(
    coverage = mean(contained),
    n = n(),
    .groups = "drop"
  ) %>%
  arrange(test_mu_alpha)

for (i in 1:nrow(coverage_by_mu)) {
  row <- coverage_by_mu[i, ]
  cat(sprintf("  α = %6.2f: %.1f%% coverage (n=%d)\n",
              row$test_mu_alpha, row$coverage * 100, row$n))
}

# Width comparison across functionals
cat("\n")
cat("Minimax Bound Width by Functional:\n\n")

width_by_functional <- all_results %>%
  group_by(functional) %>%
  summarise(
    mean_width = mean(minimax_width),
    median_width = median(minimax_width),
    max_width = max(minimax_width),
    .groups = "drop"
  ) %>%
  arrange(mean_width)

cat(sprintf("%-20s %-15s %-15s %-15s\n",
            "Functional", "Mean Width", "Median Width", "Max Width"))
cat(strrep("-", 70), "\n")

for (i in 1:nrow(width_by_functional)) {
  row <- width_by_functional[i, ]
  cat(sprintf("%-20s %14.4f %14.4f %14.4f\n",
              row$functional,
              row$mean_width,
              row$median_width,
              row$max_width))
}

cat("\n")
cat("Interpretation:\n")

overall_coverage <- mean(all_results$contained)

if (overall_coverage >= 0.99) {
  cat("✓ EXCELLENT: Near-perfect coverage (≥99%) across all functionals\n")
  cat("  → Minimax bounds hold as theoretically guaranteed\n")
} else if (overall_coverage >= 0.95) {
  cat("✓ GOOD: Nominal coverage (≥95%) across functionals\n")
  cat("  → Bounds provide robust inference\n")
} else {
  cat("✗ ISSUE: Coverage below 95%\n")
  cat("  → May need broader class M or finer grid\n")
}

cat("\n")

# Check which functional has narrowest/widest bounds
narrowest <- width_by_functional %>% slice(1)
widest <- width_by_functional %>% slice(n())

cat(sprintf("Narrowest bounds: %s (width = %.4f)\n",
            narrowest$functional, narrowest$mean_width))
cat(sprintf("Widest bounds: %s (width = %.4f)\n",
            widest$functional, widest$mean_width))

cat("\n")
cat("----------------------------------------------------------------\n")
cat("Creating Visualizations\n")
cat("----------------------------------------------------------------\n\n")

if (!dir.exists("sims/results")) {
  dir.create("sims/results", recursive = TRUE)
}

# Plot 1: Coverage by functional and lambda
p1 <- ggplot(coverage_summary, aes(x = functional, y = coverage, fill = factor(lambda))) +
  geom_col(position = "dodge", alpha = 0.8) +
  geom_hline(yintercept = 1.0, linetype = "dashed", color = "red") +
  geom_hline(yintercept = 0.95, linetype = "dotted", color = "orange") +
  geom_text(aes(label = sprintf("%.1f%%", coverage * 100)),
            position = position_dodge(width = 0.9),
            vjust = -0.5, size = 3) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1.05)) +
  scale_fill_brewer(palette = "Set2", name = "λ") +
  labs(
    title = "Minimax Coverage by Functional",
    subtitle = sprintf("Target: 100%% (red line) | N=%d reps per (λ, functional)", N_REPLICATIONS),
    x = "Functional",
    y = "Coverage Rate"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom")

ggsave("sims/results/minimax_all_functionals_coverage.png", p1,
       width = 10, height = 6, dpi = 300)
cat("  Saved: sims/results/minimax_all_functionals_coverage.png\n")

# Plot 2: Bound width comparison
p2 <- ggplot(all_results, aes(x = functional, y = minimax_width, fill = functional)) +
  geom_violin(alpha = 0.6) +
  geom_boxplot(width = 0.2, alpha = 0.8) +
  facet_wrap(~lambda, labeller = label_both) +
  labs(
    title = "Minimax Bound Width by Functional",
    subtitle = "Distribution across replications and test μ values",
    x = "Functional",
    y = "Bound Width [φ* - φ_*]"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "none")

ggsave("sims/results/minimax_all_functionals_width.png", p2,
       width = 12, height = 8, dpi = 300)
cat("  Saved: sims/results/minimax_all_functionals_width.png\n")

# Plot 3: True φ vs bounds (sample)
sample_results <- all_results %>%
  filter(lambda == 0.3, replication <= 10) %>%
  mutate(rep_id = interaction(replication, test_mu_alpha))

p3 <- ggplot(sample_results) +
  geom_point(aes(x = rep_id, y = true_phi, color = contained), size = 2) +
  geom_errorbar(aes(x = rep_id, ymin = minimax_lower, ymax = minimax_upper),
                alpha = 0.3, width = 0.5) +
  facet_wrap(~functional, scales = "free_y") +
  scale_color_manual(values = c("TRUE" = "blue", "FALSE" = "red"),
                     labels = c("TRUE" = "Contained", "FALSE" = "Missed")) +
  labs(
    title = "True φ(F_λ^μ) vs. Minimax Bounds (λ=0.3, Sample)",
    subtitle = "Points: true φ for different μ; Bars: minimax bounds [φ_*, φ*]",
    x = "Replication × Test μ",
    y = "Functional Value",
    color = "Contained?"
  ) +
  theme_minimal(base_size = 10) +
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank())

ggsave("sims/results/minimax_all_functionals_containment.png", p3,
       width = 12, height = 8, dpi = 300)
cat("  Saved: sims/results/minimax_all_functionals_containment.png\n")

# Save detailed results
saveRDS(all_results, "sims/results/minimax_all_functionals_detailed.rds")
cat("\n  Saved: sims/results/minimax_all_functionals_detailed.rds\n")

saveRDS(coverage_summary, "sims/results/minimax_all_functionals_summary.rds")
cat("  Saved: sims/results/minimax_all_functionals_summary.rds\n")

cat("\n")
cat("================================================================\n")
cat("PAPER IMPLICATIONS\n")
cat("================================================================\n\n")

if (overall_coverage >= 0.99) {
  cat("Key Finding:\n")
  cat(sprintf("  Minimax bounds achieve %.1f%% coverage across ALL four\n",
              overall_coverage * 100))
  cat("  functionals and all test μ values, validating the theoretical\n")
  cat("  guarantee. This demonstrates that:\n")
  cat("    (1) The class M is sufficiently rich\n")
  cat("    (2) The search algorithm finds extrema reliably\n")
  cat("    (3) The minimax approach extends universally to all functionals\n\n")

  cat("Width Findings:\n")
  cat(sprintf("  - Narrowest bounds: %s (%.4f)\n",
              narrowest$functional, narrowest$mean_width))
  cat(sprintf("  - Widest bounds: %s (%.4f)\n",
              widest$functional, widest$mean_width))
  cat("  This shows which functionals are most/least sensitive to μ.\n\n")

  cat("Paper Claim:\n")
  cat("  'We validated minimax inference across all four surrogate functionals.\n")
  cat(sprintf("   Across %d baseline studies, 3 λ values, and 8 test μ distributions,\n",
              N_REPLICATIONS * nrow(scenarios) * length(functionals)))
  cat(sprintf("   minimax bounds contained the true functional value in %.1f%% of cases,\n",
              overall_coverage * 100))
  cat("   confirming the universal applicability of the minimax approach. Bound\n")
  cat(sprintf("   width varied from %.3f (%s) to %.3f (%s), reflecting\n",
              narrowest$mean_width, narrowest$functional,
              widest$mean_width, widest$functional))
  cat("   the sensitivity of different functionals to innovation distribution μ.'\n")

} else if (overall_coverage >= 0.95) {
  cat("Finding:\n")
  cat("  Minimax bounds achieve nominal coverage with acceptable width.\n")
  cat("  Some edge cases may require investigation.\n")
} else {
  cat("Finding:\n")
  cat("  Coverage below target. Action items:\n")
  cat("    - Increase n_dirichlet_grid for finer search\n")
  cat("    - Expand alpha range or add more vertices\n")
  cat("    - Investigate which (functional, μ) combinations fail\n")
}

cat("\n")
cat("================================================================\n")
cat("Minimax validation (all functionals) complete!\n")
cat("================================================================\n")
