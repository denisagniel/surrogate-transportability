#' TV Ball Correlation with IF-Based Inference (RCT Version)
#'
#' Computes correlation functional with influence function-based confidence intervals
#' for randomized controlled trials (RCTs). Uses TV ball geometry to model future
#' study variation and provides √n-consistent asymptotically normal inference.
#'
#' **This is the RCT-only simplified version.** For observational studies with
#' propensity scores and AIPW corrections, use \code{tv_ball_correlation_IF_aipw()}
#' (not yet implemented).
#'
#' @param data Data frame with columns:
#'   \itemize{
#'     \item{X}{Covariate (for defining distribution P₀)}
#'     \item{A}{Treatment indicator (0/1)}
#'     \item{S}{Surrogate outcome}
#'     \item{Y}{Primary outcome}
#'   }
#' @param lambda Numeric. TV ball radius in [0, 1]. Controls how far future studies
#'   can deviate from current study P₀.
#' @param M Integer. Number of future studies to sample from TV ball (default: 500).
#'   Larger M reduces Monte Carlo error but increases computation time.
#' @param burn_in Integer. MCMC burn-in iterations for TV ball sampler (default: 1000).
#' @param thin Integer. MCMC thinning interval (default: 10).
#' @param alpha Numeric. Significance level for confidence interval (default: 0.05).
#' @param method Character. Method for computing treatment effects and IFs:
#'   \itemize{
#'     \item{"importance_weighting"}{Explicit importance weights w_i = Q(X_i)/P₀(X_i)}
#'     \item{"bootstrap"}{Bootstrap resampling with probabilities Q_m (default)}
#'     \item{"aipw"}{Augmented IPW with cross-fitted nuisance estimates}
#'   }
#'   All three are theoretically equivalent; may differ in finite-sample properties.
#' @param n_folds Integer. Number of folds for cross-fitting (only used for AIPW, default: 5)
#' @param verbose Logical. Print progress messages? (default: TRUE)
#'
#' @return List with elements:
#'   \item{rho_hat}{Correlation estimate ρ̂}
#'   \item{se}{Standard error from influence function}
#'   \item{ci_lower}{Lower bound of (1-α)×100\% confidence interval}
#'   \item{ci_upper}{Upper bound of (1-α)×100\% confidence interval}
#'   \item{IF_vals}{Influence function values for each observation (length n)}
#'   \item{Delta_S}{Treatment effects on S in each future study (length M)}
#'   \item{Delta_Y}{Treatment effects on Y in each future study (length M)}
#'   \item{Q_samples}{Sampled distributions from TV ball (M × n matrix)}
#'   \item{lambda}{TV ball radius used}
#'   \item{M}{Number of future studies sampled}
#'   \item{n}{Sample size}
#'
#' @details
#' **Algorithm (RCT-Simplified):**
#'
#' 1. **Sample M future studies from TV ball:** Use hit-and-run MCMC to sample
#'    Q₁,...,Q_M from B_λ(P₀) where P₀ is the empirical distribution over X.
#'
#' 2. **Compute treatment effects:** For each Q_m, compute Δ_S(Q_m) and Δ_Y(Q_m)
#'    using weighted difference-in-means (no outcome regression needed for RCT).
#'
#' 3. **Compute correlation:** ρ̂ = cor({Δ_S(Q_m)}, {Δ_Y(Q_m)}) across M studies.
#'
#' 4. **Compute gradient:** For each Q_m, compute ∇φ(Δ_S(Q_m), Δ_Y(Q_m)) - the
#'    gradient of correlation at that study's treatment effects.
#'
#' 5. **Compute influence functions:** For each observation i and each Q_m,
#'    compute the AIPW IF for treatment effects under Q_m:
#'    \deqn{
#'      \psi_S(O_i; Q_m) = w_m[i] \left[
#'        \frac{A_i (S_i - \bar{S}_1)}{0.5} - \frac{(1-A_i)(S_i - \bar{S}_0)}{0.5}
#'      \right]
#'    }
#'    (Similarly for ψ_Y)
#'
#' 6. **Compose full IF:** Combine via chain rule:
#'    \deqn{
#'      \psi_\Theta(O_i) = \sum_{m=1}^M \left[
#'        \nabla\phi(Q_m) \cdot \begin{pmatrix} \psi_S(O_i; Q_m) \\
#'                                               \psi_Y(O_i; Q_m) \end{pmatrix}
#'      \right]
#'    }
#'
#' 7. **Variance estimation:** σ̂² = (1/n) Σᵢ ψ_Θ(O_i)²
#'
#' 8. **Confidence interval:** ρ̂ ± z_{α/2} × sqrt(σ̂²/n)
#'
#' **Theoretical Properties:**
#'
#' - **Asymptotic normality:** √n(ρ̂ - ρ(μ_M)) →_d N(0, σ²(μ_M))
#' - **Rate:** √n-consistent (semiparametric efficient for RCTs)
#' - **MCMC approximation:** For M ≥ 500, Monte Carlo error is O(M^{-1/2}) ≈ 0.045 SE
#'
#' **RCT Assumptions:**
#'
#' - **Randomization:** A ⊥ (X, S₀, S₁, Y₀, Y₁)
#' - **Known propensity:** e(X) = P(A=1|X) = 0.5 (balanced randomization)
#' - **Overlap:** Automatic (e = 0.5 for all units)
#' - **Consistency:** S = A·S₁ + (1-A)·S₀, Y = A·Y₁ + (1-A)·Y₀
#'
#' **Comparison to bootstrap:**
#' - IF-based: ~10× faster, theoretically grounded, analytical SE
#' - Bootstrap: More robust to misspecification, no gradient needed
#'
#' @section Selecting M:
#'
#' Tradeoff between Monte Carlo error and computation time:
#' \itemize{
#'   \item{M = 200}{Fast (~5 sec), MCMC error ~0.07 SE}
#'   \item{M = 500 (default)}{Moderate (~10 sec), MCMC error ~0.045 SE}
#'   \item{M = 1000}{Slower (~20 sec), MCMC error ~0.03 SE}
#' }
#'
#' For most applications, M = 500 provides good balance. Increase M if you need
#' very precise estimates or are close to decision boundaries.
#'
#' @references
#' Chernozhukov, V., et al. (2018). Double/debiased machine learning for treatment
#' and structural parameters. \emph{The Econometrics Journal}, 21(1), C1-C68.
#'
#' Kennedy, E. H. (2022). Semiparametric doubly robust targeted double machine
#' learning: A review. \emph{arXiv preprint arXiv:2203.06469}.
#'
#' @examples
#' \dontrun{
#' # Generate RCT data
#' n <- 500
#' data <- data.frame(
#'   X = rnorm(n),
#'   A = rbinom(n, 1, 0.5)
#' )
#' data$S <- data$A * (0.3 + 0.2 * data$X) + rnorm(n, sd = 0.5)
#' data$Y <- data$A * (0.4 + 0.25 * data$X) + rnorm(n, sd = 0.6)
#'
#' # Estimate correlation with IF-based inference
#' result <- tv_ball_correlation_IF(
#'   data = data,
#'   lambda = 0.3,
#'   M = 500
#' )
#'
#' # Results
#' cat(sprintf("Correlation: %.3f (SE = %.3f)\n", result$rho_hat, result$se))
#' cat(sprintf("95%% CI: [%.3f, %.3f]\n", result$ci_lower, result$ci_upper))
#'
#' # Diagnostics
#' hist(result$IF_vals, main = "Influence Function Values", xlab = "IF")
#' plot(result$Delta_S, result$Delta_Y,
#'      main = "Treatment Effects Across Future Studies",
#'      xlab = "Delta_S", ylab = "Delta_Y")
#' abline(lm(result$Delta_Y ~ result$Delta_S), col = "red", lty = 2)
#' }
#'
#' @export
tv_ball_correlation_IF <- function(data,
                                   lambda,
                                   M = 500,
                                   burn_in = 1000,
                                   thin = 10,
                                   alpha = 0.05,
                                   method = c("bootstrap", "importance_weighting", "aipw"),
                                   n_folds = 5,
                                   verbose = TRUE) {

  # Input validation
  required_cols <- c("X", "A", "S", "Y")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Required columns missing: ", paste(missing_cols, collapse = ", "))
  }

  if (!all(data$A %in% c(0, 1))) {
    stop("Treatment A must be binary (0/1)")
  }

  method <- match.arg(method)

  n <- nrow(data)

  if (verbose) {
    message("\n=== TV Ball Correlation with IF-Based Inference (RCT) ===")
    message(sprintf("Sample size: n = %d", n))
    message(sprintf("TV ball radius: λ = %.3f", lambda))
    message(sprintf("Number of future studies: M = %d", M))
    message(sprintf("Method: %s", method))
  }

  # Step 1: Sample from TV ball
  if (verbose) message("\nStep 1: Sampling future studies from TV ball...")

  # For discrete X: Create distribution over unique X values
  # Identify unique X values and their frequencies
  X_unique <- sort(unique(data$X))
  K <- length(X_unique)

  # Compute empirical distribution P₀ over K categories
  P0_categorical <- numeric(K)
  for (k in seq_len(K)) {
    P0_categorical[k] <- mean(data$X == X_unique[k])
  }

  if (verbose) {
    message(sprintf("  Covariate X has %d unique values (discrete)", K))
    message(sprintf("  P₀ distribution: %s",
                    paste(sprintf("%.3f", P0_categorical), collapse = ", ")))
  }

  # Sample distributions over K categories
  Q_samples_categorical <- sample_tv_ball(
    P0 = P0_categorical,
    lambda = lambda,
    M = M,
    burn_in = burn_in,
    thin = thin,
    verbose = verbose
  )

  # Step 2: Compute treatment effects for each Q_m
  if (verbose) message(sprintf("\nStep 2: Computing treatment effects via %s...", method))

  Delta_S <- numeric(M)
  Delta_Y <- numeric(M)

  # Storage for group means (needed for IF computation)
  mean_S1_vec <- numeric(M)
  mean_S0_vec <- numeric(M)
  mean_Y1_vec <- numeric(M)
  mean_Y0_vec <- numeric(M)

  # Storage for AIPW nuisance estimates (M sets, one per Q_m)
  if (method == "aipw") {
    # Pre-allocate storage for M sets of nuisance estimates
    e_hat_all <- matrix(0, nrow = n, ncol = M)
    mu_1S_hat_all <- matrix(0, nrow = n, ncol = M)
    mu_0S_hat_all <- matrix(0, nrow = n, ncol = M)
    mu_1Y_hat_all <- matrix(0, nrow = n, ncol = M)
    mu_0Y_hat_all <- matrix(0, nrow = n, ncol = M)

    if (verbose) message(sprintf("  Pre-computing nuisance estimates for %d studies (with cross-fitting)...", M))

    # Create folds (same for all Q_m for reproducibility)
    folds <- sample(rep(1:n_folds, length.out = n))
  }

  # Compute treatment effects for each Q_m
  for (m in seq_len(M)) {
    Q_m <- Q_samples_categorical[m, ]

    # Map Q_m to observation weights
    obs_weights <- numeric(n)
    for (i in seq_len(n)) {
      k_i <- which(X_unique == data$X[i])
      obs_weights[i] <- Q_m[k_i]
    }

    if (method == "bootstrap") {
      # Bootstrap resampling: resample with probabilities Q_m
      resample_indices <- sample(seq_len(n), size = n, replace = TRUE, prob = obs_weights)
      data_resampled <- data[resample_indices, ]

      # Treatment effects on resampled data
      Delta_S[m] <- mean(data_resampled$S[data_resampled$A == 1]) -
                    mean(data_resampled$S[data_resampled$A == 0])
      Delta_Y[m] <- mean(data_resampled$Y[data_resampled$A == 1]) -
                    mean(data_resampled$Y[data_resampled$A == 0])

    } else if (method == "importance_weighting") {
      # Importance weighting: explicit weights w_i = Q(X_i)/P₀(X_i)
      w_i <- numeric(n)
      for (i in seq_len(n)) {
        k_i <- which(X_unique == data$X[i])
        w_i[i] <- Q_m[k_i] / P0_categorical[k_i]
      }

      # Weighted group means
      w1 <- w_i * data$A
      w0 <- w_i * (1 - data$A)

      mean_S1_vec[m] <- sum(w1 * data$S) / sum(w1)
      mean_S0_vec[m] <- sum(w0 * data$S) / sum(w0)
      mean_Y1_vec[m] <- sum(w1 * data$Y) / sum(w1)
      mean_Y0_vec[m] <- sum(w0 * data$Y) / sum(w0)

      Delta_S[m] <- mean_S1_vec[m] - mean_S0_vec[m]
      Delta_Y[m] <- mean_Y1_vec[m] - mean_Y0_vec[m]

    } else if (method == "aipw") {
      # AIPW: fit nuisances under Q_m distribution via weighted cross-fitting
      # Storage for Q_m-specific nuisance estimates
      e_hat_m <- numeric(n)
      mu_1S_hat_m <- numeric(n)
      mu_0S_hat_m <- numeric(n)
      mu_1Y_hat_m <- numeric(n)
      mu_0Y_hat_m <- numeric(n)

      # Cross-fitting loop with Q_m weights
      for (fold in 1:n_folds) {
        test_idx <- (folds == fold)
        train_idx <- !test_idx

        # Training weights (Q_m probabilities for training observations)
        train_weights <- obs_weights[train_idx]

        # For RCT: e(X) = 0.5 is known (no need to estimate)
        e_hat_m[test_idx] <- 0.5

        # Fit outcome regressions with weights
        # For treated units
        train_treated_idx <- train_idx & (data$A == 1)
        if (sum(train_treated_idx) > K) {  # Need enough observations
          mu_1S_model <- stats::lm(S ~ factor(X), data = data[train_treated_idx, ],
                                    weights = train_weights[data$A[train_idx] == 1])
          mu_1S_hat_m[test_idx] <- stats::predict(mu_1S_model, newdata = data[test_idx, ])

          mu_1Y_model <- stats::lm(Y ~ factor(X), data = data[train_treated_idx, ],
                                    weights = train_weights[data$A[train_idx] == 1])
          mu_1Y_hat_m[test_idx] <- stats::predict(mu_1Y_model, newdata = data[test_idx, ])
        } else {
          # Fallback: use overall means
          mu_1S_hat_m[test_idx] <- mean(data$S[data$A == 1])
          mu_1Y_hat_m[test_idx] <- mean(data$Y[data$A == 1])
        }

        # For control units
        train_control_idx <- train_idx & (data$A == 0)
        if (sum(train_control_idx) > K) {  # Need enough observations
          mu_0S_model <- stats::lm(S ~ factor(X), data = data[train_control_idx, ],
                                    weights = train_weights[data$A[train_idx] == 0])
          mu_0S_hat_m[test_idx] <- stats::predict(mu_0S_model, newdata = data[test_idx, ])

          mu_0Y_model <- stats::lm(Y ~ factor(X), data = data[train_control_idx, ],
                                    weights = train_weights[data$A[train_idx] == 0])
          mu_0Y_hat_m[test_idx] <- stats::predict(mu_0Y_model, newdata = data[test_idx, ])
        } else {
          # Fallback: use overall means
          mu_0S_hat_m[test_idx] <- mean(data$S[data$A == 0])
          mu_0Y_hat_m[test_idx] <- mean(data$Y[data$A == 0])
        }
      }

      # Store nuisance estimates for this Q_m
      e_hat_all[, m] <- e_hat_m
      mu_1S_hat_all[, m] <- mu_1S_hat_m
      mu_0S_hat_all[, m] <- mu_0S_hat_m
      mu_1Y_hat_all[, m] <- mu_1Y_hat_m
      mu_0Y_hat_all[, m] <- mu_0Y_hat_m

      # Compute AIPW treatment effects (no additional importance weights needed,
      # already incorporated in nuisance fitting)
      ipw_term_S <- (
        data$A * (data$S - mu_1S_hat_m) / e_hat_m -
        (1 - data$A) * (data$S - mu_0S_hat_m) / (1 - e_hat_m)
      )
      reg_term_S <- mu_1S_hat_m - mu_0S_hat_m

      ipw_term_Y <- (
        data$A * (data$Y - mu_1Y_hat_m) / e_hat_m -
        (1 - data$A) * (data$Y - mu_0Y_hat_m) / (1 - e_hat_m)
      )
      reg_term_Y <- mu_1Y_hat_m - mu_0Y_hat_m

      Delta_S[m] <- mean(ipw_term_S + reg_term_S)
      Delta_Y[m] <- mean(ipw_term_Y + reg_term_Y)
    }
  }

  if (verbose) {
    message(sprintf("  Treatment effects across %d studies:", M))
    message(sprintf("    Mean Delta_S: %.3f (SD: %.3f)",
                    mean(Delta_S), stats::sd(Delta_S)))
    message(sprintf("    Mean Delta_Y: %.3f (SD: %.3f)",
                    mean(Delta_Y), stats::sd(Delta_Y)))
  }

  # Step 3: Compute correlation functional
  if (verbose) message("\nStep 3: Computing correlation across future studies...")

  rho_hat <- stats::cor(Delta_S, Delta_Y)

  if (verbose) {
    message(sprintf("  Correlation estimate: ρ̂ = %.4f", rho_hat))
  }

  # Step 4: Compute gradient at each (Delta_S[m], Delta_Y[m])
  if (verbose) message("\nStep 4: Computing gradient of correlation functional...")

  grad <- gradient_correlation_analytical(Delta_S, Delta_Y)

  # Check for gradient issues
  if (any(is.na(grad))) {
    warning("Gradient contains NA values. Check for zero variance in treatment effects.")
    # Return with NA standard error
    return(list(
      rho_hat = rho_hat,
      se = NA_real_,
      ci_lower = NA_real_,
      ci_upper = NA_real_,
      IF_vals = rep(NA_real_, n),
      Delta_S = Delta_S,
      Delta_Y = Delta_Y,
      Q_samples = Q_samples_categorical,
      lambda = lambda,
      M = M,
      n = n,
      gradient = grad,
      error = "Gradient undefined (zero variance in treatment effects)"
    ))
  }

  # Extract gradients
  grad_S <- grad[, "grad_S"]
  grad_Y <- grad[, "grad_Y"]

  # Step 5: Compute influence functions
  if (verbose) message(sprintf("\nStep 5: Computing influence functions via %s...", method))

  psi_S <- matrix(0, nrow = n, ncol = M)
  psi_Y <- matrix(0, nrow = n, ncol = M)

  for (m in seq_len(M)) {
    Q_m <- Q_samples_categorical[m, ]

    # Map Q_m to observation weights
    obs_weights <- numeric(n)
    for (i in seq_len(n)) {
      k_i <- which(X_unique == data$X[i])
      obs_weights[i] <- Q_m[k_i]
    }

    if (method == "bootstrap") {
      # Bootstrap method: weighted IF matching the resampling approach
      # Map Q_m (distribution over K categories) to observation weights
      obs_weights_norm <- obs_weights / sum(obs_weights)

      # Weighted group means under Q_m
      w1 <- obs_weights_norm * data$A
      w0 <- obs_weights_norm * (1 - data$A)

      mean_S1_m <- sum(w1 * data$S) / sum(w1)
      mean_S0_m <- sum(w0 * data$S) / sum(w0)
      mean_Y1_m <- sum(w1 * data$Y) / sum(w1)
      mean_Y0_m <- sum(w0 * data$Y) / sum(w0)

      # IF for weighted difference-in-means
      # ψ_i = w_i × [A_i/e × (S_i - μ_1) - (1-A_i)/(1-e) × (S_i - μ_0)]
      # For RCT: e = 0.5
      for (i in seq_len(n)) {
        psi_S[i, m] <- obs_weights_norm[i] * (
          2 * data$A[i] * (data$S[i] - mean_S1_m) -
          2 * (1 - data$A[i]) * (data$S[i] - mean_S0_m)
        )

        psi_Y[i, m] <- obs_weights_norm[i] * (
          2 * data$A[i] * (data$Y[i] - mean_Y1_m) -
          2 * (1 - data$A[i]) * (data$Y[i] - mean_Y0_m)
        )
      }

    } else if (method == "importance_weighting") {
      # Importance weighting: explicit weights w_i = Q(X_i)/P₀(X_i)
      w_i <- numeric(n)
      for (i in seq_len(n)) {
        k_i <- which(X_unique == data$X[i])
        w_i[i] <- Q_m[k_i] / P0_categorical[k_i]
      }

      # Use stored group means from Step 2
      mean_S1_m <- mean_S1_vec[m]
      mean_S0_m <- mean_S0_vec[m]
      mean_Y1_m <- mean_Y1_vec[m]
      mean_Y0_m <- mean_Y0_vec[m]

      # AIPW IF for treatment effects (RCT formula: e = 0.5)
      for (i in seq_len(n)) {
        psi_S[i, m] <- w_i[i] * (
          2 * data$A[i] * (data$S[i] - mean_S1_m) -
          2 * (1 - data$A[i]) * (data$S[i] - mean_S0_m)
        )

        psi_Y[i, m] <- w_i[i] * (
          2 * data$A[i] * (data$Y[i] - mean_Y1_m) -
          2 * (1 - data$A[i]) * (data$Y[i] - mean_Y0_m)
        )
      }

    } else if (method == "aipw") {
      # AIPW: full three-term IF using Q_m-specific nuisances
      # Retrieve nuisance estimates for this Q_m
      e_hat_m <- e_hat_all[, m]
      mu_1S_hat_m <- mu_1S_hat_all[, m]
      mu_0S_hat_m <- mu_0S_hat_all[, m]
      mu_1Y_hat_m <- mu_1Y_hat_all[, m]
      mu_0Y_hat_m <- mu_0Y_hat_all[, m]

      # AIPW IF (three terms: IPW + regression adjustment - centering)
      # No additional importance weights needed - already incorporated in nuisance fitting
      for (i in seq_len(n)) {
        psi_S[i, m] <- (
          data$A[i] * (data$S[i] - mu_1S_hat_m[i]) / e_hat_m[i] -
          (1 - data$A[i]) * (data$S[i] - mu_0S_hat_m[i]) / (1 - e_hat_m[i]) +
          mu_1S_hat_m[i] - mu_0S_hat_m[i] - Delta_S[m]
        )

        psi_Y[i, m] <- (
          data$A[i] * (data$Y[i] - mu_1Y_hat_m[i]) / e_hat_m[i] -
          (1 - data$A[i]) * (data$Y[i] - mu_0Y_hat_m[i]) / (1 - e_hat_m[i]) +
          mu_1Y_hat_m[i] - mu_0Y_hat_m[i] - Delta_Y[m]
        )
      }
    }
  }

  # Step 6: Compose full IF via chain rule
  if (verbose) message("\nStep 6: Composing full influence function...")

  psi_Theta <- numeric(n)

  for (i in seq_len(n)) {
    # Sum over all Q_m: gradient · IF
    # This is the chain rule: ∂ρ/∂O_i = Σ_m [∂ρ/∂Δ_S(Q_m) × ∂Δ_S(Q_m)/∂O_i +
    #                                          ∂ρ/∂Δ_Y(Q_m) × ∂Δ_Y(Q_m)/∂O_i]
    psi_Theta[i] <- sum(grad_S * psi_S[i, ] + grad_Y * psi_Y[i, ])
  }

  # Check that IF is approximately centered (should sum to ~0)
  if (verbose) {
    if_sum <- sum(psi_Theta)
    if (abs(if_sum) > 0.01 * n) {
      message(sprintf("  Warning: IF sum = %.3f (should be ≈ 0). Check centering.", if_sum))
    }
  }

  # Step 7: Variance estimation
  if (verbose) message("\nStep 7: Computing variance and standard error...")

  sigma_sq <- mean(psi_Theta^2)
  se <- sqrt(sigma_sq / n)

  if (verbose) {
    message(sprintf("  Variance: σ̂² = %.6f", sigma_sq))
    message(sprintf("  Standard error: SE = %.4f", se))
  }

  # Step 8: Confidence interval
  if (verbose) message("\nStep 8: Computing confidence interval...")

  z_crit <- stats::qnorm(1 - alpha / 2)
  ci_lower <- rho_hat - z_crit * se
  ci_upper <- rho_hat + z_crit * se

  if (verbose) {
    message(sprintf("\n=== Results ==="))
    message(sprintf("Correlation: ρ̂ = %.4f (SE = %.4f)", rho_hat, se))
    message(sprintf("%.0f%% CI: [%.4f, %.4f]", 100 * (1 - alpha), ci_lower, ci_upper))
    message(sprintf("\nInterpretation: In future studies within λ=%.2f of current study,", lambda))
    message(sprintf("the correlation between treatment effects is estimated as %.2f.", rho_hat))
  }

  # Return results
  list(
    rho_hat = rho_hat,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    IF_vals = psi_Theta,
    Delta_S = Delta_S,
    Delta_Y = Delta_Y,
    Q_samples = Q_samples_categorical,
    X_unique = X_unique,
    K = K,
    gradient = grad,
    lambda = lambda,
    M = M,
    n = n,
    alpha = alpha,
    burn_in = burn_in,
    thin = thin,
    method = method,
    n_folds = n_folds
  )
}
