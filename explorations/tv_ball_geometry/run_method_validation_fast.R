#!/usr/bin/env Rscript
# Fast test of method across scenarios (smaller M for speed)

suppressPackageStartupMessages(library(tidyverse))
source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")
source("explorations/tv_ball_geometry/13_method_validation_scenarios.R")

validation <- test_method_all_scenarios(
  n = 300,
  K = 10,
  lambda = 0.3,
  M = 500  # Smaller for speed
)
