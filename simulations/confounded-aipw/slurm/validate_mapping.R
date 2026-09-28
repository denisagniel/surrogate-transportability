#!/usr/bin/env Rscript
# =============================================================================
# validate_mapping.R -- prove the STRATUM-scoped task -> unit mapping is exact
# =============================================================================
# Not part of a run. Run BEFORE spending any cluster time. It reimplements the
# slicing arithmetic that slurm/run_replication.R performs and asserts that, for
# every plausible per-stratum reps_per_job, the set of units the array would
# execute equals the set of units config/grid.R defines -- each exactly once, with
# no duplicates and nothing out of its stratum.
#
# WHY THIS EXISTS AS A SEPARATE, EXECUTED CHECK.
# lambda-sweep's migration found that a "naive contiguous slice of unit ids" would
# have silently run the wrong units, because its unit_table() is rep-fastest within
# config and it executed only a rep SUB-SCOPE. confounded-aipw's indexing is
# different again, and differently dangerous:
#
#   * `reps` is a GRID COLUMN, not a global constant: 40 (`agreement`), 80
#     (`confounded`), 120 (`smalln`). So the units-per-config count VARIES, and
#     any arithmetic of the form (config - 1) * REPS + rep is wrong here.
#   * per-unit seeds are MAX_REPS-strided (`.unit_seed` uses
#     (config_id - 1) * 1000 + rep_id), so seeds are NOT unit ids and the two must
#     not be conflated.
#   * the study is split into two cost STRATA that are sized and submitted
#     separately, so each task's block is a slice of a FILTERED table and global
#     task ids must remain unique across the two arrays.
#
# Each of those is checked below against the real grid rather than reasoned about.
# The contiguity of the strata in unit-id space is REPORTED as an observed
# property, not relied upon: the runner filters by stratum_of() and would stay
# correct if a future grid edit interleaved them.
#
# Usage: Rscript slurm/validate_mapping.R            (from the study directory)
#        Rscript slurm/validate_mapping.R <study-dir>
# =============================================================================

args <- commandArgs(trailingOnly = TRUE)
study_dir <- if (length(args) >= 1L) args[[1]] else "."

suppressPackageStartupMessages(library(surrogateTransportability))
source(file.path(study_dir, "R", "dgp.R"))
source(file.path(study_dir, "config", "grid.R"))

ut <- unit_table()
ut$stratum <- stratum_of(ut)
strata <- sort(unique(ut$stratum))

cat("=== grid shape ===\n")
cat(sprintf("configs %d | units %d | n_units() %d\n", nrow(GRID), nrow(ut), n_units()))
stopifnot(nrow(ut) == n_units())
stopifnot(nrow(ut) == sum(GRID$reps))

# (1) `reps` really is heterogeneous across blocks -- the premise of everything
#     below. If a future edit made it constant the check still passes, but the
#     printout records which world we are in.
reps_by_block <- tapply(GRID$reps, GRID$block, function(x) unique(x))
cat("reps per block:", paste(sprintf("%s=%s", names(reps_by_block),
                                     vapply(reps_by_block, paste, character(1), collapse = "/")),
                             collapse = " "), "\n")
units_per_config <- as.integer(table(ut$config_id))
cat(sprintf("units per config: %s (heterogeneous = %s)\n",
            paste(sort(unique(units_per_config)), collapse = ","),
            length(unique(units_per_config)) > 1L))
for (i in seq_len(nrow(GRID))) {
  stopifnot(sum(ut$config_id == GRID$config_id[i]) == GRID$reps[i])
  stopifnot(setequal(ut$rep_id[ut$config_id == GRID$config_id[i]], seq_len(GRID$reps[i])))
}
cat("PASS: every config contributes exactly its own `reps` units, rep ids 1..reps.\n")

# (2) unit ids are a dense 1..N key, and are NOT the seeds. Conflating them would
#     be an easy and silent error given .unit_seed's MAX_REPS stride.
stopifnot(identical(ut$unit, seq_len(nrow(ut))))
stopifnot(!anyDuplicated(ut$seed))
stopifnot(!identical(as.integer(ut$seed), ut$unit))
cat(sprintf("PASS: unit ids dense 1..%d; %d distinct seeds, MAX_REPS-strided (%d..%d), distinct from unit ids.\n",
            nrow(ut), length(unique(ut$seed)), min(ut$seed), max(ut$seed)))
