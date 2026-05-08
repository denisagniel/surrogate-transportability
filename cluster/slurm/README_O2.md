## Cluster Simulation Infrastructure: Surrogate Transportability Validation

Complete production infrastructure for running 3000 replications (3 DGPs × 1000 reps) on Harvard O2 cluster.

---

## Quick Start

```bash
# Local: Test infrastructure
bash cluster/slurm/quick_test.sh

# Local: Push to GitHub
git add -A && git commit -m "Add cluster infrastructure"
git push

# O2: Pull and test
git pull
bash cluster/slurm/quick_test.sh

# O2: Launch full study
bash cluster/slurm/launch_all_simulations.sh

# O2: Monitor
bash cluster/slurm/check_progress.sh

# O2: Combine results (after completion)
Rscript cluster/slurm/combine_results.R
```

---

## Configuration

### Study Design

- **DGPs**: 3 (dgp1, dgp2, dgp4)
- **Replications per DGP**: 1000
- **Total replications**: 3000
- **Reps per job**: 10
- **Jobs per DGP**: 100
- **Total jobs**: 300

### Expected Runtime

- **Per job**: 50-60 minutes (10 reps × 5-6 min/rep)
- **Total wall time**: ~1 hour (parallel execution)
- **Total CPU time**: ~300 hours (300 jobs × 1 hour)

### SLURM Settings

```bash
#SBATCH --array=1-100         # 100 jobs per DGP
#SBATCH --time=02:00:00       # 2-hour limit (buffer)
#SBATCH --mem=8G              # 8GB per job
#SBATCH --partition=short     # Short queue
```

**Rationale:**
- 2-hour time limit provides buffer (expected: 50-60 min)
- 8G memory handles n=10,000 with adaptive M up to M=5000
- Short partition optimal for 1-hour jobs

---

## File Structure

```
cluster/
├── config/
│   └── dgp_specifications.yaml    # DGP parameters and settings
├── slurm/
│   ├── run_single_replication.R   # Core simulation script
│   ├── run_simulations.slurm      # SLURM batch script
│   ├── launch_all_simulations.sh  # Submit all jobs
│   ├── quick_test.sh              # Quick test (2 reps)
│   ├── check_progress.sh          # Monitor progress
│   ├── combine_results.R          # Aggregate results
│   ├── README_O2.md               # This file
│   └── logs/                      # SLURM logs (created automatically)
└── results/
    ├── dgp1/                      # Batch results for DGP 1
    ├── dgp2/                      # Batch results for DGP 2
    ├── dgp4/                      # Batch results for DGP 4
    └── combined_results.rds       # Final combined results
```

---

## Prerequisites

### On O2

1. **R module**: R/4.4.2 with gcc/14.2.0
2. **Package installation**:

```bash
module load gcc/14.2.0 R/4.4.2

# Install package
cd /path/to/surrogate-transportability
R CMD INSTALL .

# Test
Rscript -e "library(surrogateTransportability); packageVersion('surrogateTransportability')"
```

3. **Directory structure**:

```bash
mkdir -p cluster/results/{dgp1,dgp2,dgp4}
mkdir -p cluster/slurm/logs
```

4. **Permissions**:

```bash
chmod +x cluster/slurm/*.sh
```

---

## Detailed Workflow

### Step 1: Local Testing

```bash
# Test infrastructure (2 reps, ~10-12 minutes)
bash cluster/slurm/quick_test.sh
```

Expected output:
```
Test PASSED!
✓ Output file created
  First rep results:
    rho_hat: 0.XXXX
    M_final: XXXX
    converged: TRUE
    time: XXX.X seconds
```

### Step 2: Deploy to O2

```bash
# Local
git add -A
git commit -m "Add cluster simulation infrastructure"
git push

# O2
ssh [username]@o2.hms.harvard.edu
cd /path/to/surrogate-transportability
git pull

# Load modules and install package
module load gcc/14.2.0 R/4.4.2
R CMD INSTALL .
```

### Step 3: Test on O2

```bash
# Quick test on O2 (2 reps)
bash cluster/slurm/quick_test.sh
```

If test passes, infrastructure is ready.

### Step 4: Launch Full Study

```bash
bash cluster/slurm/launch_all_simulations.sh
```

Output:
```
Submitting jobs for dgp1...
  Job ID: 12345678 (100 array tasks)

Submitting jobs for dgp2...
  Job ID: 12345679 (100 array tasks)

Submitting jobs for dgp4...
  Job ID: 12345680 (100 array tasks)

Total: 300 jobs (3 DGPs × 100 batches)
Expected completion: ~1 hour
```

### Step 5: Monitor Progress

```bash
# Check status periodically
bash cluster/slurm/check_progress.sh
```

Output:
```
Job Status:
  Running:  150
  Pending:  150
  Total:    300

Results Completed:
  dgp1: 45/100 (45%)
  dgp2: 38/100 (38%)
  dgp4: 42/100 (42%)

Overall: 125/300 (42%)
Estimated completion: ~1 hour
```

### Step 6: Combine Results

After all jobs complete:

```bash
Rscript cluster/slurm/combine_results.R
```

