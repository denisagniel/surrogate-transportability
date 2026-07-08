# Quick Start: Lambda Sensitivity Simulations

**Purpose:** Generate Figure 3 for Biometrika paper Section 4.3

---

## TL;DR

```bash
# 1. Quick test (10 min, optional)
Rscript sims/scripts/lambda_sensitivity_local_test.R

# 2. Submit to cluster (28 hrs)
bash cluster/slurm/launch_lambda_sensitivity.sh

# 3. Generate Figure 3 (30 min, after simulations complete)
Rscript sims/scripts/generate_figure3_lambda_sensitivity.R
```

**Total time:** ~29 hours (mostly waiting for cluster)

---

## Option A: Cluster (Recommended)

### Prerequisites
- Access to O2 cluster (Harvard Medical School)
- `surrogateTransportability` package installed
- Modules: `gcc/14.2.0`, `R/4.4.2`

### Step 1: Submit Job
```bash
# From project root on O2
bash cluster/slurm/launch_lambda_sensitivity.sh
```

**What happens:**
- Submits 20 array tasks (one per λ-DGP combination)
- Each task runs 1000 replications
- Runtime: ~1.5 hours per task (parallel execution)
- Total: ~28 hours for all 20,000 simulations

### Step 2: Monitor Progress
```bash
# Check job status
squeue -u ${USER}

# Count completed conditions (should reach 20)
ls -1 cluster/results/lambda_sensitivity/*.rds | wc -l

# Check logs for errors
ls -lt cluster/slurm/logs/lambda_sens_*.out | head -5
tail cluster/slurm/logs/lambda_sens_JOBID_1.out
```

### Step 3: Generate Figure 3
```bash
# After all 20 conditions complete
Rscript sims/scripts/generate_figure3_lambda_sensitivity.R
```

**Output:**
- `inst/paper/figures/figure3_lambda_sensitivity.pdf`
- `inst/paper/figures/figure3_data.rds`

---

## Option B: Local (6 Days)

### Prerequisites
- 8-core machine (or adjust expectations)
- `surrogateTransportability` package installed
- ~140 hours of continuous runtime

### Step 1: Test First
```bash
# Quick test (10 min)
Rscript sims/scripts/lambda_sensitivity_local_test.R
```

### Step 2: Run Full Study Locally
```bash
# This will take ~140 hours on 8 cores
# Consider using screen/tmux for long-running process

# Run one condition at a time
for lambda in 0.1 0.2 0.3 0.4 0.5; do
  for dgp in dgp1 dgp2 dgp4 dgp5; do
    Rscript sims/scripts/lambda_sensitivity_study.R \
      --lambda $lambda \
      --dgp $dgp \
      --n-reps 1000 \
      --output-dir cluster/results/lambda_sensitivity
  done
done
```

**Or parallelize with GNU parallel:**
```bash
# Create job list
for lambda in 0.1 0.2 0.3 0.4 0.5; do
  for dgp in dgp1 dgp2 dgp4 dgp5; do
    echo "$lambda $dgp"
  done
done > jobs.txt

# Run 8 jobs in parallel
cat jobs.txt | parallel -j 8 --colsep ' ' \
  'Rscript sims/scripts/lambda_sensitivity_study.R \
   --lambda {1} --dgp {2} --n-reps 1000 \
   --output-dir cluster/results/lambda_sensitivity'
```

### Step 3: Generate Figure 3
```bash
Rscript sims/scripts/generate_figure3_lambda_sensitivity.R
```

---

## Troubleshooting

### Job fails with "DGP not found"
**Cause:** Config file not found or DGP name mismatch

**Fix:**
```bash
# Verify config exists
ls -l cluster/config/dgp_specifications.yaml

# Check DGP names match exactly
grep "^  dgp[0-9]:" cluster/config/dgp_specifications.yaml
```

### Job runs but no output
**Cause:** Output directory not created or permission issue

