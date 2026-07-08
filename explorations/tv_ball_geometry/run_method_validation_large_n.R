#!/usr/bin/env Rscript
# Test with larger sample size

suppressPackageStartupMessages(library(tidyverse))
source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")
source("explorations/tv_ball_geometry/13_method_validation_scenarios.R")

cat("Testing with n=2000 (larger sample size)\n\n")

validation <- test_method_all_scenarios(
  n = 2000,  # Much larger
  K = 10,
  lambda = 0.3,
  M = 1000
)
