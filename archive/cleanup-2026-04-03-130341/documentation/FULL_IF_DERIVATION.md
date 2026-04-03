# Complete Influence Function Derivation for Observation-Level Wasserstein Dual

**Date:** April 1, 2026
**Status:** Final derivation with both terms

---

## Estimand

$$\phi^*(\lambda_w) = \sup_{\gamma \geq 0} g(\gamma)$$

where:

$$g(\gamma) = -\gamma \lambda_w^2 + \Psi(\gamma)$$

$$\Psi(\gamma) = \mathbb{E}_{X \sim P_0}\left[-\tau \log \mathbb{E}_{X' \sim P_0}\left[\exp\left(-\frac{h(X') + \gamma(X'-X)^2}{\tau}\right)\right]\right]$$

$$h(X) = \tau_S(X) \times \tau_Y(X)$$

---

## Two Sources of Variability

The complete IF has **two terms** corresponding to two sources of uncertainty:

### Source 1: Sampling Variability in X

Which covariate values $X_1, \ldots, X_n$ we observe.

**IF contribution:**

$$\text{IF}_{\text{sampling}}(X_k; \gamma) = -\tau \log m(X_k; \gamma) - \tau \mathbb{E}_X\left[\frac{g(X, X_k; \gamma)}{m(X; \gamma)}\right] + \tau - \Psi(\gamma)$$

### Source 2: Estimation Uncertainty in h(X)

The concordance function $h(X) = \tau_S(X) \times \tau_Y(X)$ is estimated from data.

**IF contribution:**

$$\text{IF}_{\text{nuisance}}(O_k; \gamma) = \frac{1}{n} \sum_{j=1}^n w_k^j(\gamma) \cdot \text{IF}_{h(X_k)}(O_k)$$

where $w_k^j(\gamma)$ are softmax weights.

---

## Complete Influence Function

$$\boxed{
\text{IF}_{\Psi}(O_k; \gamma) = \text{IF}_{\text{sampling}}(X_k; \gamma) + \text{IF}_{\text{nuisance}}(O_k; \gamma)
}$$

---

## Cross-Fitting: Why It Works

**Key insight:** Cross-fitting makes the terms **independent** (no bias), but both sources of uncertainty still affect the estimator's variance.

**Both terms must be included for valid inference.**
