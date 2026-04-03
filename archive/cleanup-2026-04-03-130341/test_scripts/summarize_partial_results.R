#!/usr/bin/env Rscript
# Summarize results so far from comprehensive test

# Check if results file exists
if (!file.exists("flexible_nuisances_high_dim_results.rds")) {
  cat("Results file not yet created. Test still running.\n")
  quit()
}

results <- readRDS("flexible_nuisances_high_dim_results.rds")

cat("========================================\n")
cat("PARTIAL RESULTS SUMMARY\n")
cat("========================================\n\n")

cat("Configurations completed:", nrow(results), "/27\n\n")

# By sample size
cat("COVERAGE BY SAMPLE SIZE:\n")
cat("------------------------\n\n")

for (n in unique(results$n)) {
  cat(sprintf("n = %d:\n", n))
  subset_n <- results[results$n == n, ]

  for (d in sort(unique(subset_n$d))) {
    subset_d <- subset_n[subset_n$d == d, ]
    cat(sprintf("  d=%d: ", d))

    for (method in c("linear", "gam", "rf")) {
      row <- subset_d[subset_d$method == method, ]
      if (nrow(row) > 0) {
        status <- if (row$coverage >= 0.88) "✓" else "⚠"
        cat(sprintf("%s %s:%.0f%% ", status, substr(method,1,3), row$coverage*100))
      }
    }
    cat("\n")
  }
  cat("\n")
}

# Best configurations so far
cat("BEST RESULTS SO FAR:\n")
cat("--------------------\n\n")

best_by_d <- by(results, results$d, function(subset) {
  subset[which.max(subset$coverage), ]
})

for (d in names(best_by_d)) {
  best <- best_by_d[[d]]
  cat(sprintf("d=%s: %.1f%% (%s, n=%d)\n",
              d, best$coverage * 100, best$method, best$n))
}
