#!/usr/bin/env Rscript
# Production Command-Line Interface for Single Replication Batch
#
# Runs MULTIPLE replications (default: 10) in a single job for optimal cluster efficiency.
# Called by SLURM with batch number (not individual rep number).
#
# Usage: Rscript run_single_replication.R --dgp dgp1 --batch 1 --reps-per-batch 10 \
#                                          --config config.yaml --output-dir results/dgp1/
#
# Requirements:
# - surrogateTransportability package installed via library()
# - Config file with DGP specifications

suppressPackageStartupMessages({
  library(optparse)
  library(yaml)
})

# =============================================================================
# Parse Arguments
# =============================================================================

option_list <- list(
  make_option(c("--dgp"), type = "character", dest = "dgp_id",
              help = "DGP identifier (dgp1, dgp2, dgp4)", metavar = "CHARACTER"),
  make_option(c("--batch"), type = "integer", dest = "batch_number",
              help = "Batch number (1 to N_batches)", metavar = "INTEGER"),
  make_option(c("--reps-per-batch"), type = "integer", dest = "reps_per_batch",
              default = 10,
              help = "Number of replications per batch [default: %default]", metavar = "INTEGER"),
  make_option(c("--config"), type = "character", dest = "config_file",
              default = "cluster/config/dgp_specifications.yaml",
              help = "Path to YAML config [default: %default]", metavar = "FILE"),
  make_option(c("--output-dir"), type = "character", dest = "output_dir",
              help = "Output directory for results", metavar = "DIR")
)

opt <- parse_args(OptionParser(option_list = option_list))

# Validate
if (is.null(opt$dgp_id) || is.null(opt$batch_number) || is.null(opt$output_dir)) {
  stop("--dgp, --batch, and --output-dir are required")
}

cat(sprintf("\n=== Cluster Batch: %s, Batch %d (%d reps) ===\n",
            opt$dgp_id, opt$batch_number, opt$reps_per_batch))
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

# Handle NaN/NA in PTE (YAML may parse "NaN" as string)
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
# Run Batch of Replications
# =============================================================================

# Compute rep range for this batch
first_rep <- (opt$batch_number - 1) * opt$reps_per_batch + 1
last_rep <- opt$batch_number * opt$reps_per_batch

cat(sprintf("\nRunning reps %d-%d\n\n", first_rep, last_rep))

results_list <- list()
batch_start_time <- Sys.time()

for (rep_number in first_rep:last_rep) {
  cat(sprintf("--- Rep %d/%d ---\n", rep_number - first_rep + 1, opt$reps_per_batch))

  # Set seed
  seed <- cluster_settings$random_seed_start + (rep_number - 1)
  set.seed(seed)

  # Generate data
  data <- generate_dgp_data(
    n = sim_settings$sample_size,
    p_X = unlist(dgp_config$p_X),
    params = dgp_config$params,
    X_levels = unlist(dgp_config$X_levels)
  )

  # Run adaptive M
  rep_start <- Sys.time()

  result <- tv_ball_correlation_IF_adaptive(
    data = data,
    lambda = dgp_config$lambda,
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

  # Compute PTE
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
      tau_S_hat[k] <- 0  # No data for this level
      tau_Y_hat[k] <- 0
    }
  }

  Delta_S_P0_hat <- sum(p_X_0 * tau_S_hat)
  Delta_Y_P0_hat <- sum(p_X_0 * tau_Y_hat)
  PTE_hat <- (dgp_config$params$beta_S * Delta_S_P0_hat) / Delta_Y_P0_hat

  # Store results
  results_list[[length(results_list) + 1]] <- list(
    dgp_id = opt$dgp_id,
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

  cat(sprintf("  ρ̂=%.3f, M=%d, time=%.1fs\n", result$rho_hat, result$M_final, rep_time))
}

batch_time <- as.numeric(difftime(Sys.time(), batch_start_time, units = "mins"))

# =============================================================================
# Save Batch Results
# =============================================================================

dir.create(opt$output_dir, showWarnings = FALSE, recursive = TRUE)

output_file <- file.path(opt$output_dir, sprintf("batch_%03d.rds", opt$batch_number))

batch_output <- list(
  dgp_id = opt$dgp_id,
  batch_number = opt$batch_number,
  reps_per_batch = opt$reps_per_batch,
  first_rep = first_rep,
  last_rep = last_rep,
  results = results_list,
  batch_time_minutes = batch_time,
  timestamp = Sys.time()
)

saveRDS(batch_output, output_file)

cat(sprintf("\n=== Batch Complete ===\n"))
cat(sprintf("Saved: %s\n", output_file))
cat(sprintf("Total time: %.1f minutes\n", batch_time))
cat(sprintf("End: %s\n", Sys.time()))

quit(status = 0)
