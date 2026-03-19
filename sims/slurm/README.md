# SLURM Validation Studies

This directory contains SLURM batch scripts for running validation studies on HPC clusters.

---

## **HMS O2 Users: Start Here**

**For complete O2 setup instructions, see [README_O2.md](README_O2.md)**

Quick O2 workflow:
```bash
# 1. Clone from GitHub on O2
ssh USERNAME@o2.hms.harvard.edu
git clone https://github.com/denisagniel/surrogate-transportability.git
cd surrogate-transportability

# 2. Setup environment
source sims/slurm/o2_config.sh
R -e "install.packages(c('devtools', 'dplyr', 'tibble', 'optparse', 'ggplot2', 'purrr'))"

# 3. Test (10 reps × 14 scenarios = 140 jobs)
bash sims/slurm/submit_test_run.sh

# 4. Full deployment (14,000 replications)
bash sims/slurm/submit_all_studies.sh
```

**Key O2 features:**
- Uses scratch storage (`/n/scratch3/`) for individual replications
- Uses R/4.5.2 module
- Includes completeness checking and resubmission scripts
- See [README_O2.md](README_O2.md) for file transfer, monitoring, troubleshooting

---

## Overview

Each validation study runs 1,000 replications × N scenarios as independent SLURM array jobs. Results from individual replications are saved to separate files, then aggregated afterward.

**Advantages:**
- Embarrassingly parallel (no communication between tasks)
- Fault-tolerant (failed jobs can be rerun individually)
- No inner parallelization overhead
- Standard SLURM pattern

## Files

**Validation Scripts (Production):**
- `covariate_shift_validation.slurm` - Covariate shift (4 scenarios × 1,000 reps)
- `selection_bias_validation.slurm` - Selection bias (4 scenarios × 1,000 reps)
- `dirichlet_misspecification.slurm` - Dirichlet misspec (6 scenarios × 1,000 reps)
- `test_validation.slurm` - Testing template (10 reps, reduced parameters)

**Submission Helpers:**
- `submit_all_covariate_shift.sh` - Submit covariate shift study
- `submit_all_selection_bias.sh` - Submit selection bias study
- `submit_all_dirichlet_misspec.sh` - Submit Dirichlet misspec study
- `submit_all_studies.sh` - **Master script: submit all three studies**
- `submit_test_run.sh` - Submit test run (140 jobs for quick verification)

**Utilities:**
- `o2_config.sh` - O2 environment configuration (module loading, paths)
- `check_completeness.sh` - Check which replications completed
- `resubmit_failed.sh` - Resubmit specific failed replications

**Documentation:**
- `README.md` - This file (general SLURM guide)
- `README_O2.md` - **Complete HMS O2 guide** (setup, transfer, monitoring)

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

**Total compute (all three studies):**
- Covariate shift: 4,000 reps × 6 min = ~400 CPU-hours
- Selection bias: 4,000 reps × 6 min = ~400 CPU-hours
- Dirichlet misspec: 6,000 reps × 6 min = ~600 CPU-hours
- **Total: ~1,400 CPU-hours**

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
