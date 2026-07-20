# One-time transform applied to the original raw Ibex/PCIbex result logs
# (MVP pre-election-round/data/results.zip and post-election-round-1's
# equivalent) before they were added to this repo.
#
# Every data row in these logs carries an MD5 hash of the participant's IP
# address as its 2nd comma-separated field (comment lines starting with "#"
# document the column layout and don't carry this field). That hash is an
# indirect identifier, so it is replaced here with a per-file sequential
# pseudonymous ID before the log is committed. Mapping is arbitrary and not
# consistent across the two files - the original pipeline's cross-round
# repeat-participant check relied on the real MTurk WorkerId (joined in from
# mturk_HIT_results.tsv, which is not part of this repo), not on the IP
# hash, so nothing downstream depends on the two files sharing an ID space.
#
# This script is not meant to be re-run - it's kept for provenance, to
# document how raw/*_results.txt were derived from the original private
# results.zip files.

library(readr)
library(stringr)

# Reads the single "results" file out of an Ibex/PCIbex results.zip without
# extracting it to disk.
read_results_zip <- function(zip_path) {
  read_lines(unz(zip_path, "results"))
}

deidentify_log <- function(input_zip, output_path, id_prefix) {
  lines <- read_results_zip(input_zip)
  is_data_row <- !str_starts(lines, "#")

  fields <- str_match(lines[is_data_row], "^([^,]*),([^,]*),(.*)$")
  if (any(is.na(fields[, 1]))) {
    stop(
      "Found data rows that don't match the expected ",
      "'timestamp,md5,rest' shape in ", input_zip
    )
  }
  md5 <- fields[, 3]

  # Assign sequential IDs in order of first appearance, so the mapping is
  # deterministic given a fixed input file.
  participant_id <- match(md5, unique(md5))
  pseudonym <- sprintf(paste0(id_prefix, "%04d"), participant_id)

  lines[is_data_row] <- paste0(fields[, 2], ",", pseudonym, ",", fields[, 4])

  n_participants <- length(unique(md5))
  message(
    input_zip, ": ", sum(is_data_row), " data rows, ",
    n_participants, " distinct participants -> ", output_path
  )
  write_lines(lines, output_path)
}

deidentify_log(
  "../../../2020-madame-vice-president/pre-election-round/pre-election-round-data/data/results.zip",
  "../raw/pre_election_results.txt",
  "pre_participant_"
)
deidentify_log(
  "../../../2020-madame-vice-president/post-election-round-1/data/data/results.zip",
  "../raw/post_election_results.txt",
  "post_participant_"
)
