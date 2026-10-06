# Prep script for the 2020 pre-election round.
# Run with working directory set to this file's directory
# (2020/prep/) - all paths below are relative to it.

source("shared_prep_functions.R")

mturk_linkage <- read_csv("../raw/mturk_session_linkage.csv",
  col_types = cols(time = col_character()), show_col_types = FALSE
)

result <- process_round(
  raw_log_path = "../raw/pre_election_results.txt",
  stimuli_path = "../raw/stimuli.tsv",
  stimuli_mazerace_path = "../raw/stimuli_mazerace.tsv",
  round_name = "pre",
  has_aware_question = FALSE,
  mturk_linkage = mturk_linkage
)

iwalk(result, \(df, name) {
  write_csv(df, paste0("../processed/pre_", name, ".csv.gz"))
})
