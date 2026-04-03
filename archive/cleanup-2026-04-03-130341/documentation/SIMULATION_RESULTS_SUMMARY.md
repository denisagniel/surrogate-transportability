# Simulation Studies Results Summary

**Generated:** 2026-03-30 10:31:54.829198
**Host:** login06.o2.rc.hms.harvard.edu

---

## Study 1: Finite Sample Performance

- **Total replications:** 24000
- **Settings:** 48
- **Overall success rate:** 100.0%

### Overall Performance

- **Mean bias:** -0.0305
- **Mean RMSE:** 0.0345
- **Mean coverage:** 0.644

### Coverage by Sample Size

- n=250: 0.641
- n=500: 0.645
- n=1000: 0.657
- n=2000: 0.631

### Best/Worst Settings

- **Best:** n=1000, low_het_high_cor, λ=0.1 (coverage=0.880)
- **Worst:** n=250, low_het_high_cor, λ=0.4 (coverage=0.292)

## Study 2: Stress Testing

- **Total replications:** 10500
- **Conditions:** 21
- **Overall success rate:** 93.7%

### By Stress Type

- **discretization:** 6 conditions, coverage 0.569 (min 0.557)
- **extreme_lambda:** 4 conditions, coverage 0.581 (min 0.548)
- **high_heterogeneity:** 4 conditions, coverage 0.265 (min 0.222)
- **small_sample:** 3 conditions, coverage 0.638 (min 0.572)
- **weak_signal:** 4 conditions, coverage 0.884 (min 0.846)

### Conditions with Coverage < 93%

Found 20 stressed condition(s):

- **high_heterogeneity:** n=500, λ=0.3, J=16, ρ=0.70, CV=0.9 → coverage=0.222
- **high_heterogeneity:** n=500, λ=0.3, J=16, ρ=0.70, CV=0.8 → coverage=0.236
- **high_heterogeneity:** n=500, λ=0.3, J=16, ρ=0.70, CV=0.7 → coverage=0.278
- **high_heterogeneity:** n=500, λ=0.3, J=16, ρ=0.70, CV=0.6 → coverage=0.322
- **extreme_lambda:** n=500, λ=0.6, J=16, ρ=0.70, CV=0.3 → coverage=0.548

---

## Files

- `sims/results/finite_sample_results.rds` (aggregated Study 1)
- `sims/results/stress_test_results.rds` (aggregated Study 2)