# Seeds must be invariant to any block's `reps`, which is what MAX_REPS buys.
seed_recomputed <- .unit_seed(ut$config_id, ut$rep_id)
stopifnot(identical(as.integer(ut$seed), as.integer(seed_recomputed)))
cat("PASS: seeds are a pure function of (config_id, rep_id) -- ordering-invariant.\n")

# (3) The strata partition the units.
cat("\n=== strata ===\n")
covered_all <- integer(0)
for (s in strata) {
  u <- sort(ut$unit[ut$stratum == s])
  contiguous <- identical(u, min(u):max(u))
  cat(sprintf("%-9s %4d units, ids %4d-%4d, contiguous=%s, n=%s, blocks=%s\n",
              s, length(u), min(u), max(u), contiguous,
              paste(sort(unique(ut$n[ut$stratum == s])), collapse = "/"),
              paste(sort(unique(ut$block[ut$stratum == s])), collapse = "+")))
  covered_all <- c(covered_all, u)
}
stopifnot(identical(sort(covered_all), ut$unit))
stopifnot(!anyDuplicated(covered_all))
cat("PASS: strata partition the unit set (union exact, no overlap).\n")
cat("NOTE: contiguity above is OBSERVED, not relied on -- run_replication.R filters\n")
cat("      by stratum_of() and stays correct if a grid edit interleaves the strata.\n")

# (4) THE MAPPING. Reimplement run_replication.R's slice for every stratum and a
#     range of reps_per_job, including the degenerate ends (1 unit/task, and one
#     task for the whole stratum) and values that do not divide the unit count.
cat("\n=== task -> unit mapping ===\n")
slice_stratum <- function(stratum, reps_per_job, task_base) {
  target <- ut[ut$stratum == stratum, , drop = FALSE]
  target <- target[order(target$unit), , drop = FALSE]
  n_tasks <- as.integer(ceiling(nrow(target) / reps_per_job))
  out <- list(units = integer(0), task_ids = integer(0))
  for (local_task in seq_len(n_tasks)) {
    global_task <- local_task + task_base           # what submit.sh assigns
    lt <- global_task - task_base                   # what run_replication.R recovers
    stopifnot(identical(lt, local_task))
    s <- (lt - 1L) * reps_per_job + 1L
    e <- min(lt * reps_per_job, nrow(target))
    if (s > nrow(target)) next
    out$units <- c(out$units, target$unit[s:e])
    out$task_ids <- c(out$task_ids, rep(global_task, e - s + 1L))
  }
  out$n_tasks <- n_tasks
  out
}

rpj_grid <- list(
  large_n  = c(1L, 3L, 7L, 16L, 20L, 33L, 64L, 213L, 640L),
  small_n  = c(1L, 3L, 7L, 16L, 31L, 120L, 160L, 480L),
  xlarge_n = c(1L, 3L, 7L, 16L, 31L, 120L, 160L, 480L)
)
for (s in strata) {
  want <- sort(ut$unit[ut$stratum == s])
  cand <- if (!is.null(rpj_grid[[s]])) rpj_grid[[s]] else c(1L, 7L, length(want))
  cand <- cand[cand >= 1L & cand <= length(want)]
  for (rpj in cand) {
    r <- slice_stratum(s, rpj, task_base = 0L)
    ok_exact <- identical(sort(r$units), want)
    ok_nodup <- !any(duplicated(r$units))
    cat(sprintf("  %-9s units/task %4d -> %4d tasks | exact coverage %-5s | no duplicates %-5s\n",
                s, rpj, r$n_tasks, ok_exact, ok_nodup))
    stopifnot(ok_exact, ok_nodup)
  }
}
cat("PASS: every stratum is covered exactly once, at every units/task tried.\n")

