#' Compute Analytical Gradient of Correlation Functional
#'
#' Computes the gradient ∇φ(Δ_S, Δ_Y) where φ is the sample correlation functional.
#' For M treatment effect pairs {(Δ_S(Q_m), Δ_Y(Q_m))}_{m=1}^M, returns the gradient
#' at each pair indicating how the correlation changes when perturbing that pair.
#'
#' @param Delta_S Numeric vector of length M. Treatment effects on surrogate across
#'   M future studies.
#' @param Delta_Y Numeric vector of length M. Treatment effects on outcome across
#'   M future studies.
#'
#' @return Matrix of size M × 2, where row m contains the gradient
#'   (∂φ/∂Δ_S(Q_m), ∂φ/∂Δ_Y(Q_m)) evaluated at study m. This is the influence
#'   function of the sample correlation at each observation.
#'
#' @details
#' **Formula:** For the sample correlation ρ̂ = cor(Δ_S, Δ_Y), the gradient at
#' observation m is:
#'
#' \deqn{
#'   \frac{\partial \rho}{\partial \Delta_S(Q_m)} =
#'   \frac{1}{M \sigma_S \sigma_Y} \left[
#'     (\Delta_Y(Q_m) - \bar{Y}) - \rho \frac{\sigma_Y}{\sigma_S} (\Delta_S(Q_m) - \bar{S})
#'   \right]
#' }
#'
#' \deqn{
#'   \frac{\partial \rho}{\partial \Delta_Y(Q_m)} =
#'   \frac{1}{M \sigma_S \sigma_Y} \left[
#'     (\Delta_S(Q_m) - \bar{S}) - \rho \frac{\sigma_S}{\sigma_Y} (\Delta_Y(Q_m) - \bar{Y})
#'   \right]
#' }
#'
#' where:
#' - M = number of studies (length of Delta_S)
#' - \eqn{\bar{S}} = mean(Delta_S), \eqn{\bar{Y}} = mean(Delta_Y)
#' - \eqn{\sigma_S} = sd(Delta_S), \eqn{\sigma_Y} = sd(Delta_Y)
#' - ρ = cor(Delta_S, Delta_Y)
#'
#' **Interpretation:** This gradient is the influence function of the sample correlation.
#' Row m tells us: "If we add weight ε to observation m, the correlation changes by
#' approximately ε × gradient[m, ]".
#'
#' **Edge cases:**
#' - If sd(Delta_S) ≈ 0 or sd(Delta_Y) ≈ 0: Gradient is undefined (returns NA)
#' - If all values identical: No variation, gradient is NA
#'
#' **Usage in IF-based inference:** This gradient is combined with AIPW influence
#' functions via chain rule:
#'
#' \deqn{
#'   \psi_\Theta(O_i) = \sum_{m=1}^M \left[
#'     \nabla\phi(Q_m) \cdot \begin{pmatrix} \psi_S^{AIPW}(O_i; Q_m) \\
#'                                            \psi_Y^{AIPW}(O_i; Q_m) \end{pmatrix}
#'   \right]
#' }
#'
#' @examples
#' # Treatment effects from 100 future studies
#' M <- 100
#' Delta_S <- rnorm(M, mean = 0.3, sd = 0.2)
#' Delta_Y <- rnorm(M, mean = 0.4, sd = 0.25)
#'
#' # Compute gradient
#' grad <- gradient_correlation_analytical(Delta_S, Delta_Y)
#'
#' # Check: gradient should sum to approximately zero (centered IF)
#' cat(sprintf("Sum of gradients: (%.6f, %.6f)\n",
#'             sum(grad[, 1]), sum(grad[, 2])))
#'
#' # Verify numerically for one observation
#' eps <- 1e-6
#' rho_original <- cor(Delta_S, Delta_Y)
#' Delta_S_perturbed <- Delta_S
#' Delta_S_perturbed[1] <- Delta_S_perturbed[1] + eps
#' rho_perturbed <- cor(Delta_S_perturbed, Delta_Y)
#' grad_numerical <- (rho_perturbed - rho_original) / eps
#' cat(sprintf("Numerical gradient at obs 1: %.6f\n", grad_numerical))
#' cat(sprintf("Analytical gradient at obs 1: %.6f\n", grad[1, 1]))
#'
#' @export
gradient_correlation_analytical <- function(Delta_S, Delta_Y) {

  # Input validation
  if (length(Delta_S) != length(Delta_Y)) {
    stop("Delta_S and Delta_Y must have the same length")
  }

  M <- length(Delta_S)

  if (M < 2) {
    stop("Need at least 2 observations to compute correlation gradient")
  }

  # Compute summary statistics
  x_bar <- mean(Delta_S)
  y_bar <- mean(Delta_Y)
  s_x <- stats::sd(Delta_S)
  s_y <- stats::sd(Delta_Y)

  # Check for degenerate cases
  if (s_x < 1e-10 || s_y < 1e-10) {
    warning("Standard deviation near zero. Gradient undefined. Returning NA.")
    grad <- matrix(NA_real_, nrow = M, ncol = 2)
    colnames(grad) <- c("grad_S", "grad_Y")
    return(grad)
  }

  # Compute correlation
  rho <- stats::cor(Delta_S, Delta_Y)

  # Gradient matrix
  grad <- matrix(NA_real_, nrow = M, ncol = 2)
  colnames(grad) <- c("grad_S", "grad_Y")

  # Common scaling factor
  scale_factor <- 1 / (M * s_x * s_y)

  # Compute gradient at each observation
  for (m in seq_len(M)) {
    delta_s_m <- Delta_S[m]
    delta_y_m <- Delta_Y[m]

    # Centered residuals
    resid_s <- delta_s_m - x_bar
    resid_y <- delta_y_m - y_bar

    # Gradient with respect to Delta_S(Q_m)
    grad[m, 1] <- scale_factor * (resid_y - rho * (s_y / s_x) * resid_s)

    # Gradient with respect to Delta_Y(Q_m)
    grad[m, 2] <- scale_factor * (resid_s - rho * (s_x / s_y) * resid_y)
  }

  grad
}


