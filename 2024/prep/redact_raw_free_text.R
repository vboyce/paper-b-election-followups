# One-time transform applied to the original jsPsych trial exports
# (2024-mmepr24/data/mme_{pre,post}_election-trials.csv) to produce
# raw/mme_{pre,post}_election-trials.csv in this repo.
#
# A few participants typed their Prolific ID (24 lowercase hex characters)
# into a free-text cloze response box. Those IDs are direct identifiers, so
# every 24-hex-character token in the files is replaced with
# "REDACTED_PROLIFIC_ID". The cloze scoring treats the replacement exactly
# like the original text (neither is a pronoun), so processed outputs are
# unchanged apart from those cells.
#
# The replacement is a plain line-level text substitution, so the rest of
# each file stays byte-for-byte identical to the original export.
#
# Run from this file's directory (2024/prep/). It stops if the number of
# IDs found is not what was found when this was written (2026-10-06): one
# in pre, two in post. A different count means the source files changed
# and the redaction needs to be re-checked by hand.

library(readr)
library(stringr)

prolific_id_pattern <- "\\b[0-9a-f]{24}\\b"
redaction_token <- "REDACTED_PROLIFIC_ID"

redact_file <- function(source_path, output_path, expected_n_ids) {
  lines <- read_lines(source_path)
  n_ids <- sum(str_count(lines, prolific_id_pattern))
  if (n_ids != expected_n_ids) {
    stop(source_path, ": found ", n_ids, " Prolific-ID-shaped tokens, expected ", expected_n_ids)
  }
  redacted <- str_replace_all(lines, prolific_id_pattern, redaction_token)
  if (any(str_detect(redacted, regex(prolific_id_pattern, ignore_case = TRUE)))) {
    stop(output_path, ": Prolific-ID-shaped tokens remain after redaction")
  }
  write_lines(redacted, output_path)
  message(output_path, ": redacted ", n_ids, " Prolific ID(s)")
}

redact_file(
  "../../../2024-mmepr24/data/mme_pre_election-trials.csv",
  "../raw/mme_pre_election-trials.csv",
  expected_n_ids = 1
)
redact_file(
  "../../../2024-mmepr24/data/mme_post_election-trials.csv",
  "../raw/mme_post_election-trials.csv",
  expected_n_ids = 2
)
