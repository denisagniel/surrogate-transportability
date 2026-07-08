# Load and Examine Simulation Results
# Purpose: Extract key metrics from combined_results.rds for presentation slides

library(yaml)

# Load results
results_path <- "../../cluster/results/combined_results.rds"
results <- readRDS(results_path)

# Load DGP specs for context
dgp_specs <- yaml::read_yaml("../../cluster/config/dgp_specifications.yaml")

# Function to print DGP summary
print_dgp_summary <- function(dgp_name, results, specs) {
  cat("\n", strrep("=", 70), "\n")
  cat(toupper(dgp_name), ":", specs$dgps[[dgp_name]]$name, "\n")
  cat(strrep("=", 70), "\n\n")

  summary <- results[[dgp_name]]$summary

  cat("PARAMETERS:\n")
  cat(sprintf("  True ρ: %.4f\n", specs$dgps[[dgp_name]]$rho_true))

  pte_val <- specs$dgps[[dgp_name]]$PTE_P0
  if (is.null(pte_val) || is.na(pte_val) || is.nan(pte_val) ||
      (is.character(pte_val) && pte_val == "NaN")) {
    cat("  True PTE: NaN (undefined)\n")
  } else {
    cat(sprintf("  True PTE: %.1f%%\n", 100*pte_val))
  }

  if (!is.null(specs$dgps[[dgp_name]]$Delta_Y_P0)) {
    cat(sprintf("  ΔY(P₀): %.4f\n", specs$dgps[[dgp_name]]$Delta_Y_P0))
  }

  cat("\nRESULTS (1000 replications):\n")
  cat(sprintf("  Mean ρ̂: %.4f\n", summary$mean_rho_hat))
  cat(sprintf("  Bias: %.4f\n", summary$bias_rho))
  cat(sprintf("  RMSE: %.4f\n", summary$rmse_rho))
  cat(sprintf("  Coverage: %.1f%%\n", 100*summary$coverage_rho))
  cat(sprintf("  SE calibration: %.3f\n", summary$se_calibration))

  cat("\nINTERPRETATION:\n")
  if (abs(summary$bias_rho) < 0.05) {
    cat("  ✓ Essentially unbiased\n")
  } else {
    cat("  ! Bias present\n")
  }

  if (summary$coverage_rho >= 0.93 && summary$coverage_rho <= 0.97) {
    cat("  ✓ Correct coverage (nominal 95%)\n")
  } else {
    cat(sprintf("  ! Coverage %s nominal\n",
                ifelse(summary$coverage_rho < 0.93, "below", "above")))
  }

  cat("\n")
}

# Print summaries for all DGPs
for (dgp in c("dgp1", "dgp2", "dgp4", "dgp5")) {
  print_dgp_summary(dgp, results, dgp_specs)
}

# Save key metrics for figure generation
key_metrics <- list(
  dgp1 = list(
    rho_true = dgp_specs$dgps$dgp1$rho_true,
    rho_hat = results$dgp1$summary$mean_rho_hat,
    pte = dgp_specs$dgps$dgp1$PTE_P0,
    bias = results$dgp1$summary$bias_rho,
    coverage = results$dgp1$summary$coverage_rho
  ),
  dgp2 = list(
    rho_true = dgp_specs$dgps$dgp2$rho_true,
    rho_hat = results$dgp2$summary$mean_rho_hat,
    pte = dgp_specs$dgps$dgp2$PTE_P0,
    bias = results$dgp2$summary$bias_rho,
    coverage = results$dgp2$summary$coverage_rho
  ),
  dgp4 = list(
    rho_true = dgp_specs$dgps$dgp4$rho_true,
    rho_hat = results$dgp4$summary$mean_rho_hat,
    pte = dgp_specs$dgps$dgp4$PTE_P0,
    bias = results$dgp4$summary$bias_rho,
    coverage = results$dgp4$summary$coverage_rho
  ),
  dgp5 = list(
    rho_true = dgp_specs$dgps$dgp5$rho_true,
    rho_hat = results$dgp5$summary$mean_rho_hat,
    pte = NA,  # Undefined
    bias = results$dgp5$summary$bias_rho,
    coverage = results$dgp5$summary$coverage_rho
  )
)

saveRDS(key_metrics, "key_metrics.rds")
cat("\nKey metrics saved to key_metrics.rds\n")
