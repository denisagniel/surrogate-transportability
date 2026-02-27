#' Generate study data with mixture structure
#'
#' Creates simulated study data with latent mixture structure for surrogate
#' marker evaluation. Supports both binary and continuous outcomes/surrogates.
#'
#' @param n Integer. Sample size for the study.
#' @param n_classes Integer. Number of latent classes in mixture (default: 2).
#' @param class_probs Numeric vector. Probabilities for each latent class.
#'   Must sum to 1. Default: c(0.5, 0.5).
#' @param treatment_effect_surrogate Numeric vector. Treatment effect on
#'   surrogate for each latent class.
#' @param treatment_effect_outcome Numeric vector. Treatment effect on
#'   outcome for each latent class.
#' @param surrogate_type Character. Type of surrogate: "binary" or "continuous".
#' @param outcome_type Character. Type of outcome: "binary" or "continuous".
#' @param covariate_effects List. Effects of covariates on surrogate and outcome.
#'   Should contain elements 'surrogate' and 'outcome', each numeric vectors
#'   of length n_classes.
#' @param noise_sd Numeric. Standard deviation of noise for continuous variables.
#' @param seed Integer. Random seed for reproducibility.
#'
#' @return A tibble with columns:
#'   \item{class}{Latent class assignment (1 to n_classes)}
#'   \item{A}{Binary treatment assignment}
#'   \item{X}{Covariate (standard normal)}
#'   \item{S}{Surrogate marker}
#'   \item{Y}{Outcome}
#'
#' @examples
#' # Binary surrogate and outcome
#' data_binary <- generate_study_data(
#'   n = 500,
#'   treatment_effect_surrogate = c(0.3, 0.7),
#'   treatment_effect_outcome = c(0.2, 0.8),
#'   surrogate_type = "binary",
#'   outcome_type = "binary"
#' )
#'
#' # Continuous surrogate and outcome
#' data_continuous <- generate_study_data(
#'   n = 500,
#'   treatment_effect_surrogate = c(0.5, 1.2),
#'   treatment_effect_outcome = c(0.3, 0.9),
#'   surrogate_type = "continuous",
#'   outcome_type = "continuous"
#' )
#'
#' @export
generate_study_data <- function(n,
                               n_classes = 2,
                               class_probs = rep(1/n_classes, n_classes),
                               treatment_effect_surrogate,
                               treatment_effect_outcome,
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
  
  # Validate inputs
  if (length(treatment_effect_surrogate) != n_classes) {
    stop("treatment_effect_surrogate must have length equal to n_classes")
  }
  if (length(treatment_effect_outcome) != n_classes) {
    stop("treatment_effect_outcome must have length equal to n_classes")
  }
  if (abs(sum(class_probs) - 1) > 1e-10) {
    stop("class_probs must sum to 1")
  }
  
  # Generate latent class assignments
  class <- sample(1:n_classes, size = n, replace = TRUE, prob = class_probs)
  
  # Generate treatment assignment (randomized)
  A <- rbinom(n, 1, 0.5)
  
  # Generate covariate
  X <- rnorm(n)
  
  # Initialize surrogate and outcome
  S <- numeric(n)
  Y <- numeric(n)
  
  # Generate surrogate and outcome for each class
  for (v in 1:n_classes) {
    class_idx <- which(class == v)
    n_v <- length(class_idx)
    
    if (n_v == 0) next
    
    # Surrogate generation
    if (surrogate_type == "binary") {
      # Logistic model for binary surrogate
      logit_s <- treatment_effect_surrogate[v] * A[class_idx] + 
                 covariate_effects$surrogate[v] * X[class_idx]
      prob_s <- plogis(logit_s)
      S[class_idx] <- rbinom(n_v, 1, prob_s)
    } else {
      # Linear model for continuous surrogate
      S[class_idx] <- treatment_effect_surrogate[v] * A[class_idx] + 
                      covariate_effects$surrogate[v] * X[class_idx] + 
                      rnorm(n_v, sd = noise_sd)
    }
    
    # Outcome generation
    if (outcome_type == "binary") {
      # Logistic model for binary outcome
      logit_y <- treatment_effect_outcome[v] * A[class_idx] + 
                 covariate_effects$outcome[v] * X[class_idx] +
                 0.7 * S[class_idx]  # Surrogate effect on outcome
      prob_y <- plogis(logit_y)
      Y[class_idx] <- rbinom(n_v, 1, prob_y)
    } else {
      # Linear model for continuous outcome
      Y[class_idx] <- treatment_effect_outcome[v] * A[class_idx] + 
                      covariate_effects$outcome[v] * X[class_idx] +
                      0.7 * S[class_idx] +  # Surrogate effect on outcome
                      rnorm(n_v, sd = noise_sd)
    }
  }
  
  # Return as tibble
  tibble::tibble(
    class = class,
    A = A,
    X = X,
    S = S,
    Y = Y
  )
}

