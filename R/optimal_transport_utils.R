#' Optimal Transport Utilities for Wasserstein Minimax Inference
#'
#' Functions for computing Wasserstein distances and projections
#' at the type level for minimax inference.
#'
#' @name optimal_transport_utils
NULL

#' Compute Type-Level Cost Matrix
#'
#' Constructs cost matrix C[i,j] = cost(type_i, type_j) for
#' type-level Wasserstein distance computation.
#'
#' @param type_centroids Matrix (J x p) of type centroid coordinates in covariate space
#' @param cost_function Character: "euclidean" (default) or "mahalanobis"
#' @param cov_matrix Matrix (p x p): covariance matrix for Mahalanobis cost. If NULL,
#'   computed from type centroids.
#'
#' @return Matrix (J x J) of pairwise costs between types
#'
#' @details
#' The cost matrix defines the "ground metric" for Wasserstein distance.
#'
#' **Euclidean cost (default):**
#' C[i,j] = ||centroid_i - centroid_j||_2^2
#'
#' This is the L2 distance in covariate space. Suitable when covariates
#' are on similar scales or have been standardized.
#'
#' **Mahalanobis cost:**
#' C[i,j] = (centroid_i - centroid_j)' Σ^-1 (centroid_i - centroid_j)
#'
#' This accounts for covariate correlations and scale differences.
#' Use when covariates have different units or strong correlations.
#'
#' The cost matrix has properties:
#' - Symmetric: C[i,j] = C[j,i]
#' - Non-negative: C[i,j] >= 0
#' - Zero diagonal: C[i,i] = 0
#'
#' @examples
#' \dontrun{
#' # Generate data and discretize
#' data <- generate_study_data(n = 500)
#' disc <- discretize_data(data, scheme = "rf", J_target = 16)
#'
#' # Compute type centroids
#' centroids <- compute_type_centroids(data, disc$bins,
#'                                     covariate_cols = c("X1", "X2"))
#'
#' # Euclidean cost matrix
#' C_euc <- compute_type_cost_matrix(centroids, cost_function = "euclidean")
#'
#' # Mahalanobis cost matrix
#' C_maha <- compute_type_cost_matrix(centroids, cost_function = "mahalanobis")
#' }
#'
#' @keywords internal
compute_type_cost_matrix <- function(type_centroids,
                                      cost_function = c("euclidean", "mahalanobis"),
                                      cov_matrix = NULL) {

  cost_function <- match.arg(cost_function)

  J <- nrow(type_centroids)
  p <- ncol(type_centroids)

  if (J == 0) {
    stop("type_centroids must have at least one row")
  }

  if (p == 0) {
    stop("type_centroids must have at least one column")
  }

  # Initialize cost matrix
  C <- matrix(0, J, J)

  if (cost_function == "euclidean") {
    # Euclidean distance: ||x_i - x_j||^2
    for (i in 1:J) {
      for (j in i:J) {
        diff <- type_centroids[i, ] - type_centroids[j, ]
        C[i, j] <- sum(diff^2)
        C[j, i] <- C[i, j]  # Symmetric
      }
    }

  } else if (cost_function == "mahalanobis") {
    # Mahalanobis distance: (x_i - x_j)' Σ^-1 (x_i - x_j)

    # Compute covariance matrix if not provided
    if (is.null(cov_matrix)) {
      cov_matrix <- stats::cov(type_centroids)
    }

    # Check for singularity
    cond_number <- kappa(cov_matrix)
    if (is.infinite(cond_number) || cond_number > 1e10) {
      warning("Covariance matrix is near-singular. Adding regularization.")
      # Add small ridge to diagonal
      cov_matrix <- cov_matrix + diag(1e-6, p)
    }

    # Invert covariance matrix
    tryCatch({
      cov_inv <- solve(cov_matrix)

      for (i in 1:J) {
        for (j in i:J) {
          diff <- type_centroids[i, ] - type_centroids[j, ]
          C[i, j] <- as.numeric(t(diff) %*% cov_inv %*% diff)
          C[j, i] <- C[i, j]  # Symmetric
        }
      }

    }, error = function(e) {
      warning("Failed to compute Mahalanobis distance. Falling back to Euclidean.")
      for (i in 1:J) {
        for (j in i:J) {
          diff <- type_centroids[i, ] - type_centroids[j, ]
          C[i, j] <- sum(diff^2)
          C[j, i] <- C[i, j]
        }
      }
    })
  }

  # Ensure diagonal is exactly zero (numerical precision)
  diag(C) <- 0

  C
}