#' Compute Numerical Gradient of Correlation (For Validation)
#'
#' Computes gradient using finite differences. Useful for validating the
#' analytical gradient implementation.
#'
#' @param Delta_S Numeric vector. Treatment effects on surrogate.
#' @param Delta_Y Numeric vector. Treatment effects on outcome.
#' @param eps Numeric. Step size for finite differences (default: 1e-6).
#'
#' @return Matrix of size M × 2 with numerical gradients.
#'
#' @details
#' Uses central differences: ∂f/∂x ≈ (f(x+ε) - f(x-ε)) / (2ε)
#'
#' **Warning:** Numerical gradients are less accurate than analytical gradients
#' due to finite precision and step size choice. Use only for validation.
#'
#' @keywords internal
gradient_correlation_numerical <- function(Delta_S, Delta_Y, eps = 1e-6) {

  M <- length(Delta_S)
  grad <- matrix(NA_real_, nrow = M, ncol = 2)
  colnames(grad) <- c("grad_S", "grad_Y")

  for (m in seq_len(M)) {
    # Gradient with respect to Delta_S(Q_m)
    Delta_S_plus <- Delta_S
    Delta_S_plus[m] <- Delta_S_plus[m] + eps
    Delta_S_minus <- Delta_S
    Delta_S_minus[m] <- Delta_S_minus[m] - eps

    rho_plus <- stats::cor(Delta_S_plus, Delta_Y)
    rho_minus <- stats::cor(Delta_S_minus, Delta_Y)
    grad[m, 1] <- (rho_plus - rho_minus) / (2 * eps)

    # Gradient with respect to Delta_Y(Q_m)
    Delta_Y_plus <- Delta_Y
    Delta_Y_plus[m] <- Delta_Y_plus[m] + eps
    Delta_Y_minus <- Delta_Y
    Delta_Y_minus[m] <- Delta_Y_minus[m] - eps

    rho_plus <- stats::cor(Delta_S, Delta_Y_plus)
    rho_minus <- stats::cor(Delta_S, Delta_Y_minus)
    grad[m, 2] <- (rho_plus - rho_minus) / (2 * eps)
  }

  grad
}
