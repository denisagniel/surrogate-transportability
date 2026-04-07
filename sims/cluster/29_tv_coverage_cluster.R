#!/usr/bin/env Rscript

#' TV Ball Coverage Verification - CLUSTER VERSION
#'
#' Single job for array: reads parameters from command line
#'
#' Usage: Rscript 29_tv_coverage_cluster.R <job_id>

# Get job ID from command line
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  stop("Usage: Rscript 29_tv_coverage_cluster.R <job_id>")
}
job_id <- as.integer(args[1])

# Load package
suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(dplyr)
  library(tibble)
  library(MASS)
  library(MCMCpack)
})

cat(sprintf("Job ID: %d\n", job_id))
cat(sprintf("Started at: %s\n", Sys.time()))

# Read parameter grid
param_file <- "sims/cluster/29_tv_coverage_params.rds"
if (!file.exists(param_file)) {
  stop("Parameter file not found: ", param_file)
}

params_grid <- readRDS(param_file)
if (job_id > nrow(params_grid)) {
  stop(sprintf("Job ID %d exceeds parameter grid size %d", job_id, nrow(params_grid)))
}

# Extract parameters for this job
params <- params_grid[job_id, ]
cat("Parameters for this job:\n")
print(params)
cat("\n")

# Simulation parameters (fixed across jobs)
N_REPLICATIONS <- 100
N_TEST_POINTS <- 50
EPSILON_REACH <- 0.05
ALPHA_DIRICHLET <- 1.0
N_TYPES <- 10

# Extract job-specific parameters
N_BASELINE <- params$n_baseline
LAMBDA <- params$lambda
M <- params$M
FUNC_NAME <- params$functional

# Define functional specification
functionals <- list(
  correlation = list(name = "Correlation", type = "correlation"),
  ppv = list(name = "PPV", type = "ppv",
             params = list(epsilon_s = 0, epsilon_y = 0)),
  concordance = list(name = "Concordance", type = "concordance")
)

if (!FUNC_NAME %in% names(functionals)) {
  stop("Unknown functional: ", FUNC_NAME)
}
func_spec <- functionals[[FUNC_NAME]]

cat(sprintf("\nRunning simulation:\n"))
cat(sprintf("  N_BASELINE: %d\n", N_BASELINE))
cat(sprintf("  Lambda: %.2f\n", LAMBDA))
cat(sprintf("  M: %d\n", M))
cat(sprintf("  Functional: %s\n", func_spec$name))
cat(sprintf("  Replications: %d\n", N_REPLICATIONS))
cat("\n")

# Helper functions
generate_random_in_tv_ball <- function(P0, lambda, n_points = 1) {
  results <- list()
  k <- length(P0)

  for (i in seq_len(n_points)) {
    direction <- rdirichlet(1, rep(0.5, k))[1, ]
    max_shift <- lambda

    needs_scaling <- direction < P0
    if (any(needs_scaling)) {
      max_allowed_shift <- min(P0[needs_scaling] / (P0[needs_scaling] - direction[needs_scaling]))
      actual_shift <- min(max_shift, max_allowed_shift * 0.95)
    } else {
      actual_shift <- max_shift * 0.95
    }

    Q <- P0 + actual_shift * (direction - P0)
    Q <- Q / sum(Q)

    tv_dist <- compute_tv_distance(Q, P0)
    if (tv_dist > lambda * 1.01) {
      Q <- (1 - lambda/2) * P0 + (lambda/2) * direction
      Q <- Q / sum(Q)
    }

    results[[i]] <- Q
  }

  if (n_points == 1) {
    return(results[[1]])
  } else {
    return(results)
  }
}

