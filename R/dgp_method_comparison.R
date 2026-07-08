#' Data Generating Processes for Method Comparison Study
#'
#' @description
#' Generate data under scenarios designed to show divergence between
#' across-study correlation and traditional surrogate evaluation methods.
#'
#' @name dgp_method_comparison
#' @keywords internal
NULL

#' Generate DGP: High Across-Study Correlation, Low Within-Study PTE
#'
#' @description
#' Scenario where treatment effects on S and Y both vary strongly with X
#' (effect modification), but S has no causal effect on Y. This creates
#' high across-study correlation (ΔS and ΔY co-vary with P(X)) but low
#' within-study proportion of treatment effect explained (PTE).
#'
#' @param n Sample size
#' @param p_x Probability of X=1
#' @param seed Random seed
#'
#' @return List with:
#'   - `data`: Tibble with columns X, A, S, Y
#'   - `truth`: List of true parameter values
#'
#' @details
#' **Causal structure:**
#' - X → S, X → Y (baseline effects)
#' - A → S, A → Y (treatment effects)
#' - A×X → S, A×X → Y (effect modification, separate pathways)
#' - NO S → Y (no mediation)
#'
#' **Expected properties:**
#' - High across-study cor(ΔS, ΔY): ~0.9 (both vary with P(X))
#' - Low within-study PTE: ~0.3 (no mediation through S)
#' - Transportable: Treatment effect predictable from covariate shift
#'
#' @export
#' @examples
#' dgp <- generate_high_cor_low_pte(n = 500)
#' cor(dgp$data$S, dgp$data$Y)  # Within-study correlation
generate_high_cor_low_pte <- function(n = 500, p_x = 0.5, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  X <- rbinom(n, 1, p_x)
  A <- rbinom(n, 1, 0.5)

  # S model: Strong A×X interaction
  logit_S <- -1.5 + 0.5*A + 0.3*X + 2.0*A*X
  S <- rbinom(n, 1, plogis(logit_S))

  # Y model: Strong A×X interaction, NO S effect
  logit_Y <- -1.5 + 0.3*A + 0.5*X + 0.1*S + 1.8*A*X
  Y <- rbinom(n, 1, plogis(logit_Y))

  list(
    data = tibble::tibble(X = X, A = A, S = S, Y = Y),
    truth = list(
      scenario = "high_cor_low_pte",
      s_effect_on_y = 0.1,  # Small S coefficient (no mediation)
      a_x_interaction_s = 2.0,  # Strong effect modification for S
      a_x_interaction_y = 1.8,  # Strong effect modification for Y
      expected_across_cor = 0.9,
      expected_pte = 0.3,
      is_transportable = TRUE,
      mechanism = "Separate pathways: A→S and A→Y both modified by X, but S↛Y"
    )
  )
}

#' Generate DGP: Moderate Across-Study Correlation, High Within-Study PTE
#'
#' @description
#' Scenario where treatment effect on S is constant (no effect modification)
#' but S has strong causal effect on Y that varies with X. This creates
#' moderate/low across-study correlation (ΔS constant) but high within-study
#' proportion of treatment effect explained (strong mediation).
#'
#' @param n Sample size
#' @param p_x Probability of X=1
#' @param seed Random seed
#'
#' @return List with:
#'   - `data`: Tibble with columns X, A, S, Y
#'   - `truth`: List of true parameter values
#'
#' @details
#' **Causal structure:**
#' - A → S (constant treatment effect, no interaction)
#' - S → Y (strong mediation)
#' - S×X → Y (effect modification of mediation)
#' - NO direct A → Y (all through S)
#'
#' **Expected properties:**
#' - Moderate across-study cor(ΔS, ΔY): ~0.5 (ΔS constant, ΔY varies)
#' - High within-study PTE: ~0.95 (strong mediation)
#' - NOT transportable: ΔY varies with P(X) but ΔS doesn't signal this
#'
#' @export
#' @examples
#' dgp <- generate_moderate_cor_high_pte(n = 500)
#' mean(dgp$data$S[dgp$data$A == 1]) - mean(dgp$data$S[dgp$data$A == 0])  # ΔS
generate_moderate_cor_high_pte <- function(n = 500, p_x = 0.5, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  X <- rbinom(n, 1, p_x)
  A <- rbinom(n, 1, 0.5)

  # S model: CONSTANT treatment effect (no A×X interaction)
  logit_S <- -1.0 + 1.5*A
  S <- rbinom(n, 1, plogis(logit_S))

  # Y model: NO direct A effect, STRONG S effect with S×X interaction
  logit_Y <- -2.0 + 0.8*X + 2.5*S + 1.2*S*X
  Y <- rbinom(n, 1, plogis(logit_Y))

  list(
    data = tibble::tibble(X = X, A = A, S = S, Y = Y),
    truth = list(
      scenario = "moderate_cor_high_pte",
      s_effect_on_y = 2.5,  # Strong S effect (mediation)
      s_x_interaction_y = 1.2,  # S effect varies with X
      a_x_interaction_s = 0,  # NO effect modification for S
      expected_across_cor = 0.5,
      expected_pte = 0.95,
      is_transportable = FALSE,
      mechanism = "Mediation pathway: A→S→Y, S effect varies with X, but ΔS doesn't signal this"
    )
  )
}

