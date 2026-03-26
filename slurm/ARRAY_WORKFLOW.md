# Slurm Job Array Workflow

**New approach:** Each parameter combination runs as a separate Slurm job (no R parallelization). Much better for HPC clusters.

## Overview

**Study 1:** 48 array tasks (4 n × 3 scenarios × 4 lambda)
**Study 2:** 21 array tasks (5 stress types with varying conditions)

Each task:
- Uses 1 CPU core
- Runs N_REPS replications sequentially
- Saves results to `sims/results/study[1|2]_array/task_XXX.rds`
- After all tasks complete, aggregate into final results

---

## Quick Test (5-10 minutes)

Test the workflow before full runs:

```bash
# Study 1 quick test: 8 tasks × 20 reps = 160 total
sbatch slurm/study1_array_quick.slurm

# Study 2 quick test: 5 tasks × 20 reps = 100 total
sbatch slurm/study2_array_quick.slurm

# Monitor progress
squeue -u $USER

# After completion, aggregate
sbatch slurm/aggregate_results.slurm

# Check results
ls -lh sims/results/*.rds
```

---

## Full Studies (~2 hours)

```bash
# Study 1: 48 tasks × 500 reps = 24,000 total
sbatch slurm/study1_array.slurm

# Study 2: 21 tasks × 500 reps = 10,500 total
sbatch slurm/study2_array.slurm

# All tasks run in parallel across cluster
# Monitor progress
watch -n 60 'squeue -u $USER | grep "study[12]_array"'

# Check how many tasks completed
ls sims/results/study1_array/ | wc -l  # Should reach 48
ls sims/results/study2_array/ | wc -l  # Should reach 21

# After all tasks complete, aggregate
sbatch slurm/aggregate_results.slurm

# Verify final results
ls -lh sims/results/finite_sample_results.rds
ls -lh sims/results/stress_test_results.rds
```

---

## Monitoring Progress

### Check job status
```bash
# All your jobs
squeue -u $USER

# Study 1 tasks
squeue -u $USER -n study1_array

# Study 2 tasks
squeue -u $USER -n study2_array

# Count running/pending/completed
squeue -u $USER -n study1_array -t RUNNING | wc -l
squeue -u $USER -n study1_array -t PENDING | wc -l
```

### Check completed tasks
```bash
# Study 1 (should reach 48)
ls sims/results/study1_array/ | wc -l

# Study 2 (should reach 21)
ls sims/results/study2_array/ | wc -l

# View individual task result
head -20 slurm/logs/study1_array_*_1.out
tail -20 slurm/logs/study1_array_*_1.out
```

### Check for failures
```bash
# Failed jobs in last day
sacct -u $USER -S $(date -d '1 day ago' +%Y-%m-%d) --format=JobID,JobName,State,ExitCode | grep FAILED

# View error logs for failed task
cat slurm/logs/study1_array_*_5.err
```

---

## Resubmitting Failed Tasks

If some tasks fail, you can resubmit just those:

```bash
# Resubmit task 5 only
sbatch --array=5 slurm/study1_array.slurm

# Resubmit multiple tasks
sbatch --array=5,12,23 slurm/study1_array.slurm

# Resubmit range
sbatch --array=5-10 slurm/study1_array.slurm
```

---

## Resource Usage

**Per task:**
- 1 CPU core
- 8 GB memory (4 GB for quick tests)
- 30 min - 2 hours walltime
- ~50 MB output file

**Total for full studies:**
- Study 1: 48 tasks × 2 hours = 96 CPU-hours (but parallel, so ~2 hours wallclock)
- Study 2: 21 tasks × 2 hours = 42 CPU-hours (but parallel, so ~2 hours wallclock)
- Aggregation: 1 task × 30 min = 0.5 CPU-hours

---

## File Structure

```
sims/
├── results/
│   ├── study1_array/
│   │   ├── task_001.rds     # Individual task results
│   │   ├── task_002.rds
│   │   └── ...
│   ├── study2_array/
│   │   ├── task_001.rds
│   │   └── ...
│   ├── finite_sample_results.rds   # Aggregated Study 1
│   └── stress_test_results.rds     # Aggregated Study 2
└── scripts/
    └── array/
        ├── 01_finite_sample_single_task.R
        ├── 02_stress_testing_single_task.R
        ├── aggregate_study1.R
        └── aggregate_study2.R

slurm/
├── logs/
│   ├── study1_array_12345_01.out   # Logs for each task
│   ├── study1_array_12345_01.err
│   └── ...
├── study1_array.slurm
├── study2_array.slurm
├── study1_array_quick.slurm
├── study2_array_quick.slurm
└── aggregate_results.slurm
```

---

## Advantages of Array Jobs

1. **Better cluster utilization** - Tasks spread across available nodes
2. **Easy progress tracking** - Each task completes independently
3. **Fault tolerance** - Failed tasks don't affect others
4. **Easy resubmission** - Rerun only failed tasks
5. **No R parallelization issues** - Single core per task
6. **Cleaner logs** - One log per task
7. **Faster overall** - True parallelization at job level

---

## Troubleshooting

### No output files after job completes

```bash
# Check logs for errors
cat slurm/logs/study1_array_*_1.out
cat slurm/logs/study1_array_*_1.err

# Common issues:
# - Package not installed
# - Wrong working directory
# - Output directory doesn't exist
```

### Aggregation fails

```bash
# Make sure all tasks completed
ls sims/results/study1_array/ | wc -l  # Should be 48 for Study 1

# Check which tasks are missing
for i in {1..48}; do
  file=$(printf "sims/results/study1_array/task_%03d.rds" $i)
  [ ! -f "$file" ] && echo "Missing: task $i"
done
```

### Tasks taking too long

```bash
# Check resource usage of running task
sstat -j JOBID.TASKID --format=AveCPU,AveRSS,MaxRSS

# May need to increase time limit or memory
```

---

## Next Steps After Results

1. **Verify results:** Check that aggregated files exist and are reasonable size
2. **Generate tables/figures:** Use utility scripts (to be created)
3. **Update manuscript:** Integrate results into Section 5

---

## Comparison: Old vs New

| Aspect | Old (Parallel R) | New (Job Arrays) |
|--------|------------------|------------------|
| CPU cores per job | 9 | 1 |
| Jobs submitted | 1-2 | 48-69 |
| R parallelization | furrr (9 workers) | None |
| Monitoring | Hard (one log) | Easy (one log per task) |
| Fault tolerance | Lose all if fails | Lose only failed tasks |
| Total walltime | 3-8 hours | 1-2 hours |
| Cluster efficiency | Poor | Excellent |