Output:
```
=== dgp1 ===
  Found 100 batch files
  Total replications: 1000

  Correlation Results:
    TRUE ρ = 0.6907
    Mean ρ̂ = 0.6912 (SD = 0.0543)
    Bias = 0.0005 (0.1%)
    Coverage = 94.5% (945/1000)

  PTE Results:
    TRUE PTE = 0.8156
    Mean PTE_hat = 0.8159 (SD = 0.0321)
    Bias = 0.0003 (0.0%)

[... similar for dgp2, dgp4 ...]

Combined results saved: cluster/results/combined_results.rds
```

### Step 7: Retrieve Results

```bash
# Option 1: Copy to local
scp -r [username]@o2.hms.harvard.edu:/path/to/cluster/results ./cluster/

# Option 2: Commit to git (if results are small)
git add cluster/results/combined_results.rds
git commit -m "Add cluster simulation results"
git push
```

---

## Troubleshooting

### Jobs Fail with Memory Error

**Symptoms:**
```
slurmstepd: error: Exceeded job memory limit
```

**Solution:**
Edit `cluster/slurm/run_simulations.slurm`:
```bash
#SBATCH --mem=12G  # Increase from 8G
```

### Jobs Timeout

**Symptoms:**
```
CANCELLED DUE TO TIME LIMIT
```

**Solution:**
1. Check if some DGPs take longer:
   ```bash
   grep "Total time" cluster/slurm/logs/*.out | sort -t: -k2 -n
   ```

2. Increase time limit:
   ```bash
   #SBATCH --time=03:00:00  # Increase to 3 hours
   ```

3. Or reduce reps per job:
   Edit `cluster/slurm/launch_all_simulations.sh`:
   ```bash
   # Change reps-per-batch to 5 (doubles number of jobs to 200/DGP)
   ```

### Package Not Found

**Symptoms:**
```
Error: there is no package called 'surrogateTransportability'
```

**Solution:**
```bash
module load gcc/14.2.0 R/4.4.2
cd /path/to/surrogate-transportability
R CMD INSTALL .
```

### Results Directory Not Created

**Symptoms:**
```
cannot create directory 'cluster/results/dgp1'
```

**Solution:**
```bash
mkdir -p cluster/results/{dgp1,dgp2,dgp4}
mkdir -p cluster/slurm/logs
```

---

## Advanced Usage

### Re-run Failed Jobs

If some jobs fail, identify which batches are missing:

```bash
# Find missing batches for dgp1
for i in {1..100}; do
    FILE=$(printf "cluster/results/dgp1/batch_%03d.rds" $i)
    if [ ! -f "$FILE" ]; then
        echo "Missing batch: $i"
    fi
done
```

Resubmit specific batches:

```bash
# Resubmit batch 42 for dgp1
sbatch --array=42 --export=DGP_ID=dgp1 cluster/slurm/run_simulations.slurm
```

### Run Single DGP

```bash
# Only run dgp4
sbatch --export=DGP_ID=dgp4 cluster/slurm/run_simulations.slurm
```

### Increase Replications

To run 2000 reps per DGP instead of 1000:

1. Update config:
   ```yaml
   # cluster/config/dgp_specifications.yaml
   cluster_settings:
     N_reps_per_dgp: 2000
   ```

2. Launch:
   ```bash
   # Now 200 jobs per DGP (2000 reps / 10 per job)
   # Update SBATCH --array in run_simulations.slurm to 1-200
   bash cluster/slurm/launch_all_simulations.sh
   ```

---

## Module Versions

**Current configuration (O2 defaults):**
- `gcc/14.2.0`
- `R/4.4.2`

**To check available versions:**
```bash
module spider R
module spider gcc
```

**To use different versions:**
Edit `cluster/slurm/run_simulations.slurm`:
```bash
module load gcc/13.2.0  # Different gcc
module load R/4.3.1     # Different R
```

---

## Performance Notes

### Timing Breakdown

Per replication (n=10,000):
- Data generation: ~0.1 seconds
- Adaptive M (converging at M≈3300): ~5-6 minutes
- PTE computation: ~0.1 seconds
- Total: ~5-6 minutes

Per job (10 reps):
- Total: ~50-60 minutes
- Overhead: ~1-2%

### Optimization

Current configuration is optimized for:
- **Job count**: 300 (well under 1000 limit)
- **Job duration**: 50-60 min (sweet spot for short queue)
- **Memory**: 8G (adequate for n=10,000, M=5000)
- **Parallel efficiency**: ~99% (minimal overhead)

**Do not over-optimize:**
- Fewer reps per job → more overhead
- More reps per job → risk timeout, harder to debug

---

## Contact

For O2-specific issues:
- O2 documentation: https://o2.hms.harvard.edu/
- Help: rchelp@hms.harvard.edu

For simulation questions:
- See `cluster/config/dgp_specifications.yaml` for DGP details
- See `R/tv_ball_correlation_IF_adaptive.R` for estimation method

---

## Changelog

- **2026-05-08**: Initial production infrastructure
  - 3 DGPs (dgp1, dgp2, dgp4)
  - 10 reps per job targeting 1-hour runtime
  - O2 module defaults (gcc/14.2.0, R/4.4.2)
