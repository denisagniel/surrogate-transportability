#!/usr/bin/env Rscript
# TEST 3 (FIXED): Validate Wasserstein DRO dual formulation

library(tidyverse)
library(here)

devtools::load_all(here("package"))

cat("=============================================================================\n")
cat("TEST 3: Is the Wasserstein dual formulation correct?\n")
cat("=============================================================================\n\n")

cat("Strategy: Test mathematical properties the dual MUST satisfy\n\n")

# Generate fixed data with KNOWN concordances (use true tau, no estimation error)
set.seed(42)
n <- 200

X1 <- rnorm(n)
X2 <- rnorm(n)

# TRUE concordance at each point (oracle - no estimation!)
h_true <- 0.3 + 0.2 * X1 - 0.1 * X2

# Cost matrix
X <- scale(cbind(X1, X2))
cost_matrix <- as.matrix(dist(X, method = "euclidean"))^2

cat("Data:\n")
cat("  n =", n, "observations\n")
cat("  Concordance: mean =", round(mean(h_true), 4),
    ", min =", round(min(h_true), 4),
    ", max =", round(max(h_true), 4), "\n\n")

# =============================================================================
# Property 1: At lambda_w = 0, minimax should equal mean
# =============================================================================

cat("PROPERTY 1: At lambda_w = 0, should get mean concordance\n")
cat("  (Zero constraint → Q must equal P_n → E_Q[h] = E_Pn[h])\n\n")

dual_objective <- function(gamma, lambda_w, h, C) {
  obj_matrix <- matrix(h, nrow = length(h), ncol = length(h), byrow = TRUE) +
                gamma * C
  inner_mins <- apply(obj_matrix, 1, min)
  -gamma * lambda_w^2 + mean(inner_mins)
}

# At lambda_w = 0
lambda_0 <- 1e-10  # Essentially zero
result_0 <- optimize(
  function(g) dual_objective(g, lambda_0, h_true, cost_matrix),
  interval = c(0, 100),
  maximum = TRUE
)

expected_mean <- mean(h_true)
actual_at_0 <- result_0$objective

cat("  Expected (mean):  ", round(expected_mean, 6), "\n")
cat("  Dual result:      ", round(actual_at_0, 6), "\n")
cat("  Difference:       ", round(actual_at_0 - expected_mean, 6), "\n")

prop1_pass <- abs(actual_at_0 - expected_mean) < 0.01
cat("  Status:", ifelse(prop1_pass, "✓ PASS", "✗ FAIL"), "\n\n")

# =============================================================================
# Property 2: As lambda_w increases, phi* should decrease (monotonically)
# =============================================================================

cat("PROPERTY 2: Monotonicity - larger lambda_w → lower minimax\n")
cat("  (Looser constraint → smaller feasible set minimum)\n\n")

lambda_values <- seq(0.05, 1.0, by = 0.05)
phi_values <- numeric(length(lambda_values))

for (i in 1:length(lambda_values)) {
  lw <- lambda_values[i]
  result <- optimize(
    function(g) dual_objective(g, lw, h_true, cost_matrix),
    interval = c(0, 100),
    maximum = TRUE
  )
  phi_values[i] <- result$objective
}

# Check monotonicity
differences <- diff(phi_values)
n_decreasing <- sum(differences < 0)
n_total <- length(differences)

cat("  lambda_w range: [", lambda_values[1], ",", lambda_values[length(lambda_values)], "]\n")
cat("  phi* range: [", round(min(phi_values), 4), ",", round(max(phi_values), 4), "]\n")
cat("  Monotone decreasing steps:", n_decreasing, "/", n_total, "\n")

prop2_pass <- n_decreasing >= 0.95 * n_total  # Allow small numerical noise
cat("  Status:", ifelse(prop2_pass, "✓ PASS", "✗ FAIL"), "\n\n")

# =============================================================================
# Property 3: At large lambda_w, should approach naive minimum
# =============================================================================

cat("PROPERTY 3: At large lambda_w, should approach min concordance\n")
cat("  (Very loose constraint → can put mass anywhere → min(h))\n\n")

lambda_large <- 10.0  # Very large
result_large <- optimize(
  function(g) dual_objective(g, lambda_large, h_true, cost_matrix),
  interval = c(0, 100),
  maximum = TRUE
)

