# Shared parsing/cleaning logic for the 2024 mmepr24 pre-election and
# post-election waves. Both waves go through `process_wave()` with
# wave-specific arguments, so they use identical parsing and exclusion
# criteria; prep_pre_election.R / prep_post_election.R are thin drivers.
#
# Output follows the common framework in ../../shared/common_schema.R
# (column meanings in ../../DATA.md): every session that started a task is
# kept, exclusions are recorded as columns, and RTs are the measured values.
# The original analysis's RT trimming, residualization and maze-error cutoff
# are analysis decisions, so they are not applied here; the session-level
# part of the maze-error cutoff is recorded as an exclusion column so the
# original sample can be reproduced.
#
# Differences from the original mmepr24 analysis/*-process.Rmd files:
#  - The original removed duplicates using a private file linking each
#    proliferate workerid to a Prolific ID (not in this repo). It excluded
#    (1) workerids with more than one survey response, (2) workerids linked
#    to more than one Prolific ID, and (3) workerids whose Prolific ID was
#    linked to more than one workerid. (1) is computed here from the trial
#    data. (2) and (3) can't be, so the workerids they removed are passed in
#    as `original_prolific_dedup_workerids`, found by comparing this
#    pipeline's output with the original's processed participant tables
#    (which were a strict subset of ours, by exactly these workerids).
#  - The original's `completion_code_correct_workerids` check was dead code
#    (computed but never applied in either original script) and is not
#    ported.
#  - `ParseJSONColumn` uses the post-election version's extra
#    quote-normalizing rule for both waves; the pre-election version fails
#    on post-election responses containing a quoted word.
#  - Cloze: `cloze_code` uses the shared classifier in common_schema.R.
#    The original 2024 coding is kept as `cloze_code_original`, using the
#    post-election version of its "ambiguous NP" regex for both waves (a
#    strict superset of the pre-election one) plus the hand-checked
#    `cloze_overrides` (pre-election only: in the post-election data the
#    overridden workerids don't exist).
#  - SPR: the original filtered the RT window after fitting its
#    residualization model in pre-election but before in post-election.
#    Neither happens here; that choice moves to the shared analysis step.

library(tidyverse)
library(jsonlite)

source("../../shared/common_schema.R")

MAZE_ERROR_SD_MULTIPLIER <- 2
# The SPR practice trial's text isn't logged; it is hard-coded in the
# experiment (2024-mmepr24/experiment/src/experiment.js:244-250).
SPR_PRACTICE_SENTENCE <- "Press space in order to reveal the next word."
NEWS_CHOICES <- c("Daily", "Weekly", "Monthly", "Less than monthly", "Never")

ParseJSONColumn <- function(x) {
  str_replace_all(x, c(
    "'" = '"',
    'I"d' = "I'd",
    '([A-Za-z]+)n"t' = "\\1n't",
    '([A-Za-z]+)"s' = "\\1's",
    'States" ' = "States' ",
    ' "([A-Za-z]+)" ' = " `\\1` ", # avoid breaking JSON parsing on a quoted word
    ": None" = ': "NA"'
  )) |> fromJSON(flatten = TRUE)
}

is_pronoun <- function(word) {
  pronouns <- c("she", "her", "hers", "he", "him", "his", "they", "them", "their", "theirs")
  clean_word <- gsub("^[[:punct:]]+|[[:punct:]]+$", "", word)
  tolower(clean_word) %in% pronouns
}

# The original 2024 cloze coding (post-election version of the regexes),
# kept for comparison with the shared `cloze_code`.
classify_cloze_response_original <- function(response) {
  case_when(
    str_detect(response, "(?i)\\b(he or she|she or he|she/he|he/she)\\b") ~ "hedged",
    str_detect(response, "(?i)\\b(she|her|hers)\\b") ~ "pronoun female",
    str_detect(response, "(?i)\\b(he|his|him)\\b") ~ "pronoun male",
    !(str_ends(response, "challenges, and one of") &
      str_detect(trimws(response), "(?i)^(them)\\b")) &
      str_detect(response, "(?i)\\b(they|their|them)\\b") ~ "pronoun neutral",
    str_detect(response, "(?i)\\b(trump|donald|president trump|president don)") ~ "Trump",
    str_detect(response, "(?i)\\b(harris|kamala|president harris|president kamala|the first black)") ~ "Harris",
    str_detect(response, "(?i)\\b(((the|next|u.s.|u.s|us|new(.*)) (president|potus))|the candidate)") ~ "ambiguous NP",
    TRUE ~ "OTHER"
  )
}

