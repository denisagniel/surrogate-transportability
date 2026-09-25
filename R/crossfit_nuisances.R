#' Cross-Fit AIPW Nuisances Once Per Sample
#'
#' Cross-fits the five nuisance functions the AIPW path of
#' [tv_ball_correlation_IF_adaptive()] needs — the propensity score `e(X)` and the
#' four arm-specific outcome regressions — on the observed, **unweighted** sample,
#' returning out-of-fold predictions ready to pass to that function's external
#' nuisance mode.
#'
#' @details
#' **Why fit once.** Under X-transportability the nuisances are properties of the
#' observed distribution `P0` and do not depend on which future study `Q` is being
#' evaluated; only the importance weights `q_k / p_{0,k}` do. Fitting them once and
#' reusing them across all `M` sampled studies is therefore not an approximation,
#' and it removes the factor-of-`M` cost of the estimator's internal cross-fitting
#' mode (which refits per `Q`-draw and is impractical beyond a few hundred draws).
#'
#' **Out-of-fold discipline.** Each observation's five predictions come from models
#' fit on the other `n_folds - 1` folds, so the nuisance estimates are independent
#' of the observation they are applied to — the condition the AIPW influence
#' function's rate requirements rely on. The outcome regressions are fit
#' arm-separately within each training fold.
#'
#' **Propensity clipping.** Returned `e_hat` is clipped to `[0.01, 0.99]`, matching
#' the clipping [tv_ball_correlation_IF_adaptive()] applies internally, so passing
#' this object into that function cannot trip its `(0, 1)` validation. A warning
#' fires if clipping actually binds, because that means a covariate region is
#' nearly deterministic in treatment and the AIPW estimate there rests on
#' extrapolation rather than data.
#'
#' Run time is roughly `n_folds` model fits of each of five models; for the
#' canonical five-level `X` with `n = 10000` and `method_* = "linear"` this is well
#' under a second, while `"rf"` is one to two orders of magnitude slower.
#'
#' @param data Data frame with columns `X`, `A`, `S`, `Y`.
#' @param method_e Learner for the propensity score: `"linear"` (logistic
#'   regression), `"gam"`, or `"rf"`.
#' @param method_mu Learner for the outcome regressions: `"linear"`, `"gam"`, or
#'   `"rf"`.
#' @param n_folds Number of cross-fitting folds (default `5`, minimum `2`).
#' @param seed Optional integer. If supplied, `set.seed()` is called before the
#'   fold split so the split is reproducible. Leave `NULL` inside a simulation
#'   replication that has already seeded itself, so the fold split inherits that
#'   replication's stream rather than being pinned across replications.
#'
#' @return A named list of five numeric vectors, each of length `nrow(data)`:
#'   `e_hat`, `mu_1_S`, `mu_0_S`, `mu_1_Y`, `mu_0_Y`.
#'
#' @seealso [tv_ball_correlation_IF_adaptive()], whose `e_hat`/`mu_*` arguments
#'   accept this list directly.
#'
#' @examples
#' spec <- confounded_dgp_params("conf1")
#' d <- generate_dgp_data(500, spec$params, spec$p_X, spec$X_levels,
#'                        e_int = spec$e_int, e_coef = spec$e_coef)
#' nu <- crossfit_nuisances_once(d, seed = 1)
#' range(nu$e_hat)
#'
#' @export
crossfit_nuisances_once <- function(data,
                                    method_e = c("linear", "gam", "rf"),
                                    method_mu = c("linear", "gam", "rf"),
                                    n_folds = 5L,
                                    seed = NULL) {
  method_e  <- match.arg(method_e)
  method_mu <- match.arg(method_mu)

  required <- c("X", "A", "S", "Y")
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    stop("`data` is missing required columns: ", paste(missing, collapse = ", "), ".")
  }
  if (!all(data$A %in% c(0, 1))) {
    stop("Treatment `A` must be binary (0/1).")
  }
  n_folds <- as.integer(n_folds)
  if (is.na(n_folds) || n_folds < 2L) {
    stop("`n_folds` must be an integer >= 2.")
  }
  n <- nrow(data)
  if (n < 2L * n_folds) {
    stop("`data` has ", n, " rows, too few for ", n_folds,
         "-fold cross-fitting; reduce `n_folds` or supply more data.")
  }

  if (!is.null(seed)) set.seed(seed)
  folds <- sample(rep(seq_len(n_folds), length.out = n))

  # A GAM basis dimension must stay below the number of distinct X values; the
  # canonical DGP has only five, so cap k rather than letting mgcv error out.
  n_x   <- length(unique(data$X))
  gam_k <- max(3L, min(10L, n_x - 1L))
  if (method_e == "gam" || method_mu == "gam") {
    if (n_x < 4L) {
      stop("`method_*` = \"gam\" needs at least 4 distinct `X` values; found ", n_x,
           ". Use \"linear\" for coarse discrete covariates.")
    }
  }

  e_hat  <- numeric(n)
  mu_1_S <- numeric(n); mu_0_S <- numeric(n)
  mu_1_Y <- numeric(n); mu_0_Y <- numeric(n)

  for (fold in seq_len(n_folds)) {
    test  <- folds == fold
    train <- !test
    d_tr <- data[train, , drop = FALSE]
    d_te <- data[test, , drop = FALSE]
    d_tr1 <- d_tr[d_tr$A == 1, , drop = FALSE]
    d_tr0 <- d_tr[d_tr$A == 0, , drop = FALSE]

    if (nrow(d_tr1) == 0L || nrow(d_tr0) == 0L) {
      stop("Fold ", fold, " has an empty treatment arm in its training set ",
           "(treated: ", nrow(d_tr1), ", control: ", nrow(d_tr0), "); the outcome ",
           "regressions are not identified. Increase `n` or reduce `n_folds`.")
    }

    e_hat[test] <- .fit_predict_propensity(d_tr, d_te, method_e, gam_k)
    mu_1_S[test] <- .fit_predict_outcome(d_tr1, d_te, "S", method_mu, gam_k)
    mu_0_S[test] <- .fit_predict_outcome(d_tr0, d_te, "S", method_mu, gam_k)
    mu_1_Y[test] <- .fit_predict_outcome(d_tr1, d_te, "Y", method_mu, gam_k)
    mu_0_Y[test] <- .fit_predict_outcome(d_tr0, d_te, "Y", method_mu, gam_k)
  }

  n_clipped <- sum(e_hat < 0.01 | e_hat > 0.99)
  if (n_clipped > 0L) {
    warning(n_clipped, " of ", n, " estimated propensities were clipped to ",
            "[0.01, 0.99]; treatment is near-deterministic in part of the ",
            "covariate space and the AIPW estimate there rests on extrapolation.")
  }
  e_hat <- pmin(pmax(e_hat, 0.01), 0.99)

  list(e_hat = e_hat, mu_1_S = mu_1_S, mu_0_S = mu_0_S,
       mu_1_Y = mu_1_Y, mu_0_Y = mu_0_Y)
}


