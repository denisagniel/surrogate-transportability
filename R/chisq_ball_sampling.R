#' Sample from a Chi-Squared Ball using Hit-and-Run MCMC
#'
#' Implements uniform sampling from the chi-squared ball
#' U(P₀, λ; χ²) = {Q ∈ Δ_{K-1} : χ²(Q, P₀) ≤ λ}, where
#' χ²(Q, P₀) = Σ_k (q_k - p₀(k))² / p₀(k), using hit-and-run Markov chain Monte
#' Carlo in *whitened* coordinates.
#'
#' @param P0 Numeric vector. Baseline probability distribution (K-vector summing
#'   to 1). Must have **full support** (`p0(k) > 0` for all `k`): the χ²
#'   geometry is undefined when any cell has zero reference mass.
#' @param lambda Numeric. Chi-squared ball radius, `lambda > 0`. Note this is a
#'   χ² *divergence* budget, not a probability: unlike the TV radius it is not
#'   confined to `(0, 1]`, and the ball saturates the whole simplex only at
#'   `lambda >= (1 - p_min) / p_min`.
#' @param M Integer. Number of samples to return (number of future studies).
#' @param burn_in Integer. Number of burn-in iterations (default: 1000).
#' @param thin Integer. Thinning interval - keep every thin-th sample (default: 10).
#' @param initial Numeric vector. Starting point (if NULL, uses P0). Must lie in
#'   the χ² ball.
#' @param verbose Logical. Print progress messages? (default: TRUE)
#'
#' @return Matrix of size M × K, where each row is a sampled probability
#'   distribution Q from the χ² ball. Each Q satisfies:
#'   - Q_k ≥ 0 for all k
#'   - Σ_k Q_k = 1
#'   - χ²(Q, P₀) = Σ_k (Q_k - P₀_k)² / P₀_k ≤ λ
#'
#' @details
#' **Why not the TV sampler's algorithm.** [sample_tv_ball()] solves its radius
#' constraint by enumerating sign-change breakpoints, because
#' TV(t) = ½ Σ_k |r_k + t d_k| is convex *piecewise-linear* in the step size `t`.
#' The χ² constraint is a single smooth quadratic, so breakpoint enumeration is
#' both unnecessary and structurally wrong here: the feasible step interval is
#' obtained in closed form from one quadratic equation.
#'
#' **Whitening transform.** Write V := Q - P₀ and D := diag(P₀). Substitute
#' \deqn{u = D^{-1/2} V, \quad\text{i.e.}\quad u_k = (q_k - p_0(k))/\sqrt{p_0(k)},}
#' the change of variables used in the proof of the χ² interior-regime closed
#' form (`inst/paper/theory.tex`, Proposition `prop:interior-chisq`). Direct
#' algebra gives the three claims the sampler relies on:
#'
#' 1. **The χ² ellipsoid becomes a Euclidean sphere.**
#'    χ²(Q, P₀) = Vᵀ D⁻¹ V = (D^{1/2}u)ᵀ D⁻¹ (D^{1/2}u) = uᵀu = ‖u‖₂².
#'    So {Q : χ²(Q,P₀) ≤ λ} maps to the isotropic ball ‖u‖₂ ≤ √λ. The geometry
#'    is *isotropic* in `u`, which is exactly what makes a single quadratic
#'    root-finding step exact.
#'
#' 2. **The sum-to-one constraint becomes one linear (hyperplane) constraint.**
#'    Σ_k q_k = 1 ⟺ Σ_k V_k = 0 ⟺ Σ_k √(p₀(k)) u_k = ⟨ν, u⟩ = 0, where
#'    ν := (√p₀(1), ..., √p₀(K)). Since ‖ν‖² = Σ_k p₀(k) = 1, ν is a *unit*
#'    vector, so the feasible set in `u`-space is the intersection of the ball
#'    ‖u‖ ≤ √λ with the hyperplane H' = {u : ⟨ν,u⟩ = 0} through its centre —
#'    i.e. a (K-1)-dimensional Euclidean ball of radius √λ, centred at u = 0
#'    (which corresponds to Q = P₀).
#'
#' 3. **Nonnegativity becomes a box constraint.**
#'    q_k ≥ 0 ⟺ u_k ≥ -√(p₀(k)). In the *interior regime*
#'    (λ ≤ p_min/(1 - p_min), Lemma `lem:interior-chisq-threshold`) this box
#'    never binds and the feasible body is the whitened ball exactly; outside it
#'    the box truncates the ball, and the sampler handles both cases uniformly.
#'
#' Because `u = D^{-1/2} V` is a linear bijection between the hyperplanes
#' H = {V : Σ V_k = 0} and H', it scales (K-1)-dimensional Lebesgue measure by a
#' constant Jacobian. Uniform sampling in `u`-space therefore *is* uniform
#' sampling with respect to Lebesgue measure on H restricted to the ball — the
#' same reference-measure convention `μ_λ` used throughout the theory. No
#' Jacobian reweighting is required.
#'
#' **Algorithm** (hit-and-run in whitened coordinates):
#'
#' 1. Start at u = 0 (i.e. Q = P₀, always feasible since χ²(P₀,P₀) = 0).
#' 2. Draw a uniform direction `d` on the unit sphere of H' (Gaussian, projected
#'    orthogonally to ν, renormalised).
#' 3. Solve for the feasible chord {t : ‖u + t d‖² ≤ λ, u + t d ≥ -ν}:
#'    the sphere gives `t² + 2⟨u,d⟩t + (‖u‖² - λ) ≤ 0`, one quadratic with roots
#'    `-⟨u,d⟩ ± sqrt(⟨u,d⟩² - ‖u‖² + λ)`; the box gives linear bounds.
#' 4. Draw `t` uniformly on that chord and move.
#' 5. Un-whiten on output: Q = P₀ + √P₀ ⊙ u.
#'
#' **Sanity check against theory.** Under uniform sampling in the interior
#' regime the theory predicts
#' Cov(u) = λ/(K+1) · (I_K - ννᵀ) and hence
#' Cov(Q) = λ/(K+1) · (D - P₀P₀ᵀ); in particular
#' E[χ²(Q,P₀)] = λ(K-1)/(K+1). These are used as unit tests.
#'
#' @seealso [sample_tv_ball()] for the TV-ball sibling sampler.
#'
#' @examples
#' # Canonical reference distribution (5-level X), strictly inside the
#' # chi-squared interior regime: lambda < p_min / (1 - p_min) = 0.05/0.95.
#' P0 <- c(0.05, 0.25, 0.40, 0.25, 0.05)
#' Q_samples <- sample_chisq_ball(P0, lambda = 0.03, M = 200, burn_in = 200,
#'                                thin = 5, verbose = FALSE)
#'
#' cat(sprintf("Samples shape: %d x %d\n", nrow(Q_samples), ncol(Q_samples)))
#' cat(sprintf("All sum to 1: %s\n", all(abs(rowSums(Q_samples) - 1) < 1e-8)))
#'
#' chisq <- apply(Q_samples, 1, function(q) sum((q - P0)^2 / P0))
#' cat(sprintf("Mean chi-squared: %.4f (budget %.4f, theory %.4f)\n",
#'             mean(chisq), 0.03, 0.03 * (length(P0) - 1) / (length(P0) + 1)))
#'
#' @export
sample_chisq_ball <- function(P0,
                              lambda,
                              M = 500,
                              burn_in = 1000,
                              thin = 10,
                              initial = NULL,
                              verbose = TRUE) {

  K <- length(P0)

  # Input validation
  if (K < 2) {
    stop("P0 must have at least 2 cells (K = ", K, ")")
  }
  if (any(!is.finite(P0))) {
    stop("P0 must be finite")
  }
  if (abs(sum(P0) - 1) > 1e-10) {
    stop("P0 must sum to 1 (current sum: ", sum(P0), ")")
  }
  if (any(P0 <= 0)) {
    stop("P0 must have full support for the chi-squared geometry: ",
         "all p0(k) > 0 (min: ", min(P0), ")")
  }
  if (!is.finite(lambda) || lambda <= 0) {
    stop("lambda must be a finite positive chi-squared budget (got: ", lambda, ")")
  }
  if (M <= 0 || burn_in < 0 || thin < 1) {
    stop("Invalid sampling parameters: M=", M, ", burn_in=", burn_in,
         ", thin=", thin)
  }

  # Whitening scale: nu_k = sqrt(p0(k)). ||nu||^2 = sum_k p0(k) = 1, so nu is a
  # unit normal of the whitened zero-sum hyperplane H' = {u : <nu, u> = 0}.
  nu <- sqrt(P0)

  # Initialize in whitened coordinates. u = 0 <-> Q = P0 (always feasible).
  if (is.null(initial)) {
    u_current <- rep(0, K)
  } else {
    if (length(initial) != K) {
      stop("Initial point has wrong length: ", length(initial),
           " (expected ", K, ")")
    }
    if (abs(sum(initial) - 1) > 1e-8) {
      stop("Initial point must sum to 1 (current sum: ", sum(initial), ")")
    }
    chisq_init <- chisq_divergence(initial, P0)
    if (chisq_init > lambda + 1e-10) {
      stop("Initial point not in chi-squared ball: chi^2 = ", chisq_init,
           " > lambda = ", lambda)
    }
    u_current <- (initial - P0) / nu
  }

  total_iterations <- burn_in + M * thin
  samples <- matrix(NA_real_, nrow = M, ncol = K)

  if (verbose) {
    message(sprintf("Sampling %d distributions from chi-squared ball (K=%d, lambda=%.4f)",
                    M, K, lambda))
    message(sprintf("Total iterations: %d (burn-in: %d, thin: %d)",
                    total_iterations, burn_in, thin))
  }

  sample_idx <- 1
  accept_count <- 0

  for (iter in seq_len(total_iterations)) {

    if (verbose && iter %% 1000 == 0) {
      message(sprintf("  Iteration %d / %d", iter, total_iterations))
    }

    # 1. Uniform direction on the unit sphere of the whitened hyperplane H'
    direction <- sample_whitened_direction(nu)

    # 2. Feasible chord: one quadratic (sphere) intersected with a box
    range <- find_feasible_range_chisq(u_current, direction, nu, lambda)

    # 3. Uniform draw on the chord
    if (range$t_max - range$t_min < 1e-12) {
      t_step <- 0
    } else {
      t_step <- stats::runif(1, range$t_min, range$t_max)
    }

    u_new <- u_current + t_step * direction

    # Un-whiten: Q = P0 + sqrt(P0) * u
    q_new <- P0 + nu * u_new

    # Sanity checks (should always pass with correct implementation)
    if (any(q_new < -1e-10)) {
      warning(sprintf("Iteration %d: Negative probability detected (min: %.6g). Skipping.",
                      iter, min(q_new)))
      next
    }
    chisq_new <- chisq_divergence(q_new, P0)
    if (chisq_new > lambda * (1 + 1e-6) + 1e-10) {
      warning(sprintf("Iteration %d: Outside chi-squared ball (chi^2=%.6g > lambda=%.6g). Skip.",
                      iter, chisq_new, lambda))
      next
    }

    # Accept move. Note the state is carried in whitened coordinates, so no
    # renormalisation drift accumulates: <nu, u> = 0 is preserved exactly
    # because every direction lies in H'.
    u_current <- u_new
    accept_count <- accept_count + 1

    if (iter > burn_in && (iter - burn_in) %% thin == 0) {
      samples[sample_idx, ] <- pmax(q_new, 0)
      sample_idx <- sample_idx + 1
    }
  }

  if (verbose) {
    acceptance_rate <- 100 * accept_count / total_iterations
    message(sprintf("Sampling complete. Acceptance rate: %.1f%%", acceptance_rate))
  }

  samples
}


