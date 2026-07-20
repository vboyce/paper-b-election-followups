# One-time transform applied to the original raw Ibex/PCIbex result logs
# (MVP pre-election-round/data/results.zip and post-election-round-1's
# equivalent) before they were added to this repo.
#
# Every data row in these logs carries an MD5 hash of the participant's IP
# address as its 2nd comma-separated field (comment lines starting with "#"
# document the column layout and don't carry this field). That hash is an
# indirect identifier, so it is replaced here with a pseudonymous ID before
# the log is committed.
#
# The pseudonym mapping is built from the UNION of both files' MD5 hashes,
# so the same underlying hash gets the same pseudonym in both files. This
# is what lets the prep pipeline flag "this participant_id showed up in
# both rounds" as a proxy for a repeat cross-round participant (see
# shared_prep_functions.R's `previous_round_participant_ids` argument) -
# the original pipeline's equivalent check used the real MTurk WorkerId
# (joined in from mturk_HIT_results.tsv, which is not part of this repo)
# rather than the IP hash, so this catches a subset of what that caught
# (same computer/IP across rounds, not same MTurk account from a different
# one) but is the best available proxy given what's in this repo. The
# pseudonym itself carries no information beyond "same hash or not" - it's
# still a one-way relabeling, not reversible to the original IP.
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

extract_md5_column <- function(lines) {
  is_data_row <- !str_starts(lines, "#")
  fields <- str_match(lines[is_data_row], "^([^,]*),([^,]*),(.*)$")
  if (any(is.na(fields[, 1]))) {
    stop("Found data rows that don't match the expected 'timestamp,md5,rest' shape")
  }
  list(is_data_row = is_data_row, fields = fields)
}

pre_lines <- read_results_zip(
  "../../../2020-madame-vice-president/pre-election-round/pre-election-round-data/data/results.zip"
)
post_lines <- read_results_zip(
  "../../../2020-madame-vice-president/post-election-round-1/data/data/results.zip"
)

pre_parsed <- extract_md5_column(pre_lines)
post_parsed <- extract_md5_column(post_lines)

# One shared mapping built from both files' hashes together, in order of
# first appearance (pre before post), so the pseudonym is stable across
# files for the same underlying hash.
all_md5 <- c(pre_parsed$fields[, 3], post_parsed$fields[, 3])
distinct_md5 <- unique(all_md5)
pseudonym_for <- function(md5) sprintf("participant_%04d", match(md5, distinct_md5))

write_deidentified <- function(lines, parsed, output_path) {
  pseudonym <- pseudonym_for(parsed$fields[, 3])
  lines[parsed$is_data_row] <- paste0(
    parsed$fields[, 2], ",", pseudonym, ",", parsed$fields[, 4]
  )
  message(
    output_path, ": ", sum(parsed$is_data_row), " data rows, ",
    length(unique(pseudonym)), " distinct participants"
  )
  write_lines(lines, output_path)
}

write_deidentified(pre_lines, pre_parsed, "../raw/pre_election_results.txt")
write_deidentified(post_lines, post_parsed, "../raw/post_election_results.txt")

n_shared <- length(intersect(pseudonym_for(pre_parsed$fields[, 3]), pseudonym_for(post_parsed$fields[, 3])))
message(
  n_shared, " pseudonymous participant IDs appear in both rounds' raw logs ",
  "(same IP hash in pre- and post-election data)."
)
