# Checks the processed 2024 data against the original mmepr24 pipeline's
# processed tables, and stops if they don't match.
# Run after prep_pre_election.R and prep_post_election.R, with working
# directory set to this file's directory (2024/prep/).
#
# The expected numbers are the distinct workerids in each table of the
# original pipeline's output (2024-mmepr24/data/processed/, counted
# 2026-10-06). Each original table applied its own exclusions, which are
# rebuilt here from this pipeline's exclusion columns.
#
# SPR is the exception: the original also dropped words outside an RT
# window (and any session left with no usable words before the pronoun),
# which is an analysis-stage step here. So the SPR check compares the
# sessions eligible before that word-level step, and prints the difference.

library(tidyverse)

original_n <- tribble(
  ~table,              ~pre, ~post,
  "participants",      1279, 1273,
  "expectations",      1255, 1246,
  "cloze",              485,  497,
  "recall_question",    241,  228,
  "maze",               244,  235,
  "spr_all",            496,  488,
  "spr",                445,  432
) |>
  pivot_longer(c(pre, post), names_to = "round", values_to = "original")

count_for_round <- function(round_name) {
  sessions <- read_csv(paste0("../processed/", round_name, "_sessions.csv.gz"), show_col_types = FALSE)
  recall <- read_csv(paste0("../processed/", round_name, "_recall.csv.gz"), show_col_types = FALSE)
  reading <- read_csv(paste0("../processed/", round_name, "_reading.csv.gz"), show_col_types = FALSE)
  spr_sessions <- unique(reading$session_id[reading$task == "spr" & !reading$is_practice])

  # The original's participant table: survey respondents minus duplicates.
  participants <- sessions |> filter(!excl_no_survey, !excl_duplicate_submission, !excl_original_prolific_dedup)
  task_kept <- \(task_name) sessions |> filter(task == task_name, !excl_task_original)

  tibble(
    round = round_name,
    table = c("participants", "expectations", "cloze", "recall_question", "maze", "spr_all", "spr"),
    this_pipeline = c(
      n_distinct(participants$workerid),
      n_distinct(filter(sessions, !excl_expectations_original)$workerid),
      n_distinct(task_kept("cloze")$workerid),
      n_distinct(filter(sessions, session_id %in% recall$session_id, !excl_recall_original)$workerid),
      n_distinct(task_kept("maze")$workerid),
      n_distinct(filter(sessions, session_id %in% spr_sessions)$workerid),
      n_distinct(task_kept("spr")$workerid)
    )
  )
}

comparison <- bind_rows(count_for_round("pre"), count_for_round("post")) |>
  left_join(original_n, by = c("round", "table")) |>
  mutate(difference = this_pipeline - original)
print(comparison, n = Inf)

must_match <- filter(comparison, table != "spr")
if (any(must_match$difference != 0)) {
  stop("Counts differ from the original pipeline for: ",
       toString(paste(must_match$round, must_match$table)[must_match$difference != 0]))
}
spr <- filter(comparison, table == "spr")
message(
  "OK: participants, expectations, cloze, recall, maze and SPR-before-exclusions match the original exactly. ",
  "SPR sessions eligible before the word-level RT window: ",
  toString(paste0(spr$round, " ", spr$this_pipeline, " vs original ", spr$original, " after it")), "."
)
