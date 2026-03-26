#' Type-Level Treatment Effect Statistics
#'
#' Functions for computing type-level sufficient statistics for closed-form
#' DRO solutions. These functions extract treatment effects at the type level,
#' enabling analytical solutions for linear functionals.
#'
#' @name type_level_effects
NULL

#' Compute Type-Level Treatment Effects
#'
#' Computes treatment effects for each type in a discretized data set.
#' These sufficient statistics enable closed-form solutions for linear
#' functionals in distributional robustness optimization (DRO).
#'
#' @param data Data frame with columns A, S, Y
#' @param bins Integer vector of type assignments (length nrow(data))
#'
#' @return List with components:
#'   \item{tau_s}{Numeric vector (length J): surrogate treatment effect per type}
#'   \item{tau_y}{Numeric vector (length J): outcome treatment effect per type}
#'   \item{n_k}{Integer vector (length J): sample size per type}
#'   \item{p0}{Numeric vector (length J): empirical type distribution}
#'   \item{J}{Integer: number of types}
#'
#' @details
#' For each type j, computes:
#' - tau_s[j] = E[S | A=1, type=j] - E[S | A=0, type=j]
#' - tau_y[j] = E[Y | A=1, type=j] - E[Y | A=0, type=j]
#' - n_k[j] = number of observations in type j
#' - p0[j] = n_k[j] / n (empirical type probability)
#'
#' These statistics are sufficient for computing:
#' - Concordance: phi(q) = sum_j q_j * tau_s[j] * tau_y[j]
#' - And enable closed-form DRO solutions for linear functionals
#'
#' @examples
#' \dontrun{
#' data <- generate_study_data(n = 500)
#' discretization <- discretize_data(data, "quantiles", J_target = 16)
#' type_stats <- compute_type_level_effects(data, discretization$bins)
#'
#' # Check that weighted average matches population effects
#' weighted.mean(type_stats$tau_s, type_stats$p0)
#' }
#'
#' @keywords internal
compute_type_level_effects <- function(data, bins) {

  if (!all(c("A", "S", "Y") %in% names(data))) {
    stop("data must contain columns 'A', 'S', 'Y'")
  }

  if (length(bins) != nrow(data)) {
    stop("bins must have length nrow(data)")
  }

  # Get unique types
  unique_types <- sort(unique(bins))
  J <- length(unique_types)

  # Initialize storage
  tau_s <- numeric(J)
  tau_y <- numeric(J)
  n_k <- integer(J)

  # Compute treatment effects for each type
  for (idx in seq_along(unique_types)) {
    j <- unique_types[idx]

    # Extract data for this type
    type_j_data <- data[bins == j, ]
    n_k[idx] <- nrow(type_j_data)

    # Skip if type is empty or has no treated/control units
    if (n_k[idx] == 0) {
      tau_s[idx] <- NA_real_
      tau_y[idx] <- NA_real_
      next
    }

    treated <- type_j_data$A == 1
    control <- type_j_data$A == 0

    # Check if type has both treated and control units
    if (sum(treated) == 0 || sum(control) == 0) {
      # Use global average as fallback
      tau_s[idx] <- mean(data$S[data$A == 1]) - mean(data$S[data$A == 0])
      tau_y[idx] <- mean(data$Y[data$A == 1]) - mean(data$Y[data$A == 0])
      warning(sprintf("Type %d has no %s units, using global average",
                      j, if (sum(treated) == 0) "treated" else "control"))
    } else {
      # Compute type-specific treatment effects
      tau_s[idx] <- mean(type_j_data$S[treated]) - mean(type_j_data$S[control])
      tau_y[idx] <- mean(type_j_data$Y[treated]) - mean(type_j_data$Y[control])
    }
  }

  # Remove types with NA effects (if any)
  valid <- !is.na(tau_s) & !is.na(tau_y)
  if (!all(valid)) {
    warning(sprintf("Removing %d types with NA treatment effects", sum(!valid)))
    tau_s <- tau_s[valid]
    tau_y <- tau_y[valid]
    n_k <- n_k[valid]
    J <- sum(valid)
  }

  # Compute empirical type distribution
  n <- sum(n_k)
  p0 <- n_k / n

  list(
    tau_s = tau_s,
    tau_y = tau_y,
    n_k = n_k,
    p0 = p0,
    J = J
  )
}


#' Validate Type-Level Statistics
#'
#' Checks that type-level statistics are valid and internally consistent.
#'
#' @param type_stats Output from compute_type_level_effects()
#'
#' @return Logical: TRUE if valid, error otherwise
#'
#' @details
#' Validates:
#' - All vectors have length J
#' - p0 sums to 1
#' - p0 is non-negative
#' - No NA values in critical fields
#'
#' @keywords internal
validate_type_level_stats <- function(type_stats) {

  J <- type_stats$J

  # Check dimensions
  if (length(type_stats$tau_s) != J ||
      length(type_stats$tau_y) != J ||
      length(type_stats$p0) != J) {
    stop("Inconsistent dimensions in type_level_stats")
  }

  # Check p0 is valid probability distribution
  if (any(type_stats$p0 < 0)) {
    stop("type_stats$p0 contains negative values")
  }

  if (abs(sum(type_stats$p0) - 1.0) > 1e-8) {
    stop(sprintf("type_stats$p0 does not sum to 1 (sum = %f)", sum(type_stats$p0)))
  }

  # Check for NAs in critical fields
  if (any(is.na(type_stats$tau_s)) || any(is.na(type_stats$tau_y))) {
    stop("type_stats contains NA values in tau_s or tau_y")
  }

  TRUE
}


#' Compute Concordance from Type-Level Statistics
#'
#' Computes concordance functional E[delta_S * delta_Y] from type-level
#' treatment effects and type distribution.
#'
#' @param type_stats Output from compute_type_level_effects()
#' @param q Numeric vector (length J): type distribution (defaults to p0)
#'
#' @return Numeric: concordance value
#'
#' @details
#' Concordance at type level:
#'   phi(q) = sum_j q_j * tau_s[j] * tau_y[j]
#'
#' This is LINEAR in q, which enables closed-form DRO solutions.
#'
#' @keywords internal
compute_concordance_from_types <- function(type_stats, q = NULL) {

  validate_type_level_stats(type_stats)

  # Use p0 if q not specified
  if (is.null(q)) {
    q <- type_stats$p0
  }

  # Check q is valid
  if (length(q) != type_stats$J) {
    stop("q must have length J")
  }

  if (any(q < 0) || abs(sum(q) - 1.0) > 1e-8) {
    stop("q must be a valid probability distribution")
  }

  # Compute concordance: E_q[tau_s * tau_y]
  sum(q * type_stats$tau_s * type_stats$tau_y)
}
