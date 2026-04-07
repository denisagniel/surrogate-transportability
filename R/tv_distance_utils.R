#' Compute Total Variation Distance Between Two Probability Distributions
#'
#' Computes the total variation (TV) distance between two discrete probability
#' distributions Q and P0. The TV distance is defined as:
#' \deqn{d_{TV}(Q, P_0) = \frac{1}{2} \sum_{i} |q_i - p_{0,i}|}
#'
#' This distance measures the maximum difference in probability that the two
#' distributions assign to any event, and ranges from 0 (identical distributions)
#' to 1 (disjoint support).
#'
#' @param Q Numeric vector representing probability distribution Q. Must sum to 1
#'   and have all non-negative entries.
#' @param P0 Numeric vector representing reference distribution P0. Must sum to 1,
#'   have all non-negative entries, and have the same length as Q.
#'
#' @return A numeric value in [0, 1] representing the TV distance between Q and P0.
#'
#' @details
#' The total variation distance satisfies:
#' \itemize{
#'   \item Non-negativity: \eqn{d_{TV}(Q, P_0) \ge 0}
#'   \item Identity: \eqn{d_{TV}(Q, P_0) = 0} iff Q = P0
#'   \item Symmetry: \eqn{d_{TV}(Q, P_0) = d_{TV}(P_0, Q)}
#'   \item Triangle inequality: \eqn{d_{TV}(Q, R) \le d_{TV}(Q, P_0) + d_{TV}(P_0, R)}
#' }
#'
#' @section Computational Notes:
#' The implementation uses sum(abs(Q - P0)) / 2 which is numerically stable for
#' discrete distributions on finite support. For very small probabilities,
#' standard floating-point precision is sufficient.
#'
#' @examples
#' # Identical distributions
#' P0 <- c(0.3, 0.5, 0.2)
#' compute_tv_distance(P0, P0)  # Returns 0
#'
#' # Disjoint support
#' Q1 <- c(1, 0, 0)
#' Q2 <- c(0, 1, 0)
#' compute_tv_distance(Q1, Q2)  # Returns 1
#'
#' # Partial overlap
#' Q <- c(0.4, 0.4, 0.2)
#' compute_tv_distance(Q, P0)  # Returns 0.1
#'
#' @seealso
#' \code{\link{verify_tv_constraint}} for checking if TV distance satisfies a bound,
#' \code{\link{generate_tv_ball_point}} for constructively generating distributions
#' within a TV ball.
#'
#' @export
compute_tv_distance <- function(Q, P0) {
  # Input validation
  if (!is.numeric(Q) || !is.numeric(P0)) {
    stop("Q and P0 must be numeric vectors")
  }

  if (length(Q) != length(P0)) {
    stop(sprintf(
      "Q and P0 must have the same length (Q: %d, P0: %d)",
      length(Q), length(P0)
    ))
  }

  if (any(Q < 0) || any(P0 < 0)) {
    stop("Q and P0 must have all non-negative entries")
  }

  # Check normalization (with tolerance for floating-point errors)
  tol <- 1e-10
  sum_Q <- sum(Q)
  sum_P0 <- sum(P0)

  if (abs(sum_Q - 1) > tol) {
    stop(sprintf(
      "Q must sum to 1 (current sum: %.10f)",
      sum_Q
    ))
  }

  if (abs(sum_P0 - 1) > tol) {
    stop(sprintf(
      "P0 must sum to 1 (current sum: %.10f)",
      sum_P0
    ))
  }

  # Compute TV distance
  tv_dist <- sum(abs(Q - P0)) / 2

  return(tv_dist)
}


