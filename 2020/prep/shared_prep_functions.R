# Shared parsing/cleaning logic for the 2020 MVP pre-election and
# post-election rounds. Both rounds are processed by calling
# `process_round()` from this file with round-specific arguments, so the
# two rounds are guaranteed to use identical parsing, exclusion criteria,
# and RT thresholds - see prep_pre_election.R / prep_post_election.R for
# the thin per-round drivers.
#
# Differences from the original MadameVicePresident pre-processing.R this
# is derived from:
#  - No dependency on mturk_HIT_results.tsv (not part of this repo - see
#    STATUS.md), so the real MTurk WorkerId is never available. The
#    original post-election script's cross-round exclusion
#    (WorkerIdInPreviousRound) can't be reproduced exactly. Instead,
#    `process_round()` takes an optional `previous_round_participant_ids`
#    argument: the pseudonymous participant IDs are built from a mapping
#    shared across both rounds' raw logs (see deidentify_raw_logs.R), so
#    the same underlying IP hash gets the same ID in both files, and a
#    ID showing up in both rounds is used as a proxy for the same person
#    doing both. This is not equivalent to the original WorkerId check -
#    it only catches repeats from the same computer/IP, not someone using
#    a different one under the same MTurk account - so it's expected to
#    catch fewer repeats than the original. This is reported via
#    `message()` rather than silently assumed complete.
#  - The per-row participant identifier is a pseudonymous ID
#    (participant_NNNN) substituted for the raw log's MD5 IP hash before
#    this repo was created - see deidentify_raw_logs.R. It plays the same
#    structural role the MD5 hash played in the original script (grouping
#    a participant's own rows together, and detecting repeat submissions
#    within or across rounds).
#  - Exclusion is tracked with a human-readable `excl_reason` rather than a
#    single overwritten boolean, and every exclusion step reports the
#    number of participants/trials it removes via `message()`.
#  - Output is a set of tidy, per-task tables (participants/expectations/
#    cloze/recall/maze/spr/mazerace) rather than one wide table joined on
#    `code` - this matches the per-task-table shape used for the 2024 data.

library(tidyverse)

RT_MIN_MS <- 180
RT_MAX_MS <- 10000

# Distinct pseudonymous participant IDs (2nd comma-separated field) seen
# anywhere in a raw log, comment lines excluded. Used to pass one round's
# full set of IDs into another round's `process_round()` call for the
# cross-round repeat check - this is deliberately the full raw set, not
# the "kept after exclusions" set, matching how the original pipeline's
# WorkerIdInPreviousRound check looked at the full previous round's MTurk
# records, not just its post-exclusion survivors.
read_participant_ids <- function(raw_log_path) {
  lines <- read_lines(raw_log_path)
  data_rows <- lines[!str_starts(lines, "#")]
  fields <- str_match(data_rows, "^[^,]*,([^,]*),")
  unique(fields[, 2])
}

# Pulls out the rows of a raw Ibex log that match `pattern`, parses them as
# headerless CSV, and keeps+renames the requested columns (1-indexed,
# matching the log's own column numbering documented in its comment
# header). This is the single place that talks to the raw log format, so
# every field extraction goes through it instead of repeating a
# grep-then-parse-then-rename block per field (as the original script did
# ~20 times).
extract_field <- function(lines, pattern, col_indices, col_names) {
  matched <- lines[str_detect(lines, pattern)]
  if (length(matched) == 0) {
    stop("No lines in the raw log matched pattern: ", pattern)
  }
  # Force column 1 (the submission timestamp) to parse as character in
  # every call - otherwise readr's per-call type guessing can infer
  # double for some fields and character for others (depending on how
  # many rows/what values that particular field happens to have), which
  # then makes every left_join() on `time` below fail with a type
  # mismatch. Timestamps are cast to numeric explicitly where needed
  # (see submission_time below).
  parsed <- read_csv(
    I(matched),
    col_names = FALSE,
    col_types = cols(X1 = col_character(), .default = col_guess()),
    show_col_types = FALSE
  )
  out <- parsed[col_indices]
  names(out) <- col_names
  out
}

