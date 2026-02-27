set.seed(123)

# ----- Outer level: simulate many possible "true" studies -----
true_num_studies <- 50000   # large for ground truth
study_size <- 500           # subjects per study

# Parameters:
# Surrogate model coefficients
b_S_A <- 0.5
b_S_X <- 0.3

# Outcome model coefficients (A intercept fixed, slope for S varies across studies)
b_Y_A <- 0.2
b_Y_X <- 0.1
b_Y_S_mean <- 0.7
b_Y_S_sd <- 0.3  # variation in slope for S across studies

true_results <- data.frame(delta_S = numeric(true_num_studies),
                           delta_Y = numeric(true_num_studies))

for (i in seq_len(true_num_studies)) {

  # Draw a study-specific slope for S in the Y model
  b_Y_S <- rnorm(1, mean = b_Y_S_mean, sd = b_Y_S_sd)

  # Simulate study data
  X <- rnorm(study_size)
  A <- rbinom(study_size, 1, 0.5)
  S <- b_S_A*A + b_S_X*X + rnorm(study_size, sd = 0.5)
  Y <- b_Y_S*S + b_Y_A*A + b_Y_X*X + rnorm(study_size, sd = 1)

  # Record treatment effects
  delta_S <- mean(S[A==1]) - mean(S[A==0])
  delta_Y <- mean(Y[A==1]) - mean(Y[A==0])

  true_results$delta_S[i] <- delta_S
  true_results$delta_Y[i] <- delta_Y
}

# ---- True functionals ----
true_corr <- cor(true_results$delta_S, true_results$delta_Y)

# Probability functional: P(ΔY>eps_Y | ΔS>eps_S)
eps_S <- 0.2; eps_Y <- 0.1
true_prob <- mean(true_results$delta_Y > eps_Y & true_results$delta_S > eps_S) /
  mean(true_results$delta_S > eps_S)

list(true_corr = true_corr, true_prob = true_prob)