#' Verify TV Distance Constraint for Innovation Mechanism
#'
#' Checks whether the total variation distance between Q and P0 satisfies the
#' constraint \eqn{d_{TV}(Q, P_0) \le \lambda}, as required by the innovation
#' mechanism Q = (1-λ)P0 + λP̃. Returns detailed diagnostics.
#'
#' @param Q Numeric vector representing the generated distribution Q. Must sum to 1
#'   and have all non-negative entries.
#' @param P0 Numeric vector representing reference distribution P0. Must sum to 1,
#'   have all non-negative entries, and have the same length as Q.
#' @param lambda Numeric value in [0, 1] representing the mixing parameter or
#'   maximum allowed TV distance.
#' @param tolerance Numeric tolerance for constraint satisfaction (default: 1e-10).
#'   The constraint is considered satisfied if tv_distance <= lambda + tolerance.
#'
#' @return A list with the following components:
#'   \item{satisfies_constraint}{Logical indicating whether the constraint is satisfied}
#'   \item{tv_distance}{Numeric TV distance between Q and P0}
#'   \item{lambda}{The constraint bound (input parameter)}
#'   \item{violation}{Numeric amount by which constraint is violated (max(0, tv - lambda))}
#'   \item{margin}{Numeric margin by which constraint is satisfied (lambda - tv, can be negative)}
#'
#' @details
#' For the innovation mechanism Q = (1-λ)P0 + λP̃, the TV distance satisfies:
#' \deqn{d_{TV}(Q, P_0) = d_{TV}((1-\lambda)P_0 + \lambda\tilde{P}, P_0) = \lambda \cdot d_{TV}(\tilde{P}, P_0) \le \lambda}
#'
#' The inequality becomes an equality when P̃ has disjoint support from P0.
#' This function verifies this constraint holds and provides diagnostics for
#' debugging when it does not.
#'
#' @section Use Cases:
#' \itemize{
#'   \item Verify generated future studies satisfy TV constraint
#'   \item Debug innovation mechanism implementation
#'   \item Quality control in simulation studies
#'   \item Validate theoretical properties empirically
#' }
#'
#' @examples
#' # Example 1: Constraint satisfied
#' P0 <- c(0.3, 0.5, 0.2)
#' P_tilde <- c(0.6, 0.1, 0.3)
#' lambda <- 0.4
#' Q <- (1 - lambda) * P0 + lambda * P_tilde
#'
#' result <- verify_tv_constraint(Q, P0, lambda)
#' result$satisfies_constraint  # TRUE
#' result$tv_distance           # Should be <= 0.4
#'
#' # Example 2: Constraint violated (Q generated differently)
#' Q_bad <- c(0.1, 0.2, 0.7)  # Not from innovation mechanism
#' result_bad <- verify_tv_constraint(Q_bad, P0, lambda = 0.2)
#' result_bad$satisfies_constraint  # May be FALSE
#' result_bad$violation             # Positive if violated
#'
#' @seealso
#' \code{\link{compute_tv_distance}} for computing TV distance,
#' \code{\link{generate_future_study}} for the innovation mechanism implementation.
#'
#' @export
verify_tv_constraint <- function(Q, P0, lambda, tolerance = 1e-10) {
  # Input validation
  if (!is.numeric(lambda) || length(lambda) != 1) {
    stop("lambda must be a single numeric value")
  }

  if (lambda < 0 || lambda > 1) {
    stop(sprintf(
      "lambda must be in [0, 1] (current value: %.4f)",
      lambda
    ))
  }

  if (!is.numeric(tolerance) || length(tolerance) != 1 || tolerance < 0) {
    stop("tolerance must be a single non-negative numeric value")
  }

  # Compute TV distance (this also validates Q and P0)
  tv_dist <- compute_tv_distance(Q, P0)

  # Check constraint with tolerance
  satisfies <- tv_dist <= lambda + tolerance

  # Compute violation and margin
  violation <- max(0, tv_dist - lambda)
  margin <- lambda - tv_dist

  # Return diagnostics
  list(
    satisfies_constraint = satisfies,
    tv_distance = tv_dist,
    lambda = lambda,
    violation = violation,
    margin = margin
  )
}


