#' Study 2: Stress Testing (QUICK VERSION)

library(tidyverse)
library(here)

# Override parameters for quick test
N_REPS <- 50  # Reduced from 500

# Reduce stress dimensions for quick test
STRESS_DIMENSIONS <- list(
  small_sample = list(
    name = "Small sample size",
    params = expand_grid(
      n = c(100, 500),
      lambda = 0.3,
      J = 16,
      rho = 0.7,
      cv = 0.3
    )
  ),
  extreme_lambda = list(
    name = "Extreme λ",
    params = expand_grid(
      n = 500,
      lambda = c(0.3, 0.7),
      J = 16,
      rho = 0.7,
      cv = 0.3
    )
  )
)

# Source main script
source(here("sims/scripts/02_stress_testing.R"))
