# Slurm Cluster Package: Complete

**Date:** 2026-03-26
**Status:** Ready for cluster submission

---

## ✅ What's Been Created

### Slurm Job Scripts (`slurm/`)
1. **`studies_quick_test.slurm`** ⭐ Test first (15 min)
2. **`studies_reduced.slurm`** ⭐ Recommended (3-4 hrs)
3. **`study1_finite_sample.slurm`** - Study 1 full (6-8 hrs)
4. **`study2_stress_testing.slurm`** - Study 2 full (4-6 hrs)
5. **`README.md`** - Slurm directory overview

### Documentation
1. **`SLURM_INSTRUCTIONS.md`** 📖 Complete guide (15 pages)
2. **`SLURM_QUICK_REFERENCE.md`** 📋 One-page cheat sheet
3. **`SLURM_PACKAGE_SUMMARY.md`** 📝 This file

### Helper Scripts
1. **`prepare_for_cluster.sh`** 🚀 Prep code for transfer (executable)

---

## 🎯 Quick Start (3 Steps)

### Step 1: Prepare Transfer (5 minutes)
```bash
# On your local machine
bash prepare_for_cluster.sh

# Transfer to cluster
scp surrogate-transportability-cluster.tar.gz username@cluster.edu:~/
```

### Step 2: Setup on Cluster (30 minutes, one-time)
```bash
# SSH to cluster
ssh username@cluster.edu

# Extract and setup
tar -xzf surrogate-transportability-cluster.tar.gz
cd surrogate-transportability-cluster

# Install R packages (see SLURM_INSTRUCTIONS.md)
srun --pty --mem=16G bash
module load R/4.3.0
R
# install.packages(...)
```

### Step 3: Run Jobs (3-4 hours)
```bash
# Quick test first
sbatch slurm/studies_quick_test.slurm

# If test passes, run reduced studies
sbatch slurm/studies_reduced.slurm

# Monitor
tail -f slurm/logs/studies_reduced_*.out
```

---

## 📁 File Structure

```
surrogate-transportability/
├── slurm/
│   ├── studies_quick_test.slurm      ⭐ Test (15 min)
│   ├── studies_reduced.slurm         ⭐ Recommended (3-4 hrs)
│   ├── study1_finite_sample.slurm    Study 1 full (6-8 hrs)
│   ├── study2_stress_testing.slurm   Study 2 full (4-6 hrs)
│   ├── logs/                         Job output logs
│   └── README.md
│
├── SLURM_INSTRUCTIONS.md             Complete guide
├── SLURM_QUICK_REFERENCE.md          One-page reference
├── prepare_for_cluster.sh            Transfer prep script
│
├── sims/
│   ├── scripts/
│   │   ├── 01_finite_sample_performance.R
│   │   ├── 02_stress_testing.R
│   │   ├── *_quick.R                 Quick test versions
│   │   └── utils/
│   └── results/                      Output directory
│
└── package/                          R package code
```

---

## 📊 Study Options

### Option A: Quick Test (15 min) ⚡
- **Purpose:** Verify setup works
- **Reps:** 20 per setting
- **Resources:** 4 cores, 16 GB
- **Command:** `sbatch slurm/studies_quick_test.slurm`
- **Use:** **ALWAYS RUN THIS FIRST**

### Option B: Reduced Studies (3-4 hrs) ⭐ RECOMMENDED
- **Purpose:** Complete validation
- **Reps:** 100 per setting (statistically valid)
- **Resources:** 9 cores, 32 GB
- **Command:** `sbatch slurm/studies_reduced.slurm`
- **Use:** **Best balance of speed and completeness**

### Option C: Full Studies (6-8 hrs) 🔬
- **Purpose:** Maximum precision
- **Reps:** 500 per setting
- **Resources:** 9 cores, 32 GB
- **Commands:** 
  - `sbatch slurm/study1_finite_sample.slurm`
  - `sbatch slurm/study2_stress_testing.slurm`
- **Use:** If reviewers request or top-tier journal

---

## 🎓 What Each Study Does

### Study 1: Finite Sample Performance
**Question:** Do the methods work correctly?
- Tests: Coverage (~95%), bias (~0), consistency
- Settings: 4 sample sizes × 4 lambdas × 3 scenarios = 48
- Output: `finite_sample_results.rds`

### Study 2: Stress Testing
**Question:** Where do the methods break?
- Tests: Small n, extreme λ, weak signal, high heterogeneity
- Conditions: 21 stress scenarios
- Output: `stress_test_results.rds`

### Study 3: Classification (ALREADY COMPLETE ✓)
**Question:** Do we classify transportability correctly?
- Result: 71% accuracy vs 38% for traditional methods
- Files: Already in `sims/results/classification_*`

