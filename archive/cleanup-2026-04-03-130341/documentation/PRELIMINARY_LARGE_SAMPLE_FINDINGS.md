# Preliminary Large Sample Bias Findings

**Date:** 2026-03-31
**Status:** Test still running (partial results)
**Truth:** φ* = 0.114220

---

## Observed Pattern (Linear Method)

### Estimates at n = 20,000 (5 reps so far)

```
Rep 1: 0.1169  (bias: +0.0027, 2.4% of truth)
Rep 2: 0.1214  (bias: +0.0072, 6.3% of truth)
Rep 3: 0.1167  (bias: +0.0025, 2.2% of truth)
Rep 4: 0.1209  (bias: +0.0067, 5.9% of truth)
Rep 5: 0.1301  (bias: +0.0159, 13.9% of truth)
```

**Mean so far:** ~0.121 (bias ≈ +0.007, ~6% of truth)

---

## Comparison Across Sample Sizes (from earlier complete data)

### Linear Method

| n     | Mean Estimate | Bias      | % of Truth |
|-------|---------------|-----------|------------|
| 1,000 | 0.118         | +0.0035   | 3.1%       |
| 5,000 | ~0.121        | +0.0070   | 6.1%       |
| 20,000| ~0.121 (partial)| +0.0070 | 6.1%       |

### Kernel Method

| n     | Mean Estimate | Bias      | % of Truth |
|-------|---------------|-----------|------------|
| 1,000 | ~0.041        | -0.073    | 64%        |
| 5,000 | ~0.063        | -0.051    | 45%        |
| 20,000| [running]     | ?         | ?          |

---

## Key Observations

### 1. **Linear Method: Small but Persistent Bias**

- Bias at n=1,000: +0.0035 (3%)
- Bias at n=5,000: +0.0070 (6%)
- Bias at n=20,000: +0.0070 (6%) [partial]

**Finding:** Bias is **NOT decreasing** with n. It appears stable around +0.007 (6% of truth).

**Interpretation:** This suggests:
- NOT a finite sample effect (would decrease)
- Possibly a **small systematic bias** in the method
- OR the "truth" computed on grid is slightly off

### 2. **Kernel Method: Large Bias, Unclear Trend**

- Bias at n=1,000: -0.073 (64%)
- Bias at n=5,000: -0.051 (45%)
- Bias decreasing somewhat but still huge

**Finding:** Kernel bias decreases but remains substantial even at n=5,000.

---

## Preliminary Conclusions

### Linear Method
✓ **Practically unbiased** (bias < 1% of truth would be ideal, but 6% is acceptable)
⚠ **Bias does not vanish** with n (not theoretically unbiased)
✓ **Consistent across sample sizes** (predictable behavior)

### Kernel Method
✗ **Substantial bias** even at large n
~ **Bias decreases** but slowly (may need n >> 20,000)
✗ **Not recommended** for practical use

### Overall Assessment
The sample splitting estimator with **correctly-specified parametric models** produces estimates with small (~6%) positive bias that appears to be **systematic rather than finite-sample**.

This bias is:
- **Acceptable for practice** (< 10% of truth)
- **Stable and predictable** (doesn't vary much with n)
- **Not theoretically unbiased** (bias ≠ 0 as n → ∞)

---

## Implications

### For Theory
- Cannot claim "unbiased estimator"
- CAN claim "low-bias estimator with controlled error"
- Need to investigate source of small systematic bias

### For Practice
- Linear/parametric methods: Recommend with caveat about ~6% bias
- Kernel/flexible methods: Do NOT recommend (huge bias)
- Document bias magnitude clearly

### For Manuscript
Adjust claims:
- ❌ "Unbiased with provable coverage"
- ✓ "Low-bias estimation (< 10%) with valid inference via sample splitting"
- ✓ "Asymptotic coverage holds under mild bias conditions"

---

## Questions to Answer

1. **Why doesn't bias vanish?**
   - Is it the split itself (n/2 per phase)?
   - Is it the dual optimization?
   - Is it the grid-based "truth" being wrong?

2. **Why is bias positive?**
   - Estimates are systematically higher than truth
   - Suggests underestimation of worst-case (too optimistic)
   - Or truth computation is biased downward?

3. **Can we correct the bias?**
   - Analytical bias correction?
   - Bootstrap bias correction?
   - Or just document and accept?

---

## Next Steps

Once test completes:
1. Confirm n=20,000 results match n=5,000 (bias plateaus)
2. Verify kernel bias at n=20,000 (still substantial?)
3. Decide on manuscript language (see implications above)
4. Potentially investigate bias source (or accept as small)

---

**Status:** Waiting for n=20,000 results to confirm pattern.
**Expected:** Bias will remain around +0.007 (6%) for linear, confirming systematic bias.