# Builds the stimulus lookup used to attach sentence text, pronoun
# conditions, and pronoun/race-adjective word positions to SPR/Maze trials,
# keyed on the same `sens` string the raw log's SPR/Maze rows carry.
build_stimulus_lookup <- function(stimuli_path, stimuli_mazerace_path) {
  stims <- read_tsv(stimuli_path, n_max = 12, show_col_types = FALSE) |>
    rename(sen_context = Context) |>
    mutate(
      sen1 = paste(1:12, Sentence, sep = "_"),
      sen2 = paste(1:12, Sentence, sep = "_")
    ) |>
    tidyr::expand(sen_context, sen1, sen2) |>
    separate(sen1, sep = "_", into = c("sen1_number", "sen1")) |>
    separate(sen2, sep = "_", into = c("sen2_number", "sen2")) |>
    filter(sen1 != sen2) |>
    mutate(
      sens = paste(sen_context, sen1, sen2, sep = " "),
      words = str_split(sens, pattern = " ")
    ) |>
    rowwise() |>
    mutate(
      pro1_pos = which(words %in% c(
        "he|she|they", "his|her|their", "him|her|them"
      ))[1],
      pro2_pos = which(words %in% c(
        "he|she|they", "his|her|their", "him|her|them"
      ))[2],
      pro1_placeholder = words[pro1_pos],
      pro2_placeholder = words[pro2_pos]
    ) |>
    separate(pro1_placeholder,
      sep = "\\|", remove = FALSE,
      into = c("masculine", "feminine", "singular they")
    ) |>
    gather(
      key = "pro1_type", value = "pro1",
      masculine, feminine, `singular they`
    ) |>
    separate(pro2_placeholder,
      sep = "\\|", remove = FALSE,
      into = c("masculine", "feminine", "singular they")
    ) |>
    gather(
      key = "pro2_type", value = "pro2",
      masculine, feminine, `singular they`
    ) |>
    mutate(
      sen1 = str_replace(sen1, fixed(pro1_placeholder), pro1),
      sen2 = str_replace(sen2, fixed(pro2_placeholder), pro2),
      sens = str_replace(sens, fixed(pro1_placeholder), pro1),
      sens = str_replace(sens, fixed(pro2_placeholder), pro2)
    ) |>
    select(-words, -pro1_placeholder, -pro2_placeholder) |>
    ungroup()

  mazerace_stims <- read_tsv(stimuli_mazerace_path, show_col_types = FALSE) |>
    rename(sen_context = Context, sen1 = Sentence) |>
    mutate(
      sens = paste(sen_context, sen1, sep = " "),
      words = str_split(sens, pattern = " ")
    ) |>
    rowwise() |>
    mutate(
      raceadj_pos = which(words == "black|white|Black|White"),
      raceadj_placeholder = words[raceadj_pos]
    ) |>
    separate(raceadj_placeholder,
      sep = "\\|", remove = FALSE,
      into = c("black", "white", "Black", "White")
    ) |>
    gather(key = "to_be_removed", value = "raceadj", black, white, Black, White) |>
    mutate(
      sen1 = str_replace(sen1, fixed(raceadj_placeholder), raceadj),
      sens = str_replace(sens, fixed(raceadj_placeholder), raceadj)
    ) |>
    select(
      sen_context, sen1, ContextAlternatives, SentenceAlternatives,
      sens, raceadj_pos, raceadj
    ) |>
    ungroup() |>
    # The mazerace stimuli spreadsheet lists several distractor-wording
    # alternatives (ContextAlternatives/SentenceAlternatives) per sentence,
    # so multiple rows here share the same final `sens` text - but the raw
    # log's maze rows only ever carry `sens`, not which distractor variant
    # was shown, so joining on `sens` alone is inherently many-to-one from
    # the log's side. That's fine for raceadj_pos/raceadj (verified
    # identical across every row that shares a `sens`), but left as-is this
    # produces a many-to-many join that silently fans out every matching
    # maze row once per distractor-alternative variant, inflating N. Keep
    # one row per `sens`.
    distinct(sens, .keep_all = TRUE)

  list(stims = stims, mazerace_stims = mazerace_stims)
}

