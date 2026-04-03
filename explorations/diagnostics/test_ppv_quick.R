# Quick test of PPV functional

library(devtools)
load_all()

# Generate baseline data
set.seed(123)
baseline <- generate_study_data(
  n = 200,
  treatment_effect_surrogate = c(0.3, 0.9),
  treatment_effect_outcome = c(0.2, 0.8)
)

cat("Testing PPV functional...\n\n")

# Test 1: surrogate_inference_if with PPV
cat("Test 1: surrogate_inference_if with functional_type='ppv'\n")
result <- tryCatch({
  surrogate_inference_if(
    baseline,
    lambda = 0.3,
    n_innovations = 100,
    functional_type = "ppv",
    n_future = 500,
    test_alpha = 0.05
  )
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
  NULL
})

if (!is.null(result)) {
  cat(sprintf("  Estimate: %.3f\n", result$estimate))
  cat(sprintf("  95%% CI: [%.3f, %.3f]\n", result$ci_lower, result$ci_upper))
  cat("  ✓ PASS\n")
} else {
  cat("  ✗ FAIL\n")
}

cat("\n")

# Test 2: surrogate_inference_minimax with PPV
cat("Test 2: surrogate_inference_minimax with functional_type='ppv'\n")
result2 <- tryCatch({
  surrogate_inference_minimax(
    baseline,
    lambda = 0.3,
    functional_type = "ppv",
    n_innovations = 100,
    n_dirichlet_grid = 5,
    include_vertices = FALSE,
    verbose = FALSE
  )
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
  NULL
})

if (!is.null(result2)) {
  cat(sprintf("  Bounds: [%.3f, %.3f]\n", result2$phi_star_lower, result2$phi_star))
  cat(sprintf("  Width: %.3f\n", result2$bound_width))
  cat("  ✓ PASS\n")
} else {
  cat("  ✗ FAIL\n")
}

cat("\nAll tests completed!\n")
