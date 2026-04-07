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

#' Generate covariate shift study
#'
#' Creates a future study where only the covariate (latent class) distribution
#' shifts, while conditional distributions P(S,Y|X,A,class) remain unchanged.
#' This represents pure covariate shift scenarios.
#'
#' @param baseline_study A tibble from generate_study_data() serving as P₀.
#' @param target_class_probs Numeric vector. New class probabilities for future study.
#'   Length must match number of classes in baseline_study.
#' @param n Integer. Sample size for future study. Default: same as baseline.
#' @param seed Integer. Random seed for reproducibility.
#'
#' @return A list with elements:
#'   \item{future_study}{The generated future study data}
#'   \item{shift_type}{Character: "covariate_shift"}
#'   \item{baseline_class_probs}{Original class probabilities from P₀}
#'   \item{target_class_probs}{New class probabilities in future study}
#'   \item{tv_distance}{Estimated total variation distance between distributions}
#'   \item{kl_divergence}{KL divergence between class distributions}
#'   \item{shift_magnitude}{Maximum absolute change in any class probability}
#'
#' @details
#' This function implements pure covariate shift: the distribution P(class)
#' changes from baseline_class_probs to target_class_probs, but the conditional
#' distributions P(S,Y|A,class) remain identical to the baseline study.
#'
#' This is useful for testing whether the innovation approach (which assumes
#' μ = Dirichlet(1,...,1)) provides valid inference when the true mechanism
#' generating future studies is structured covariate shift rather than uniform
#' perturbations.
#'
#' The TV distance is computed analytically for the class distribution shift,
#' which provides a lower bound on the TV distance between full joint distributions.
#'
#' @examples
#' # Generate baseline study
#' baseline <- generate_study_data(
#'   n = 500,
#'   n_classes = 2,
#'   class_probs = c(0.5, 0.5),
#'   treatment_effect_surrogate = c(0.3, 0.9),
#'   treatment_effect_outcome = c(0.2, 0.8)
#' )
#'
#' # Generate future study with covariate shift
#' future <- generate_covariate_shift_study(
#'   baseline,
#'   target_class_probs = c(0.7, 0.3)  # Shift toward class 1
#' )
#'
#' # Check TV distance
#' future$tv_distance
#'
#' @export
generate_covariate_shift_study <- function(baseline_study,
                                           target_class_probs,
                                           n = nrow(baseline_study),
                                           seed = NULL) {

  if (!is.null(seed)) set.seed(seed)

  # Extract baseline class probabilities
  baseline_classes <- table(baseline_study$class)
  n_classes <- length(baseline_classes)
  baseline_class_probs <- as.numeric(baseline_classes / sum(baseline_classes))

  # Validate target_class_probs
  if (length(target_class_probs) != n_classes) {
    stop("target_class_probs must have length ", n_classes,
         " (number of classes in baseline study)")
  }
  if (abs(sum(target_class_probs) - 1) > 1e-10) {
    stop("target_class_probs must sum to 1")
  }

  # Compute shift metrics
  tv_distance_classes <- 0.5 * sum(abs(baseline_class_probs - target_class_probs))

  # KL divergence (with small constant to avoid log(0))
  epsilon <- 1e-10
  kl_div <- sum(target_class_probs * log((target_class_probs + epsilon) /
                                          (baseline_class_probs + epsilon)))

  # Maximum shift in any single class
  shift_magnitude <- max(abs(target_class_probs - baseline_class_probs))

  # Generate new class assignments with target probabilities
  new_classes <- sample(1:n_classes, size = n, replace = TRUE,
                       prob = target_class_probs)

  # For each observation, sample from baseline observations in that class
  # This preserves the conditional distributions P(S,Y|A,class)
  future_study <- tibble::tibble(
    class = integer(n),
    A = integer(n),
    X = numeric(n),
    S = numeric(n),
    Y = numeric(n)
  )

  for (v in 1:n_classes) {
    new_class_idx <- which(new_classes == v)
    n_needed <- length(new_class_idx)

    if (n_needed == 0) next

    # Get baseline observations from this class
    baseline_class_obs <- baseline_study[baseline_study$class == v, ]

    if (nrow(baseline_class_obs) == 0) {
      stop("No observations in class ", v, " in baseline study")
    }

    # Sample with replacement from baseline observations in this class
    sampled_idx <- sample(1:nrow(baseline_class_obs), size = n_needed,
                         replace = TRUE)

    future_study[new_class_idx, ] <- baseline_class_obs[sampled_idx, ]
  }

  list(
    future_study = future_study,
    shift_type = "covariate_shift",
    baseline_class_probs = baseline_class_probs,
    target_class_probs = target_class_probs,
    tv_distance = tv_distance_classes,
    kl_divergence = kl_div,
    shift_magnitude = shift_magnitude,
    n_classes = n_classes
  )
}

