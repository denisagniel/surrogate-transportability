# AIPW Robustness Study: O2 Deployment Guide

**Study:** Observational AIPW Robustness to Nuisance Misspecification
**Date:** 2026-05-11
**Total:** 615 settings × 1000 reps = 615,000 replications
**Estimated Runtime:** 20-50 hours (parallelized)

---

## Quick Start

```bash
# On O2
cd ~/surrogate-transportability/cluster/aipw_robustness/slurm

# 1. Quick test (2 settings × 10 reps, ~2 minutes)
bash quick_test.sh

# 2. Check test completed
bash check_progress.sh

# 3. Launch full study (after test succeeds)
bash launch_all_simulations.sh

# 4. Monitor progress
watch -n 60 bash check_progress.sh

# 5. After completion, combine results
Rscript combine_results.R
```

---

## Prerequisites

### 1. O2 Account and Access

- [ ] Have O2 account at HMS Research Computing
- [ ] Can SSH to O2: `ssh username@o2.hms.harvard.edu`
- [ ] Have quota in scratch storage: `/n/scratch/users/u/username/`

### 2. R Package Installation

The study requires `surrogateTransportability` package installed in your O2 R library:

```bash
# On O2, load R
module load gcc/14.2.0
module load R/4.4.2

# Install package
R
```

```r
# In R console
install.packages("devtools")
install.packages("optparse")
install.packages("yaml")
install.packages("dplyr")
install.packages("purrr")
install.packages("readr")

# Install surrogateTransportability from local source
# (Assuming you've pushed package to GitHub and pulled to O2)
devtools::install("~/surrogate-transportability")

# Verify installation
library(surrogateTransportability)
?tv_ball_correlation_IF_adaptive
```

### 3. Code Transfer to O2

```bash
# On local machine
cd ~/RAND/rprojects/surrogates/surrogate-transportability
git add cluster/aipw_robustness/
git commit -m "Add AIPW robustness O2 infrastructure"
git push origin main

# On O2
cd ~/surrogate-transportability
git pull origin main
```

---

## File Structure

```
cluster/aipw_robustness/
├── config/
│   └── aipw_grid.yaml             # Parameter grid configuration
├── slurm/
│   ├── run_single_replication.R   # Core simulation script
│   ├── run_simulations.slurm      # SLURM batch script
│   ├── launch_scenario.sh         # Launch specific scenario (0-3)
│   ├── launch_all_simulations.sh  # Launch all scenarios
│   ├── quick_test.sh              # Quick infrastructure test
│   ├── check_progress.sh          # Monitor job progress
│   ├── combine_results.R          # Aggregate results
│   ├── README_O2.md               # This file
│   └── logs/                      # SLURM output logs (created)
└── results/                       # Result files (created)
    ├── s0_n*/batch_*.rds          # Scenario 0 results
    ├── s1_n*/batch_*.rds          # Scenario 1 results
    ├── s2_n*/batch_*.rds          # Scenario 2 results
    ├── s3_n*/batch_*.rds          # Scenario 3 results
    ├── aipw_robustness_combined.rds   # Combined dataset
    └── aipw_robustness_summary.csv    # Summary table
```

---

## Study Design Overview

### Scenarios

| Scenario | Description | Settings |
|----------|-------------|----------|
| 0 | Oracle (true nuisances) | 15 |
| 1 | Propensity noise only | 180 |
| 2 | Outcome noise only | 180 |
| 3 | Both noisy | 240 |
| **Total** | | **615** |

### Parameter Grid

- **Sample sizes:** n ∈ {500, 1000, 2000, 5000, 10000}
- **Confounding:** α₁ ∈ {0.0, 0.3, 0.6} (RCT, mild, strong)
- **Convergence rates:** α_e, α_μ ∈ {0, 0.25, 0.5, 0.75}
- **Noise constants:** c_e, c_μ ∈ {0.5, 1.0, 2.0}
- **Replications:** 1000 per setting

**Noise scaling:** σ(n) = c · n^(-α)

---

## Deployment Workflow

### Step 1: Quick Test (~2 minutes)

Validates infrastructure before full launch.

```bash
cd ~/surrogate-transportability/cluster/aipw_robustness/slurm
bash quick_test.sh
```

**Expected output:**
```
Submitted: Job 12345678
Submitted: Job 12345679
```

**Monitor:**
```bash
squeue -u $USER | grep aipw
watch -n 5 'squeue -u $USER | grep aipw'
```

**Check results after completion:**
```bash
ls -lh results/
ls results/s0_n1000*/
ls results/s3_n1000*/

# View first result
Rscript -e "readRDS(list.files('results', pattern='batch.*\\.rds', recursive=TRUE, full.names=TRUE)[1])"
```

