#!/usr/bin/env Rscript
if (!requireNamespace("transport", quietly = TRUE)) {
  cat("Installing transport package...\n")
  install.packages("transport", repos = "https://cloud.r-project.org")
} else {
  cat("transport package already installed.\n")
}

if (!requireNamespace("lpSolve", quietly = TRUE)) {
  cat("Installing lpSolve package...\n")
  install.packages("lpSolve", repos = "https://cloud.r-project.org")
} else {
  cat("lpSolve package already installed.\n")
}