#' Sample Uniform Direction on the Whitened Zero-Sum Hyperplane (Internal)
#'
#' Draws a direction uniformly on the unit sphere of
#' H' = {u : ⟨ν, u⟩ = 0}, the whitened image of the simplex tangent space.
#'
#' @param nu Numeric vector. Unit normal of H', `nu = sqrt(P0)`.
#' @return Numeric vector of length K with `sum(nu * d) = 0` and norm 1.
#' @keywords internal
sample_whitened_direction <- function(nu) {
  d <- stats::rnorm(length(nu))

  # Project out the nu component. In whitened coordinates the constraint is
  # <nu, d> = 0 with ||nu|| = 1, so the projection is d - <nu,d> * nu.
  # (In the unwhitened simplex tangent space the analogous step is d - mean(d);
  # here the normal is nu, not 1, so a plain mean-centering would be wrong.)
  d <- d - sum(nu * d) * nu

  nrm <- sqrt(sum(d^2))
  if (nrm < 1e-12) {
    # Degenerate draw (probability ~0): retry with a fresh Gaussian.
    return(sample_whitened_direction(nu))
  }

  d / nrm
}


#' Find Feasible Range Along a Direction in the Whitened Chi-Squared Ball (Internal)
#'
#' Given the current whitened point `u` and a unit direction `d` in H', find
#' `[t_min, t_max]` such that `u + t*d` satisfies
#' 1. the χ² constraint `‖u + t d‖² ≤ λ` (one smooth quadratic), and
#' 2. nonnegativity `(u + t d)_k ≥ -ν_k` (equivalently `q_k ≥ 0`).
#'
#' No breakpoint enumeration is needed: unlike TV, the χ² radius is a single
#' quadratic in `t`, solved in closed form.
#'
#' @param u_current Numeric vector. Current whitened point (in H', norm² ≤ λ).
#' @param direction Numeric vector. Unit direction in H'.
#' @param nu Numeric vector. `sqrt(P0)`; the box floor is `-nu`.
#' @param lambda Numeric. Chi-squared radius.
#'
#' @return List with elements:
#'   \item{t_min}{Lower bound of feasible range}
#'   \item{t_max}{Upper bound of feasible range}
#'
#' @keywords internal
find_feasible_range_chisq <- function(u_current, direction, nu, lambda) {

  # Constraint 1 (chi-squared): ||u + t d||^2 <= lambda with ||d|| = 1 gives
  #   t^2 + 2*<u,d>*t + (||u||^2 - lambda) <= 0,
  # a single quadratic whose roots are -b +/- sqrt(b^2 - c), b = <u,d>,
  # c = ||u||^2 - lambda <= 0 for a feasible u (so the discriminant is >= 0
  # and t = 0 always lies between the roots).
  b <- sum(u_current * direction)
  c_coef <- sum(u_current^2) - lambda
  disc <- b^2 - c_coef
  if (disc <= 0) {
    # Numerically on the boundary: zero-length chord rather than a move that
    # would leave the ball.
    return(list(t_min = 0, t_max = 0))
  }
  root <- sqrt(disc)
  t_min <- -b - root
  t_max <- -b + root

  # Constraint 2 (nonnegativity as a box in whitened coordinates):
  #   q_k >= 0  <=>  u_k + t*d_k >= -nu_k.
  # Binds only outside the interior regime lambda <= p_min/(1 - p_min).
  pos <- direction > 1e-12
  neg <- direction < -1e-12
  if (any(pos)) {
    t_min <- max(t_min, max((-nu[pos] - u_current[pos]) / direction[pos]))
  }
  if (any(neg)) {
    t_max <- min(t_max, min((-nu[neg] - u_current[neg]) / direction[neg]))
  }

  if (t_min > t_max) {
    # Degenerate (numerical): collapse to the current point rather than
    # silently moving outside the body.
    return(list(t_min = 0, t_max = 0))
  }

  list(t_min = t_min, t_max = t_max)
}


#' Compute Chi-Squared Divergence Between Distributions (Internal)
#'
#' @param Q Numeric vector. Probability distribution.
#' @param P0 Numeric vector. Baseline probability distribution (full support).
#' @return Numeric. `sum((Q - P0)^2 / P0)`.
#' @keywords internal
chisq_divergence <- function(Q, P0) {
  sum((Q - P0)^2 / P0)
}
