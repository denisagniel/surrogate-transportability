#!/usr/bin/env Rscript
# AIPW Robustness Study: Single Replication Script
# Purpose: Run one replication of AIPW correlation estimation with noisy nuisances
# Usage: Rscript run_single_replication.R --scenario=0 --n=2000 --alpha_1=0.3 ...

suppressPackageStartupMessages({
  library(optparse)
  library(surrogateTransportability)
  library(yaml)
})

# ==============================================================================
# Command-Line Arguments
# ==============================================================================

option_list <- list(
  make_option("--scenario", type = "integer", dest = "scenario",
             help = "Scenario number (0=oracle, 1=propensity, 2=outcome, 3=both)"),
  make_option("--n", type = "integer", dest = "n",
             help = "Sample size"),
  make_option("--alpha_1", type = "double", dest = "alpha_1",
             help = "Confounding strength (0=RCT, 0.3=mild, 0.6=strong)"),
  make_option("--alpha_e", type = "double", dest = "alpha_e", default = 0.5,
             help = "Propensity convergence rate (0, 0.25, 0.5, 0.75)"),
  make_option("--alpha_mu", type = "double", dest = "alpha_mu", default = 0.5,
             help = "Outcome convergence rate (0, 0.25, 0.5, 0.75)"),
  make_option("--c_e", type = "double", dest = "c_e", default = 1.0,
             help = "Propensity noise constant"),
  make_option("--c_mu", type = "double", dest = "c_mu", default = 1.0,
             help = "Outcome noise constant"),
  make_option("--rep_id", type = "integer", dest = "rep_id",
             help = "Replication ID (for seeding)"),
  make_option("--output", type = "character", dest = "output",
             help = "Output file path (.rds)"),
  make_option("--config", type = "character", dest = "config",
             default = "../config/aipw_grid.yaml",
             help = "Path to configuration YAML")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# Validate required arguments
required_args <- c("scenario", "n", "alpha_1", "rep_id", "output")
missing_args <- required_args[!sapply(required_args, function(x) !is.null(opt[[x]]))]
if (length(missing_args) > 0) {
  stop("Missing required arguments: ", paste(missing_args, collapse = ", "))
}

# ==============================================================================
# Load Configuration
# ==============================================================================

config <- yaml::read_yaml(opt$config)

# Extract DGP parameters
dgp <- config$dgp
X_levels <- unlist(dgp$X_levels)
p_X <- unlist(dgp$p_X)
params <- dgp$params
rho_true <- dgp$rho_true

# Extract inference settings
inf <- config$inference
lambda <- inf$lambda
M_start <- inf$M_start
M_increment <- inf$M_increment
M_max <- inf$M_max
tolerance <- inf$tolerance
n_stable <- inf$n_stable
alpha_conf <- inf$alpha

# ==============================================================================
# Set Seed for Reproducibility
# ==============================================================================

set.seed(opt$rep_id)

# ==============================================================================
# Step 1: Generate Observational Data with Confounding
# ==============================================================================

# Sample covariate X
X <- sample(X_levels, size = opt$n, replace = TRUE, prob = p_X)

# True propensity score: e(X) = expit(α₀ + α₁·X)
# α₀ = 0 gives overall prevalence ≈ 50%
alpha_0 <- 0
logit_e_true <- alpha_0 + opt$alpha_1 * X
e_true <- plogis(logit_e_true)  # expit = inverse logit

# Generate treatment via propensity score
A <- rbinom(opt$n, 1, prob = e_true)

# Generate S and Y (structural model from DGP parameters)
# S: E[S|A,X] = (γ_A + γ_AX·X)·A
S <- (params$gamma_A + params$gamma_AX * X) * A + rnorm(opt$n, sd = params$sigma_S)

# Y: E[Y|A,X,S] = (β_A + β_AX·X)·A + β_S·S + β_SX·S·X
Y <- (params$beta_A + params$beta_AX * X) * A +
     params$beta_S * S + params$beta_SX * S * X +
     rnorm(opt$n, sd = params$sigma_Y)

data <- data.frame(X = X, A = A, S = S, Y = Y)

# ==============================================================================
# Step 2: Compute True Nuisance Functions
# ==============================================================================

# True propensity score (already computed above)
# e_true is vector of length n

# True outcome regressions (deterministic given X in linear model)
mu_1_S_true <- params$gamma_A + params$gamma_AX * X
mu_0_S_true <- rep(0, opt$n)

mu_1_Y_true <- params$beta_A + params$beta_AX * X +
               params$beta_S * (params$gamma_A + params$gamma_AX * X)
mu_0_Y_true <- rep(0, opt$n)

# ==============================================================================
# Step 3: Add Noise Based on Scenario
# ==============================================================================

K <- length(X_levels)

# Initialize with true values
e_est <- e_true
mu_1_S_est <- mu_1_S_true
mu_0_S_est <- mu_0_S_true
mu_1_Y_est <- mu_1_Y_true
mu_0_Y_est <- mu_0_Y_true

# Scenario 0: Oracle (no noise)
if (opt$scenario == 0) {
  # Use true values (already initialized)

# Scenario 1: Propensity noise only
} else if (opt$scenario == 1) {
  # Compute noise standard deviation: σ_e(n) = c_e · n^(-α_e)
  sigma_e <- opt$c_e * opt$n^(-opt$alpha_e)

  # Generate K noise terms (one per X level, X-specific noise)
  epsilon_e <- rnorm(K, mean = 0, sd = sigma_e)
  noise_lookup_e <- setNames(epsilon_e, X_levels)

  # Add noise on logit scale: e_est(X) = expit(logit(e_true(X)) + ε_X)
  logit_e_noisy <- logit_e_true + noise_lookup_e[as.character(X)]
  e_est <- plogis(logit_e_noisy)

  # Clip to [0.01, 0.99] for numerical stability
  e_est <- pmax(pmin(e_est, 0.99), 0.01)

# Scenario 2: Outcome noise only
} else if (opt$scenario == 2) {
  # Compute noise standard deviation: σ_μ(n) = c_μ · n^(-α_μ)
  sigma_mu <- opt$c_mu * opt$n^(-opt$alpha_mu)

  # Generate K noise terms per outcome regression
  epsilon_mu_S1 <- rnorm(K, mean = 0, sd = sigma_mu)
  epsilon_mu_Y1 <- rnorm(K, mean = 0, sd = sigma_mu)

  noise_lookup_mu_S1 <- setNames(epsilon_mu_S1, X_levels)
  noise_lookup_mu_Y1 <- setNames(epsilon_mu_Y1, X_levels)

  # Add noise to outcome regressions
  mu_1_S_est <- mu_1_S_true + noise_lookup_mu_S1[as.character(X)]
  mu_1_Y_est <- mu_1_Y_true + noise_lookup_mu_Y1[as.character(X)]
  # mu_0_* remain 0 (no noise added to control outcomes in this DGP)

# Scenario 3: Both noisy
} else if (opt$scenario == 3) {
  # Propensity noise
  sigma_e <- opt$c_e * opt$n^(-opt$alpha_e)
  epsilon_e <- rnorm(K, mean = 0, sd = sigma_e)
  noise_lookup_e <- setNames(epsilon_e, X_levels)
  logit_e_noisy <- logit_e_true + noise_lookup_e[as.character(X)]
  e_est <- pmax(pmin(plogis(logit_e_noisy), 0.99), 0.01)

  # Outcome noise
  sigma_mu <- opt$c_mu * opt$n^(-opt$alpha_mu)
  epsilon_mu_S1 <- rnorm(K, mean = 0, sd = sigma_mu)
  epsilon_mu_Y1 <- rnorm(K, mean = 0, sd = sigma_mu)
  noise_lookup_mu_S1 <- setNames(epsilon_mu_S1, X_levels)
  noise_lookup_mu_Y1 <- setNames(epsilon_mu_Y1, X_levels)
  mu_1_S_est <- mu_1_S_true + noise_lookup_mu_S1[as.character(X)]
  mu_1_Y_est <- mu_1_Y_true + noise_lookup_mu_Y1[as.character(X)]
}

# ==============================================================================
# Step 4: Run AIPW Estimation
# ==============================================================================

start_time <- Sys.time()

result <- tryCatch({
  tv_ball_correlation_IF_adaptive(
    data = data,
    lambda = lambda,
    M_start = M_start,
    M_increment = M_increment,
    M_max = M_max,
    tolerance = tolerance,
    n_stable = n_stable,
    burn_in = 500,
    thin = 5,
    alpha = alpha_conf,
    method = "aipw",
    e_hat = e_est,
    mu_1_S = mu_1_S_est,
    mu_0_S = mu_0_S_est,
    mu_1_Y = mu_1_Y_est,
    mu_0_Y = mu_0_Y_est,
    verbose = FALSE
  )
}, error = function(e) {
  list(
    error = TRUE,
    error_message = as.character(e),
    rho_hat = NA,
    se = NA,
    ci_lower = NA,
    ci_upper = NA,
    converged = FALSE,
    M_final = NA
  )
})

end_time <- Sys.time()
time_elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

# ==============================================================================
# Step 5: Package Results
# ==============================================================================

# Compute quality metrics
nuisance_quality <- list(
  e_mae = mean(abs(e_est - e_true)),
  e_rmse = sqrt(mean((e_est - e_true)^2)),
  mu_1_S_mae = mean(abs(mu_1_S_est - mu_1_S_true)),
  mu_1_Y_mae = mean(abs(mu_1_Y_est - mu_1_Y_true))
)

# Coverage indicator
covers <- !is.na(result$rho_hat) &&
          result$ci_lower <= rho_true &&
          rho_true <= result$ci_upper

output_data <- data.frame(
  # Settings
  scenario = opt$scenario,
  n = opt$n,
  alpha_1 = opt$alpha_1,
  alpha_e = opt$alpha_e,
  alpha_mu = opt$alpha_mu,
  c_e = opt$c_e,
  c_mu = opt$c_mu,
  rep_id = opt$rep_id,

  # Results
  rho_hat = result$rho_hat,
  se = result$se,
  ci_lower = result$ci_lower,
  ci_upper = result$ci_upper,
  rho_true = rho_true,
  bias = result$rho_hat - rho_true,
  covers = covers,

  # Convergence
  converged = result$converged,
  M_final = result$M_final,

  # Nuisance quality
  e_mae = nuisance_quality$e_mae,
  e_rmse = nuisance_quality$e_rmse,
  mu_1_S_mae = nuisance_quality$mu_1_S_mae,
  mu_1_Y_mae = nuisance_quality$mu_1_Y_mae,

  # Computational
  time_sec = time_elapsed,
  error = ifelse(is.null(result$error), FALSE, result$error)
)

# ==============================================================================
# Step 6: Save Results
# ==============================================================================

saveRDS(output_data, file = opt$output)

# Print summary
cat(sprintf("Replication %d complete:\n", opt$rep_id))
cat(sprintf("  Setting: scenario=%d, n=%d, α₁=%.2f\n", opt$scenario, opt$n, opt$alpha_1))
cat(sprintf("  ρ̂ = %.4f (true: %.4f), bias = %.4f\n", result$rho_hat, rho_true, result$rho_hat - rho_true))
cat(sprintf("  SE = %.4f, covers = %s\n", result$se, covers))
cat(sprintf("  Converged: %s (M = %d)\n", result$converged, result$M_final))
cat(sprintf("  Time: %.1f sec\n", time_elapsed))
cat(sprintf("  Output: %s\n", opt$output))
