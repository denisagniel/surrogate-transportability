#!/bin/bash
# Launch AIPW Robustness Simulations for a Specific Scenario
#
# Usage: bash launch_scenario.sh <scenario_number> [total_reps] [mode]
#
# Arguments:
#   scenario_number: 0 (oracle), 1 (propensity), 2 (outcome), 3 (both)
#   total_reps: Total replications per setting (default: 1000)
#   mode: "auto" (sample-size-specific reps/job) or number (fixed reps/job)
#
# Examples:
#   bash launch_scenario.sh 0                  # Oracle, auto reps/job, 1000 total
#   bash launch_scenario.sh 3 1000 auto        # Scenario 3, auto (recommended)
#   bash launch_scenario.sh 0 100 10           # Quick test: 10 reps/job, 100 total
#
# Auto mode keeps jobs < 12 hours by adjusting reps per job based on sample size:
#   n=500,1000:   200 reps/job
#   n=2000:       150 reps/job
#   n=5000:       100 reps/job
#   n=10000:      80 reps/job

set -e  # Exit on error

SCENARIO=${1:-0}
TOTAL_REPS=${2:-1000}
MODE=${3:-auto}

# Validate scenario
if [ $SCENARIO -lt 0 ] || [ $SCENARIO -gt 3 ]; then
  echo "Error: Scenario must be 0, 1, 2, or 3"
  exit 1
fi

# Function to get reps per job based on sample size (auto mode)
get_reps_per_job() {
  local n=$1
  if [ "$MODE" = "auto" ]; then
    case $n in
      500|1000)
        echo 200
        ;;
      2000)
        echo 150
        ;;
      5000)
        echo 100
        ;;
      10000)
        echo 80
        ;;
      *)
        echo 100  # Default fallback
        ;;
    esac
  else
    echo $MODE  # Use fixed value
  fi
}

echo "========================================================================"
echo "Launching AIPW Robustness Study - Scenario $SCENARIO"
echo "========================================================================"
echo "Configuration:"
echo "  Scenario: $SCENARIO"
echo "  Total reps per setting: $TOTAL_REPS"
if [ "$MODE" = "auto" ]; then
  echo "  Mode: Auto (sample-size-specific reps/job)"
  echo "    n=500,1000: 200 reps/job → ~5-10 hrs"
  echo "    n=2000:     150 reps/job → ~5-10 hrs"
  echo "    n=5000:     100 reps/job → ~5-10 hrs"
  echo "    n=10000:    80 reps/job  → ~5-11 hrs"
else
  echo "  Mode: Fixed ($MODE reps/job)"
fi
echo ""

# Grid parameters (from config)
N_VALUES=(500 1000 2000 5000 10000)
ALPHA_1_VALUES=(0.0 0.3 0.6)
ALPHA_E_VALUES=(0.0 0.25 0.5 0.75)
ALPHA_MU_VALUES=(0.0 0.25 0.5 0.75)
C_E_VALUES=(0.5 1.0 2.0)
C_MU_VALUES=(0.5 1.0 2.0)

# Create logs directory
mkdir -p logs

# Counter for submitted jobs
JOB_COUNT=0

# Scenario 0: Oracle (no noise parameters needed)
if [ $SCENARIO -eq 0 ]; then
  echo "Scenario 0: Oracle (true nuisances)"
  echo "Settings: ${#N_VALUES[@]} n × ${#ALPHA_1_VALUES[@]} α₁ = $((${#N_VALUES[@]} * ${#ALPHA_1_VALUES[@]}))"
  echo ""

  for N in "${N_VALUES[@]}"; do
    # Get reps per job for this sample size
    REPS_PER_JOB=$(get_reps_per_job $N)
    N_ARRAY_JOBS=$(( (TOTAL_REPS + REPS_PER_JOB - 1) / REPS_PER_JOB ))

    for ALPHA_1 in "${ALPHA_1_VALUES[@]}"; do
      echo "Submitting: n=$N, α₁=$ALPHA_1 ($REPS_PER_JOB reps/job, $N_ARRAY_JOBS jobs)"
      sbatch --array=1-${N_ARRAY_JOBS} \
             --export=SCENARIO=$SCENARIO,N=$N,ALPHA_1=$ALPHA_1,REPS_PER_JOB=$REPS_PER_JOB,TOTAL_REPS=$TOTAL_REPS \
             run_simulations.slurm
      JOB_COUNT=$((JOB_COUNT + 1))
      sleep 0.1  # Avoid overwhelming scheduler
    done
  done

