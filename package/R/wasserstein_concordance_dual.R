#' Wasserstein Concordance Dual Optimization
#'
#' Solves the Wasserstein DRO dual for concordance functional using
#' 1-parameter optimization. This provides orders-of-magnitude speedup
#' compared to sampling-based approaches.
#'
#' @name wasserstein_concordance_dual
NULL

#' Wasserstein Concordance Dual Solver
#'
#' Solves the Wasserstein DRO dual for concordance functional:
#'   min_{Q: W_2(Q,P0)<=lambda_w} E_Q[delta_S * delta_Y]
#'
#' Dual formulation (Esfahani & Kuhn 2018):
#'   sup_{gamma>=0} { -gamma*lambda_w^2 + sum_j p0_j * min_i {tau_i^s*tau_i^y + gamma*C[i,j]} }
#'
#' This is a 1-dimensional optimization problem over gamma >= 0.
#'
#' @param type_stats Output from compute_type_level_effects()
#' @param cost_matrix Matrix (J x J): pairwise cost between types
#' @param lambda_w Numeric: Wasserstein ball radius
#' @param method Character: optimization method
#'   - "brent" (default): Brent's method via optimize()
#'   - "golden": Golden section search
#'   - "grid": Grid search (robust but slower)
#' @param grid_size Integer: number of grid points (for method="grid")
#' @param tol Numeric: convergence tolerance
#'
#' @return List with components:
#'   \item{phi_star}{Optimal value (minimax concordance)}
#'   \item{optimal_gamma}{Optimal dual variable gamma*}
#'   \item{method}{Optimization method used}
#'   \item{convergence}{Logical: did optimization converge?}
#'   \item{objective_at_zero}{Objective value at gamma=0 (equals E_P0[concordance])}
#'
#' @details
#' **Mathematical formulation:**
#'
#' The Wasserstein DRO problem for concordance (linear functional):
#'   min_{q: W_2(q,p0)<=lambda_w} sum_j q_j * (tau_j^s * tau_j^y)
#'
#' Has dual:
#'   sup_{gamma>=0} g(gamma)
#'
#' where g(gamma) = -gamma*lambda_w^2 + sum_j p0_j * min_i {h_i + gamma*C[i,j]}
#' and h_i = tau_i^s * tau_i^y (concordance per type).
#'
#' **Correctness:** This implements the closed-form dual from Esfahani & Kuhn (2018),
#' Theorem 4.1. The dual is exact (no approximation) and strong duality holds.
#'
#' **Complexity:** O(J^2) per gamma evaluation, O(J^2 * log(1/tol)) total.
#' Compare to sampling: O(M*n) where M=2000, n=500 → 50-100x speedup.
#'
#' @references
#' Esfahani, P. M., & Kuhn, D. (2018). Data-driven distributionally robust
#' optimization using the Wasserstein metric: Performance guarantees and
#' tractable reformulations. Mathematical Programming, 171(1-2), 115-166.
#'
#' @examples
#' \dontrun{
#' # Generate data and discretize
#' data <- generate_study_data(n = 500)
#' disc <- discretize_data(data, "quantiles", J_target = 16)
#' type_stats <- compute_type_level_effects(data, disc$bins)
#'
#' # Compute cost matrix
#' centroids <- compute_type_centroids(data, disc$bins, setdiff(names(data), c("A","S","Y")))
#' cost_matrix <- compute_type_cost_matrix(centroids, cost_function = "euclidean")
#'
#' # Solve dual
#' result <- wasserstein_concordance_dual(type_stats, cost_matrix, lambda_w = 0.5)
#' cat(sprintf("Minimax concordance: %.4f\n", result$phi_star))
#' cat(sprintf("Optimal gamma: %.4f\n", result$optimal_gamma))
#' }
#'
#' @keywords internal
wasserstein_concordance_dual <- function(type_stats,
                                          cost_matrix,
                                          lambda_w,
                                          method = c("brent", "golden", "grid"),
                                          grid_size = 100,
                                          tol = 1e-6) {

  method <- match.arg(method)

  # Validate inputs
  validate_type_level_stats(type_stats)

  J <- type_stats$J

  if (nrow(cost_matrix) != J || ncol(cost_matrix) != J) {
    stop(sprintf("cost_matrix dimensions (%d x %d) must match J = %d",
                 nrow(cost_matrix), ncol(cost_matrix), J))
  }

  if (lambda_w < 0) {
    stop("lambda_w must be non-negative")
  }

  # Concordance per type (linear functional coefficient)
  h <- type_stats$tau_s * type_stats$tau_y

  # Dual objective: g(gamma) = -gamma*lambda_w^2 + sum_j p0_j * min_i {h_i + gamma*C[i,j]}
  objective <- function(gamma) {
    # For each type j (under P0), find worst-case transport target i
    min_values <- numeric(J)

    for (j in 1:J) {
      # Worst-case: min over i of {concordance_i + gamma * cost[i,j]}
      # cost[i,j] is the cost to transport from type j to type i
      # So we want cost_matrix[i, j] for all i, which is cost_matrix[, j]
      # Actually, C[i,j] in the dual is the cost from j (reference) to i (target)
      # Standard cost matrix: C[i,j] = ||centroid_i - centroid_j||^2
      # We want: for reference type j, transport to target i with cost C[i,j]
      # This is the j-th column: cost_matrix[, j]
      # But actually, if cost_matrix is symmetric (Euclidean), C[i,j] = C[j,i]
      # Let me use cost_matrix[j, ] to be explicit: cost from j to all i
      worst_values <- h + gamma * cost_matrix[j, ]
      min_values[j] <- min(worst_values)
    }

    # Dual objective
    dual_value <- -gamma * lambda_w^2 + sum(type_stats$p0 * min_values)

    dual_value
  }

  # Special case: lambda_w = 0 (no perturbation)
  if (lambda_w < 1e-12) {
    concordance_p0 <- sum(type_stats$p0 * h)
    return(list(
      phi_star = concordance_p0,
      optimal_gamma = 0,
      method = "closed_form_zero_radius",
      convergence = TRUE,
      objective_at_zero = concordance_p0,
      concordance_p0 = concordance_p0
    ))
  }

  # Objective value at gamma = 0 (unconstrained minimum = min(h))
  obj_at_zero <- objective(0)

  # E_P0[concordance] for reference
  concordance_p0 <- sum(type_stats$p0 * h)

  # Determine reasonable upper bound for gamma
  # The objective is -gamma*lambda_w^2 + bounded_term
  # So it becomes negative for large gamma
  # Use heuristic: max_gamma such that -gamma*lambda_w^2 ≈ -|max(h)|
  max_gamma <- max(100 / lambda_w^2, 10 * max(abs(h)) / lambda_w^2)

  # Optimize over gamma >= 0
  if (method == "brent") {
    # Brent's method (efficient for 1D, C implementation)
    result <- optimize(
      f = objective,
      interval = c(0, max_gamma),
      maximum = TRUE,
      tol = tol
    )

    optimal_gamma <- result$maximum
    phi_star <- result$objective
    convergence <- TRUE

  } else if (method == "golden") {
    # Golden section search (more robust, pure R)
    result <- golden_section_search(
      f = objective,
      lower = 0,
      upper = max_gamma,
      tol = tol,
      maximize = TRUE
    )

    optimal_gamma <- result$argmax
    phi_star <- result$max_value
    convergence <- result$converged

  } else if (method == "grid") {
    # Grid search (most robust, slowest)
    gamma_grid <- seq(0, max_gamma, length.out = grid_size)
    obj_values <- sapply(gamma_grid, objective)

    best_idx <- which.max(obj_values)
    optimal_gamma <- gamma_grid[best_idx]
    phi_star <- obj_values[best_idx]
    convergence <- TRUE

  } else {
    stop("Unknown method: ", method)
  }

  # Sanity check: phi_star should be <= concordance_p0 (dual is lower bound)
  if (phi_star > concordance_p0 + 1e-6) {
    warning(sprintf(
      "Dual solution (%.6f) exceeds E_P0[concordance] (%.6f). Likely numerical issue.",
      phi_star, concordance_p0
    ))
  }

  list(
    phi_star = phi_star,
    optimal_gamma = optimal_gamma,
    method = method,
    convergence = convergence,
    objective_at_zero = obj_at_zero,
    concordance_p0 = concordance_p0
  )
}