#' Generate Future Study Effects for Across-Study Correlation
#'
#' @description
#' Sample M hypothetical future studies with different covariate distributions
#' P(X) and compute treatment effects ΔS and ΔY in each. Used to compute
#' across-study correlation cor(ΔS, ΔY).
#'
#' @param data Original study data (tibble with X, A, S, Y)
#' @param M Number of future studies to simulate
#' @param p_x_range Range of P(X) values to sample (default: 0.1 to 0.9)
#' @param seed Random seed
#'
#' @return Tibble with columns:
#'   - `study_id`: Study identifier (1 to M)
#'   - `p_x`: Probability of X=1 in this study
#'   - `delta_s`: Treatment effect on S
#'   - `delta_y`: Treatment effect on Y
#'
#' @details
#' For each future study:
#' 1. Sample P(X) uniformly from `p_x_range`
#' 2. Resample from original data to match new P(X)
#' 3. Compute ΔS = E[S|A=1] - E[S|A=0]
#' 4. Compute ΔY = E[Y|A=1] - E[Y|A=0]
#'
#' @export
#' @examples
#' dgp <- generate_high_cor_low_pte(n = 500)
#' future_effects <- generate_future_study_effects(dgp$data, M = 100)
#' cor(future_effects$delta_s, future_effects$delta_y)
generate_future_study_effects <- function(data, M = 100,
                                           p_x_range = c(0.1, 0.9),
                                           seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Sample P(X) values for M future studies
  p_x_values <- runif(M, min = p_x_range[1], max = p_x_range[2])

  purrr::map_dfr(seq_len(M), function(study_id) {
    px <- p_x_values[study_id]

    # Resample to match new P(X)
    n_x1 <- round(nrow(data) * px)
    n_x0 <- nrow(data) - n_x1

    # Handle edge cases
    if (n_x1 == 0 || n_x0 == 0) {
      return(tibble::tibble(
        study_id = study_id,
        p_x = px,
        delta_s = NA_real_,
        delta_y = NA_real_
      ))
    }

    # Resample from original data
    data_x1 <- data[data$X == 1, ]
    data_x0 <- data[data$X == 0, ]

    if (nrow(data_x1) == 0 || nrow(data_x0) == 0) {
      return(tibble::tibble(
        study_id = study_id,
        p_x = px,
        delta_s = NA_real_,
        delta_y = NA_real_
      ))
    }

    future_data <- dplyr::bind_rows(
      dplyr::slice_sample(data_x1, n = n_x1, replace = TRUE),
      dplyr::slice_sample(data_x0, n = n_x0, replace = TRUE)
    )

    # Compute treatment effects
    delta_s <- mean(future_data$S[future_data$A == 1]) -
               mean(future_data$S[future_data$A == 0])
    delta_y <- mean(future_data$Y[future_data$A == 1]) -
               mean(future_data$Y[future_data$A == 0])

    tibble::tibble(
      study_id = study_id,
      p_x = px,
      delta_s = delta_s,
      delta_y = delta_y
    )
  })
}

#' Generate DGP: Low Across-Study Correlation, High Within-Study PTE
#'
#' @description
#' Scenario where S strongly mediates the effect within-study (high PTE),
#' but the S→Y relationship varies unpredictably across populations due to
#' unmeasured effect modifiers. This creates low across-study correlation
#' despite high within-study mediation.
#'
#' @param n Sample size
#' @param p_x Probability of X=1
#' @param seed Random seed
#'
#' @return List with:
#'   - `data`: Tibble with columns X, A, S, Y, U (unmeasured modifier)
#'   - `truth`: List of true parameter values
#'
#' @details
#' **Causal structure:**
#' - A → S (constant treatment effect)
#' - S → Y (strong mediation, but effect modified by unmeasured U)
#' - U → Y (unmeasured confounder that varies across populations)
#' - S×U → Y (interaction: S effect depends on U)
#'
#' **Key mechanism:**
#' Within the original study, U is fixed at U=0, so S→Y is strong and
#' positive (high PTE). But across future studies, U varies randomly,
#' causing the S→Y relationship to vary unpredictably. This breaks the
#' correlation between ΔS and ΔY across studies.
#'
#' **Expected properties:**
#' - Low across-study cor(ΔS, ΔY): ~0.1 (ΔY varies unpredictably)
#' - High within-study PTE: ~0.9 (strong mediation in observed study)
#' - NOT transportable: Cannot predict ΔY from ΔS across populations
#'
#' @export
#' @examples
#' dgp <- generate_low_cor_high_pte(n = 500)
#' # Original study has U=0, strong S→Y
#' # Future studies have varying U, unpredictable S→Y
generate_low_cor_high_pte <- function(n = 500, p_x = 0.5, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  X <- rbinom(n, 1, p_x)
  A <- rbinom(n, 1, 0.5)

  # Unmeasured modifier U (fixed at 0 in original study)
  U <- 0

  # S model: Constant treatment effect
  logit_S <- -0.5 + 1.2*A
  S <- rbinom(n, 1, plogis(logit_S))

  # Y model: Strong S effect, but depends on U
  # In original study (U=0): Strong positive S→Y
  # In future studies: U varies, making S→Y unpredictable
  logit_Y <- -1.5 + 0.05*A + 0.3*X + 2.0*S + 1.5*U*S
  Y <- rbinom(n, 1, plogis(logit_Y))

  list(
    data = tibble::tibble(X = X, A = A, S = S, Y = Y, U = U),
    truth = list(
      scenario = "low_cor_high_pte",
      s_effect_on_y = 2.0,  # Strong S effect
      s_u_interaction = 1.5,  # S effect modified by U
      u_range = c(-1, 1),  # U varies across studies
      expected_across_cor = 0.1,
      expected_pte = 0.9,
      is_transportable = FALSE,
      mechanism = "Strong mediation within-study, but S→Y varies with unmeasured U across populations"
    )
  )
}

