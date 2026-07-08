#!/usr/bin/env Rscript
# Quick test of method across scenarios

library(tidyverse, quietly = TRUE, warn.conflicts = FALSE)
source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")
source("explorations/tv_ball_geometry/13_method_validation_scenarios.R")

validation <- test_method_all_scenarios(
  n = 500,
  K = 10,
  lambda = 0.3,
  M = 2000
)
