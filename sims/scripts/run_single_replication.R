#!/usr/bin/env Rscript

#' Run a single validation replication
#' Designed for SLURM array jobs where each task runs one rep

library(devtools)
library(dplyr)
library(tibble)
library(optparse)

# Parse command-line arguments
option_list <- list(
  make_option(c("-s", "--scenario"), type = "character", default = NULL,
              help = "Scenario name (e.g., 'covariate_shift_small')", metavar = "character"),
  make_option(c("-r", "--replication"), type = "integer", default = 1,
              help = "Replication number [default %default]", metavar = "number"),
  make_option(c("-o", "--output-dir"), type = "character", default = "sims/results/reps",
              help = "Output directory for individual replication results", metavar = "path"),
  make_option(c("-t", "--study-type"), type = "character", default = "covariate_shift",
              help = "Study type: covariate_shift, selection_bias, or dirichlet_misspec", metavar = "character"),
  make_option(c("--n-baseline"), type = "integer", default = 1000,
              help = "Baseline sample size", metavar = "number"),
  make_option(c("--n-true-studies"), type = "integer", default = 500,
              help = "Number of studies for computing TRUE phi", metavar = "number"),
  make_option(c("--n-baseline-resamples"), type = "integer", default = 100,
              help = "Number of baseline resamples for nested bootstrap", metavar = "number"),
  make_option(c("--n-bootstrap"), type = "integer", default = 100,
              help = "Number of bootstrap draws from F_lambda", metavar = "number"),
  make_option(c("--n-mc-draws"), type = "integer", default = 50,
              help = "Number of MC draws per bootstrap", metavar = "number"),
  make_option(c("--seed"), type = "integer", default = NULL,
              help = "Random seed (if NULL, uses replication number)", metavar = "number")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# Validate inputs
if (is.null(opt$scenario)) {
  stop("Must specify --scenario")
}

# Load package
devtools::load_all("package/", quiet = TRUE)

# Set seed
if (is.null(opt$seed)) {
  set.seed(20260313 + opt$replication)
} else {
  set.seed(opt$seed)
}

# Define scenario configurations
COVARIATE_SHIFT_SCENARIOS <- list(
  small = list(name = "Small Shift (60/40)", target_probs = c(0.6, 0.4)),
  moderate = list(name = "Moderate Shift (70/30)", target_probs = c(0.7, 0.3)),
  large = list(name = "Large Shift (80/20)", target_probs = c(0.8, 0.2)),
  extreme = list(name = "Extreme Shift (90/10)", target_probs = c(0.9, 0.1))
)

SELECTION_SCENARIOS <- list(
  weak_outcome = list(name = "Weak Outcome-Favorable", type = "outcome_favorable", strength = 0.3),
  moderate_outcome = list(name = "Moderate Outcome-Favorable", type = "outcome_favorable", strength = 0.6),
  strong_outcome = list(name = "Strong Outcome-Favorable", type = "outcome_favorable", strength = 0.9),
  moderate_responders = list(name = "Moderate Treatment-Responders", type = "treatment_responders", strength = 0.6)
)

DIRICHLET_SCENARIOS <- list(
  very_sparse = list(name = "Very Sparse (α=0.1)", alpha = 0.1),
  sparse = list(name = "Sparse (α=0.5)", alpha = 0.5),
  uniform = list(name = "Uniform (α=1.0)", alpha = 1.0),
  concentrated = list(name = "Concentrated (α=2.0)", alpha = 2.0),
  highly_concentrated = list(name = "Highly Concentrated (α=5.0)", alpha = 5.0),
  very_concentrated = list(name = "Very Concentrated (α=10.0)", alpha = 10.0)
)

# Get scenario configuration
if (opt$`study-type` == "covariate_shift") {
  scenario_config <- COVARIATE_SHIFT_SCENARIOS[[opt$scenario]]
} else if (opt$`study-type` == "selection_bias") {
  scenario_config <- SELECTION_SCENARIOS[[opt$scenario]]
} else if (opt$`study-type` == "dirichlet_misspec") {
  scenario_config <- DIRICHLET_SCENARIOS[[opt$scenario]]
} else {
  stop("Unknown study-type: ", opt$`study-type`)
}

if (is.null(scenario_config)) {
  stop("Unknown scenario: ", opt$scenario)
}

cat(sprintf("Replication %d: %s\n", opt$replication, scenario_config$name))

# Generate baseline
baseline <- generate_study_data(
  n = opt$`n-baseline`,
  n_classes = 2,
  class_probs = c(0.5, 0.5),
  treatment_effect_surrogate = c(0.3, 0.9),
  treatment_effect_outcome = c(0.2, 0.8),
  surrogate_type = "continuous",
  outcome_type = "continuous"
)

# Generate future study and compute TRUE correlation
if (opt$`study-type` == "covariate_shift") {
  # Covariate shift
  shifted_study <- generate_covariate_shift_study(
    baseline,
    target_class_probs = scenario_config$target_probs,
    n = opt$`n-baseline`
  )

  multiple_futures <- replicate(opt$`n-true-studies`, {
    future <- generate_covariate_shift_study(
      baseline,
      target_class_probs = scenario_config$target_probs,
      n = opt$`n-baseline`
    )
    effects <- compute_multiple_treatment_effects(future$future_study, c("S", "Y"))
    c(delta_s = effects["S"], delta_y = effects["Y"])
  }, simplify = FALSE)

  lambda_empirical <- shifted_study$tv_distance

} else if (opt$`study-type` == "selection_bias") {
  # Selection bias
  selected_study <- generate_selection_study(
    baseline,
    selection_type = scenario_config$type,
    selection_strength = scenario_config$strength,
    n = opt$`n-baseline`
  )

  multiple_futures <- replicate(opt$`n-true-studies`, {
    future <- generate_selection_study(
      baseline,
      selection_type = scenario_config$type,
      selection_strength = scenario_config$strength,
      n = opt$`n-baseline`
    )
    effects <- compute_multiple_treatment_effects(future$future_study, c("S", "Y"))
    c(delta_s = effects["S"], delta_y = effects["Y"])
  }, simplify = FALSE)

  lambda_empirical <- selected_study$tv_distance_estimate

} else if (opt$`study-type` == "dirichlet_misspec") {
  # Dirichlet misspecification
  # For this, lambda is fixed (will need to add as parameter)
  lambda_empirical <- 0.2  # Default

  multiple_futures <- replicate(opt$`n-true-studies`, {
    future <- generate_future_study(
      baseline,
      lambda = lambda_empirical,
      innovation_type = "bayesian_bootstrap",
      alpha = scenario_config$alpha
    )
    effects <- compute_multiple_treatment_effects(future, c("S", "Y"))
    c(delta_s = effects["S"], delta_y = effects["Y"])
  }, simplify = FALSE)
}

# Compute TRUE correlation
future_effects_df <- do.call(rbind, multiple_futures) %>% as.data.frame()
true_correlation <- cor(future_effects_df$delta_s, future_effects_df$delta_y)

# Apply method with nested bootstrap
method_result <- posterior_inference(
  baseline,
  n_draws_from_F = opt$`n-bootstrap`,
  n_future_studies_per_draw = opt$`n-mc-draws`,
  n_baseline_resamples = opt$`n-baseline-resamples`,
  lambda = lambda_empirical,
  functional_type = "correlation",
  innovation_type = "bayesian_bootstrap",
  parallel = FALSE  # No inner parallelization for SLURM
)

# Compile results
result <- list(
  replication = opt$replication,
  scenario = opt$scenario,
  scenario_name = scenario_config$name,
  study_type = opt$`study-type`,
  lambda = lambda_empirical,
  true_correlation = true_correlation,
  method_estimate = method_result$summary$mean,
  method_se = method_result$summary$se,
  method_ci_lower = method_result$summary$ci_lower,
  method_ci_upper = method_result$summary$ci_upper,
  method_q025 = as.numeric(method_result$summary$q025),
  method_q975 = as.numeric(method_result$summary$q975),
  covered_ci = (true_correlation >= method_result$summary$ci_lower) &&
               (true_correlation <= method_result$summary$ci_upper),
  covered_quantile = (true_correlation >= method_result$summary$q025) &&
                     (true_correlation <= method_result$summary$q975),
  parameters = list(
    n_baseline = opt$`n-baseline`,
    n_true_studies = opt$`n-true-studies`,
    n_baseline_resamples = opt$`n-baseline-resamples`,
    n_bootstrap = opt$`n-bootstrap`,
    n_mc_draws = opt$`n-mc-draws`
  )
)

# Save result
if (!dir.exists(opt$`output-dir`)) {
  dir.create(opt$`output-dir`, recursive = TRUE)
}

output_file <- file.path(
  opt$`output-dir`,
  sprintf("%s_%s_rep%04d.rds", opt$`study-type`, opt$scenario, opt$replication)
)

saveRDS(result, output_file)

cat(sprintf("Saved to: %s\n", output_file))
cat(sprintf("TRUE φ = %.3f, METHOD φ = %.3f [%.3f, %.3f], Covered: %s\n",
            true_correlation,
            method_result$summary$mean,
            method_result$summary$ci_lower,
            method_result$summary$ci_upper,
            ifelse(result$covered_ci, "YES", "NO")))
