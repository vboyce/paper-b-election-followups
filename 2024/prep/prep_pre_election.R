# Prep script for the 2024 pre-election wave.
# Run with working directory set to this file's directory
# (2024/prep/) - all paths below are relative to it.

source("shared_prep_functions.R")

# Verified by hand against the raw response text: both participants used a
# "the [US] president" noun phrase that the original regex missed, on item 12.
# Affects cloze_code_original only.
cloze_overrides <- tibble(workerid = c(1676, 2291), item = c("12", "12"))

result <- process_wave(
  trials_path = "../raw/mme_pre_election-trials.csv",
  cloze_stim_path = "../raw/exported_cloze_stim.csv",
  comp_q_path = "../raw/exported_comp_q.csv",
  maze_stim_path = "../raw/exported_maze_stim.csv",
  wave = "pre",
  apply_political_aff_fix = TRUE,
  cloze_overrides = cloze_overrides,
  # Removed by the original's Prolific-ID-based duplicate checks (see
  # shared_prep_functions.R): the original processed participant table is
  # exactly ours minus these workerids.
  original_prolific_dedup_workerids = c(1916, 2483)
)

iwalk(result, \(df, name) {
  write_csv(df, paste0("../processed/pre_", name, ".csv.gz"))
})