#' Compute Type-Level Wasserstein Distance
#'
#' Computes the 2-Wasserstein (L2) distance between two type-level
#' probability distributions using proper optimal transport.
#'
#' @param q1 Numeric vector (length J): first type distribution (probability simplex)
#' @param q2 Numeric vector (length J): second type distribution (probability simplex)
#' @param cost_matrix Matrix (J x J): pairwise cost between types
#' @param method Character: "transport" (exact via transport package) or "lp" (exact via lpSolve)
#'
#' @return Numeric: W_2(q1, q2) - the 2-Wasserstein distance
#'
#' @details
#' Computes the exact 2-Wasserstein distance by solving the optimal transport problem:
#'
#' W_2^2(q1, q2) = min_{π} Σᵢⱼ πᵢⱼ Cᵢⱼ
#'
#' subject to: Σⱼ πᵢⱼ = q1ᵢ, Σᵢ πᵢⱼ = q2ⱼ, πᵢⱼ ≥ 0
#'
#' This is a linear programming problem. We use established solvers:
#' - **transport package** (preferred): Fast, specialized OT solver
#' - **lpSolve** (fallback): General LP solver
#'
#' **Properties:**
#' - W_2(q, q) = 0 (identity)
#' - W_2(q1, q2) = W_2(q2, q1) (symmetry)
#' - W_2(q1, q2) >= 0 (non-negativity)
#' - Triangle inequality (satisfied)
#'
#' **Note on cost matrix:**
#' Unlike the previous approximation, this method does NOT require the cost matrix
#' to be positive semi-definite. It works with any valid cost matrix.
#'
#' @examples
#' \dontrun{
#' # Type distributions
#' J <- 10
#' p0 <- rep(1/J, J)  # Uniform reference
#' q <- MCMCpack::rdirichlet(1, rep(1, J))[1,]  # Random perturbation
#'
#' # Cost matrix
#' centroids <- matrix(rnorm(J * 2), J, 2)
#' C <- compute_type_cost_matrix(centroids)
#'
#' # Compute exact distance
#' w_dist <- wasserstein_distance_types(q, p0, C)
#' }
#'
#' @keywords internal
wasserstein_distance_types <- function(q1, q2, cost_matrix,
                                        method = c("transport", "lp")) {

  method <- match.arg(method)

  # Validate inputs
  if (length(q1) != length(q2)) {
    stop("q1 and q2 must have the same length")
  }

  J <- length(q1)

  if (nrow(cost_matrix) != J || ncol(cost_matrix) != J) {
    stop("cost_matrix dimensions must match length of q1 and q2")
  }

  # Check that q1 and q2 are valid probability distributions
  if (abs(sum(q1) - 1) > 1e-6) {
    warning("q1 does not sum to 1. Normalizing.")
    q1 <- q1 / sum(q1)
  }

  if (abs(sum(q2) - 1) > 1e-6) {
    warning("q2 does not sum to 1. Normalizing.")
    q2 <- q2 / sum(q2)
  }

  # Any negative values?
  if (any(q1 < -1e-10) || any(q2 < -1e-10)) {
    stop("q1 and q2 must be non-negative")
  }

  # Ensure strictly non-negative
  q1 <- pmax(q1, 0)
  q2 <- pmax(q2, 0)

  # Renormalize after truncation
  q1 <- q1 / sum(q1)
  q2 <- q2 / sum(q2)

  # Check if distributions are identical (avoid numerical issues)
  if (max(abs(q1 - q2)) < 1e-12) {
    return(0)
  }

  # Compute exact Wasserstein distance via optimal transport
  if (method == "transport") {
    # Use transport package (preferred)
    if (!requireNamespace("transport", quietly = TRUE)) {
      warning("Package 'transport' not available. Falling back to 'lp' method.")
      method <- "lp"
    } else {
      # transport::wasserstein expects mass vectors and cost matrix
      # It computes W_p distance where p is specified
      # For p=2, we get W_2 distance

      # Note: transport package uses different convention
      # It expects mass vectors (a, b) and distance matrix
      # We have probability vectors, so we can use directly

      tryCatch({
        # The transport package uses wasserstein() function
        # which takes two mass vectors and a distance matrix
        # NOTE: With p=2, it returns W_2^2 (squared distance), so we take sqrt
        w_dist_squared <- transport::wasserstein(
          a = q1,
          b = q2,
          costm = cost_matrix,
          p = 2  # For W_2 distance
        )

        return(sqrt(w_dist_squared))

      }, error = function(e) {
        warning("transport::wasserstein failed: ", e$message, ". Using LP fallback.")
        method <<- "lp"
      })
    }
  }

  if (method == "lp") {
    # Fallback: use general LP solver
    if (!requireNamespace("lpSolve", quietly = TRUE)) {
      stop("Neither 'transport' nor 'lpSolve' package available. ",
           "Install one with: install.packages('transport') or install.packages('lpSolve')")
    }

    # Formulate as LP:
    # Variables: π[i,j] for i=1..J, j=1..J (J^2 variables)
    # Minimize: Σᵢⱼ C[i,j] * π[i,j]
    # Subject to:
    #   Σⱼ π[i,j] = q1[i]  for all i  (row sums)
    #   Σᵢ π[i,j] = q2[j]  for all j  (column sums)
    #   π[i,j] >= 0

    # Objective: vectorize cost matrix
    obj <- as.vector(cost_matrix)  # Column-major order

    # Constraints
    # Row sum constraints: sum over j for each i
    A_row <- matrix(0, J, J * J)
    for (i in 1:J) {
      for (j in 1:J) {
        idx <- (j - 1) * J + i  # Column-major index
        A_row[i, idx] <- 1
      }
    }

    # Column sum constraints: sum over i for each j
    A_col <- matrix(0, J, J * J)
    for (j in 1:J) {
      for (i in 1:J) {
        idx <- (j - 1) * J + i
        A_col[j, idx] <- 1
      }
    }

    # Combine constraints
    A <- rbind(A_row, A_col)
    b <- c(q1, q2)

    # Solve LP
    lp_result <- lpSolve::lp(
      direction = "min",
      objective.in = obj,
      const.mat = A,
      const.dir = rep("==", 2 * J),
      const.rhs = b,
      all.bin = FALSE,
      all.int = FALSE
    )

    if (lp_result$status != 0) {
      warning("LP solver failed. Returning NA.")
      return(NA_real_)
    }

    # W_2 is sqrt of optimal value (since cost is squared distance)
    w2_squared <- lp_result$objval

    return(sqrt(max(0, w2_squared)))
  }
}