read_stimulus_lookup <- function(cloze_stim_path, comp_q_path, maze_stim_path) {
  cloze_stim <- read_csv(cloze_stim_path, col_types = cols(item = col_character(), partial = col_character()))
  comp_qa <- read_csv(comp_q_path, show_col_types = FALSE) |> mutate(item = as.character(item))
  sprmaze_stim <- read_csv(maze_stim_path, show_col_types = FALSE) |>
    mutate(item = as.character(item), s_len = str_count(sentence, "\\S+")) |>
    mutate(
      words = str_split(sentence, " "),
      # Items 3 and 11 have a second pronoun that doesn't refer to the
      # president; the first pronoun is the critical one.
      pron_pos_s = map_int(words, ~ which(is_pronoun(.x))[1])
    ) |>
    select(-words)
  list(cloze_stim = cloze_stim, comp_qa = comp_qa, sprmaze_stim = sprmaze_stim)
}

# Unnests one SPR or Maze trial row per session into one row per word.
# Every per-word list in the trial must have the same length as the words.
unnest_reading_trials <- function(trials, list_cols) {
  lengths_ok <- trials |>
    mutate(across(all_of(list_cols), lengths, .names = "n_{.col}")) |>
    mutate(ok = if_all(starts_with("n_"), \(n) n == n_word))
  if (!all(lengths_ok$ok)) {
    stop(sum(!lengths_ok$ok), " reading trials have per-word lists of unequal length")
  }
  trials |>
    unnest(all_of(c("word", setdiff(list_cols, "word")))) |>
    mutate(.by = c(workerid, run, trial_index), word_index = row_number())
}

# Adds sentence positions and pronoun flags to critical-trial words: each
# critical trial is the starter sentence (s0) followed by two item sentences.
attach_sentence_positions <- function(words, sprmaze_stim) {
  s0_len <- filter(sprmaze_stim, item == "start")$s_len[[1]]
  stim <- sprmaze_stim |> filter(item != "start") |> select(item, type, s_len, pron_pos_s)
  words |>
    left_join(stim, join_by(sen1_item == item, pro1_type == type)) |>
    rename(s1_len = s_len, pron_pos_s1 = pron_pos_s) |>
    left_join(stim, join_by(sen2_item == item, pro2_type == type)) |>
    rename(s2_len = s_len, pron_pos_s2 = pron_pos_s) |>
    mutate(
      sentence_index = as.integer(case_when(
        is_practice ~ NA,
        word_index <= s0_len ~ 0,
        word_index <= s0_len + s1_len ~ 1,
        .default = 2
      )),
      word_index_in_sentence = as.integer(case_when(
        is_practice ~ NA,
        sentence_index == 0 ~ word_index,
        sentence_index == 1 ~ word_index - s0_len,
        .default = word_index - s0_len - s1_len
      )),
      is_pro1 = !is_practice & word_index == s0_len + pron_pos_s1,
      is_pro2 = !is_practice & word_index == s0_len + s1_len + pron_pos_s2
    ) |>
    select(-s1_len, -s2_len, -pron_pos_s1, -pron_pos_s2)
}

