#!/bin/bash
# =============================================================================
# retry_failed.sh -- resume/retry an existing run-id with bumped resources (A2)
# =============================================================================
# submit.sh mints a NEW run-id (fresh scratch) every call, so re-running it does
# NOT resume -- it starts over. This script resubmits the SAME arrays against an
# EXISTING run-id's scratch dir, so the per-unit idempotent skip in
# run_replication.R resumes: completed units are skipped, only failed/incomplete
# units recompute. Optionally bump --time/--mem for strata that timed out or
# OOM'd (the common reason to retry).
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

set -euo pipefail

HMS_ID="dma12"
PROJECT_NAME="surrogate-transportability"
STUDY_NAME="canonical-validation"

SLURM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDY_DIR="$(dirname "${SLURM_DIR}")"
SCRATCH_ROOT="/n/scratch/users/${HMS_ID:0:1}/${HMS_ID}/${PROJECT_NAME}/${STUDY_NAME}"

RUN_ID=""
TIME_MULT="1.0"
MEM_MULT="1.0"
while (( $# )); do
  case "$1" in
    --run-id)    RUN_ID="$2"; shift 2 ;;
    --time-mult) TIME_MULT="$2"; shift 2 ;;
    --mem-mult)  MEM_MULT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

# --- Resolve the existing run's scratch dir ----------------------------------
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

TOTALS_ENV="${STUDY_DIR}/config/sizing_totals.env"
SIZING_TSV="${STUDY_DIR}/config/sizing.tsv"
[[ -f "${TOTALS_ENV}" && -f "${SIZING_TSV}" ]] || { echo "ERROR: sizing files missing; profile first." >&2; exit 1; }
# shellcheck disable=SC1090
source "${TOTALS_ENV}"
: "${MAX_ARRAY_SIZE:?}" "${MAX_CONCURRENT_JOBS:?}" "${CONCURRENCY_CAP:?}"

# Guard: refuse to resume against code that changed since this run started.
if [[ -f "${SCRATCH_DIR}/GRID_HASH" ]]; then
  CUR=$(Rscript -e "sd<-'${STUDY_DIR}'; files<-c('config/grid.R','R/dgp.R','R/estimators.R','R/run_one.R'); \
    h<-0; for(f in files){b<-readBin(file.path(sd,f),'raw',n=file.size(file.path(sd,f))); \
    for(x in as.integer(b)){h<-(h*257+x)%%2147483647}}; cat(sprintf('%.0f',h))")
  REC=$(tr -d '[:space:]' < "${SCRATCH_DIR}/GRID_HASH")
  if [[ "${CUR}" != "${REC}" ]]; then
    echo "ERROR: study code changed since run ${RUN_ID} (hash ${REC} -> ${CUR})." >&2
    echo "       Start a fresh run with submit.sh instead of resuming stale scratch." >&2
    exit 1
  fi
fi

# Bump a SLURM D-HH:MM:SS walltime by a float multiplier (via seconds).
bump_time() {
  local wt="$1" mult="$2"
  local d h m s total
  d=${wt%%-*}; local rest=${wt#*-}
  IFS=: read -r h m s <<< "${rest}"
  total=$(( (10#$d*86400) + (10#$h*3600) + (10#$m*60) + 10#$s ))
  total=$(awk -v t="${total}" -v f="${mult}" 'BEGIN{printf "%d", (t*f)+0.999}')
  # cap at 3 days (short partition is shorter, but sizing already targets <=3h)
  printf "%d-%02d:%02d:%02d" $(( total/86400 )) $(( (total%86400)/3600 )) $(( (total%3600)/60 )) $(( total%60 ))
}

echo "Resuming run ${RUN_ID} (scratch ${SCRATCH_DIR}); time x${TIME_MULT}, mem x${MEM_MULT}."
mkdir -p "${LOG_DIR}"
ln -sfn "${LOG_DIR}" "${STUDY_DIR}/logs/latest"

ARRAYS_PER_WAVE=$(( MAX_CONCURRENT_JOBS / MAX_ARRAY_SIZE )); (( ARRAYS_PER_WAVE < 1 )) && ARRAYS_PER_WAVE=1
wave_index=0; arrays_in_wave=0; prev_wave_last_jobid=""; this_wave_last_jobid=""
declare -a JOB_IDS=()

{
  read -r _header
  while IFS=$'\t' read -r stratum_id stratum unit_start unit_end n_units reps_per_job n_tasks array_offset walltime mem_gb; do
    [[ -z "${stratum_id:-}" ]] && continue
    new_time=$(bump_time "${walltime}" "${TIME_MULT}")
    new_mem=$(awk -v m="${mem_gb}" -v f="${MEM_MULT}" 'BEGIN{printf "%d", (m*f)+0.999}')
    echo "  stratum ${stratum}: ${n_tasks} task(s), --time ${new_time} --mem ${new_mem}G (resume-skip completed units)"

    chunk_offset=0
    while (( chunk_offset < n_tasks )); do
      remaining=$(( n_tasks - chunk_offset ))
      chunk=$(( remaining < MAX_ARRAY_SIZE ? remaining : MAX_ARRAY_SIZE ))
      cap=$(( CONCURRENCY_CAP < chunk ? CONCURRENCY_CAP : chunk ))
      global_offset=$(( array_offset + chunk_offset ))

      dep_args=()
      if (( arrays_in_wave == 0 )) && [[ -n "${prev_wave_last_jobid}" ]]; then
        dep_args=(--dependency=afterany:"${prev_wave_last_jobid}")
      fi

      jobid=$(sbatch --parsable \
        --array=1-"${chunk}"%"${cap}" \
        --time="${new_time}" --mem="${new_mem}G" \
        --output="${LOG_DIR}/task_%A_%a.out" --error="${LOG_DIR}/task_%A_%a.err" \
        ${dep_args[@]+"${dep_args[@]}"} \
        --export=ALL,STUDY_DIR="${STUDY_DIR}",SCRATCH_DIR="${SCRATCH_DIR}",REPS_PER_JOB="${reps_per_job}",ARRAY_OFFSET="${global_offset}",STRATUM_ARRAY_OFFSET="${array_offset}",STRATUM_UNIT_START="${unit_start}",STRATUM_UNIT_END="${unit_end}" \
        "${SLURM_DIR}/array.slurm")
      JOB_IDS+=("${jobid}"); this_wave_last_jobid="${jobid}"
      echo "     resubmitted array ${jobid}: global tasks $((global_offset+1))-$((global_offset+chunk))"

      chunk_offset=$(( chunk_offset + chunk ))
      arrays_in_wave=$(( arrays_in_wave + 1 ))
      if (( arrays_in_wave >= ARRAYS_PER_WAVE )); then
        prev_wave_last_jobid="${this_wave_last_jobid}"; wave_index=$(( wave_index+1 )); arrays_in_wave=0
      fi
    done
  done
} < "${SIZING_TSV}"

echo "Resubmitted ${#JOB_IDS[@]} array job(s) against run ${RUN_ID}. Monitor: bash slurm/monitor.sh"
