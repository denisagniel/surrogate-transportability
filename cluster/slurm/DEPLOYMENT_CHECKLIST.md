# Deployment Checklist: O2 Cluster Simulations

## Pre-Deployment (Local)

- [ ] **Infrastructure generated**
  - [x] `run_single_replication.R` - Core simulation script
  - [x] `run_simulations.slurm` - SLURM batch script
  - [x] `launch_all_simulations.sh` - Submit all jobs
  - [x] `quick_test.sh` - Quick test script
  - [x] `check_progress.sh` - Progress monitoring
  - [x] `combine_results.R` - Result aggregation
  - [x] `README_O2.md` - Complete documentation
  - [x] `DEPLOYMENT_CHECKLIST.md` - This file

- [ ] **Configuration updated**
  - [x] `cluster/config/dgp_specifications.yaml` includes dgp1, dgp2, dgp4
  - [x] All DGP parameters match validation results
  - [x] True correlations documented (dgp1: 0.691, dgp2: -0.884, dgp4: 1.000)
  - [x] True PTEs documented (dgp1: 81.6%, dgp2: 53.1%, dgp4: 30.0%)

- [ ] **Package ready**
  - [ ] `R/tv_ball_correlation_IF_adaptive.R` has `@export`
  - [ ] Run `devtools::document()` to update NAMESPACE
  - [ ] Package passes `R CMD check` (or at minimum loads without errors)

- [ ] **Local test passed**
  - [ ] Run `bash cluster/slurm/quick_test.sh` locally
  - [ ] Test completes in ~10-12 minutes
  - [ ] Output file created with correct structure
  - [ ] Both reps converge successfully

- [ ] **Code committed and pushed**
  - [ ] `git add cluster/slurm/`
  - [ ] `git add cluster/config/dgp_specifications.yaml`
  - [ ] `git commit -m "Add O2 cluster simulation infrastructure"`
  - [ ] `git push origin main`

---

## Deployment (On O2)

- [ ] **Login and navigate**
  ```bash
  ssh [username]@o2.hms.harvard.edu
  cd /path/to/surrogate-transportability
  ```

- [ ] **Pull latest code**
  ```bash
  git pull origin main
  ```

- [ ] **Load modules**
  ```bash
  module load gcc/14.2.0
  module load R/4.4.2
  ```

- [ ] **Install package**
  ```bash
  R CMD INSTALL .
  ```

- [ ] **Verify installation**
  ```bash
  Rscript -e "library(surrogateTransportability); ls('package:surrogateTransportability')" | grep tv_ball
  ```
  Should show: `tv_ball_correlation_IF_adaptive`

- [ ] **Create directories**
  ```bash
  mkdir -p cluster/results/{dgp1,dgp2,dgp4}
  mkdir -p cluster/slurm/logs
  ```

- [ ] **Set permissions**
  ```bash
  chmod +x cluster/slurm/*.sh
  ```

- [ ] **Run quick test on O2**
  ```bash
  bash cluster/slurm/quick_test.sh
  ```
  - [ ] Test passes in ~10-12 minutes
  - [ ] No module errors
  - [ ] No package errors
  - [ ] Output structure correct

---

## Launch

- [ ] **Submit jobs**
  ```bash
  bash cluster/slurm/launch_all_simulations.sh
  ```

- [ ] **Verify submission**
  ```bash
  squeue -u $USER
  ```
  Should show ~300 jobs (or fewer if running/pending)

- [ ] **Check initial progress** (after 10-15 minutes)
  ```bash
  bash cluster/slurm/check_progress.sh
  ```
  - [ ] Some jobs running
  - [ ] Some results appearing in `cluster/results/*/`

- [ ] **Monitor logs** (check for errors)
  ```bash
  tail cluster/slurm/logs/*.out
  tail cluster/slurm/logs/*.err
  ```

---

## Monitoring

- [ ] **Check progress every 15-30 minutes**
  ```bash
  bash cluster/slurm/check_progress.sh
  ```

- [ ] **Expected timeline**
  - [ ] After 15 min: ~25% complete
  - [ ] After 30 min: ~50% complete
  - [ ] After 45 min: ~75% complete
  - [ ] After 60 min: ~95-100% complete

- [ ] **Watch for issues**
  - [ ] Any jobs with FAILED status
  - [ ] Any jobs hitting time limit
  - [ ] Any jobs hitting memory limit
  - [ ] Check error logs if issues found

---

## Post-Completion

- [ ] **Verify all results present**
  ```bash
  bash cluster/slurm/check_progress.sh
  ```
  Should show: "ALL JOBS COMPLETE!"

- [ ] **Check result counts**
  ```bash
  ls cluster/results/dgp1/batch_*.rds | wc -l  # Should be 100
  ls cluster/results/dgp2/batch_*.rds | wc -l  # Should be 100
  ls cluster/results/dgp4/batch_*.rds | wc -l  # Should be 100
  ```

- [ ] **Combine results**
  ```bash
  Rscript cluster/slurm/combine_results.R
  ```

- [ ] **Review summary report**
  - [ ] All DGPs have ~1000 reps
  - [ ] Bias within acceptable range (< ±10%)
  - [ ] Coverage near 95%
  - [ ] SE calibration near 1.0
  - [ ] Convergence rate > 95%

- [ ] **Save combined results**
  ```bash
  # Option 1: Copy to local
  scp [username]@o2.hms.harvard.edu:/path/to/cluster/results/combined_results.rds ./cluster/results/

  # Option 2: Commit to git (if small)
  git add cluster/results/combined_results.rds
  git commit -m "Add cluster simulation results"
  git push
  ```

---

## Troubleshooting

### Package not found

```bash
# Reinstall
module load gcc/14.2.0 R/4.4.2
R CMD INSTALL . --no-test-load
```

### Jobs timeout

```bash
# Check which batches are slow
grep "Total time" cluster/slurm/logs/*.out | sort -t: -k2 -n | tail -20

# If needed, increase time limit in run_simulations.slurm
# Then resubmit failed jobs
```

### Missing results

```bash
# Find missing batches
for dgp in dgp1 dgp2 dgp4; do
  echo "=== $dgp ==="
  for i in {1..100}; do
    FILE=$(printf "cluster/results/$dgp/batch_%03d.rds" $i)
    [ ! -f "$FILE" ] && echo "  Missing: batch_$i"
  done
done

# Resubmit specific batches
sbatch --array=42 --export=DGP_ID=dgp1 cluster/slurm/run_simulations.slurm
```

---

## Success Criteria

✅ All 300 jobs completed successfully
✅ All 3000 replications present (3 DGPs × 1000 reps)
✅ Combined results show:
  - Bias < ±10% for all DGPs
  - Coverage 90-96% for all DGPs
  - SE calibration 0.9-1.1 for all DGPs
  - Convergence rate > 95%

---

## Timeline Summary

- **Setup**: 15-20 minutes (package install, test)
- **Launch**: 2 minutes (submit jobs)
- **Execution**: 60 minutes (parallel jobs)
- **Combination**: 2 minutes (aggregate results)
- **Total**: ~80 minutes from start to final results

---

## Notes

- First time running: Plan for 90-120 minutes total
- Subsequent runs: Can be as fast as 60-70 minutes
- Monitor first few batches closely to catch issues early
- If issues arise, check logs immediately (don't wait for completion)
