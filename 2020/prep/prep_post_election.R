# Prep script for the 2020 post-election round.
# Run with working directory set to this file's directory
# (2020/prep/) - all paths below are relative to it.
#
# Note: the original pipeline additionally excluded participants who also
# took part in the pre-election round (via a real MTurk WorkerId lookup).
# That check is not reproducible here - see the message() emitted by
# process_round() and STATUS.md for why.

source("shared_prep_functions.R")

result <- process_round(
  raw_log_path = "../raw/post_election_results.txt",
  stimuli_path = "../raw/stimuli.tsv",
  stimuli_mazerace_path = "../raw/stimuli_mazerace.tsv",
  has_aware_question = TRUE
)

iwalk(result, \(df, name) {
  write_csv(df |> mutate(batch = "post"), paste0("../processed/post_", name, ".csv"))
})
