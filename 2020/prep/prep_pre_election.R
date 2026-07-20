# Prep script for the 2020 pre-election round.
# Run with working directory set to this file's directory
# (2020/prep/) - all paths below are relative to it.

source("shared_prep_functions.R")

result <- process_round(
  raw_log_path = "../raw/pre_election_results.txt",
  stimuli_path = "../raw/stimuli.tsv",
  stimuli_mazerace_path = "../raw/stimuli_mazerace.tsv",
  has_aware_question = FALSE
)

iwalk(result, \(df, name) {
  write_csv(df |> mutate(batch = "pre"), paste0("../processed/pre_", name, ".csv"))
})
