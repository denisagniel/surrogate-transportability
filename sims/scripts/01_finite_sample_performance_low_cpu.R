#' Study 1: Finite Sample Performance (Low CPU version)
#'
#' Same as full study but uses only 3 cores to reduce CPU load

# Set parameters BEFORE loading main script
N_REPS <- 500  # Replications per setting
SAMPLE_SIZES <- c(250, 500, 1000, 2000)
LAMBDA_VALUES <- c(0.1, 0.2, 0.3, 0.4)
J <- 16  # Number of types
N_CORES <- 3  # Use only 3 cores (instead of 9)

# Source the main study script
source("sims/scripts/01_finite_sample_performance.R")