compute_functional_value <- function(Q, P0, S_baseline, Y_baseline, functional_spec) {
  n_future <- length(S_baseline)
  types <- sample(seq_along(Q), size = n_future, replace = TRUE, prob = Q)

  S_future <- numeric(n_future)
  Y_future <- numeric(n_future)

  for (j in seq_along(types)) {
    sample_idx <- sample(seq_along(S_baseline), 1)
    S_future[j] <- S_baseline[sample_idx]
    Y_future[j] <- Y_baseline[sample_idx]
  }

  if (functional_spec$type == "correlation") {
    return(cor(S_future, Y_future))
  } else if (functional_spec$type == "ppv") {
    eps_s <- functional_spec$params$epsilon_s
    eps_y <- functional_spec$params$epsilon_y
    numer <- mean(S_future >= eps_s & Y_future >= eps_y)
    denom <- mean(S_future >= eps_s)
    return(ifelse(denom > 0, numer / denom, NA_real_))
  } else if (functional_spec$type == "concordance") {
    n <- length(S_future)
    concordant <- 0
    discordant <- 0
    for (i in seq_len(n-1)) {
      for (j in (i+1):n) {
        if (S_future[i] != S_future[j]) {
          if ((S_future[i] > S_future[j] && Y_future[i] > Y_future[j]) ||
              (S_future[i] < S_future[j] && Y_future[i] < Y_future[j])) {
            concordant <- concordant + 1
          } else {
            discordant <- discordant + 1
          }
        }
      }
    }
    return(ifelse(concordant + discordant > 0,
                  concordant / (concordant + discordant),
                  NA_real_))
  }
}

# Set seed based on job_id for reproducibility
set.seed(20260407 + job_id)

# Run replications
results_list <- list()

for (rep in seq_len(N_REPLICATIONS)) {
  if (rep %% 20 == 0) {
    cat(sprintf("  Replication %d/%d\n", rep, N_REPLICATIONS))
  }

  # Generate baseline data
  Sigma <- matrix(c(1, 0.5, 0.5, 1), 2, 2)
  data_baseline <- mvrnorm(N_BASELINE, mu = c(0, 0), Sigma = Sigma)
  S_baseline <- data_baseline[, 1]
  Y_baseline <- data_baseline[, 2]

  # Compute baseline P₀
  S_bins <- cut(S_baseline, breaks = N_TYPES, labels = FALSE)
  P0 <- table(S_bins) / N_BASELINE
  P0 <- as.numeric(P0)
  P0 <- pmax(P0, 1e-6)
  P0 <- P0 / sum(P0)

  # Generate test points
  test_points <- generate_random_in_tv_ball(P0, LAMBDA, N_TEST_POINTS)

  # Compute empirical infimum
  test_values <- numeric(N_TEST_POINTS)
  for (i in seq_len(N_TEST_POINTS)) {
    test_values[i] <- compute_functional_value(
      Q = test_points[[i]],
      P0 = P0,
      S_baseline = S_baseline,
      Y_baseline = Y_baseline,
      functional_spec = func_spec
    )
  }
  empirical_inf <- min(test_values, na.rm = TRUE)

  # Generate M samples from innovation mechanism
  Q_samples <- list()
  for (m in seq_len(M)) {
    P_tilde <- rdirichlet(1, rep(ALPHA_DIRICHLET, length(P0)))[1, ]
    Q_samples[[m]] <- (1 - LAMBDA) * P0 + LAMBDA * P_tilde
  }

  # Compute φ(Q_m)
  phi_values <- numeric(M)
  for (m in seq_len(M)) {
    phi_values[m] <- compute_functional_value(
      Q = Q_samples[[m]],
      P0 = P0,
      S_baseline = S_baseline,
      Y_baseline = Y_baseline,
      functional_spec = func_spec
    )
  }

  min_phi <- min(phi_values, na.rm = TRUE)

  # Compute reachability
  reachability_count <- 0
  for (i in seq_len(N_TEST_POINTS)) {
    Q_target <- test_points[[i]]
    min_dist <- Inf
    for (m in seq_len(M)) {
      dist <- compute_tv_distance(Q_samples[[m]], Q_target)
      min_dist <- min(min_dist, dist)
    }
    if (min_dist < EPSILON_REACH) {
      reachability_count <- reachability_count + 1
    }
  }
  reachability <- reachability_count / N_TEST_POINTS

  # Compute gap
  gap <- min_phi - empirical_inf

  # Store results
  results_list[[rep]] <- tibble(
    job_id = job_id,
    n_baseline = N_BASELINE,
    lambda = LAMBDA,
    M = M,
    functional = FUNC_NAME,
    replication = rep,
    min_phi = min_phi,
    empirical_inf = empirical_inf,
    gap = gap,
    reachability = reachability
  )
}

# Combine results
results_df <- bind_rows(results_list)

# Save results for this job
output_dir <- "sims/cluster/results"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

output_file <- sprintf("%s/job_%04d.rds", output_dir, job_id)
saveRDS(results_df, output_file)

cat(sprintf("\nCompleted %d replications\n", N_REPLICATIONS))
cat(sprintf("Results saved to: %s\n", output_file))
cat(sprintf("Finished at: %s\n", Sys.time()))