#' Project Vector onto Probability Simplex
#'
#' Projects a vector onto the probability simplex using Euclidean projection.
#'
#' @param x Numeric vector (length J) to project
#'
#' @return Numeric vector (length J) on the probability simplex
#'
#' @details
#' Solves the problem:
#'
#' minimize ||x - p||_2^2 subject to: sum(p) = 1, p >= 0
#'
#' This has a closed-form solution using the water-filling algorithm.
#'
#' **Algorithm:**
#' 1. Sort x in descending order
#' 2. Find the threshold τ such that truncating at τ gives sum = 1
#' 3. Return max(x - τ, 0)
#'
#' **Properties:**
#' - If x is already on simplex, returns x
#' - Result always sums to 1 with all non-negative entries
#' - Minimizes Euclidean distance to simplex
#'
#' @examples
#' \dontrun{
#' # Vector not on simplex
#' x <- c(0.3, 0.5, -0.1, 0.4)
#' p <- project_to_simplex(x)
#' sum(p)  # Should be 1
#' all(p >= 0)  # Should be TRUE
#' }
#'
#' @references
#' Duchi et al. (2008). "Efficient Projections onto the l1-Ball for Learning
#' in High Dimensions". ICML.
#'
#' @keywords internal
project_to_simplex <- function(x) {

  J <- length(x)

  if (J == 0) {
    stop("x must have at least one element")
  }

  # Sort in descending order
  x_sorted <- sort(x, decreasing = TRUE)

  # Find the threshold using water-filling
  cumsum_x <- cumsum(x_sorted)
  k_vals <- 1:J
  threshold_candidates <- (cumsum_x - 1) / k_vals

  # Find largest k where x_sorted[k] > threshold
  valid <- x_sorted > threshold_candidates

  if (!any(valid)) {
    # Edge case: all elements below threshold
    # Return uniform distribution
    return(rep(1/J, J))
  }

  k_star <- max(which(valid))
  threshold <- threshold_candidates[k_star]

  # Project
  p <- pmax(x - threshold, 0)

  # Normalize (should already sum to 1, but ensure numerical precision)
  p <- p / sum(p)

  p
}


