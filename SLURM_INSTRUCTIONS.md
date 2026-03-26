# Running Studies 1 & 2 on Slurm Cluster

**Date:** 2026-03-26
**Status:** Ready for cluster submission

---

## Quick Start

```bash
# 1. Transfer code to cluster
rsync -avz --exclude='.git' \
  /path/to/surrogate-transportability/ \
  username@cluster.edu:/path/to/destination/

# 2. Login to cluster
ssh username@cluster.edu
cd /path/to/surrogate-transportability

# 3. Create logs directory
mkdir -p slurm/logs

# 4. Edit email address in slurm scripts
sed -i 's/your.email@example.com/your.actual@email.com/g' slurm/*.slurm

# 5. Test first (15 minutes)
sbatch slurm/studies_quick_test.slurm

# 6. If test passes, run reduced studies (3-4 hours)
sbatch slurm/studies_reduced.slurm

# 7. Monitor progress
squeue -u $USER
tail -f slurm/logs/studies_reduced_JOBID.out
```

---

## File Transfer to Cluster

### Option 1: rsync (Recommended)

```bash
# From your local machine
rsync -avz --exclude='.git' --exclude='*.pdf' --exclude='*.Rhistory' \
  /Users/dagniel/RAND/rprojects/surrogates/surrogate-transportability/ \
  username@cluster.edu:~/surrogate-transportability/

# Explanation:
# -a: archive mode (preserves permissions, timestamps)
# -v: verbose
# -z: compress during transfer
# --exclude: skip unnecessary files
```

### Option 2: scp

```bash
# Tar locally first
cd /Users/dagniel/RAND/rprojects/surrogates
tar -czf surrogate-transportability.tar.gz \
  --exclude='.git' --exclude='*.pdf' \
  surrogate-transportability/

# Copy to cluster
scp surrogate-transportability.tar.gz username@cluster.edu:~/

# On cluster: extract
ssh username@cluster.edu
tar -xzf surrogate-transportability.tar.gz
```

### Option 3: Git (If repository is on GitHub/GitLab)

```bash
# On cluster
git clone https://github.com/yourusername/surrogate-transportability.git
cd surrogate-transportability
git checkout main
```

---

## Cluster Setup (One-Time)

### 1. Check available R version

```bash
module avail R
# or
module spider R
```

### 2. Load R and check version

```bash
module load R/4.3.0  # adjust to your cluster's version
R --version
```

### 3. Set up personal R library

```bash
# Create personal R library directory
mkdir -p ~/R/library

# Add to ~/.bashrc or ~/.bash_profile
echo 'export R_LIBS_USER=$HOME/R/library' >> ~/.bashrc
source ~/.bashrc
```

### 4. Install required packages (interactive session)

```bash
# Request interactive session
srun --pty --mem=16G --cpus-per-task=4 --time=01:00:00 bash

# Load R
module load R/4.3.0

# Install packages
R
```

```r
# In R:
install.packages(c('devtools', 'tidyverse', 'furrr', 'progressr', 'here'),
                 repos = 'http://cran.rstudio.com/')

# Install package from source
devtools::load_all('package')

# Test that it works
library(tidyverse)
library(furrr)
devtools::load_all('package')

# Quit
quit(save = "no")
```

---

## Slurm Job Scripts

### Created for You

1. **`slurm/studies_quick_test.slurm`** ⭐ RUN THIS FIRST
   - 20 reps per setting
   - ~15 minutes
   - Verifies everything works

2. **`slurm/studies_reduced.slurm`** ⭐ RECOMMENDED
   - 100 reps per setting
   - ~3-4 hours
   - Statistically valid

3. **`slurm/study1_finite_sample.slurm`**
   - Study 1 only (full: 500 reps)
   - ~6-8 hours

4. **`slurm/study2_stress_testing.slurm`**
   - Study 2 only (full: 500 reps)
   - ~4-6 hours

### Customize Before Submitting

**Edit email address in all .slurm files:**

```bash
# Update email
sed -i 's/your.email@example.com/yourname@rand.org/g' slurm/*.slurm

# Or edit manually
nano slurm/studies_reduced.slurm
# Change line: #SBATCH --mail-user=your.email@example.com
```

**Adjust module names for your cluster:**

```bash
# Check what's available
module avail R
module avail gcc

# Edit slurm scripts to match
nano slurm/studies_reduced.slurm
# Change: module load R/4.3.0  to match your cluster
```

**Adjust resource requests if needed:**

```bash
# For large memory clusters, you might increase:
#SBATCH --cpus-per-task=16   # more cores
#SBATCH --mem=64G            # more memory

# For busy clusters, you might decrease:
#SBATCH --cpus-per-task=4    # fewer cores
#SBATCH --time=08:00:00      # will take longer
```

---

## Job Submission

### Step 1: Quick Test (MANDATORY)