#' Generate selection mechanism study
#'
#' Creates a future study where observations are non-randomly selected from
#' the baseline population according to a selection mechanism. This represents
#' selection bias scenarios common in transportability.
#'
#' @param baseline_study A tibble from generate_study_data() serving as P₀.
#' @param selection_type Character. Type of selection mechanism:
#'   "outcome_favorable" (select healthier patients),
#'   "outcome_unfavorable" (select sicker patients),
#'   "treatment_responders" (select high ΔS),
#'   "treatment_nonresponders" (select low ΔS),
#'   "covariate_extreme" (select extreme X values),
#'   "custom" (provide custom selection_function).
#' @param selection_strength Numeric in [0,1]. Strength of selection bias.
#'   0 = no selection (uniform), 1 = maximum selection bias.
#'   Default: 0.5.
#' @param selection_function Function. For selection_type = "custom", a function
#'   that takes baseline_study and returns selection weights. Default: NULL.
#' @param n Integer. Sample size for future study. Default: same as baseline.
#' @param seed Integer. Random seed for reproducibility.
#'
#' @return A list with elements:
#'   \item{future_study}{The generated future study data}
#'   \item{shift_type}{Character: "selection"}
#'   \item{selection_type}{Type of selection mechanism used}
#'   \item{selection_weights}{Selection probability for each baseline observation}
#'   \item{selection_strength}{Strength parameter used}
#'   \item{effective_sample_size}{Effective sample size after selection}
#'   \item{tv_distance_estimate}{Estimated TV distance (Monte Carlo approximation)}
#'
#' @details
#' This function models future studies arising from non-random selection of
#' participants from the baseline population. Selection mechanisms include:
#'
#' \itemize{
#'   \item outcome_favorable: P(selected) ∝ Y^(selection_strength)
#'   \item outcome_unfavorable: P(selected) ∝ (1-Y)^(selection_strength)
#'   \item treatment_responders: P(selected) ∝ S^(selection_strength) for treated
#'   \item treatment_nonresponders: P(selected) ∝ (1-S)^(selection_strength)
#'   \item covariate_extreme: P(selected) ∝ |X|^(selection_strength)
#' }
#'
#' Selection strength controls how biased the selection is:
#' - strength = 0: uniform selection (no bias)
#' - strength = 1: maximum bias toward selected characteristic
#'
#' This is useful for testing robustness when future studies have selection bias
#' that differs from the uniform Dirichlet(1,...,1) assumption.
#'
#' @examples
#' # Generate baseline study
#' baseline <- generate_study_data(
#'   n = 500,
#'   treatment_effect_surrogate = c(0.3, 0.9),
#'   treatment_effect_outcome = c(0.2, 0.8)
#' )
#'
#' # Future study selects treatment responders
#' future_responders <- generate_selection_study(
#'   baseline,
#'   selection_type = "treatment_responders",
#'   selection_strength = 0.7
#' )
#'
#' # Future study selects healthier patients
#' future_healthy <- generate_selection_study(
#'   baseline,
#'   selection_type = "outcome_favorable",
#'   selection_strength = 0.5
#' )
#'
#' # Check effective sample size (measure of selection bias)
#' future_responders$effective_sample_size
#'
#' @export
generate_selection_study <- function(baseline_study,
                                    selection_type = c("outcome_favorable",
                                                      "outcome_unfavorable",
                                                      "treatment_responders",
                                                      "treatment_nonresponders",
                                                      "covariate_extreme",
                                                      "custom"),
                                    selection_strength = 0.5,
                                    selection_function = NULL,
                                    n = nrow(baseline_study),
                                    seed = NULL) {

  if (!is.null(seed)) set.seed(seed)

  selection_type <- match.arg(selection_type)

  # Validate selection_strength
  if (selection_strength < 0 || selection_strength > 1) {
    stop("selection_strength must be in [0, 1]")
  }

  n_baseline <- nrow(baseline_study)

  # Compute selection weights based on mechanism
  if (selection_type == "custom") {
    if (is.null(selection_function)) {
      stop("selection_function must be provided when selection_type = 'custom'")
    }
    raw_weights <- selection_function(baseline_study)

  } else {
    raw_weights <- switch(selection_type,

      "outcome_favorable" = {
        # Select patients with better outcomes
        # For continuous Y: higher values get higher weight
        # For binary Y: Y=1 gets higher weight
        if (all(baseline_study$Y %in% c(0,1))) {
          # Binary outcome
          baseline_study$Y
        } else {
          # Continuous outcome: standardize and shift to [0,1]
          y_std <- (baseline_study$Y - min(baseline_study$Y)) /
                   (max(baseline_study$Y) - min(baseline_study$Y) + 1e-10)
          y_std
        }
      },

      "outcome_unfavorable" = {
        # Select patients with worse outcomes
        if (all(baseline_study$Y %in% c(0,1))) {
          1 - baseline_study$Y
        } else {
          y_std <- (baseline_study$Y - min(baseline_study$Y)) /
                   (max(baseline_study$Y) - min(baseline_study$Y) + 1e-10)
          1 - y_std
        }
      },

      "treatment_responders" = {
        # Select patients with high surrogate response
        # Only makes sense for treated patients; use overall S for control
        if (all(baseline_study$S %in% c(0,1))) {
          baseline_study$S
        } else {
          s_std <- (baseline_study$S - min(baseline_study$S)) /
                   (max(baseline_study$S) - min(baseline_study$S) + 1e-10)
          s_std
        }
      },

      "treatment_nonresponders" = {
        # Select patients with low surrogate response
        if (all(baseline_study$S %in% c(0,1))) {
          1 - baseline_study$S
        } else {
          s_std <- (baseline_study$S - min(baseline_study$S)) /
                   (max(baseline_study$S) - min(baseline_study$S) + 1e-10)
          1 - s_std
        }
      },

      "covariate_extreme" = {
        # Select patients with extreme covariate values
        abs(baseline_study$X)
      }
    )
  }

  # Apply selection strength: interpolate between uniform and biased
  # strength = 0: uniform weights
  # strength = 1: pure biased weights
  uniform_weights <- rep(1, n_baseline)

  # Ensure raw_weights are positive
  raw_weights <- pmax(raw_weights, 1e-10)

  # Interpolate
  selection_weights <- (1 - selection_strength) * uniform_weights +
                       selection_strength * raw_weights

  # Normalize to probabilities
  selection_probs <- selection_weights / sum(selection_weights)

  # Sample from baseline with selection probabilities
  selected_idx <- sample(1:n_baseline, size = n, replace = TRUE,
                        prob = selection_probs)

  future_study <- baseline_study[selected_idx, ]

  # Compute effective sample size (inverse of sum of squared weights)
  ess <- 1 / sum(selection_probs^2)

  # Estimate TV distance via Monte Carlo
  # TV distance between empirical distribution under selection vs. uniform
  # This is a rough approximation
  tv_estimate <- 0.5 * sum(abs(selection_probs - 1/n_baseline))

  list(
    future_study = future_study,
    shift_type = "selection",
    selection_type = selection_type,
    selection_weights = selection_probs,
    selection_strength = selection_strength,
    effective_sample_size = ess,
    tv_distance_estimate = tv_estimate,
    baseline_n = n_baseline
  )
}

