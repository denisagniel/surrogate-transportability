#!/bin/bash
# =============================================================================
# array.slurm -- SLURM array job for the "confounded-aipw" study
# =============================================================================
# NOT run directly. submit.sh sets the sizing (--array, --time, --mem) on the
# sbatch command line and exports the variables below. This script maps its array
# index to a GLOBAL task id, prepares scratch, and runs one task.
#
# ONE ARRAY PER COST STRATUM. This study's config/grid.R defines stratum_of()
# splitting n = 10,000 units ("large_n") from n = 250 units ("small_n"), whose
# per-unit cost differs by ~2 orders of magnitude. submit.sh therefore submits one
# array per stratum with its own --time/--mem/REPS_PER_JOB, and passes STRATUM +
# TASK_BASE so run_replication.R can turn the GLOBAL task id back into a
# within-stratum row slice. Global task ids are contiguous across strata, so
# task_NNNNNN.rds is unique in the shared scratch dir.
#
# Exported by submit.sh (via --export=ALL after shell export):
#   STUDY_DIR    absolute path to the study dir (config/, R/, slurm/)
#   SCRATCH_DIR  run-specific scratch dir (task files + logs live here)
#   REPS_PER_JOB units per task, FOR THIS STRATUM
#   ARRAY_OFFSET added to SLURM_ARRAY_TASK_ID to get the global task id
#                (stratum base, plus 1000 per chunk when an array is split)
#   STRATUM      the stratum this array covers
#   TASK_BASE    global id of this stratum's first task, minus one
#   ROWS         OPTIONAL comma-separated row restriction, set only by
#                `submit.sh --smoke` so a timing probe straddles the cost axes.
#                Unset (the normal case) means the whole stratum.
# =============================================================================
#SBATCH --job-name=confounded-aipw
#SBATCH --partition=short
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
# --array, --time, --mem, --output, --error are supplied by submit.sh.

# --- Module environment -------------------------------------------------------
# `module` is a bash FUNCTION that Lmod `export -f`s into the environment, so
# --export=ALL carries it only from an INTERACTIVE submitting shell. Submitted
# non-interactively (ssh host 'bash -s') it is ABSENT, a bare `module load` fails,
# and `set -euo pipefail` kills every task within a second. See
# ~/.claude/skills/setup-cluster-simulations/O2_SSH_GOTCHAS.md sections 4 and 11.
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

# Distinguishable exit codes so `sacct -o State,ExitCode` names the cause with no
# log read: 78 module env, 79 Rscript missing, 80 R library path, 81 missing export.
die() { echo "[$(date '+%F %T')] FATAL(${2}): ${1}" >&2; exit "${2}"; }

command -v module >/dev/null 2>&1 || die "module unavailable after profile bootstrap" 78
module purge 2>/dev/null || true
module load gcc/14.2.0 || die "module load gcc/14.2.0" 78
module load R/4.4.2 || die "module load R/4.4.2" 78
command -v Rscript >/dev/null 2>&1 || die "Rscript not on PATH after module load" 79

# Validate required exports BY NAME, so an --export typo does not look identical
# to a module failure (they had the same symptom before exit codes were split).
for v in STUDY_DIR SCRATCH_DIR REPS_PER_JOB ARRAY_OFFSET STRATUM TASK_BASE; do
  [[ -n "${!v:-}" ]] || die "required export ${v} is unset (check submit.sh --export)" 81
done

# Pinned, not inherited: --export=ALL otherwise propagates the submitter's
# R_LIBS_USER/MODULEPATH, the likely cause of .libPaths() non-determinism.
R_LIBS_USER="${R_LIBS_USER:-${HOME}/R/x86_64-pc-linux-gnu-library/4.4}"
export R_LIBS_USER
[[ -d "${R_LIBS_USER}" ]] || die "R_LIBS_USER does not exist: ${R_LIBS_USER}" 80
echo "[$(date '+%F %T')] R_LIBS_USER=${R_LIBS_USER}"

# --- Global task id -----------------------------------------------------------
GLOBAL_TASK_ID=$(( SLURM_ARRAY_TASK_ID + ARRAY_OFFSET ))

echo "[$(date '+%F %T')] host=$(hostname) array_idx=${SLURM_ARRAY_TASK_ID} offset=${ARRAY_OFFSET} global_task=${GLOBAL_TASK_ID} stratum=${STRATUM} task_base=${TASK_BASE}"

mkdir -p "${SCRATCH_DIR}"

# --- SIGTERM trap: SLURM sends SIGTERM then (after grace) SIGKILL on a wall-time
# TIMEOUT. Report how many per-unit partials this task flushed so the over-run is
# visibly recoverable (a resubmit skips completed units). The "received SIGTERM"
# line is the sentinel monitor.sh scans for.
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
  --task-base    "${TASK_BASE}" \
  --stratum      "${STRATUM}" \
  --reps-per-job "${REPS_PER_JOB}" \
  --study-dir    "${STUDY_DIR}" \
  --scratch-dir  "${SCRATCH_DIR}" \
  --rows         "${ROWS:-}" &
# `wait` returns the child's exit status; `|| status=$?` keeps `set -e` from
# aborting before we print the "finished with status N" sentinel monitor.sh needs.
status=0
wait $! || status=$?

echo "[$(date '+%F %T')] global_task=${GLOBAL_TASK_ID} finished with status ${status}"
exit "${status}"
