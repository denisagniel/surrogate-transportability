#!/usr/bin/env Rscript
# Test if function is available

cat("Loading package...\n")
suppressMessages(library(surrogateTransportability))

cat("Checking for function...\n")
if (exists("tv_ball_correlation_IF_adaptive")) {
  cat("✓ Function exists!\n")
  cat("Function signature:\n")
  print(args(tv_ball_correlation_IF_adaptive))
} else {
  cat("✗ Function NOT found!\n")
  cat("\nSearching for similar functions:\n")
  funs <- ls("package:surrogateTransportability")
  tv_funs <- grep("tv_", funs, value = TRUE)
  print(tv_funs)
}

cat("\nPackage version:\n")
print(packageVersion("surrogateTransportability"))

cat("\nPackage installation path:\n")
print(.libPaths())
