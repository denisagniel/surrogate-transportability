# Slurm Quick Reference Card

## Prepare for Transfer (Local Machine)

```bash
# Run preparation script
bash prepare_for_cluster.sh

# Transfer to cluster
scp surrogate-transportability-cluster.tar.gz username@cluster.edu:~/
```

---

## On Cluster (One-Time Setup)

```bash
# Extract
tar -xzf surrogate-transportability-cluster.tar.gz
cd surrogate-transportability-cluster

# Install R packages (interactive session)
srun --pty --mem=16G --cpus-per-task=4 --time=01:00:00 bash
module load R/4.3.0
R
```

```r
install.packages(c('devtools', 'tidyverse', 'furrr', 'progressr', 'here'),
                 repos='http://cran.rstudio.com/')
quit(save="no")
```

---

## Submit Jobs

```bash
# 1. Quick test (REQUIRED - 15 min)
sbatch slurm/studies_quick_test.slurm

# 2. Reduced studies (RECOMMENDED - 3-4 hrs)
sbatch slurm/studies_reduced.slurm

# OR full studies separately
sbatch slurm/study1_finite_sample.slurm  # 6-8 hrs
sbatch slurm/study2_stress_testing.slurm # 4-6 hrs
```

---

## Monitor Jobs

```bash
# Check status
squeue -u $USER

# Watch output
JOBID=$(squeue -u $USER -h -o %i | head -1)
tail -f slurm/logs/studies_reduced_$JOBID.out

# Check progress every 30 min
watch -n 1800 'tail -20 slurm/logs/studies_reduced_*.out'
```

---

## After Completion

```bash
# On cluster: verify outputs
ls -lh sims/results/*.rds

# From local machine: download
rsync -avz username@cluster.edu:~/surrogate-transportability-cluster/sims/results/ \
  ~/RAND/rprojects/surrogates/surrogate-transportability/sims/results/
```

---

## Common Commands

### Job Control
```bash
squeue -u $USER              # Your jobs
scontrol show job JOBID      # Job details
scancel JOBID                # Cancel job
seff JOBID                   # Efficiency (after completion)
```

### Cluster Info
```bash
sinfo                        # Partition status
sinfo -Nel                   # Node list
sacct -u $USER               # Job history
```

### File Transfer
```bash
# Upload
rsync -avz local/ user@cluster:~/remote/

# Download
rsync -avz user@cluster:~/remote/ local/
```

---

## Troubleshooting

### Job Won't Start
- Check: `squeue -u $USER` for reason
- Try: Reduce resources in .slurm file
- Try: Different partition `--partition=short`

### Job Failed
- Check: `cat slurm/logs/JOBNAME_JOBID.err`
- Check: Module names correct
- Check: R packages installed

### No Output Files
- Check: Job completed successfully
- Check: `ls -lh sims/results/`
- Check: Disk space `df -h ~`

---

## Quick Test Checklist

- [ ] Code transferred to cluster
- [ ] Email updated in .slurm files
- [ ] Logs directory created
- [ ] R packages installed
- [ ] Quick test submitted
- [ ] Quick test passed
- [ ] Reduced studies submitted
- [ ] Jobs monitored
- [ ] Results downloaded
- [ ] Manuscript updated

---

## Expected Timeline

| Action | Time |
|--------|------|
| Transfer code | 5 min |
| Setup (one-time) | 30 min |
| Quick test | 15 min |
| Reduced studies | 3-4 hrs |
| Download results | 5 min |
| Generate tables | 30 min |
| **Total** | **~5 hours** |

---

## File Locations

**On Cluster:**
- Code: `~/surrogate-transportability-cluster/`
- Results: `~/surrogate-transportability-cluster/sims/results/`
- Logs: `~/surrogate-transportability-cluster/slurm/logs/`

**Local:**
- Results: `sims/results/`
- Tables: `sims/results/*.tex`
- Figures: `sims/results/*.pdf`

---

## Support

**Documentation:**
- Full instructions: `SLURM_INSTRUCTIONS.md`
- Package details: `STUDIES_1_AND_2_PACKAGE.md`
- Next steps: `NEXT_STEPS.md`

**Cluster Help:**
```bash
man sbatch
# Or contact: cluster-support@institution.edu
```