#' Generate Distribution in TV Ball via Constructive Algorithm
#'
#' Given a target distribution Q_target in the TV ball B_λ(P0), this function
#' constructively solves for the mixing parameter λ_actual and innovation
#' distribution P̃ such that Q_target = (1-λ_actual)P0 + λ_actual·P̃.
#'
#' This implements the constructive proof of existence in Theorem 5(a): for any
#' Q0 in the TV ball, there exists (λ', P̃') such that Q0 can be expressed as
#' the innovation mechanism mixture.
#'
#' @param P0 Numeric vector representing reference distribution P0. Must sum to 1,
#'   have all non-negative entries, and all entries must be strictly positive
#'   for the inversion to be well-defined.
#' @param Q_target Numeric vector representing target distribution in TV ball.
#'   Must sum to 1, have all non-negative entries, same length as P0, and
#'   satisfy d_TV(Q_target, P0) <= lambda_max.
#' @param lambda_max Numeric value in [0, 1] representing the maximum TV distance
#'   (radius of TV ball). Default is 1 (unrestricted).
#'
#' @return A list with the following components:
#'   \item{P_tilde}{Numeric vector representing the solved innovation distribution}
#'   \item{lambda_actual}{Numeric value representing the solved mixing parameter}
#'   \item{Q_reconstructed}{Numeric vector: (1-λ_actual)P0 + λ_actual·P̃ (should match Q_target)}
#'   \item{reconstruction_error}{Numeric: max absolute difference between Q_reconstructed and Q_target}
#'   \item{tv_distance}{Numeric: d_TV(Q_target, P0)}
#'   \item{satisfies_constraint}{Logical: whether tv_distance <= lambda_max}
#'   \item{algorithm_successful}{Logical: whether reconstruction error < tolerance and P_tilde is valid}
#'
#' @details
#' The algorithm works as follows:
#' \enumerate{
#'   \item Check that d_TV(Q_target, P0) <= lambda_max (target must be in TV ball)
#'   \item Find minimum λ such that P̃ = (Q_target - (1-λ)P0) / λ has all non-negative entries
#'   \item The minimum λ is: λ = max over i where Q_target[i] < P0[i] of (P0[i] - Q_target[i]) / P0[i]
#'   \item Solve for P̃ using this λ
#'   \item Verify sum(P̃) = 1 and reconstruction: Q_reconstructed = (1-λ)P0 + λ·P̃ ≈ Q_target
#' }
#'
#' Special cases:
#' \itemize{
#'   \item If λ_actual = 0 (Q_target = P0), returns P_tilde = P0, lambda_actual = 0
#'   \item If λ_actual > lambda_max, returns with satisfies_constraint = FALSE
#'   \item If P̃ has negative entries (numerical issues), returns with algorithm_successful = FALSE
#' }
#'
#' @section Numerical Considerations:
#' The inversion P̃ = (Q_target - (1-λ)P0) / λ can be numerically unstable when:
#' \itemize{
#'   \item λ is very small (near 0) - division by small number
#'   \item P0 has near-zero entries - can lead to negative P̃ entries
#'   \item Q_target is very close to P0 - amplification of floating-point errors
#' }
#'
#' A tolerance of 1e-10 is used for validation. If numerical issues arise,
#' algorithm_successful will be FALSE.
#'
#' @examples
#' # Example 1: Target in TV ball
#' P0 <- c(0.3, 0.5, 0.2)
#' Q_target <- c(0.4, 0.4, 0.2)
#'
#' result <- generate_tv_ball_point(P0, Q_target, lambda_max = 0.5)
#' result$satisfies_constraint      # TRUE
#' result$algorithm_successful      # TRUE
#' result$reconstruction_error      # Near 0
#'
#' # Verify: Q_reconstructed should match Q_target
#' max(abs(result$Q_reconstructed - Q_target))  # < 1e-10
#'
#' # Example 2: Target outside TV ball
#' Q_far <- c(0.9, 0.05, 0.05)
#' result_far <- generate_tv_ball_point(P0, Q_far, lambda_max = 0.2)
#' result_far$satisfies_constraint  # FALSE (target too far)
#'
#' @seealso
#' \code{\link{compute_tv_distance}} for TV distance computation,
#' \code{\link{verify_tv_constraint}} for checking TV constraints.
#'
#' @references
#' See Theorem 5 in the package manuscript for the formal proof of existence
#' and the constructive algorithm.
#'
#' @export
generate_tv_ball_point <- function(P0, Q_target, lambda_max = 1) {
  # Input validation
  if (!is.numeric(P0) || !is.numeric(Q_target)) {
    stop("P0 and Q_target must be numeric vectors")
  }

  if (length(P0) != length(Q_target)) {
    stop(sprintf(
      "P0 and Q_target must have the same length (P0: %d, Q_target: %d)",
      length(P0), length(Q_target)
    ))
  }

  if (any(P0 <= 0)) {
    stop("P0 must have all strictly positive entries for inversion to be well-defined")
  }

  if (any(Q_target < 0)) {
    stop("Q_target must have all non-negative entries")
  }

  # Check normalization
  tol <- 1e-10
  if (abs(sum(P0) - 1) > tol) {
    stop(sprintf("P0 must sum to 1 (current sum: %.10f)", sum(P0)))
  }

  if (abs(sum(Q_target) - 1) > tol) {
    stop(sprintf("Q_target must sum to 1 (current sum: %.10f)", sum(Q_target)))
  }

  if (!is.numeric(lambda_max) || length(lambda_max) != 1) {
    stop("lambda_max must be a single numeric value")
  }

  if (lambda_max < 0 || lambda_max > 1) {
    stop(sprintf(
      "lambda_max must be in [0, 1] (current value: %.4f)",
      lambda_max
    ))
  }

  # Step 1: Compute TV distance and check if target is in TV ball
  tv_dist <- compute_tv_distance(Q_target, P0)
  satisfies_constraint <- tv_dist <= lambda_max + tol

  # Step 2: Handle special case Q_target = P0
  if (tv_dist < tol) {
    return(list(
      P_tilde = P0,
      lambda_actual = 0,
      Q_reconstructed = P0,
      reconstruction_error = 0,
      tv_distance = 0,
      satisfies_constraint = TRUE,
      algorithm_successful = TRUE
    ))
  }

  # Step 3: Find minimum λ such that P̃ = (Q_target - (1-λ)P0) / λ has non-negative entries
  # For P̃[i] >= 0, we need: Q_target[i] >= (1-λ)P0[i]
  # Rearranging: Q_target[i] >= P0[i] - λ*P0[i]
  # λ*P0[i] >= P0[i] - Q_target[i]
  # λ >= (P0[i] - Q_target[i]) / P0[i]  when Q_target[i] < P0[i]
  #
  # The minimum λ is the maximum of these lower bounds

  # Find indices where Q_target < P0
  needs_increase <- Q_target < P0

  if (any(needs_increase)) {
    # Compute minimum λ for each such index
    lambda_mins <- (P0[needs_increase] - Q_target[needs_increase]) / P0[needs_increase]
    lambda_actual <- max(lambda_mins)
  } else {
    # If Q_target >= P0 everywhere, any small λ works
    # Use TV distance as a reasonable choice
    lambda_actual <- tv_dist
  }

  # Ensure lambda_actual is at least as large as necessary (add small buffer for numerics)
  lambda_actual <- lambda_actual * (1 + tol)

  # Step 4: Solve for P̃ = (Q_target - (1-λ)P0) / λ
  P_tilde <- (Q_target - (1 - lambda_actual) * P0) / lambda_actual

  # Step 5: Clean up small numerical errors
  # Clip small negative values to zero
  P_tilde[P_tilde < 0 & P_tilde >= -tol] <- 0

  # Re-normalize to ensure sum = 1
  if (abs(sum(P_tilde) - 1) > tol) {
    P_tilde <- P_tilde / sum(P_tilde)
  }

  # Verify P̃ is a valid probability distribution
  P_tilde_valid <- all(P_tilde >= -tol) && abs(sum(P_tilde) - 1) < tol

  # Step 6: Reconstruct Q and verify
  Q_reconstructed <- (1 - lambda_actual) * P0 + lambda_actual * P_tilde
  reconstruction_error <- max(abs(Q_reconstructed - Q_target))

  algorithm_successful <- P_tilde_valid && reconstruction_error < tol

  # Return results
  list(
    P_tilde = P_tilde,
    lambda_actual = lambda_actual,
    Q_reconstructed = Q_reconstructed,
    reconstruction_error = reconstruction_error,
    tv_distance = tv_dist,
    satisfies_constraint = satisfies_constraint,
    algorithm_successful = algorithm_successful
  )
}
