# Prep script for the 2020 post-election round.
# Run with working directory set to this file's directory
# (2020/prep/) - all paths below are relative to it.
#
# Note: the original pipeline excluded participants who also took part in
# the pre-election round using the real MTurk WorkerId, which isn't
# available here. As a proxy, we exclude anyone whose pseudonymous
# participant ID (built from a mapping shared across both rounds' raw
# logs - see deidentify_raw_logs.R) also appears anywhere in the
# pre-election round's raw log. This only catches repeats from the same
# computer/IP, not the same MTurk account from a different one - see the
# message() emitted by process_round() and STATUS.md for the full picture.

source("shared_prep_functions.R")

pre_election_participant_ids <- read_participant_ids("../raw/pre_election_results.txt")

result <- process_round(
  raw_log_path = "../raw/post_election_results.txt",
  stimuli_path = "../raw/stimuli.tsv",
  stimuli_mazerace_path = "../raw/stimuli_mazerace.tsv",
  has_aware_question = TRUE,
  previous_round_participant_ids = pre_election_participant_ids
)

iwalk(result, \(df, name) {
  write_csv(df |> mutate(batch = "post"), paste0("../processed/post_", name, ".csv"))
})
