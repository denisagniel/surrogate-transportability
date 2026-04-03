# EIF of E[X_i X_j]: Using Same Sample Twice

**Question:** What's the EIF when we estimate $\mathbb{E}[X_i X_j]$ using the same sample for both $i$ and $j$?

---

## The Population Parameter

If $X_1, X_2$ are **independent** draws from $P_0$:

$$\theta = \mathbb{E}[X_1 X_2] = \mathbb{E}[X_1] \mathbb{E}[X_2] = \mu^2$$

where $\mu = \mathbb{E}[X]$.

---

## The Estimator (Same Sample)

Using sample $X_1, \ldots, X_n$:

$$\hat{\theta} = \frac{1}{n^2} \sum_{i=1}^n \sum_{j=1}^n X_i X_j = \left(\frac{1}{n}\sum_{i=1}^n X_i\right)^2 = \bar{X}^2$$

Each observation appears in **both roles** (as $i$ and as $j$).

---

## The EIF

By the delta method, for $\theta = \mu^2$:

$$\hat{\theta} = \bar{X}^2$$

$$\text{IF}(x) = \frac{\partial (\bar{X}^2)}{\partial P}(x) = 2\mu(x - \mu)$$

**Verification it has mean zero:**
$$\mathbb{E}[\text{IF}(X)] = 2\mu \mathbb{E}[X - \mu] = 0 \quad \checkmark$$

**Variance:**
$$\text{Var}[\text{IF}(X)] = 4\mu^2 \text{Var}[X] = 4\mu^2 \sigma^2$$

**Asymptotic distribution:**
$$\sqrt{n}(\bar{X}^2 - \mu^2) \xrightarrow{d} N(0, 4\mu^2\sigma^2)$$

---

## Key Insight: Not a Simple Nested Expectation

If we **naively** treated this as:
$$\hat{\theta} = \mathbb{E}_{\text{outer}}[\mathbb{E}_{\text{inner}}[X_i X_j]]$$

with **independent** outer and inner samples, the IF would be different!

**With independent samples:**
- Outer sample for $i$: $X_1^{(1)}, \ldots, X_n^{(1)}$
- Inner sample for $j$: $X_1^{(2)}, \ldots, X_m^{(2)}$

Estimator:
$$\hat{\theta}_{\text{indep}} = \frac{1}{n} \sum_{i=1}^n \left(\frac{1}{m}\sum_{j=1}^m X_i^{(1)} X_j^{(2)}\right) = \bar{X}^{(1)} \cdot \bar{X}^{(2)}$$

IF for observation $k$ in sample 1:
$$\text{IF}^{(1)}(x) = \mu(x - \mu)$$

IF for observation $k$ in sample 2:
$$\text{IF}^{(2)}(x) = \mu(x - \mu)$$

Total variance: $\frac{\mu^2\sigma^2}{n} + \frac{\mu^2\sigma^2}{m}$

---

## Comparison: Same Sample vs Independent Samples

### Same Sample (What We Actually Do)

$$\hat{\theta} = \bar{X}^2$$

IF: $\text{IF}(x) = 2\mu(x - \mu)$

Variance: $\frac{4\mu^2\sigma^2}{n}$

### Independent Samples (What Naive IF Assumes)

$$\hat{\theta}_{\text{indep}} = \bar{X}^{(1)} \cdot \bar{X}^{(2)}$$

IF: $\text{IF}^{(1)}(x) = \mu(x - \mu)$ and $\text{IF}^{(2)}(x) = \mu(x - \mu)$

Total variance: $\frac{2\mu^2\sigma^2}{n}$ (if $n = m$)

---

## The Factor of 2

Using the **same sample twice** gives variance that is **2× larger** than using independent samples!

This is because each observation $X_k$ appears in:
- The outer sum (as $i = k$)
- The inner sum for **all** $j$ (including $j = k$)

This creates **covariance** between terms that doesn't exist with independent samples.

---

## Application to Our Problem

In our Wasserstein dual:

$$\hat{\Psi}_n = \frac{1}{n}\sum_{j=1}^n \phi_\tau(\gamma; X_j)$$

where:

$$\phi_\tau(\gamma; X_j) = -\tau \log\left(\frac{1}{n}\sum_{i=1}^n g(X_i, X_j)\right)$$

We use the **same sample** $\{X_1, \ldots, X_n\}$ for both:
- Reference points (index $j$)
- Target points (index $i$)

The IF formula I derived treated these as **independent**, which is why:
- Variance is too small (by a factor related to how much covariance we're missing)
- Coverage fails (CIs too narrow)

---

## The Correct Approach

For U-statistics or "same sample used twice" structures, we need to account for:

1. **Direct effect**: Observation $k$ as reference point (outer sum)
2. **Indirect effect**: Observation $k$ affecting all other reference points (inner sum)
3. **Covariance**: Between these two effects

The U-statistic IF formula accounts for this. For a symmetric kernel $h(X_i, X_j)$:

$$\text{IF}(x) = 2\left[\mathbb{E}[h(x, X)] - \theta\right]$$

The factor of 2 comes from the observation appearing in both positions.

For our (non-symmetric) nested structure, we need a similar correction that accounts for each observation's **dual role**.

---

## Next Steps

We need to derive the IF for:

$$\hat{\Psi}_n = \frac{1}{n}\sum_{j=1}^n f_n(X_j)$$

where $f_n(x) = -\tau \log\left(\frac{1}{n}\sum_{i=1}^n g(x, X_i)\right)$ depends on the **full sample**.

This is not a standard U-statistic, but has similar structure - each observation affects both:
- Its own term $f_n(X_k)$
- All other terms $f_n(X_j)$ for $j \neq k$ (through the inner sum)

The correct IF must account for both pathways.
