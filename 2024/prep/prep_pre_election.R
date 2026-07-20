# Prep script for the 2024 pre-election wave.
# Run with working directory set to this file's directory
# (2024/prep/) - all paths below are relative to it.

source("shared_prep_functions.R")

# Verified by hand against the raw response text (see
# shared_prep_functions.R's file-level comment): both participants used an
# uncaught "the [US] president" noun phrase to refer to the candidate on
# item 12.
cloze_overrides <- tibble(workerid = c(1676, 2291), item = c(12, 12))

result <- process_wave(
  trials_path = "../raw/mme_pre_election-trials.csv",
  cloze_stim_path = "../raw/exported_cloze_stim.csv",
  comp_q_path = "../raw/exported_comp_q.csv",
  maze_stim_path = "../raw/exported_maze_stim.csv",
  apply_political_aff_fix = TRUE,
  cloze_overrides = cloze_overrides
)

iwalk(result, \(df, name) {
  write_csv(df |> mutate(batch = "pre"), paste0("../processed/pre_", name, ".csv"))
})
