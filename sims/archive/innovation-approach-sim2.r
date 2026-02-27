set.seed(123)

# Current study size
n_current <- 500

# Covariate X ~ Normal
X <- rnorm(n_current)

# Treatment A ~ Bernoulli(0.5)
A <- rbinom(n_current, 1, 0.5)

# Surrogate S = 0.5*A + 0.3*X + noise
S <- 0.5*A + 0.3*X + rnorm(n_current, sd = 0.5)

# Outcome Y = 0.7*S + 0.2*A + 0.1*X + noise
Y <- 0.7*S + 0.2*A + 0.1*X + rnorm(n_current, sd = 1)

current_data <- data.frame(X, A, S, Y)

# Quick check: population-level treatment effects (from current data)
delta_S_current <- mean(current_data$S[current_data$A == 1]) - mean(current_data$S[current_data$A == 0])
delta_Y_current <- mean(current_data$Y[current_data$A == 1]) - mean(current_data$Y[current_data$A == 0])
c(delta_S_current = delta_S_current, delta_Y_current = delta_Y_current)

library(MCMCpack)  # for rdirichlet

# Helper to compute treatment effect given a dataset
treatment_effect <- function(data, outcome) {
  mean(data[data$A == 1, outcome]) - mean(data[data$A == 0, outcome])
}

generate_future_study <- function(current_data, a = 2, b = 5, m_future = nrow(current_data)) {
  n <- nrow(current_data)

  # Step 1: sample closeness lambda
  lambda <- rbeta(1, a, b)

  # Step 2: BB innovation weights over observed data points
  bb_weights <- as.numeric(rdirichlet(1, rep(1, n)))

  # Step 3: empirical weights from current data
  p0_weights <- rep(1/n, n)

  # Step 4: mixture weights
  future_weights <- (1 - lambda) * p0_weights + lambda * bb_weights

  # Step 5: sample m_future individuals from mixture distribution
  idx <- sample(seq_len(n), size = m_future, replace = TRUE, prob = future_weights)

  future_data <- current_data[idx, ]
  list(lambda = lambda, future_data = future_data)
}

# Posterior predictive draws
B <- 2000
results <- data.frame(lambda = numeric(B),
                      delta_S = numeric(B),
                      delta_Y = numeric(B))

for (b in seq_len(B)) {
  fut <- generate_future_study(current_data, a = 2, b = 5, m_future = 500)
  results$lambda[b] <- fut$lambda
  results$delta_S[b] <- treatment_effect(fut$future_data, "S")
  results$delta_Y[b] <- treatment_effect(fut$future_data, "Y")
}

# Posterior summaries
posterior_corr <- cor(results$delta_S, results$delta_Y)

summary_delta_S <- quantile(results$delta_S, probs = c(0.025, 0.5, 0.975))
summary_delta_Y <- quantile(results$delta_Y, probs = c(0.025, 0.5, 0.975))

posterior_corr
summary_delta_S
summary_delta_Y

R_outer <- 500  # outer BB resamples of current study
corr_draws <- numeric(R_outer)

for (r in seq_len(R_outer)) {
  # Outer BB to resample current data
  outer_weights <- as.numeric(rdirichlet(1, rep(1, n_current)))
  idx_outer <- sample(seq_len(n_current), size = n_current, replace = TRUE, prob = outer_weights)
  current_resampled <- current_data[idx_outer, ]

  # Inner loop: simulate many future studies from this resampled P0
  B_inner <- 200
  deltas <- data.frame(deltaS = numeric(B_inner), deltaY = numeric(B_inner))

  for (b in seq_len(B_inner)) {
    fut <- generate_future_study(current_resampled, a = 2, b = 5, m_future = 500)
    deltas$deltaS[b] <- treatment_effect(fut$future_data, "S")
    deltas$deltaY[b] <- treatment_effect(fut$future_data, "Y")
  }

  corr_draws[r] <- cor(deltas$deltaS, deltas$deltaY)
}

# Posterior summary for correlation functional
quantile(corr_draws, probs = c(0.025, 0.5, 0.975))