#' Compute total variation distance between empirical distributions
#'
#' Computes the total variation distance between two datasets by treating
#' them as empirical distributions. For finite discrete support (after binning),
#' TV distance is 0.5 * sum(|p - q|) where p and q are probability mass functions.
#'
#' @param data1 First dataset (tibble or data.frame).
#' @param data2 Second dataset (tibble or data.frame).
#' @param variables Character vector. Variables to use for computing TV distance.
#'   Default: c("A", "S", "Y") for treatment, surrogate, outcome.
#' @param n_bins Integer. Number of bins for continuous variables. Default: 10.
#'
#' @return Numeric. Estimated total variation distance in [0, 1].
#'
#' @details
#' This function discretizes continuous variables into bins and computes the
#' TV distance on the resulting discrete joint distribution. For purely discrete
#' variables, it computes the exact TV distance. For mixed discrete/continuous,
#' the result is an approximation that improves with more bins.
#'
#' The TV distance is:
#' d_TV(P, Q) = 0.5 * sum_x |P(x) - Q(x)|
#'
#' This provides an upper bound on the difference in expectations for any
#' bounded function: |E_P[f] - E_Q[f]| ≤ d_TV(P,Q) * (sup f - inf f).
#'
#' @examples
#' data1 <- generate_study_data(n = 500, class_probs = c(0.5, 0.5))
#' data2 <- generate_study_data(n = 500, class_probs = c(0.7, 0.3))
#'
#' # Compute TV distance
#' tv_distance_empirical(data1, data2)
#'
#' @export
tv_distance_empirical <- function(data1,
                                 data2,
                                 variables = c("A", "S", "Y"),
                                 n_bins = 10) {

  # Check that variables exist in both datasets
  if (!all(variables %in% names(data1))) {
    stop("Not all variables found in data1")
  }
  if (!all(variables %in% names(data2))) {
    stop("Not all variables found in data2")
  }

  # Extract relevant variables
  d1 <- data1[, variables, drop = FALSE]
  d2 <- data2[, variables, drop = FALSE]

  # Discretize continuous variables
  for (var in variables) {
    if (is.numeric(d1[[var]]) && length(unique(d1[[var]])) > 20) {
      # Continuous variable: bin it
      combined <- c(d1[[var]], d2[[var]])
      breaks <- quantile(combined, probs = seq(0, 1, length.out = n_bins + 1))
      breaks <- unique(breaks)  # In case of ties

      d1[[var]] <- cut(d1[[var]], breaks = breaks, include.lowest = TRUE,
                      labels = FALSE)
      d2[[var]] <- cut(d2[[var]], breaks = breaks, include.lowest = TRUE,
                      labels = FALSE)
    }
  }

  # Create joint distribution tables
  # Combine to get all possible combinations
  all_data <- rbind(
    cbind(d1, source = "data1"),
    cbind(d2, source = "data2")
  )

  # Get unique combinations (cells)
  cells <- unique(all_data[, variables, drop = FALSE])
  n_cells <- nrow(cells)

  # Compute empirical probabilities for each cell
  prob1 <- numeric(n_cells)
  prob2 <- numeric(n_cells)

  for (i in 1:n_cells) {
    # Check which observations match this cell
    match1 <- rep(TRUE, nrow(d1))
    match2 <- rep(TRUE, nrow(d2))

    for (var in variables) {
      match1 <- match1 & (d1[[var]] == cells[[var]][i] |
                         (is.na(d1[[var]]) & is.na(cells[[var]][i])))
      match2 <- match2 & (d2[[var]] == cells[[var]][i] |
                         (is.na(d2[[var]]) & is.na(cells[[var]][i])))
    }

    prob1[i] <- sum(match1) / nrow(d1)
    prob2[i] <- sum(match2) / nrow(d2)
  }

  # Compute TV distance
  tv_dist <- 0.5 * sum(abs(prob1 - prob2))

  return(tv_dist)
}


