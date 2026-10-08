# Shared parsing/cleaning logic for the 2020 MVP pre-election and
# post-election rounds. Both rounds are processed by calling
# `process_round()` from this file with round-specific arguments, so the
# two rounds are guaranteed to use identical parsing, exclusion criteria,
# and RT thresholds - see prep_pre_election.R / prep_post_election.R for
# the thin per-round drivers.
#
# Design: nothing is dropped here. Every Ibex session is kept, and every
# exclusion criterion - the ones the original analysis applied and further
# candidate criteria for robustness checks - is recorded as a column of
# the `sessions` table. Analyses choose an exclusion set by filtering on
# those columns. See ../README.md ("Exclusions") for the full list.
#
# Differences from the original MadameVicePresident pre-processing.R this
# is derived from:
#  - Participant identifiers are pseudonymous. `participant_id`
#    (participant_NNNN) replaces the raw log's MD5 IP hash (see
#    deidentify_raw_logs.R); `worker` (worker_NNNN) replaces the MTurk
#    WorkerId and comes from ../raw/mturk_session_linkage.csv, built outside
#    this repo by private/2020-mturk/build_mturk_linkage.R. Both pseudonyms
#    are shared across rounds.
#  - Sessions are linked to MTurk by survey code + a time window rather than
#    the original's code + 2-hour-rounded time (which missed sessions that
#    straddled a rounding boundary). The original linkage is carried along
#    as `worker_original_method` so the original exclusion counts can be
#    reproduced exactly (see validate_against_original.R).
#  - The original's "worker took part in the pre-election round" check used
#    a pre-election MTurk file that also contained 7 post-election
#    assignments; `excl_worker_in_pre_round` uses the corrected list.
#  - Output is a set of tidy tables (sessions/expectations/cloze/recall/
#    comprehension/maze/spr) keyed by `session_id`, rather than one wide
#    table joined on `code` - this matches the per-task-table shape used
#    for the 2024 data.

library(tidyverse)

source("../../shared/common_schema.R")

RT_MIN_MS <- 180
RT_MAX_MS <- 10000

# Distinct pseudonymous participant IDs (2nd comma-separated field) seen
# anywhere in a raw log. Used to pass one round's
# full set of IDs into another round's `process_round()` call for the
# `flag_ip_in_pre_round` candidate flag - deliberately the full raw set,
# not the "kept after exclusions" set, mirroring how the worker-based
# cross-round exclusion uses every pre-election MTurk assignment.
read_participant_ids <- function(raw_log_path) {
  lines <- read_lines(raw_log_path)
  fields <- str_match(lines, "^[^,]*,([^,]*),")
  if (anyNA(fields[, 2])) stop("Raw log rows without a participant_id field in ", raw_log_path)
  unique(fields[, 2])
}

