#!/bin/bash
# =============================================================================
# retry_failed.sh -- resume/retry an EXISTING run-id with bumped resources
# =============================================================================
# submit.sh mints a NEW run-id (fresh scratch) every call, so re-running it does
# NOT resume -- it starts over. This script resubmits the SAME arrays against an
# EXISTING run-id's scratch dir, so the per-unit idempotent skip in
# run_replication.R resumes: completed units are skipped, only failed/incomplete
# units recompute. Optionally bump --time/--mem (the common reason to retry).
#
# NOTE ON DIVERGENCE FROM canonical-validation. That study's retry_failed.sh reads
# config/sizing.tsv + config/sizing_totals.env (the per-stratum scaffold form), but
# canonical-validation itself only ever wrote config/sizing.env (the single-stratum
# form its submit.sh/array.slurm/combine.R actually use) -- so its retry script
# could not have run as shipped. lambda-sweep is single-cost-stratum like that
# study, so this version reads sizing.env, consistent with its own submit.sh.
#
# Recommended flow:
#   1) Purge poisoned results so they regenerate:
#        Rscript slurm/purge_failed_tasks.R --scratch-dir <scratch> --apply
#   2) Retry with more time/memory:
#        bash slurm/retry_failed.sh --run-id <id> --time-mult 1.5 --mem-mult 1.5
#
# Usage:
#   bash slurm/retry_failed.sh [--run-id RID] [--time-mult F] [--mem-mult F]
#   (no --run-id -> uses ./logs/latest)
# =============================================================================

# --- Login-node environment bootstrap (see submit.sh for the full rationale) ---
set +eu
if ! command -v module >/dev/null 2>&1; then
  for profile_script in /etc/profile.d/lmod.sh /etc/profile.d/modules.sh /etc/profile; do
    [ -r "${profile_script}" ] && . "${profile_script}" && break
  done
fi
set -euo pipefail
if command -v module >/dev/null 2>&1; then
  module load gcc/14.2.0 2>/dev/null || module load gcc || true
  module load R/4.4.2   2>/dev/null || module load R   || true
fi
command -v Rscript >/dev/null 2>&1 || {
  echo "ERROR: Rscript not on PATH after module bootstrap." >&2; exit 1; }
export R_LIBS_USER="${R_LIBS_USER:-${HOME}/R/x86_64-pc-linux-gnu-library/4.4}"

HMS_ID="dma12"
PROJECT_NAME="surrogate-transportability"
STUDY_NAME="lambda-sweep"

SLURM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDY_DIR="$(dirname "${SLURM_DIR}")"
SCRATCH_ROOT="/n/scratch/users/${HMS_ID:0:1}/${HMS_ID}/${PROJECT_NAME}/${STUDY_NAME}"

RUN_ID=""; TIME_MULT="1.0"; MEM_MULT="1.0"
while (( $# )); do
  case "$1" in
    --run-id)    RUN_ID="$2"; shift 2 ;;
    --time-mult) TIME_MULT="$2"; shift 2 ;;
    --mem-mult)  MEM_MULT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "${RUN_ID}" ]]; then
  if [[ -L "${STUDY_DIR}/logs/latest" ]]; then
    LOG_DIR="$(readlink -f "${STUDY_DIR}/logs/latest")"
    SCRATCH_DIR="$(dirname "${LOG_DIR}")"
    RUN_ID="$(basename "${SCRATCH_DIR}")"
  else
    echo "ERROR: no --run-id and ./logs/latest missing." >&2; exit 1
  fi
else
  SCRATCH_DIR="${SCRATCH_ROOT}/${RUN_ID}"
  LOG_DIR="${SCRATCH_DIR}/logs"
fi
[[ -d "${SCRATCH_DIR}" ]] || { echo "ERROR: scratch dir not found: ${SCRATCH_DIR}" >&2; exit 1; }

# --- Resume against the ORIGINAL run's parameters, not today's sizing.env ------
# The task -> unit mapping is a function of (REPS_PER_JOB, REP_FROM, REP_TO). Using
# a re-profiled sizing.env here would remap tasks onto different units and scatter
# duplicate/missing work across the same scratch dir, which combine.R would then
# report as a coverage failure with no obvious cause. So read REP_SCOPE.
SCOPE_FILE="${SCRATCH_DIR}/REP_SCOPE"
[[ -f "${SCOPE_FILE}" ]] || { echo "ERROR: ${SCOPE_FILE} missing; cannot resume safely." >&2; exit 1; }
# shellcheck disable=SC1090
source "${SCOPE_FILE}"
: "${REP_FROM:?}" "${REP_TO:?}" "${REPS_PER_JOB:?}" "${TOTAL_TASKS:?}"

SIZING_ENV="${STUDY_DIR}/config/sizing.env"
[[ -f "${SIZING_ENV}" ]] || { echo "ERROR: ${SIZING_ENV} missing." >&2; exit 1; }
WALLTIME=$(grep '^WALLTIME=' "${SIZING_ENV}" | cut -d= -f2)
MEM_GB=$(grep '^MEM_GB=' "${SIZING_ENV}" | cut -d= -f2)
MAX_ARRAY_SIZE=$(grep '^MAX_ARRAY_SIZE=' "${SIZING_ENV}" | cut -d= -f2)
MAX_CONCURRENT_JOBS=$(grep '^MAX_CONCURRENT_JOBS=' "${SIZING_ENV}" | cut -d= -f2)
CONCURRENCY_CAP=$(grep '^CONCURRENCY_CAP=' "${SIZING_ENV}" | cut -d= -f2)

