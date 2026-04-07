# TV Ball Coverage Cluster Simulations

Comprehensive simulation study to verify dense coverage properties of the innovation mechanism across:
- Sample sizes: N ∈ {50, 100, 250, 500, 1000}
- TV ball radii: λ ∈ {0.1, 0.3, 0.5}
- Innovation samples: M ∈ {50, 100, 250, 500, 1000, 2500, 5000}
- Functionals: correlation, PPV, concordance

**Total:** 315 jobs × 100 replications = 31,500 simulation runs

## Setup (Run Once)

```bash
# 1. Generate parameter grid
Rscript sims/cluster/00_generate_param_grid.R

# 2. Create log directory
mkdir -p sims/cluster/logs
mkdir -p sims/cluster/results
```

## Submit to O2

```bash
# From project root directory
sbatch sims/cluster/submit_o2.sh
```

This submits an array job with 315 tasks. Each task:
- Takes 3-5 minutes
- Uses 2GB RAM
- Runs 100 replications
- Saves results to `sims/cluster/results/job_XXXX.rds`

**Estimated wall time:** 15-30 minutes with 100 parallel jobs

## Monitor Jobs

```bash
# Check job status
squeue -u $USER

# Check specific job
squeue -j <job_id>

# View output logs
tail -f sims/cluster/logs/job_001.out
tail -f sims/cluster/logs/job_001.err

# Count completed jobs
ls sims/cluster/results/job_*.rds | wc -l
```

## Aggregate Results

After all jobs complete:

```bash
Rscript sims/cluster/99_aggregate_results.R
```

This:
1. Combines all 315 job outputs
2. Generates summary statistics
3. Creates 4 publication-quality plots
4. Saves to `sims/results/29_tv_ball_coverage_CLUSTER_*`

## Troubleshooting

**Jobs failing:**
- Check error logs: `cat sims/cluster/logs/job_*.err | grep -i error`
- Check module versions in `submit_o2.sh`
- Verify package loads: `module load R/4.3.1 && Rscript -e "devtools::load_all()"`

**Missing results:**
- Aggregation script lists missing job IDs
- Resubmit specific jobs: `sbatch --array=42,73,105 sims/cluster/submit_o2.sh`

**Out of memory:**
- Increase `--mem=2G` to `--mem=4G` in `submit_o2.sh`
- Large M values may need more memory

**Time limit exceeded:**
- Increase `--time=00:15:00` to `--time=00:30:00`
- Large M and N combinations may take longer

## File Structure

```
sims/cluster/
├── README.md                          # This file
├── 00_generate_param_grid.R           # Setup: create parameter grid
├── 29_tv_coverage_cluster.R           # Worker: run single job
├── 99_aggregate_results.R             # Postprocess: combine results
├── submit_o2.sh                       # SLURM submission script
├── 29_tv_coverage_params.rds          # Parameter grid (generated)
├── 29_tv_coverage_params.csv          # Human-readable grid (generated)
├── logs/                              # Job stdout/stderr (created by SLURM)
│   ├── job_001.out
│   ├── job_001.err
│   └── ...
└── results/                           # Individual job outputs
    ├── job_0001.rds
    ├── job_0002.rds
    └── ...
```

## Expected Outputs

**Intermediate:** `sims/cluster/results/job_XXXX.rds` (315 files)
- One per job, ~100 rows each
- Contains: reachability, gap, min_phi for 100 replications

**Final:** `sims/results/29_tv_ball_coverage_CLUSTER_*`
- `*_results.rds`: Combined dataset (~31,500 rows)
- `*_summary.rds`: Aggregated statistics (315 rows)
- `*_reachability_grid.pdf`: Main plot (5×3 facets)
- `*_convergence_grid.pdf`: Gap plot (5×3 facets)
- `*_reachability_lambda03.pdf`: Focus on λ=0.3
- `*_sample_size_effect.pdf`: N effect at M=1000

## Research Questions

1. **Dense Coverage (Theorem 5b):** Does reachability increase with M?
2. **Convergence (Theorem 5c):** Does gap → 0 as M → ∞?
3. **Scaling:** How does λ affect coverage difficulty?
4. **Sample Size:** Does baseline N affect coverage quality?
5. **M Threshold:** What M is needed for 60% reachability at λ=0.5?

## Next Steps

1. Run simulations
2. Review plots in `sims/results/`
3. Compare to theoretical predictions (Theorem 5)
4. Include key plot in manuscript
5. Report summary statistics in paper (Table or caption)
