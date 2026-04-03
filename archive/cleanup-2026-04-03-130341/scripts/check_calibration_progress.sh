#!/bin/bash

# Monitor progress of calibration testing

echo "================================================================"
echo "CALIBRATION TESTING PROGRESS"
echo "================================================================"
echo ""

# Check if process is running
if pgrep -f "test_all_calibration_methods.R" > /dev/null; then
    echo "✓ Test is RUNNING"
    echo ""
else
    echo "✗ Test is NOT running (either completed or failed)"
    echo ""
fi

# Show last 50 lines of output
echo "Last 50 lines of output:"
echo "----------------------------------------------------------------"

# Find the task output file (try both old and new task IDs)
TASK_FILE=$(ls -t /private/tmp/claude-*/*/tasks/b7g3q1r1n.output 2>/dev/null | head -1)

if [ -z "$TASK_FILE" ]; then
    TASK_FILE=$(ls -t /private/tmp/claude-*/*/tasks/btb00g83y.output 2>/dev/null | head -1)
fi

if [ -n "$TASK_FILE" ]; then
    tail -50 "$TASK_FILE"
else
    echo "No output file found yet"
fi

echo ""
echo "================================================================"
echo "To see full output:"
echo "  tail -f /private/tmp/claude-*/*/tasks/b7g3q1r1n.output"
echo "================================================================"
