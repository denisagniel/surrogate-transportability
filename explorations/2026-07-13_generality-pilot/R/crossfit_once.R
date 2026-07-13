# =============================================================================
# crossfit_once.R -- fit AIPW nuisances ONCE per replication (X-transportability)
# =============================================================================
# Under X-transportability the nuisances e(X), mu_a^S(X), mu_a^Y(X) are properties
# of P0 and do NOT depend on Q (derivation §1-2). So cross-fit them once on the
# observed (UNWEIGHTED) sample and reuse across all Q_m via Mode 1 of
# tv_ball_correlation_IF_adaptive(). This collapses AIPW cost by the ~M factor.
#
# Returns the five out-of-fold n-vectors expected by Mode 1.
# Learners: "linear" (glm/lm), "gam" (mgcv with k set for discrete X), "rf" (ranger).
# =============================================================================

crossfit_once <- function(data, method_e = "linear", method_mu = "linear",
                          n_folds = 5, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  n <- nrow(data)
  folds <- sample(rep(1:n_folds, length.out = n))
  n_x <- length(unique(data$X))

  e_hat  <- numeric(n)
  mu_1_S <- numeric(n); mu_0_S <- numeric(n)
  mu_1_Y <- numeric(n); mu_0_Y <- numeric(n)

  # GAM basis dim must be < #unique X; for discrete X with few levels, cap k.
  gam_k <- max(3L, min(10L, n_x - 1L))

  for (fold in 1:n_folds) {
    te <- folds == fold
    tr <- !te
    d_tr <- data[tr, ]; d_te <- data[te, ]
    d_tr1 <- d_tr[d_tr$A == 1, ]; d_tr0 <- d_tr[d_tr$A == 0, ]

    # --- propensity e(X) = P(A=1|X) ---
    if (method_e == "linear") {
      f <- stats::glm(A ~ X, family = binomial(), data = d_tr)
      e_hat[te] <- stats::predict(f, d_te, type = "response")
    } else if (method_e == "gam") {
      f <- mgcv::gam(A ~ s(X, k = gam_k), family = binomial(), data = d_tr)
      e_hat[te] <- stats::predict(f, d_te, type = "response")
    } else if (method_e == "rf") {
      f <- ranger::ranger(A ~ X, data = d_tr, probability = TRUE)
      e_hat[te] <- stats::predict(f, d_te)$predictions[, 2]
    }

    # --- outcome regressions mu_a^S, mu_a^Y ---
    fit_pred <- function(train, resp) {
      if (method_mu == "linear") {
        f <- stats::lm(stats::reformulate("X", resp), data = train)
        stats::predict(f, d_te)
      } else if (method_mu == "gam") {
        f <- mgcv::gam(stats::reformulate(sprintf("s(X, k=%d)", gam_k), resp), data = train)
        stats::predict(f, d_te)
      } else if (method_mu == "rf") {
        f <- ranger::ranger(stats::reformulate("X", resp), data = train)
        stats::predict(f, d_te)$predictions
      }
    }
    mu_1_S[te] <- fit_pred(d_tr1, "S"); mu_0_S[te] <- fit_pred(d_tr0, "S")
    mu_1_Y[te] <- fit_pred(d_tr1, "Y"); mu_0_Y[te] <- fit_pred(d_tr0, "Y")
  }

  e_hat <- pmax(pmin(e_hat, 0.99), 0.01)
  list(e_hat = e_hat, mu_1_S = mu_1_S, mu_0_S = mu_0_S,
       mu_1_Y = mu_1_Y, mu_0_Y = mu_0_Y)
}
