#!/usr/bin/env Rscript
# Lambda Sensitivity Analysis: Single Condition Study
#
# Runs 1000 replications for one (lambda, DGP) combination
# Called by SLURM array job with lambda and DGP parameters
#
# Usage: Rscript lambda_sensitivity_study.R --lambda 0.3 --dgp dgp1 --n-reps 1000 \
#                                            --config config.yaml --output-dir results/

suppressPackageStartupMessages({
  library(optparse)
  library(yaml)
})

# =============================================================================
# Parse Arguments
# =============================================================================

option_list <- list(
  make_option(c("--lambda"), type = "double", dest = "lambda",
              help = "TV ball radius lambda", metavar = "DOUBLE"),
  make_option(c("--dgp"), type = "character", dest = "dgp_id",
              help = "DGP identifier (dgp1, dgp2, dgp4, dgp5)", metavar = "CHARACTER"),
  make_option(c("--n-reps"), type = "integer", dest = "n_reps",
              default = 1000,
              help = "Number of replications [default: %default]", metavar = "INTEGER"),
  make_option(c("--config"), type = "character", dest = "config_file",
              default = "cluster/config/dgp_specifications.yaml",
              help = "Path to YAML config [default: %default]", metavar = "FILE"),
  make_option(c("--output-dir"), type = "character", dest = "output_dir",
              help = "Output directory for results", metavar = "DIR"),
  make_option(c("--checkpoint-interval"), type = "integer", dest = "checkpoint_interval",
              default = 50,
              help = "Save checkpoint every N reps [default: %default]", metavar = "INTEGER")
)

opt <- parse_args(OptionParser(option_list = option_list))

# Validate
if (is.null(opt$lambda) || is.null(opt$dgp_id) || is.null(opt$output_dir)) {
  stop("--lambda, --dgp, and --output-dir are required")
}

cat(sprintf("\n=== Lambda Sensitivity Study ===\n"))
cat(sprintf("Lambda: %.2f\n", opt$lambda))
cat(sprintf("DGP: %s\n", opt$dgp_id))
cat(sprintf("Replications: %d\n", opt$n_reps))
cat(sprintf("Start: %s\n", Sys.time()))

# =============================================================================
# Load Package and Config
# =============================================================================

suppressMessages(library(surrogateTransportability))

config <- yaml::read_yaml(opt$config_file)
dgp_config <- config$dgps[[opt$dgp_id]]
sim_settings <- config$simulation_settings
cluster_settings <- config$cluster_settings

if (is.null(dgp_config)) {
  stop(sprintf("DGP '%s' not found in config", opt$dgp_id))
}

cat(sprintf("\nDGP: %s\n", dgp_config$name))

# Handle NaN/NA in PTE and rho_true
rho_true <- as.numeric(dgp_config$rho_true)
pte_val <- dgp_config$PTE_P0
if (is.character(pte_val) && pte_val == "NaN") {
  pte_val <- NA_real_
} else {
  pte_val <- as.numeric(pte_val)
}

# Print with proper NA handling
if (is.na(pte_val)) {
  cat(sprintf("TRUE ρ = %.4f, PTE = NA (undefined)\n", rho_true))
} else {
  cat(sprintf("TRUE ρ = %.4f, PTE = %.4f\n", rho_true, pte_val))
}

cat(sprintf("\nNote: Using lambda = %.2f (overrides config value %.2f)\n",
            opt$lambda, dgp_config$lambda))

# =============================================================================
# DGP Function
# =============================================================================

generate_dgp_data <- function(n, p_X, params, X_levels) {
  X <- sample(X_levels, size = n, replace = TRUE, prob = p_X)
  A <- rbinom(n, 1, 0.5)

  S <- (params$gamma_A + params$gamma_AX * X) * A + rnorm(n, sd = params$sigma_S)
  Y <- (params$beta_A + params$beta_AX * X) * A + params$beta_S * S +
       params$beta_SX * S * X + rnorm(n, sd = params$sigma_Y)

  data.frame(X = X, A = A, S = S, Y = Y)
}

# =============================================================================
# Run Replications with Checkpointing
# =============================================================================

dir.create(opt$output_dir, showWarnings = FALSE, recursive = TRUE)
output_file <- file.path(opt$output_dir,
                         sprintf("lambda_%.1f_%s.rds", opt$lambda, opt$dgp_id))

# Check for existing checkpoint
checkpoint_file <- file.path(opt$output_dir,
                             sprintf("lambda_%.1f_%s_checkpoint.rds",
                                    opt$lambda, opt$dgp_id))

if (file.exists(checkpoint_file)) {
  cat("\nResuming from checkpoint...\n")
  checkpoint <- readRDS(checkpoint_file)
  results_list <- checkpoint$results
  start_rep <- length(results_list) + 1
  cat(sprintf("Completed: %d/%d reps\n", length(results_list), opt$n_reps))
} else {
  results_list <- list()
  start_rep <- 1
}

study_start_time <- Sys.time()

