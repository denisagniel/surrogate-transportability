#!/bin/bash
# =============================================================================
# monitor.sh -- progress, failed-task detection, and log discovery
# =============================================================================
# Run ON O2 from the study directory. With no arguments it reports on the most
# recent run (via ./logs/latest). Pass a run-id to inspect an older run.
#
# Solves "hard to find recent logs": it resolves the current run's scratch log
# dir, shows the newest log files, counts completed vs expected tasks, and tails
# the logs of any FAILED array tasks so you can debug fast.
#
# Usage:
#   bash slurm/monitor.sh                 # latest run
#   bash slurm/monitor.sh <run-id>        # specific run
#   bash slurm/monitor.sh --tail-failures # also print tails of failed task logs
# =============================================================================

set -euo pipefail

HMS_ID="dma12"
PROJECT_NAME="surrogate-transportability"
STUDY_NAME="canonical-validation"

SLURM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDY_DIR="$(dirname "${SLURM_DIR}")"
SCRATCH_ROOT="/n/scratch/users/${HMS_ID:0:1}/${HMS_ID}/${PROJECT_NAME}/${STUDY_NAME}"

TAIL_FAILURES=0
RUN_ID=""
for arg in "$@"; do
  case "${arg}" in
    --tail-failures) TAIL_FAILURES=1 ;;
    *) RUN_ID="${arg}" ;;
  esac
done

# --- Resolve run dir ----------------------------------------------------------
if [[ -n "${RUN_ID}" ]]; then
  SCRATCH_DIR="${SCRATCH_ROOT}/${RUN_ID}"
  LOG_DIR="${SCRATCH_DIR}/logs"
elif [[ -L "${STUDY_DIR}/logs/latest" ]]; then
  LOG_DIR="$(readlink -f "${STUDY_DIR}/logs/latest")"
  SCRATCH_DIR="$(dirname "${LOG_DIR}")"
  RUN_ID="$(basename "${SCRATCH_DIR}")"
else
  echo "No run-id given and ./logs/latest missing. Recent runs in scratch:" >&2
  ls -1t "${SCRATCH_ROOT}" 2>/dev/null | head -10 >&2 || echo "  (none)" >&2
  exit 1
fi

if [[ ! -d "${SCRATCH_DIR}" ]]; then
  echo "ERROR: scratch dir not found: ${SCRATCH_DIR}" >&2
  exit 1
fi

echo "=============================================================="
echo " run-id : ${RUN_ID}"
echo " scratch: ${SCRATCH_DIR}"
echo " logs   : ${LOG_DIR}"
echo "=============================================================="

# --- Progress: completed task files vs expected -------------------------------
# find (never `ls | wc`): a glob overflows to a wrong/zero count at ~100k files,
# which silently reads as "done" and triggers a stale combine/resume.
DONE=$(find "${SCRATCH_DIR}" -maxdepth 1 -name 'task_*.rds' 2>/dev/null | wc -l | tr -d ' ')
EXPECTED="?"
EXPECTED_UNITS="?"
if [[ -f "${STUDY_DIR}/config/sizing.env" ]]; then
  EXPECTED=$(grep '^TOTAL_TASKS=' "${STUDY_DIR}/config/sizing.env" | cut -d= -f2)
  EXPECTED_UNITS=$(grep '^TOTAL_UNITS=' "${STUDY_DIR}/config/sizing.env" | cut -d= -f2)
fi
echo "Completed task files: ${DONE} / ${EXPECTED}"

# Per-unit checkpoint progress (partials): finer-grained than task files.
PARTIALS=$(find "${SCRATCH_DIR}/partials" -maxdepth 1 -name 'unit_*.rds' 2>/dev/null | wc -l | tr -d ' ')
echo "Completed unit partials: ${PARTIALS} / ${EXPECTED_UNITS}"

