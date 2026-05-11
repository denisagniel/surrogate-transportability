#!/bin/bash
# Check Progress of AIPW Robustness Simulations
#
# Usage: bash check_progress.sh
#        watch -n 30 bash check_progress.sh  # Auto-refresh every 30 seconds

echo "========================================================================"
echo "AIPW Robustness Study: Progress Check"
echo "Date: $(date)"
echo "========================================================================"
echo ""

# Check SLURM queue
echo "─────────────────────────────────────────────────────────────────────"
echo "SLURM Job Status:"
echo "─────────────────────────────────────────────────────────────────────"

# Count jobs by state
PENDING=$(squeue -u $USER -n aipw_robustness -h -t PD | wc -l)
RUNNING=$(squeue -u $USER -n aipw_robustness -h -t R | wc -l)
TOTAL_QUEUE=$(squeue -u $USER -n aipw_robustness -h | wc -l)

echo "  Pending:  $PENDING"
echo "  Running:  $RUNNING"
echo "  Total in queue: $TOTAL_QUEUE"
echo ""

# Show running jobs sample
if [ $RUNNING -gt 0 ]; then
  echo "Sample of running jobs:"
  squeue -u $USER -n aipw_robustness -t R | head -10
  if [ $RUNNING -gt 10 ]; then
    echo "  ... and $(( RUNNING - 10 )) more"
  fi
  echo ""
fi

# Check results files
echo "─────────────────────────────────────────────────────────────────────"
echo "Results Files:"
echo "─────────────────────────────────────────────────────────────────────"

RESULTS_DIR="../results"

# Count result files by scenario
for SCENARIO in 0 1 2 3; do
  SCENARIO_RESULTS=$(find $RESULTS_DIR -name "s${SCENARIO}_*_batch_*.rds" 2>/dev/null | wc -l)
  echo "  Scenario $SCENARIO: $SCENARIO_RESULTS batch files"
done

TOTAL_RESULTS=$(find $RESULTS_DIR -name "*_batch_*.rds" 2>/dev/null | wc -l)
echo "  ─────────────"
echo "  Total: $TOTAL_RESULTS batch files"
echo ""

# Estimate completion
if [ $TOTAL_QUEUE -gt 0 ]; then
  echo "─────────────────────────────────────────────────────────────────────"
  echo "Completion Estimate:"
  echo "─────────────────────────────────────────────────────────────────────"

  # Get average job runtime from completed jobs (very rough estimate)
  # This is just for display; actual times vary widely
  if [ $RUNNING -gt 0 ]; then
    echo "  Jobs still running - check back later for estimate"
  else
    echo "  No jobs currently running"
    echo "  Jobs pending: $PENDING"
  fi
  echo ""
fi

# Check for errors in logs
echo "─────────────────────────────────────────────────────────────────────"
echo "Recent Errors (if any):"
echo "─────────────────────────────────────────────────────────────────────"

ERROR_COUNT=$(find logs -name "*.err" -type f -mmin -60 -exec grep -l "ERROR\|Error\|error" {} \; 2>/dev/null | wc -l)

if [ $ERROR_COUNT -gt 0 ]; then
  echo "  ⚠ Found $ERROR_COUNT log files with errors in last 60 minutes"
  echo "  Check: ls -lt logs/*.err | head -5"
  echo ""
  echo "  Recent error files:"
  find logs -name "*.err" -type f -mmin -60 -exec grep -l "ERROR\|Error\|error" {} \; 2>/dev/null | head -5
else
  echo "  ✓ No errors in recent logs (last 60 minutes)"
fi

echo ""
echo "========================================================================"
echo "Refresh this display:"
echo "  bash check_progress.sh"
echo "  watch -n 30 bash check_progress.sh  # Auto-refresh"
echo ""
echo "When all jobs complete, combine results:"
echo "  Rscript combine_results.R"
echo "========================================================================"
