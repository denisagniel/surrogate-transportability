#!/usr/bin/env Rscript
#' Quick version of covariate shift validation (for testing)
#' Runs only 50 reps per scenario to test everything works

# Source the main script but override parameters
N_BASELINE <- 1000
N_FUTURE <- 1000
N_REPLICATIONS <- 50  # <<< Reduced from 1000
N_TRUE_STUDIES <- 200  # <<< Reduced from 500
N_INNOVATIONS <- 500   # <<< Reduced from 1000
CONFIDENCE_LEVEL <- 0.95

cat("================================================================\n")
cat("QUICK TEST VERSION - 50 REPS PER SCENARIO\n")
cat("================================================================\n\n")

# Now source the rest from the main script
source("sims/scripts/08_covariate_shift_validation.R", local = TRUE)
