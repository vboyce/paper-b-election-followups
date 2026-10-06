# Prep script for the 2020 post-election round.
# Run with working directory set to this file's directory
# (2020/prep/) - all paths below are relative to it.
#
# The pre-election round's IP pseudonyms are passed in only for the
# candidate flag `flag_ip_in_pre_round`; the applied cross-round exclusion
# (`excl_worker_in_pre_round`) uses MTurk workers, via the linkage file.

source("shared_prep_functions.R")

mturk_linkage <- read_csv("../raw/mturk_session_linkage.csv",
  col_types = cols(time = col_character()), show_col_types = FALSE
)

result <- process_round(
  raw_log_path = "../raw/post_election_ibex_rows.csv.gz",
  submissions_path = "../raw/post_election_ibex_submissions.csv",
  stimuli_path = "../raw/stimuli.tsv",
  stimuli_mazerace_path = "../raw/stimuli_mazerace.tsv",
  round_name = "post",
  has_aware_question = TRUE,
  mturk_linkage = mturk_linkage,
  previous_round_participant_ids = read_participant_ids("../raw/pre_election_ibex_rows.csv.gz")
)

iwalk(result, \(df, name) {
  write_csv(df, paste0("../processed/post_", name, ".csv.gz"))
})
