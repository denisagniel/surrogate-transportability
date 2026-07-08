#!/usr/bin/env Rscript
#
# Generate Table 2: Simulation Performance Metrics for Biometrika Paper
#
# Reads combined_results.rds and extracts bias, SE, coverage
# Output: inst/paper/tables/table2_performance.tex

library(dplyr)
library(glue)

# Read simulation results
results <- readRDS("cluster/results/combined_results.rds")

# Extract performance metrics for each DGP
performance <- tibble(
  DGP = c("1", "2", "4", "5"),
  rho_true = numeric(4),
  bias = numeric(4),
  emp_se = numeric(4),
  est_se = numeric(4),
  coverage = numeric(4),
  n_reps = integer(4)
)

for (i in seq_along(results)) {
  dgp <- results[[i]]
  dgp_id <- as.integer(gsub("dgp", "", dgp$dgp_id))
  idx <- which(performance$DGP == as.character(dgp_id))

  performance$rho_true[idx] <- dgp$summary$rho_true
  performance$bias[idx] <- dgp$summary$bias_rho
  performance$emp_se[idx] <- dgp$summary$empirical_sd_rho
  performance$est_se[idx] <- dgp$summary$mean_se_rho
  performance$coverage[idx] <- dgp$summary$coverage_rho
  performance$n_reps[idx] <- dgp$n_reps
}

# Format columns
performance <- performance %>%
  mutate(
    rho_true_fmt = sprintf("%.3f", rho_true),
    bias_fmt = sprintf("%.4f", bias),
    emp_se_fmt = sprintf("%.4f", emp_se),
    est_se_fmt = sprintf("%.4f", est_se),
    coverage_fmt = sprintf("%.1f", coverage * 100)  # Convert to percentage
  )

# Generate LaTeX table
latex_table <- glue('
\\begin{{table}}[ht]
\\centering
\\caption{{Simulation performance across 1000 replications per DGP.
Bias = $\\bar{{\\hat{{\\rho}}}} - \\rho_{{\\mathrm{{true}}}}$.
Emp. SE is the empirical standard error of $\\hat{{\\rho}}$ across replications.
Est. SE is the mean estimated standard error from the influence function.
Coverage is the proportion of 95\\% confidence intervals containing $\\rho_{{\\mathrm{{true}}}}$.}}
\\label{{tab:performance}}
\\begin{{tabular}}{{lrrrrrr}}
\\toprule
DGP & $\\rho_{{\\mathrm{{true}}}}$ & Bias & Emp. SE & Est. SE & Coverage (\\%) & Reps \\\\
\\midrule
{paste(glue_data(performance,
  "{DGP} & {rho_true_fmt} & {bias_fmt} & {emp_se_fmt} & {est_se_fmt} & {coverage_fmt} & {n_reps} \\\\\\\\"),
  collapse = "\\n")}
\\bottomrule
\\end{{tabular}}
\\end{{table}}
')

# Write to file
output_file <- "inst/paper/tables/table2_performance.tex"
cat(latex_table, file = output_file)
cat("Table 2 written to:", output_file, "\n")

# Print summary to console for verification
cat("\n=== Performance Summary ===\n")
print(performance %>% select(DGP, rho_true, bias, emp_se, est_se, coverage))
