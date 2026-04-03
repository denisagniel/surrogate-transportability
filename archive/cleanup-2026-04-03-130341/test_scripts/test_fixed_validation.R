#!/usr/bin/env Rscript
# Test the fixed validation script with just 3 replications

library(tidyverse)
library(here)

devtools::load_all(here("package"))

# Source the fixed functions
source("sims/scripts/25_sample_splitting_coverage.R", local = TRUE)

cat("Testing fixed validation script (3 replications)...\n\n")

# Run just 3 replications of baseline DGP
results <- run_coverage_study(
  dgp = dgps$baseline,
  n_reps = 3,
  n = 500,
  lambda_w = 0.5,
  split_ratio = 0.5,
  n_bootstrap = 50,  # Fewer for speed
  confidence_level = 0.95,
  verbose = TRUE
)

cat("\n\nResults structure:\n")
str(results)

cat("\n\nResults:\n")
print(results)

if (nrow(results) == 0) {
  cat("\n\n❌ ERROR: Still getting 0 rows\n")
} else if (all(results$status == "failed")) {
  cat("\n\n❌ All replications failed\n")
  if ("error" %in% names(results)) {
    print(results %>% select(rep, status, error))
  }
} else {
  cat("\n\n✓ Got", sum(results$status == "success"), "successful replications!\n")
}
