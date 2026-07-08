#!/usr/bin/env Rscript
# Run uncorrelated effects comparison

library(tidyverse)
library(MASS)  # for mvrnorm

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")
source("explorations/tv_ball_geometry/12_uncorrelated_effects.R")

# Run comparison
comparison <- compare_scenarios(
  n = 1000,
  K = 10,
  lambda = 0.3,
  M = 2000
)

cat("\n\nResults saved to:\n")
cat("  explorations/tv_ball_geometry/figures/uncorrelated_effects_comparison.pdf\n")
