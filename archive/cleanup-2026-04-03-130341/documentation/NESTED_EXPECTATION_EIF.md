# Influence Function for Nested Expectation

**Question:** What is the EIF for:

$$\Psi = \mathbb{E}_{X} \left[ -\tau \log \mathbb{E}_{X'} [g(X, X')] \right]$$

---

## Setup

Define:
- **Inner expectation:** $m(x) = \mathbb{E}_{X' \sim P_0}[g(x, X')]$
- **Estimand:** $\Psi = \mathbb{E}_{X \sim P_0}[-\tau \log m(X)]$

We use the **same** population distribution $P_0$ for both $X$ and $X'$.

---

## Plug-in Estimator

Replace $P_0$ with empirical distribution $\hat{P}_n = \frac{1}{n}\sum_{i=1}^n \delta_{X_i}$:

$$\hat{m}_n(x) = \frac{1}{n} \sum_{i=1}^n g(x, X_i)$$

$$\hat{\Psi}_n = \frac{1}{n} \sum_{j=1}^n [-\tau \log \hat{m}_n(X_j)]$$

Expanded:
$$\hat{\Psi}_n = \frac{1}{n} \sum_{j=1}^n \left[-\tau \log\left(\frac{1}{n} \sum_{i=1}^n g(X_j, X_i)\right)\right]$$

---

## Von Mises Derivative

The functional is:
$$\Psi[P] = \int \phi_P(x) \, dP(x)$$

where:
$$\phi_P(x) = -\tau \log \int g(x, x') \, dP(x')$$

Consider perturbation $P_\epsilon = (1-\epsilon)P_0 + \epsilon \delta_z$ (mixture with point mass at $z$).

### Step 1: Derivative of $\phi_P(x)$

$$\phi_{P_\epsilon}(x) = -\tau \log \int g(x, x') \, dP_\epsilon(x')$$

$$= -\tau \log\left[(1-\epsilon)\int g(x, x') dP_0(x') + \epsilon \, g(x, z)\right]$$

$$= -\tau \log[(1-\epsilon)m(x) + \epsilon \, g(x, z)]$$

Taking derivative w.r.t. $\epsilon$ and evaluating at $\epsilon = 0$:

$$\frac{\partial \phi_{P_\epsilon}(x)}{\partial \epsilon}\bigg|_{\epsilon=0} = -\tau \cdot \frac{g(x, z) - m(x)}{m(x)}$$

### Step 2: Derivative of Outer Integral

$$\Psi[P_\epsilon] = \int \phi_{P_\epsilon}(x) \, dP_\epsilon(x)$$

Taking derivative:
$$\frac{d\Psi[P_\epsilon]}{d\epsilon}\bigg|_{\epsilon=0} = \int \frac{\partial \phi_{P_\epsilon}(x)}{\partial \epsilon}\bigg|_{\epsilon=0} dP_0(x) + \phi_{P_0}(z) - \Psi$$

**First term (change in $m$ affecting all reference points):**
$$\int \left[-\tau \cdot \frac{g(x, z) - m(x)}{m(x)}\right] dP_0(x) = -\tau \mathbb{E}_X\left[\frac{g(X, z)}{m(X)}\right] + \tau$$

**Second term (z as reference point):**
$$\phi_{P_0}(z) = -\tau \log m(z)$$

**Third term (centering):**
$$-\Psi$$

---

## Complete Influence Function

$$\boxed{
\text{IF}_{\Psi}(z) = -\tau \log m(z) - \tau \mathbb{E}_X\left[\frac{g(X, z)}{m(X)}\right] + \tau - \Psi
}$$

Or equivalently:
$$\text{IF}_{\Psi}(z) = [\phi_{P_0}(z) - \Psi] + \left[-\tau \mathbb{E}_X\left[\frac{g(X, z)}{m(X)}\right] + \tau\right]$$

**Two components:**
1. **$z$ as reference point:** $\phi_{P_0}(z) - \Psi = -\tau \log m(z) - \Psi$
2. **$z$ in inner averages:** $-\tau \mathbb{E}_X\left[\frac{g(X, z)}{m(X)}\right] + \tau$