# Fit P(A = 1 | X) on `train`, predict on `test`. One learner per branch; no
# fallback, so an unsupported method is a hard error rather than a silent default.
.fit_predict_propensity <- function(train, test, method_e, gam_k) {
  if (method_e == "linear") {
    fit <- stats::glm(A ~ X, family = stats::binomial(), data = train)
    as.numeric(stats::predict(fit, newdata = test, type = "response"))
  } else if (method_e == "gam") {
    fit <- mgcv::gam(A ~ s(X, k = gam_k), family = stats::binomial(), data = train)
    as.numeric(stats::predict(fit, newdata = test, type = "response"))
  } else {
    fit <- ranger::ranger(A ~ X, data = train, probability = TRUE)
    as.numeric(stats::predict(fit, data = test)$predictions[, 2])
  }
}


# Fit E[response | X] on a single-arm `train`, predict on `test`.
.fit_predict_outcome <- function(train, test, response, method_mu, gam_k) {
  if (method_mu == "linear") {
    fit <- stats::lm(stats::reformulate("X", response), data = train)
    as.numeric(stats::predict(fit, newdata = test))
  } else if (method_mu == "gam") {
    fit <- mgcv::gam(stats::reformulate(sprintf("s(X, k = %d)", gam_k), response),
                     data = train)
    as.numeric(stats::predict(fit, newdata = test))
  } else {
    fit <- ranger::ranger(stats::reformulate("X", response), data = train)
    as.numeric(stats::predict(fit, data = test)$predictions)
  }
}
