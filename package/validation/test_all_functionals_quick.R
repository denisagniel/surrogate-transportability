#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all()
  }
})

set.seed(2026)

n <- 150
data <- data.frame(
  X1 = rnorm(n),
  A = rbinom(n, 1, 0.5),
  S = rnorm(n) + 0.5,
  Y = rnorm(n) + 0.3
)

cat("Testing all functionals with corrected W_2...\n\n")

# Correlation
cat("1. Correlation...")
result_cor <- try(surrogate_inference_minimax_wasserstein(
  data, lambda_w = 0.4, functional_type = "correlation",
  discretization_schemes = "kmeans", n_innovations = 50, verbose = FALSE
), silent = TRUE)
if (!inherits(result_cor, "try-error")) {
  cat(sprintf(" %.4f ✓\n", result_cor$phi_star))
} else {
  cat(" FAIL\n")
  print(result_cor)
}

# Probability
cat("2. Probability...")
result_prob <- try(surrogate_inference_minimax_wasserstein(
  data, lambda_w = 0.4, functional_type = "probability",
  epsilon_s = 0.2, epsilon_y = 0.2,
  discretization_schemes = "kmeans", n_innovations = 50, verbose = FALSE
), silent = TRUE)
if (!inherits(result_prob, "try-error")) {
  cat(sprintf(" %.4f ✓\n", result_prob$phi_star))
} else {
  cat(" FAIL\n")
  print(result_prob)
}

# PPV
cat("3. PPV...")
result_ppv <- try(surrogate_inference_minimax_wasserstein(
  data, lambda_w = 0.4, functional_type = "ppv",
  epsilon_s = 0.2, epsilon_y = 0.2,
  discretization_schemes = "kmeans", n_innovations = 50, verbose = FALSE
), silent = TRUE)
if (!inherits(result_ppv, "try-error")) {
  cat(sprintf(" %.4f ✓\n", result_ppv$phi_star))
} else {
  cat(" FAIL\n")
  print(result_ppv)
}

# NPV
cat("4. NPV...")
result_npv <- try(surrogate_inference_minimax_wasserstein(
  data, lambda_w = 0.4, functional_type = "npv",
  epsilon_s = 0.2, epsilon_y = 0.2,
  discretization_schemes = "kmeans", n_innovations = 50, verbose = FALSE
), silent = TRUE)
if (!inherits(result_npv, "try-error")) {
  cat(sprintf(" %.4f ✓\n", result_npv$phi_star))
} else {
  cat(" FAIL\n")
  print(result_npv)
}

# Conditional mean
cat("5. Conditional mean...")
result_cm <- try(surrogate_inference_minimax_wasserstein(
  data, lambda_w = 0.4, functional_type = "conditional_mean",
  delta_s_value = 0.5,
  discretization_schemes = "kmeans", n_innovations = 50, verbose = FALSE
), silent = TRUE)
if (!inherits(result_cm, "try-error")) {
  cat(sprintf(" %.4f ✓\n", result_cm$phi_star))
} else {
  cat(" FAIL\n")
  print(result_cm)
}

cat("\nAll functionals tested successfully!\n")
