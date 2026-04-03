# Observation-Level Efficient Influence Function Derivation

**Date:** April 1, 2026
**Status:** Complete theoretical derivation

---

## Problem Setup

**Estimand:** Minimax concordance under observation-level Wasserstein ambiguity:

$$
\phi^*(\lambda_w) = \sup_{\gamma \geq 0} \left\{ -\gamma \lambda_w^2 + \frac{1}{n} \sum_{j=1}^n \phi_\tau^j(\gamma) \right\}
$$

where for each reference observation $j$:

$$
\phi_\tau^j(\gamma) = -\tau \log\left( \frac{1}{n} \sum_{i=1}^n \exp\left( -\frac{h_i + \gamma C[i,j]}{\tau} \right) \right)
$$

**Key quantities:**
- $h_i = \tau_S(X_i) \times \tau_Y(X_i)$ — concordance at observation $i$
- $C[i,j] = (X_i - X_j)^2$ — cost matrix (squared distance)
- $\tau$ — smoothing parameter (small positive constant)
- $\lambda_w$ — Wasserstein radius
- $\gamma^*$ — optimal dual variable (computed numerically)

**No discretization:** Works directly with all $n$ observations, avoiding type-based aggregation.

---

## Step 1: Influence Function for $h_i$ (Concordances)

Each concordance is a product of treatment effects at observation $i$:

$$
h_i = \tau_S(X_i) \times \tau_Y(X_i)
$$

Under randomized treatment with $e(X_i) = 0.5$:

$$
\text{IF}_{\tau_S}(O) = \frac{A(S - \mu_S^1(X))}{e(X)} - \frac{(1-A)(S - \mu_S^0(X))}{1-e(X)}
$$

$$
\text{IF}_{\tau_Y}(O) = \frac{A(Y - \mu_Y^1(X))}{e(X)} - \frac{(1-A)(Y - \mu_Y^0(X))}{1-e(X)}
$$

**Product rule for $h_i$:**

$$
\text{IF}_{h_i}(O_k) =
\begin{cases}
\tau_S(X_i) \cdot \text{IF}_{\tau_Y}(O_k) + \tau_Y(X_i) \cdot \text{IF}_{\tau_S}(O_k) & \text{if } k = i \\
0 & \text{if } k \neq i
\end{cases}
$$

The IF for $h_i$ is non-zero only for observation $i$ itself.

---

## Step 2: Influence Function for $\phi_\tau^j(\gamma)$ (Reference Observation $j$)

For fixed $\gamma$ and reference observation $j$:

$$
\phi_\tau^j(\gamma) = -\tau \log\left( \frac{1}{n} \sum_{i=1}^n \exp\left( -\frac{h_i + \gamma C[i,j]}{\tau} \right) \right)
$$

**Pathwise derivative with respect to $h_k$:**

Using the chain rule:

$$
\frac{\partial \phi_\tau^j}{\partial h_k} = -\tau \cdot \frac{1}{\frac{1}{n} \sum_{i=1}^n \exp(-\frac{h_i + \gamma C[i,j]}{\tau})} \cdot \frac{1}{n} \cdot \exp\left(-\frac{h_k + \gamma C[k,j]}{\tau}\right) \cdot \left(-\frac{1}{\tau}\right)
$$

Simplifying:

$$
\frac{\partial \phi_\tau^j}{\partial h_k} = \frac{\exp(-\frac{h_k + \gamma C[k,j]}{\tau})}{\sum_{i=1}^n \exp(-\frac{h_i + \gamma C[i,j]}{\tau})} = w_k^j(\gamma)
$$

This is the **softmax weight**: how much observation $k$ contributes to the smooth minimum at reference $j$.

**Influence function for $\phi_\tau^j(\gamma)$:**

By the chain rule:

$$
\text{IF}_{\phi_\tau^j}(O; \gamma) = \sum_{k=1}^n \frac{\partial \phi_\tau^j}{\partial h_k} \cdot \text{IF}_{h_k}(O) = \sum_{k=1}^n w_k^j(\gamma) \cdot \text{IF}_{h_k}(O)
$$

For a specific observation $O_\ell$:

$$
\text{IF}_{\phi_\tau^j}(O_\ell; \gamma) = w_\ell^j(\gamma) \cdot \text{IF}_{h_\ell}(O_\ell)
$$

since $\text{IF}_{h_k}(O_\ell) = 0$ for $k \neq \ell$.

---

## Step 3: Influence Function for $g_\tau(\gamma)$ (Dual Objective)

The dual objective for fixed $\gamma$:

$$
g_\tau(\gamma) = -\gamma \lambda_w^2 + \frac{1}{n} \sum_{j=1}^n \phi_\tau^j(\gamma)
$$

The first term $-\gamma \lambda_w^2$ is constant (does not depend on data), so:

$$
\text{IF}_{g_\tau}(O; \gamma) = \frac{1}{n} \sum_{j=1}^n \text{IF}_{\phi_\tau^j}(O; \gamma)
$$