# (5) GLOBAL task ids must be unique ACROSS every stratum's separate array,
#     because all of them write task_NNNNNN.rds into ONE shared scratch dir. A
#     collision would silently overwrite one stratum's results with another's.
#     Generalized over `strata` (not hardcoded to two names) so a future
#     stratum_of() change is exercised here automatically.
cat("\n=== cross-stratum global task-id uniqueness ===\n")
xstrata_cand <- lapply(strata, function(s) {
  want_n <- sum(ut$stratum == s)
  cand <- if (!is.null(rpj_grid[[s]])) rpj_grid[[s]] else c(1L, 7L, want_n)
  cand <- unique(cand[cand >= 1L & cand <= want_n])
  if (length(cand) > 3L) cand <- unique(c(cand[1L], cand[ceiling(length(cand) / 2L)], cand[length(cand)]))
  cand
})
names(xstrata_cand) <- strata
combos <- expand.grid(xstrata_cand, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
for (ci in seq_len(nrow(combos))) {
  base <- 0L
  all_units <- integer(0); all_tasks <- integer(0); plan <- character(0)
  for (s in strata) {
    rpj <- combos[[s]][ci]
    r <- slice_stratum(s, rpj, task_base = base)
    all_units <- c(all_units, r$units)
    all_tasks <- c(all_tasks, r$task_ids)
    plan <- c(plan, sprintf("%s:rpj=%d,%dtasks(base %d)", s, rpj, r$n_tasks, base))
    base <- base + r$n_tasks
  }
  # Each global task id maps to exactly one stratum's block...
  tasks_unique <- length(unique(all_tasks)) == length(unique(paste(all_tasks)))
  per_task_strata <- tapply(all_units, all_tasks, function(u) length(unique(ut$stratum[ut$unit %in% u])))
  stopifnot(all(per_task_strata == 1L))
  # ...and the union over all tasks is the full unit set, exactly once.
  stopifnot(identical(sort(all_units), ut$unit))
  stopifnot(!any(duplicated(all_units)))
  expected_base <- sum(vapply(strata, function(s)
    as.integer(ceiling(sum(ut$stratum == s) / combos[[s]][ci])), integer(1)))
  stopifnot(identical(base, expected_base))
  cat(sprintf("  %s -> %2d tasks total | full coverage TRUE | no task spans >1 stratum\n",
              paste(plan, collapse = ", "), base))
  stopifnot(tasks_unique)
}
cat("PASS: global task ids are contiguous, unique across strata, and each covers one stratum.\n")

# (6) The smoke probe selector must straddle the cost axes, not land on one cell.
cat("\n=== smoke probe rows ===\n")
for (s in strata) {
  target <- ut[ut$stratum == s, , drop = FALSE]
  target <- target[order(target$unit), , drop = FALSE]
  target$row <- seq_len(nrow(target))
  rows_txt <- system2("Rscript", c(file.path(study_dir, "slurm", "smoke_rows.R"),
                                  shQuote(study_dir), s), stdout = TRUE)
  rows <- as.integer(strsplit(tail(rows_txt, 1), ",", fixed = TRUE)[[1]])
  stopifnot(!anyNA(rows), all(rows >= 1L), all(rows <= nrow(target)))
  p <- target[rows, c("row", "unit", "block", "dgp", "dgp_kind", "n", "method", "rep_id", "seed")]
  cat(sprintf("stratum %s: %d probe rows\n", s, nrow(p)))
  print(p, row.names = FALSE)
  # Both methods must be present, or the IW-vs-AIPW timing question cannot be
  # answered from the probe; every dgp AND every n in the stratum must appear
  # too, since a stratum can now span multiple n (small_n covers 250/500/2000).
  stopifnot(setequal(unique(p$method), c("importance_weighting", "aipw")))
  stopifnot(setequal(unique(p$dgp), unique(target$dgp)))
  stopifnot(setequal(unique(p$n), unique(target$n)))
  stopifnot(all(p$rep_id == 1L))
  stopifnot(!anyDuplicated(p$unit))
}
cat("PASS: probes cover both methods and every dgp in each stratum, at rep 1.\n")

cat("\nALL MAPPING CHECKS PASSED\n")
