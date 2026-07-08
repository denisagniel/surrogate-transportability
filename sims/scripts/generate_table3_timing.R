#!/usr/bin/env Rscript
#
# Generate Table 3: Computational Timing for Biometrika Paper
#
# Reads combined_results.rds and extracts timing information
# Output: inst/paper/tables/table3_timing.tex

library(dplyr)
library(glue)

# Read simulation results
results <- readRDS("cluster/results/combined_results.rds")

# Extract timing metrics for each DGP
timing <- tibble(
  DGP = c("1", "2", "4", "5"),
  mean_elapsed = numeric(4),
  mean_M = numeric(4),
  n_reps = integer(4)
)

for (i in seq_along(results)) {
  dgp <- results[[i]]
  dgp_id <- as.integer(gsub("dgp", "", dgp$dgp_id))
  idx <- which(timing$DGP == as.character(dgp_id))

  timing$mean_elapsed[idx] <- dgp$summary$mean_time
  timing$mean_M[idx] <- dgp$summary$mean_M
  timing$n_reps[idx] <- dgp$n_reps
}

# Format columns (convert to minutes)
timing <- timing %>%
  mutate(
    elapsed_min = mean_elapsed / 60,
    elapsed_fmt = sprintf("%.1f", elapsed_min),
    M_fmt = sprintf("%.0f", mean_M)
  )

# Generate LaTeX table
latex_table <- glue('
\\begin{{table}}[ht]
\\centering
\\caption{{Mean computational time per replication across 1000 replications.
Timing includes MCMC sampling for the Wasserstein minimax estimator
(adaptive M with tolerance 0.01), treatment effect estimation, and
nonparametric bootstrap (B=500). All computations performed on a single core.}}
\\label{{tab:timing}}
\\begin{{tabular}}{{lrrr}}
\\toprule
DGP & Mean M & Mean Time (min) & Reps \\\\
\\midrule
{paste(glue_data(timing,
  "{DGP} & {M_fmt} & {elapsed_fmt} & {n_reps} \\\\\\\\"),
  collapse = "\\n")}
\\bottomrule
\\end{{tabular}}
\\end{{table}}
')

# Write to file
output_file <- "inst/paper/tables/table3_timing.tex"
cat(latex_table, file = output_file)
cat("Table 3 written to:", output_file, "\n")

# Print summary to console for verification
cat("\n=== Timing Summary ===\n")
print(timing %>% select(DGP, mean_M, elapsed_min))
cat("\nTotal time for 1000 reps across all DGPs:",
    round(sum(timing$mean_elapsed) / 3600, 1), "hours\n")