**Success criteria:**
- 4 jobs complete without errors
- Result files created in `results/`
- Oracle bias < 0.05 (check in result file)

### Step 2: Launch Full Study

**Option A: Launch all scenarios at once**
```bash
bash launch_all_simulations.sh
```

**Option B: Launch scenarios individually (recommended)**
```bash
# Scenario 0: Oracle (15 settings, ~300 jobs)
bash launch_scenario.sh 0

# Wait for scenario 0 to complete, verify results look good
bash check_progress.sh
Rscript -e "readRDS('results/s0_*/batch_001.rds')"

# Then launch scenario 1
bash launch_scenario.sh 1

# Repeat for scenarios 2-3
bash launch_scenario.sh 2
bash launch_scenario.sh 3
```

**Option C: Pilot run (faster test)**
```bash
# 100 reps per setting instead of 1000
bash launch_all_simulations.sh 50 100
```

### Step 3: Monitor Progress

```bash
# Manual check
bash check_progress.sh

# Auto-refresh every 60 seconds
watch -n 60 bash check_progress.sh

# Check specific scenario
find results -name "s0_*_batch_*.rds" | wc -l  # Scenario 0 files
```

**Monitoring tips:**
- Check progress every hour or so
- Don't refresh too frequently (every 30-60 sec is fine)
- Use `squeue -u $USER` to see all your jobs
- Check logs if jobs fail: `tail logs/aipw_*.err`

### Step 4: Combine Results

After all jobs complete:

```bash
Rscript combine_results.R
```

**Expected output:**
```
Found 12,300 batch files
Combined 615,000 replications
Computed summaries for 615 settings

Scenario 0: Oracle
  Max |bias|: 0.0234 ✓ PASS
  Min coverage: 93.2% ✓ PASS

Combined data: ../results/aipw_robustness_combined.rds (615000 rows)
Summary table: ../results/aipw_robustness_summary.csv (615 settings)
```

### Step 5: Transfer Results to Local Machine

```bash
# On local machine
cd ~/RAND/rprojects/surrogates/surrogate-transportability
scp username@o2.hms.harvard.edu:~/surrogate-transportability/cluster/aipw_robustness/results/aipw_robustness_combined.rds cluster/aipw_robustness/results/
scp username@o2.hms.harvard.edu:~/surrogate-transportability/cluster/aipw_robustness/results/aipw_robustness_summary.csv cluster/aipw_robustness/results/
```

Or commit and push from O2:

```bash
# On O2
cd ~/surrogate-transportability
git add cluster/aipw_robustness/results/*.rds
git add cluster/aipw_robustness/results/*.csv
git commit -m "Add AIPW robustness simulation results"
git push origin main

# Then pull on local
git pull origin main
```

---

## Configuration

### Tuning Job Parameters

Edit `run_simulations.slurm` `#SBATCH` directives:

```bash
#SBATCH --time=2:00:00       # Time limit (increase if jobs timeout)
#SBATCH --mem=8G             # Memory (increase if out-of-memory errors)
#SBATCH --partition=short    # Queue (change to 'medium' for >12hr jobs)
```

### Tuning Parallelization

Default: 50 reps per job = ~20 jobs per setting

**If jobs too short (<30 min):** Increase reps per job
```bash
bash launch_scenario.sh 0 100 1000  # 100 reps/job = 10 jobs per setting
```

**If jobs too long (>2 hr):** Decrease reps per job
```bash
bash launch_scenario.sh 0 25 1000   # 25 reps/job = 40 jobs per setting
```

### Module Versions

Current defaults (edit `run_simulations.slurm` if needed):
- GCC: 14.2.0
- R: 4.4.2

Check available versions:
```bash
module avail gcc
module avail R
```

---

## Troubleshooting

### Problem: Jobs fail immediately

**Check:**
```bash
tail logs/aipw_*.err
```

**Common causes:**
1. Package not installed: Run R installation steps above
2. Module not found: Check module versions with `module avail`
3. File path wrong: Ensure you're in `slurm/` directory when launching

**Fix:** Install missing dependencies, adjust paths, resubmit

### Problem: Out of memory errors

**Symptoms:**
```
slurmstepd: error: Detected OOM
```

**Fix:**
```bash
# Edit run_simulations.slurm
#SBATCH --mem=16G  # Increase from 8G to 16G
```

### Problem: Jobs timeout

**Symptoms:**
```
DUE TO TIME LIMIT
```

