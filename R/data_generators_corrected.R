#' Generate study data WITHOUT causal S→Y path (for surrogate validation)
#'
#' This is a CORRECTED version of generate_study_data that removes the hard-coded
#' S→Y relationship. This allows us to independently control treatment effects on
#' S and Y, testing whether S predicts Y across populations rather than whether
#' S mediates the effect on Y.
#'
#' Key difference from original:
#'   - S and Y are both affected by treatment, covariates, and latent class
#'   - S and Y are CORRELATED through shared dependence on class/covariates
#'   - But S does NOT directly cause Y (no S term in Y equation)
#'
#' This tests the right question for surrogate evaluation:
#'   "Does treatment effect on S predict treatment effect on Y?"
#'
#' Not the mediation question:
#'   "Does treatment affect Y through its effect on S?"
#'
#' @param n Integer. Sample size.
#' @param n_classes Integer. Number of latent classes.
#' @param class_probs Numeric vector. Class probabilities (must sum to 1).
#' @param treatment_effect_surrogate Numeric vector. Treatment effect on S for each class.
#' @param treatment_effect_outcome Numeric vector. Treatment effect on Y for each class.
#' @param surrogate_type Character. "binary" or "continuous".
#' @param outcome_type Character. "binary" or "continuous".
#' @param covariate_effects List with elements 'surrogate' and 'outcome'.
#' @param noise_sd Numeric. Standard deviation for continuous variables.
#' @param correlation_structure Character. How to create S-Y correlation:
#'   - "class_only": S and Y correlated only through shared class dependence
#'   - "residual": Add correlated noise terms for S and Y
#' @param residual_correlation Numeric in [-1,1]. If correlation_structure="residual",
#'   correlation between S and Y noise terms. Default: 0.5.
#' @param seed Integer. Random seed.
#'
#' @return A tibble with columns: class, A, X, S, Y
#'
#' @examples
#' # Good surrogate: treatment effects on S and Y co-vary across classes
#' good_surrogate <- generate_study_data_no_mediation(
#'   n = 500,
#'   n_classes = 2,
#'   treatment_effect_surrogate = c(0.3, 0.9),  # Low and high
#'   treatment_effect_outcome = c(0.2, 0.8),     # Also low and high
#'   surrogate_type = "continuous",
#'   outcome_type = "continuous"
#' )
#'
#' # Bad surrogate: treatment effects on S don't predict effects on Y
#' bad_surrogate <- generate_study_data_no_mediation(
#'   n = 500,
#'   n_classes = 2,
#'   treatment_effect_surrogate = c(0.3, 0.9),   # Low and high on S
#'   treatment_effect_outcome = c(-0.5, 0.1),    # OPPOSITE pattern on Y!
#'   surrogate_type = "continuous",
#'   outcome_type = "continuous"
#' )
#'
#' @export
generate_study_data_no_mediation <- function(n,
                                             n_classes = 2,
                                             class_probs = rep(1/n_classes, n_classes),
                                             treatment_effect_surrogate,
                                             treatment_effect_outcome,
                                             surrogate_type = c("binary", "continuous"),
                                             outcome_type = c("binary", "continuous"),
                                             covariate_effects = list(
                                               surrogate = rep(0.3, n_classes),
                                               outcome = rep(0.3, n_classes)
                                             ),
                                             noise_sd = 0.5,
                                             correlation_structure = c("class_only", "residual"),
                                             residual_correlation = 0.5,
                                             seed = NULL) {

  if (!is.null(seed)) set.seed(seed)

  surrogate_type <- match.arg(surrogate_type)
  outcome_type <- match.arg(outcome_type)
  correlation_structure <- match.arg(correlation_structure)

  # Validate inputs
  if (length(treatment_effect_surrogate) != n_classes) {
    stop("treatment_effect_surrogate must have length n_classes")
  }
  if (length(treatment_effect_outcome) != n_classes) {
    stop("treatment_effect_outcome must have length n_classes")
  }
  if (abs(sum(class_probs) - 1) > 1e-10) {
    stop("class_probs must sum to 1")
  }

  # Generate latent class
  class <- sample(1:n_classes, size = n, replace = TRUE, prob = class_probs)

  # Generate treatment (randomized)
  A <- rbinom(n, 1, 0.5)

  # Generate covariate
  X <- rnorm(n)

  # Generate correlated noise if requested
  if (correlation_structure == "residual" && surrogate_type == "continuous" && outcome_type == "continuous") {
    # Generate bivariate normal noise with specified correlation
    noise_matrix <- MASS::mvrnorm(n, mu = c(0, 0),
                                  Sigma = matrix(c(noise_sd^2,
                                                  residual_correlation * noise_sd^2,
                                                  residual_correlation * noise_sd^2,
                                                  noise_sd^2), 2, 2))
    noise_S <- noise_matrix[, 1]
    noise_Y <- noise_matrix[, 2]
  } else {
    noise_S <- rnorm(n, sd = noise_sd)
    noise_Y <- rnorm(n, sd = noise_sd)
  }

  # Initialize
  S <- numeric(n)
  Y <- numeric(n)

  # Generate S and Y for each class
  for (v in 1:n_classes) {
    class_idx <- which(class == v)
    n_v <- length(class_idx)

    if (n_v == 0) next

    # SURROGATE - depends on: treatment, class, covariate, noise
    if (surrogate_type == "binary") {
      logit_s <- treatment_effect_surrogate[v] * A[class_idx] +
                 covariate_effects$surrogate[v] * X[class_idx]
      prob_s <- plogis(logit_s)
      S[class_idx] <- rbinom(n_v, 1, prob_s)
    } else {
      S[class_idx] <- treatment_effect_surrogate[v] * A[class_idx] +
                      covariate_effects$surrogate[v] * X[class_idx] +
                      noise_S[class_idx]
    }

    # OUTCOME - depends on: treatment, class, covariate, noise
    # ***NO S TERM*** - this is the key difference!
    if (outcome_type == "binary") {
      logit_y <- treatment_effect_outcome[v] * A[class_idx] +
                 covariate_effects$outcome[v] * X[class_idx]
      prob_y <- plogis(logit_y)
      Y[class_idx] <- rbinom(n_v, 1, prob_y)
    } else {
      Y[class_idx] <- treatment_effect_outcome[v] * A[class_idx] +
                      covariate_effects$outcome[v] * X[class_idx] +
                      noise_Y[class_idx]
    }
  }

  tibble::tibble(
    class = class,
    A = A,
    X = X,
    S = S,
    Y = Y
  )
}