#' Generate Future Study Effects with Unmeasured Heterogeneity
#'
#' @description
#' Sample M hypothetical future studies where unmeasured effect modifier U
#' varies, causing the S→Y relationship to vary unpredictably. This breaks
#' the correlation between ΔS and ΔY even when S strongly mediates within-study.
#'
#' @param data Original study data (tibble with X, A, S, Y, U)
#' @param M Number of future studies to simulate
#' @param p_x_range Range of P(X) values to sample
#' @param u_range Range of U values across studies (default: -1 to 1)
#' @param seed Random seed
#'
#' @return Tibble with columns:
#'   - `study_id`: Study identifier (1 to M)
#'   - `p_x`: Probability of X=1 in this study
#'   - `u_mean`: Mean of unmeasured modifier U in this study
#'   - `delta_s`: Treatment effect on S
#'   - `delta_y`: Treatment effect on Y
#'
#' @details
#' For each future study:
#' 1. Sample P(X) and mean(U) from specified ranges
#' 2. Regenerate Y using new U value (S→Y relationship changes)
#' 3. Compute ΔS and ΔY
#'
#' The varying U causes ΔY to fluctuate independently of ΔS, breaking
#' their correlation even though S mediates strongly within each study.
#'
#' @export
generate_future_effects_with_heterogeneity <- function(data, M = 100,
                                                        p_x_range = c(0.1, 0.9),
                                                        u_range = c(-1, 1),
                                                        seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Sample P(X) and U for M future studies
  p_x_values <- runif(M, min = p_x_range[1], max = p_x_range[2])
  u_values <- runif(M, min = u_range[1], max = u_range[2])

  purrr::map_dfr(seq_len(M), function(study_id) {
    px <- p_x_values[study_id]
    u_mean <- u_values[study_id]

    # Resample to match new P(X)
    n_x1 <- round(nrow(data) * px)
    n_x0 <- nrow(data) - n_x1

    if (n_x1 == 0 || n_x0 == 0) {
      return(tibble::tibble(
        study_id = study_id,
        p_x = px,
        u_mean = u_mean,
        delta_s = NA_real_,
        delta_y = NA_real_
      ))
    }

    # Resample from original data
    data_x1 <- data[data$X == 1, ]
    data_x0 <- data[data$X == 0, ]

    if (nrow(data_x1) == 0 || nrow(data_x0) == 0) {
      return(tibble::tibble(
        study_id = study_id,
        p_x = px,
        u_mean = u_mean,
        delta_s = NA_real_,
        delta_y = NA_real_
      ))
    }

    future_data <- dplyr::bind_rows(
      dplyr::slice_sample(data_x1, n = n_x1, replace = TRUE),
      dplyr::slice_sample(data_x0, n = n_x0, replace = TRUE)
    )

    # Regenerate Y with new U value
    # This changes the S→Y relationship for this study
    logit_Y_new <- -1.5 + 0.05*future_data$A + 0.3*future_data$X +
                   2.0*future_data$S + 1.5*u_mean*future_data$S

    future_data$Y <- rbinom(nrow(future_data), 1, plogis(logit_Y_new))

    # Compute treatment effects
    delta_s <- mean(future_data$S[future_data$A == 1]) -
               mean(future_data$S[future_data$A == 0])
    delta_y <- mean(future_data$Y[future_data$A == 1]) -
               mean(future_data$Y[future_data$A == 0])

    tibble::tibble(
      study_id = study_id,
      p_x = px,
      u_mean = u_mean,
      delta_s = delta_s,
      delta_y = delta_y
    )
  })
}