**Fix:**
```bash
# Create output directory
mkdir -p cluster/results/lambda_sensitivity

# Check permissions
ls -ld cluster/results/lambda_sensitivity
```

### Package not found on cluster
**Cause:** Package not installed or wrong R version

**Fix:**
```bash
# Load correct R version
module load gcc/14.2.0
module load R/4.4.2

# Install package
R -e "devtools::install()"

# Test
R -e "library(surrogateTransportability)"
```

### Figure 3 generation fails with "Missing files"
**Cause:** Not all 20 conditions completed

**Fix:**
```bash
# Check how many conditions completed
ls -1 cluster/results/lambda_sensitivity/*.rds | wc -l

# Should output: 20
# If less, wait for jobs to complete or check logs for failures
```

---

## Expected Results

### Convergence
- All 20,000 replications should converge
- Mean M ≈ 1500-3000 (adaptive convergence)

### Scientific Insights

**Robust transportability (flat profiles):**
- DGP 1: ρ̂(λ) ≈ 0.69 for all λ
- DGP 4: ρ̂(λ) ≈ 1.00 for all λ
- DGP 5: ρ̂(λ) ≈ 1.00 for all λ

**Fragile transportability (declining):**
- DGP 2: ρ̂(0.1) ≈ -0.88 → ρ̂(0.5) ≈ -0.65

### Statistical Performance
- Bias < 0.01 for all conditions
- Coverage: 93-97%
- SE calibration: empirical ≈ estimated

---

## Verification

After Figure 3 generation, check:

```bash
# Figure exists
ls -lh inst/paper/figures/figure3_lambda_sensitivity.pdf

# All conditions in data
Rscript -e "
  data <- readRDS('inst/paper/figures/figure3_data.rds')
  table(data\$dgp_id, data\$lambda)
"
# Should show 4 DGPs × 5 lambdas with ~1000 reps each

# Visual inspection
open inst/paper/figures/figure3_lambda_sensitivity.pdf
```

**Look for:**
- 4 panels (one per DGP)
- 5 points per panel (one per λ)
- Error bars (95% CIs)
- Dashed line showing true ρ
- Flat profiles for DGPs 1, 4, 5
- Declining profile for DGP 2

---

## Files Overview

| File | Purpose |
|------|---------|
| `cluster/config/lambda_sensitivity_specs.yaml` | Configuration (20 conditions) |
| `cluster/slurm/lambda_sensitivity_array.slurm` | SLURM array job script |
| `cluster/slurm/launch_lambda_sensitivity.sh` | Launcher (submit to cluster) |
| `sims/scripts/lambda_sensitivity_study.R` | Main simulation (one condition) |
| `sims/scripts/generate_figure3_lambda_sensitivity.R` | Figure generator |
| `sims/scripts/lambda_sensitivity_local_test.R` | Quick test (10 reps) |

---

## Timeline

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Optional: Local test | 10 min | 10 min |
| Submit cluster job | 5 min | 15 min |
| **Wait for cluster** | **28 hours** | **28 hr 15 min** |
| Generate Figure 3 | 30 min | 28 hr 45 min |
| Verify output | 15 min | **29 hours total** |

**Cluster highly recommended** - 29 hours vs 6 days local

---

## After Completion

Once Figure 3 is generated, Section 4 is complete:

- ✅ Table 1: DGP specifications
- ✅ Table 2: Performance metrics
- ✅ Table 3: Timing
- ✅ Figure 1: Histograms
- ✅ Figure 2: Scatter plots
- ✅ Figure 3: λ-sensitivity

**Paper is submission-ready for Biometrika!**

---

## Questions?

See detailed documentation:
- `SIMULATION_IMPLEMENTATION_STATUS.md` - Full status and design
- `inst/paper/PAPER_OUTLINE.md` - Paper structure
- `session_notes/2026-05-27.md` - Implementation log