**Fix:**
```bash
# Edit run_simulations.slurm
#SBATCH --time=4:00:00  # Increase from 2:00:00 to 4:00:00
# Or reduce reps per job:
bash launch_scenario.sh 0 25 1000  # 25 reps/job instead of 50
```

### Problem: "Too many open files"

**Fix:** Reduce batch size (fewer reps per job)

### Problem: Convergence failures (M_final = NA)

**Check results:**
```r
results <- readRDS("results/aipw_robustness_combined.rds")
table(results$converged)
summary(results$M_final[!results$converged])
```

**If >10% don't converge:**
- Increase M_max in `config/aipw_grid.yaml` (currently 3000)
- Loosen tolerance (currently 0.01)

### Problem: Results look wrong (oracle bias > 0.05)

**This indicates a bug.** Check:
1. Function implementation: `tv_ball_correlation_IF_adaptive`
2. Nuisance generation: `run_single_replication.R` noise logic
3. DGP parameters: `config/aipw_grid.yaml`

**Don't proceed** with full study until oracle scenario validates.

---

## Resource Usage Estimates

### Computational Cost

**Per replication:**
- Time: 2-5 minutes (varies with n and M convergence)
- Memory: ~1-2GB peak
- CPU: 1 core

**Full study (615 settings × 1000 reps):**
- Total CPU time: ~2,000-5,000 hours
- Wall time (parallelized): ~20-50 hours
- Disk space: ~5-10GB for results

**Pilot run (615 settings × 100 reps):**
- Total CPU time: ~200-500 hours
- Wall time: ~2-5 hours
- Disk space: ~500MB-1GB

### Job Counts

With 50 reps/job (default):
- Scenario 0: 15 settings × 20 jobs = 300 jobs
- Scenario 1: 180 settings × 20 jobs = 3,600 jobs
- Scenario 2: 180 settings × 20 jobs = 3,600 jobs
- Scenario 3: 240 settings × 20 jobs = 4,800 jobs
- **Total: 12,300 jobs**

All jobs are independent and can run in parallel (subject to cluster limits).

---

## FAQ

**Q: Can I run this locally instead of O2?**
A: Yes, but it will take much longer. Estimate: ~3-12 months on single machine vs ~1-2 days on O2.

**Q: How do I cancel jobs if something goes wrong?**
A: `scancel -u $USER` (cancels all your jobs) or `scancel <job_id>` (specific job)

**Q: Can I pause and resume?**
A: Yes! Results are saved per batch. Just resubmit jobs for settings that didn't complete.

**Q: What if my SSH connection drops?**
A: Jobs keep running! Use `tmux` or `screen` to persist monitoring terminal.

**Q: How do I check disk quota?**
A: `df -h /n/scratch/users/${USER:0:1}/${USER}` for scratch
   `du -sh ~/surrogate-transportability/cluster/aipw_robustness/results` for current usage

**Q: Should I use shared storage or scratch?**
A: Jobs write to scratch (fast, temporary), then copy to home (slower, permanent). This is already handled in SLURM script.

---

## Support

**O2 Documentation:**
- Portal: https://harvardmed.atlassian.net/wiki/spaces/O2/overview
- Getting Started: https://harvardmed.atlassian.net/wiki/spaces/O2/pages/1586662833/How+to+Guide+Get+Started+on+O2
- SLURM Guide: https://harvardmed.atlassian.net/wiki/spaces/O2/pages/1586662409/Using+Slurm+Basic

**O2 Support:**
- Email: rchelp@rc.fas.harvard.edu
- Office Hours: Check O2 wiki for schedule

**Package/Study Issues:**
- Check GitHub issues: https://github.com/your-org/surrogate-transportability
- Contact study lead

---

## Version History

- **2026-05-11:** Initial O2 infrastructure for AIPW robustness study
- **Date:** Updates as needed after testing/deployment

---

## Checklist

### Before Launch
- [ ] R package installed on O2
- [ ] Quick test completes successfully
- [ ] Oracle results validate (bias < 0.05, coverage ~95%)
- [ ] Disk quota sufficient (~10GB needed)
- [ ] Understand job monitoring and cancellation

### During Run
- [ ] Check progress hourly/daily
- [ ] Monitor for errors in logs
- [ ] Verify results files being created
- [ ] Confirm convergence rates acceptable

### After Completion
- [ ] All jobs finished (check `squeue -u $USER`)
- [ ] Combine results with `combine_results.R`
- [ ] Validate summary statistics
- [ ] Transfer results to local machine
- [ ] Clean up scratch directory if needed

---

**Ready to deploy!** Start with `bash quick_test.sh` and proceed from there.