# Processes one wave end to end and returns the common-framework tables.
#  - `wave`: "pre" or "post".
#  - `apply_political_aff_fix`: pre-election only. A survey bug put political
#    affiliation under the "news" topic for some participants; fixed in the
#    instrument before the post-election wave.
#  - `cloze_overrides`: (workerid, item) pairs hand-checked to need the
#    original coding's "ambiguous NP" label (affects cloze_code_original only).
#  - `original_prolific_dedup_workerids`: see the file-level comment.
process_wave <- function(trials_path, cloze_stim_path, comp_q_path, maze_stim_path,
                         wave, apply_political_aff_fix,
                         cloze_overrides = tibble(workerid = numeric(), item = character()),
                         original_prolific_dedup_workerids = numeric()) {
  # A workerid can hold more than one run of the experiment (the trial
  # counter restarts); each run that reached a task is its own session.
  raw <- read_csv(trials_path, show_col_types = FALSE) |>
    select(-proliferate.condition) |>
    mutate(.by = workerid, run = 1L + cumsum(trial_index <= lag(trial_index, default = -1L)))
  stim <- read_stimulus_lookup(cloze_stim_path, comp_q_path, maze_stim_path)

  # --- Sessions: every run that has a condition, i.e. started a task ---
  session_conditions <- raw |>
    filter(!is.na(condition)) |>
    distinct(workerid, run, condition)
  if (anyDuplicated(session_conditions[c("workerid", "run")])) stop("A run has more than one condition")
  if (any(session_conditions$workerid >= 10000)) stop("workerid too large for the session_id format")
  n_not_started <- nrow(distinct(raw, workerid, run)) - nrow(session_conditions)
  message(wave, ": ", nrow(session_conditions), " sessions started a task; ",
          n_not_started, " runs never reached a task and are not kept")
  missing_from_dedup <- setdiff(original_prolific_dedup_workerids, session_conditions$workerid)
  if (length(missing_from_dedup) > 0) {
    stop("original_prolific_dedup_workerids not in this wave: ", toString(missing_from_dedup))
  }

  base <- session_conditions |>
    mutate(
      study = "2024", round = wave,
      session_id = sprintf("2024-%s-%04d-%d", wave, workerid, run),
      task = str_remove(condition, "-?event-?"),
      task_order = if_else(str_starts(condition, "event"), "event_first", "task_first"),
      expectation_target = "president"
    )
  id_of <- select(base, workerid, run, study, round, session_id)
  # Attaches study/round/session_id to a per-run table, dropping rows of
  # runs that never started a task, and checking nothing else is lost.
  with_ids <- function(df) {
    out <- inner_join(id_of, df, by = c("workerid", "run"), relationship = "one-to-many")
    n_unknown <- nrow(anti_join(df, id_of, by = c("workerid", "run")))
    if (nrow(out) + n_unknown != nrow(df)) stop("Attaching session ids changed the row count")
    out
  }

  # --- Event expectations (long: one row per candidate per slider response) ---
  expectations <- raw |>
    filter(trial_type == "survey-slider") |>
    select(workerid, run, trial_index, response) |>
    mutate(response = map(response, ParseJSONColumn)) |>
    unnest_longer(response, indices_to = "candidate") |>
    mutate(
      slider_value = as.numeric(response),
      candidate_party = recode(candidate, harris = "dem", trump = "rep", other = "other"),
      candidate_name = recode(candidate, harris = "Kamala Harris", trump = "Donald Trump", other = "someone else")
    ) |>
    mutate(.by = c(workerid, run, trial_index), probability = slider_value / sum(slider_value)) |>
    # All sliders at 0 (no movement): probability undefined, not NaN.
    mutate(probability = if_else(is.nan(probability), NA_real_, probability)) |>
    with_ids() |>
    mutate(expectation_target = "president") |>
    select(study, round, session_id, expectation_target, candidate_party, candidate_name,
           slider_value, probability, workerid, trial_index)
  if (anyNA(expectations$slider_value)) stop("Non-numeric slider values")

  # --- Cloze ---
  cloze <- raw |>
    filter(trial_type == "cloze") |>
    select(workerid, run, item, response) |>
    mutate(item = as.character(item), response = map_chr(response, \(x) {
      parsed <- ParseJSONColumn(x)
      if (length(parsed) != 1) stop("Cloze response with ", length(parsed), " fields")
      as.character(parsed[[1]])
    })) |>
    left_join(stim$cloze_stim, join_by(item)) |>
    rename(prompt = partial, cloze_item = item)
  if (anyNA(cloze$prompt)) stop("Cloze items without a prompt in the stimulus file")
  settings <- cloze_coding_settings[["2024"]]
  cloze <- cloze |>
    bind_cols(code_cloze_response(
      cloze$response,
      female_names = settings$female_names,
      male_names = settings$male_names,
      other_names = settings$other_names,
      them_not_referential = str_detect(cloze$prompt, "one of\\s*$"),
      target_office = settings$target_office
    )) |>
    bind_cols(flag_cloze_nonsense(cloze$response, cloze$prompt, study = "2024", cloze$cloze_item,
                                  judgments = read_cloze_single_word_judgments(),
                                  pasted_text = read_cloze_pasted_text())) |>
    (\(df) bind_cols(df, code_cloze_coreference(df$response, study = "2024", df$cloze_item,
                                                reference_columns = df, target_office = settings$target_office,
                                                judgments = read_cloze_coreference_judgments(),
                                                them_not_referential = str_detect(df$prompt, "one of\\s*$"))))() |>
    mutate(
      cloze_code_original = classify_cloze_response_original(response),
      cloze_code_original = if_else(
        paste(workerid, cloze_item) %in% paste(cloze_overrides$workerid, cloze_overrides$item),
        "ambiguous NP", cloze_code_original
      )
    ) |>
    with_ids()

  # --- Reading (Maze and SPR, critical and practice trials) ---
  split_item_type <- function(df) {
    df |>
      mutate(
        is_practice = is.na(condition),
        sen1_item = if_else(is_practice, NA, str_split_i(item, "-", 1)),
        sen2_item = if_else(is_practice, NA, str_split_i(item, "-", 2)),
        pro1_type = if_else(is_practice, NA, str_split_i(type, "-", 1)),
        pro2_type = if_else(is_practice, NA, str_split_i(type, "-", 2))
      )
  }
  spr <- raw |>
    filter(trial_type == "spr") |>
    select(workerid, run, trial_index, condition, item, type, rt, sentence) |>
    mutate(sentence = if_else(is.na(condition), SPR_PRACTICE_SENTENCE, sentence))
  if (anyNA(spr$sentence)) stop("Critical SPR trials without a logged sentence")
  spr <- spr |>
    mutate(
      word = str_split(sentence, " "),
      # The first RT is for the display before the first word appears.
      rt = map(rt, \(x) ParseJSONColumn(x)[-1]),
      n_word = lengths(word)
    ) |>
    unnest_reading_trials(c("word", "rt")) |>
    mutate(task = "spr", maze_correct = NA, maze_distractor = NA_character_,
           maze_correct_side = NA_character_, maze_time_to_correct = NA_real_)
  maze <- raw |>
    filter(trial_type == "maze") |>
    select(workerid, run, trial_index, condition, item, type, rt, cumrt, correct, words, distractors, order) |>
    mutate(
      word = map(words, ParseJSONColumn),
      rt = map(rt, ParseJSONColumn),
      maze_time_to_correct = map(cumrt, ParseJSONColumn),
      maze_correct = map(correct, ParseJSONColumn),
      maze_distractor = map(distractors, ParseJSONColumn),
      n_word = lengths(word),
      # The correct word's side is logged for the practice trial only; the
      # critical trials' `order` field is empty in the raw data.
      maze_correct_side = map2(order, n_word, \(x, n) if (is.na(x)) rep(NA_integer_, n) else ParseJSONColumn(x))
    ) |>
    unnest_reading_trials(c("word", "rt", "maze_time_to_correct", "maze_correct", "maze_distractor", "maze_correct_side")) |>
    mutate(
      task = "maze",
      maze_correct = case_when(maze_correct == 0 ~ FALSE, maze_correct == 1 ~ TRUE),
      maze_correct_side = case_when(maze_correct_side == 0 ~ "left", maze_correct_side == 1 ~ "right")
    )
  if (anyNA(maze$maze_correct)) stop("Unexpected Maze correct codes")
  if (anyNA(maze$maze_correct_side[is.na(maze$condition)])) stop("Practice Maze trial without a logged correct side")
  reading <- bind_rows(spr, maze) |>
    split_item_type() |>
    attach_sentence_positions(stim$sprmaze_stim) |>
    mutate(
      rt = as.double(rt), maze_time_to_correct = as.double(maze_time_to_correct),
      race_adjective = NA_character_, is_race_adjective = FALSE
    ) |>
    with_ids()
  critical <- filter(reading, !is_practice)
  pronoun_counts <- critical |>
    summarize(.by = c(session_id, trial_index), n_pro1 = sum(is_pro1), n_pro2 = sum(is_pro2))
  if (any(pronoun_counts$n_pro1 != 1 | pronoun_counts$n_pro2 != 1)) {
    stop("Critical reading trials without exactly one pronoun-1 and one pronoun-2 word")
  }

  # --- Comprehension questions (one per Maze/SPR session) ---
  comprehension <- raw |>
    filter(trial_type == "html-button-response", !is.na(item)) |>
    select(workerid, run, item, response) |>
    mutate(
      item = as.character(item),
      # Buttons were Yes (0) then No (1).
      answer = case_when(response == "0" ~ "Yes", response == "1" ~ "No")
    ) |>
    left_join(stim$comp_qa, join_by(item)) |>
    rename(question = q, correct_answer = a) |>
    mutate(correct = tolower(answer) == tolower(correct_answer))
  if (anyNA(comprehension$answer) || anyNA(comprehension$correct_answer)) {
    stop("Comprehension responses with unknown answer codes or items")
  }
  comprehension <- comprehension |>
    with_ids() |>
    left_join(select(base, session_id, task), by = "session_id")

  # --- Recall ("who does the writer believe will be president?") ---
  recall <- raw |>
    filter(trial_type == "html-button-response", !is.na(recall_order)) |>
    select(workerid, run, response, recall_order) |>
    mutate(recall_response = map2_chr(recall_order, response, \(order, choice) {
      ParseJSONColumn(order)[as.integer(choice) + 1]
    })) |>
    with_ids() |>
    select(study, round, session_id, recall_response, workerid, run)

  # --- Demographics (in-experiment survey) ---
  survey <- raw |>
    filter(trial_type == "survey") |>
    select(workerid, run, trial_index, response) |>
    mutate(response = map(response, ParseJSONColumn)) |>
    unnest_longer(response, indices_to = "topic", transform = as.character) |>
    mutate(
      response = na_if(response, "NA"),
      topic = if_else(topic == "poltical_aff", "political_aff", topic)
    )
  if (apply_political_aff_fix) {
    survey <- survey |>
      mutate(topic = if_else(topic == "news" & !is.na(response) & !(response %in% NEWS_CHOICES),
                             "political_aff_from_news", topic))
  }
  survey <- survey |>
    pivot_wider(id_cols = c(workerid, run, trial_index), names_from = topic, values_from = response)
  if (apply_political_aff_fix) {
    survey <- survey |> mutate(political_aff = coalesce(political_aff, political_aff_from_news))
  }
  if (anyDuplicated(survey[c("workerid", "run")])) stop("A run has more than one survey response")
  # The original's duplicate check counted survey responses per workerid,
  # across runs.
  n_surveys <- count(survey, workerid, name = "n_survey_responses_workerid")

  if (anyDuplicated(distinct(expectations, session_id, trial_index)$session_id)) {
    stop("A session has more than one event-expectation response")
  }
  session_expectations <- expectations |>
    select(session_id, candidate_party, probability) |>
    pivot_wider(names_from = candidate_party, values_from = probability, names_prefix = "expect_prob_")

  maze_accuracy <- critical |>
    filter(task == "maze") |>
    summarize(.by = session_id, maze_accuracy = mean(maze_correct), maze_n_errors = sum(!maze_correct))
  comprehension_summary <- comprehension |>
    summarize(.by = session_id, comprehension_n = n(), comprehension_n_correct = sum(correct))
  mobile <- raw |>
    filter(trial_type == "browser-check") |>
    summarize(.by = c(workerid, run), device_mobile = any(mobile))

  sessions <- base |>
    left_join(select(survey, -trial_index), by = c("workerid", "run")) |>
    left_join(n_surveys, by = "workerid") |>
    left_join(session_expectations, by = "session_id") |>
    left_join(recall |> slice_head(n = 1, by = session_id) |> select(session_id, recall_response), by = "session_id") |>
    left_join(comprehension_summary, by = "session_id") |>
    left_join(maze_accuracy, by = "session_id") |>
    left_join(mobile, by = c("workerid", "run")) |>
    mutate(
      has_survey = session_id %in% session_id[!is.na(age) | !is.na(gender) | !is.na(citizen)],
      n_survey_responses_workerid = coalesce(n_survey_responses_workerid, 0L),
      comprehension_n = coalesce(comprehension_n, 0L),
      comprehension_n_correct = coalesce(comprehension_n_correct, 0L),
      age = as.integer(age),
      news_consumption = if_else(news %in% NEWS_CHOICES, tolower(news), NA_character_),
      political_affiliation = political_aff,
      us_citizen = citizen == "Yes", us_resident = residence == "Yes", native_english = english == "Yes",
      election_pref = prefer
    )
  if (nrow(sessions) != nrow(base)) stop("Building the sessions table changed the number of sessions")

  # --- Exclusions (original 2024 pipeline, one column per criterion) ---
  # The original kept only sessions with a survey response, then removed
  # duplicates and screened on residence/citizenship/native English. Maze
  # and SPR (and recall, which only reading-task sessions saw) also required
  # a correct comprehension answer; Maze additionally dropped sessions with
  # more errors than mean + 2 SD of the remaining Maze sessions.
  sessions <- sessions |>
    mutate(
      excl_no_survey = !has_survey,
      excl_duplicate_submission = n_survey_responses_workerid > 1,
      excl_original_prolific_dedup = workerid %in% original_prolific_dedup_workerids,
      excl_not_us_resident = !coalesce(us_resident, FALSE),
      excl_not_us_citizen = !coalesce(us_citizen, FALSE),
      excl_not_native_english = !coalesce(native_english, FALSE),
      excl_comprehension_wrong = task %in% c("maze", "spr") & comprehension_n_correct == 0,
      excl_expectations_original = excl_no_survey | excl_duplicate_submission | excl_original_prolific_dedup |
        excl_not_us_resident | excl_not_us_citizen | excl_not_native_english
    )
  maze_cutoff_pool <- sessions |> filter(task == "maze", !excl_expectations_original, !excl_comprehension_wrong)
  maze_error_cutoff <- floor(mean(maze_cutoff_pool$maze_n_errors) + MAZE_ERROR_SD_MULTIPLIER * sd(maze_cutoff_pool$maze_n_errors))
  message(wave, ": Maze error cutoff (mean + ", MAZE_ERROR_SD_MULTIPLIER, " SD over ", nrow(maze_cutoff_pool),
          " sessions) = ", maze_error_cutoff)
  sessions <- sessions |>
    mutate(
      excl_maze_errors_over_cutoff = task == "maze" & coalesce(maze_n_errors > maze_error_cutoff, FALSE),
      excl_task_original = excl_expectations_original | excl_comprehension_wrong | excl_maze_errors_over_cutoff,
      # The original's recall table applied the comprehension check but not
      # the Maze error cutoff.
      excl_recall_original = excl_expectations_original | excl_comprehension_wrong,
      # 2024 has no corrections to the original rules, so the replication
      # columns equal the original-rule columns.
      excl_task_original_replication = excl_task_original,
      excl_expectations_original_replication = excl_expectations_original
    ) |>
    select(-any_of(c("news", "political_aff", "political_aff_from_news", "citizen", "residence", "english", "prefer", "intro")))

  list(
    sessions = check_core_schema(sessions, "sessions"),
    expectations = check_core_schema(expectations, "expectations"),
    cloze = check_core_schema(cloze, "cloze"),
    reading = check_core_schema(reading, "reading"),
    comprehension = check_core_schema(comprehension, "comprehension"),
    recall = check_core_schema(recall, "recall")
  )
}
