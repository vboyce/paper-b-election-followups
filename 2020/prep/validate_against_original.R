# Checks the processed 2020 data against the original analysis's published
# participant counts, and stops if they don't match.
# Run after prep_pre_election.R and prep_post_election.R, with working
# directory set to this file's directory (2020/prep/).
#
# The expected counts are the "not excluded" column of the per-condition
# table in each round's original data-analysis.md:
#   2020-madame-vice-president/pre-election-round/pre-election-round-data/data-analysis/data-analysis.md:189-198
#   2020-madame-vice-president/post-election-round-1/data/data-analysis/data-analysis.md:188-197
#
# `excl_task_original_replication` must reproduce them exactly. The column
# analyses should use, `excl_task_original`, is printed alongside so the
# effect of this pipeline's corrections (see ../README.md) is visible.

library(tidyverse)

original_kept <- tribble(
  ~condition,       ~pre, ~post,
  "cloze-event",     299,   111,
  "event-cloze",     164,    61,
  "event-maze",      119,    52,
  "event-mazerace",  121,    40,
  "event-spr",       149,    48,
  "maze-event",      220,    86,
  "mazerace-event",  235,   103,
  "spr-event",       300,    88
) |>
  pivot_longer(c(pre, post), names_to = "round", values_to = "original_kept")

original_total_sessions <- c(pre = 4648, post = 4543)

sessions <- bind_rows(
  read_csv("../processed/pre_sessions.csv.gz", show_col_types = FALSE),
  read_csv("../processed/post_sessions.csv.gz", show_col_types = FALSE)
)

for (r in names(original_total_sessions)) {
  n <- sum(sessions$round == r)
  if (n != original_total_sessions[[r]]) stop(r, ": ", n, " sessions, original had ", original_total_sessions[[r]])
}

comparison <- sessions |>
  group_by(round, condition) |>
  summarise(
    replication_kept = sum(!excl_task_original_replication),
    corrected_rule_kept = sum(!excl_task_original),
    .groups = "drop"
  ) |>
  full_join(original_kept, by = c("round", "condition")) |>
  mutate(corrected_minus_original = corrected_rule_kept - original_kept) |>
  arrange(desc(round), condition)

print(comparison, n = Inf)
print(
  comparison |>
    group_by(round) |>
    summarise(across(c(original_kept, replication_kept, corrected_rule_kept), sum)) |>
    arrange(desc(round))
)

mismatches <- comparison |> filter(is.na(replication_kept) | replication_kept != original_kept)
if (nrow(mismatches) > 0) {
  print(mismatches)
  stop("excl_task_original_replication does not reproduce the original per-condition counts")
}
message("OK: excl_task_original_replication reproduces the original per-condition kept counts exactly.")