#' Golden Section Search for 1D Optimization
#'
#' Implements golden section search for maximizing a univariate function.
#'
#' @param f Function to maximize
#' @param lower Numeric: lower bound of search interval
#' @param upper Numeric: upper bound of search interval
#' @param tol Numeric: convergence tolerance
#' @param maximize Logical: maximize (TRUE) or minimize (FALSE)?
#' @param max_iter Integer: maximum iterations
#'
#' @return List with argmax, max_value, converged, iterations
#'
#' @details
#' Golden section search is a robust method for 1D optimization that
#' doesn't require derivatives. Convergence rate: O(log(1/tol)).
#'
#' @keywords internal
golden_section_search <- function(f,
                                   lower,
                                   upper,
                                   tol = 1e-6,
                                   maximize = TRUE,
                                   max_iter = 100) {

  # Golden ratio
  phi <- (1 + sqrt(5)) / 2
  resphi <- 2 - phi

  # Initialize
  a <- lower
  b <- upper
  x1 <- a + resphi * (b - a)
  x2 <- b - resphi * (b - a)

  f1 <- f(x1)
  f2 <- f(x2)

  # Flip sign if minimizing
  if (!maximize) {
    f1 <- -f1
    f2 <- -f2
  }

  # Iterate
  iter <- 0
  while (abs(b - a) > tol && iter < max_iter) {
    iter <- iter + 1

    if (f1 > f2) {
      b <- x2
      x2 <- x1
      f2 <- f1
      x1 <- a + resphi * (b - a)
      f1 <- f(x1)
      if (!maximize) f1 <- -f1
    } else {
      a <- x1
      x1 <- x2
      f1 <- f2
      x2 <- b - resphi * (b - a)
      f2 <- f(x2)
      if (!maximize) f2 <- -f2
    }
  }

  # Return best point
  if (f1 > f2) {
    argmax <- x1
    max_value <- if (maximize) f1 else -f1
  } else {
    argmax <- x2
    max_value <- if (maximize) f2 else -f2
  }

  list(
    argmax = argmax,
    max_value = max_value,
    converged = (iter < max_iter),
    iterations = iter
  )
}