For observation $O_\ell$:

$$
\text{IF}_{g_\tau}(O_\ell; \gamma) = \frac{1}{n} \sum_{j=1}^n w_\ell^j(\gamma) \cdot \text{IF}_{h_\ell}(O_\ell)
$$

**Interpretation:** Observation $\ell$ contributes to the dual objective through ALL reference observations $j$, weighted by how much $\ell$ influences each $j$'s smooth minimum.

---

## Step 4: Influence Function for $\gamma^*$ (Optimal Dual Variable)

At the optimum $\gamma^*$, the first-order condition holds:

$$
\frac{\partial g_\tau}{\partial \gamma}\bigg|_{\gamma = \gamma^*} = 0
$$

(assuming interior solution; boundary case $\gamma^* = 0$ handled separately).

**Envelope theorem application:**

By the implicit function theorem, the IF for $\gamma^*$ would be:

$$
\text{IF}_{\gamma^*}(O) = -\left[\frac{\partial^2 g_\tau}{\partial \gamma^2}\bigg|_{\gamma^*}\right]^{-1} \cdot \left[\frac{\partial}{\partial \gamma} \text{IF}_{g_\tau}(O; \gamma)\bigg|_{\gamma^*}\right]
$$

**BUT** we don't need this! By the envelope theorem:

$$
\text{IF}_{\phi^*}(O) = \frac{\partial g_\tau}{\partial \gamma}\bigg|_{\gamma^*} \cdot \text{IF}_{\gamma^*}(O) + \text{IF}_{g_\tau}(O; \gamma^*)
$$

Since $\frac{\partial g_\tau}{\partial \gamma}|_{\gamma^*} = 0$ (first-order condition), the first term **vanishes**:

$$
\text{IF}_{\phi^*}(O) = \text{IF}_{g_\tau}(O; \gamma^*)
$$

**Key insight:** The IF for the optimal $\gamma^*$ drops out of the final IF because we're at a stationary point!

---

## Step 5: Complete Influence Function for $\phi^*(\lambda_w)$

Combining all steps, for observation $\ell$:

$$
\boxed{
\text{IF}_{\phi^*}(O_\ell) = \frac{1}{n} \sum_{j=1}^n w_\ell^j(\gamma^*) \cdot \text{IF}_{h_\ell}(O_\ell)
}
$$

where:

$$
w_\ell^j(\gamma^*) = \frac{\exp(-\frac{h_\ell + \gamma^* C[\ell,j]}{\tau})}{\sum_{i=1}^n \exp(-\frac{h_i + \gamma^* C[i,j]}{\tau})}
$$

and:

$$
\text{IF}_{h_\ell}(O_\ell) = \tau_S(X_\ell) \cdot \text{IF}_{\tau_Y}(O_\ell) + \tau_Y(X_\ell) \cdot \text{IF}_{\tau_S}(O_\ell)
$$

**Computational algorithm:**

1. Compute optimal $\gamma^*$ by maximizing $g_\tau(\gamma)$ numerically
2. At $\gamma^*$, compute softmax weight matrix $W$ where $W[\ell,j] = w_\ell^j(\gamma^*)$
3. For each observation $\ell$:
   - Compute $\text{IF}_{h_\ell}(O_\ell)$ using treatment effect IFs
   - Compute $\text{IF}_{\phi^*}(O_\ell) = \frac{1}{n} \sum_j W[\ell,j] \cdot \text{IF}_{h_\ell}(O_\ell)$
4. Center: $\text{IF}_{\phi^*}(O_\ell) \leftarrow \text{IF}_{\phi^*}(O_\ell) - \frac{1}{n}\sum_{\ell=1}^n \text{IF}_{\phi^*}(O_\ell)$

---

## Key Properties

### Property 1: Mean Zero

$$
\mathbb{E}_n[\text{IF}_{\phi^*}(O)] = 0
$$

**Proof:** By centering in Step 4, and because each component IF has mean zero.

### Property 2: Variance Formula

$$
\sigma^2 = \text{Var}[\text{IF}_{\phi^*}(O)] = \mathbb{E}[\text{IF}_{\phi^*}(O)^2]
$$

Estimated by:

$$
\hat{\sigma}^2 = \frac{1}{n} \sum_{\ell=1}^n \text{IF}_{\phi^*}(O_\ell)^2
$$

### Property 3: Asymptotic Normality

Under regularity conditions:

$$
\sqrt{n}(\hat{\phi}^* - \phi^*) \xrightarrow{d} N(0, \sigma^2)
$$

### Property 4: Valid Confidence Intervals

$$
\text{CI}_{1-\alpha} = \hat{\phi}^* \pm z_{\alpha/2} \cdot \frac{\hat{\sigma}}{\sqrt{n}}
$$

has asymptotic coverage $1-\alpha$.

---

## Comparison: Type-Based vs Observation-Level

### Type-Based (Discretized) IF:

