#!/bin/bash
# Monitor Simulation Progress
#
# Shows job status and completion estimates
# Run periodically to track progress

echo "========================================="
echo "Surrogate Validation: Progress Check"
echo "========================================="
echo "Time: $(date)"
echo ""

# Check if jobs are running
RUNNING=$(squeue -u $USER --name=surrogate_val --states=RUNNING | tail -n +2 | wc -l)
PENDING=$(squeue -u $USER --name=surrogate_val --states=PENDING | tail -n +2 | wc -l)
TOTAL_JOBS=$((RUNNING + PENDING))

if [ ${TOTAL_JOBS} -eq 0 ]; then
    echo "No jobs currently running or pending."
    echo ""
else
    echo "Job Status:"
    echo "  Running:  ${RUNNING}"
    echo "  Pending:  ${PENDING}"
    echo "  Total:    ${TOTAL_JOBS}"
    echo ""
fi

# Count completed results
DGPS=("dgp1" "dgp2" "dgp4")
TOTAL_EXPECTED=300  # 100 per DGP × 3 DGPs

echo "Results Completed:"
echo ""

TOTAL_COMPLETE=0

for DGP in "${DGPS[@]}"; do
    RESULTS_DIR="cluster/results/${DGP}"

    if [ -d "${RESULTS_DIR}" ]; then
        COUNT=$(find ${RESULTS_DIR} -name "batch_*.rds" 2>/dev/null | wc -l)
        TOTAL_COMPLETE=$((TOTAL_COMPLETE + COUNT))

        PERCENT=$((COUNT * 100 / 100))

        echo "  ${DGP}: ${COUNT}/100 (${PERCENT}%)"
    else
        echo "  ${DGP}: 0/100 (0%)"
    fi
done

echo ""
echo "Overall: ${TOTAL_COMPLETE}/${TOTAL_EXPECTED} ($((TOTAL_COMPLETE * 100 / TOTAL_EXPECTED))%)"
echo ""

# Estimate completion time
if [ ${TOTAL_JOBS} -gt 0 ] && [ ${TOTAL_COMPLETE} -gt 0 ]; then
    REMAINING=$((TOTAL_EXPECTED - TOTAL_COMPLETE))

    # Rough estimate: if jobs are running, completion in ~1 hour
    # (since all jobs run in parallel)
    if [ ${RUNNING} -gt 0 ]; then
        echo "Estimated completion: ~1 hour (jobs running in parallel)"
    else
        echo "Jobs pending, will start soon"
    fi
    echo ""
fi

if [ ${TOTAL_COMPLETE} -eq ${TOTAL_EXPECTED} ]; then
    echo "========================================="
    echo "ALL JOBS COMPLETE!"
    echo "========================================="
    echo ""
    echo "Next step: Combine results"
    echo "  Rscript cluster/slurm/combine_results.R"
    echo ""
fi

echo "========================================="