#' Generate Study Data with Nonlinear Treatment Effects
#'
#' Creates simulated study data with nonlinear treatment effect functions for
#' testing flexible nuisance estimation methods. Supports various nonlinear
#' patterns to assess method performance under model misspecification.
#'
#' @param n Integer. Sample size for the study. Default: 500
#' @param d Integer. Number of covariates. Default: 2
#' @param pattern Character. Nonlinear pattern for treatment effects:
#'   - "linear": Linear baseline (τ = α + βX)
#'   - "quadratic": Quadratic terms (τ = α + βX + γX²)
#'   - "interaction": Two-way interactions (τ = α + β₁X₁ + β₂X₂ + γX₁X₂)
#'   - "threshold": Step function (τ = α + β·I(X > 0))
#'   - "sine": Sinusoidal (τ = α + β·sin(2πX))
#'   Default: "linear"
#' @param effect_size Character. Overall treatment effect magnitude:
#'   "small", "medium", or "large". Default: "medium"
#' @param noise_sd Numeric. Standard deviation of outcome noise. Default: 0.5
#' @param seed Integer. Random seed for reproducibility. Default: NULL
#'
#' @return Data frame with columns:
#'   \item{A}{Binary treatment assignment (0 or 1)}
#'   \item{S}{Surrogate outcome (continuous)}
#'   \item{Y}{Primary outcome (continuous)}
#'   \item{X1, X2, ..., Xd}{Covariates (standard normal)}
#'
#' @details
#' **Treatment effect patterns (medium effect size):**
#'
#' **Linear (baseline):**
#' - τ_S(X) = 0.3 + 0.2·X₁
#' - τ_Y(X) = 0.4 + 0.3·X₁
#'
#' **Quadratic:**
#' - τ_S(X) = 0.3 + 0.2·X₁ + 0.15·X₁²
#' - τ_Y(X) = 0.4 + 0.3·X₁ + 0.2·X₁²
#'
#' **Interaction (requires d ≥ 2):**
#' - τ_S(X) = 0.3 + 0.2·X₁ + 0.15·X₂ + 0.25·X₁·X₂
#' - τ_Y(X) = 0.4 + 0.3·X₁ + 0.2·X₂ + 0.3·X₁·X₂
#'
#' **Threshold:**
#' - τ_S(X) = 0.2 + 0.4·I(X₁ > 0)
#' - τ_Y(X) = 0.3 + 0.5·I(X₁ > 0)
#'
#' **Sine:**
#' - τ_S(X) = 0.3 + 0.2·sin(2πX₁)
#' - τ_Y(X) = 0.4 + 0.3·sin(2πX₁)
#'
#' **Effect size multipliers:**
#' - Small: coefficients × 0.5
#' - Medium: coefficients × 1.0 (default)
#' - Large: coefficients × 1.5
#'
#' **Data generation model:**
#' - Covariates: X ~ N(0, I_d)
#' - Treatment: A ~ Bernoulli(0.5) (randomized)
#' - Surrogate: S = A·τ_S(X) + ε_S, where ε_S ~ N(0, noise_sd²)
#' - Outcome: Y = A·τ_Y(X) + ε_Y, where ε_Y ~ N(0, noise_sd²)
#'
#' **Use cases:**
#' - Testing flexible methods (GAM, RF) vs linear regression
#' - Assessing misspecification robustness
#' - Validating diagnostics (R², cross-validation)
#' - Comparing method performance across patterns
#'
#' @examples
#' \dontrun{
#' # Linear baseline (lm should work well)
#' data_linear <- generate_nonlinear_study_data(
#'   n = 500, d = 2, pattern = "linear"
#' )
#'
#' # Quadratic (lm will be misspecified)
#' data_quadratic <- generate_nonlinear_study_data(
#'   n = 500, d = 2, pattern = "quadratic"
#' )
#'
#' # Interaction (needs flexible method)
#' data_interaction <- generate_nonlinear_study_data(
#'   n = 500, d = 3, pattern = "interaction", effect_size = "large"
#' )
#'
#' # Threshold (discontinuous)
#' data_threshold <- generate_nonlinear_study_data(
#'   n = 500, d = 2, pattern = "threshold"
#' )
#'
#' # Sine (highly nonlinear)
#' data_sine <- generate_nonlinear_study_data(
#'   n = 500, d = 2, pattern = "sine", noise_sd = 0.3
#' )
#' }
#'
#' @export
generate_nonlinear_study_data <- function(n = 500,
                                           d = 2,
                                           pattern = c("linear", "quadratic",
                                                       "interaction", "threshold",
                                                       "sine"),
                                           effect_size = c("small", "medium", "large"),
                                           noise_sd = 0.5,
                                           seed = NULL) {

  if (!is.null(seed)) set.seed(seed)

  pattern <- match.arg(pattern)
  effect_size <- match.arg(effect_size)

  # Validate inputs
  if (n < 10) stop("Sample size n must be at least 10")
  if (d < 1) stop("Number of covariates d must be at least 1")
  if (pattern == "interaction" && d < 2) {
    stop("Pattern 'interaction' requires at least 2 covariates (d >= 2)")
  }

  # Generate covariates (standard normal)
  X <- matrix(rnorm(n * d), nrow = n, ncol = d)
  colnames(X) <- paste0("X", 1:d)

  # Generate treatment (randomized)
  A <- rbinom(n, 1, 0.5)

  # Effect size multiplier
  multiplier <- switch(effect_size,
                       "small" = 0.5,
                       "medium" = 1.0,
                       "large" = 1.5)

  # Compute treatment effects based on pattern
  tau_S <- compute_tau_pattern(X, pattern, outcome = "S", multiplier)
  tau_Y <- compute_tau_pattern(X, pattern, outcome = "Y", multiplier)

  # Generate outcomes
  S <- A * tau_S + rnorm(n, sd = noise_sd)
  Y <- A * tau_Y + rnorm(n, sd = noise_sd)

  # Combine into data frame
  data <- data.frame(A = A, S = S, Y = Y, X)

  return(data)
}


