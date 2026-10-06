# One-time transform applied to the original raw Ibex/PCIbex result logs
# (MVP pre-election-round/data/results.zip and post-election-round-1's
# equivalent) to produce this repo's 2020 raw data. It needs those private
# original files, which are not part of this repo; it is kept to document
# exactly how raw/ was derived from them.
#
# For each round it writes two files:
#
# 1. raw/{round}_election_ibex_rows.csv.gz - every data row of the Ibex log,
#    in order, as headerless comma-separated lines (Ibex URL-encodes commas
#    inside fields, so splitting on "," is safe). The rows are unchanged
#    except for column 2 (see below). The log's comment lines are dropped:
#    they only re-describe the column layout before every block (~60% of
#    the log), apart from three per-submission comments handled in (2).
#    The column layout depends only on the controller (column 3) and the
#    number of fields, and is documented once in ../README.md.
#
# 2. raw/{round}_election_ibex_submissions.csv - one row per submission
#    (time, participant_id, design_number). `design_number` comes from the
#    "# Design number was non-random = N" comment that precedes each
#    submission's rows (Ibex's counter for assigning lists/conditions).
#    The other two per-submission comments are dropped: "# Results on
#    <date>" repeats the timestamp in column 1, and "# USER AGENT: ..." is
#    a browser fingerprint that the analysis doesn't use.
#
# De-identification: every data row of the original log carries an MD5 hash
# of the participant's IP address as its 2nd field. That hash is an indirect
# identifier, so it is replaced with a pseudonymous participant_NNNN ID.
# The pseudonym mapping is built from the UNION of both rounds' hashes, in
# order of first appearance (pre before post), so the same hash gets the
# same pseudonym in both rounds. That lets the prep pipeline flag "this
# participant_id also appears in the other round" (same IP across rounds).
# The pseudonym carries no information beyond "same hash or not" and can't
# be reversed to the original IP.
#
# Run from this file's directory (2020/prep/).

library(readr)
library(stringr)
library(dplyr)
library(tibble)

# Reads the single "results" file out of an Ibex/PCIbex results.zip without
# extracting it to disk.
read_results_zip <- function(zip_path) {
  read_lines(unz(zip_path, "results"))
}

# Splits a log into its data rows and the per-submission design numbers.
# Each submission's block starts with "# Results on ..." and contains
# exactly one "# Design number ..." comment before its data rows.
parse_log <- function(lines) {
  is_comment <- str_starts(lines, "#")
  data_rows <- lines[!is_comment]
  fields <- str_match(data_rows, "^([^,]*),([^,]*),(.*)$")
  if (any(is.na(fields[, 1]))) {
    stop("Found data rows that don't match the expected 'timestamp,md5,rest' shape")
  }

  block_id <- cumsum(str_starts(lines, "# Results on"))
  if (any(block_id[!is_comment] == 0)) stop("Data rows before the first '# Results on' comment")
  design_lines <- str_starts(lines, "# Design number was non-random = ")
  design_per_block <- tibble(
    block = block_id[design_lines],
    design_number = as.integer(str_remove(lines[design_lines], "^# Design number was non-random = "))
  )
  if (anyNA(design_per_block$design_number)) stop("Unparseable design number")
  if (anyDuplicated(design_per_block$block) || nrow(design_per_block) != max(block_id)) {
    stop("Expected exactly one design number per submission block")
  }

  rows_per_block <- tibble(block = block_id[!is_comment], time = fields[, 2], md5 = fields[, 3]) |>
    distinct()
  if (anyDuplicated(rows_per_block$block)) {
    stop("A submission block contains data rows with more than one (time, md5) key")
  }
  if (nrow(rows_per_block) != max(block_id)) stop("A submission block has no data rows")
  submissions <- inner_join(rows_per_block, design_per_block, by = "block")
  if (anyDuplicated(submissions[c("time", "md5")])) stop("(time, md5) is not unique across submissions")

  list(fields = fields, submissions = submissions)
}

# Known contents of the original logs (checked 2026-10-06): rows per
# (controller, number of fields), and number of submissions.
expected_layout <- list(
  pre = tribble(
    ~controller, ~n_fields, ~n_rows,
    "DashedSentence", 8L, 18592L,
    "DashedSentence", 12L, 109379L,
    "Form", 9L, 14906L,
    "Maze", 15L, 161564L,
    "Question", 11L, 46017L,
    "Slider", 9L, 13944L
  ),
  post = tribble(
    ~controller, ~n_fields, ~n_rows,
    "DashedSentence", 8L, 18172L,
    "DashedSentence", 12L, 92564L,
    "Form", 9L, 14499L,
    "Maze", 15L, 174353L,
    "Question", 11L, 49361L,
    "Slider", 9L, 13629L
  )
)
expected_n_submissions <- c(pre = 4648L, post = 4543L)

check_layout <- function(rows, round_name) {
  observed <- tibble(
    controller = str_split_i(rows, ",", 3),
    n_fields = str_count(rows, ",") + 1L
  ) |>
    count(controller, n_fields, name = "n_rows")
  expected <- expected_layout[[round_name]]
  if (!isTRUE(all.equal(arrange(observed, controller, n_fields), expected, check.attributes = FALSE))) {
    stop(round_name, ": rows per (controller, n_fields) differ from the expected layout:\n",
         paste(capture.output(print(observed)), collapse = "\n"))
  }
}

write_round <- function(parsed, round_name, pseudonym_for) {
  rows <- paste0(parsed$fields[, 2], ",", pseudonym_for(parsed$fields[, 3]), ",", parsed$fields[, 4])
  check_layout(rows, round_name)

  submissions <- parsed$submissions |>
    transmute(time, participant_id = pseudonym_for(md5), design_number)
  if (nrow(submissions) != expected_n_submissions[[round_name]]) {
    stop(round_name, ": ", nrow(submissions), " submissions, expected ", expected_n_submissions[[round_name]])
  }

  rows_path <- paste0("../raw/", round_name, "_election_ibex_rows.csv.gz")
  submissions_path <- paste0("../raw/", round_name, "_election_ibex_submissions.csv")
  write_lines(rows, rows_path)
  write_csv(submissions, submissions_path)
  message(rows_path, ": ", length(rows), " data rows; ",
          submissions_path, ": ", nrow(submissions), " submissions, ",
          n_distinct(submissions$participant_id), " distinct participants")
  invisible(submissions)
}

pre_parsed <- parse_log(read_results_zip(
  "../../../2020-madame-vice-president/pre-election-round/pre-election-round-data/data/results.zip"
))
post_parsed <- parse_log(read_results_zip(
  "../../../2020-madame-vice-president/post-election-round-1/data/data/results.zip"
))

# One shared mapping built from both files' hashes together, in order of
# first appearance (pre before post), so the pseudonym is stable across
# files for the same underlying hash.
distinct_md5 <- unique(c(pre_parsed$fields[, 3], post_parsed$fields[, 3]))
pseudonym_for <- function(md5) sprintf("participant_%04d", match(md5, distinct_md5))

pre_submissions <- write_round(pre_parsed, "pre", pseudonym_for)
post_submissions <- write_round(post_parsed, "post", pseudonym_for)

n_shared <- length(intersect(pre_submissions$participant_id, post_submissions$participant_id))
message(
  n_shared, " pseudonymous participant IDs appear in both rounds' raw logs ",
  "(same IP hash in pre- and post-election data)."
)
