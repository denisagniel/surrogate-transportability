#!/usr/bin/env Rscript
# Run Single Replication for Cluster Simulation
#
# Usage: Rscript run_single_rep.R <dgp_id> <rep_number> <config_file>
#
# Arguments:
#   dgp_id: DGP identifier (e.g., "dgp1", "dgp2")
#   rep_number: Replication number (1 to N_reps)
#   config_file: Path to YAML configuration file

suppressPackageStartupMessages({
  library(yaml)
  library(dplyr)
})

# Load package
suppressMessages(devtools::load_all())

# =============================================================================
# Parse Arguments
# =============================================================================

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 3) {
  stop("Usage: Rscript run_single_rep.R <dgp_id> <rep_number> <config_file>")
}

dgp_id <- args[1]
rep_number <- as.integer(args[2])
config_file <- args[3]

cat(sprintf("\n=== Cluster Job: %s, Rep %d ===\n", dgp_id, rep_number))
cat(sprintf("Start time: %s\n", Sys.time()))

# =============================================================================
# Load Configuration
# =============================================================================

config <- yaml::read_yaml(config_file)

dgp_config <- config$dgps[[dgp_id]]
sim_settings <- config$simulation_settings
cluster_settings <- config$cluster_settings

if (is.null(dgp_config)) {
  stop(sprintf("DGP '%s' not found in configuration", dgp_id))
}

cat(sprintf("\nDGP: %s\n", dgp_config$name))
cat(sprintf("TRUE ρ = %.4f, PTE(P₀) = %.4f\n", dgp_config$rho_true, dgp_config$PTE_P0))

# =============================================================================
# Setup DGP
# =============================================================================

# DGP function
generate_dgp_data <- function(n, p_X, params, X_levels) {
  K <- length(X_levels)

  X <- sample(X_levels, size = n, replace = TRUE, prob = p_X)
  A <- rbinom(n, 1, 0.5)

  gamma_A <- params$gamma_A
  gamma_AX <- params$gamma_AX
  beta_A <- params$beta_A
  beta_AX <- params$beta_AX
  beta_S <- params$beta_S
  beta_SX <- params$beta_SX
  sigma_S <- params$sigma_S
  sigma_Y <- params$sigma_Y

  S <- (gamma_A + gamma_AX * X) * A + rnorm(n, sd = sigma_S)
  Y <- (beta_A + beta_AX * X) * A + beta_S * S + beta_SX * S * X +
       rnorm(n, sd = sigma_Y)

  data.frame(X = X, A = A, S = S, Y = Y)
}

# =============================================================================
# Generate Data
# =============================================================================

seed <- cluster_settings$random_seed_start + (rep_number - 1)
set.seed(seed)

cat(sprintf("\nGenerating data: n = %d, seed = %d\n", sim_settings$n, seed))

data <- generate_dgp_data(
  n = sim_settings$n,
  p_X = unlist(dgp_config$p_X),
  params = dgp_config$params,
  X_levels = unlist(dgp_config$X_levels)
)

# =============================================================================
# Run Adaptive M Estimation
# =============================================================================

cat(sprintf("\nRunning adaptive M estimation...\n"))

time_start <- Sys.time()

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

time_end <- Sys.time()
elapsed_time <- as.numeric(difftime(time_end, time_start, units = "secs"))

cat(sprintf("\nResults:\n"))
cat(sprintf("  ρ̂ = %.4f (TRUE = %.4f, bias = %.4f)\n",
            result$rho_hat, dgp_config$rho_true, result$rho_hat - dgp_config$rho_true))
cat(sprintf("  SE = %.4f\n", result$se))
cat(sprintf("  95%% CI: [%.4f, %.4f]\n", result$ci_lower, result$ci_upper))
cat(sprintf("  Converged: %s at M = %d\n", ifelse(result$converged, "YES", "NO"), result$M_final))
cat(sprintf("  Time: %.1f seconds\n", elapsed_time))

# =============================================================================
# Compute PTE Estimate
# =============================================================================

# Empirical PTE estimation
# PTE = (β_S × ΔS) / ΔY (using estimated ΔS and ΔY at P₀)

# At P₀, compute empirical treatment effects
p_X_0 <- unlist(dgp_config$p_X)
X_unique <- sort(unique(data$X))
K <- length(X_unique)

# Estimate CATEs
tau_S_hat <- numeric(K)
tau_Y_hat <- numeric(K)

for (k in 1:K) {
  data_k <- data[data$X == X_unique[k], ]
  tau_S_hat[k] <- mean(data_k$S[data_k$A == 1]) - mean(data_k$S[data_k$A == 0])
  tau_Y_hat[k] <- mean(data_k$Y[data_k$A == 1]) - mean(data_k$Y[data_k$A == 0])
}

# Treatment effects at P₀
Delta_S_P0_hat <- sum(p_X_0 * tau_S_hat)
Delta_Y_P0_hat <- sum(p_X_0 * tau_Y_hat)

# PTE estimate
beta_S <- dgp_config$params$beta_S
PTE_hat <- (beta_S * Delta_S_P0_hat) / Delta_Y_P0_hat

cat(sprintf("\nPTE Estimate:\n"))
cat(sprintf("  PTE_hat = %.4f (TRUE = %.4f, bias = %.4f)\n",
            PTE_hat, dgp_config$PTE_P0, PTE_hat - dgp_config$PTE_P0))

# =============================================================================
# Save Results
# =============================================================================

output_dir <- file.path(cluster_settings$output_dir, dgp_id)
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

output_file <- file.path(output_dir, sprintf("rep_%04d.rds", rep_number))

output <- list(
  dgp_id = dgp_id,
  rep_number = rep_number,
  seed = seed,
  # Correlation results
  rho_hat = result$rho_hat,
  se = result$se,
  ci_lower = result$ci_lower,
  ci_upper = result$ci_upper,
  converged = result$converged,
  M_final = result$M_final,
  M_history = result$M_history,
  rho_history = result$rho_history,
  # PTE results
  PTE_hat = PTE_hat,
  Delta_S_P0_hat = Delta_S_P0_hat,
  Delta_Y_P0_hat = Delta_Y_P0_hat,
  tau_S_hat = tau_S_hat,
  tau_Y_hat = tau_Y_hat,
  # Metadata
  elapsed_time = elapsed_time,
  timestamp = Sys.time(),
  # Truth
  rho_true = dgp_config$rho_true,
  PTE_true = dgp_config$PTE_P0
)

saveRDS(output, output_file)

cat(sprintf("\nSaved: %s\n", output_file))
cat(sprintf("End time: %s\n", Sys.time()))
cat(sprintf("\n=== Job Complete ===\n"))

# Exit with success
quit(status = 0)
