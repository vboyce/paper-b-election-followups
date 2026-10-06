# Stacks the core columns of both studies' processed tables into one table
# per kind (see ../shared/common_schema.R; column meanings in ../DATA.md).
# Run after both studies' prep scripts, with working directory set to this
# file's directory (combined/). Study-specific columns stay in the
# per-study processed/ tables.

library(tidyverse)

source("../shared/common_schema.R")

studies <- c("2020", "2024")
rounds <- c("pre", "post")

read_core <- function(table) {
  paths <- as.vector(outer(studies, rounds, \(s, r) file.path("..", s, "processed", paste0(r, "_", table, ".csv.gz"))))
  missing <- paths[!file.exists(paths)]
  if (length(missing) > 0) stop("Missing processed files: ", toString(missing))
  spec <- core_columns[[table]]
  col_types <- do.call(cols_only, map(spec, \(type) switch(type,
    character = col_character(), integer = col_integer(), double = col_double(), logical = col_logical()
  )))
  stacked <- map(paths, \(p) read_csv(p, col_types = col_types)) |> list_rbind()
  n_by_source <- stacked |> count(study, round)
  if (nrow(n_by_source) != length(studies) * length(rounds) || any(n_by_source$n == 0)) {
    stop(table, ": expected rows from every study and round")
  }
  check_core_schema(stacked, table)
}

combined <- map(set_names(names(core_columns)), read_core)

# Every non-sessions table refers only to known sessions.
for (table in setdiff(names(combined), "sessions")) {
  orphans <- setdiff(combined[[table]]$session_id, combined$sessions$session_id)
  if (length(orphans) > 0) stop(table, ": ", length(orphans), " session_ids not in sessions")
}

iwalk(combined, \(df, table) {
  write_csv(df, paste0(table, ".csv.gz"))
  message(table, ".csv.gz: ", nrow(df), " rows")
})
