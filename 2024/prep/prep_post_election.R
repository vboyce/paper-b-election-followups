# Prep script for the 2024 post-election wave.
# Run with working directory set to this file's directory
# (2024/prep/) - all paths below are relative to it.
#
# Note: the original post-election-process.Rmd carried over a
# workerid-based cloze override from the pre-election script
# (workerid %in% c(1676, 2291)), but neither workerid exists in this
# wave's data at all (checked directly against the raw trials: 0 matching
# rows out of 4939 participants) - so it's not passed here. See
# shared_prep_functions.R's file-level comment.

source("shared_prep_functions.R")

result <- process_wave(
  trials_path = "../raw/mme_post_election-trials.csv",
  cloze_stim_path = "../raw/exported_cloze_stim.csv",
  comp_q_path = "../raw/exported_comp_q.csv",
  maze_stim_path = "../raw/exported_maze_stim.csv",
  apply_political_aff_fix = FALSE
)

iwalk(result, \(df, name) {
  write_csv(df |> mutate(batch = "post"), paste0("../processed/post_", name, ".csv"))
})