#' Generate study data WITH controlled mediation (alternative approach)
#'
#' This version allows S to cause Y, but requires specifying TOTAL treatment
#' effects on Y, which are then decomposed into direct and indirect (through S).
#'
#' Use this when you want to model S as a causal mediator but still control
#' the total treatment effect on Y.
#'
#' @param n Integer. Sample size.
#' @param n_classes Integer. Number of latent classes.
#' @param class_probs Numeric vector. Class probabilities.
#' @param treatment_effect_surrogate Numeric vector. Treatment effect on S.
#' @param treatment_effect_outcome_TOTAL Numeric vector. TOTAL treatment effect on Y
#'   (including both direct effect and indirect effect through S).
#' @param surrogate_outcome_coefficient Numeric. Causal effect of S on Y (β in Y = ... + βS).
#'   Default: 0.5.
#' @param surrogate_type Character. "binary" or "continuous".
#' @param outcome_type Character. "binary" or "continuous".
#' @param covariate_effects List. Covariate effects on S and Y.
#' @param noise_sd Numeric. Noise standard deviation.
#' @param seed Integer. Random seed.
#'
#' @return A tibble with columns: class, A, X, S, Y, and additional columns:
#'   \item{te_y_direct}{Direct treatment effect on Y (for each class)}
#'   \item{te_y_indirect}{Indirect effect through S (for each class)}
#'   \item{te_y_total}{Total effect (for verification)}
#'
#' @examples
#' # Opposite effects: treatment increases S but decreases Y
#' opposite_effects <- generate_study_data_with_mediation(
#'   n = 500,
#'   treatment_effect_surrogate = c(0.5, 0.5),
#'   treatment_effect_outcome_TOTAL = c(-0.3, -0.3),  # Negative total effect
#'   surrogate_outcome_coefficient = 0.7
#' )
#'
#' @export
generate_study_data_with_mediation <- function(n,
                                               n_classes = 2,
                                               class_probs = rep(1/n_classes, n_classes),
                                               treatment_effect_surrogate,
                                               treatment_effect_outcome_TOTAL,
                                               surrogate_outcome_coefficient = 0.5,
                                               surrogate_type = c("binary", "continuous"),
                                               outcome_type = c("binary", "continuous"),
                                               covariate_effects = list(
                                                 surrogate = rep(0.3, n_classes),
                                                 outcome = rep(0.1, n_classes)
                                               ),
                                               noise_sd = 0.5,
                                               seed = NULL) {

  if (!is.null(seed)) set.seed(seed)

  surrogate_type <- match.arg(surrogate_type)
  outcome_type <- match.arg(outcome_type)

  # Validate
  if (length(treatment_effect_surrogate) != n_classes) {
    stop("treatment_effect_surrogate must have length n_classes")
  }
  if (length(treatment_effect_outcome_TOTAL) != n_classes) {
    stop("treatment_effect_outcome_TOTAL must have length n_classes")
  }

  # Back-calculate direct effects
  # Total effect = Direct effect + β * (effect on S)
  # So: Direct effect = Total effect - β * (effect on S)
  te_y_direct <- treatment_effect_outcome_TOTAL -
                 surrogate_outcome_coefficient * treatment_effect_surrogate

  # Store for verification
  te_y_indirect <- surrogate_outcome_coefficient * treatment_effect_surrogate

  # Generate data
  class <- sample(1:n_classes, size = n, replace = TRUE, prob = class_probs)
  A <- rbinom(n, 1, 0.5)
  X <- rnorm(n)

  S <- numeric(n)
  Y <- numeric(n)

  for (v in 1:n_classes) {
    class_idx <- which(class == v)
    n_v <- length(class_idx)
    if (n_v == 0) next

    # Generate S
    if (surrogate_type == "binary") {
      logit_s <- treatment_effect_surrogate[v] * A[class_idx] +
                 covariate_effects$surrogate[v] * X[class_idx]
      S[class_idx] <- rbinom(n_v, 1, plogis(logit_s))
    } else {
      S[class_idx] <- treatment_effect_surrogate[v] * A[class_idx] +
                      covariate_effects$surrogate[v] * X[class_idx] +
                      rnorm(n_v, sd = noise_sd)
    }

    # Generate Y with S→Y path
    if (outcome_type == "binary") {
      logit_y <- te_y_direct[v] * A[class_idx] +
                 covariate_effects$outcome[v] * X[class_idx] +
                 surrogate_outcome_coefficient * S[class_idx]
      Y[class_idx] <- rbinom(n_v, 1, plogis(logit_y))
    } else {
      Y[class_idx] <- te_y_direct[v] * A[class_idx] +
                      covariate_effects$outcome[v] * X[class_idx] +
                      surrogate_outcome_coefficient * S[class_idx] +
                      rnorm(n_v, sd = noise_sd)
    }
  }

  # Add decomposition info
  result <- tibble::tibble(
    class = class,
    A = A,
    X = X,
    S = S,
    Y = Y
  )

  # Add attributes with effect decomposition
  attr(result, "te_y_direct") <- te_y_direct
  attr(result, "te_y_indirect") <- te_y_indirect
  attr(result, "te_y_total") <- treatment_effect_outcome_TOTAL

  result
}
