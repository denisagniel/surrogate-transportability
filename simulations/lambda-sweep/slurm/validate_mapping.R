# Local validation of the O2 scaffold's task -> unit mapping. Not part of the run;
# proves the rep-scoped slicing covers reps 1-20 exactly, for every plausible
# reps_per_job, before 720 units of cluster time are spent on it.
source("config/grid.R")

ut     <- unit_table()
target <- ut[ut$rep_id >= 1L & ut$rep_id <= 20L, , drop = FALSE]
target <- target[order(target$unit), , drop = FALSE]
expected <- sort(target$unit)

cat(sprintf("configs %d | TOTAL_REPS %d | in-scope units %d\n",
            nrow(GRID), TOTAL_REPS, nrow(target)))
stopifnot(nrow(target) == 36L * 20L)

# Reps 1-20 must NOT be a contiguous unit range -- that is the whole reason the
# runner slices the filtered table rather than absolute unit ids.
contiguous <- identical(expected, seq_len(length(expected)))
cat(sprintf("in-scope units contiguous from 1? %s (expected FALSE)\n", contiguous))
stopifnot(!contiguous)
cat(sprintf("unit id range %d-%d; first 25: %s\n", min(expected), max(expected),
            paste(head(expected, 25), collapse = ",")))

# Every rep in scope, no rep out of scope.
stopifnot(setequal(unique(target$rep_id), 1:20))
stopifnot(all(target$rep_id <= 20L))

for (rpj in c(1L, 3L, 5L, 7L, 12L, 20L, 37L, 60L, 100L, 720L)) {
  n_tasks <- as.integer(ceiling(nrow(target) / rpj))
  covered <- integer(0)
  for (t in seq_len(n_tasks)) {
    s <- (t - 1L) * rpj + 1L
    e <- min(t * rpj, nrow(target))
    if (s > nrow(target)) next
    covered <- c(covered, target$unit[s:e])
  }
  ok_exact <- identical(sort(covered), expected)
  ok_nodup <- !any(duplicated(covered))
  cat(sprintf("reps_per_job %4d -> %4d tasks | exact coverage %s | no duplicates %s\n",
              rpj, n_tasks, ok_exact, ok_nodup))
  stopifnot(ok_exact, ok_nodup)
}

# The smoke row selector must straddle both cost axes, not land on one config.
t2 <- target; t2$row <- seq_len(nrow(t2))
lam <- range(LAMBDA_GRID)
want <- expand.grid(dgp = c("dgp1", "dgp2", "dgp4", "dgp5"), lambda = lam,
                    stringsAsFactors = FALSE)
idx <- vapply(seq_len(nrow(want)), function(i) {
  h <- t2$row[t2$dgp == want$dgp[i] & abs(t2$lambda - want$lambda[i]) < 1e-12 & t2$rep_id == 1L]
  if (!length(h)) stop("no row for ", want$dgp[i], " lambda ", want$lambda[i])
  h[1]
}, numeric(1))
idx <- unique(idx)
cat(sprintf("\nsmoke rows: %s\n", paste(idx, collapse = ",")))
probe <- t2[idx, c("row", "unit", "dgp", "lambda", "rep_id", "data_seed", "mcmc_seed")]
print(probe, row.names = FALSE)
stopifnot(length(unique(probe$dgp)) == 4L, length(unique(probe$lambda)) == 2L,
          all(probe$rep_id == 1L))
cat("\nALL MAPPING CHECKS PASSED\n")
