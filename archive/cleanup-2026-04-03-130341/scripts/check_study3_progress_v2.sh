#!/bin/bash
# Check Study 3 progress (v2 - corrected parallel processing)

LOG_FILE="/private/tmp/claude-1141097072/-Users-dagniel-RAND-rprojects-surrogates-surrogate-transportability/tasks/b2lpdvbjg.output"

if [ -f "$LOG_FILE" ]; then
    echo "=== STUDY 3 PROGRESS (V2 - Fixed Parallel Processing) ==="
    echo ""

    # Check which scenario is running
    tail -50 "$LOG_FILE" | grep -E "Running (true_positive|false_positive|false_negative|true_negative)" | tail -1

    echo ""
    echo "Recent output:"
    tail -20 "$LOG_FILE"

    echo ""
    echo "=== STATUS ==="

    # Check if completed
    if grep -q "Study 3 complete!" "$LOG_FILE"; then
        echo "✓ COMPLETE!"
        echo ""
        echo "Key findings:"
        grep -A 10 "KEY FINDINGS" "$LOG_FILE"
    else
        echo "⏳ Still running..."
        echo ""
        echo "To monitor in real-time:"
        echo "  tail -f $LOG_FILE"
    fi
else
    echo "Log file not found. Process may not have started."
fi
