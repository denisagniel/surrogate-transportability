# Understanding the Wasserstein Dual Estimand

**Question:** What is the "something that looks like an expected value" in the dual, and what is its influence function?

---

## The Population-Level Wasserstein Dual

The Wasserstein dual (Esfahani & Kuhn 2018) is:

$$
\phi^*(\lambda_w) = \sup_{\gamma \geq 0} \left\{ -\gamma \lambda_w^2 + \mathbb{E}_{X \sim P_0}[\phi_\tau(\gamma; X)] \right\}
$$

where for each reference covariate value $X$:

$$
\phi_\tau(\gamma; X) = -\tau \log \mathbb{E}_{X' \sim P_0}\left[\exp\left(-\frac{h(X') + \gamma C(X', X)}{\tau}\right)\right]
$$

**Key structure:**
1. **Outer expectation:** $\mathbb{E}_{X \sim P_0}[\cdot]$ — average over reference distribution
2. **Inner smooth minimum:** The log-exp expression is a smooth min over the target distribution

---

## What is "That Thing That Looks Like an Expected Value"?

It's:

$$
\boxed{
\Psi(\gamma) = \mathbb{E}_{X \sim P_0}[\phi_\tau(\gamma; X)]
}
$$

This is a **population expectation** of a functional that itself involves expectations.

**Expanded form:**

$$
\Psi(\gamma) = \mathbb{E}_{X \sim P_0}\left[ -\tau \log \mathbb{E}_{X' \sim P_0}\left[\exp\left(-\frac{h(X') + \gamma C(X', X)}{\tau}\right)\right] \right]
$$

where:
- $h(X') = \tau_S(X') \times \tau_Y(X')$ — concordance function
- $C(X', X) = (X' - X)^2$ — cost function (squared distance)

---

## Two Estimands: The Key Distinction

### Estimand 1: Population Parameter

$$
\Psi(\gamma) = \mathbb{E}_{X \sim P_0}[\phi_\tau(\gamma; X)]
$$

This is a **population parameter** — it exists even without data.

### Estimand 2: Empirical Average (Sample Statistic)

$$
\hat{\Psi}_n(\gamma) = \frac{1}{n} \sum_{j=1}^n \phi_\tau(\gamma; X_j)
$$

This is a **sample statistic** — it's a deterministic function of the observed $X_1, \ldots, X_n$.

---

## The Problem with Observation-Level Approach

In our observation-level code, we computed:

$$
g_\tau(\gamma) = -\gamma \lambda_w^2 + \frac{1}{n} \sum_{j=1}^n \phi_\tau^j(\gamma)
$$

where:

$$
\phi_\tau^j(\gamma) = -\tau \log\left(\frac{1}{n} \sum_{i=1}^n \exp\left(-\frac{h_i + \gamma C[i,j]}{\tau}\right)\right)
$$

**Issue:** Both the outer sum $(1/n)\sum_j$ and inner sum $(1/n)\sum_i$ use the **same empirical distribution**.

This means we're computing:

$$
g_\tau(\gamma) = -\gamma \lambda_w^2 + \hat{\Psi}_n(\gamma)
$$

where $\hat{\Psi}_n(\gamma)$ is a **sample statistic**, not estimating a population parameter.

**With oracle nuisances** (where $h_i = h(X_i)$ are deterministic functions), this becomes a deterministic function of $X_1, \ldots, X_n$ with **no sampling variability** → variance collapses to zero.

---

## Influence Function for $\Psi(\gamma)$ (Population Parameter)

To get a proper IF, we need to target the **population parameter** $\Psi(\gamma)$.

### Step 1: Write as a Statistical Functional

$$
\Psi(\gamma) = \int \phi_\tau(\gamma; x) \, dP_0(x)
$$

where:

$$
\phi_\tau(\gamma; x) = -\tau \log \int \exp\left(-\frac{h(x') + \gamma (x' - x)^2}{\tau}\right) dP_0(x')
$$

### Step 2: Plug-in Estimator

Replace $P_0$ with empirical distribution $\hat{P}_n$:

$$
\hat{\Psi}_n(\gamma) = \int \phi_\tau(\gamma; x) \, d\hat{P}_n(x) = \frac{1}{n} \sum_{j=1}^n \phi_\tau(\gamma; X_j)
$$

where:

$$
\phi_\tau(\gamma; X_j) = -\tau \log \int \exp\left(-\frac{h(x') + \gamma (x' - X_j)^2}{\tau}\right) d\hat{P}_n(x')
$$

$$
= -\tau \log\left(\frac{1}{n} \sum_{i=1}^n \exp\left(-\frac{h(X_i) + \gamma (X_i - X_j)^2}{\tau}\right)\right)
$$

### Step 3: Now h(X) is a Statistical Functional

The key is that $h(X) = \tau_S(X) \times \tau_Y(X)$ is **itself estimated from data**, not observed directly.

$$
h(X) = \tau_S(X) \times \tau_Y(X)
$$

where $\tau_S(X) = \mathbb{E}[S \mid A=1, X] - \mathbb{E}[S \mid A=0, X]$ (and similarly for $\tau_Y$).

These are estimated via regression, so they have their own influence functions.

---

## The Complete Influence Function Structure

For the population parameter $\Psi(\gamma)$, the IF has **two sources of variability**:

### Source 1: Sampling X from P₀

The outer expectation $\mathbb{E}_{X \sim P_0}[\phi_\tau(\gamma; X)]$ is estimated by:

$$
\frac{1}{n} \sum_{j=1}^n \phi_\tau(\gamma; X_j)
$$

**Von Mises expansion:** For observation $\ell$,

$$
\text{IF}_{\text{avg}}(O_\ell; \gamma) = \phi_\tau(\gamma; X_\ell) - \mathbb{E}_{P_0}[\phi_\tau(\gamma; X)]
$$

This captures variability in which $X$ values we observe.

### Source 2: Estimating h(X) = τ_S(X) × τ_Y(X)

Each $\phi_\tau(\gamma; X_j)$ depends on $h(X_i)$ for all $i$:

$$
\phi_\tau(\gamma; X_j) = -\tau \log\left(\frac{1}{n} \sum_{i=1}^n \exp\left(-\frac{h(X_i) + \gamma C[i,j]}{\tau}\right)\right)
$$

**Chain rule:** For observation $\ell$,

$$
\frac{\partial \phi_\tau(\gamma; X_j)}{\partial h(X_\ell)} = w_\ell^j(\gamma)
$$

where $w_\ell^j(\gamma)$ is the softmax weight.

So changes in $h(X_\ell)$ propagate through all $\phi_\tau(\gamma; X_j)$.

---

## The Complete IF Formula

Combining both sources:

$$
\text{IF}_{\Psi}(O_\ell; \gamma) = \underbrace{\phi_\tau(\gamma; X_\ell) - \Psi(\gamma)}_{\text{Source 1: sampling X}} + \underbrace{\frac{1}{n} \sum_{j=1}^n w_\ell^j(\gamma) \cdot \text{IF}_{h(X_\ell)}(O_\ell)}_{\text{Source 2: estimating h}}
$$

Wait — this doesn't look right. Let me reconsider...

---

## Actually: The Proper Target

The issue is that when we estimate $\Psi(\gamma)$ by:

$$
\hat{\Psi}_n(\gamma) = \frac{1}{n} \sum_{j=1}^n \phi_\tau(\gamma; X_j)
$$

with:

$$
\phi_\tau(\gamma; X_j) = -\tau \log\left(\frac{1}{n} \sum_{i=1}^n \exp\left(-\frac{\hat{h}(X_i) + \gamma C[i,j]}{\tau}\right)\right)
$$

We have a **U-statistic-like structure** where:
- The $j$-th term depends on all observations through $\hat{h}(X_i)$
- Each observation appears in two roles: as reference (index $j$) and as target (index $i$)

---

## U-Statistic Perspective

Actually, the estimator has the structure:

$$
\hat{\Psi}_n(\gamma) = \frac{1}{n} \sum_{j=1}^n k_n(\gamma; X_j)
$$

where $k_n(\gamma; X_j)$ is a **data-dependent kernel**:

$$
k_n(\gamma; X_j) = -\tau \log\left(\frac{1}{n} \sum_{i=1}^n \exp\left(-\frac{\hat{h}(X_i) + \gamma C[i,j]}{\tau}\right)\right)
$$

This is **not** a standard U-statistic because the kernel itself depends on all the data.

The IF needs to account for:
1. Which $X_j$ are sampled (outer sum)
2. Which $X_i$ are sampled (inner smooth min)
3. Estimation of $h(X_i)$ for all $i$

---

## Key Insight: Why Type-Based Works

In the **type-based approach**, we have:

$$
\Psi(\gamma) = \sum_{j=1}^J p_0^j \phi_\tau^j(\gamma)
$$

where:
- $p_0^j = P(X \in \text{type } j)$ — type probability (population parameter)
- $\phi_\tau^j(\gamma) = -\tau \log\left(\sum_{k=1}^J \exp\left(-\frac{h_k + \gamma C[k,j]}{\tau}\right)\right)$
- $h_k = \mathbb{E}[\tau_S(X) \times \tau_Y(X) \mid X \in \text{type } k]$ — type-level concordance (population parameter)

Now we estimate:
- $\hat{p}_0^j = n_j / n$ — empirical type frequencies
- $\hat{h}_k$ — sample average within type $k$

Both $p_0^j$ and $h_k$ are **population parameters** with well-defined IFs.

The estimator is:

$$
\hat{\Psi}_n(\gamma) = \sum_{j=1}^J \hat{p}_0^j \phi_\tau^j(\gamma; \hat{h}_1, \ldots, \hat{h}_J)
$$

This is a **smooth functional of finite-dimensional parameters** $(p_0^1, \ldots, p_0^J, h_1, \ldots, h_J)$, each with its own IF.

---

## The Answer

**"That thing that looks like an expected value" is:**

$$
\Psi(\gamma) = \mathbb{E}_{X \sim P_0}[\phi_\tau(\gamma; X)]
$$

**In the type-based parametrization:**

$$
\Psi(\gamma) = \sum_{j=1}^J p_0^j \phi_\tau^j(\gamma)
$$

where $\phi_\tau^j(\gamma)$ is a function of $(h_1, \ldots, h_J)$.

**Its influence function comes from two sources:**

1. **Estimation of $p_0^j$:**
   $$\text{IF}_{p_0^j}(O) = \frac{\mathbb{1}(X \in \text{type } j) - p_0^j}{\text{irrelevant normalizer}}$$

2. **Estimation of $h_k$:**
   $$\text{IF}_{h_k}(O) = \frac{\mathbb{1}(X \in \text{type } k)}{\pi_k} \cdot [\tau_S^k \cdot \text{IF}_{\tau_Y}(O) + \tau_Y^k \cdot \text{IF}_{\tau_S}(O)]$$

**Chain rule:**

$$
\text{IF}_{\Psi}(O; \gamma) = \sum_{j=1}^J \left[\phi_\tau^j(\gamma) \cdot \text{IF}_{p_0^j}(O) + \sum_{k=1}^J \frac{\partial \phi_\tau^j}{\partial h_k} \cdot \text{IF}_{h_k}(O) \right]
$$

where:

$$
\frac{\partial \phi_\tau^j}{\partial h_k} = w_k^j(\gamma) = \text{softmax weight}
$$

---

## Summary

The observation-level approach failed because it targeted an **empirical average** (sample statistic) rather than a **population parameter**.

The type-based approach works because it:
1. Discretizes into types
2. Estimates population parameters $(p_0^j, h_k)$
3. These parameters have proper IFs
4. Chain rule gives IF for $\Psi(\gamma)$

The 6× variance inflation in the type-based approach suggests an error in how we're combining these IFs (likely the $(1/\pi_k)$ terms or the type probability part), but the **structure is correct**.

We should fix the type-based IF formula, not pursue the observation-level approach.
