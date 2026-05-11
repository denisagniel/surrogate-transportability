#!/bin/bash
# Launch All AIPW Robustness Scenarios
#
# Usage: bash launch_all_simulations.sh [reps_per_job] [total_reps]
#
# Launches all 4 scenarios (0-3) for the full AIPW robustness study
# Total: 615 settings × 1000 reps = 615,000 replications (default)
#
# WARNING: This will submit a LARGE number of jobs to the cluster!
# Consider launching scenarios individually for better control.

set -e

REPS_PER_JOB=${1:-50}
TOTAL_REPS=${2:-1000}

echo "========================================================================"
echo "AIPW Robustness Study: Full Launch"
echo "========================================================================"
echo "Configuration:"
echo "  Reps per job: $REPS_PER_JOB"
echo "  Total reps per setting: $TOTAL_REPS"
echo ""
echo "Expected totals:"
echo "  Scenario 0 (Oracle): 15 settings"
echo "  Scenario 1 (Propensity): 180 settings"
echo "  Scenario 2 (Outcome): 180 settings"
echo "  Scenario 3 (Both): 240 settings"
echo "  ─────────────────────────────────"
echo "  TOTAL: 615 settings × $TOTAL_REPS reps = $(( 615 * TOTAL_REPS )) replications"
echo ""

read -p "Proceed with full launch? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

echo ""
echo "Launching scenarios..."
echo ""

# Launch each scenario
for SCENARIO in 0 1 2 3; do
  echo "──────────────────────────────────────────────────────────────────"
  echo "Launching Scenario $SCENARIO..."
  echo "──────────────────────────────────────────────────────────────────"
  bash launch_scenario.sh $SCENARIO $REPS_PER_JOB $TOTAL_REPS
  echo ""
  sleep 2  # Brief pause between scenarios
done

echo ""
echo "========================================================================"
echo "All scenarios launched!"
echo ""
echo "Monitor with:"
echo "  squeue -u \$USER | grep aipw"
echo "  bash check_progress.sh"
echo ""
echo "After completion, combine results with:"
echo "  Rscript combine_results.R"
echo "========================================================================"