```bash
# Create logs directory
mkdir -p slurm/logs

# Submit test job
sbatch slurm/studies_quick_test.slurm

# Check status
squeue -u $USER

# Watch output
tail -f slurm/logs/quick_test_JOBID.out

# When complete, check for "QUICK TEST PASSED"
# If failed, check errors and fix before proceeding
```

### Step 2: Run Reduced Studies (RECOMMENDED)

If test passed:

```bash
# Submit reduced version (3-4 hours)
sbatch slurm/studies_reduced.slurm

# Save job ID
JOBID=$(squeue -u $USER -h -o %i | head -1)
echo "Job ID: $JOBID"

# Monitor
tail -f slurm/logs/studies_reduced_$JOBID.out
```

### Alternative: Run Studies Separately

```bash
# Submit both studies (they'll run in parallel if nodes available)
JOB1=$(sbatch --parsable slurm/study1_finite_sample.slurm)
JOB2=$(sbatch --parsable slurm/study2_stress_testing.slurm)

echo "Study 1 Job ID: $JOB1"
echo "Study 2 Job ID: $JOB2"

# Monitor both
tail -f slurm/logs/study1_$JOB1.out
tail -f slurm/logs/study2_$JOB2.out
```

---

## Monitoring Jobs

### Check job status

```bash
# Your jobs
squeue -u $USER

# Detailed status
scontrol show job JOBID

# Job history
sacct -u $USER --format=JobID,JobName,Partition,State,Elapsed,MaxRSS
```

### Watch output in real-time

```bash
# Find job ID
JOBID=$(squeue -u $USER -h -o %i | head -1)

# Watch output
tail -f slurm/logs/studies_reduced_$JOBID.out

# Or for multiple jobs
watch -n 30 'squeue -u $USER'
```

### Check resource usage

```bash
# After job completes
seff JOBID

# Shows:
# - CPU efficiency
# - Memory usage
# - Wall time
```

---

## Troubleshooting

### Job Failed Immediately

```bash
# Check error log
cat slurm/logs/studies_reduced_JOBID.err

# Common issues:
# - Module not found: adjust module load commands
# - Permission denied: chmod +x scripts
# - Package missing: run interactive session to install
```

### Job Pending Too Long

```bash
# Check queue
squeue -u $USER

# Reasons:
# - High resource request: reduce cpus/memory
# - Busy cluster: wait or submit to different partition
# - Priority: check cluster policies

# Check available partitions
sinfo

# Submit to specific partition
sbatch --partition=short slurm/studies_quick_test.slurm
```

### Job Running But No Output

```bash
# Check if file being written
ls -lh slurm/logs/studies_reduced_JOBID.out

# Check if R process running on node
squeue -u $USER  # get node name
ssh nodename
ps aux | grep $USER | grep R
```

### R Package Installation Fails

```bash
# Request interactive session
srun --pty --mem=16G --cpus-per-task=4 --time=01:00:00 bash

# Load modules
module load R/4.3.0
module load gcc/11.2.0  # needed for compilation

# Try installing manually
R
install.packages('package-name', repos='http://cran.rstudio.com/')
```

### Out of Memory

```bash
# Check memory usage
seff JOBID

# If exceeded, increase memory in .slurm file:
#SBATCH --mem=64G  # or higher

# Or reduce cores and run longer:
#SBATCH --cpus-per-task=4
N_CORES=4  # in R script
```

---

## Retrieving Results

### Option 1: rsync Back to Local Machine

```bash
# From your local machine
rsync -avz username@cluster.edu:~/surrogate-transportability/sims/results/ \
  /Users/dagniel/RAND/rprojects/surrogates/surrogate-transportability/sims/results/

# This downloads:
# - finite_sample_results.rds
# - stress_test_results.rds
# - All CSV and PDF files
```

### Option 2: scp Individual Files

```bash
# From your local machine
scp username@cluster.edu:~/surrogate-transportability/sims/results/*.rds \
  /Users/dagniel/RAND/rprojects/surrogates/surrogate-transportability/sims/results/
```

### Option 3: Generate Tables/Figures on Cluster First

```bash
# On cluster, after jobs complete
module load R/4.3.0
cd ~/surrogate-transportability

# Generate outputs
Rscript sims/scripts/utils/create_tables.R
Rscript sims/scripts/utils/create_figures.R

# Then download everything
rsync -avz ~/surrogate-transportability/sims/results/ \
  username@local:~/path/to/local/results/
```

---

## Post-Processing on Local Machine

After downloading results:

```bash
# On your local machine
cd /Users/dagniel/RAND/rprojects/surrogates/surrogate-transportability

# Verify files exist
ls -lh sims/results/finite_sample_results.rds
ls -lh sims/results/stress_test_results.rds

# Generate tables and figures
Rscript -e "
library(tidyverse)
library(here)

# Load results
results1 <- readRDS(here('sims/results/finite_sample_results.rds'))
results2 <- readRDS(here('sims/results/stress_test_results.rds'))

# Quick summary
cat('Study 1 rows:', nrow(results1), '\n')
cat('Study 2 rows:', nrow(results2), '\n')
"

# Update manuscript Section 5
# See STUDIES_1_AND_2_PACKAGE.md for LaTeX code
```

