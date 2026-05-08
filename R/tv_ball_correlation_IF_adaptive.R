#' TV Ball Correlation with Adaptive M (IF-Based Inference)
#'
#' Automatically increases M until correlation estimate stabilizes.
#'
#' @param data Data frame with X, A, S, Y
#' @param lambda TV ball radius
#' @param M_start Initial number of future studies (default: 300)
#' @param M_increment How much to increase M each iteration (default: 300)
#' @param M_max Maximum M to try (default: 5000)
#' @param tolerance Convergence tolerance (default: 0.01)
#' @param n_stable Number of consecutive stable iterations required (default: 3)
#' @param burn_in MCMC burn-in
#' @param thin MCMC thinning
#' @param alpha Significance level
#' @param method "bootstrap" or "importance_weighting"
#' @param verbose Print progress?
#'
#' @return List with rho_hat, se, ci_lower, ci_upper, IF_vals, and convergence info
#'
#' @details
#' The algorithm:
#' 1. Start with M = M_start
#' 2. Compute ρ̂(M)
#' 3. Increase M by M_increment
#' 4. Compute ρ̂(M + M_increment)
#' 5. Check convergence: ALL of the following must hold:
#'    - Each consecutive change |ρ̂_t - ρ̂_{t-1}| < tolerance
#'    - Overall change |ρ̂_t - ρ̂_{t-n_stable}| < tolerance
#'    - This must hold for n_stable consecutive iterations
#' 6. If converged, stop. Otherwise, repeat from step 3 (up to M_max)
#'
#' This prevents both premature convergence and consistent drift.
#'
#' @export
tv_ball_correlation_IF_adaptive <- function(data,
                                           lambda,
                                           M_start = 300,
                                           M_increment = 300,
                                           M_max = 5000,
                                           tolerance = 0.01,
                                           n_stable = 3,
                                           burn_in = 500,
                                           thin = 5,
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
    message(sprintf("\n=== TV Ball Correlation (Adaptive M) ==="))
    message(sprintf("Method: %s", ifelse(method == "bootstrap", "Bootstrap", "Importance Weighting")))
    message(sprintf("n = %d, λ = %.3f", n, lambda))
    message(sprintf("M_start = %d, M_increment = %d, M_max = %d", M_start, M_increment, M_max))
    message(sprintf("Tolerance = %.4f, n_stable = %d\n", tolerance, n_stable))
  }

  # Get X distribution
  X_unique <- sort(unique(data$X))
  K <- length(X_unique)

  P0_categorical <- numeric(K)
  for (k in seq_len(K)) {
    P0_categorical[k] <- mean(data$X == X_unique[k])
  }

  if (verbose) {
    message(sprintf("K = %d categories", K))
    message(sprintf("P₀ = [%s]", paste(sprintf("%.3f", P0_categorical), collapse = ", ")))
  }

  # Adaptive M loop
  M_current <- 0
  M_target <- M_start
  rho_history <- numeric(0)
  M_history <- numeric(0)
  converged <- FALSE

  # Pre-sample large Q matrix (sample M_max at once for efficiency)
  if (verbose) message(sprintf("\nPre-sampling %d distributions from TV ball...", M_max))

  Q_samples_all <- sample_tv_ball(
    P0 = P0_categorical,
    lambda = lambda,
    M = M_max,
    burn_in = burn_in,
    thin = thin,
    verbose = FALSE
  )

  if (verbose) message("Starting adaptive M loop...\n")

  while (M_current < M_max && !converged) {
    # Use Q samples from M_current+1 to M_target
    Q_samples <- Q_samples_all[(M_current + 1):M_target, , drop = FALSE]
    M_batch <- M_target - M_current

    if (verbose) {
      message(sprintf("Iteration %d: M = %d (adding %d new samples)",
                      length(M_history) + 1, M_target, M_batch))
    }

    # Compute treatment effects for this batch
    Delta_S_batch <- numeric(M_batch)
    Delta_Y_batch <- numeric(M_batch)

    if (method == "importance_weighting") {
      mean_S1_batch <- numeric(M_batch)
      mean_S0_batch <- numeric(M_batch)
      mean_Y1_batch <- numeric(M_batch)
      mean_Y0_batch <- numeric(M_batch)
    }

    for (m in seq_len(M_batch)) {
      Q_m <- Q_samples[m, ]

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
        Delta_S_batch[m] <- mean(data_resampled$S[data_resampled$A == 1]) -
                            mean(data_resampled$S[data_resampled$A == 0])
        Delta_Y_batch[m] <- mean(data_resampled$Y[data_resampled$A == 1]) -
                            mean(data_resampled$Y[data_resampled$A == 0])

      } else if (method == "importance_weighting") {
        # Compute importance weights
        w_i <- numeric(n)
        for (i in seq_len(n)) {
          k_i <- which(X_unique == data$X[i])
          w_i[i] <- Q_m[k_i] / P0_categorical[k_i]
        }

        # Weighted group means
        w1 <- w_i * data$A
        w0 <- w_i * (1 - data$A)

        mean_S1_batch[m] <- sum(w1 * data$S) / sum(w1)
        mean_S0_batch[m] <- sum(w0 * data$S) / sum(w0)
        mean_Y1_batch[m] <- sum(w1 * data$Y) / sum(w1)
        mean_Y0_batch[m] <- sum(w0 * data$Y) / sum(w0)

        Delta_S_batch[m] <- mean_S1_batch[m] - mean_S0_batch[m]
        Delta_Y_batch[m] <- mean_Y1_batch[m] - mean_Y0_batch[m]
      }
    }

    # Append to cumulative vectors
    if (M_current == 0) {
      Delta_S <- Delta_S_batch
      Delta_Y <- Delta_Y_batch
      if (method == "importance_weighting") {
        mean_S1_vec <- mean_S1_batch
        mean_S0_vec <- mean_S0_batch
        mean_Y1_vec <- mean_Y1_batch
        mean_Y0_vec <- mean_Y0_batch
      }
    } else {
      Delta_S <- c(Delta_S, Delta_S_batch)
      Delta_Y <- c(Delta_Y, Delta_Y_batch)
      if (method == "importance_weighting") {
        mean_S1_vec <- c(mean_S1_vec, mean_S1_batch)
        mean_S0_vec <- c(mean_S0_vec, mean_S0_batch)
        mean_Y1_vec <- c(mean_Y1_vec, mean_Y1_batch)
        mean_Y0_vec <- c(mean_Y0_vec, mean_Y0_batch)
      }
    }

    # Compute correlation with cumulative samples
    rho_new <- stats::cor(Delta_S, Delta_Y)

    # Store history
    M_history <- c(M_history, M_target)
    rho_history <- c(rho_history, rho_new)

    if (verbose) {
      message(sprintf("  ρ̂ = %.4f", rho_new))
    }

    # Check convergence (requires sliding window of n_stable + 1 values)
    if (length(rho_history) >= n_stable + 1) {
      # Get last n_stable + 1 values
      window <- rho_history[(length(rho_history) - n_stable):length(rho_history)]

      # Check all consecutive changes in window
      consecutive_changes <- abs(diff(window))
      all_small <- all(consecutive_changes < tolerance)

      # Check cumulative change from start to end of window
      cumulative_change <- abs(window[length(window)] - window[1])

      if (verbose) {
        message(sprintf("  Window changes: [%s]",
                       paste(sprintf("%.4f", consecutive_changes), collapse = ", ")))
        message(sprintf("  Cumulative change (t to t+%d): %.4f", n_stable, cumulative_change))
      }

      if (all_small && cumulative_change < tolerance) {
        converged <- TRUE
        if (verbose) {
          message(sprintf("  ✓ Converged! (All changes < %.4f, cumulative < %.4f)\n",
                         tolerance, tolerance))
        }
      }
    } else {
      # Not enough history yet
      if (verbose && length(rho_history) > 1) {
        change <- abs(rho_history[length(rho_history)] - rho_history[length(rho_history) - 1])
        message(sprintf("  Change from previous: %.4f (need %d more iterations)",
                       change, n_stable + 1 - length(rho_history)))
      }
    }

    # Update for next iteration
    rho_old <- rho_new
    M_current <- M_target
    M_target <- min(M_current + M_increment, M_max)
  }

  if (!converged && verbose) {
    message(sprintf("\n⚠ Did not converge within M_max = %d", M_max))
    message(sprintf("  Final change: %.4f (tolerance: %.4f)", abs(rho_history[length(rho_history)] - rho_history[length(rho_history) - 1]), tolerance))
  }

  # Use final M
  M_final <- M_current
  rho_hat <- rho_history[length(rho_history)]

  if (verbose) {
    message(sprintf("\nFinal M = %d, ρ̂ = %.4f", M_final, rho_hat))
  }

  # Now compute full inference with final M
  Q_samples_final <- Q_samples_all[1:M_final, , drop = FALSE]

  # Compute gradient
  if (verbose) message("\nComputing gradient...")

  grad <- gradient_correlation_analytical(Delta_S, Delta_Y)

  if (any(is.na(grad))) {
    warning("Gradient undefined (zero variance)")
    return(list(
      rho_hat = rho_hat,
      se = NA_real_,
      ci_lower = NA_real_,
      ci_upper = NA_real_,
      IF_vals = rep(NA_real_, n),
      M_final = M_final,
      M_history = M_history,
      rho_history = rho_history,
      converged = converged,
      error = "gradient_undefined"
    ))
  }

  grad_S <- grad[, "grad_S"]
  grad_Y <- grad[, "grad_Y"]

  # Compute influence functions
  if (verbose) message("Computing influence functions...")

  psi_S <- matrix(0, nrow = n, ncol = M_final)
  psi_Y <- matrix(0, nrow = n, ncol = M_final)

  for (m in seq_len(M_final)) {
    Q_m <- Q_samples_final[m, ]

    if (method == "bootstrap") {
      obs_weights <- numeric(n)
      for (i in seq_len(n)) {
        k_i <- which(X_unique == data$X[i])
        obs_weights[i] <- Q_m[k_i]
      }

      obs_weights <- obs_weights / sum(obs_weights)

      w1 <- obs_weights * data$A
      w0 <- obs_weights * (1 - data$A)

      mean_S1_m <- sum(w1 * data$S) / sum(w1)
      mean_S0_m <- sum(w0 * data$S) / sum(w0)
      mean_Y1_m <- sum(w1 * data$Y) / sum(w1)
      mean_Y0_m <- sum(w0 * data$Y) / sum(w0)

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
      w_i <- numeric(n)
      for (i in seq_len(n)) {
        k_i <- which(X_unique == data$X[i])
        w_i[i] <- Q_m[k_i] / P0_categorical[k_i]
      }

      mean_S1_m <- mean_S1_vec[m]
      mean_S0_m <- mean_S0_vec[m]
      mean_Y1_m <- mean_Y1_vec[m]
      mean_Y0_m <- mean_Y0_vec[m]

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

  # Compose IF
  psi_Theta <- numeric(n)
  for (i in seq_len(n)) {
    psi_Theta[i] <- sum(grad_S * psi_S[i, ] + grad_Y * psi_Y[i, ])
  }

  # Variance
  sigma_sq <- mean(psi_Theta^2)
  se <- sqrt(sigma_sq / n)

  # CI
  z_crit <- stats::qnorm(1 - alpha / 2)
  ci_lower <- rho_hat - z_crit * se
  ci_upper <- rho_hat + z_crit * se

  if (verbose) {
    message(sprintf("\n=== Results ==="))
    message(sprintf("ρ̂ = %.4f (SE = %.4f)", rho_hat, se))
    message(sprintf("95%% CI: [%.4f, %.4f]", ci_lower, ci_upper))
    message(sprintf("Converged: %s (M = %d)", ifelse(converged, "YES", "NO"), M_final))
  }

  list(
    rho_hat = rho_hat,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    IF_vals = psi_Theta,
    Delta_S = Delta_S,
    Delta_Y = Delta_Y,
    M_final = M_final,
    M_history = M_history,
    rho_history = rho_history,
    converged = converged,
    tolerance = tolerance,
    n_stable = n_stable,
    method = method
  )
}