---

## Mean-Zero Property

To verify $\mathbb{E}_Z[\text{IF}_{\Psi}(Z)] = 0$:

$$\mathbb{E}_Z[\text{IF}_{\Psi}(Z)] = \mathbb{E}[-\tau \log m(Z)] - \tau \mathbb{E}_Z\mathbb{E}_X\left[\frac{g(X, Z)}{m(X)}\right] + \tau - \Psi$$

$$= \Psi - \tau \mathbb{E}_X\mathbb{E}_Z\left[\frac{g(X, Z)}{m(X)}\right] + \tau - \Psi$$

$$= -\tau \mathbb{E}_X\left[\frac{\mathbb{E}_Z[g(X, Z)]}{m(X)}\right] + \tau$$

$$= -\tau \mathbb{E}_X\left[\frac{m(X)}{m(X)}\right] + \tau$$

$$= -\tau + \tau = 0 \quad \checkmark$$

---

## Sample-Level Computation

For observation $k$ in sample $\{X_1, \ldots, X_n\}$:

$$\text{IF}_{\Psi}(X_k) = \underbrace{-\tau \log \hat{m}_n(X_k) - \hat{\Psi}_n}_{\text{reference term}} + \underbrace{-\tau \frac{1}{n}\sum_{j=1}^n \frac{g(X_j, X_k)}{\hat{m}_n(X_j)} + \tau}_{\text{inner average term}}$$

where:
$$\hat{m}_n(X_j) = \frac{1}{n} \sum_{i=1}^n g(X_j, X_i)$$

**Computational steps:**
1. Compute all $\hat{m}_n(X_j)$ for $j = 1, \ldots, n$ (requires $n \times n$ evaluations of $g$)
2. Compute $\hat{\Psi}_n = \frac{1}{n}\sum_{j=1}^n [-\tau \log \hat{m}_n(X_j)]$
3. For each $k$:
   - Reference term: $-\tau \log \hat{m}_n(X_k) - \hat{\Psi}_n$
   - Inner term: $-\tau \frac{1}{n}\sum_{j=1}^n \frac{g(X_j, X_k)}{\hat{m}_n(X_j)} + \tau$
4. Check: $\frac{1}{n}\sum_{k=1}^n \text{IF}_{\Psi}(X_k) \approx 0$

---

## Application to Wasserstein Dual

