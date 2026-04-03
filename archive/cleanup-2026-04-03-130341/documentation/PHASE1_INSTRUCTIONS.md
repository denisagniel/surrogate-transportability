# Phase 1: Sample Size Effect Test

## Overview

Test whether selection bias in observation-level Wasserstein DRO decreases with larger sample sizes.

**Hypothesis:** If bias ∝ 1/√n, then n=2000 should achieve coverage ≥90%.

## Files

1. **test_sample_size_effect.R** - Sequential version (slow, for local testing)
2. **test_sample_size_effect_single.R** - Single replication (for SLURM)
3. **test_sample_size_effect_slurm.sh** - SLURM array job submission
4. **test_sample_size_effect_aggregate.R** - Combine results and analyze

## Design

- **Sample sizes:** n ∈ {250, 500, 1000, 2000}
- **Replications:** 50 per sample size (200 total)
- **Bootstraps:** 500 per replication (for stable 95% quantiles)
- **Total computations:** 200 reps × 500 bootstraps = 100,000 estimations

## Option 1: SLURM (Recommended)

Parallel execution across 200 jobs:

```bash
# Create directories
mkdir -p test_sample_size_results
mkdir -p slurm_logs

# Submit array job
sbatch test_sample_size_effect_slurm.sh

# Monitor progress
squeue -u $USER

# Check how many results are ready
ls test_sample_size_results/*.rds | wc -l

# Once all 200 complete, aggregate
Rscript test_sample_size_effect_aggregate.R
```

**Expected time:** ~30-60 minutes (parallel) per replication, so ~1-2 hours total.

## Option 2: Sequential (Local)

For small-scale testing only (very slow):

```bash
# Run all (will take HOURS)
Rscript test_sample_size_effect.R

# Or test with fewer reps first
# Edit n_reps=10 and n_bootstrap=100 in script
```

**Expected time:**
- n=250: ~2 min per rep × 50 = 100 min
- n=500: ~4 min per rep × 50 = 200 min
- n=1000: ~8 min per rep × 50 = 400 min
- n=2000: ~15 min per rep × 50 = 750 min
- **Total: ~25 hours**

## Modifying for Your Cluster

Edit `test_sample_size_effect_slurm.sh`:

```bash
# Adjust these lines for your cluster
#SBATCH --time=01:00:00      # May need more for n=2000
#SBATCH --mem=4G              # May need 8G for n=2000
module load R/4.3.0           # Your R module name

# Update working directory path
cd /your/path/to/surrogate-transportability
```

## Quick Test (Recommended First)

Test with smaller parameters to verify everything works:

```bash
# Test single replication
mkdir -p test_sample_size_results
Rscript test_sample_size_effect_single.R 250 1 test_sample_size_results

# Check output
ls test_sample_size_results/
```

Should create: `result_n250_rep001.rds`

## Interpreting Results

After aggregation, check:

1. **Coverage trend:** Does it increase with n?
2. **n=2000 coverage:**
   - ≥90%: SUCCESS (Phase 1 solves it)
   - 85-90%: PARTIAL (proceed to Phase 2 with optimism)
   - <85%: Phase 2 needed (fundamental issue)

3. **Bias scaling:** Does bias ∝ 1/√n hold?

## Decision Points

**If n=2000 gives coverage ≥90%:**
- Problem solved by larger samples
- Update package with sample size requirements
- No need for Phase 2 debiasing

**If n=2000 gives coverage <85%:**
- Proceed to Phase 2: systematic debiasing
- Test 5 correction approaches
- Consider mean performance alternative

## Troubleshooting

**SLURM jobs failing:**
- Check: `tail slurm_logs/sample_size_*.err`
- Common issues: R module not loaded, package not found, memory

**Few results completing:**
- n=2000 may need more time (increase `--time`)
- Or more memory (increase `--mem`)

**All replications fail for large n:**
- May indicate optimization issues
- Check one manually: `Rscript test_sample_size_effect_single.R 2000 1 test`

## Next Steps

After Phase 1 complete:
- Review `test_sample_size_effect_results.rds`
- Check plots in root directory
- Update session notes with findings
- Decide: Phase 2 needed?
