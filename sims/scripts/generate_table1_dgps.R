#!/usr/bin/env Rscript
#
# Generate Table 1: DGP Specifications for Biometrika Paper
#
# Reads dgp_specifications.yaml and formats as LaTeX table
# Output: inst/paper/tables/table1_dgp_specs.tex

library(yaml)
library(dplyr)
library(glue)

# Read DGP specifications
dgp_config <- yaml::read_yaml("cluster/config/dgp_specifications.yaml")

# Extract DGP details
dgps <- dgp_config$dgps

# Create data frame for table
dgp_table <- tibble(
  DGP = c("1", "2", "4", "5"),
  Description = c(
    "Moderate positive correlation, high mediation",
    "Strong negative correlation, moderate mediation",
    "Low PTE, near-perfect correlation",
    "Small $\\Delta_Y$ at $P_0$, high correlation"
  ),
  gamma_A = c(dgps$dgp1$params$gamma_A, dgps$dgp2$params$gamma_A,
              dgps$dgp4$params$gamma_A, dgps$dgp5$params$gamma_A),
  gamma_AX = c(dgps$dgp1$params$gamma_AX, dgps$dgp2$params$gamma_AX,
               dgps$dgp4$params$gamma_AX, dgps$dgp5$params$gamma_AX),
  beta_A = c(dgps$dgp1$params$beta_A, dgps$dgp2$params$beta_A,
             dgps$dgp4$params$beta_A, dgps$dgp5$params$beta_A),
  beta_AX = c(dgps$dgp1$params$beta_AX, dgps$dgp2$params$beta_AX,
              dgps$dgp4$params$beta_AX, dgps$dgp5$params$beta_AX),
  beta_S = c(dgps$dgp1$params$beta_S, dgps$dgp2$params$beta_S,
             dgps$dgp4$params$beta_S, dgps$dgp5$params$beta_S),
  beta_SX = c(dgps$dgp1$params$beta_SX, dgps$dgp2$params$beta_SX,
              dgps$dgp4$params$beta_SX, dgps$dgp5$params$beta_SX),
  rho_true = c(dgps$dgp1$rho_true, dgps$dgp2$rho_true,
               dgps$dgp4$rho_true, dgps$dgp5$rho_true),
  PTE = c(dgps$dgp1$PTE_P0, dgps$dgp2$PTE_P0,
          dgps$dgp4$PTE_P0, dgps$dgp5$PTE_P0)
)

# Format PTE (handle NaN for DGP5)
dgp_table$PTE_formatted <- sapply(dgp_table$PTE, function(x) {
  # Handle character "NaN" from YAML, NA, or NaN
  if (is.character(x) && x == "NaN") {
    "---"
  } else if (is.na(x) || (is.numeric(x) && is.nan(x))) {
    "---"
  } else {
    sprintf("%.2f", as.numeric(x))
  }
})

# Format rho_true
dgp_table$rho_formatted <- sprintf("%.3f", dgp_table$rho_true)

# Generate LaTeX table rows
table_rows <- sapply(1:nrow(dgp_table), function(i) {
  row <- dgp_table[i, ]
  sprintf("%s & %s & %s & %s & %s & %s & %s & %s & %s & %s \\\\",
          row$DGP, row$Description, row$gamma_A, row$gamma_AX,
          row$beta_A, row$beta_AX, row$beta_S, row$beta_SX,
          row$rho_formatted, row$PTE_formatted)
})

# Generate LaTeX table (not using glue to avoid escaping issues)
latex_table <- paste0(
'\\begin{table}[ht]
\\centering
\\caption{Data-generating process specifications. All DGPs use $n=10{,}000$,
$\\lambda=0.3$, $p_X = (0.05, 0.25, 0.40, 0.25, 0.05)$,
and $X \\in \\{-2,-1,0,1,2\\}$. Noise variances are $\\sigma_S^2 = \\sigma_Y^2 = 0.25$.}
\\label{tab:dgp-specs}
\\begin{tabular}{lp{6cm}rrrrrrrr}
\\toprule
DGP & Description & $\\gamma_A$ & $\\gamma_{AX}$ & $\\beta_A$ & $\\beta_{AX}$ & $\\beta_S$ & $\\beta_{SX}$ & $\\rho_{\\mathrm{true}}$ & PTE($P_0$) \\\\
\\midrule
', paste(table_rows, collapse = "\n"), '
\\bottomrule
\\end{tabular}
\\end{table}
')

# Write to file
output_file <- "inst/paper/tables/table1_dgp_specs.tex"
cat(latex_table, file = output_file)
cat("Table 1 written to:", output_file, "\n")
