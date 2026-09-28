#!/bin/bash
# =============================================================================
# monitor.sh -- progress, failed-task detection, and log discovery
# =============================================================================
# Run ON O2 from the study directory. With no arguments it reports on the most
# recent run (via ./logs/latest). Pass a run-id to inspect an older run.
#
# Reports PER STRATUM as well as in total, because this study's two strata differ
# by ~2 orders of magnitude in per-unit cost: a global "40% done" hides whether
# the expensive large_n arm has started, and the per-unit seconds that (re-)size
# the arrays are only meaningful per stratum.
#
# Usage:
#   bash slurm/monitor.sh                 # latest run
#   bash slurm/monitor.sh <run-id>        # specific run
#   bash slurm/monitor.sh --tail-failures # also print tails of failed task logs
# =============================================================================

set -euo pipefail

HMS_ID="dma12"
PROJECT_NAME="surrogate-transportability"
STUDY_NAME="confounded-aipw"

SLURM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDY_DIR="$(dirname "${SLURM_DIR}")"
SCRATCH_ROOT="/n/scratch/users/${HMS_ID:0:1}/${HMS_ID}/${PROJECT_NAME}/${STUDY_NAME}"

TAIL_FAILURES=0
RUN_ID=""
for arg in ${@+"$@"}; do
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
# Prefer the RUN's own SCOPE (written by submit.sh) over config/sizing*.  The
# sizing files are mutable and describe the NEXT submission; SCOPE describes THIS
# one. A smoke run has a SCOPE and may predate any sizing file at all.
if [[ -f "${SCRATCH_DIR}/SCOPE.env" ]]; then
  EXPECTED=$(grep '^TOTAL_TASKS=' "${SCRATCH_DIR}/SCOPE.env" | cut -d= -f2)
  EXPECTED_UNITS=$(grep '^TOTAL_UNITS=' "${SCRATCH_DIR}/SCOPE.env" | cut -d= -f2)
  if grep -q '^SMOKE=1' "${SCRATCH_DIR}/SCOPE.env"; then
    echo "*** SMOKE TIMING PROBE (not a reportable run) ***"
  fi
elif [[ -f "${STUDY_DIR}/config/sizing_totals.env" ]]; then
  EXPECTED=$(grep '^TOTAL_TASKS=' "${STUDY_DIR}/config/sizing_totals.env" | cut -d= -f2)
  EXPECTED_UNITS=$(grep '^TOTAL_UNITS=' "${STUDY_DIR}/config/sizing_totals.env" | cut -d= -f2)
fi
echo "Completed task files   : ${DONE} / ${EXPECTED}"

# Per-unit checkpoint progress (partials): finer-grained than task files.
PARTIALS=$(find "${SCRATCH_DIR}/partials" -maxdepth 1 -name 'unit_*.rds' 2>/dev/null | wc -l | tr -d ' ')
echo "Completed unit partials: ${PARTIALS} / ${EXPECTED_UNITS}"

if [[ -f "${SCRATCH_DIR}/SCOPE.tsv" ]]; then
  echo
  echo "Submitted stratum plan:"
  column -t -s $'\t' "${SCRATCH_DIR}/SCOPE.tsv" 2>/dev/null || cat "${SCRATCH_DIR}/SCOPE.tsv"
fi

# Observed per-unit wall time and peak RSS so far, PER STRATUM. These are the
# numbers that size (or re-size) the arrays; local profiling underestimated real
# O2 cost by ~3.8x in canonical-validation, and lambda-sweep's own smoke probe
# underestimated its full run's tail by 1.4-3.1x, so they are reported at every
# monitor call rather than once at sizing time.
if (( PARTIALS > 0 )) && command -v Rscript >/dev/null 2>&1; then
  Rscript -e "
    pf <- list.files('${SCRATCH_DIR}/partials', pattern='^unit_[0-9]+[.]rds\$', full.names=TRUE)
    rows <- lapply(pf, function(f) tryCatch(readRDS(f), error=function(e) NULL))
    rows <- rows[!vapply(rows, is.null, logical(1))]
    if (length(rows)) {
      g <- function(r, k) if (k %in% names(r)) r[[k]][1] else NA
      d <- data.frame(
        stratum = vapply(rows, function(r) as.character(g(r,'stratum')), character(1)),
        method  = vapply(rows, function(r) as.character(g(r,'method')),  character(1)),
        secs    = vapply(rows, function(r) as.numeric(g(r,'secs')),      numeric(1)),
        peak    = vapply(rows, function(r) as.numeric(g(r,'peak_rss_gb')), numeric(1)),
        err     = vapply(rows, function(r) as.character(g(r,'error_msg')), character(1)),
        stringsAsFactors = FALSE)
      ok <- d[is.finite(d\$secs), , drop=FALSE]
      if (nrow(ok)) {
        cat('\nObserved per-unit cost so far:\n')
        for (s in sort(unique(ok\$stratum))) {
          v <- ok\$secs[ok\$stratum == s]
          p <- ok\$peak[ok\$stratum == s]; p <- p[is.finite(p)]
          cat(sprintf('  %-9s n=%5d | median %7.1f s | q0.9 %7.1f s | max %8.1f s | peak RSS max %s\n',
                      s, length(v), median(v), quantile(v, 0.9, names=FALSE), max(v),
                      if (length(p)) sprintf('%.2f GB', max(p)) else 'n/a'))
          for (m in sort(unique(ok\$method[ok\$stratum == s]))) {
            w <- ok\$secs[ok\$stratum == s & ok\$method == m]
            cat(sprintf('      %-22s n=%5d | median %7.1f s | max %8.1f s\n',
                        m, length(w), median(w), max(w)))
          }
        }
      }
      nerr <- sum(!is.na(d\$err))
      cat(sprintf('Failed replications so far (error_msg set): %d / %d partial(s)\n', nerr, nrow(d)))
    }
  " 2>/dev/null || true
fi

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

# --- Failed-task detection (sentinel/exit-code, not grep-the-.err) -----------
# array.slurm writes "finished with status N" to the .out on completion and a
# distinctive "received SIGTERM" line on a wall-time TIMEOUT. Relying on those
# sentinels avoids the false positives that grepping .err for "error" produces
# from ever-present mgcv/ranger startup messages.
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