---

## Resource Requirements

### Studies Quick Test
- **Time:** 30 minutes
- **Cores:** 4
- **Memory:** 16 GB
- **Cost:** ~2 CPU-hours

### Studies Reduced (Recommended)
- **Time:** 3-4 hours
- **Cores:** 9
- **Memory:** 32 GB
- **Cost:** ~30 CPU-hours

### Studies Full
- **Time:** 6-8 hours
- **Cores:** 9
- **Memory:** 32 GB
- **Cost:** ~60 CPU-hours

### Both Studies Separately (Parallel)
- **Study 1:** 6-8 hours, 9 cores, 32 GB
- **Study 2:** 4-6 hours, 9 cores, 32 GB
- **Total:** ~6-8 hours (parallel), ~100 CPU-hours

---

## Cluster-Specific Adjustments

### If Using Different Cluster Scheduler

**PBS/Torque:**
```bash
# Convert SBATCH to PBS
#PBS -N studies_reduced
#PBS -l walltime=04:00:00
#PBS -l nodes=1:ppn=9
#PBS -l mem=32gb
#PBS -M your.email@example.com
#PBS -m abe
```

**LSF:**
```bash
# Convert SBATCH to LSF
#BSUB -J studies_reduced
#BSUB -W 4:00
#BSUB -n 9
#BSUB -M 32GB
#BSUB -u your.email@example.com
#BSUB -N
```

### If R Version < 4.0

Update package installation:
```r
# Use older package versions
install.packages('furrr', version='0.2.3')
install.packages('tidyverse', version='1.3.0')
```

---

## Checklist

**Before Submitting:**
- [ ] Code transferred to cluster
- [ ] Email address updated in .slurm files
- [ ] Module names adjusted for cluster
- [ ] Logs directory created (`mkdir -p slurm/logs`)
- [ ] R packages installed in interactive session
- [ ] Quick test submitted and passed

**After Quick Test Passes:**
- [ ] Submit reduced studies OR full studies
- [ ] Job ID saved
- [ ] Monitor output logs
- [ ] Check for completion

**After Jobs Complete:**
- [ ] Download result files
- [ ] Verify file sizes (should be 1-10 MB each)
- [ ] Generate tables and figures
- [ ] Update manuscript Section 5

---

## Example Session

```bash
# ============================================================================
# Complete workflow from local machine to results
# ============================================================================

# 1. Transfer code
rsync -avz --exclude='.git' \
  ~/RAND/rprojects/surrogates/surrogate-transportability/ \
  username@cluster.edu:~/surrogate-transportability/

# 2. SSH to cluster
ssh username@cluster.edu
cd ~/surrogate-transportability

# 3. Setup (one-time)
mkdir -p slurm/logs
sed -i 's/your.email@example.com/username@rand.org/g' slurm/*.slurm
module load R/4.3.0
# Install packages in interactive session (see above)

# 4. Quick test
sbatch slurm/studies_quick_test.slurm
squeue -u $USER
tail -f slurm/logs/quick_test_*.out
# Wait for "QUICK TEST PASSED"

# 5. Run reduced studies
sbatch slurm/studies_reduced.slurm
JOBID=$(squeue -u $USER -h -o %i)
echo "Job ID: $JOBID"

# 6. Monitor (check every 30 minutes)
tail slurm/logs/studies_reduced_$JOBID.out

# 7. When complete, check outputs
ls -lh sims/results/*.rds

# 8. Download results (from local machine)
rsync -avz username@cluster.edu:~/surrogate-transportability/sims/results/ \
  ~/RAND/rprojects/surrogates/surrogate-transportability/sims/results/

# 9. Generate tables (local machine)
cd ~/RAND/rprojects/surrogates/surrogate-transportability
Rscript sims/scripts/utils/create_tables.R
```

---

## Support

### Cluster-Specific Help

```bash
# Get help on Slurm commands
man sbatch
man squeue
man scancel

# Cluster documentation (adjust URL)
# Usually at: https://hpc.institution.edu/docs

# Contact cluster support
# support@cluster.edu
```

### Project-Specific Help

- **Quick test fails:** Check package installation, module names
- **Jobs pending forever:** Reduce resource requests, try different partition
- **Out of memory:** Increase `--mem` or reduce `--cpus-per-task`
- **Results don't match expected:** Check log files for warnings

---

## Summary

**Quick Start:**
1. Transfer code: `rsync` to cluster
2. Quick test: `sbatch slurm/studies_quick_test.slurm` (15 min)
3. Run reduced: `sbatch slurm/studies_reduced.slurm` (3-4 hrs)
4. Download: `rsync` results back
5. Generate tables and update manuscript

**Total time:** ~4-5 hours hands-off on cluster, 1 hour local processing

**Output:** Complete Studies 1 & 2 ready for manuscript Section 5