#' Generate data for comparison scenarios
#'
#' Creates specific data scenarios mentioned in the method paper for comparing
#' traditional surrogate evaluation methods with the innovation approach.
#'
#' @param scenario Character. Scenario name: "good_innovation_poor_traditional",
#'   "poor_innovation_good_traditional", or "mixture_structure".
#' @param n Integer. Sample size.
#' @param seed Integer. Random seed.
#'
#' @return A tibble with study data for the specified scenario.
#'
#' @details
#' Scenarios:
#' \itemize{
#'   \item "good_innovation_poor_traditional": Low PTE but high cross-study correlation
#'   \item "poor_innovation_good_traditional": High within-study correlation but low cross-study correlation
#'   \item "mixture_structure": Latent classes with varying treatment effects
#' }
#'
#' @examples
#' # Good by innovation method, poor by traditional
#' data1 <- generate_comparison_scenario("good_innovation_poor_traditional", n = 500)
#'
#' # Poor by innovation method, good by traditional
#' data2 <- generate_comparison_scenario("poor_innovation_good_traditional", n = 500)
#'
#' @export
generate_comparison_scenario <- function(scenario = c("good_innovation_poor_traditional",
                                                     "poor_innovation_good_traditional",
                                                     "mixture_structure"),
                                        n = 500,
                                        seed = NULL) {
  
  scenario <- match.arg(scenario)
  
  if (!is.null(seed)) set.seed(seed)
  
  switch(scenario,
    "good_innovation_poor_traditional" = {
      # Low PTE but high cross-study correlation
      # Create mixture where surrogate has strong treatment effect but
      # outcome treatment effect varies across latent classes
      generate_study_data(
        n = n,
        n_classes = 2,
        class_probs = c(0.6, 0.4),
        treatment_effect_surrogate = c(0.8, 0.8),  # Strong, consistent
        treatment_effect_outcome = c(0.2, 0.9),    # Varies by class
        surrogate_type = "continuous",
        outcome_type = "continuous",
        covariate_effects = list(
          surrogate = c(0.3, 0.3),
          outcome = c(0.1, 0.1)
        ),
        seed = seed
      )
    },
    
    "poor_innovation_good_traditional" = {
      # High within-study correlation but low cross-study correlation
      # Strong correlation within study but treatment effects don't
      # transport well across studies
      generate_study_data(
        n = n,
        n_classes = 3,
        class_probs = c(0.4, 0.3, 0.3),
        treatment_effect_surrogate = c(0.5, 0.1, 0.9),  # Varies by class
        treatment_effect_outcome = c(0.4, 0.05, 0.8),   # Varies by class
        surrogate_type = "continuous",
        outcome_type = "continuous",
        covariate_effects = list(
          surrogate = c(0.2, 0.2, 0.2),
          outcome = c(0.1, 0.1, 0.1)
        ),
        seed = seed
      )
    },
    
    "mixture_structure" = {
      # Clear mixture structure with distinct latent classes
      generate_study_data(
        n = n,
        n_classes = 2,
        class_probs = c(0.5, 0.5),
        treatment_effect_surrogate = c(0.2, 0.8),
        treatment_effect_outcome = c(0.1, 0.7),
        surrogate_type = "continuous",
        outcome_type = "continuous",
        covariate_effects = list(
          surrogate = c(0.4, 0.1),
          outcome = c(0.2, 0.05)
        ),
        seed = seed
      )
    }
  )
}

