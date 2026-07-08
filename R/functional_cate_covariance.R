#' Compute CATE Covariance Functional with Doubly Robust Estimation
#'
#' Computes φ(Q) = Cov(τ_S(X), τ_Y(X)) where τ_S(X) = E[S|A=1,X] - E[S|A=0,X]
#' and τ_Y(X) = E[Y|A=1,X] - E[Y|A=0,X] are the conditional average treatment
#' effects (CATEs) for a single distribution Q.
#'
#' @section Functional Paradigm:
#' This is a **within-study** functional. It operates on individual-level data
#' from a **single** study to measure treatment effect heterogeneity.
#'
#' **Input:** Raw study data with columns A, S, Y, and covariates. Individual-level
#' observations, not summary statistics.
#'
#' **Output:** Covariance of individual-level treatment effects τ_S(Xi) and
#' τ_Y(Xi) **within** this study.
#'
#' **Interpretation:** "In this study, do individuals with large τ_Y(X) also
#' tend to have large τ_S(X)?"
#'
#' For the **across-study** version (correlation of study-level treatment effects
#' across multiple studies), use \code{\link{functional_correlation}}.
#'
#' See \code{\link{functional-paradigms}} for detailed explanation of the
#' two paradigms.
#'
#' @section Comparison to Across-Study Functionals:
#' Unlike \code{\link{functional_correlation}} and related functions, this
#' functional:
#' \itemize{
#'   \item Operates on a **single** distribution Q (not across samples)
#'   \item Requires **individual-level** data (not just summary effects)
#'   \item Measures **heterogeneity** within a study
#'   \item Has causal interpretation about individual treatment effects
#'   \item Enables doubly robust estimation with influence functions
#' }
#'
#' Use this when interested in person-level treatment effect relationships
#' within a study. Use \code{functional_correlation()} when interested in
#' study-to-study transportability.
#'
#' @param data Data frame containing treatment, outcomes, and covariates.
#'   Must contain columns: A (treatment), S (surrogate), Y (outcome), and
#'   optionally X₁, X₂, ... (covariates)
#' @param covariates Character vector. Names of covariate columns for X. If NULL,
#'   assumes randomized trial without covariates (simpler estimator).
#' @param nuisance_method Character. Method for estimating nuisance functions
#'   μ(A,X) and e(X). Options: "lm" (linear), "gam" (generalized additive model),
#'   "rf" (random forest). Default: "gam" for flexibility.
#' @param cross_fit Logical. Use K-fold cross-fitting for nuisance estimation?
#'   Default: TRUE (recommended for doubly robust properties).
#' @param K Integer. Number of folds for cross-fitting. Default: 5.
#' @param return_influence_function Logical. Return element-wise influence function
#'   values ψ(Oᵢ)? Default: TRUE.
#' @param return_nuisance Logical. Return estimated nuisance functions? Default: FALSE.
#'
#' @details
#' **Estimand:** φ(Q) = Cov(τ_S(X), τ_Y(X)) for distribution Q, where:
#' - τ_S(X) = μ_{S1}(X) - μ_{S0}(X) is the CATE for surrogate S
#' - τ_Y(X) = μ_{Y1}(X) - μ_{Y0}(X) is the CATE for outcome Y
#' - μ_{Sa}(X) = E[S|A=a,X] and μ_{Ya}(X) = E[Y|A=a,X]
#'
#' **Decomposition:**
#' Cov(τ_S(X), τ_Y(X)) = E[τ_S(X) · τ_Y(X)] - E[τ_S(X)] · E[τ_Y(X)]
#'
#' Each component is estimated with doubly robust corrections:
#' - E[τ_S(X)] = n⁻¹ Σᵢ [τ̂_S(Xᵢ) + ψ_S(Oᵢ)]
#' - E[τ_Y(X)] = n⁻¹ Σᵢ [τ̂_Y(Xᵢ) + ψ_Y(Oᵢ)]
#' - E[τ_S(X) · τ_Y(X)] = n⁻¹ Σᵢ [τ̂_S(Xᵢ) · τ̂_Y(Xᵢ) + ψ_prod(Oᵢ)]
#'
#' where ψ(Oᵢ) are doubly robust corrections (AIPW-style) involving
#' propensity scores e(Xᵢ) and outcome residuals.
#'
#' **Influence Function for Variance:**
#' The influence function for the covariance is:
#' ψ_cov(Oᵢ) = ψ_prod(Oᵢ) - E[τ_S] · ψ_Y(Oᵢ) - E[τ_Y] · ψ_S(Oᵢ)
#'
#' This gives variance estimate: Var(φ̂) = n⁻¹ · Var(ψ_cov) and standard error
#' se(φ̂) = √[n⁻¹ · Var(ψ_cov)]
#'
#' **Why Doubly Robust?**
#' The estimator is consistent if either:
#' 1. The outcome regression models μ(A,X) are correctly specified, OR
#' 2. The propensity score model e(X) is correctly specified
#'
#' (Not both are required, hence "doubly robust")
#'
#' @return List with components:
#'   \item{phi}{Scalar. Covariance estimate Cov(tau_S(X), tau_Y(X))}
#'   \item{se}{Scalar. Standard error from influence function}
#'   \item{ci}{Vector of length 2. 95 percent confidence interval}
#'   \item{E_tau_S}{Scalar. Mean CATE for surrogate E[tau_S(X)]}
#'   \item{E_tau_Y}{Scalar. Mean CATE for outcome E[tau_Y(X)]}
#'   \item{E_product}{Scalar. Mean product E[tau_S(X) times tau_Y(X)]}
#'   \item{tau_S}{Numeric vector. Estimated tau_S(X_i) for each observation}
#'   \item{tau_Y}{Numeric vector. Estimated tau_Y(X_i) for each observation}
#'   \item{influence_function}{Numeric vector (if return_influence_function=TRUE).
#'     Element-wise psi_cov(O_i) for variance estimation}
#'   \item{nuisance_estimates}{List (if return_nuisance=TRUE) with:
#'     \itemize{
#'       \item mu_S1, mu_S0: Conditional means for S
#'       \item mu_Y1, mu_Y0: Conditional means for Y
#'       \item e_X: Propensity scores
#'     }
#'   }
#'
#' @examples
#' \dontrun{
#' # Generate test data with treatment effects
#' set.seed(123)
#' n <- 500
#' data <- data.frame(
#'   A = rbinom(n, 1, 0.5),
#'   X1 = rnorm(n),
#'   X2 = rnorm(n)
#' )
#' # Add outcomes with heterogeneous treatment effects
#' tau_S <- 0.3 + 0.2 * data$X1  # CATE for S depends on X1
#' tau_Y <- 0.4 + 0.3 * data$X1  # CATE for Y depends on X1 (correlated)
#' data$S <- rnorm(n, mean = data$A * tau_S, sd = 1)
#' data$Y <- rnorm(n, mean = data$A * tau_Y, sd = 1)
#'
#' # Compute CATE covariance
#' result <- functional_cate_covariance(
#'   data = data,
#'   covariates = c("X1", "X2"),
#'   nuisance_method = "gam",
#'   cross_fit = TRUE
#' )
#'
#' # Results
#' cat(sprintf("Cov(τ_S, τ_Y): %.3f (SE: %.3f)\n", result$phi, result$se))
#' cat(sprintf("95%% CI: [%.3f, %.3f]\n", result$ci[1], result$ci[2]))
#' }
#'
#' @export
functional_cate_covariance <- function(data,
                                       covariates = NULL,
                                       nuisance_method = c("gam", "lm", "rf"),
                                       cross_fit = TRUE,
                                       K = 5,
                                       return_influence_function = TRUE,
                                       return_nuisance = FALSE) {

  nuisance_method <- match.arg(nuisance_method)

  # Check for correct input type - helpful error if treatment effects passed by mistake
  if (all(c("delta_s", "delta_y") %in% names(data)) &&
      !any(c("A", "S", "Y") %in% names(data))) {
    stop(
      "functional_cate_covariance() expects raw study data (A, S, Y), ",
      "not treatment effect pairs (delta_s, delta_y).\n",
      "This is a WITHIN-STUDY functional.\n",
      "For ACROSS-STUDY correlation, use functional_correlation().\n",
      "See ?`functional-paradigms` for details."
    )
  }

  n <- nrow(data)

  # Step 1: Estimate conditional means μ(A,X) with cross-fitting

  # For surrogate S
  eff_S <- estimate_treatment_effects(
    data = data,
    outcome = "S",
    covariates = covariates,
    method = nuisance_method,
    cross_fit = cross_fit,
    K = K,
    return_diagnostics = FALSE
  )

  # For outcome Y
  eff_Y <- estimate_treatment_effects(
    data = data,
    outcome = "Y",
    covariates = covariates,
    method = nuisance_method,
    cross_fit = cross_fit,
    K = K,
    return_diagnostics = FALSE
  )

  # Step 2: Estimate propensity scores
  ps_method <- switch(nuisance_method,
    "lm" = "logistic",
    "gam" = "gam",
    "rf" = "rf",
    "logistic"  # default
  )

  ps <- estimate_propensity_score(
    data = data,
    covariates = covariates,
    method = ps_method,
    cross_fit = cross_fit,
    K = K,
    return_diagnostics = FALSE
  )

  # Extract estimates
  tau_S <- eff_S$tau_hat
  tau_Y <- eff_Y$tau_hat
  mu_S1 <- eff_S$mu1_hat
  mu_S0 <- eff_S$mu0_hat
  mu_Y1 <- eff_Y$mu1_hat
  mu_Y0 <- eff_Y$mu0_hat
  e_X <- ps$e_hat

  A <- data$A
  S <- data$S
  Y <- data$Y

  # Step 3: Compute doubly robust corrections

  # For E[τ_S(X)]
  # DR correction: (A/e - (1-A)/(1-e)) * residual
  S_correction <- (A / e_X) * (S - mu_S1) - ((1 - A) / (1 - e_X)) * (S - mu_S0)
  E_tau_S <- mean(tau_S + S_correction)

  # For E[τ_Y(X)]
  Y_correction <- (A / e_X) * (Y - mu_Y1) - ((1 - A) / (1 - e_X)) * (Y - mu_Y0)
  E_tau_Y <- mean(tau_Y + Y_correction)

  # For E[τ_S(X) · τ_Y(X)] - more complex
  # Start with plug-in: τ̂_S(X) · τ̂_Y(X)
  prod_term <- tau_S * tau_Y

  # DR correction for product (derived from influence function theory)
  # When A=1: correction involves (S - μ_S1) and (Y - μ_Y1)
  # When A=0: correction involves (S - μ_S0) and (Y - μ_Y0)
  prod_correction <- (A / e_X) * (
    (S - mu_S1) * tau_Y + (Y - mu_Y1) * tau_S + (S - mu_S1) * (Y - mu_Y1)
  ) - ((1 - A) / (1 - e_X)) * (
    (S - mu_S0) * tau_Y + (Y - mu_Y0) * tau_S + (S - mu_S0) * (Y - mu_Y0)
  )

  E_prod <- mean(prod_term + prod_correction)

  # Step 4: Covariance = E[prod] - E[τ_S] · E[τ_Y]
  phi <- E_prod - E_tau_S * E_tau_Y

  # Step 5: Influence function for variance estimation
  # ψ_cov(O) = ψ_prod(O) - E[τ_S] · ψ_Y(O) - E[τ_Y] · ψ_S(O)

  # Individual influence function components
  psi_prod <- prod_term + prod_correction - E_prod
  psi_S <- tau_S + S_correction - E_tau_S
  psi_Y <- tau_Y + Y_correction - E_tau_Y

  # Combined influence function for covariance
  psi_cov <- psi_prod - E_tau_S * psi_Y - E_tau_Y * psi_S

  # Variance and standard error
  var_phi <- var(psi_cov) / n
  se_phi <- sqrt(var_phi)

  # 95% Confidence interval
  ci <- phi + c(-1.96, 1.96) * se_phi

  # Build result list
  result <- list(
    phi = phi,
    se = se_phi,
    ci = ci,
    E_tau_S = E_tau_S,
    E_tau_Y = E_tau_Y,
    E_product = E_prod,
    tau_S = tau_S,
    tau_Y = tau_Y
  )

  # Optional: return influence function
  if (return_influence_function) {
    result$influence_function <- psi_cov
  }

  # Optional: return nuisance estimates
  if (return_nuisance) {
    result$nuisance_estimates <- list(
      mu_S1 = mu_S1,
      mu_S0 = mu_S0,
      mu_Y1 = mu_Y1,
      mu_Y0 = mu_Y0,
      e_X = e_X
    )
  }

  result
}