# --- Queue state for this user's jobs ----------------------------------------
echo
echo "Queue (squeue) for ${HMS_ID}, job name ${STUDY_NAME}:"
squeue -u "${HMS_ID}" --name="${STUDY_NAME}" \
  --format="%.18i %.9P %.20j %.8T %.10M %.6D %R" 2>/dev/null || echo "  (squeue unavailable)"
# `|| true` so a transient squeue failure (or its absence) never aborts the
# monitor under `set -e pipefail`.
RUNNING=$( (squeue -u "${HMS_ID}" --name="${STUDY_NAME}" -h -t RUNNING 2>/dev/null || true) | wc -l | tr -d ' ')
PENDING=$( (squeue -u "${HMS_ID}" --name="${STUDY_NAME}" -h -t PENDING 2>/dev/null || true) | wc -l | tr -d ' ')
echo "Running: ${RUNNING}   Pending: ${PENDING}"

# --- Most recent log files (log discovery) -----------------------------------
echo
echo "Newest log files:"
# find + sort (never `ls *.out`): the glob overflows / errors at ~100k logs.
find "${LOG_DIR}" -maxdepth 1 \( -name '*.out' -o -name '*.err' \) -printf '%T@ %p\n' 2>/dev/null \
  | sort -rn | head -8 | while read -r ts f; do
      printf "  %s  %s\n" "$(date -d "@${ts%.*}" '+%F %T' 2>/dev/null || echo '?')" "${f}"
    done || echo "  (no logs yet)"

# --- Failed-task detection (A3: sentinel/exit-code, not grep-the-.err) --------
# array.slurm writes "finished with status N" to the .out on completion and a
# distinctive "received SIGTERM" line on a wall-time TIMEOUT. Relying on those
# sentinels (and the exit status) avoids the false positives that grepping .err
# for "error" produces from ever-present import/S7/mgcv/ranger startup warnings.
#   FAILED     = definite failures (SIGTERM/timeout, or non-zero exit)
#   INCOMPLETE = no finish sentinel yet AND no result file -> still running or killed
echo
echo "Scanning for failed/incomplete tasks (exit-status sentinels)..."
FAILED=()
INCOMPLETE=()
while IFS= read -r -d '' outf; do
  if grep -q 'received SIGTERM' "${outf}" 2>/dev/null; then
    FAILED+=("${outf}")                                    # wall-time TIMEOUT
  elif grep -qE 'finished with status [1-9]' "${outf}" 2>/dev/null; then
    FAILED+=("${outf}")                                    # non-zero exit
  elif ! grep -q 'finished with status 0' "${outf}" 2>/dev/null; then
    INCOMPLETE+=("${outf}")                                # no sentinel: running OR killed
  fi
done < <(find "${LOG_DIR}" -maxdepth 1 -name 'task_*.out' -print0 2>/dev/null)

if (( ${#INCOMPLETE[@]} > 0 )); then
  echo "  ${#INCOMPLETE[@]} task log(s) have no finish sentinel yet (still running, or killed/OOM if the job is gone from squeue)."
fi

if (( ${#FAILED[@]} == 0 )); then
  echo "  No failed/timed-out tasks detected via exit sentinels."
else
  echo "  ${#FAILED[@]} task log(s) failed or timed out:"
  for f in "${FAILED[@]}"; do echo "    ${f}"; done
  if (( TAIL_FAILURES == 1 )); then
    echo
    echo "---- tails of failed task logs ----"
    for f in "${FAILED[@]}"; do
      echo ">>> ${f}"
      tail -n 15 "${f}"
      echo
    done
  else
    echo "  (re-run with --tail-failures to see the tails)"
  fi
fi

echo
if [[ "${DONE}" == "${EXPECTED}" ]]; then
  echo "All tasks complete. Combine with:"
  echo "  Rscript slurm/combine.R --run-id ${RUN_ID} --scratch-dir ${SCRATCH_DIR} --study-dir ${STUDY_DIR}"
fi
