# Correct EIF Derivation for Nested Expectation

**Estimand:**
$$\Psi(\mathcal{P}) = \int \phi_\tau(x; \mathcal{P}) \, d\mathcal{P}(x)$$

where:
$$\phi_\tau(x; \mathcal{P}) = -\tau \log \int g(x, x') \, d\mathcal{P}(x')$$

and:
$$g(x, x'; \gamma) = \exp\left(-\frac{h(x') + \gamma(x' - x)^2}{\tau}\right)$$

The distribution $\mathcal{P}$ appears **twice**: outer integral (reference $x$) and inner integral (target $x'$).

---

## Gâteaux Derivative Derivation

Along parametric path $\mathcal{P}_t = t\hat{\mathcal{P}} + (1-t)\mathcal{P}$:

$$\Psi(\mathcal{P}_t) = \int \phi_\tau(x; \mathcal{P}_t) \, d\mathcal{P}_t(x)$$

Taking derivative at $t=0$ using **product rule** (since $\mathcal{P}_t$ appears in both places):

$$\frac{d\Psi(\mathcal{P}_t)}{dt}\bigg|_{t=0} = \underbrace{\int \frac{\partial \phi_\tau(x; \mathcal{P}_t)}{\partial t}\bigg|_{t=0} d\mathcal{P}(x)}_{\text{Term 1: inner integral}} + \underbrace{\int \phi_\tau(x; \mathcal{P}) \, d(\hat{\mathcal{P}} - \mathcal{P})(x)}_{\text{Term 2: outer integral}}$$

---

## Term 1: Derivative of Inner Functional

For fixed reference point $x$:
$$\phi_\tau(x; \mathcal{P}_t) = -\tau \log \int g(x, x') \, d\mathcal{P}_t(x')$$

Define $m(x) = \int g(x, x') \, d\mathcal{P}(x')$. Then:

$$\phi_\tau(x; \mathcal{P}_t) = -\tau \log m_t(x)$$

where $m_t(x) = \int g(x, x') \, d\mathcal{P}_t(x')$.

Taking derivative:
$$\frac{\partial \phi_\tau(x; \mathcal{P}_t)}{\partial t}\bigg|_{t=0} = -\tau \frac{1}{m(x)} \frac{\partial m_t(x)}{\partial t}\bigg|_{t=0}$$

Now:
$$\frac{\partial m_t(x)}{\partial t}\bigg|_{t=0} = \int g(x, x') \, d(\hat{\mathcal{P}} - \mathcal{P})(x')$$

For point mass at observation $o$:
$$\int g(x, x') \, d(\hat{\mathcal{P}} - \mathcal{P})(x') = g(x, o) - m(x)$$

Therefore:
$$\frac{\partial \phi_\tau(x; \mathcal{P}_t)}{\partial t}\bigg|_{t=0} = -\tau \frac{g(x, o) - m(x)}{m(x)} = -\tau\left(\frac{g(x, o)}{m(x)} - 1\right)$$

Integrating over $x$ with respect to $\mathcal{P}$:
$$\text{Term 1} = \int \left[-\tau\left(\frac{g(x, o)}{m(x)} - 1\right)\right] d\mathcal{P}(x)$$

$$= -\tau \int \frac{g(x, o)}{m(x)} \, d\mathcal{P}(x) + \tau$$

---

## Term 2: Derivative of Outer Integral

$$\text{Term 2} = \int \phi_\tau(x; \mathcal{P}) \, d(\hat{\mathcal{P}} - \mathcal{P})(x)$$

For point mass at observation $o$:
$$= \phi_\tau(o; \mathcal{P}) - \int \phi_\tau(x; \mathcal{P}) \, d\mathcal{P}(x)$$

$$= \phi_\tau(o; \mathcal{P}) - \Psi(\mathcal{P})$$

$$= -\tau \log m(o) - \Psi(\mathcal{P})$$

---

## Complete Efficient Influence Function

Combining both terms:

$$\boxed{
\phi(o, \mathcal{P}) = \underbrace{-\tau \log m(o) - \Psi(\mathcal{P})}_{\text{outer: } o \text{ as reference}} + \underbrace{-\tau \int \frac{g(x, o)}{m(x)} \, d\mathcal{P}(x) + \tau}_{\text{inner: } o \text{ in expectations}}
}$$

where:
- $m(x) = \int g(x, x') \, d\mathcal{P}(x')$
- $g(x, x') = \exp(-\frac{h(x') + \gamma(x'-x)^2}{\tau})$

---

## Two Contributions

**Outer contribution** (observation $o$ as reference point $x$):
- $-\tau \log m(o)$: How observation $o$ directly enters the estimand
- $-\Psi(\mathcal{P})$: Centering

**Inner contribution** (observation $o$ in inner expectations):
- Observation $o$ affects **all** reference points $x$ through their inner expectations $m(x)$
- Weighted by how much $o$ contributes to each $m(x)$: weight is $\frac{g(x,o)}{m(x)}$
- The $+\tau$ ensures mean zero

---

## Mean Zero Property

To verify $\mathbb{E}_{\mathcal{P}}[\phi(O, \mathcal{P})] = 0$:

**Outer term:**
$$\mathbb{E}\left[-\tau \log m(O) - \Psi(\mathcal{P})\right] = \int [-\tau \log m(x)] d\mathcal{P}(x) - \Psi(\mathcal{P}) = \Psi(\mathcal{P}) - \Psi(\mathcal{P}) = 0$$

**Inner term:**
$$\mathbb{E}\left[-\tau \int \frac{g(X, O)}{m(X)} d\mathcal{P}(x) + \tau\right]$$

$$= -\tau \int \frac{1}{m(x)} \mathbb{E}_O[g(x, O)] d\mathcal{P}(x) + \tau$$

$$= -\tau \int \frac{1}{m(x)} \int g(x, o) d\mathcal{P}(o) d\mathcal{P}(x) + \tau$$

$$= -\tau \int \frac{m(x)}{m(x)} d\mathcal{P}(x) + \tau = -\tau + \tau = 0$$

Both terms have mean zero. ✓

---

## Sample-Level Implementation

For sample $\{X_1, \ldots, X_n\}$, replace $\mathcal{P}$ with empirical $\hat{\mathcal{P}}_n = \frac{1}{n}\sum_{i=1}^n \delta_{X_i}$:

$$m(x) \approx \hat{m}_n(x) = \frac{1}{n}\sum_{i=1}^n g(x, X_i)$$

$$\Psi(\mathcal{P}) \approx \hat{\Psi}_n = \frac{1}{n}\sum_{j=1}^n [-\tau \log \hat{m}_n(X_j)]$$

For observation $k$:

$$\phi(X_k, \hat{\mathcal{P}}_n) = \left[-\tau \log \hat{m}_n(X_k) - \hat{\Psi}_n\right] + \left[-\tau \frac{1}{n}\sum_{j=1}^n \frac{g(X_j, X_k)}{\hat{m}_n(X_j)} + \tau\right]$$

---

## Key Insight: Why My Earlier Derivation Failed

My earlier "nested expectation" derivation treated the inner expectation as if it were **independent** from the outer one. 

**Wrong approach:** Treated as $\mathbb{E}_X[\mathbb{E}_{X'}[\cdot]]$ with independent samples.

**Correct approach:** Both expectations use **same distribution** $\mathcal{P}$, so when we perturb $\mathcal{P}$, we get contributions from **both** pathways via the product rule.

This is exactly analogous to $\mathbb{E}[X_i X_j]$ where the factor of 2 came from both integrals contributing.

---

## Computational Algorithm

1. Compute $\hat{m}_n(X_j)$ for all $j = 1, \ldots, n$
2. Compute $\hat{\Psi}_n = \frac{1}{n}\sum_j [-\tau \log \hat{m}_n(X_j)]$
3. For each observation $k$:
   - Outer term: $-\tau \log \hat{m}_n(X_k) - \hat{\Psi}_n$
   - Inner term: $-\tau \frac{1}{n}\sum_j \frac{g(X_j, X_k)}{\hat{m}_n(X_j)} + \tau$
   - Total: sum both terms
4. Verify: $\frac{1}{n}\sum_k \phi(X_k) \approx 0$

This is the correct IF that accounts for the same sample being used twice.
