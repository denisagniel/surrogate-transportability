library(MCMCpack)

# K=4 scenario
K <- 4
tau_s <- c(-0.6, -0.2, 0.2, 0.6)
tau_y <- c(-0.5, -0.1, 0.1, 0.5)
lambda <- 0.3
M <- 5000

set.seed(123)
type_innovations <- rdirichlet(M, rep(1, K))

effects <- matrix(NA, M, 2)
for (m in 1:M) {
  type_weights_m <- type_innovations[m, ]
  p0_type <- rep(1/K, K)
  q_m_type <- (1 - lambda) * p0_type + lambda * type_weights_m
  
  effects[m, 1] <- sum(q_m_type * tau_s)
  effects[m, 2] <- sum(q_m_type * tau_y)
}

# Need to compute correlation for SUBSETS, not overall
# Look at rolling correlations or bootstrap correlations

# Method 1: What's the minimum pairwise product (proxy for min correlation)?
min_product <- min(effects[, 1] * effects[, 2])

# Method 2: For subsets of size 100, what's min correlation?
min_corrs <- sapply(1:100, function(i) {
  idx <- sample(1:M, size = 100)
  cor(effects[idx, 1], effects[idx, 2])
})

cat("K=4 Type-Level Analysis:\n")
cat(sprintf("  Average correlation: %.3f\n", cor(effects[, 1], effects[, 2])))
cat(sprintf("  Min product (proxy): %.6f\n", min_product))
cat(sprintf("  5th percentile of subset correlations: %.3f\n", quantile(min_corrs, 0.05)))
cat(sprintf("  1st percentile of subset correlations: %.3f\n", quantile(min_corrs, 0.01)))
cat(sprintf("  Minimum of subset correlations: %.3f\n\n", min(min_corrs)))

# What we found with multi-scheme: 0.824
# Is this plausible for the true minimax?

# Try to find adversarial type weights
cat("Searching for adversarial type weights...\n")
objective <- function(v) {
  # v are simplex weights (will project to simplex)
  v <- exp(v) / sum(exp(v))
  p0 <- rep(1/K, K)
  q <- (1 - lambda) * p0 + lambda * v
  
  delta_s <- sum(q * tau_s)
  delta_y <- sum(q * tau_y)
  
  # Want to minimize correlation = delta_s * delta_y / (sd_s * sd_y)
  # Since sd's are fixed for this distribution, minimize product
  return(delta_s * delta_y)
}

# Optimize
result <- optim(rep(0, K), objective, method = "BFGS")
v_opt <- exp(result$par) / sum(exp(result$par))

p0 <- rep(1/K, K)
q_worst <- (1 - lambda) * p0 + lambda * v_opt

delta_s_worst <- sum(q_worst * tau_s)
delta_y_worst <- sum(q_worst * tau_y)

cat(sprintf("Adversarial type weights: %s\n", paste(round(v_opt, 3), collapse=", ")))
cat(sprintf("Resulting Q weights: %s\n", paste(round(q_worst, 3), collapse=", ")))
cat(sprintf("Delta_S: %.3f, Delta_Y: %.3f\n", delta_s_worst, delta_y_worst))
cat(sprintf("Product: %.6f\n\n", delta_s_worst * delta_y_worst))

# The actual minimum correlation in TV ball would need to account for
# the fact that we're looking at distribution of (Delta_S, Delta_Y) pairs
# not just a single pair
