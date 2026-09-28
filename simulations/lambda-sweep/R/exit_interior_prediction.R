#!/usr/bin/env Rscript
# =============================================================================
# exit_interior_prediction.R -- MCMC-free prediction of the lambda-profile's
# direction at the interior edge
# =============================================================================
# Computes, for each canonical DGP, the quantity whose SIGN Proposition
# "First-order exit from the interior regime" (inst/paper/theory.tex,
# Section sec:exit-interior) says determines whether Theta(P_0, lambda) rises or
# falls as the ball is widened past lambda = p_min:
#
#   d+/dlambda Theta |_{lambda = p_min} = (C_K / p_min) * sum_{k in K*} varpi(k),
#   varpi(k) = (r_K / 2) (z_S(k)^2 + z_Y(k)^2) - z_S(k) z_Y(k),
#
# with C_K > 0 depending only on K (never evaluated in closed form, so only the
# SIGN and cross-design ratios are available), K* = argmin_k p_0(k),
# r_K = Corr_K(tau_S, tau_Y), c_a(k) = tau_a(k) - mean(tau_a), and
# z_a(k) = c_a(k) / ||c_a||_2.
#
# This is the paper's "one concrete, MCMC-free diagnostic ... computable before
# running any hit-and-run sampling" (main.tex, "Interpreting lambda"). Running it
# BEFORE the sweep gives the sweep a falsifiable prediction to be checked against,
# rather than a picture to be admired.
#
# Usage (from the study directory):  Rscript R/exit_interior_prediction.R
# Run time: < 1 s (no sampling, no data).
# =============================================================================

suppressPackageStartupMessages(library(surrogateTransportability))

STUDY_DIR <- if (basename(getwd()) == "R") ".." else "."
source(file.path(STUDY_DIR, "R", "cell_cates.R"))

#' First-order exit-from-interior diagnostic for one canonical DGP
#'
#' @param dgp Character canonical id ("dgp1", "dgp2", "dgp4", "dgp5").
#' @return A one-row data frame: interior value r_K, p_min, the minimizing cells,
#'   the summed influence-function weight over them, and the predicted sign of
#'   dTheta/dlambda at the interior edge.
exit_interior_diagnostic <- function(dgp) {
  cc <- cell_cates(dgp)

  c_S <- cc$tau_S - mean(cc$tau_S)          # centred cell CATEs (unweighted mean, per Corr_K)
  c_Y <- cc$tau_Y - mean(cc$tau_Y)
  z_S <- c_S / sqrt(sum(c_S^2))             # standardized: ||z||_2 = 1
  z_Y <- c_Y / sqrt(sum(c_Y^2))
  r_K <- sum(z_S * z_Y)                     # == Corr_K(tau_S, tau_Y)

  # varpi(k): negative of the classical Pearson-correlation influence function
  # at cell k's standardized CATEs (Devlin-Gnanadesikan-Kettenring 1975).
  varpi <- (r_K / 2) * (z_S^2 + z_Y^2) - z_S * z_Y

  p_min  <- min(cc$p0)
  K_star <- which(abs(cc$p0 - p_min) < 1e-12)
  slope_sign_stat <- sum(varpi[K_star])

  data.frame(
    dgp          = dgp,
    K            = length(cc$x),
    r_K_interior = r_K,
    p_min        = p_min,
    K_star_cells = paste(sprintf("x=%g", cc$x[K_star]), collapse = ", "),
    sum_varpi    = slope_sign_stat,
    varpi_total  = sum(varpi),        # must be ~0: a correlation's IF integrates to zero
    prediction   = if (abs(slope_sign_stat) < 1e-10) "flat to first order"
                   else if (slope_sign_stat > 0) "Theta RISES past p_min"
                   else "Theta FALLS past p_min",
    stringsAsFactors = FALSE
  )
}

if (sys.nframe() == 0L) {
  tab <- do.call(rbind, lapply(c("dgp1", "dgp2", "dgp4", "dgp5"), exit_interior_diagnostic))
  tab$r_K_interior <- round(tab$r_K_interior, 6)
  tab$sum_varpi    <- signif(tab$sum_varpi, 4)
  tab$varpi_total  <- signif(tab$varpi_total, 3)
  print(tab, row.names = FALSE)

  out <- file.path(STUDY_DIR, "results", "exit_interior_prediction.rds")
  readr::write_rds(tab, out)
  cat(sprintf("\nwrote %s\n", out))
}
