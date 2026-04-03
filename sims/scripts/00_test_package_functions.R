#' Test Package Functions
#'
#' Quick validation that all required package functions work correctly
#' before running simulations.

library(tidyverse)
library(here)

# Load package
cat("Loading package...\n")
devtools::load_all(here("package"))

cat("\n=== Testing DGP Generators ===\n")

# Test DGP generators
source(here("sims/scripts/utils/create_dgps.R"))

# Generate all four scenarios
cat("Generating four classification scenarios...\n")
scenarios <- generate_all_classification_scenarios(n = 500, J = 16, seed = 123)

# Verify properties
cat("\nVerifying scenario properties...\n")
verification <- verify_scenario_properties(scenarios)
print(verification)

if (!all(verification[, grepl("_ok$", names(verification))])) {
  stop("Some scenarios failed verification!")
}

cat("\nAll scenarios passed verification ✓\n")

# Print diagnostics
for (name in names(scenarios)) {
  print_scenario_diagnostics(scenarios[[name]])
}

cat("\n=== Testing Traditional Methods ===\n")

# Test traditional methods on one scenario
data <- scenarios$true_positive$data

cat("Computing PTE...\n")
pte <- compute_pte(data)
cat(sprintf("  PTE = %.3f\n", pte))

cat("Computing within-study correlation...\n")
cor_within <- compute_within_study_correlation(data)
cat(sprintf("  Within-study correlation = %.3f\n", cor_within))

cat("Computing mediation effects...\n")
mediation <- compute_mediation_effects(data)
cat(sprintf("  Proportion mediated = %.3f\n", mediation$proportion_mediated))

cat("\nTraditional methods working ✓\n")

cat("\n=== Testing Minimax Functions ===\n")

# Generate type-level effects
type_effects <- data %>%
  group_by(type) %>%
  summarize(
    tau_s = mean(S[A == 1]) - mean(S[A == 0]),
    tau_y = mean(Y[A == 1]) - mean(Y[A == 0]),
    n = n(),
    .groups = "drop"
  )

pi_hat <- as.numeric(table(data$type) / nrow(data))

cat("Testing TV-ball minimax (closed-form)...\n")
tv_result <- minimax_concordance_tv_ball(
  tau_s = type_effects$tau_s,
  tau_y = type_effects$tau_y,
  pi_hat = pi_hat,
  lambda = 0.3
)
cat(sprintf("  φ* (TV-ball) = %.3f\n", tv_result$phi_star))
cat(sprintf("  φ_hat (nominal) = %.3f\n", tv_result$phi_hat))
cat(sprintf("  Method: %s\n", tv_result$method))

if (is.na(tv_result$phi_star) || !is.finite(tv_result$phi_star)) {
  stop("TV-ball minimax returned invalid result!")
}

cat("\nTV-ball minimax working ✓\n")

cat("\nTesting Wasserstein minimax (dual)...\n")
wass_result <- minimax_concordance_wasserstein_dual(
  tau_s = type_effects$tau_s,
  tau_y = type_effects$tau_y,
  pi_hat = pi_hat,
  lambda = 0.3
)
cat(sprintf("  φ* (Wasserstein) = %.3f\n", wass_result$phi_star))
cat(sprintf("  φ_hat (nominal) = %.3f\n", wass_result$phi_hat))
cat(sprintf("  Method: %s\n", wass_result$method))
cat(sprintf("  Converged: %s\n", wass_result$convergence))

if (is.na(wass_result$phi_star) || !is.finite(wass_result$phi_star)) {
  stop("Wasserstein minimax returned invalid result!")
}

cat("\nWasserstein minimax working ✓\n")

cat("\n=== Testing Bootstrap CI (small sample) ===\n")

cat("Testing minimax_inference_with_ci() with n_bootstrap = 50...\n")
ci_result <- minimax_inference_with_ci(
  data = data,
  lambda = 0.3,
  functional = "concordance",
  method = "tv_ball",
  n_bootstrap = 50,  # Small for speed
  alpha = 0.05
)

cat(sprintf("  Point estimate: %.3f\n", ci_result$phi_star))
cat(sprintf("  95%% CI: [%.3f, %.3f]\n", ci_result$ci_lower, ci_result$ci_upper))
cat(sprintf("  SE: %.3f\n", ci_result$se))

if (is.na(ci_result$ci_lower) || is.na(ci_result$ci_upper)) {
  stop("Bootstrap CI returned invalid results!")
}

cat("\nBootstrap CI working ✓\n")

cat("\n=== Testing Ground Truth Functions ===\n")

source(here("sims/scripts/utils/compute_ground_truth.R"))

# Test ground truth computation
tau_s <- scenarios$true_positive$tau_s
tau_y <- scenarios$true_positive$tau_y

cat("Computing ground truth transportability...\n")
is_transportable <- is_truly_transportable(tau_s, tau_y, threshold = 0.6)
cat(sprintf("  Is transportable: %s\n", is_transportable))

# Test classification metrics
cat("\nTesting classification metrics...\n")
ground_truth <- c(TRUE, TRUE, FALSE, FALSE)
predictions <- c(TRUE, FALSE, FALSE, TRUE)

metrics <- compute_classification_metrics(ground_truth, predictions)
cat(sprintf("  Sensitivity: %.3f\n", metrics$sensitivity))
cat(sprintf("  Specificity: %.3f\n", metrics$specificity))
cat(sprintf("  Accuracy: %.3f\n", metrics$accuracy))

cat("\nGround truth functions working ✓\n")

cat("\n=== All Tests Passed ✓ ===\n")
cat("\nReady to run simulations!\n")
cat("\nNext steps:\n")
cat("  1. Run quick validation: Rscript sims/scripts/03_classification_accuracy_quick.R\n")
cat("  2. If successful, run full simulations\n")
