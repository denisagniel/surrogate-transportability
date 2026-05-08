#' TV Ball Correlation with IF-Based Inference (Bootstrap + Importance Weighting)
#'
#' @param data Data frame with X, A, S, Y
#' @param lambda TV ball radius
#' @param M Number of future studies
#' @param burn_in MCMC burn-in
#' @param thin MCMC thinning
#' @param alpha Significance level
#' @param method "bootstrap" (default) or "importance_weighting"
#' @param verbose Print progress?
#'
#' @export
tv_ball_correlation_IF_v2 <- function(data,
                                      lambda,
                                      M = 500,
                                      burn_in = 1000,
                                      thin = 10,
                                      alpha = 0.05,
                                      method = c("bootstrap", "importance_weighting"),
                                      verbose = TRUE) {

  method <- match.arg(method)

  # Input validation
  required_cols <- c("X", "A", "S", "Y")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Required columns missing: ", paste(missing_cols, collapse = ", "))
  }

  if (!all(data$A %in% c(0, 1))) {
    stop("Treatment A must be binary (0/1)")
  }

  n <- nrow(data)

  if (verbose) {
    message(sprintf("\n=== TV Ball Correlation (%s) ===",
                    ifelse(method == "bootstrap", "Bootstrap", "Importance Weighting")))
    message(sprintf("n = %d, λ = %.3f, M = %d", n, lambda, M))
  }

  # Step 1: Sample from TV ball
  if (verbose) message("\nStep 1: Sampling from TV ball...")

  X_unique <- sort(unique(data$X))
  K <- length(X_unique)

  P0_categorical <- numeric(K)
  for (k in seq_len(K)) {
    P0_categorical[k] <- mean(data$X == X_unique[k])
  }

  if (verbose) {
    message(sprintf("  K = %d categories", K))
    message(sprintf("  P₀ = [%s]", paste(sprintf("%.3f", P0_categorical), collapse = ", ")))
  }

  Q_samples_categorical <- sample_tv_ball(
    P0 = P0_categorical,
    lambda = lambda,
    M = M,
    burn_in = burn_in,
    thin = thin,
    verbose = verbose
  )

  # Step 2: Compute treatment effects
  if (verbose) message(sprintf("\nStep 2: Computing effects via %s...", method))

  Delta_S <- numeric(M)
  Delta_Y <- numeric(M)

  # Storage for importance weighting (need group means for IF)
  if (method == "importance_weighting") {
    mean_S1_vec <- numeric(M)
    mean_S0_vec <- numeric(M)
    mean_Y1_vec <- numeric(M)
    mean_Y0_vec <- numeric(M)
  }

  for (m in seq_len(M)) {
    Q_m <- Q_samples_categorical[m, ]

    if (method == "bootstrap") {
      # Map Q_m to observation probabilities
      obs_probs <- numeric(n)
      for (i in seq_len(n)) {
        k_i <- which(X_unique == data$X[i])
        obs_probs[i] <- Q_m[k_i]
      }

      # Resample with replacement
      resample_idx <- sample(seq_len(n), size = n, replace = TRUE, prob = obs_probs)
      data_resampled <- data[resample_idx, ]

      # Compute effects on resampled data
      Delta_S[m] <- mean(data_resampled$S[data_resampled$A == 1]) -
                    mean(data_resampled$S[data_resampled$A == 0])
      Delta_Y[m] <- mean(data_resampled$Y[data_resampled$A == 1]) -
                    mean(data_resampled$Y[data_resampled$A == 0])

    } else if (method == "importance_weighting") {
      # Compute importance weights w_i = Q(X_i) / P₀(X_i)
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
    }
  }

  if (verbose) {
    message(sprintf("  Mean ΔS: %.3f (SD: %.3f)", mean(Delta_S), sd(Delta_S)))
    message(sprintf("  Mean ΔY: %.3f (SD: %.3f)", mean(Delta_Y), sd(Delta_Y)))
  }

  # Step 3: Correlation
  if (verbose) message("\nStep 3: Computing correlation...")

  rho_hat <- stats::cor(Delta_S, Delta_Y)

  if (verbose) message(sprintf("  ρ̂ = %.4f", rho_hat))

  # Step 4: Gradient
  if (verbose) message("\nStep 4: Computing gradient...")

  grad <- gradient_correlation_analytical(Delta_S, Delta_Y)

  if (any(is.na(grad))) {
    warning("Gradient undefined (zero variance)")
    return(list(
      rho_hat = rho_hat,
      se = NA_real_,
      ci_lower = NA_real_,
      ci_upper = NA_real_,
      IF_vals = rep(NA_real_, n),
      Delta_S = Delta_S,
      Delta_Y = Delta_Y,
      error = "gradient_undefined"
    ))
  }

  grad_S <- grad[, "grad_S"]
  grad_Y <- grad[, "grad_Y"]

  # Step 5: Influence functions
  if (verbose) message(sprintf("\nStep 5: Computing IFs via %s...", method))

  psi_S <- matrix(0, nrow = n, ncol = M)
  psi_Y <- matrix(0, nrow = n, ncol = M)

  for (m in seq_len(M)) {
    Q_m <- Q_samples_categorical[m, ]

    if (method == "bootstrap") {
      # Map Q_m to observation weights
      obs_weights <- numeric(n)
      for (i in seq_len(n)) {
        k_i <- which(X_unique == data$X[i])
        obs_weights[i] <- Q_m[k_i]
      }

      # Normalize
      obs_weights <- obs_weights / sum(obs_weights)

      # Weighted group means
      w1 <- obs_weights * data$A
      w0 <- obs_weights * (1 - data$A)

      mean_S1_m <- sum(w1 * data$S) / sum(w1)
      mean_S0_m <- sum(w0 * data$S) / sum(w0)
      mean_Y1_m <- sum(w1 * data$Y) / sum(w1)
      mean_Y0_m <- sum(w0 * data$Y) / sum(w0)

      # IF for weighted difference-in-means (RCT: e = 0.5)
      for (i in seq_len(n)) {
        psi_S[i, m] <- obs_weights[i] * (
          2 * data$A[i] * (data$S[i] - mean_S1_m) -
          2 * (1 - data$A[i]) * (data$S[i] - mean_S0_m)
        )

        psi_Y[i, m] <- obs_weights[i] * (
          2 * data$A[i] * (data$Y[i] - mean_Y1_m) -
          2 * (1 - data$A[i]) * (data$Y[i] - mean_Y0_m)
        )
      }

    } else if (method == "importance_weighting") {
      # Compute importance weights
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

      # IF with importance weights (RCT: e = 0.5)
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
    }
  }

  # Step 6: Compose IF
  if (verbose) message("\nStep 6: Composing full IF...")

  psi_Theta <- numeric(n)
  for (i in seq_len(n)) {
    psi_Theta[i] <- sum(grad_S * psi_S[i, ] + grad_Y * psi_Y[i, ])
  }

  # Step 7: Variance
  if (verbose) message("\nStep 7: Computing variance...")

  sigma_sq <- mean(psi_Theta^2)
  se <- sqrt(sigma_sq / n)

  if (verbose) {
    message(sprintf("  σ̂² = %.6f", sigma_sq))
    message(sprintf("  SE = %.4f", se))
  }

  # Step 8: CI
  z_crit <- stats::qnorm(1 - alpha / 2)
  ci_lower <- rho_hat - z_crit * se
  ci_upper <- rho_hat + z_crit * se

  if (verbose) {
    message(sprintf("\n=== Results ==="))
    message(sprintf("ρ̂ = %.4f (SE = %.4f)", rho_hat, se))
    message(sprintf("95%% CI: [%.4f, %.4f]", ci_lower, ci_upper))
  }

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
    method = "bootstrap"
  )
}