---

## ⚙️ Resource Requirements

| Version | Time | Cores | Memory | CPU-hours |
|---------|------|-------|--------|-----------|
| Quick test | 15 min | 4 | 16 GB | 1 |
| Reduced | 3-4 hrs | 9 | 32 GB | 30 |
| Study 1 full | 6-8 hrs | 9 | 32 GB | 60 |
| Study 2 full | 4-6 hrs | 9 | 32 GB | 40 |

---

## 📝 Customization Required

Before submitting, edit these in `.slurm` files:

1. **Email:** Change `your.email@example.com` to your email
2. **Modules:** Update `module load R/4.3.0` for your cluster
3. **Partition:** Add `#SBATCH --partition=name` if needed

**Quick fix all emails:**
```bash
sed -i 's/your.email@example.com/yourname@domain.com/g' slurm/*.slurm
```

---

## 🔍 Monitoring

### Check Job Status
```bash
squeue -u $USER                    # Your jobs
scontrol show job JOBID            # Detailed info
```

### Watch Progress
```bash
JOBID=$(squeue -u $USER -h -o %i | head -1)
tail -f slurm/logs/studies_reduced_$JOBID.out
```

### After Completion
```bash
ls -lh sims/results/*.rds          # Check outputs
seff JOBID                         # Check efficiency
```

---

## 📥 Retrieving Results

From your local machine:
```bash
# Download results
rsync -avz username@cluster.edu:~/surrogate-transportability-cluster/sims/results/ \
  ~/RAND/rprojects/surrogates/surrogate-transportability/sims/results/

# Verify
ls -lh sims/results/*.rds
```

---

## ✅ Success Checklist

### Before Submitting
- [ ] Code transferred to cluster
- [ ] Email address updated in .slurm files
- [ ] Module names adjusted for cluster
- [ ] R packages installed (interactive session)
- [ ] `slurm/logs/` directory exists

### After Quick Test
- [ ] Quick test completed successfully
- [ ] Output files created in `sims/results/`
- [ ] No errors in log files

### After Full Run
- [ ] Jobs completed (check `squeue`)
- [ ] Result files downloaded
- [ ] File sizes reasonable (1-10 MB)
- [ ] Generate tables: `Rscript sims/scripts/utils/create_tables.R`
- [ ] Update manuscript Section 5

---

## 🆘 Troubleshooting

| Problem | Solution |
|---------|----------|
| Job pending forever | Reduce resources or try different partition |
| Job failed immediately | Check error log, verify module names |
| R package install fails | Request interactive session with more memory |
| No output files | Check job log for errors, verify disk space |
| Out of memory | Increase `--mem` or reduce `--cpus-per-task` |

**Full troubleshooting guide:** See `SLURM_INSTRUCTIONS.md` pages 10-12

---

## 📚 Documentation

| File | Purpose | Length |
|------|---------|--------|
| `SLURM_INSTRUCTIONS.md` | Complete guide | 15 pages |
| `SLURM_QUICK_REFERENCE.md` | Quick commands | 1 page |
| `slurm/README.md` | Slurm dir info | 1 page |
| `STUDIES_1_AND_2_PACKAGE.md` | Technical specs | 12 pages |
| `NEXT_STEPS.md` | Decision tree | 10 pages |

**Read first:** `SLURM_QUICK_REFERENCE.md` (1 page)
**For details:** `SLURM_INSTRUCTIONS.md` (complete walkthrough)

---

## 🎯 Recommended Workflow

1. **Local prep** (5 min): Run `prepare_for_cluster.sh`
2. **Transfer** (5 min): `scp` or `rsync` to cluster
3. **One-time setup** (30 min): Install R packages
4. **Quick test** (15 min): Verify everything works
5. **Submit reduced** (3-4 hrs): Let it run
6. **Download** (5 min): Get results back
7. **Generate outputs** (30 min): Tables and figures
8. **Update manuscript** (1 hr): Add to Section 5

**Total:** ~6 hours (mostly hands-off)

---

## 💡 Pro Tips

- **Always run quick test first** - catches issues early
- **Use reduced version** - 100 reps is plenty for validation
- **Submit during off-hours** - faster queue times
- **Monitor occasionally** - check every 30-60 minutes
- **Save job IDs** - easier to track and debug

---

## 🚀 Ready to Go!

Everything is prepared. To start:

```bash
bash prepare_for_cluster.sh
```

Then follow prompts and see `SLURM_QUICK_REFERENCE.md` for next steps.

**Questions?** See `SLURM_INSTRUCTIONS.md` sections:
- Setup: Pages 2-3
- Submission: Pages 4-5
- Monitoring: Pages 6-7
- Troubleshooting: Pages 10-12
