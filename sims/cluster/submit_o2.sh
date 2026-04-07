#!/bin/bash
#SBATCH --job-name=tv_coverage
#SBATCH --output=sims/cluster/logs/job_%a.out
#SBATCH --error=sims/cluster/logs/job_%a.err
#SBATCH --array=1-315
#SBATCH --time=00:15:00
#SBATCH --mem=2G
#SBATCH --cpus-per-task=1
#SBATCH --partition=short

# TV Ball Coverage Verification - O2 Cluster Submission
#
# Usage: sbatch sims/cluster/submit_o2.sh
#
# Array job: runs 315 jobs (5 n × 3 λ × 7 M × 3 functionals)
# Each job: 100 replications, ~3-5 min

echo "Job ID: $SLURM_ARRAY_TASK_ID"
echo "Started at: $(date)"
echo "Running on node: $(hostname)"
echo ""

# Load required modules
module load gcc/14.2.0
module load R/4.4.2

# Set working directory to project root
cd $SLURM_SUBMIT_DIR
echo "Working directory: $(pwd)"
echo ""

# Run R script with job ID
Rscript sims/cluster/29_tv_coverage_cluster.R $SLURM_ARRAY_TASK_ID

echo ""
echo "Finished at: $(date)"
