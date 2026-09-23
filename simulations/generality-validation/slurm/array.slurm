#!/bin/bash
# =============================================================================
# array.slurm -- SLURM array job for the "generality-validation" study
# =============================================================================
# NOT run directly. submit.sh sets the sizing (#SBATCH --array, --time, --mem)
# on the sbatch command line and exports the variables below. This script maps
# its array index to a GLOBAL task id, prepares scratch, and runs one task.
#
# Exported by submit.sh (via --export):
#   STUDY_DIR    absolute path to the study dir (config/, R/, slurm/)
#   SCRATCH_DIR  run-specific scratch dir (task files + logs live here)
#   REPS_PER_JOB units per task
#   ARRAY_OFFSET added to SLURM_ARRAY_TASK_ID to get the global task id
#                (arrays are chunked at <=1000; wave k covers a different range)
# =============================================================================
#SBATCH --job-name=generality-validation
#SBATCH --partition=short
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
# --array, --time, --mem, --output, --error are supplied by submit.sh.

# --- Module environment -------------------------------------------------------
# Backfilled 2026-09-22. `module` is a bash FUNCTION that Lmod `export -f`s into the
# environment, so --export=ALL carries it only from an INTERACTIVE submitting shell.
# Submitted non-interactively (ssh host 'bash -s') it is ABSENT, the bare `module
# load` below failed, and `set -euo pipefail` killed every task within a second.
# That is what happened to doubletree run 20260918-130255_88ba1bd (6 arrays, 134
# tasks). See O2_SSH_GOTCHAS.md sections 4 and 11.
#
# Bootstrap MUST precede strict mode: /etc/profile.d/* scripts reference unset
# variables and return non-zero, both fatal under `set -eu`.
set +eu
if ! command -v module >/dev/null 2>&1; then
  for profile_script in /etc/profile.d/lmod.sh /etc/profile.d/modules.sh /etc/profile; do
    [ -r "${profile_script}" ] && . "${profile_script}" && break
  done
fi
set -euo pipefail

# Distinguishable exit codes so `sacct -o State,ExitCode` names the cause with no log
# read: 78 module env, 79 Rscript missing, 80 R library path.
die() { echo "[$(date '+%F %T')] FATAL(${2}): ${1}" >&2; exit "${2}"; }

command -v module >/dev/null 2>&1 || die "module unavailable after profile bootstrap" 78
module purge 2>/dev/null || true
module load gcc/14.2.0 || die "module load gcc/14.2.0" 78
module load R/4.4.2 || die "module load R/4.4.2" 78
command -v Rscript >/dev/null 2>&1 || die "Rscript not on PATH after module load" 79

# Pinned, not inherited: --export=ALL otherwise propagates the submitter's
# R_LIBS_USER/MODULEPATH, which is the likely cause of the .libPaths()
# non-determinism in O2_SSH_GOTCHAS.md section 5. Defaulted rather than required so
# this patch does not depend on also replacing submit.sh.
R_LIBS_USER="${R_LIBS_USER:-${HOME}/R/x86_64-pc-linux-gnu-library/4.4}"
export R_LIBS_USER
[[ -d "${R_LIBS_USER}" ]] || die "R_LIBS_USER does not exist: ${R_LIBS_USER}" 80
echo "[$(date '+%F %T')] R_LIBS_USER=${R_LIBS_USER}"
# --- Global task id -----------------------------------------------------------
GLOBAL_TASK_ID=$(( SLURM_ARRAY_TASK_ID + ARRAY_OFFSET ))

echo "[$(date '+%F %T')] host=$(hostname) array_idx=${SLURM_ARRAY_TASK_ID} offset=${ARRAY_OFFSET} global_task=${GLOBAL_TASK_ID}"

mkdir -p "${SCRATCH_DIR}"

# --- SIGTERM trap (M3): SLURM sends SIGTERM then (after grace) SIGKILL on a
# wall-time TIMEOUT. Report how many per-unit partials this task flushed so the
# over-run is visibly recoverable (a resubmit skips completed units). The
# "received SIGTERM" line is the sentinel monitor.sh scans for.
on_term() {
  local pdir="${SCRATCH_DIR}/partials"
  local n=0
  [[ -d "${pdir}" ]] && n=$(find "${pdir}" -maxdepth 1 -name 'unit_*.rds' 2>/dev/null | wc -l | tr -d ' ')
  echo "[$(date '+%F %T')] global_task=${GLOBAL_TASK_ID} received SIGTERM (likely TIMEOUT); ${n} unit partial(s) flushed and safe. Resubmit to resume." >&2
  exit 143
}
trap on_term TERM

# --- Run one task's block of units (backgrounded so the trap can fire) --------
Rscript "${STUDY_DIR}/slurm/run_replication.R" \
  --task-id      "${GLOBAL_TASK_ID}" \
  --reps-per-job "${REPS_PER_JOB}" \
  --study-dir    "${STUDY_DIR}" \
  --scratch-dir  "${SCRATCH_DIR}" &
# `wait` returns the child's exit status; `|| status=$?` keeps `set -e` from
# aborting before we print the "finished with status N" sentinel monitor.sh needs.
status=0
wait $! || status=$?

echo "[$(date '+%F %T')] global_task=${GLOBAL_TASK_ID} finished with status ${status}"
exit "${status}"
