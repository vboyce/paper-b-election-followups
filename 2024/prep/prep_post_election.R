# Prep script for the 2024 post-election wave.
# Run with working directory set to this file's directory
# (2024/prep/) - all paths below are relative to it.
#
# The original post-election-process.Rmd carried over the pre-election
# cloze override (workerid %in% c(1676, 2291)), but neither workerid exists
# in this wave, so no override is passed here.

source("shared_prep_functions.R")

result <- process_wave(
  trials_path = "../raw/mme_post_election-trials.csv",
  cloze_stim_path = "../raw/exported_cloze_stim.csv",
  comp_q_path = "../raw/exported_comp_q.csv",
  maze_stim_path = "../raw/exported_maze_stim.csv",
  wave = "post",
  apply_political_aff_fix = FALSE,
  # Removed by the original's Prolific-ID-based duplicate checks (see
  # shared_prep_functions.R): the original processed participant table is
  # exactly ours minus these workerids.
  original_prolific_dedup_workerids = c(3621, 3776, 3990, 4121, 4184, 4308)
)

iwalk(result, \(df, name) {
  write_csv(df, paste0("../processed/post_", name, ".csv.gz"))
})