#' Compute Treatment Effect Pattern (Internal)
#'
#' Computes treatment effect τ(X) according to specified nonlinear pattern.
#'
#' @param X Matrix of covariates (n × d)
#' @param pattern Pattern name
#' @param outcome "S" or "Y" (determines coefficient values)
#' @param multiplier Effect size multiplier
#'
#' @return Numeric vector of length n with treatment effects
#' @keywords internal
compute_tau_pattern <- function(X, pattern, outcome, multiplier) {

  n <- nrow(X)
  X1 <- X[, 1]

  # Base coefficients depend on outcome
  if (outcome == "S") {
    alpha <- 0.3
    beta1 <- 0.2
    beta2 <- 0.15
    gamma <- 0.25
  } else {  # outcome == "Y"
    alpha <- 0.4
    beta1 <- 0.3
    beta2 <- 0.2
    gamma <- 0.3
  }

  # Apply multiplier
  alpha <- alpha * multiplier
  beta1 <- beta1 * multiplier
  beta2 <- beta2 * multiplier
  gamma <- gamma * multiplier

  # Compute τ(X) based on pattern
  if (pattern == "linear") {
    # τ(X) = α + β₁·X₁
    tau <- alpha + beta1 * X1

  } else if (pattern == "quadratic") {
    # τ(X) = α + β₁·X₁ + γ·X₁²
    tau <- alpha + beta1 * X1 + gamma * X1^2

  } else if (pattern == "interaction") {
    # τ(X) = α + β₁·X₁ + β₂·X₂ + γ·X₁·X₂
    X2 <- X[, 2]
    tau <- alpha + beta1 * X1 + beta2 * X2 + gamma * X1 * X2

  } else if (pattern == "threshold") {
    # τ(X) = α + β₁·I(X₁ > 0)
    tau <- alpha + beta1 * (X1 > 0)

  } else if (pattern == "sine") {
    # τ(X) = α + β₁·sin(2π·X₁)
    tau <- alpha + beta1 * sin(2 * pi * X1)

  } else {
    stop(sprintf("Unknown pattern: %s", pattern))
  }

  return(tau)
}

