# Simulation Studies

This directory contains simulation studies for validating the surrogate transportability method.

## Quick Start

### Run a Quick Test (2 minutes)
```bash
Rscript quick_test_covariate_shift.R
```
Runs 50 reps per scenario to verify everything works.

### Run Full Covariate Shift Validation (5-10 minutes)
```bash
Rscript sims/scripts/08_covariate_shift_validation.R
```
Runs 1000 reps across 4 shift scenarios.

### Run All Simulations
```bash
Rscript run_all_simulations.R
```
Interactive runner that executes all simulation studies sequentially.

## Performance

**With influence function method (current):**
- 0.3 seconds per replication
- 1000 reps = ~5 minutes
- **Can run on laptop** ✓

**With nested bootstrap (old):**
- 30-60 minutes per replication
- 1000 reps = 500+ hours
- **Required SLURM cluster**

## Simulation Studies

### 08_covariate_shift_validation.R
Tests inference under pure covariate shift where only P(class) changes.

**Parameters:**
- N_BASELINE: 1000
- N_REPLICATIONS: 1000
- N_INNOVATIONS: 1000
- Scenarios: 4 shift levels (small, moderate, large, extreme)

**Expected coverage:** ~93-95%

**Outputs:**
- `sims/results/covariate_shift_validation_detailed.rds`
- `sims/results/covariate_shift_validation_summary.csv`
- `sims/results/covariate_shift_coverage.png`
- `sims/results/covariate_shift_calibration.png`
- `sims/results/covariate_shift_ci_coverage.png`

## Structure

```
sims/
├── README.md                    # This file
├── classes/                     # R6 simulation classes (if used)
├── config/                      # YAML configuration (if used)
├── scripts/
│   ├── 08_covariate_shift_validation.R  # Main validation script
│   └── ...                      # Other simulation scripts
└── results/                     # Output directory (auto-created)
```

## Method

All simulations now use the **influence function method** (`surrogate_inference_if()`) which implements the delta method from Proposition 1 of the paper.

**Key features:**
- Theoretically grounded (Proposition 1)
- 60-120x faster than nested bootstrap
- Provides 93-95% CI coverage
- Unbiased point estimates

**Technical details:**
- Uses M = 1000 innovations (default)
- Numerical gradient with ε = 0.01
- Fresh innovations at each gradient evaluation point
- Delta method variance: σ²(λ) = (∇H)ᵀ V(λ) (∇H)

## Adding New Simulations

To add a new simulation study:

1. Create script in `sims/scripts/`
2. Use `surrogate_inference_if()` for inference
3. Follow naming convention: `##_descriptive_name.R`
4. Add to `run_all_simulations.R` studies list
5. Document in this README

## SLURM Infrastructure

The old SLURM infrastructure (in `sims/slurm/`) is **no longer needed** with the influence function method. Simulations now run fast enough on a laptop.

If you have extremely large studies (10,000+ reps) or many scenarios to run in parallel, SLURM can still be useful, but it's not required.

## Troubleshooting

**Slow performance?**
- Check that you're using `surrogate_inference_if()` not `posterior_inference()`
- Reduce `n_innovations` to 500 for testing (default: 1000)

**Coverage too low?**
- Small n_reps can give unstable coverage estimates
- Run full 1000 reps for reliable estimates
- Check that scenarios are appropriate for the method

**Out of memory?**
- Reduce `N_BASELINE` or `N_FUTURE`
- Process scenarios sequentially instead of in parallel
- Check for memory leaks in data generation

## Questions?

See session notes in `session_notes/2026-03-23.md` for implementation details and validation results.