#' Project onto Wasserstein Ball (Constrained Sampling Method)
#'
#' Projects a target distribution onto the Wasserstein ball around a
#' reference distribution using rejection sampling and binary search.
#'
#' @param target Numeric vector (length J): target distribution to project
#' @param reference Numeric vector (length J): center of Wasserstein ball
#' @param cost_matrix Matrix (J x J): pairwise cost between types
#' @param radius Numeric: Wasserstein ball radius (lambda_w)
#' @param max_iter Integer: maximum iterations for binary search
#' @param tol Numeric: convergence tolerance for binary search
#'
#' @return Numeric vector (length J) on probability simplex satisfying W_2 constraint
#'
#' @details
#' Projects target onto the set: {q : W_2(q, reference) <= radius, sum(q) = 1, q >= 0}
#'
#' **Algorithm:**
#' 1. If target already in ball, return target
#' 2. Otherwise, find largest α ∈ [0,1] such that:
#'    q = α*target + (1-α)*reference satisfies W_2(q, reference) <= radius
#' 3. Use binary search to find α
#'
#' This is a heuristic projection that is:
#' - Fast (no optimization solver required)
#' - Guaranteed to satisfy constraints
#' - Produces reasonable distributions for minimax inference
#'
#' For exact Euclidean projection onto Wasserstein ball, use
#' `project_onto_wasserstein_ball_qp()` which requires the quadprog package.
#'
#' @examples
#' \dontrun{
#' # Setup
#' J <- 10
#' p0 <- rep(1/J, J)
#' target <- MCMCpack::rdirichlet(1, rep(0.5, J))[1,]
#'
#' centroids <- matrix(rnorm(J * 2), J, 2)
#' C <- compute_type_cost_matrix(centroids)
#' lambda_w <- 0.5
#'
#' # Project
#' q <- project_onto_wasserstein_ball(target, p0, C, lambda_w)
#'
#' # Verify constraint
#' wasserstein_distance_types(q, p0, C) <= lambda_w  # Should be TRUE
#' }
#'
#' @keywords internal
project_onto_wasserstein_ball <- function(target,
                                          reference,
                                          cost_matrix,
                                          radius,
                                          max_iter = 20,
                                          tol = 1e-6) {

  # Validate inputs
  if (length(target) != length(reference)) {
    stop("target and reference must have same length")
  }

  J <- length(target)

  # Ensure both are on simplex
  if (abs(sum(target) - 1) > 1e-6) {
    target <- target / sum(target)
  }

  if (abs(sum(reference) - 1) > 1e-6) {
    reference <- reference / sum(reference)
  }

  # Check if target is already in the ball
  current_dist <- wasserstein_distance_types(target, reference, cost_matrix)

  if (current_dist <= radius * (1 + tol)) {
    # Already in ball
    return(target)
  }

  # Binary search for largest alpha such that
  # q = alpha*target + (1-alpha)*reference satisfies W_2 constraint

  alpha_low <- 0
  alpha_high <- 1
  alpha_best <- 0
  q_best <- reference

  for (iter in 1:max_iter) {
    alpha <- (alpha_low + alpha_high) / 2

    # Convex combination
    q <- alpha * target + (1 - alpha) * reference
    q <- q / sum(q)  # Ensure normalization

    # Check constraint
    dist <- wasserstein_distance_types(q, reference, cost_matrix)

    if (dist <= radius * (1 + tol)) {
      # Feasible: try larger alpha
      alpha_best <- alpha
      q_best <- q
      alpha_low <- alpha
    } else {
      # Infeasible: try smaller alpha
      alpha_high <- alpha
    }

    # Check convergence
    if (alpha_high - alpha_low < tol) {
      break
    }
  }

  q_best
}