expected_min <- min(h_true)
actual_at_large <- result_large$objective

cat("  Expected (min):   ", round(expected_min, 6), "\n")
cat("  Dual result:      ", round(actual_at_large, 6), "\n")
cat("  Difference:       ", round(actual_at_large - expected_min, 6), "\n")

# Should be close but maybe not exact due to cost structure
prop3_pass <- abs(actual_at_large - expected_min) < 0.2 * abs(expected_min)
cat("  Status:", ifelse(prop3_pass, "✓ PASS (within 20%)", "✗ FAIL"), "\n\n")

# =============================================================================
# Property 4: Primal-dual verification - construct Q* from dual solution
# =============================================================================

cat("PROPERTY 4: Primal-dual consistency\n")
cat("  Dual solution should imply a valid primal Q* with E_Q*[h] = phi*\n\n")

lambda_test <- 0.3
result_test <- optimize(
  function(g) dual_objective(g, lambda_test, h_true, cost_matrix),
  interval = c(0, 100),
  maximum = TRUE
)

phi_dual <- result_test$objective
gamma_star <- result_test$maximum

cat("  lambda_w =", lambda_test, "\n")
cat("  Dual result: phi* =", round(phi_dual, 6), ", gamma* =", round(gamma_star, 6), "\n\n")

# From dual solution, construct the optimal transport plan
# For each i, mass goes to j* = argmin_j {h[j] + gamma*C[i,j]}
obj_matrix <- matrix(h_true, nrow = n, ncol = n, byrow = TRUE) +
              gamma_star * cost_matrix

# Find target for each source
targets <- apply(obj_matrix, 1, which.min)

# Resulting Q* distribution (how much mass ends up at each observation)
q_star <- rep(0, n)
for (i in 1:n) {
  q_star[targets[i]] <- q_star[targets[i]] + 1/n
}

# Verify q_star sums to 1
cat("  Q* is valid distribution: sum =", round(sum(q_star), 6), "\n")

# Compute E_Q*[h]
e_q_h <- sum(q_star * h_true)

cat("  E_Q*[h] =", round(e_q_h, 6), "\n")
cat("  phi* (dual) =", round(phi_dual, 6), "\n")
cat("  Difference:", round(abs(e_q_h - phi_dual), 6), "\n")

prop4_pass <- abs(e_q_h - phi_dual) < 1e-4
cat("  Status:", ifelse(prop4_pass, "✓ PASS", "✗ FAIL"), "\n\n")

# =============================================================================
# Property 5: Verify Wasserstein constraint is satisfied (approximately)
# =============================================================================

cat("PROPERTY 5: Q* satisfies Wasserstein constraint W_2(Q*, P_n) ≤ lambda_w\n\n")

# Compute Wasserstein distance between Q* and uniform P_n
# This is expensive in general, but with our transport plan we can compute the cost

p_n <- rep(1/n, n)

# Total transport cost under the plan
# Cost = sum_i p_n[i] * C[i, targets[i]]
total_cost <- 0
for (i in 1:n) {
  total_cost <- total_cost + p_n[i] * cost_matrix[i, targets[i]]
}

w2_distance <- sqrt(total_cost)

cat("  W_2(Q*, P_n) =", round(w2_distance, 6), "\n")
cat("  Constraint: lambda_w =", lambda_test, "\n")
cat("  Satisfied?", w2_distance <= lambda_test + 1e-6, "\n")

# For Wasserstein ball, constraint should be BINDING (equality) at optimum
cat("  Binding (≈ equality)?", abs(w2_distance - lambda_test) < 0.05, "\n")

prop5_pass <- w2_distance <= lambda_test + 1e-3
cat("  Status:", ifelse(prop5_pass, "✓ PASS", "✗ FAIL"), "\n\n")

# =============================================================================
# Property 6: Compare to simple approximation
# =============================================================================

cat("PROPERTY 6: Sanity check against simple lower bound\n")
cat("  A valid (suboptimal) Q is: Q = P_n → gives E_Q[h] = mean(h)\n")
cat("  Minimax should be ≤ mean (can always choose Q = P_n)\n\n")