In our case:
$$g(x, x'; \gamma) = \exp\left(-\frac{h(x') + \gamma (x' - x)^2}{\tau}\right)$$

So:
$$m(x; \gamma) = \mathbb{E}_{X'}\left[\exp\left(-\frac{h(X') + \gamma (X' - x)^2}{\tau}\right)\right]$$

And:
$$\Psi(\gamma) = \mathbb{E}_{X}\left[-\tau \log m(X; \gamma)\right]$$

The IF for $\Psi(\gamma)$ (at fixed $\gamma$) is:

$$\text{IF}_{\Psi}(z; \gamma) = -\tau \log m(z; \gamma) - \tau \mathbb{E}_X\left[\frac{g(X, z; \gamma)}{m(X; \gamma)}\right] + \tau - \Psi(\gamma)$$

**Simplifying the second term:**
$$\mathbb{E}_X\left[\frac{g(X, z; \gamma)}{m(X; \gamma)}\right] = \mathbb{E}_X\left[\frac{\exp(-\frac{h(z) + \gamma(z-X)^2}{\tau})}{m(X; \gamma)}\right]$$

This is a **weighted average** where observation $z$ is weighted by how much it contributes to each reference point $X$'s smooth minimum.

---

## What About Estimating h(x)?

So far we've treated $g(x, x')$ as known. But in practice, $h(x') = \tau_S(x') \times \tau_Y(x')$ must be estimated.

When $h$ is estimated, we get an **additional IF contribution** via the chain rule:

$$\text{IF}_{\Psi, \text{total}}(O_k) = \text{IF}_{\Psi}(X_k) + \text{IF}_{\text{nuisance}}(O_k)$$

where the nuisance term accounts for estimating $h(X_i)$ for all $i$.

**Chain rule for nuisance:**

$$\text{IF}_{\text{nuisance}}(O_k) = \sum_{i=1}^n \frac{\partial \hat{\Psi}_n}{\partial h(X_i)} \cdot \text{IF}_{h(X_i)}(O_k)$$

But $\text{IF}_{h(X_i)}(O_k) = 0$ unless $k = i$ (concordance at $X_i$ only depends on observation $i$).

So:
$$\text{IF}_{\text{nuisance}}(O_k) = \frac{\partial \hat{\Psi}_n}{\partial h(X_k)} \cdot \text{IF}_{h(X_k)}(O_k)$$

---

## Computing $\frac{\partial \hat{\Psi}_n}{\partial h(X_k)}$

$$\hat{\Psi}_n = \frac{1}{n} \sum_{j=1}^n [-\tau \log \hat{m}_n(X_j)]$$

where:
$$\hat{m}_n(X_j) = \frac{1}{n} \sum_{i=1}^n \exp\left(-\frac{h(X_i) + \gamma C[i,j]}{\tau}\right)$$

Taking derivative w.r.t. $h(X_k)$:

$$\frac{\partial \hat{m}_n(X_j)}{\partial h(X_k)} = \frac{1}{n} \cdot \exp\left(-\frac{h(X_k) + \gamma C[k,j]}{\tau}\right) \cdot \left(-\frac{1}{\tau}\right)$$

$$= -\frac{1}{n\tau} \exp\left(-\frac{h(X_k) + \gamma C[k,j]}{\tau}\right)$$

Then:
$$\frac{\partial [-\tau \log \hat{m}_n(X_j)]}{\partial h(X_k)} = -\tau \cdot \frac{1}{\hat{m}_n(X_j)} \cdot \frac{\partial \hat{m}_n(X_j)}{\partial h(X_k)}$$

$$= -\tau \cdot \frac{1}{\hat{m}_n(X_j)} \cdot \left(-\frac{1}{n\tau}\right) \exp\left(-\frac{h(X_k) + \gamma C[k,j]}{\tau}\right)$$

$$= \frac{1}{n} \cdot \frac{\exp(-\frac{h(X_k) + \gamma C[k,j]}{\tau})}{\hat{m}_n(X_j)}$$

This is the **softmax weight** $w_k^j(\gamma)$!

Summing over all $j$:
$$\frac{\partial \hat{\Psi}_n}{\partial h(X_k)} = \frac{1}{n} \sum_{j=1}^n w_k^j(\gamma)$$

---

## Complete IF with Estimated h

$$\boxed{
\text{IF}_{\text{total}}(O_k; \gamma) = \text{IF}_{\Psi}(X_k; \gamma) + \frac{1}{n} \sum_{j=1}^n w_k^j(\gamma) \cdot \text{IF}_{h(X_k)}(O_k)
}$$

where:
- $\text{IF}_{\Psi}(X_k; \gamma)$ is the IF treating $h$ as fixed (formula above)
- $w_k^j(\gamma) = \frac{\exp(-\frac{h(X_k) + \gamma C[k,j]}{\tau})}{\sum_i \exp(-\frac{h(X_i) + \gamma C[i,j]}{\tau})}$ (softmax weights)
- $\text{IF}_{h(X_k)}(O_k) = \tau_S(X_k) \cdot \text{IF}_{\tau_Y}(O_k) + \tau_Y(X_k) \cdot \text{IF}_{\tau_S}(O_k)$

---

## Key Insight

The observation-level approach DOES have a proper IF when $h$ is estimated from data. The variance collapse we saw was because we used **oracle nuisances**, making $h(X_k)$ deterministic.

With estimated $h$:
- The first term $\text{IF}_{\Psi}(X_k)$ captures sampling variability in $X$ values
- The second term $\frac{1}{n}\sum_j w_k^j \cdot \text{IF}_{h(X_k)}$ captures estimation uncertainty in concordances

Both contribute to the total variance!

**Test this:** Re-run observation-level tests with **estimated** (not oracle) nuisances and see if variance becomes proper.