#' Project onto Wasserstein Ball (Sinkhorn Method)
#'
#' Projects onto Wasserstein ball using entropic regularization (Sinkhorn algorithm).
#' This is an alternative to the constrained sampling method.
#'
#' @param target Numeric vector (length J): target distribution to project
#' @param reference Numeric vector (length J): center of Wasserstein ball
#' @param cost_matrix Matrix (J x J): pairwise cost between types
#' @param radius Numeric: Wasserstein ball radius
#' @param epsilon Numeric: entropic regularization parameter
#' @param max_iter Integer: maximum Sinkhorn iterations
#' @param tol Numeric: convergence tolerance
#'
#' @return Numeric vector (length J) approximating projection onto W-ball
#'
#' @details
#' Uses Sinkhorn iterations to solve the regularized optimal transport problem.
#' This provides an approximate projection that:
#' - Trades off W_2 distance and entropic regularization
#' - Is smooth and differentiable (useful for optimization)
#' - Converges faster than exact methods
#'
#' **Trade-off:**
#' - Small epsilon: closer to exact Wasserstein, slower convergence
#' - Large epsilon: faster convergence, more entropic smoothing
#'
#' For minimax inference, epsilon = 0.1 provides good balance.
#'
#' @references
#' Cuturi (2013). "Sinkhorn Distances: Lightspeed Computation of Optimal Transport".
#' NeurIPS.
#'
#' @keywords internal
sinkhorn_projection <- function(target,
                                 reference,
                                 cost_matrix,
                                 radius,
                                 epsilon = 0.1,
                                 max_iter = 100,
                                 tol = 1e-6) {

  # This is a simplified version
  # Full implementation would use Sinkhorn iterations

  # For now, fall back to constrained sampling method
  warning("Sinkhorn projection not fully implemented. Using constrained sampling.")
  project_onto_wasserstein_ball(target, reference, cost_matrix, radius)
}


#' Project onto Wasserstein Ball (Quadratic Programming)
#'
#' Exact Euclidean projection onto Wasserstein ball using QP solver.
#' Requires the 'quadprog' package.
#'
#' @param target Numeric vector (length J): target distribution to project
#' @param reference Numeric vector (length J): center of Wasserstein ball
#' @param cost_matrix Matrix (J x J): pairwise cost between types
#' @param radius Numeric: Wasserstein ball radius
#'
#' @return Numeric vector (length J) - exact projection onto W-ball
#'
#' @details
#' Solves the quadratic program:
#'
#' minimize ||q - target||^2
#' subject to: W_2(q, reference) <= radius
#'             sum(q) = 1
#'             q >= 0
#'
#' This requires the 'quadprog' package for QP solving. If not available,
#' falls back to constrained sampling method.
#'
#' **Use when:**
#' - Exact projection needed (e.g., for validation)
#' - Computational cost acceptable (slower than heuristics)
#'
#' **Not recommended when:**
#' - Running M=2000 iterations (too slow)
#' - quadprog not installed
#'
#' @keywords internal
quadratic_projection <- function(target,
                                  reference,
                                  cost_matrix,
                                  radius) {

  if (!requireNamespace("quadprog", quietly = TRUE)) {
    warning("Package 'quadprog' not available. Using constrained sampling instead.")
    return(project_onto_wasserstein_ball(target, reference, cost_matrix, radius))
  }

  # TODO: Implement exact QP-based projection
  # This would formulate the problem as:
  # min_q  ||q - target||^2
  # s.t.   (q - reference)' C (q - reference) <= radius^2
  #        sum(q) = 1
  #        q >= 0

  # For now, fall back to heuristic
  warning("QP projection not fully implemented. Using constrained sampling.")
  project_onto_wasserstein_ball(target, reference, cost_matrix, radius)
}
