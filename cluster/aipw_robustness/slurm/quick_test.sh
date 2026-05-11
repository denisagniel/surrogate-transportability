#!/bin/bash
# Quick Test: Validate AIPW Robustness Infrastructure
#
# Runs a minimal test (2 settings × 10 reps = 20 total) to verify:
# 1. R script runs without errors
# 2. Package loads correctly
# 3. AIPW method works
# 4. Results format is correct
# 5. File paths work on cluster
#
# Runtime: ~1-2 minutes
#
# Usage: bash quick_test.sh

set -e

echo "========================================================================"
echo "AIPW Robustness Study: Quick Test"
echo "========================================================================"
echo "Running minimal test:"
echo "  - Scenario 0 (Oracle): n=1000, α₁=0.3"
echo "  - Scenario 3 (Both noisy): n=1000, α₁=0.3, α_e=0.5, α_μ=0.5"
echo "  - 10 replications per setting"
echo "  - 5 reps per job (2 jobs per setting)"
echo ""
echo "Expected: 4 jobs (2 settings × 2 jobs)"
echo "Runtime: ~1-2 minutes"
echo "========================================================================"
echo ""

# Test parameters
N_TEST=1000
ALPHA_1_TEST=0.3
ALPHA_E_TEST=0.5
ALPHA_MU_TEST=0.5
REPS_PER_JOB=5
TOTAL_REPS=10
N_ARRAY_JOBS=2  # 10 reps / 5 per job = 2 jobs

# Create logs directory
mkdir -p logs

echo "Test 1: Scenario 0 (Oracle) - n=$N_TEST, α₁=$ALPHA_1_TEST"
JOB_ID_0=$(sbatch --parsable --array=1-${N_ARRAY_JOBS} \
           --export=SCENARIO=0,N=$N_TEST,ALPHA_1=$ALPHA_1_TEST,REPS_PER_JOB=$REPS_PER_JOB,TOTAL_REPS=$TOTAL_REPS \
           run_simulations.slurm)
echo "  Submitted: Job $JOB_ID_0"
sleep 0.5

echo ""
echo "Test 2: Scenario 3 (Both noisy) - n=$N_TEST, α₁=$ALPHA_1_TEST, α_e=$ALPHA_E_TEST, α_μ=$ALPHA_MU_TEST"
JOB_ID_3=$(sbatch --parsable --array=1-${N_ARRAY_JOBS} \
           --export=SCENARIO=3,N=$N_TEST,ALPHA_1=$ALPHA_1_TEST,ALPHA_E=$ALPHA_E_TEST,ALPHA_MU=$ALPHA_MU_TEST,C_E=1.0,C_MU=1.0,REPS_PER_JOB=$REPS_PER_JOB,TOTAL_REPS=$TOTAL_REPS \
           run_simulations.slurm)
echo "  Submitted: Job $JOB_ID_3"

echo ""
echo "========================================================================"
echo "Quick test launched!"
echo ""
echo "Monitor with:"
echo "  squeue -j $JOB_ID_0,$JOB_ID_3"
echo "  watch -n 5 'squeue -u \$USER | grep aipw'"
echo ""
echo "Check logs:"
echo "  tail -f logs/aipw_${JOB_ID_0}_*.out"
echo "  tail -f logs/aipw_${JOB_ID_3}_*.out"
echo ""
echo "After completion (~1-2 min), check results:"
echo "  ls -lh results/"
echo "  Rscript -e \"readRDS(list.files('results', pattern='batch.*\\\\.rds', recursive=TRUE, full.names=TRUE)[1])\""
echo "========================================================================"