# Scenario 1: Propensity noise only
elif [ $SCENARIO -eq 1 ]; then
  echo "Scenario 1: Propensity noise (noisy e(X), true μ(X))"
  SETTINGS=$(( ${#N_VALUES[@]} * ${#ALPHA_1_VALUES[@]} * ${#ALPHA_E_VALUES[@]} * ${#C_E_VALUES[@]} ))
  echo "Settings: ${#N_VALUES[@]} n × ${#ALPHA_1_VALUES[@]} α₁ × ${#ALPHA_E_VALUES[@]} α_e × ${#C_E_VALUES[@]} c_e = $SETTINGS"
  echo ""

  for N in "${N_VALUES[@]}"; do
    # Get reps per job for this sample size
    REPS_PER_JOB=$(get_reps_per_job $N)
    N_ARRAY_JOBS=$(( (TOTAL_REPS + REPS_PER_JOB - 1) / REPS_PER_JOB ))

    for ALPHA_1 in "${ALPHA_1_VALUES[@]}"; do
      for ALPHA_E in "${ALPHA_E_VALUES[@]}"; do
        for C_E in "${C_E_VALUES[@]}"; do
          echo "Submitting: n=$N, α₁=$ALPHA_1, α_e=$ALPHA_E, c_e=$C_E ($REPS_PER_JOB reps/job, $N_ARRAY_JOBS jobs)"
          sbatch --array=1-${N_ARRAY_JOBS} \
                 --export=SCENARIO=$SCENARIO,N=$N,ALPHA_1=$ALPHA_1,ALPHA_E=$ALPHA_E,C_E=$C_E,REPS_PER_JOB=$REPS_PER_JOB,TOTAL_REPS=$TOTAL_REPS \
                 run_simulations.slurm
          JOB_COUNT=$((JOB_COUNT + 1))
          sleep 0.1
        done
      done
    done
  done

# Scenario 2: Outcome noise only
elif [ $SCENARIO -eq 2 ]; then
  echo "Scenario 2: Outcome noise (true e(X), noisy μ(X))"
  SETTINGS=$(( ${#N_VALUES[@]} * ${#ALPHA_1_VALUES[@]} * ${#ALPHA_MU_VALUES[@]} * ${#C_MU_VALUES[@]} ))
  echo "Settings: ${#N_VALUES[@]} n × ${#ALPHA_1_VALUES[@]} α₁ × ${#ALPHA_MU_VALUES[@]} α_μ × ${#C_MU_VALUES[@]} c_μ = $SETTINGS"
  echo ""

  for N in "${N_VALUES[@]}"; do
    # Get reps per job for this sample size
    REPS_PER_JOB=$(get_reps_per_job $N)
    N_ARRAY_JOBS=$(( (TOTAL_REPS + REPS_PER_JOB - 1) / REPS_PER_JOB ))

    for ALPHA_1 in "${ALPHA_1_VALUES[@]}"; do
      for ALPHA_MU in "${ALPHA_MU_VALUES[@]}"; do
        for C_MU in "${C_MU_VALUES[@]}"; do
          echo "Submitting: n=$N, α₁=$ALPHA_1, α_μ=$ALPHA_MU, c_μ=$C_MU ($REPS_PER_JOB reps/job, $N_ARRAY_JOBS jobs)"
          sbatch --array=1-${N_ARRAY_JOBS} \
                 --export=SCENARIO=$SCENARIO,N=$N,ALPHA_1=$ALPHA_1,ALPHA_MU=$ALPHA_MU,C_MU=$C_MU,REPS_PER_JOB=$REPS_PER_JOB,TOTAL_REPS=$TOTAL_REPS \
                 run_simulations.slurm
          JOB_COUNT=$((JOB_COUNT + 1))
          sleep 0.1
        done
      done
    done
  done

# Scenario 3: Both noisy (fixed c=1.0)
elif [ $SCENARIO -eq 3 ]; then
  echo "Scenario 3: Both noisy (noisy e(X) and μ(X), c=1.0)"
  SETTINGS=$(( ${#N_VALUES[@]} * ${#ALPHA_1_VALUES[@]} * ${#ALPHA_E_VALUES[@]} * ${#ALPHA_MU_VALUES[@]} ))
  echo "Settings: ${#N_VALUES[@]} n × ${#ALPHA_1_VALUES[@]} α₁ × ${#ALPHA_E_VALUES[@]} α_e × ${#ALPHA_MU_VALUES[@]} α_μ = $SETTINGS"
  echo ""

  C_FIXED=1.0  # Scenario 3 uses c=1.0 for both

  for N in "${N_VALUES[@]}"; do
    # Get reps per job for this sample size
    REPS_PER_JOB=$(get_reps_per_job $N)
    N_ARRAY_JOBS=$(( (TOTAL_REPS + REPS_PER_JOB - 1) / REPS_PER_JOB ))

    for ALPHA_1 in "${ALPHA_1_VALUES[@]}"; do
      for ALPHA_E in "${ALPHA_E_VALUES[@]}"; do
        for ALPHA_MU in "${ALPHA_MU_VALUES[@]}"; do
          echo "Submitting: n=$N, α₁=$ALPHA_1, α_e=$ALPHA_E, α_μ=$ALPHA_MU ($REPS_PER_JOB reps/job, $N_ARRAY_JOBS jobs)"
          sbatch --array=1-${N_ARRAY_JOBS} \
                 --export=SCENARIO=$SCENARIO,N=$N,ALPHA_1=$ALPHA_1,ALPHA_E=$ALPHA_E,ALPHA_MU=$ALPHA_MU,C_E=$C_FIXED,C_MU=$C_FIXED,REPS_PER_JOB=$REPS_PER_JOB,TOTAL_REPS=$TOTAL_REPS \
                 run_simulations.slurm
          JOB_COUNT=$((JOB_COUNT + 1))
          sleep 0.1
        done
      done
    done
  done
fi

echo ""
echo "========================================================================"
echo "Submission complete!"
echo "  Total jobs submitted: $JOB_COUNT"
echo "  Array jobs per setting: $N_ARRAY_JOBS"
echo "  Total array tasks: $(( JOB_COUNT * N_ARRAY_JOBS ))"
echo ""
echo "Monitor progress with: bash check_progress.sh"
echo "========================================================================"
