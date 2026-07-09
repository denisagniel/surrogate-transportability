# Quick DGP checks: truncation, closed-form truth vs Monte Carlo.
root <- "explorations/2026-07-09_a5-elbow-validation"
source(file.path(root, "config/grid.R"))
source(file.path(root, "R/dgp_smooth.R"))
set.seed(20260709)

cat("=== truncation of psi_SS = sum j^-(2s+1) vs Riemann zeta(2s+1) ===\n")
for (s in c(0.2, 0.4, 0.5, 0.8)) {
  ex <- 2 * s + 1
  zeta <- sum((seq_len(1e6))^(-ex))            # ~infinite reference
  cat(sprintf("  s=%.2f (exp=%.2f) zeta=%.4f | ", s, ex, zeta))
  for (J in c(200L, 800L, 2000L, 5000L)) {
    b <- cate_basis(s, 1, J)
    cat(sprintf("J%d=%.4f ", J, psi_true(b, b)))
  }
  cat("\n")
}

cat("\n=== closed-form (truncated) psi vs MC, per design, large n ===\n")
for (i in seq_len(nrow(STAGE1_DESIGN))) {
  cfg <- STAGE1_DESIGN[i, ]
  d <- generate_stage1(if (cfg$d == 1L) 2e5 else 1e5, cfg)
  tS <- attr(d, "tau_S"); tY <- attr(d, "tau_Y")
  cat(sprintf("  %-9s d=%d s=(%.1f,%.1f) | psi_SY closed=%.4f MC=%.4f | psi_SS closed=%.4f MC=%.4f\n",
              cfg$design, cfg$d, cfg$s_S, cfg$s_Y,
              attr(d, "psi_SY"), mean(tS * tY),
              attr(d, "psi_SS"), mean(tS^2)))
}