cat("  phi* =", round(phi_dual, 6), "\n")
cat("  mean(h) =", round(mean(h_true), 6), "\n")
cat("  phi* ≤ mean?", phi_dual <= mean(h_true) + 1e-6, "\n")

prop6_pass <- phi_dual <= mean(h_true) + 1e-3
cat("  Status:", ifelse(prop6_pass, "✓ PASS", "✗ FAIL"), "\n\n")

# =============================================================================
# ADDITIONAL: Compare dual to exact OT solution (for small n)
# =============================================================================

cat("BONUS: Compare to exact optimal transport solution\n")
cat("  Using transport package to solve primal directly\n\n")

if (requireNamespace("transport", quietly = TRUE)) {
  # Primal: min_{Q: W_2(Q,P_n)<=lambda_w} E_Q[h]
  # This is hard to solve directly with the constraint
  # But we can check that our dual solution is reasonable

  # Compute W_2 distances from P_n to a few candidate Q distributions
  # and verify our solution makes sense

  cat("  Transport package available - computing reference distances\n")

  # Create a simple alternative Q: put more mass on low-h observations
  h_order <- order(h_true)
  q_alternative <- rep(0, n)
  # Put 2x mass on lowest quartile
  q_alternative[h_order[1:floor(n/4)]] <- 2 / n
  q_alternative[h_order[(floor(n/4)+1):n]] <- (n - 2*floor(n/4)) / n / (n - floor(n/4))
  q_alternative <- q_alternative / sum(q_alternative)  # Normalize

  # Compute W_2(q_alternative, p_n) using transport package
  wpp_pn <- transport::wpp(X, mass = p_n)
  wpp_q <- transport::wpp(X, mass = q_alternative)
  w2_alt <- transport::wasserstein(wpp_pn, wpp_q, p = 2)

  e_q_alt <- sum(q_alternative * h_true)

  cat("    Alternative Q:\n")
  cat("      W_2(Q_alt, P_n) =", round(w2_alt, 4), "\n")
  cat("      E_Q_alt[h] =", round(e_q_alt, 4), "\n")
  cat("      Feasible?", w2_alt <= lambda_test, "\n")

  if (w2_alt <= lambda_test) {
    cat("      Our dual gives:", round(phi_dual, 4), "\n")
    cat("      Should be ≤ alternative:", phi_dual <= e_q_alt, "\n")
  }

} else {
  cat("  Transport package not available - skipping\n")
}

cat("\n")

# =============================================================================
# SUMMARY
# =============================================================================

cat("=============================================================================\n")
cat("TEST 3 SUMMARY: Dual Formulation Properties\n")
cat("=============================================================================\n\n")

cat("Property 1 (lambda=0 → mean):      ", ifelse(prop1_pass, "✓ PASS", "✗ FAIL"), "\n")
cat("Property 2 (monotonicity):         ", ifelse(prop2_pass, "✓ PASS", "✗ FAIL"), "\n")
cat("Property 3 (lambda→∞ → min):       ", ifelse(prop3_pass, "✓ PASS", "✗ FAIL"), "\n")
cat("Property 4 (primal-dual match):    ", ifelse(prop4_pass, "✓ PASS", "✗ FAIL"), "\n")
cat("Property 5 (constraint satisfied): ", ifelse(prop5_pass, "✓ PASS", "✗ FAIL"), "\n")
cat("Property 6 (≤ mean):               ", ifelse(prop6_pass, "✓ PASS", "✗ FAIL"), "\n\n")

all_pass <- prop1_pass && prop2_pass && prop3_pass && prop4_pass && prop5_pass && prop6_pass

if (all_pass) {
  cat("=============================================================================\n")
  cat("✓✓✓ ALL PROPERTIES SATISFIED ✓✓✓\n")
  cat("The Wasserstein dual formulation is mathematically correct.\n")
  cat("=============================================================================\n")
} else {
  cat("=============================================================================\n")
  cat("⚠ SOME PROPERTIES FAILED - DUAL HAS BUGS ⚠\n")
  cat("=============================================================================\n")
}

cat("\nNote: This tests the dual formulation itself, not whether it finds\n")
cat("      the right answer in practice (that's Tests 1 and 2).\n")