for (rep_number in start_rep:opt$n_reps) {
  if (rep_number %% 50 == 0 || rep_number == opt$n_reps) {
    cat(sprintf("\n--- Rep %d/%d ---\n", rep_number, opt$n_reps))
  }

  # Set seed (use base 20000 to avoid overlap with main study)
  seed <- 20000 + (rep_number - 1) + opt$lambda * 10000 +
          match(opt$dgp_id, c("dgp1", "dgp2", "dgp4", "dgp5")) * 100
  set.seed(seed)

  # Generate data
  data <- generate_dgp_data(
    n = sim_settings$sample_size,
    p_X = unlist(dgp_config$p_X),
    params = dgp_config$params,
    X_levels = unlist(dgp_config$X_levels)
  )

  # Run adaptive M with specified lambda
  rep_start <- Sys.time()

  result <- tv_ball_correlation_IF_adaptive(
    data = data,
    lambda = opt$lambda,  # Use specified lambda, not config value
    M_start = sim_settings$M_start,
    M_increment = sim_settings$M_increment,
    M_max = sim_settings$M_max,
    tolerance = sim_settings$tolerance,
    n_stable = sim_settings$n_stable,
    burn_in = sim_settings$burn_in,
    thin = sim_settings$thin,
    alpha = sim_settings$alpha,
    method = sim_settings$method,
    verbose = FALSE
  )

  rep_time <- as.numeric(difftime(Sys.time(), rep_start, units = "secs"))

  # Compute PTE at P0
  p_X_0 <- unlist(dgp_config$p_X)
  X_levels <- unlist(dgp_config$X_levels)
  K <- length(X_levels)

  tau_S_hat <- numeric(K)
  tau_Y_hat <- numeric(K)

  for (k in 1:K) {
    data_k <- data[data$X == X_levels[k], ]
    if (nrow(data_k) > 0 && sum(data_k$A == 1) > 0 && sum(data_k$A == 0) > 0) {
      tau_S_hat[k] <- mean(data_k$S[data_k$A == 1]) - mean(data_k$S[data_k$A == 0])
      tau_Y_hat[k] <- mean(data_k$Y[data_k$A == 1]) - mean(data_k$Y[data_k$A == 0])
    } else {
      tau_S_hat[k] <- 0
      tau_Y_hat[k] <- 0
    }
  }

  Delta_S_P0_hat <- sum(p_X_0 * tau_S_hat)
  Delta_Y_P0_hat <- sum(p_X_0 * tau_Y_hat)
  PTE_hat <- if (abs(Delta_Y_P0_hat) > 1e-10) {
    (dgp_config$params$beta_S * Delta_S_P0_hat) / Delta_Y_P0_hat
  } else {
    NA_real_
  }

  # Store results
  results_list[[length(results_list) + 1]] <- list(
    dgp_id = opt$dgp_id,
    lambda = opt$lambda,
    rep_number = rep_number,
    seed = seed,
    rho_hat = result$rho_hat,
    se = result$se,
    ci_lower = result$ci_lower,
    ci_upper = result$ci_upper,
    converged = result$converged,
    M_final = result$M_final,
    PTE_hat = PTE_hat,
    elapsed_time = rep_time,
    rho_true = rho_true,
    PTE_true = pte_val
  )

  if (rep_number %% 50 == 0 || rep_number == opt$n_reps) {
    cat(sprintf("  ρ̂=%.3f, M=%d, time=%.1fs\n",
                result$rho_hat, result$M_final, rep_time))
  }

  # Save checkpoint periodically
  if (rep_number %% opt$checkpoint_interval == 0 && rep_number < opt$n_reps) {
    checkpoint_data <- list(
      dgp_id = opt$dgp_id,
      lambda = opt$lambda,
      n_reps_completed = rep_number,
      results = results_list,
      timestamp = Sys.time()
    )
    saveRDS(checkpoint_data, checkpoint_file)
    cat(sprintf("  Checkpoint saved: %d/%d reps\n", rep_number, opt$n_reps))
  }
}

study_time <- as.numeric(difftime(Sys.time(), study_start_time, units = "mins"))

# =============================================================================
# Save Final Results
# =============================================================================

final_output <- list(
  dgp_id = opt$dgp_id,
  lambda = opt$lambda,
  n_reps = opt$n_reps,
  results = results_list,
  study_time_minutes = study_time,
  timestamp = Sys.time(),
  config = list(
    sample_size = sim_settings$sample_size,
    M_settings = list(
      M_start = sim_settings$M_start,
      M_increment = sim_settings$M_increment,
      M_max = sim_settings$M_max,
      tolerance = sim_settings$tolerance,
      n_stable = sim_settings$n_stable
    )
  )
)

saveRDS(final_output, output_file)

# Remove checkpoint file
if (file.exists(checkpoint_file)) {
  file.remove(checkpoint_file)
}

cat(sprintf("\n=== Study Complete ===\n"))
cat(sprintf("Saved: %s\n", output_file))
cat(sprintf("Total time: %.1f minutes\n", study_time))
cat(sprintf("Avg time per rep: %.1f seconds\n", (study_time * 60) / opt$n_reps))
cat(sprintf("End: %s\n", Sys.time()))

quit(status = 0)