# Classifies a free-text cloze completion by which pronoun/candidate name
# it refers to the VP candidate with. Ports the classification rules from
# https://github.com/tpoppels/MadamePresident/blob/master/R/clean_cloze_data.script.R
# unchanged.
classify_cloze_response <- function(response) {
  idx_male <- str_detect(response, regex("\\b(his|he|him)\\b", ignore_case = TRUE))
  idx_female <- str_detect(response, regex("\\b(her|she)\\b", ignore_case = TRUE))
  idx_neutral <- str_detect(response, regex("\\b(they|their|them)\\b", ignore_case = TRUE))
  idx_both <- idx_male & idx_female
  idx_male <- idx_male & !idx_both
  idx_female <- idx_female & !idx_both

  idx_harris <- str_detect(response, regex("harris", ignore_case = TRUE))
  idx_pence <- str_detect(response, regex("pence", ignore_case = TRUE))
  idx_biden <- str_detect(response, regex("biden", ignore_case = TRUE))
  idx_trump <- str_detect(response, regex("trump", ignore_case = TRUE))

  out <- ifelse(!is.na(response), "none", NA_character_)
  out[idx_male] <- "male"
  out[idx_female] <- "female"
  out[idx_neutral] <- "neutral"
  out[idx_both] <- "both"
  out[idx_harris] <- "harris"
  out[idx_pence] <- "pence"
  out[idx_biden] <- "biden"
  out[idx_trump] <- "trump"
  out
}

