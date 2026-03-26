#' Study 1: Finite Sample Performance (QUICK VERSION)

library(tidyverse)
library(here)

# Override parameters for quick test
N_REPS <- 50  # Reduced from 500
SAMPLE_SIZES <- c(250, 1000)  # Reduced subset
LAMBDA_VALUES <- c(0.2, 0.3)  # Reduced subset

# Source main script
source(here("sims/scripts/01_finite_sample_performance.R"))