# Pulls out the rows of a raw Ibex log that match `pattern`, parses them as
# headerless CSV, and keeps+renames the requested columns (1-indexed,
# matching the log's own column numbering documented in its comment
# header). This is the single place that talks to the raw log format, so
# every field extraction goes through it instead of repeating a
# grep-then-parse-then-rename block per field (as the original script did
# ~20 times).
# `character_cols` (1-indexed raw-log column numbers) are read as
# character instead of being type-guessed, for columns that need explicit
# handling of non-numeric values.
extract_field <- function(lines, pattern, col_indices, col_names, character_cols = integer(0)) {
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
  forced_character <- set_names(
    rep(list(col_character()), length(character_cols) + 1),
    paste0("X", c(1, character_cols))
  )
  parsed <- read_csv(
    I(matched),
    col_names = FALSE,
    col_types = do.call(cols, c(forced_character, list(.default = col_guess()))),
    show_col_types = FALSE
  )
  if (nrow(problems(parsed)) > 0) {
    stop("Parsing problems reading raw-log rows matching '", pattern, "':\n",
         paste(capture.output(print(problems(parsed))), collapse = "\n"))
  }
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
      # One item per distinct race sentence frame (several spreadsheet rows
      # share a frame, differing only in distractor alternatives).
      race_item = as.character(match(sen1, unique(sen1))),
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
      sen_context, sen1, race_item, ContextAlternatives, SentenceAlternatives,
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


# Time points used by candidate exclusion flags (all UTC).
# Election day: 2020-11-03 00:00 US Eastern (EST, UTC-5).
ELECTION_DAY_START_UTC <- as.POSIXct("2020-11-03 05:00:00", tz = "UTC")
# Major networks/AP projected Biden-Harris the winners on 2020-11-07 at
# about 11:25 US Eastern (EST, UTC-5).
RACE_CALLED_UTC <- as.POSIXct("2020-11-07 16:25:00", tz = "UTC")
MAZE_ACCURACY_THRESHOLD <- 0.8

session_keys <- c("time", "participant_id")

# Converts a raw RT column read as character to numeric, mapping Ibex's
# literal "None" to NA and failing on any other non-numeric value.
parse_rt_allowing_none <- function(rt) {
  rt[rt == "None"] <- NA_character_
  parsed <- parse_double(rt)
  if (nrow(problems(parsed)) > 0) stop("Non-numeric RT values other than 'None' in the raw log")
  parsed
}

# Fails loudly if a per-session table has more than one row for a session.
assert_one_row_per_session <- function(df, what) {
  if (anyDuplicated(df[, session_keys])) {
    stop(what, ": more than one row for some session (time, participant_id)")
  }
  df
}

# Answer key for the comprehension questions, from the stimulus files.
# Question text is unique per item, so it is used as the join key.
build_comprehension_key <- function(stimuli_path, stimuli_mazerace_path) {
  key <- bind_rows(
    read_tsv(stimuli_path, n_max = 12, show_col_types = FALSE) |> select(Question, Answer),
    read_tsv(stimuli_mazerace_path, show_col_types = FALSE) |> select(Question, Answer)
  ) |>
    distinct() |>
    rename(question = Question, correct_answer = Answer)
  if (anyDuplicated(key$question)) stop("Comprehension question text is not unique in the stimulus files")
  key
}

# Session-level reading-time and accuracy summaries.
# `*_min_rt`/`*_max_rt` reproduce the original criterion exactly, so they
# are taken over every SPR/Maze word the participant saw, practice and
# (for Maze) the mazerace item included. The proportion and accuracy
# measures use experimental items only (no practice). Missing ("None")
# SPR RTs are ignored; `spr_n_missing_rt` records how many there were.
summarise_rt_measures <- function(spr, maze) {
  spr_summary <- spr |>
    group_by(time, participant_id) |>
    summarise(
      spr_n_missing_rt = sum(is.na(spr_word_rt)),
      spr_n_valid_rt = sum(!is.na(spr_word_rt)),
      spr_min_rt = min(spr_word_rt, na.rm = TRUE),
      spr_max_rt = max(spr_word_rt, na.rm = TRUE),
      spr_prop_rt_out_of_range = mean(
        (spr_word_rt <= RT_MIN_MS | spr_word_rt >= RT_MAX_MS)[spr_type == "spr"],
        na.rm = TRUE
      ),
      .groups = "drop"
    )
  if (any(spr_summary$spr_n_valid_rt == 0)) stop("A session has SPR rows but no valid SPR RT")
  if (anyNA(maze$maze_word_rt)) stop("Missing Maze RTs - not expected in this data")
  maze_summary <- maze |>
    group_by(time, participant_id) |>
    summarise(
      maze_min_rt = min(maze_word_rt),
      maze_max_rt = max(maze_word_rt),
      maze_prop_rt_out_of_range = mean(
        (maze_word_rt <= RT_MIN_MS | maze_word_rt >= RT_MAX_MS)[maze_type != "maze-practice"]
      ),
      maze_accuracy = mean((maze_word_correct == "yes")[maze_type != "maze-practice"]),
      .groups = "drop"
    )
  list(spr = spr_summary, maze = maze_summary)
}

# Within-round repeat structure: how many sessions share this session's IP
# pseudonym / MTurk worker, and where this session falls in time among
# them (rank 1 = first). Rank is by Ibex receipt time.
add_repeat_ranks <- function(sessions) {
  sessions |>
    arrange(submission_time) |>
    group_by(participant_id) |>
    mutate(ip_n_sessions_round = n(), ip_session_rank_round = row_number()) |>
    group_by(worker) |>
    mutate(
      worker_n_sessions_round = if_else(is.na(worker), NA_integer_, n()),
      worker_session_rank_round = if_else(is.na(worker), NA_integer_, row_number())
    ) |>
    group_by(worker_original_method) |>
    mutate(worker_original_method_session_rank_round = if_else(
      is.na(worker_original_method), NA_integer_, row_number()
    )) |>
    ungroup()
}

# Exclusion columns. `excl_*` are the criteria the original analysis
# applied; `excl_original_rule` is their union. `flag_*` are further
# candidate criteria that the original did not apply, for robustness
# checks. Every column is TRUE/FALSE with no NA: a criterion that cannot
# be evaluated for a session (e.g. no SPR task) is FALSE.
add_exclusion_columns <- function(sessions, round_name, previous_round_participant_ids) {
  sessions |>
    mutate(
      # --- applied in the original analysis ---
      excl_not_native = native != "yes",
      excl_repeat_ip = ip_session_rank_round > 1,
      excl_repeat_worker = coalesce(worker_session_rank_round > 1, FALSE),
      excl_worker_in_pre_round = worker_in_pre_round,
      excl_spr_rt_too_fast = coalesce(spr_min_rt <= RT_MIN_MS, FALSE),
      excl_spr_rt_too_slow = coalesce(spr_max_rt >= RT_MAX_MS, FALSE),
      excl_maze_rt_too_fast = coalesce(maze_min_rt <= RT_MIN_MS, FALSE),
      excl_maze_rt_too_slow = coalesce(maze_max_rt >= RT_MAX_MS, FALSE),
      excl_no_slider_movement = candidate_value_dem == 0 &
        candidate_value_rep == 0 & candidate_value_someone_else == 0,
      excl_original_rule = excl_not_native | excl_repeat_ip | excl_repeat_worker |
        excl_worker_in_pre_round | excl_spr_rt_too_fast | excl_spr_rt_too_slow |
        excl_maze_rt_too_fast | excl_maze_rt_too_slow | excl_no_slider_movement,

      # --- candidate criteria, not applied in the original analysis ---
      flag_not_linked_to_mturk = !linked_to_mturk,
      flag_code_submitted_by_multiple_workers = code_submitted_by_multiple_workers,
      flag_worker_did_multiple_assignments = coalesce(worker_n_assignments_round > 1, FALSE),
      flag_ip_had_multiple_sessions = ip_n_sessions_round > 1,
      flag_ip_in_pre_round = participant_id %in% previous_round_participant_ids,
      flag_not_us_resident = resident != "yes",
      flag_not_us_citizen = citizen != "yes",
      flag_comprehension_wrong = coalesce(!comprehension_correct, FALSE),
      flag_maze_accuracy_low = coalesce(maze_accuracy < MAZE_ACCURACY_THRESHOLD, FALSE),
      flag_pre_on_or_after_election_day = round_name == "pre" & submission_time >= ELECTION_DAY_START_UTC,
      flag_post_before_race_called = round_name == "post" & submission_time < RACE_CALLED_UTC,
      flag_post_unaware_race_called = round_name == "post" & coalesce(aware != "yes", FALSE)
    )
}

# Reproduces the original analysis's exclusion exactly, using the
# original MTurk linkage and the uncorrected pre-election worker list.
# Only used to validate this pipeline against the original's published
# counts (validate_against_original.R) - analyses should use
# `excl_original_rule`.
add_original_replication_column <- function(sessions) {
  sessions |>
    mutate(excl_original_replication =
      excl_not_native | excl_repeat_ip |
        coalesce(worker_original_method_session_rank_round > 1, FALSE) |
        worker_in_pre_round_original_method |
        # The original took min()/max() without na.rm, so a session with
        # any missing SPR RT got NA and escaped both SPR RT criteria.
        (coalesce(spr_n_missing_rt, 0) == 0 & (excl_spr_rt_too_fast | excl_spr_rt_too_slow)) |
        excl_maze_rt_too_fast | excl_maze_rt_too_slow | excl_no_slider_movement)
}

report_exclusions <- function(sessions, round_name) {
  counts <- sessions |>
    summarise(across(c(starts_with("excl_"), starts_with("flag_")), sum)) |>
    pivot_longer(everything(), names_to = "column", values_to = "n_sessions")
  message(
    "process_round (", round_name, "): ", nrow(sessions), " sessions; ",
    sum(!sessions$excl_original_rule), " kept under excl_original_rule. ",
    "Sessions flagged per column (columns overlap):"
  )
  pwalk(counts, \(column, n_sessions) message("  - ", column, ": ", n_sessions))
}

# Processes one round's raw log end to end and returns a named list of
# tidy tibbles keyed by `session_id`. `round_name` is "pre" or "post".
# `submissions_path` is the round's raw/*_ibex_submissions.csv (one row per
# submission, carrying Ibex's design number).
# `mturk_linkage` is ../raw/mturk_session_linkage.csv (all rounds; filtered
# here). `previous_round_participant_ids` is the set of IP pseudonyms seen
# in the pre-election raw log (pass it for post; empty for pre).
process_round <- function(raw_log_path, submissions_path, stimuli_path, stimuli_mazerace_path,
                          round_name, has_aware_question, mturk_linkage,
                          previous_round_participant_ids = character(0)) {
  lines <- read_lines(raw_log_path)
  design_number <- read_csv(submissions_path,
    col_types = cols(time = col_character(), participant_id = col_character(), design_number = col_integer())
  )

  # --- Session-level fields (one row per session each) ---
  code <- extract_field(lines, ",code,", c(1, 2, 8), c("time", "participant_id", "code"))
  condition <- extract_field(lines, ",condition,", c(1, 2, 8), c("time", "participant_id", "condition"))
  display_order <- extract_field(lines, ",event_expectation_display_order,", c(1, 2, 8), c("time", "participant_id", "display_order"))
  # Read as character: readr would otherwise guess "true"/"false" as
  # logical, and the comparison below would always be FALSE.
  vp <- extract_field(lines, ",event_expectation_vice,", c(1, 2, 8), c("time", "participant_id", "asked_about_vp"),
                      character_cols = 8) |>
    mutate(asked_about_vp = case_when(asked_about_vp == "true" ~ TRUE, asked_about_vp == "false" ~ FALSE))
  if (anyNA(vp$asked_about_vp)) stop("event_expectation_vice values other than true/false")
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
  event <- extract_field(lines, ",event,", c(1, 2, 8, 9), c("time", "participant_id", "field", "value")) |>
    pivot_wider(names_from = field, values_from = value)
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

  session_fields <- list(
    design_number, condition, display_order, vp, news, age, gender, state, education,
    political_affiliation, citizen, native, resident, election_pref, event, aware
  )
  walk(session_fields, \(df) assert_one_row_per_session(df, paste(names(df)[3], "field")))
  assert_one_row_per_session(code, "code")
  if (nrow(design_number) != nrow(code) || nrow(anti_join(code, design_number, by = session_keys)) > 0) {
    stop("The submissions file and the raw log's code rows don't cover the same sessions")
  }

  # --- Task data (several rows per session) ---
  recall <- extract_field(lines, ",recall,", c(1, 2, 9), c("time", "participant_id", "recall_response")) |>
    assert_one_row_per_session("recall")
  cloze <- extract_field(lines, ",cloze,", c(1, 2, 4, 9), c("time", "participant_id", "cloze_item", "cloze_response")) |>
    mutate(cloze_pronoun = classify_cloze_response(cloze_response))

  comprehension_key <- build_comprehension_key(stimuli_path, stimuli_mazerace_path)
  comprehension <- extract_field(
    lines, ",Question,[0-9]+,1,(spr|maze|mazerace),", c(1, 2, 6, 8, 9, 11),
    c("time", "participant_id", "question_task", "question", "answer", "question_rt")
  ) |>
    left_join(comprehension_key, by = "question", relationship = "many-to-one") |>
    mutate(correct = answer == correct_answer) |>
    assert_one_row_per_session("comprehension")
  if (anyNA(comprehension$correct_answer)) stop("Some comprehension questions are not in the stimulus answer key")

  lookup <- build_stimulus_lookup(stimuli_path, stimuli_mazerace_path)

  spr <- extract_field(
    lines, ",0,spr(-practice)?,", c(1, 2, 4, 6, 8, 9, 10, 12),
    c("time", "participant_id", "spr_item_no", "spr_type", "spr_word_no", "spr_word", "spr_word_rt", "spr_sens"),
    character_cols = 10
  ) |>
    mutate(
      # Ibex occasionally logs the RT of a sentence-final word as "None"
      # (7 sessions pre, 1 post). Treat it as missing; anything else
      # non-numeric is unexpected.
      spr_word_rt = parse_rt_allowing_none(spr_word_rt),
      spr_sens = str_replace_all(spr_sens, "%2C", ","),
      spr_sens = str_replace_all(spr_sens, "%0A%0A", " "),
      spr_word = str_replace_all(spr_word, "%2C", ",")
    ) |>
    left_join(lookup$stims, by = c("spr_sens" = "sens"), relationship = "many-to-one")

  maze <- extract_field(
    lines, "0,maze(-practice|race)?,", c(1, 2, 4, 6, 8, 9, 10, 11, 12, 13, 14, 15),
    c(
      "time", "participant_id", "maze_item_no", "maze_type", "maze_word_no", "maze_word",
      "maze_distractor", "maze_word_location", "maze_word_correct",
      "maze_word_rt", "maze_sens", "maze_word_time_to_correct"
    )
  ) |>
    mutate(
      maze_word_no = maze_word_no + 1, # align word count with spr
      maze_sens = str_replace_all(maze_sens, "%2C", ","),
      maze_word = str_replace_all(maze_word, "%2C", ","),
      maze_distractor = str_replace_all(maze_distractor, "%2C", ",")
    ) |>
    left_join(lookup$stims, by = c("maze_sens" = "sens"), relationship = "many-to-one") |>
    left_join(lookup$mazerace_stims, by = c("maze_sens" = "sens"), relationship = "many-to-one") |>
    mutate(
      sen_context = coalesce(sen_context.x, sen_context.y),
      sen1 = coalesce(sen1.x, sen1.y)
    ) |>
    select(-ends_with(".x"), -ends_with(".y"), -ContextAlternatives, -SentenceAlternatives)

  stopifnot(
    "Experimental SPR rows did not all match a stimulus" =
      !anyNA(spr$sen1[spr$spr_type == "spr"]),
    "Experimental Maze rows did not all match a stimulus" =
      !anyNA(maze$sen1[maze$maze_type != "maze-practice"])
  )

  # Every task row must belong to a session that has a code row.
  for (task in list(spr = spr, maze = maze, cloze = cloze, recall = recall, comprehension = comprehension)) {
    orphan <- anti_join(distinct(task, time, participant_id), code, by = session_keys)
    if (nrow(orphan) > 0) stop(nrow(orphan), " task-row sessions have no code row")
  }

  rt_measures <- summarise_rt_measures(spr, maze)

  # --- MTurk linkage ---
  linkage <- mturk_linkage |>
    filter(round == round_name) |>
    mutate(time = as.character(time)) |>
    select(-round)
  if (nrow(linkage) != nrow(code)) {
    stop("MTurk linkage has ", nrow(linkage), " rows for ", round_name, " but the raw log has ", nrow(code), " sessions")
  }

  # --- Assemble the sessions table ---
  sessions <- reduce(session_fields, \(acc, df) left_join(acc, df, by = session_keys), .init = code) |>
    left_join(recall, by = session_keys) |>
    left_join(comprehension |> select(time, participant_id, comprehension_correct = correct), by = session_keys) |>
    left_join(rt_measures$spr, by = session_keys) |>
    left_join(rt_measures$maze, by = session_keys) |>
    left_join(linkage, by = session_keys, relationship = "one-to-one")
  if (nrow(sessions) != nrow(code)) stop("Building the sessions table changed the number of sessions")
  if (anyNA(sessions$linked_to_mturk)) stop("Some sessions have no row in the MTurk linkage file")
  if (!has_aware_question) sessions$aware <- NA_character_

  sessions <- sessions |>
    mutate(
      candidate_value_dem = ifelse(display_order == "dem_first", candidate_1_value, candidate_2_value),
      candidate_value_rep = ifelse(display_order == "dem_first", candidate_2_value, candidate_1_value),
      candidate_value_someone_else = someone_else_value,
      candidate_value_sum = candidate_value_dem + candidate_value_rep + candidate_value_someone_else,
      candidate_prob_dem = candidate_value_dem / candidate_value_sum,
      candidate_prob_rep = candidate_value_rep / candidate_value_sum,
      candidate_prob_someone_else = candidate_value_someone_else / candidate_value_sum,
      submission_time = as.POSIXct(as.numeric(time), origin = "1970-01-01", tz = "UTC"),
      round = round_name
    ) |>
    select(-candidate_1_value, -candidate_2_value, -someone_else_value) |>
    arrange(time, participant_id) |>
    mutate(session_id = sprintf("2020-%s-%04d", round_name, row_number())) |>
    add_repeat_ranks() |>
    add_exclusion_columns(round_name, previous_round_participant_ids) |>
    add_original_replication_column()

  exclusion_columns <- sessions |> select(starts_with("excl_"), starts_with("flag_"))
  if (anyNA(exclusion_columns)) {
    stop("NA in exclusion columns: ", toString(names(exclusion_columns)[colSums(is.na(exclusion_columns)) > 0]))
  }
  report_exclusions(sessions, round_name)

  build_common_tables(sessions, cloze, recall, comprehension, spr, maze, stimuli_path, round_name)
}

# Ibex URL-encodes commas (%2C) and newlines (%0A) inside free-text fields;
# no other encodings occur in these logs.
decode_ibex_text <- function(x) {
  x |> str_replace_all("%2C", ",") |> str_replace_all("%0A", " ")
}

pronoun_type_names <- c(masculine = "he", feminine = "she", `singular they` = "they")

# Turns the round's parsed tables into the common-framework tables (see
# ../../shared/common_schema.R and ../../DATA.md), keyed by session_id.
build_common_tables <- function(sessions, cloze, recall, comprehension, spr, maze, stimuli_path, round_name) {
  sessions <- sessions |>
    mutate(
      study = "2020",
      task = str_remove(condition, "-?event-?"),
      task_order = if_else(str_starts(condition, "event"), "event_first", "task_first"),
      expectation_target = if_else(asked_about_vp, "vice_president", "president"),
      age = as.integer(age),
      us_citizen = citizen == "yes", us_resident = resident == "yes", native_english = native == "yes",
      expect_prob_dem = candidate_prob_dem, expect_prob_rep = candidate_prob_rep,
      expect_prob_other = candidate_prob_someone_else,
      comprehension_n = as.integer(!is.na(comprehension_correct)),
      comprehension_n_correct = as.integer(coalesce(comprehension_correct, FALSE)),
      # The original 2020 analysis dropped excluded participants from every
      # analysis, so one rule covers both the task and the expectations.
      excl_task_original = excl_original_rule,
      excl_task_original_replication = excl_original_replication,
      excl_expectations_original = excl_original_rule,
      excl_expectations_original_replication = excl_original_replication
    ) |>
    select(-excl_original_rule, -excl_original_replication)

  ids <- sessions |> select(time, participant_id, study, round, session_id)
  with_ids <- function(df) {
    out <- df |> inner_join(ids, by = session_keys, relationship = "many-to-one")
    if (nrow(out) != nrow(df)) stop("Attaching session_id dropped rows")
    out |> select(study, round, session_id, everything(), -time, -participant_id)
  }

  # Long event expectations: dem/rep candidates depend on which office the
  # session was asked about.
  expectations <- sessions |>
    filter(!is.na(candidate_value_dem)) |>
    select(study, round, session_id, expectation_target,
           dem = candidate_value_dem, rep = candidate_value_rep, other = candidate_value_someone_else) |>
    pivot_longer(c(dem, rep, other), names_to = "candidate_party", values_to = "slider_value") |>
    mutate(
      slider_value = as.double(slider_value),
      candidate_name = case_when(
        candidate_party == "other" ~ "someone else",
        expectation_target == "vice_president" & candidate_party == "dem" ~ "Kamala Harris",
        expectation_target == "vice_president" & candidate_party == "rep" ~ "Mike Pence",
        candidate_party == "dem" ~ "Joe Biden",
        candidate_party == "rep" ~ "Donald Trump"
      ),
      .by = session_id, probability = slider_value / sum(slider_value)
    ) |>
    # All sliders at 0 (no movement): probability undefined, not NaN.
    mutate(probability = if_else(is.nan(probability), NA_real_, probability))

  # Cloze item k is row k of stimuli.tsv; the prompt is the context plus the
  # critical sentence up to the pronoun slot (as in items.js:243-245).
  cloze_prompts <- read_tsv(stimuli_path, n_max = 12, show_col_types = FALSE, name_repair = "unique_quiet") |>
    transmute(
      cloze_item = as.character(row_number()),
      prompt = str_trim(paste(Context, str_remove(Sentence, "[a-z]+\\|[a-z]+\\|[a-z]+.+$")))
    )
  cloze <- cloze |>
    mutate(cloze_item = as.character(cloze_item), response = decode_ibex_text(cloze_response)) |>
    left_join(cloze_prompts, by = "cloze_item", relationship = "many-to-one") |>
    rename(cloze_code_original = cloze_pronoun) |>
    select(-cloze_response)
  if (anyNA(cloze$prompt)) stop("Cloze items without a prompt")
  settings <- cloze_coding_settings[["2020"]]
  cloze <- bind_cols(cloze, code_cloze_response(
    cloze$response,
    female_names = settings$female_names,
    male_names = settings$male_names,
    other_names = settings$other_names,
    them_not_referential = str_detect(cloze$prompt, "one of\\s*$"),
    target_office = settings$target_office
  )) |>
    bind_cols(flag_cloze_nonsense(cloze$response, cloze$prompt, study = "2020", cloze$cloze_item,
                                  judgments = read_cloze_single_word_judgments(),
                                  pasted_text = read_cloze_pasted_text())) |>
    (\(df) bind_cols(df, code_cloze_coreference(df$response, study = "2020", df$cloze_item,
                                                reference_columns = df, target_office = settings$target_office,
                                                judgments = read_cloze_coreference_judgments(),
                                                them_not_referential = str_detect(df$prompt, "one of\\s*$"))))() |>
    with_ids()

  # Reading: SPR and Maze/mazerace words, critical and practice trials.
  word_count <- \(x) str_count(x, "\\S+")
  reading <- bind_rows(
    spr |> transmute(
      time, participant_id, task = "spr", is_practice = spr_type == "spr-practice",
      sen1_item = sen1_number, sen2_item = sen2_number, pro1_type, pro2_type,
      race_adjective = NA_character_, raceadj_pos = NA_integer_,
      word_index = as.integer(spr_word_no), word = spr_word, rt = as.double(spr_word_rt),
      maze_correct = NA, maze_distractor = NA_character_, maze_correct_side = NA_character_,
      maze_time_to_correct = NA_real_, sen_context, sen1, pro1_pos, pro2_pos
    ),
    maze |> transmute(
      time, participant_id,
      task = if_else(maze_type == "mazerace", "mazerace", "maze"),
      is_practice = maze_type == "maze-practice",
      sen1_item = coalesce(sen1_number, race_item), sen2_item = sen2_number, pro1_type, pro2_type,
      race_adjective = raceadj, raceadj_pos = as.integer(raceadj_pos),
      word_index = as.integer(maze_word_no), word = maze_word, rt = as.double(maze_word_rt),
      maze_correct = case_when(maze_word_correct == "yes" ~ TRUE, maze_word_correct == "no" ~ FALSE),
      maze_distractor,
      maze_correct_side = case_when(maze_word_location == 0 ~ "left", maze_word_location == 1 ~ "right"),
      maze_time_to_correct = as.double(maze_word_time_to_correct),
      sen_context, sen1, pro1_pos, pro2_pos
    )
  ) |>
    mutate(
      pro1_type = unname(pronoun_type_names[pro1_type]),
      pro2_type = unname(pronoun_type_names[pro2_type]),
      n_context = word_count(sen_context), n_sen1 = word_count(sen1),
      sentence_index = as.integer(case_when(
        is_practice ~ NA,
        word_index <= n_context ~ 0,
        word_index <= n_context + n_sen1 ~ 1,
        .default = 2
      )),
      word_index_in_sentence = as.integer(case_when(
        is_practice ~ NA,
        sentence_index == 0 ~ word_index,
        sentence_index == 1 ~ word_index - n_context,
        .default = word_index - n_context - n_sen1
      )),
      is_pro1 = !is_practice & coalesce(word_index == pro1_pos, FALSE),
      is_pro2 = !is_practice & coalesce(word_index == pro2_pos, FALSE),
      is_race_adjective = !is_practice & coalesce(word_index == raceadj_pos, FALSE)
    ) |>
    select(-n_context, -n_sen1, -sen_context, -sen1, -pro1_pos, -pro2_pos, -raceadj_pos) |>
    with_ids()
  if (anyNA(reading$maze_correct[reading$task != "spr"])) stop("Unexpected Maze correct codes")
  if (anyNA(reading$maze_correct_side[reading$task != "spr"])) stop("Unexpected Maze word-location codes")
  # Every critical gender trial has one pronoun-1 and one pronoun-2 word,
  # and every mazerace trial one race adjective.
  per_trial <- reading |>
    filter(!is_practice) |>
    summarize(.by = c(session_id, task), n_pro1 = sum(is_pro1), n_pro2 = sum(is_pro2), n_race = sum(is_race_adjective))
  if (any(per_trial$task != "mazerace" & (per_trial$n_pro1 != 1 | per_trial$n_pro2 != 1)) ||
      any(per_trial$task == "mazerace" & per_trial$n_race != 1)) {
    stop("Critical reading trials without exactly one critical word")
  }
  pronoun_words <- reading |> filter(is_pro1 | is_pro2) |> pull(word) |> str_remove_all("[[:punct:]]") |> tolower()
  if (!all(pronoun_words %in% c("he", "she", "they", "his", "her", "their", "him", "them"))) {
    stop("Words flagged as pronouns that aren't pronouns")
  }

  comprehension <- comprehension |>
    rename(task = question_task) |>
    mutate(question = decode_ibex_text(question), answer = decode_ibex_text(answer)) |>
    with_ids()
  recall <- with_ids(recall)

  sessions <- sessions |>
    select(study, round, session_id, participant_id, worker, submission_time, everything(), -time)

  list(
    sessions = check_core_schema(sessions, "sessions"),
    expectations = check_core_schema(expectations, "expectations"),
    cloze = check_core_schema(cloze, "cloze"),
    reading = check_core_schema(reading, "reading"),
    comprehension = check_core_schema(comprehension, "comprehension"),
    recall = check_core_schema(recall, "recall")
  )
}