# Guard: refuse to resume against code that changed since this run started.
if [[ -f "${SCRATCH_DIR}/GRID_HASH" ]]; then
  CUR=$(Rscript "${SLURM_DIR}/_code_hash.R" "${STUDY_DIR}")
  REC=$(tr -d '[:space:]' < "${SCRATCH_DIR}/GRID_HASH")
  if [[ "${CUR}" != "${REC}" ]]; then
    echo "ERROR: study code changed since run ${RUN_ID} (hash ${REC} -> ${CUR})." >&2
    echo "       Start a fresh run with submit.sh instead of resuming stale scratch." >&2
    exit 1
  fi
fi

# Bump a SLURM D-HH:MM:SS walltime by a float multiplier (via seconds).
bump_time() {
  local wt="$1" mult="$2" d h m s total rest
  d=${wt%%-*}; rest=${wt#*-}
  IFS=: read -r h m s <<< "${rest}"
  total=$(( (10#$d*86400) + (10#$h*3600) + (10#$m*60) + 10#$s ))
  total=$(awk -v t="${total}" -v f="${mult}" 'BEGIN{printf "%d", (t*f)+0.999}')
  printf "%d-%02d:%02d:%02d" $(( total/86400 )) $(( (total%86400)/3600 )) $(( (total%3600)/60 )) $(( total%60 ))
}
NEW_TIME=$(bump_time "${WALLTIME}" "${TIME_MULT}")
NEW_MEM=$(awk -v m="${MEM_GB}" -v f="${MEM_MULT}" 'BEGIN{printf "%d", (m*f)+0.999}')

DONE_UNITS=$(find "${SCRATCH_DIR}/partials" -maxdepth 1 -name 'unit_*.rds' 2>/dev/null | wc -l | tr -d ' ')
echo "Resuming run ${RUN_ID}: ${DONE_UNITS}/${TOTAL_UNITS:-?} units already done."
echo "  reps ${REP_FROM}-${REP_TO}, ${TOTAL_TASKS} tasks x ${REPS_PER_JOB} units, --time ${NEW_TIME} --mem ${NEW_MEM}G"

mkdir -p "${LOG_DIR}"
ln -sfn "${LOG_DIR}" "${STUDY_DIR}/logs/latest"

ARRAYS_PER_WAVE=$(( MAX_CONCURRENT_JOBS / MAX_ARRAY_SIZE )); (( ARRAYS_PER_WAVE < 1 )) && ARRAYS_PER_WAVE=1
offset=0; arrays_in_wave=0; prev_wave_last_jobid=""; this_wave_last_jobid=""
declare -a JOB_IDS=()

while (( offset < TOTAL_TASKS )); do
  remaining=$(( TOTAL_TASKS - offset ))
  chunk=$(( remaining < MAX_ARRAY_SIZE ? remaining : MAX_ARRAY_SIZE ))
  cap=$(( CONCURRENCY_CAP < chunk ? CONCURRENCY_CAP : chunk ))

  dep_args=()
  if (( arrays_in_wave == 0 )) && [[ -n "${prev_wave_last_jobid}" ]]; then
    dep_args=(--dependency=afterany:"${prev_wave_last_jobid}")
  fi

  # Shell-exported, then a PLAIN --export=ALL. The combined --export=ALL,KEY=value
  # form is CANCELLED BY ROOT on O2 within seconds with no output written at all.
  export STUDY_DIR="${STUDY_DIR}"
  export SCRATCH_DIR="${SCRATCH_DIR}"
  export REPS_PER_JOB="${REPS_PER_JOB}"
  export ARRAY_OFFSET="${offset}"
  export REP_FROM="${REP_FROM}"
  export REP_TO="${REP_TO}"
  export ROWS=""
  jobid=$(sbatch --parsable \
    --array=1-"${chunk}"%"${cap}" \
    --time="${NEW_TIME}" --mem="${NEW_MEM}G" \
    --output="${LOG_DIR}/task_%A_%a.out" --error="${LOG_DIR}/task_%A_%a.err" \
    ${dep_args[@]+"${dep_args[@]}"} \
    --export=ALL \
    "${SLURM_DIR}/array.slurm")
  JOB_IDS+=("${jobid}"); this_wave_last_jobid="${jobid}"
  echo "  resubmitted array ${jobid}: global tasks $((offset+1))-$((offset+chunk)) (%${cap})"

  offset=$(( offset + chunk ))
  arrays_in_wave=$(( arrays_in_wave + 1 ))
  if (( arrays_in_wave >= ARRAYS_PER_WAVE )); then
    prev_wave_last_jobid="${this_wave_last_jobid}"; arrays_in_wave=0
  fi
done

echo "Resubmitted ${#JOB_IDS[@]} array job(s) against run ${RUN_ID}. Monitor: bash slurm/monitor.sh"
