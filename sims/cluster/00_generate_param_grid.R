#!/usr/bin/env Rscript

#' Generate Parameter Grid for TV Ball Coverage Cluster Simulations
#'
#' Creates a parameter grid with all combinations of:
#' - n_baseline: baseline study sample sizes
#' - lambda: TV ball radius
#' - M: number of innovation samples
#' - functional: type of functional to evaluate

library(tidyr)
library(dplyr)

# Parameter grid
params <- expand.grid(
  n_baseline = c(50, 100, 250, 500, 1000),
  lambda = c(0.1, 0.3, 0.5),
  M = c(50, 100, 250, 500, 1000, 2500, 5000),
  functional = c("correlation", "ppv", "concordance"),
  stringsAsFactors = FALSE
)

# Add job_id
params <- params %>%
  mutate(job_id = row_number()) %>%
  select(job_id, everything())

# Print summary
cat("Parameter Grid Summary\n")
cat("======================\n\n")
cat(sprintf("Total jobs: %d\n\n", nrow(params)))

cat("Dimensions:\n")
cat(sprintf("  n_baseline: %s\n", paste(unique(params$n_baseline), collapse = ", ")))
cat(sprintf("  lambda: %s\n", paste(unique(params$lambda), collapse = ", ")))
cat(sprintf("  M: %s\n", paste(unique(params$M), collapse = ", ")))
cat(sprintf("  functional: %s\n", paste(unique(params$functional), collapse = ", ")))
cat("\n")

cat("Breakdown by dimension:\n")
cat(sprintf("  %d sample sizes × %d λ values × %d M values × %d functionals = %d jobs\n",
            length(unique(params$n_baseline)),
            length(unique(params$lambda)),
            length(unique(params$M)),
            length(unique(params$functional)),
            nrow(params)))
cat("\n")

# Estimate compute time
# Each job: 100 reps × (generate data + compute functional for M samples + reachability check)
# Conservative estimate: ~0.5 sec per replication for small M, ~5 sec for large M
# Average across M: ~2 sec per replication
# 100 reps × 2 sec = 200 sec = 3.3 min per job
# Total: 315 jobs × 3.3 min = 1040 min = 17.3 hours serial
# With 50 parallel jobs: 17.3 / 50 = 0.35 hours = 21 min

cat("Estimated compute time:\n")
cat("  Per job: ~3-5 minutes (100 replications)\n")
cat("  Total serial: ~17-26 hours\n")
cat("  With 50 parallel jobs: ~20-30 minutes\n")
cat("  With 100 parallel jobs: ~10-15 minutes\n")
cat("\n")

# Save parameter grid
output_file <- "sims/cluster/29_tv_coverage_params.rds"
saveRDS(params, output_file)
cat(sprintf("Parameter grid saved to: %s\n", output_file))

# Also save as CSV for inspection
csv_file <- "sims/cluster/29_tv_coverage_params.csv"
write.csv(params, csv_file, row.names = FALSE)
cat(sprintf("Parameter grid saved to: %s (for inspection)\n", csv_file))

# Print first few rows
cat("\nFirst 10 jobs:\n")
print(head(params, 10))

cat("\nLast 10 jobs:\n")
print(tail(params, 10))
