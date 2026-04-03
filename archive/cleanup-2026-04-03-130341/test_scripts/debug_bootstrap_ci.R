#!/usr/bin/env Rscript
# Debug bootstrap_ci_sample_splitting return value

library(tidyverse)
library(here)

devtools::load_all(here("package"))

set.seed(123)
n <- 500

X1 <- rnorm(n)
X2 <- rnorm(n)
A <- rbinom(n, 1, 0.5)

tau_s <- 0.3 + 0.2 * X1 - 0.1 * X2
tau_y <- 0.4 + 0.3 * X1 + 0.1 * X2

S <- tau_s * A + 0.5 + 0.2 * X1 + rnorm(n, sd = 0.3)
Y <- tau_y * A + 0.6 + 0.3 * X2 + rnorm(n, sd = 0.4)

data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

cat("Testing bootstrap_ci_sample_splitting...\n\n")

result <- bootstrap_ci_sample_splitting(
  data = data,
  covariates = c("X1", "X2"),
  lambda_w = 0.5,
  split_ratio = 0.5,
  tau_method = "kernel",
  cross_fit = TRUE,
  n_bootstrap = 10,  # Just 10 for quick test
  confidence_level = 0.95,
  seed = 123,
  verbose = TRUE
)

cat("\n\nResult structure:\n")
str(result)

cat("\n\nResult names:\n")
print(names(result))

cat("\n\nChecking key fields:\n")
cat("phi_star:", result$phi_star, "\n")
cat("ci_lower:", result$ci_lower, "\n")
cat("ci_upper:", result$ci_upper, "\n")
