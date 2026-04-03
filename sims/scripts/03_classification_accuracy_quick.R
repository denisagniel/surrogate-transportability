#' Study 3: Classification Accuracy (QUICK VERSION)
#'
#' Quick test version with reduced replications for validation

library(tidyverse)
library(here)

# Source full script but override parameters
N_REPS <- 50  # Reduced from 1000
N <- 500
J <- 16
LAMBDA <- 0.3
N_CORES <- 1  # Sequential processing for quick version

# Source the main script
source(here("sims/scripts/03_classification_accuracy.R"))