$$
\text{IF}_{\phi^*}(O_\ell) = \sum_{j=1}^J p_0^j \sum_{k=1}^J w_k^j(\gamma^*) \cdot \frac{\mathbb{1}(O_\ell \in \text{type } k)}{\pi_k} \cdot \text{IF}_{h_k}^{\text{type}}(O_\ell)
$$

**Issues:**
- Division by $\pi_k$ can inflate variance when types are small
- Discretization introduces approximation error
- Type-level concordances $h_k$ are averages, losing individual variation

### Observation-Level (Continuous) IF:

$$
\text{IF}_{\phi^*}(O_\ell) = \frac{1}{n} \sum_{j=1}^n w_\ell^j(\gamma^*) \cdot \text{IF}_{h_\ell}(O_\ell)
$$

**Advantages:**
- No discretization error
- No small-sample type problems
- Direct observation-level variation
- Cleaner theoretical properties

**Trade-off:** $n \times n$ cost matrix instead of $J \times J$ (computational cost scales as $O(n^2)$ vs $O(J^2)$).

---

## Connection to Wasserstein DRO

This observation-level IF corresponds to the smoothed dual of:

$$
\inf_{\mathbb{Q}: W_2(\mathbb{P}_n, \mathbb{Q}) \leq \lambda_w} \mathbb{E}_{\mathbb{Q}}[h(X)]
$$

where:
- $\mathbb{P}_n$ is the empirical distribution (equal weight $1/n$ on each observation)
- $W_2$ is the 2-Wasserstein distance based on cost $C[i,j] = (X_i - X_j)^2$
- $h(X) = \tau_S(X) \times \tau_Y(X)$ is the concordance function

The smoothing parameter $\tau$ makes this a **smooth approximation** to the exact dual, enabling well-defined influence function derivation.

---

## Regularity Conditions

For asymptotic validity, we require:

1. **Boundedness:** $|h_i| \leq M < \infty$ for all $i$
2. **Lipschitz continuity:** Treatment effects $\tau_S(X)$, $\tau_Y(X)$ are Lipschitz in $X$
3. **Moment conditions:** $\mathbb{E}[S^2], \mathbb{E}[Y^2] < \infty$
4. **Propensity overlap:** $0 < c \leq e(X) \leq 1-c < 1$
5. **Smoothing:** $\tau > 0$ fixed (or $\tau \to 0$ at rate slower than $n^{-1/4}$)
6. **Wasserstein radius:** $\lambda_w$ fixed and positive

Under these conditions:
- $\hat{\phi}^* \xrightarrow{p} \phi^*$ (consistency)
- $\sqrt{n}(\hat{\phi}^* - \phi^*) \xrightarrow{d} N(0, \sigma^2)$ (asymptotic normality)
- $\hat{\sigma}^2 \xrightarrow{p} \sigma^2$ (variance consistency)

---

## Computational Complexity

**Per-iteration cost:**
- Compute $g_\tau(\gamma)$: $O(n^2)$ (evaluate cost matrix and softmax for each $j$)
- Compute $\gamma^*$: $O(K \cdot n^2)$ where $K$ is number of optimization iterations (typically $K \approx 20-50$)
- Compute softmax weights: $O(n^2)$
- Compute all IFs: $O(n^2)$

**Total:** $O(n^2)$

**Practical limits:**
- $n = 500$: Fast (< 1 second)
- $n = 1000$: Moderate (few seconds)
- $n = 5000$: Slow (minutes)
- $n > 10000$: May require optimization (sparse matrices, subsampling)

For very large $n$, consider:
- Mini-batch approximations
- Random feature approximations
- Type-based discretization as a fast approximation

---

## Implementation Verification Checklist

To verify the IF implementation is correct:

1. **Mean zero test:** $|\bar{\text{IF}}| < 10^{-6}$ (after centering)
2. **Coverage test:** Empirical coverage $\approx 95\%$ over many simulations
3. **Variance consistency:** $\frac{\hat{\sigma}_{\text{IF}}}{\hat{\sigma}_{\text{empirical}}} \approx 1.0$ (ratio near 1)
4. **Robustness:** Check across different $\lambda_w$, $\tau$, sample sizes
5. **Oracle test:** With oracle nuisances, should have near-perfect properties

All five tests must pass for the IF to be considered correct.

---

## Summary

The observation-level EIF provides:

✅ **No discretization error** (uses all $n$ observations directly)
✅ **Well-defined IF** (smooth dual enables pathwise derivatives)
✅ **Mean-zero property** (by construction with centering)
✅ **Valid inference** (asymptotic normality under regularity conditions)
✅ **Computational tractability** (for moderate $n \leq 5000$)

The key theoretical innovation is using **smooth approximation** to the hard minimum, which:
- Eliminates selection bias
- Enables influence function derivation
- Preserves asymptotic properties
- Converges to exact solution as $\tau \to 0$

This provides a **theoretically rigorous** path to inference for minimax concordance under Wasserstein ambiguity.
