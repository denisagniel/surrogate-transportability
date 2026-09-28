#!/bin/bash
# =============================================================================
# retry_failed.sh -- resume/retry an EXISTING run-id with bumped resources
# =============================================================================
# submit.sh mints a NEW run-id (fresh scratch) every call, so re-running it does
# NOT resume -- it starts over. This script resubmits the SAME per-stratum arrays
# against an EXISTING run-id's scratch dir, so the per-unit idempotent skip in
# run_replication.R resumes: completed units are skipped, only failed/incomplete
# units recompute. Optionally bump --time/--mem (the common reason to retry).
#
# READS THE RUN'S OWN SCOPE.tsv, NOT today's config/sizing.tsv. The task -> unit
# mapping is a function of (stratum, reps_per_job, task_base); a re-profiled
# sizing file would remap tasks onto different units and scatter duplicate and
# missing work across the same scratch dir, which combine.R would then report as a
# coverage failure with no obvious cause. (canonical-validation's retry script
# read a config/sizing.tsv its own submit.sh never wrote, so it could not have run
# as shipped; this one reads what this study's submit.sh actually records.)
# --time/--mem may be bumped freely, since they do not affect the mapping.
#
# Recommended flow:
#   1) Purge poisoned results so they regenerate:
#        Rscript slurm/purge_failed_tasks.R --scratch-dir <scratch> --apply
#   2) Retry with more time/memory:
#        bash slurm/retry_failed.sh --run-id <id> --time-mult 1.5 --mem-mult 1.5
#
# Usage:
#   bash slurm/retry_failed.sh [--run-id RID] [--time-mult F] [--mem-mult F]
#                              [--stratum S]
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
STUDY_NAME="confounded-aipw"

SLURM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDY_DIR="$(dirname "${SLURM_DIR}")"
SCRATCH_ROOT="/n/scratch/users/${HMS_ID:0:1}/${HMS_ID}/${PROJECT_NAME}/${STUDY_NAME}"

RUN_ID=""; TIME_MULT="1.0"; MEM_MULT="1.0"; ONLY_STRATUM=""
while (( $# )); do
  case "$1" in
    --run-id)    RUN_ID="$2"; shift 2 ;;
    --time-mult) TIME_MULT="$2"; shift 2 ;;
    --mem-mult)  MEM_MULT="$2"; shift 2 ;;
    --stratum)   ONLY_STRATUM="$2"; shift 2 ;;
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

SCOPE_TSV="${SCRATCH_DIR}/SCOPE.tsv"
[[ -f "${SCOPE_TSV}" ]] || { echo "ERROR: ${SCOPE_TSV} missing; cannot resume safely." >&2; exit 1; }

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

# Per-stratum --time/--mem come from today's sizing.tsv (safe to change) but the
# MAPPING columns come from SCOPE.tsv (not safe to change).
SIZING_TSV="${STUDY_DIR}/config/sizing.tsv"
lookup_sizing() {  # $1 = stratum, $2 = column index (5 walltime, 6 mem_gb)
  awk -F'\t' -v s="$1" -v c="$2" '$1 == s { print $c; exit }' "${SIZING_TSV}" 2>/dev/null
}

# Bump a SLURM D-HH:MM:SS walltime by a float multiplier (via seconds).
bump_time() {
  local wt="$1" mult="$2" d h m s total rest
  d=${wt%%-*}; rest=${wt#*-}
  IFS=: read -r h m s <<< "${rest}"
  total=$(( (10#$d*86400) + (10#$h*3600) + (10#$m*60) + 10#$s ))
  total=$(awk -v t="${total}" -v f="${mult}" 'BEGIN{printf "%d", (t*f)+0.999}')
  printf "%d-%02d:%02d:%02d" $(( total/86400 )) $(( (total%86400)/3600 )) $(( (total%3600)/60 )) $(( total%60 ))
}

DONE_UNITS=$(find "${SCRATCH_DIR}/partials" -maxdepth 1 -name 'unit_*.rds' 2>/dev/null | wc -l | tr -d ' ')
TOTAL_UNITS=$(grep '^TOTAL_UNITS=' "${SCRATCH_DIR}/SCOPE.env" 2>/dev/null | cut -d= -f2 || echo '?')
echo "Resuming run ${RUN_ID}: ${DONE_UNITS}/${TOTAL_UNITS} units already done."

mkdir -p "${LOG_DIR}"
ln -sfn "${LOG_DIR}" "${STUDY_DIR}/logs/latest"

MAX_ARRAY_SIZE=1000
declare -a JOB_IDS=()

while IFS=$'\t' read -r s units rpj tasks base; do
  [[ "${s}" == "stratum" || -z "${s}" ]] && continue
  [[ -n "${ONLY_STRATUM}" && "${s}" != "${ONLY_STRATUM}" ]] && continue

  wt=$(lookup_sizing "${s}" 5); mem=$(lookup_sizing "${s}" 6)
  # No sizing.tsv row (e.g. resuming a smoke probe) -> conservative defaults.
  [[ -z "${wt}"  ]] && wt="0-03:00:00"
  [[ -z "${mem}" ]] && mem=4
  NEW_TIME=$(bump_time "${wt}" "${TIME_MULT}")
  NEW_MEM=$(awk -v m="${mem}" -v f="${MEM_MULT}" 'BEGIN{printf "%d", (m*f)+0.999}')

  chunk_offset=0
  while (( chunk_offset < tasks )); do
    remaining=$(( tasks - chunk_offset ))
    chunk=$(( remaining < MAX_ARRAY_SIZE ? remaining : MAX_ARRAY_SIZE ))
    cap=$(( MAX_ARRAY_SIZE < chunk ? MAX_ARRAY_SIZE : chunk ))

    # Shell-exported, then a PLAIN --export=ALL. The combined
    # --export=ALL,KEY=value form is CANCELLED BY ROOT on O2 within seconds.
    export STUDY_DIR="${STUDY_DIR}"
    export SCRATCH_DIR="${SCRATCH_DIR}"
    export REPS_PER_JOB="${rpj}"
    export ARRAY_OFFSET=$(( base + chunk_offset ))
    export STRATUM="${s}"
    export TASK_BASE="${base}"
    export ROWS=""
    jobid=$(sbatch --parsable \
      --array=1-"${chunk}"%"${cap}" \
      --time="${NEW_TIME}" --mem="${NEW_MEM}G" \
      --output="${LOG_DIR}/task_%A_%a.out" --error="${LOG_DIR}/task_%A_%a.err" \
      --export=ALL \
      "${SLURM_DIR}/array.slurm")
    JOB_IDS+=("${jobid}")
    echo "  resubmitted array ${jobid}: stratum ${s}, global tasks $((base+chunk_offset+1))-$((base+chunk_offset+chunk)) (--time ${NEW_TIME} --mem ${NEW_MEM}G)"
    chunk_offset=$(( chunk_offset + chunk ))
  done
done < "${SCOPE_TSV}"

echo "Resubmitted ${#JOB_IDS[@]} array job(s) against run ${RUN_ID}. Monitor: bash slurm/monitor.sh"
