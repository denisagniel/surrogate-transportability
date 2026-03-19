# HMS O2 SLURM Quick Start Guide

Complete guide for running surrogate transportability validation studies on HMS O2 cluster.

---

## Table of Contents

1. [O2 Storage Strategy](#o2-storage-strategy)
2. [File Transfer to O2](#file-transfer-to-o2)
3. [Initial Setup](#initial-setup)
4. [Testing Workflow](#testing-workflow)
5. [Full Deployment](#full-deployment)
6. [Monitoring](#monitoring)
7. [Results Retrieval](#results-retrieval)
8. [Troubleshooting](#troubleshooting)

---

## O2 Storage Strategy

### Storage Locations

**Home Directory** (`$HOME`): Limited space (~100 GB quota)
- Use for: Code, documentation, final aggregated results
- **Do NOT store:** Individual replication .rds files

**Scratch Storage** (`/n/scratch/users/...`): 10 TB quota, 30-day auto-deletion
- Use for: Individual replication .rds files (sims/results/reps/)
- Files deleted 30 days after last access
- Reference: https://harvardmed.atlassian.net/wiki/spaces/O2/pages/2652045313/Scratch+Storage

### Recommended Workflow

```bash
# Project code in home directory
$HOME/surrogate-transportability/

# Individual replications in scratch
/n/scratch/users/d/dagniel/surrogate-transportability/results/reps/

# Final aggregated results back in home
$HOME/surrogate-transportability/sims/results/
```

The `o2_config.sh` script automatically configures these paths.

---

## File Transfer to O2

### Code/Scripts: Use GitHub (Recommended)

**Clone repository on O2:**
```bash
# Connect to O2
ssh USERNAME@o2.hms.harvard.edu

# Clone repository
cd ~
git clone https://github.com/denisagniel/surrogate-transportability.git
cd surrogate-transportability

# Or pull latest changes if already cloned
git pull
```

**Benefits:**
- Version controlled
- Easy to sync updates
- No need to transfer code files manually
- Can switch branches/commits as needed

### Results: Transfer from O2 to Local

Reference: https://harvardmed.atlassian.net/wiki/spaces/O2/pages/1588662157/File+Transfer

**Option 1: rsync (Recommended)**
```bash
# From local machine
# Download aggregated results only (recommended, ~500 MB)
rsync -avz --progress \
  USERNAME@transfer.rc.hms.harvard.edu:~/surrogate-transportability/sims/results/ \
  ./local/results/

# Or download everything including individual reps (large, ~5-7 GB)
rsync -avz --progress \
  USERNAME@transfer.rc.hms.harvard.edu:/n/scratch/users/d/dagniel/surrogate-transportability/results/ \
  ./local/all-results/
```

**Option 2: scp (Simple)**
```bash
# From local machine
scp -r USERNAME@transfer.rc.hms.harvard.edu:~/surrogate-transportability/sims/results/ \
  ./local/results/
```

**Option 3: Globus (Best for Very Large Datasets)**

For datasets > 10 GB, use Globus web interface:
1. Go to https://www.globus.org/
2. Search for "HMS O2" endpoint
3. Transfer files via web interface

**Option 4: FileZilla/Cyberduck (GUI)**

Configure SFTP connection:
- Host: transfer.rc.hms.harvard.edu
- Protocol: SFTP
- Port: 22
- Use HMS credentials

---

## Initial Setup

### 1. Connect to O2 and Clone Repository

```bash
# Connect to O2
ssh USERNAME@o2.hms.harvard.edu

# Clone repository from GitHub
cd ~
git clone https://github.com/denisagniel/surrogate-transportability.git
cd surrogate-transportability

# Verify code is up to date
git status
git log --oneline -5
```

### 2. Set Up R Environment on O2

```bash
# Already connected to O2 from step 1
cd ~/surrogate-transportability

# Source O2 configuration (loads R module, sets up paths)
source sims/slurm/o2_config.sh

# Install required R packages
R -e "install.packages(c('devtools', 'dplyr', 'tibble', 'optparse', 'ggplot2', 'purrr'), repos='https://cloud.r-project.org')"

# Load project package to check dependencies
R -e "devtools::load_all('package/')"
```

### 3. Verify Setup

```bash
# Check R version
R --version

# Check module availability
module spider R

# Verify directories
ls -lh sims/slurm/
ls -lh sims/scripts/
```

---

## Testing Workflow

### Phase 0: Interactive Testing (Optional, Recommended)

Before submitting any jobs, test interactively:

```bash
# Start interactive session (1 hour, 6 GB)
srun --pty -p interactive -t 0-01:00 --mem 6G bash

# Load modules
module load gcc/14.2.0
module load R/4.4.2

# Navigate to project
cd ~/surrogate-transportability

# Test a single replication with reduced parameters
Rscript sims/scripts/run_single_replication.R \
  --study-type covariate_shift \
  --scenario small \
  --replication 1 \
  --output-dir /n/scratch/users/d/dma12/surrogate-transportability/results/reps/covariate_shift \
  --n-baseline 300 \
  --n-true-studies 100 \
  --n-baseline-resamples 50 \
  --n-bootstrap 20 \
  --n-mc-draws 10

# Exit interactive session
exit
```

**Expected:**
- Script completes in 2-5 minutes
- Output file created in scratch storage
- No errors

**Interactive session options:**
- `-p interactive` - Interactive partition (faster scheduling)
- `-p short` - Alternative partition for testing
- `-t 0-01:00` - Time limit (days-hours:minutes)
- `--mem 6G` - Memory (match SLURM scripts)

### Phase 1: Single Job Test (5 minutes)

```bash
# Make scripts executable
chmod +x sims/slurm/*.sh

# Submit single test replication
sbatch --export=STUDY_TYPE=covariate_shift,SCENARIO=small --array=1 \
  sims/slurm/test_validation.slurm

# Monitor
squeue -u $USER

# Check job details
scontrol show job <JOBID>

# When complete, check output
ls -lh /n/scratch/users/${USER:0:1}/${USER}/surrogate-transportability/results/reps/covariate_shift/

# View logs
cat logs/test_*.out
```

**Expected:**
- Job completes in 3-5 minutes
- Output file created: `covariate_shift_small_rep0001.rds`
- No errors in log file

### Phase 2: Small Array Test (15-20 minutes)

```bash
# Submit 10-rep test for all studies (140 total jobs)
bash sims/slurm/submit_test_run.sh

# Monitor progress
watch -n 10 'squeue -u $USER | wc -l'

# After completion, check completeness
bash sims/slurm/check_completeness.sh covariate_shift
bash sims/slurm/check_completeness.sh selection_bias
bash sims/slurm/check_completeness.sh dirichlet_misspec
```

**Expected:**
- All 140 jobs complete successfully
- 140 .rds files created (10 per scenario × 14 scenarios)
- 0-2 failures acceptable (can resubmit)

### Phase 3: Resource Check

```bash
# Check resource usage for completed jobs
seff <JOBID>

# Look for:
# - Memory usage (should be < 4 GB)
# - CPU time (should be < 15 minutes)
# - CPU efficiency (should be > 90%)
```

**If memory usage > 4 GB:** Increase `--mem` in SLURM scripts to 8G

---

## Full Deployment

### Launch All Studies

```bash
# Navigate to project
cd ~/surrogate-transportability

# Source configuration
source sims/slurm/o2_config.sh

# Submit all validation studies (14,000 replications)
bash sims/slurm/submit_all_studies.sh
```

**Deployment Summary:**
- Total replications: 14,000
- Covariate shift: 4,000 (4 scenarios × 1,000 reps)
- Selection bias: 4,000 (4 scenarios × 1,000 reps)
- Dirichlet misspec: 6,000 (6 scenarios × 1,000 reps)

**Expected timeline:**
- With 100-200 cores: 12-20 hours wall time
- Core hours: ~1,400 hours total

### Submit Individual Studies

```bash
# Submit only covariate shift
bash sims/slurm/submit_all_covariate_shift.sh

# Submit only selection bias
bash sims/slurm/submit_all_selection_bias.sh

# Submit only Dirichlet misspecification
bash sims/slurm/submit_all_dirichlet_misspec.sh
```

---

## Monitoring

### Quick Status Check

```bash
# Count active jobs
squeue -u $USER | wc -l

# View all your jobs
squeue -u $USER

# Monitor in real-time (updates every 30 seconds)
watch -n 30 'squeue -u $USER | wc -l'
```

### Detailed Progress

```bash
# Check completeness per study
bash sims/slurm/check_completeness.sh covariate_shift
bash sims/slurm/check_completeness.sh selection_bias
bash sims/slurm/check_completeness.sh dirichlet_misspec
```

**Output shows:**
- Expected replications per scenario
- Found replications
- Missing replications with specific IDs
- Overall completion percentage

### Job Details

```bash
# Detailed job information
scontrol show job <JOBID>

# Resource efficiency
seff <JOBID>

# Cancel specific job
scancel <JOBID>

# Cancel all your jobs
scancel -u $USER

# Cancel specific array indices
scancel <JOBID>_[1-10]
```

### Log Files

```bash
# View most recent output log
tail -f logs/covariate_shift_*_*.out

# Check for errors
grep -i error logs/*.err

# Count completed replications
ls -1 /n/scratch/users/${USER:0:1}/${USER}/surrogate-transportability/results/reps/*/*.rds | wc -l
```

---

## Results Retrieval

### Aggregate Results on O2

```bash
# After all jobs complete, aggregate each study
Rscript sims/scripts/aggregate_results.R \
  --study-type covariate_shift \
  --input-dir /n/scratch/users/${USER:0:1}/${USER}/surrogate-transportability/results/reps/covariate_shift \
  --output-dir sims/results

Rscript sims/scripts/aggregate_results.R \
  --study-type selection_bias \
  --input-dir /n/scratch/users/${USER:0:1}/${USER}/surrogate-transportability/results/reps/selection_bias \
  --output-dir sims/results

Rscript sims/scripts/aggregate_results.R \
  --study-type dirichlet_misspec \
  --input-dir /n/scratch/users/${USER:0:1}/${USER}/surrogate-transportability/results/reps/dirichlet_misspec \
  --output-dir sims/results

# Generate combined validation report
Rscript sims/scripts/create_validation_report.R
```

### Download Results to Local Machine

```bash
# From local machine (not from O2)
# Use transfer.rc.hms.harvard.edu for file transfer

# Download aggregated results only (recommended, ~500 MB)
rsync -avz --progress \
  USERNAME@transfer.rc.hms.harvard.edu:~/surrogate-transportability/sims/results/ \
  ./local/results/

# Or download everything including individual reps (large, ~5-7 GB)
rsync -avz --progress \
  USERNAME@transfer.rc.hms.harvard.edu:/n/scratch/users/d/dagniel/surrogate-transportability/results/ \
  ./local/all-results/
```

**Note:** If you need to update code on O2 after local changes, push to GitHub first, then pull on O2:
```bash
# On local machine
git add .
git commit -m "Update simulation scripts"
git push

# On O2
cd ~/surrogate-transportability
git pull
```

### Clean Up Scratch Storage

```bash
# After downloading results, clean up scratch storage
# (Files auto-delete after 30 days, but manual cleanup frees space)

# Remove individual replications (keep aggregated results)
rm -rf /n/scratch/users/${USER:0:1}/${USER}/surrogate-transportability/results/reps/
```

---

## Troubleshooting

### Interactive Session for Debugging

To debug issues interactively:

```bash
# Start interactive session
srun --pty -p interactive -t 0-01:00 --mem 6G bash

# Load environment
cd ~/surrogate-transportability
source sims/slurm/o2_config.sh

# Test R package loading
R -e "devtools::load_all('package/')"

# Test single replication
Rscript sims/scripts/run_single_replication.R \
  --study-type covariate_shift --scenario small --replication 1 \
  --output-dir /n/scratch/users/d/dma12/surrogate-transportability/results/reps/covariate_shift \
  --n-baseline 300 --n-bootstrap 20 --n-mc-draws 10

# Exit when done
exit
```

### Module Loading Fails

**Error:** `R: command not found` or module load fails

**Solution:**
```bash
# Check available R versions
module spider R

# Check what R/4.4.2 requires
module spider R/4.4.2

# Load gcc first, then R
module load gcc/14.2.0
module load R/4.4.2
```

### Missing R Packages

**Error:** Package installation fails or packages not found

**Solution:**
```bash
# Set library path
export R_LIBS_USER=~/R/library
mkdir -p ~/R/library

# Install packages interactively
R
> install.packages(c('devtools', 'dplyr', 'tibble', 'optparse'), repos='https://cloud.r-project.org')
> devtools::install_deps('package/')
```

### Memory Exceeded

**Error:** Job killed with "OUT OF MEMORY" or similar

**Solution:**
```bash
# Increase memory in SLURM scripts from 6G to 8G
# Edit: sims/slurm/*_validation.slurm
#SBATCH --mem=8G
```

### Jobs Pending Too Long

**Issue:** Jobs stay in PENDING state for hours

**Check:**
```bash
# See why job is pending
squeue -u $USER -j <JOBID> --start

# Check partition limits
sinfo -p short

# Use different partition if needed
# Edit SLURM script:
#SBATCH --partition=medium  # or long
```

### Resubmit Failed Jobs

```bash
# Check which replications are missing
bash sims/slurm/check_completeness.sh covariate_shift

# Resubmit specific replications
bash sims/slurm/resubmit_failed.sh covariate_shift small "1,5,10-15"
bash sims/slurm/resubmit_failed.sh selection_bias weak_outcome "42,100-105"
```

### Disk Quota Exceeded

**Error:** Cannot write files, disk quota exceeded

**Solution:**
```bash
# Check disk usage
du -sh ~/*
quota

# If home directory full:
# 1. Ensure replications are in scratch (not home)
# 2. Remove large files from home
# 3. Clean up old logs
rm logs/*.out logs/*.err

# Verify scratch usage
du -sh /n/scratch/users/${USER:0:1}/${USER}/surrogate-transportability/
```

---

## Contact and Support

**HMS RC Support:**
- Email: rchelp@hms.harvard.edu
- Documentation: https://harvardmed.atlassian.net/wiki/spaces/O2/

**O2 Office Hours:**
- Check RC website for current schedule

**Project-Specific Issues:**
- Check project README.md
- Review session notes in `session_notes/`

---

## Quick Reference Card

```bash
# === LOGIN & CLONE ===
ssh USERNAME@o2.hms.harvard.edu
git clone https://github.com/denisagniel/surrogate-transportability.git
cd surrogate-transportability

# === SETUP ===
source sims/slurm/o2_config.sh
R -e "install.packages(c('devtools', 'dplyr', 'tibble', 'optparse', 'ggplot2', 'purrr'))"

# === TESTING ===
bash sims/slurm/submit_test_run.sh
watch -n 10 'squeue -u $USER | wc -l'
bash sims/slurm/check_completeness.sh covariate_shift

# === FULL RUN ===
bash sims/slurm/submit_all_studies.sh

# === MONITORING ===
squeue -u $USER
bash sims/slurm/check_completeness.sh <study_type>

# === RESUBMIT ===
bash sims/slurm/resubmit_failed.sh <study> <scenario> "1,5,10-15"

# === AGGREGATE ===
Rscript sims/scripts/aggregate_results.R --study-type covariate_shift

# === DOWNLOAD RESULTS ===
# From local machine, use transfer.rc.hms.harvard.edu
rsync -avz USERNAME@transfer.rc.hms.harvard.edu:~/surrogate-transportability/sims/results/ ./

# === UPDATE CODE ===
# On O2, pull latest changes from GitHub
git pull
```
