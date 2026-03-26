# Slurm Job Scripts for Studies 1 & 2

This directory contains Slurm batch scripts for running simulation studies on an HPC cluster.

## Files

### Job Scripts
- **`studies_quick_test.slurm`** - Quick test (15 min) ⭐ **RUN THIS FIRST**
- **`studies_reduced.slurm`** - Reduced studies (3-4 hrs) ⭐ **RECOMMENDED**
- **`study1_finite_sample.slurm`** - Study 1 full version (6-8 hrs)
- **`study2_stress_testing.slurm`** - Study 2 full version (4-6 hrs)

### Logs
- **`logs/`** - Output and error logs (created when jobs run)

## Quick Start

```bash
# 1. Create logs directory
mkdir -p logs

# 2. Edit email address
sed -i 's/your.email@example.com/youremail@domain.com/g' *.slurm

# 3. Submit quick test
sbatch studies_quick_test.slurm

# 4. If test passes, submit reduced studies
sbatch studies_reduced.slurm

# 5. Monitor
squeue -u $USER
tail -f logs/studies_reduced_*.out
```

## Resource Requirements

| Script | Time | Cores | Memory | CPU-hrs |
|--------|------|-------|--------|---------|
| Quick test | 30 min | 4 | 16 GB | 2 |
| Reduced | 3-4 hrs | 9 | 32 GB | 30 |
| Study 1 full | 6-8 hrs | 9 | 32 GB | 60 |
| Study 2 full | 4-6 hrs | 9 | 32 GB | 40 |

## Customization

Before submitting, adjust:

1. **Email:** Change `--mail-user` to your email
2. **Modules:** Update `module load` commands for your cluster
3. **Partition:** Add `#SBATCH --partition=name` if needed
4. **Resources:** Adjust `--cpus-per-task` and `--mem` as needed

## Full Documentation

See `../SLURM_INSTRUCTIONS.md` for complete setup and usage instructions.