# Processes one round's raw log end to end. `has_aware_question` selects
# whether to parse the post-election-only "are you aware the race was
# called" question. `previous_round_participant_ids` is the set of
# pseudonymous participant IDs seen in an earlier round (pass the
# pre-election round's IDs when processing post-election) - anyone
# appearing in both is excluded as a same-IP cross-round repeat; leave at
# the default (empty) for the first round processed, since there's no
# earlier round to check against. Returns a named list of tidy tibbles,
# one per task, ready to be written out by the calling driver script.
process_round <- function(raw_log_path, stimuli_path, stimuli_mazerace_path,
                           has_aware_question,
                           previous_round_participant_ids = character(0)) {
  lines <- read_lines(raw_log_path)

  code <- extract_field(lines, ",code,", c(1, 2, 8), c("time", "participant_id", "code"))
  condition <- extract_field(lines, ",condition,", c(1, 2, 8), c("time", "participant_id", "condition"))
  display_order <- extract_field(lines, ",event_expectation_display_order,", c(1, 2, 8), c("time", "participant_id", "display_order"))
  vp <- extract_field(lines, ",event_expectation_vice,", c(1, 2, 8), c("time", "participant_id", "asked_about_vp")) |>
    mutate(asked_about_vp = asked_about_vp == "true")
  news <- extract_field(lines, ",news,", c(1, 2, 9), c("time", "participant_id", "news_consumption"))
  age <- extract_field(lines, ",age,", c(1, 2, 9), c("time", "participant_id", "age"))
  gender <- extract_field(lines, ",Please select your gender.,", c(1, 2, 9), c("time", "participant_id", "gender"))
  state <- extract_field(lines, ",state,", c(1, 2, 9), c("time", "participant_id", "state"))
  education <- extract_field(lines, "education you have attained:", c(1, 2, 9), c("time", "participant_id", "education"))
  political_affiliation <- extract_field(lines, "political affiliation\\?", c(1, 2, 9), c("time", "participant_id", "political_affiliation"))
  citizen <- extract_field(lines, "citizen of the United States\\?", c(1, 2, 9), c("time", "participant_id", "citizen"))
  native <- extract_field(lines, "native speaker of English\\?", c(1, 2, 9), c("time", "participant_id", "native"))
  resident <- extract_field(lines, "reside in the United States\\?", c(1, 2, 9), c("time", "participant_id", "resident"))
  election_pref <- extract_field(lines, "<i>prefer</i>", c(1, 2, 9), c("time", "participant_id", "election_pref"))
  recall <- extract_field(lines, ",recall,", c(1, 2, 9), c("time", "participant_id", "recall_response"))
  cloze <- extract_field(lines, ",cloze,", c(1, 2, 4, 9), c("time", "participant_id", "cloze_item", "cloze_response"))

  event <- extract_field(lines, ",event,", c(1, 2, 8, 9), c("time", "participant_id", "field", "value")) |>
    pivot_wider(names_from = field, values_from = value)

  spr <- extract_field(
    lines, ",0,spr(-practice)?,", c(1, 2, 4, 8, 9, 10, 12),
    c("time", "participant_id", "spr_item_no", "spr_word_no", "spr_word", "spr_word_rt", "spr_sens")
  ) |>
    mutate(
      spr_sens = str_replace_all(spr_sens, "%2C", ","),
      spr_sens = str_replace_all(spr_sens, "%0A%0A", " "),
      spr_word = str_replace_all(spr_word, "%2C", ",")
    )

  maze <- extract_field(
    lines, "0,maze(-practice|race)?,", c(1, 2, 4, 8, 9, 10, 11, 12, 13, 14, 15),
    c(
      "time", "participant_id", "maze_item_no", "maze_word_no", "maze_word",
      "maze_distractor", "maze_word_location", "maze_word_correct",
      "maze_word_rt", "maze_sens", "maze_word_time_to_correct"
    )
  ) |>
    mutate(
      maze_word_no = maze_word_no + 1, # align word count with spr
      maze_sens = str_replace_all(maze_sens, "%2C", ","),
      maze_word = str_replace_all(maze_word, "%2C", ","),
      maze_distractor = str_replace_all(maze_distractor, "%2C", ",")
    )

  aware <- if (has_aware_question) {
    extract_field(
      lines,
      paste0(
        "Are you aware that major news outlets have officially ",
        "projected that the Biden-Harris ticket has defeated ",
        "the Trump-Pence ticket\\?"
      ),
      c(1, 2, 9), c("time", "participant_id", "aware")
    )
  } else {
    tibble(time = character(), participant_id = character(), aware = character())
  }

  d <- code |>
    left_join(condition, by = c("time", "participant_id")) |>
    left_join(display_order, by = c("time", "participant_id")) |>
    left_join(vp, by = c("time", "participant_id")) |>
    left_join(news, by = c("time", "participant_id")) |>
    left_join(age, by = c("time", "participant_id")) |>
    left_join(gender, by = c("time", "participant_id")) |>
    left_join(state, by = c("time", "participant_id")) |>
    left_join(education, by = c("time", "participant_id")) |>
    left_join(political_affiliation, by = c("time", "participant_id")) |>
    left_join(citizen, by = c("time", "participant_id")) |>
    left_join(native, by = c("time", "participant_id")) |>
    left_join(aware, by = c("time", "participant_id")) |>
    left_join(resident, by = c("time", "participant_id")) |>
    left_join(event, by = c("time", "participant_id")) |>
    left_join(election_pref, by = c("time", "participant_id")) |>
    left_join(cloze, by = c("time", "participant_id")) |>
    left_join(recall, by = c("time", "participant_id")) |>
    left_join(spr, by = c("time", "participant_id")) |>
    left_join(maze, by = c("time", "participant_id"))

  if (!has_aware_question) d$aware <- NA_character_

  d <- d |>
    mutate(
      candidate_value_dem = ifelse(display_order == "dem_first", candidate_1_value, candidate_2_value),
      candidate_value_rep = ifelse(display_order == "dem_first", candidate_2_value, candidate_1_value),
      candidate_value_someone_else = someone_else_value,
      candidate_value_sum = candidate_value_dem + candidate_value_rep + candidate_value_someone_else,
      candidate_prob_dem = candidate_value_dem / candidate_value_sum,
      candidate_prob_rep = candidate_value_rep / candidate_value_sum,
      candidate_prob_someone_else = candidate_value_someone_else / candidate_value_sum
    ) |>
    select(-candidate_1_value, -candidate_2_value, -someone_else_value)

  d$cloze_pronoun <- classify_cloze_response(d$cloze_response)

  lookup <- build_stimulus_lookup(stimuli_path, stimuli_mazerace_path)
  d <- d |>
    unite(col = "sens", remove = FALSE, na.rm = TRUE, spr_sens, maze_sens) |>
    left_join(lookup$stims, by = "sens") |>
    left_join(lookup$mazerace_stims, by = "sens") |>
    unite(col = "sen1", na.rm = TRUE, sen1.x, sen1.y) |>
    unite(col = "sen_context", na.rm = TRUE, sen_context.x, sen_context.y) |>
    mutate(
      sen_context = ifelse(sen_context == "", NA, sen_context),
      sen1 = ifelse(sen1 == "", NA, sen1)
    )

  d <- d |>
    mutate(
      submission_time = as.POSIXct(as.numeric(time), origin = "1970-01-01", tz = "UTC"),
      sid_long = paste(time, participant_id, sep = "_")
    ) |>
    select(-time)

  subs <- levels(as.factor(d$sid_long))
  d <- d |>
    mutate(
      sid = match(sid_long, subs),
      sid = sprintf(paste0("Sub%0", max(nchar(sid)), "d"), sid)
    )

  if (length(previous_round_participant_ids) > 0) {
    message(
      "process_round: excluding same-IP repeats against ",
      length(previous_round_participant_ids), " participant IDs from the ",
      "earlier round. This catches the same computer/IP being used in ",
      "both rounds, but - unlike the original pipeline's WorkerId-based ",
      "check, which isn't reproducible here (see STATUS.md) - it will ",
      "miss someone who used a different IP/browser under the same MTurk ",
      "account across rounds."
    )
  }

  # Repeat submissions within THIS round: since `participant_id` is a
  # 1:1 relabeling of the raw log's IP hash (see deidentify_raw_logs.R),
  # grouping by it reproduces the original repeat.md5 check exactly.
  repeats <- d |>
    distinct(sid_long, .keep_all = TRUE) |>
    group_by(participant_id) |>
    mutate(repeat_participant_id = submission_time > first(submission_time)) |>
    ungroup() |>
    select(sid_long, repeat_participant_id)

  d <- d |>
    left_join(repeats, by = "sid_long") |>
    group_by(sid) |>
    mutate(
      spr_max_rt = max(spr_word_rt),
      maze_max_rt = max(maze_word_rt),
      spr_min_rt = min(spr_word_rt),
      maze_min_rt = min(maze_word_rt)
    ) |>
    ungroup() |>
    mutate(
      excl_not_native = !is.na(native) & native != "yes",
      excl_repeat_participant = coalesce(repeat_participant_id, FALSE),
      excl_participated_in_previous_round = participant_id %in% previous_round_participant_ids,
      excl_spr_rt_too_slow = !is.na(spr_max_rt) & spr_max_rt >= RT_MAX_MS,
      excl_spr_rt_too_fast = !is.na(spr_min_rt) & spr_min_rt <= RT_MIN_MS,
      excl_maze_rt_too_slow = !is.na(maze_max_rt) & maze_max_rt >= RT_MAX_MS,
      excl_maze_rt_too_fast = !is.na(maze_min_rt) & maze_min_rt <= RT_MIN_MS,
      excl_no_slider_movement = candidate_value_dem == 0 &
        candidate_value_rep == 0 & candidate_value_someone_else == 0
    )

  # Build a human-readable excl_reason (e.g. "not_native;spr_rt_too_slow")
  # from the boolean flags above, one row at a time - done as a matrix
  # + apply() rather than a vectorized c()-index, since the flags are
  # per-row and need to stay aligned within a row, not concatenated
  # across rows.
  reason_labels <- c(
    "not_native", "repeat_participant", "participated_in_previous_round",
    "spr_rt_too_slow", "spr_rt_too_fast",
    "maze_rt_too_slow", "maze_rt_too_fast", "no_slider_movement"
  )
  reason_flags <- d |>
    select(
      excl_not_native, excl_repeat_participant, excl_participated_in_previous_round,
      excl_spr_rt_too_slow, excl_spr_rt_too_fast, excl_maze_rt_too_slow,
      excl_maze_rt_too_fast, excl_no_slider_movement
    ) |>
    as.matrix()
  d$excl_reason <- apply(reason_flags, 1, function(row) {
    matched <- reason_labels[row]
    if (length(matched) == 0) NA_character_ else paste(matched, collapse = ";")
  })
  d$excl <- !is.na(d$excl_reason)

  d <- d |>
    select(
      -spr_max_rt, -maze_max_rt, -spr_min_rt, -maze_min_rt, -repeat_participant_id,
      -excl_not_native, -excl_repeat_participant, -excl_participated_in_previous_round,
      -excl_spr_rt_too_slow, -excl_spr_rt_too_fast, -excl_maze_rt_too_slow,
      -excl_maze_rt_too_fast, -excl_no_slider_movement
    )

  n_participants <- n_distinct(d$sid)
  n_excluded <- n_distinct(d$sid[d$excl])
  message(
    "process_round: ", n_participants, " participants total, ",
    n_excluded, " excluded (", round(100 * n_excluded / n_participants, 1), "%). ",
    "Breakdown (participants can match more than one reason):"
  )
  d |>
    distinct(sid, excl_reason) |>
    filter(!is.na(excl_reason)) |>
    separate_rows(excl_reason, sep = ";") |>
    count(excl_reason) |>
    pwalk(\(excl_reason, n) message("  - ", excl_reason, ": ", n))

  d <- d |> filter(!excl)

  participants <- d |>
    distinct(
      sid, participant_id, submission_time, condition, display_order,
      asked_about_vp, news_consumption, age, gender, state, education,
      political_affiliation, citizen, native, resident, election_pref, aware
    )

  expectations <- d |>
    filter(!is.na(candidate_prob_dem)) |>
    distinct(
      sid, candidate_value_dem, candidate_value_rep, candidate_value_someone_else,
      candidate_prob_dem, candidate_prob_rep, candidate_prob_someone_else
    )

  cloze_out <- d |>
    filter(!is.na(cloze_response)) |>
    distinct(sid, condition, cloze_item, cloze_response, cloze_pronoun)

  recall_out <- d |>
    filter(!is.na(recall_response)) |>
    distinct(sid, condition, recall_response)

  maze_out <- d |>
    filter(!is.na(maze_word)) |>
    select(
      sid, condition, maze_item_no, maze_word_no, maze_word, maze_distractor,
      maze_word_location, maze_word_correct, maze_word_rt, maze_word_time_to_correct,
      sen_context, sen1, pro1_type, pro1, pro1_pos, pro2_type, pro2, pro2_pos,
      raceadj, raceadj_pos
    )

  spr_out <- d |>
    filter(!is.na(spr_word)) |>
    select(
      sid, condition, spr_item_no, spr_word_no, spr_word, spr_word_rt,
      sen_context, sen1, pro1_type, pro1, pro1_pos, pro2_type, pro2, pro2_pos
    )

  list(
    participants = participants,
    expectations = expectations,
    cloze = cloze_out,
    recall = recall_out,
    maze = maze_out,
    spr = spr_out
  )
}
