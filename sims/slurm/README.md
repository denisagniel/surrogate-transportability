# SLURM Validation Studies

This directory contains SLURM batch scripts for running validation studies on HPC clusters.

## Overview

Each validation study runs 1000 replications × N scenarios as independent SLURM array jobs. Results from individual replications are saved to separate files, then aggregated afterward.

**Advantages:**
- Embarrassingly parallel (no communication between tasks)
- Fault-tolerant (failed jobs can be rerun individually)
- No inner parallelization overhead
- Standard SLURM pattern

## Files

- `covariate_shift_validation.slurm` - Main batch script for covariate shift validation
- `submit_all_covariate_shift.sh` - Helper to submit all 4 scenarios
- `README.md` - This file

## Quick Start

### 1. Test Locally

Before submitting to SLURM, test the workflow locally:

```bash
cd /path/to/surrogate-transportability
bash sims/scripts/test_slurm_workflow.sh
```

This runs 5 replications with reduced parameters (~30 seconds) and aggregates results.

### 2. Adjust SLURM Parameters

Edit `covariate_shift_validation.slurm` to match your cluster:

```bash
#SBATCH --partition=short        # Your partition name
#SBATCH --time=00:30:00          # Adjust based on timing tests
#SBATCH --mem=4G                 # Adjust if needed
module load R/4.5.0              # Your R module
```

### 3. Submit Jobs

Submit all covariate shift scenarios:

```bash
cd /path/to/surrogate-transportability
bash sims/slurm/submit_all_covariate_shift.sh
```

Or submit individual scenarios:

```bash
sbatch --export=SCENARIO=small sims/slurm/covariate_shift_validation.slurm
sbatch --export=SCENARIO=moderate sims/slurm/covariate_shift_validation.slurm
sbatch --export=SCENARIO=large sims/slurm/covariate_shift_validation.slurm
sbatch --export=SCENARIO=extreme sims/slurm/covariate_shift_validation.slurm
```

### 4. Monitor Jobs

```bash
# Check job status
squeue -u $USER

# Check specific job
squeue -j <job_id>

# Cancel job
scancel <job_id>

# Cancel all array tasks
scancel <job_id>_[1-1000]
```

### 5. Aggregate Results

Once all jobs complete:

```bash
Rscript sims/scripts/aggregate_results.R \
  --study-type covariate_shift \
  --input-dir sims/results/reps/covariate_shift \
  --output-dir sims/results
```

This creates:
- `covariate_shift_validation_detailed.rds` - All replication data
- `covariate_shift_validation_summary.csv` - Coverage summary by scenario
- `covariate_shift_coverage_by_scenario.png` - Coverage plot
- `covariate_shift_ci_coverage_sample.png` - CI visualization
- `covariate_shift_calibration.png` - True vs estimated φ

## Parameters

Default validation parameters (full scale):

```
--n-baseline 1000            # Baseline sample size
--n-true-studies 500         # Studies for computing TRUE φ(Q)
--n-baseline-resamples 100   # Outer bootstrap for CI
--n-bootstrap 100            # Draws from F_λ
--n-mc-draws 50              # Studies per Q
```

**Total per replication:** 500 + (100 × 100 × 50) = 500,500 study generations

**Estimated time per replication:** ~5-10 minutes (depends on cluster)

**Total compute:** 1000 reps × 4 scenarios × 8 min = ~533 CPU-hours

## Rerunning Failed Jobs

If some replications fail, rerun specific array indices:

```bash
# Rerun replications 100-150 for small scenario
sbatch --export=SCENARIO=small --array=100-150 \
  sims/slurm/covariate_shift_validation.slurm
```

Or identify missing files and rerun:

```bash
# Find missing replications
for REP in {1..1000}; do
  FILE="sims/results/reps/covariate_shift/covariate_shift_small_rep$(printf %04d $REP).rds"
  if [ ! -f "$FILE" ]; then
    echo $REP
  fi
done > missing_reps.txt

# Rerun missing replications
sbatch --export=SCENARIO=small --array=$(cat missing_reps.txt | tr '\n' ',') \
  sims/slurm/covariate_shift_validation.slurm
```

## Troubleshooting

### Out of Memory

Increase `--mem`:

```bash
#SBATCH --mem=8G
```

### Timeout

Increase `--time` or reduce parameters:

```bash
#SBATCH --time=01:00:00
```

Or reduce nested bootstrap:

```bash
--n-baseline-resamples 50   # Instead of 100
--n-bootstrap 50            # Instead of 100
```

### Module Not Found

Adjust module load command:

```bash
module load R/4.3.0  # Or your cluster's R version
```

### Permission Denied

Make scripts executable:

```bash
chmod +x sims/scripts/run_single_replication.R
chmod +x sims/slurm/submit_all_covariate_shift.sh
```

## Extending to Other Studies

### Selection Bias Validation

Copy and modify for selection bias:

```bash
cp sims/slurm/covariate_shift_validation.slurm \
   sims/slurm/selection_bias_validation.slurm

# Edit to change:
# - Job name
# - --study-type selection_bias
# - SCENARIO values (weak_outcome, moderate_outcome, etc.)
```

### Dirichlet Misspecification

Similar process, with:

```bash
--study-type dirichlet_misspec
--scenario very_sparse  # Or sparse, uniform, concentrated, etc.
```

## Output Structure

```
sims/results/
├── reps/                              # Individual replication results
│   ├── covariate_shift/
│   │   ├── covariate_shift_small_rep0001.rds
│   │   ├── covariate_shift_small_rep0002.rds
│   │   └── ...
│   ├── selection_bias/
│   └── dirichlet_misspec/
├── covariate_shift_validation_detailed.rds
├── covariate_shift_validation_summary.csv
├── covariate_shift_coverage_by_scenario.png
└── ...
```

## Tips

1. **Start small:** Test with `--array=1-10` first
2. **Monitor logs:** Check `logs/covariate_shift_*.out` for progress
3. **Save intermediate:** Individual .rds files allow recovery from failures
4. **Timing tests:** Run 5-10 reps to estimate --time needed
5. **Resource requests:** Start conservative, adjust based on actual usage

## Support

For cluster-specific help, consult your HPC documentation or contact your cluster support team.
