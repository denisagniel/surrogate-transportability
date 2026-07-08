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
#' @param method "bootstrap", "importance_weighting", or "aipw"
#' @param verbose Print progress?
#' @param e_hat Estimated propensity scores (for AIPW external mode, length n). If NULL, cross-fitting is used.
#' @param mu_1_S Estimated E[S|A=1,X] (for AIPW external mode, length n)
#' @param mu_0_S Estimated E[S|A=0,X] (for AIPW external mode, length n)
#' @param mu_1_Y Estimated E[Y|A=1,X] (for AIPW external mode, length n)
#' @param mu_0_Y Estimated E[Y|A=0,X] (for AIPW external mode, length n)
#' @param method_e Method for propensity score estimation in cross-fitting mode (if e_hat is NULL)
#' @param method_mu Method for outcome regression in cross-fitting mode (if e_hat is NULL)
#' @param n_folds Number of cross-fitting folds (default: 5)
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
#'    - Each consecutive change |rho_t - rho_(t-1)| < tolerance
#'    - Overall change |rho_t - rho_(t-n_stable)| < tolerance
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
                                           method = c("bootstrap", "importance_weighting", "aipw"),
                                           verbose = TRUE,
                                           e_hat = NULL,
                                           mu_1_S = NULL,
                                           mu_0_S = NULL,
                                           mu_1_Y = NULL,
                                           mu_0_Y = NULL,
                                           method_e = c("linear", "gam", "rf"),
                                           method_mu = c("linear", "gam", "rf"),
                                           n_folds = 5) {

  method <- match.arg(method)

  # AIPW validation: two modes supported
  if (method == "aipw") {
    n <- nrow(data)

    # MODE 1: External nuisances provided
    if (!is.null(e_hat)) {
      # All 5 nuisances must be provided
      if (is.null(mu_1_S) || is.null(mu_0_S) || is.null(mu_1_Y) || is.null(mu_0_Y)) {
        stop("AIPW external mode: If e_hat provided, all nuisances required (mu_1_S, mu_0_S, mu_1_Y, mu_0_Y)")
      }

      # Check lengths
      if (length(e_hat) != n || length(mu_1_S) != n || length(mu_0_S) != n ||
          length(mu_1_Y) != n || length(mu_0_Y) != n) {
        stop("All nuisance functions must have length n")
      }

      # Check propensity scores in (0,1)
      if (any(e_hat <= 0 | e_hat >= 1)) {
        stop("Propensity scores must be in (0, 1)")
      }
    } else {
      # MODE 2: Cross-fitting mode - method_e and method_mu required
      method_e <- match.arg(method_e)
      method_mu <- match.arg(method_mu)

      if (n_folds < 2) {
        stop("n_folds must be >= 2 for cross-fitting")
      }

      # Warn if other nuisances provided but will be ignored
      if (!is.null(mu_1_S) || !is.null(mu_0_S) || !is.null(mu_1_Y) || !is.null(mu_0_Y)) {
        warning("AIPW cross-fitting mode: provided mu_* will be ignored, fitting internally")
      }
    }
  }

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
    method_name <- switch(method,
                         "bootstrap" = "Bootstrap",
                         "importance_weighting" = "Importance Weighting",
                         "aipw" = "AIPW (Doubly Robust)")
    message(sprintf("Method: %s", method_name))
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

  # AIPW pre-loop setup
  if (method == "aipw") {
    # MODE 1: External nuisances provided
    if (!is.null(e_hat)) {
      if (verbose) message("AIPW: Using provided nuisance estimates\n")
      use_external_nuisances <- TRUE
    } else {
      # MODE 2: Cross-fitting mode
      if (verbose) message(sprintf("AIPW: Cross-fitting nuisances (method_e=%s, method_mu=%s, k=%d folds)\n",
                                  method_e, method_mu, n_folds))

      # Create folds (same for all Q_m)
      folds <- sample(rep(1:n_folds, length.out = n))

      # Pre-allocate storage for M_max nuisance estimates (one set per Q_m)
      e_hat_all <- matrix(0, nrow = n, ncol = M_max)
      mu_1_S_all <- matrix(0, nrow = n, ncol = M_max)
      mu_0_S_all <- matrix(0, nrow = n, ncol = M_max)
      mu_1_Y_all <- matrix(0, nrow = n, ncol = M_max)
      mu_0_Y_all <- matrix(0, nrow = n, ncol = M_max)

      use_external_nuisances <- FALSE
    }
  }

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

      } else if (method == "aipw") {
        # Get or fit nuisances for this Q_m
        if (use_external_nuisances) {
          # MODE 1: Use provided nuisances (same for all Q_m)
          e_hat_m <- e_hat
          mu_1_S_m <- mu_1_S
          mu_0_S_m <- mu_0_S
          mu_1_Y_m <- mu_1_Y
          mu_0_Y_m <- mu_0_Y
        } else {
          # MODE 2: Cross-fit nuisances specific to this Q_m
          # Compute observation weights from Q_m
          obs_weights <- numeric(n)
          for (i in seq_len(n)) {
            k_i <- which(X_unique == data$X[i])
            obs_weights[i] <- Q_m[k_i]
          }
          obs_weights <- obs_weights / sum(obs_weights)

          # Initialize nuisance vectors for this Q_m
          e_hat_m <- numeric(n)
          mu_1_S_m <- numeric(n)
          mu_0_S_m <- numeric(n)
          mu_1_Y_m <- numeric(n)
          mu_0_Y_m <- numeric(n)

          # Cross-fitting loop
          for (fold in 1:n_folds) {
            test_idx <- (folds == fold)
            train_idx <- !test_idx

            # Fit propensity score on train, predict on test
            if (method_e == "linear") {
              fit_e <- stats::glm(A ~ X, family = binomial(), data = data[train_idx, ],
                                 weights = obs_weights[train_idx])
              e_hat_m[test_idx] <- pmax(pmin(
                stats::predict(fit_e, newdata = data[test_idx, ], type = "response"),
                0.99), 0.01)
            } else if (method_e == "gam") {
              fit_e <- mgcv::gam(A ~ s(X), family = binomial(), data = data[train_idx, ],
                                weights = obs_weights[train_idx])
              e_hat_m[test_idx] <- pmax(pmin(
                stats::predict(fit_e, newdata = data[test_idx, ], type = "response"),
                0.99), 0.01)
            } else if (method_e == "rf") {
              fit_e <- ranger::ranger(A ~ X, data = data[train_idx, ],
                                     case.weights = obs_weights[train_idx],
                                     probability = TRUE)
              e_hat_m[test_idx] <- pmax(pmin(
                stats::predict(fit_e, data = data[test_idx, ])$predictions[, 2],
                0.99), 0.01)
            }

            # Fit outcome regressions on train, predict on test
            train_data_1 <- data[train_idx & data$A == 1, ]
            train_data_0 <- data[train_idx & data$A == 0, ]
            train_weights_1 <- obs_weights[train_idx & data$A == 1]
            train_weights_0 <- obs_weights[train_idx & data$A == 0]

            if (method_mu == "linear") {
              fit_S1 <- stats::lm(S ~ X, data = train_data_1, weights = train_weights_1)
              fit_S0 <- stats::lm(S ~ X, data = train_data_0, weights = train_weights_0)
              fit_Y1 <- stats::lm(Y ~ X, data = train_data_1, weights = train_weights_1)
              fit_Y0 <- stats::lm(Y ~ X, data = train_data_0, weights = train_weights_0)

              mu_1_S_m[test_idx] <- stats::predict(fit_S1, newdata = data[test_idx, ])
              mu_0_S_m[test_idx] <- stats::predict(fit_S0, newdata = data[test_idx, ])
              mu_1_Y_m[test_idx] <- stats::predict(fit_Y1, newdata = data[test_idx, ])
              mu_0_Y_m[test_idx] <- stats::predict(fit_Y0, newdata = data[test_idx, ])
            } else if (method_mu == "gam") {
              fit_S1 <- mgcv::gam(S ~ s(X), data = train_data_1, weights = train_weights_1)
              fit_S0 <- mgcv::gam(S ~ s(X), data = train_data_0, weights = train_weights_0)
              fit_Y1 <- mgcv::gam(Y ~ s(X), data = train_data_1, weights = train_weights_1)
              fit_Y0 <- mgcv::gam(Y ~ s(X), data = train_data_0, weights = train_weights_0)

              mu_1_S_m[test_idx] <- stats::predict(fit_S1, newdata = data[test_idx, ])
              mu_0_S_m[test_idx] <- stats::predict(fit_S0, newdata = data[test_idx, ])
              mu_1_Y_m[test_idx] <- stats::predict(fit_Y1, newdata = data[test_idx, ])
              mu_0_Y_m[test_idx] <- stats::predict(fit_Y0, newdata = data[test_idx, ])
            } else if (method_mu == "rf") {
              fit_S1 <- ranger::ranger(S ~ X, data = train_data_1, case.weights = train_weights_1)
              fit_S0 <- ranger::ranger(S ~ X, data = train_data_0, case.weights = train_weights_0)
              fit_Y1 <- ranger::ranger(Y ~ X, data = train_data_1, case.weights = train_weights_1)
              fit_Y0 <- ranger::ranger(Y ~ X, data = train_data_0, case.weights = train_weights_0)

              mu_1_S_m[test_idx] <- stats::predict(fit_S1, data = data[test_idx, ])$predictions
              mu_0_S_m[test_idx] <- stats::predict(fit_S0, data = data[test_idx, ])$predictions
              mu_1_Y_m[test_idx] <- stats::predict(fit_Y1, data = data[test_idx, ])$predictions
              mu_0_Y_m[test_idx] <- stats::predict(fit_Y0, data = data[test_idx, ])$predictions
            }
          }

          # Store for later use in IF computation
          m_abs <- M_current + m  # Absolute index in pre-allocated matrix
          e_hat_all[, m_abs] <- e_hat_m
          mu_1_S_all[, m_abs] <- mu_1_S_m
          mu_0_S_all[, m_abs] <- mu_0_S_m
          mu_1_Y_all[, m_abs] <- mu_1_Y_m
          mu_0_Y_all[, m_abs] <- mu_0_Y_m
        }

        # Compute importance weights
        w_i <- numeric(n)
        for (i in seq_len(n)) {
          k_i <- which(X_unique == data$X[i])
          w_i[i] <- Q_m[k_i] / P0_categorical[k_i]
        }

        # AIPW estimator: IPW + outcome regression correction
        aipw_S <- w_i * (
          data$A * (data$S - mu_1_S_m) / e_hat_m -
          (1 - data$A) * (data$S - mu_0_S_m) / (1 - e_hat_m) +
          mu_1_S_m - mu_0_S_m
        )

        aipw_Y <- w_i * (
          data$A * (data$Y - mu_1_Y_m) / e_hat_m -
          (1 - data$A) * (data$Y - mu_0_Y_m) / (1 - e_hat_m) +
          mu_1_Y_m - mu_0_Y_m
        )

        Delta_S_batch[m] <- mean(aipw_S)
        Delta_Y_batch[m] <- mean(aipw_Y)
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

      # Influence function of the Hajek weighted difference-in-means (★★ in
      # derivation_influence_functions.md). Normalize weights to mean 1 so that
      # Delta_hat - Delta ≈ (1/n) Σ_i psi[i]; per-arm denominators are the
      # average (mean-1) weights in each arm. (The old code hard-coded a factor
      # of 2, i.e. 1/ebar_a assuming e≡0.5 — correct only for a balanced RCT.)
      w_norm <- obs_weights / mean(obs_weights)
      ebar1 <- mean(w_norm * data$A)
      ebar0 <- mean(w_norm * (1 - data$A))
      if (ebar1 < 1e-8 || ebar0 < 1e-8) {
        stop(sprintf("Q_m %d: an arm has near-zero total weight (ebar1=%.2e, ebar0=%.2e)",
                     m, ebar1, ebar0))
      }
      psi_S[, m] <- w_norm * (
        data$A * (data$S - mean_S1_m) / ebar1 -
        (1 - data$A) * (data$S - mean_S0_m) / ebar0
      )
      psi_Y[, m] <- w_norm * (
        data$A * (data$Y - mean_Y1_m) / ebar1 -
        (1 - data$A) * (data$Y - mean_Y0_m) / ebar0
      )

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

      # Hajek difference-in-means IF (★★). See bootstrap branch above.
      w_norm <- w_i / mean(w_i)
      ebar1 <- mean(w_norm * data$A)
      ebar0 <- mean(w_norm * (1 - data$A))
      if (ebar1 < 1e-8 || ebar0 < 1e-8) {
        stop(sprintf("Q_m %d: an arm has near-zero total weight (ebar1=%.2e, ebar0=%.2e)",
                     m, ebar1, ebar0))
      }
      psi_S[, m] <- w_norm * (
        data$A * (data$S - mean_S1_m) / ebar1 -
        (1 - data$A) * (data$S - mean_S0_m) / ebar0
      )
      psi_Y[, m] <- w_norm * (
        data$A * (data$Y - mean_Y1_m) / ebar1 -
        (1 - data$A) * (data$Y - mean_Y0_m) / ebar0
      )

    } else if (method == "aipw") {
      # Get nuisances for this Q_m
      if (use_external_nuisances) {
        # MODE 1: Use provided nuisances (same for all Q_m)
        e_hat_m <- e_hat
        mu_1_S_m <- mu_1_S
        mu_0_S_m <- mu_0_S
        mu_1_Y_m <- mu_1_Y
        mu_0_Y_m <- mu_0_Y
      } else {
        # MODE 2: Retrieve Q_m-specific fitted nuisances
        e_hat_m <- e_hat_all[, m]
        mu_1_S_m <- mu_1_S_all[, m]
        mu_0_S_m <- mu_0_S_all[, m]
        mu_1_Y_m <- mu_1_Y_all[, m]
        mu_0_Y_m <- mu_0_Y_all[, m]
      }

      # Compute importance weights for this Q_m
      w_i <- numeric(n)
      for (i in seq_len(n)) {
        k_i <- which(X_unique == data$X[i])
        w_i[i] <- Q_m[k_i] / P0_categorical[k_i]
      }

      # Clip propensity away from 0/1 before dividing (external-nuisance mode is
      # only validated in (0,1); cross-fit mode already clips upstream).
      e_hat_m <- pmin(pmax(e_hat_m, 0.01), 0.99)

      # Retrieve treatment effects for centering
      Delta_S_m <- Delta_S[m]
      Delta_Y_m <- Delta_Y[m]

      # Per-study AIPW influence function (★ in derivation_influence_functions.md):
      # the whole reweighted AIPW score minus the CONSTANT Delta_m. The old code
      # subtracted w_i * Delta_m, which is the wrong centering for the fixed-Q
      # estimand and gives an incorrect variance.
      psi_S[, m] <- w_i * (
        data$A * (data$S - mu_1_S_m) / e_hat_m -
        (1 - data$A) * (data$S - mu_0_S_m) / (1 - e_hat_m) +
        mu_1_S_m - mu_0_S_m
      ) - Delta_S_m

      psi_Y[, m] <- w_i * (
        data$A * (data$Y - mu_1_Y_m) / e_hat_m -
        (1 - data$A) * (data$Y - mu_0_Y_m) / (1 - e_hat_m) +
        mu_1_Y_m - mu_0_Y_m
      ) - Delta_Y_m
    }
  }

  # Compose the two-stage IF (delta method across studies, §3 of
  # derivation_influence_functions.md): Psi(O_i) = Σ_m [ grad_S[m]·psi_S[i,m]
  # + grad_Y[m]·psi_Y[i,m] ]. grad_* already carry the 1/(M s_S s_Y) factor, so
  # this is a proper mean-zero per-observation IF. Vectorized as psi %*% grad.
  psi_Theta <- as.numeric(psi_S %*% grad_S + psi_Y %*% grad_Y)

  # Conditional variance given the M sampled studies (√n estimation term).
  # NOTE: this SE is CONDITIONAL on the sampled future studies μ̂_M; it targets
  # the M-study correlation Θ_M, not the population Θ. The MCMC approximation
  # error Θ_M − Θ = O_P(M^{-1/2}) is a separate source (§4 of the derivation);
  # with M large relative to n it is negligible. Reported as conditional SE.
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
    method = method,
    se_type = "conditional"  # SE is conditional on μ̂_M (see §4 of derivation)
  )
}
