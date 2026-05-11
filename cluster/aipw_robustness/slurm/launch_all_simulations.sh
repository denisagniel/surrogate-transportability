#!/bin/bash
# Launch All AIPW Robustness Scenarios
#
# Usage: bash launch_all_simulations.sh [total_reps] [mode]
#
# Launches all 4 scenarios (0-3) for the full AIPW robustness study
# Total: 615 settings × 1000 reps = 615,000 replications (default)
#
# Arguments:
#   total_reps: Total replications per setting (default: 1000)
#   mode: "auto" (sample-size-specific, default) or number (fixed reps/job)
#
# Auto mode keeps jobs < 12 hours by adjusting reps per job:
#   n=500,1000: 200 reps/job, n=2000: 150, n=5000: 100, n=10000: 80
#   Result: ~4,920 total jobs instead of 12,300
#
# WARNING: This will submit THOUSANDS of jobs to the cluster!
# Consider launching scenarios individually for better control.

set -e

TOTAL_REPS=${1:-1000}
MODE=${2:-auto}

echo "========================================================================"
echo "AIPW Robustness Study: Full Launch"
echo "========================================================================"
echo "Configuration:"
echo "  Total reps per setting: $TOTAL_REPS"
if [ "$MODE" = "auto" ]; then
  echo "  Mode: Auto (sample-size-specific reps/job for <12hr runtime)"
  echo "  Expected total jobs: ~4,920 (60% fewer than fixed reps/job)"
else
  echo "  Mode: Fixed ($MODE reps/job)"
fi
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
  bash launch_scenario.sh $SCENARIO $TOTAL_REPS $MODE
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