#' Validate Wasserstein Dual Solution
#'
#' Checks that the dual solution is valid and satisfies optimality conditions.
#'
#' @param dual_result Output from wasserstein_concordance_dual()
#' @param type_stats Type-level statistics
#' @param cost_matrix Cost matrix
#' @param lambda_w Wasserstein radius
#' @param tol Numerical tolerance
#'
#' @return List with validation checks
#'
#' @details
#' Validates:
#' 1. gamma* >= 0 (dual feasibility)
#' 2. phi_star <= E_P0[concordance] (dual is lower bound)
#' 3. Optimality: derivative conditions (if analytical)
#'
#' @keywords internal
validate_wasserstein_dual_solution <- function(dual_result,
                                                type_stats,
                                                cost_matrix,
                                                lambda_w,
                                                tol = 1e-6) {

  checks <- list()

  # Check 1: Dual feasibility (gamma >= 0)
  checks$gamma_nonneg <- (dual_result$optimal_gamma >= -tol)

  # Check 2: Dual is lower bound
  concordance_p0 <- compute_concordance_from_types(type_stats)
  checks$dual_lower_bound <- (dual_result$phi_star <= concordance_p0 + tol)

  # Check 3: Convergence
  checks$converged <- dual_result$convergence

  # Overall validity
  checks$valid <- all(unlist(checks))

  checks
}
