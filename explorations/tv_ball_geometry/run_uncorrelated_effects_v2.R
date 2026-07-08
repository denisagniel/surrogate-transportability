#!/usr/bin/env Rscript
# Clearer example: truly uncorrelated vs correlated effects

library(tidyverse)
library(MASS)

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")

# Setup
K <- 10
P0 <- rep(1/K, K)

# Scenario 1: Correlated effects (GOOD surrogate)
cat("========================================\n")
cat("SCENARIO 1: Correlated Effects\n")
cat("========================================\n\n")

set.seed(123)
tau_S_corr <- seq(0.2, 0.8, length.out = K)
tau_Y_corr <- tau_S_corr + rnorm(K, sd = 0.1)  # Positively correlated

cat(sprintf("Type-level correlation: cor(τ_S, τ_Y) = %.3f\n\n", cor(tau_S_corr, tau_Y_corr)))

# Sample from TV ball
Q_samples_1 <- hit_and_run_tv_ball(P0, lambda = 0.3, n_samples = 2000,
                                    burn_in = 1000, thin = 10, verbose = FALSE)

Delta_S_1 <- Q_samples_1 %*% tau_S_corr
Delta_Y_1 <- Q_samples_1 %*% tau_Y_corr

cor_1 <- cor(Delta_S_1, Delta_Y_1)
cat(sprintf("Across-study correlation: %.3f\n", cor_1))
cat("→ Strong positive correlation: GOOD surrogate\n\n")

# Scenario 2: Uncorrelated effects (POOR surrogate)
cat("========================================\n")
cat("SCENARIO 2: Uncorrelated Effects\n")
cat("========================================\n\n")

set.seed(456)
tau_S_uncorr <- seq(0.2, 0.8, length.out = K)
tau_Y_uncorr <- c(0.8, 0.3, 0.6, 0.4, 0.5, 0.7, 0.2, 0.9, 0.35, 0.65)  # Manually uncorrelated

# Force correlation to be near zero
tau_Y_uncorr <- tau_Y_uncorr - mean(tau_Y_uncorr)
tau_Y_uncorr <- tau_Y_uncorr - cor(tau_S_uncorr, tau_Y_uncorr) *
                (tau_S_uncorr - mean(tau_S_uncorr)) / var(tau_S_uncorr) * var(tau_Y_uncorr)
tau_Y_uncorr <- tau_Y_uncorr + mean(tau_S_uncorr)

cat(sprintf("Type-level correlation: cor(τ_S, τ_Y) = %.3f\n\n", cor(tau_S_uncorr, tau_Y_uncorr)))

# Sample from TV ball (reuse same samples for fair comparison)
Delta_S_2 <- Q_samples_1 %*% tau_S_uncorr
Delta_Y_2 <- Q_samples_1 %*% tau_Y_uncorr

cor_2 <- cor(Delta_S_2, Delta_Y_2)
cat(sprintf("Across-study correlation: %.3f\n", cor_2))
cat("→ Near-zero correlation: POOR surrogate\n\n")

# Scenario 3: Negatively correlated effects (BAD surrogate)
cat("========================================\n")
cat("SCENARIO 3: Negatively Correlated Effects\n")
cat("========================================\n\n")

set.seed(789)
tau_S_neg <- seq(0.2, 0.8, length.out = K)
tau_Y_neg <- rev(tau_S_neg) + rnorm(K, sd = 0.05)  # Negatively correlated

cat(sprintf("Type-level correlation: cor(τ_S, τ_Y) = %.3f\n\n", cor(tau_S_neg, tau_Y_neg)))

Delta_S_3 <- Q_samples_1 %*% tau_S_neg
Delta_Y_3 <- Q_samples_1 %*% tau_Y_neg

cor_3 <- cor(Delta_S_3, Delta_Y_3)
cat(sprintf("Across-study correlation: %.3f\n", cor_3))
cat("→ Negative correlation: BAD surrogate (opposite effects!)\n\n")

# Summary
cat("========================================\n")
cat("SUMMARY\n")
cat("========================================\n\n")

results <- tibble(
  scenario = c("Correlated", "Uncorrelated", "Negatively Correlated"),
  type_cor = c(cor(tau_S_corr, tau_Y_corr),
               cor(tau_S_uncorr, tau_Y_uncorr),
               cor(tau_S_neg, tau_Y_neg)),
  across_study_cor = c(cor_1, cor_2, cor_3),
  surrogate_quality = c("GOOD", "POOR", "BAD")
)

print(results, n = Inf)

cat("\nKey insight:\n")
cat("  Type-level correlation → Across-study correlation\n")
cat("  Only when treatment effects are correlated across types\n")
cat("  will they be correlated across studies (Q distributions)\n\n")

# Combined visualization
plot_data <- bind_rows(
  tibble(scenario = "Correlated\n(GOOD)", Delta_S = as.numeric(Delta_S_1), Delta_Y = as.numeric(Delta_Y_1)),
  tibble(scenario = "Uncorrelated\n(POOR)", Delta_S = as.numeric(Delta_S_2), Delta_Y = as.numeric(Delta_Y_2)),
  tibble(scenario = "Negatively Correlated\n(BAD)", Delta_S = as.numeric(Delta_S_3), Delta_Y = as.numeric(Delta_Y_3))
)

p <- ggplot(plot_data, aes(x = Delta_S, y = Delta_Y)) +
  geom_point(alpha = 0.2, size = 0.8) +
  geom_smooth(method = "lm", se = TRUE, color = "steelblue", linewidth = 1) +
  facet_wrap(~scenario, scales = "free", nrow = 1) +
  labs(
    title = "Across-Study Treatment Effect Correlation",
    subtitle = "Same Q samples, different type-level effect patterns",
    x = "ΔS(Q) = Q'τ_S",
    y = "ΔY(Q) = Q'τ_Y",
    caption = "M = 2000 samples from TV ball (λ = 0.3)"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    strip.text = element_text(face = "bold", size = 10),
    strip.background = element_rect(fill = "gray90", color = NA)
  )

print(p)
ggsave(
  "explorations/tv_ball_geometry/figures/effect_correlation_scenarios.pdf",
  p, width = 12, height = 4
)

cat("Results saved to:\n")
cat("  explorations/tv_ball_geometry/figures/effect_correlation_scenarios.pdf\n")
