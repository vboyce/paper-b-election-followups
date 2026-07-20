# Shared parsing/cleaning logic for the 2024 mmepr24 pre-election and
# post-election waves. Both waves are processed by calling
# `process_wave()` from this file with wave-specific arguments, so the two
# waves are guaranteed to use identical parsing, exclusion criteria, and
# RT thresholds - see prep_pre_election.R / prep_post_election.R for the
# thin per-wave drivers.
#
# Differences from the original mmepr24 analysis/*-process.Rmd files this
# is derived from:
#  - No dependency on the Prolific-linked files (data/mme_*-workerids.csv,
#    data/prolific_export_*.csv) - neither is part of this repo (they
#    carry real Prolific IDs; see STATUS.md). The original scripts only
#    used those files for (a) detecting a workerid linked to more than one
#    Prolific account, and (b) a `completion_code_correct_workerids` check
#    that was already dead code (computed but never actually applied to
#    `included_participants` in either original script). (a) is not
#    reproducible here and is reported loudly by `process_wave()`; (b) is
#    simply not ported, since it did nothing in the originals either.
#    Participant screening (residence/citizenship/English) still works
#    because those questions were asked directly in the in-experiment
#    survey, not sourced from Prolific.
#  - `ParseJSONColumn` uses the post-election version's extra
#    quote-normalizing rule unconditionally. It's not just cosmetic: the
#    pre-election version of this function fails outright on post-election
#    responses that contain a quoted word (e.g. Trump will begin his
#    "reign"...) - so the superset has to be used for both waves, not just
#    post, for this to be a shared function at all.
#  - The cloze "ambiguous NP" classifier regex uses the post-election
#    version (a strict superset of the pre-election one: also matches
#    "potus", "u.s. president", "the candidate") for both waves, so the
#    same free-text response is scored the same way regardless of wave.
#  - The hardcoded `workerid %in% c(1676, 2291)` cloze override is applied
#    only where it was verified against the actual response text (the
#    pre-election wave - both IDs' item-12 responses do use an uncaught
#    "the [US] president" NP). In the post-election data neither workerid
#    exists at all (checked directly: 0 matching rows out of 4939
#    participants), so applying the same override there was dead code
#    copied over from the pre-election script; it's simply not passed for
#    post-election here rather than silently kept around as a no-op that
#    would misfire if a future post-election re-run ever reused those
#    numeric IDs for different people.
#  - The SPR RT window (>180ms, <5000ms, and the same window applied to
#    the next 3 words) is now filtered *before* fitting the residualization
#    model in both waves. The original pre-election script filtered
#    *after* fitting the model (so the model was fit on a different,
#    unfiltered row set than post-election's), which the code review
#    flagged as making pre/post SPR RTs not computed by the identical
#    procedure. Filtering first means the residualization model is fit on
#    exactly the rows that end up in the analysis, which is also the more
#    defensible choice statistically (extreme/unreliable RTs shouldn't
#    influence the model used to residualize the RTs that remain).
#  - RT/exclusion thresholds are named constants instead of literals
#    repeated in each wave's script.

library(tidyverse)
library(here)
library(jsonlite)

RT_MIN_MS <- 180
RT_MAX_MS <- 5000
MAZE_ERROR_SD_MULTIPLIER <- 2

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

side_msg <- \(df, msg, fn) {
  message(msg, fn(df))
  df
}

gmean <- function(x) exp(mean(log(x)))

is_pronoun <- function(word) {
  pronouns <- c("she", "her", "hers", "he", "him", "his", "they", "them", "their", "theirs")
  clean_word <- gsub("^[[:punct:]]+|[[:punct:]]+$", "", word)
  tolower(clean_word) %in% pronouns
}

# Classifies a cloze completion's reference to the presidential candidate.
# Uses the broader (post-election) regex for "ambiguous NP" so pre and
# post score identical free text the same way.
classify_cloze_response <- function(response) {
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
  cloze_stim <- read_csv(cloze_stim_path, show_col_types = FALSE)
  comp_qa <- read_csv(comp_q_path, show_col_types = FALSE)
  sprmaze_stim <- read_csv(maze_stim_path, show_col_types = FALSE) |>
    mutate(.by = c(item, sentence), s_len = str_count(sentence, "\\S+")) |>
    mutate(
      words = str_split(sentence, " "),
      # Note in items 3 and 11 there is a second pronoun, but not
      # referring to the president.
      pron_pos_s = map_int(words, ~ which(is_pronoun(.x))[1])
    ) |>
    select(-words)
  list(cloze_stim = cloze_stim, comp_qa = comp_qa, sprmaze_stim = sprmaze_stim)
}

# Attaches sentence text and pronoun position to a raw SPR/Maze table
# (both have the same shape: one row per word, `item`/`type` split into
# item1-item2/type1-type2 for the two sentences shown).
attach_sentence_positions <- function(trial_words, sprmaze_stim) {
  s0 <- filter(sprmaze_stim, item == "start")$sentence[[1]]
  s0_len <- filter(sprmaze_stim, item == "start")$s_len[[1]]
  stim_s12 <- sprmaze_stim |>
    select(-distractor) |>
    filter(item != "start") |>
    mutate(item = as.numeric(item))

  trial_words$s0 <- s0
  trial_words |>
    left_join(stim_s12, join_by(item1 == item, type1 == type)) |>
    rename(s1 = sentence, s1_len = s_len, pron_pos_s1 = pron_pos_s) |>
    left_join(stim_s12, join_by(item2 == item, type2 == type)) |>
    rename(s2 = sentence, s2_len = s_len, pron_pos_s2 = pron_pos_s) |>
    mutate(
      is_pron1 = word_number == (s0_len + pron_pos_s1),
      is_pron2 = word_number == (s0_len + s1_len + pron_pos_s2),
      is_target = is_pron1 | is_pron2,
      is_first_in_sent = word_number == 1 |
        word_number == s0_len + 1 |
        word_number == s0_len + s1_len + 1,
      word_number_in_s = case_when(
        word_number <= s0_len ~ word_number,
        word_number <= s0_len + s1_len ~ word_number - s0_len,
        .default = word_number - s0_len - s1_len
      ),
      in_s = case_when(
        word_number <= s0_len ~ 0,
        word_number <= s0_len + s1_len ~ 1,
        .default = 2
      )
    )
}

# Processes one wave end to end. `apply_political_aff_fix` selects
# whether to apply the pre-election-only fix for a survey bug where
# political affiliation was mislabeled under the "news" topic for some
# participants (fixed in the post-election survey instrument itself, so
# not needed there). `cloze_overrides` is a tibble of (workerid, item)
# pairs verified by hand to need the "ambiguous NP" classification
# regardless of what the regex says - empty by default, and should only
# be populated for a wave after checking the actual response text (see
# the file-level comment above for why the original override doesn't
# carry over to post-election).
process_wave <- function(trials_path, cloze_stim_path, comp_q_path, maze_stim_path,
                          apply_political_aff_fix,
                          cloze_overrides = tibble(workerid = numeric(), item = numeric())) {
  raw <- read_csv(trials_path, show_col_types = FALSE) |>
    select(-proliferate.condition) |>
    filter(!is.na(condition))

  stim <- read_stimulus_lookup(cloze_stim_path, comp_q_path, maze_stim_path)

  expectations_all <- raw |>
    filter(trial_type == "survey-slider") |>
    select(workerid, condition, response) |>
    mutate(response = map(response, ParseJSONColumn)) |>
    unnest_longer(response, indices_to = "candidate") |>
    mutate(
      response = as.numeric(response),
      candidate = factor(candidate, levels = c("harris", "trump", "other"))
    ) |>
    mutate(.by = workerid, probability = response / sum(as.numeric(response)))

  cloze_all <- raw |>
    filter(trial_type == "cloze") |>
    select(workerid, item, response) |>
    mutate(response = map(response, ParseJSONColumn), item = as.numeric(item)) |>
    unnest(response) |>
    left_join(stim$cloze_stim, join_by(item))

  spr_all <- raw |>
    filter(trial_type == "spr") |>
    select(workerid, item, type, rt, text = sentence) |>
    mutate(word = str_split(text, " "), rt = map(rt, ParseJSONColumn)) |>
    rowwise() |>
    mutate(rt = list(rt[-1])) |>
    ungroup() |>
    unnest(c(word, rt)) |>
    mutate(.by = c(workerid, item, text), word_number = row_number()) |>
    separate(item, into = c("item1", "item2"), sep = "-", remove = FALSE, convert = TRUE) |>
    separate(type, into = c("type1", "type2"), sep = "-", remove = FALSE) |>
    attach_sentence_positions(stim$sprmaze_stim)

  maze_all <- raw |>
    filter(trial_type == "maze") |>
    select(workerid, item, type, rt, correct, text = sentence, word = words, distractor = distractors) |>
    mutate(
      rt = map(rt, ParseJSONColumn),
      correct = map(correct, ParseJSONColumn),
      word = map(word, ParseJSONColumn),
      distractor = map(distractor, ParseJSONColumn)
    ) |>
    unnest(c(rt, correct, word, distractor)) |>
    mutate(correct = case_when(correct == 0 ~ FALSE, correct == 1 ~ TRUE, .default = NA)) |>
    mutate(.by = c(workerid, item, text), word_number = row_number()) |>
    separate(item, into = c("item1", "item2"), sep = "-", remove = FALSE, convert = TRUE) |>
    separate(type, into = c("type1", "type2"), sep = "-", remove = FALSE) |>
    attach_sentence_positions(stim$sprmaze_stim)

  recall_question_all <- raw |>
    filter(trial_type == "html-button-response" & !is.na(recall_order)) |>
    select(workerid, response, stimulus, recall_order) |>
    mutate(recall_order = map(recall_order, ParseJSONColumn)) |>
    rowwise() |>
    mutate(response = recall_order[as.numeric(response) + 1]) |>
    select(-recall_order) |>
    ungroup()

  comp_q <- raw |>
    filter(trial_type == "html-button-response" & !is.na(item)) |>
    select(workerid, item, response) |>
    mutate(
      # 0 means the first item in the list, which was Yes
      response = case_when(response == "0" ~ "Yes", response == "1" ~ "No", .default = response),
      item = as.numeric(item)
    ) |>
    left_join(stim$comp_qa, join_by(item)) |>
    mutate(is_correct = tolower(response) == tolower(a))

  comp_q_correct_workerids <- unique(filter(comp_q, is_correct)$workerid)

  demographics <- raw |>
    filter(trial_type == "survey") |>
    select(workerid, condition, response) |>
    mutate(response = map(response, ParseJSONColumn)) |>
    unnest_longer(response, indices_to = "topic") |>
    mutate(response = ifelse(response == "NA", NA, response)) |>
    mutate(topic = ifelse(topic == "poltical_aff", "political_aff", topic))

  if (apply_political_aff_fix) {
    # Political affiliation was mislabeled under the "news" topic for some
    # pre-election participants; coalesce it back in if the response came
    # from that choice list. Fixed in the survey instrument itself before
    # the post-election wave ran, so not needed there.
    demographics <- demographics |>
      mutate(topic = ifelse(
        topic == "news" & !(response %in% c("Daily", "Weekly", "Monthly", "Less than monthly", "Never")),
        "TEMP", topic
      )) |>
      pivot_wider(names_from = "topic", values_from = "response") |>
      mutate(political_aff = coalesce(political_aff, TEMP)) |>
      select(-TEMP)
  } else {
    demographics <- demographics |> pivot_wider(names_from = "topic", values_from = "response")
  }

  demographics <- demographics |>
    mutate(age_bin = factor(case_when(
      age < 18 ~ "<18",
      age >= 18 & age <= 24 ~ "18-24",
      age >= 25 & age <= 34 ~ "25-34",
      age >= 35 & age <= 44 ~ "35-44",
      age >= 45 & age <= 54 ~ "45-54",
      age >= 55 & age <= 64 ~ "55-64",
      age >= 65 ~ "≥65"
    ), levels = c("<18", "18-24", "25-34", "35-44", "45-54", "55-64", "≥65")))

  # Duplicate submissions under the same workerid are detectable directly
  # from the in-experiment survey data. What is NOT reproducible here is
  # detecting one real person completing the study under two *different*
  # Prolific accounts/workerids - the original scripts caught that by
  # joining in a workerid<->Prolific-account linkage file that isn't part
  # of this repo (it carries real Prolific IDs; see STATUS.md).
  message(
    "process_wave: not applying the original scripts' 'workerid linked to ",
    "multiple Prolific accounts' exclusion - that check required the ",
    "Prolific export/workerid-linkage files, which are not part of this ",
    "repo. Only same-workerid duplicate submissions are caught here."
  )
  workerids_many_from <- demographics |>
    group_by(workerid) |>
    filter(n() > 1) |>
    pull(workerid) |>
    unique()
  if (length(workerids_many_from) > 0) {
    message(length(workerids_many_from), " workerids submitted more than once. Will exclude.")
  }

  demographics_uniq <- demographics |> filter(!(workerid %in% workerids_many_from))

  included_participants <- demographics_uniq |>
    side_msg("Participant exclusion. Initial: ", nrow) |>
    filter(residence == "Yes", citizen == "Yes", english == "Yes") |>
    side_msg("After screening criteria: ", nrow) |>
    select(workerid) |>
    distinct() |>
    side_msg("After removing duplicates: ", nrow)

  exclude_participants <- function(df, use_comp_q = TRUE) {
    ids <- if (use_comp_q) {
      intersect(included_participants$workerid, comp_q_correct_workerids)
    } else {
      included_participants$workerid
    }
    filter(df, workerid %in% ids)
  }

  expectations <- exclude_participants(expectations_all, use_comp_q = FALSE)
  conditions <- expectations |>
    select(workerid, condition) |>
    distinct()

  recall_question <- exclude_participants(recall_question_all) |>
    left_join(conditions, join_by(workerid))

  cloze <- exclude_participants(cloze_all, use_comp_q = FALSE) |>
    mutate(response_type = classify_cloze_response(response)) |>
    mutate(response_type = if_else(
      paste(workerid, item) %in% paste(cloze_overrides$workerid, cloze_overrides$item),
      "ambiguous NP",
      response_type
    )) |>
    select(workerid, item, response, response_type, everything()) |>
    left_join(conditions, join_by(workerid))

  spr <- exclude_participants(spr_all) |>
    mutate(included_rt = rt > RT_MIN_MS & rt < RT_MAX_MS) |>
    left_join(conditions, join_by(workerid))
  message(
    "SPR: Proportion RTs excluded for being unreasonably fast or slow: ",
    format(100 - 100 * nrow(filter(spr, included_rt)) / nrow(spr_all), digits = 2), "%."
  )
  spr <- spr |>
    mutate(
      .by = c(workerid, item, text),
      across(
        c(rt, included_rt, word),
        list(
          "1next" = ~ lead(.x, 1L), "2next" = ~ lead(.x, 2L), "3next" = ~ lead(.x, 3L)
        )
      )
    ) |>
    filter(if_all(starts_with("included_rt"))) |>
    rowwise() |>
    mutate(rt_gmean = gmean(c_across(matches("^rt$|^rt_(.)next$")))) |>
    ungroup() |>
    select(-starts_with("included_rt"))

  spr_mean_rts <- spr |>
    filter(word_number < pron_pos_s1) |>
    group_by(workerid) |>
    summarize(gmean_rt = gmean(rt))
  spr <- spr |>
    mutate(
      nchar = nchar(gsub("^[[:punct:]]+|[[:punct:]]+$", "", trimws(word))),
      comma = grepl(",", word),
      period = grepl("[.]", word)
    ) |>
    inner_join(spr_mean_rts, by = "workerid")
  m <- lme4::lmer(
    log(rt) ~ 1 + (
      scale(log(gmean_rt)) + scale(word_number) + scale(nchar) + is_first_in_sent + comma + period
    )^2 + (1 | item),
    spr
  )
  spr$rt.raw <- spr$rt
  spr$rt <- exp(residuals(m) + lme4::fixef(m)[1])
  spr <- spr |> arrange(item1, item2, type1, type2, workerid, word_number)

  maze <- exclude_participants(maze_all) |>
    left_join(conditions, join_by(workerid))
  maze_errors <- maze |>
    summarize(.by = workerid, errors = sum(!correct)) |>
    mutate(cutoff = floor(mean(errors) + MAZE_ERROR_SD_MULTIPLIER * sd(errors))) |>
    arrange(errors)
  maze_good_workerids <- maze_errors |> filter(errors <= cutoff) |> pull(workerid)
  message(
    "Removed ",
    format(100 - 100 * length(maze_good_workerids) / n_distinct(maze_errors$workerid), digits = 2),
    "% of participants who had number of errors larger than cutoff value."
  )
  maze <- maze |>
    filter(workerid %in% maze_good_workerids) |>
    mutate(
      .by = workerid,
      errors_so_far = cumsum(!correct),
      prev_incorrect = coalesce(lag(!correct, 1L), FALSE)
    ) |>
    filter(correct)

  maze_mean_rts <- maze |>
    filter(word_number < pron_pos_s1) |>
    group_by(workerid) |>
    summarize(gmean_rt = gmean(rt))
  maze <- maze |>
    mutate(
      nchar = nchar(gsub("^[[:punct:]]+|[[:punct:]]+$", "", trimws(word))),
      comma = grepl(",", word),
      period = grepl("[.]", word)
    ) |>
    inner_join(maze_mean_rts, by = "workerid")
  m2 <- lme4::lmer(
    log(rt) ~ 1 + (
      scale(log(gmean_rt)) + scale(word_number) + scale(nchar) +
        prev_incorrect + is_first_in_sent + comma + period
    )^2 + (1 | item),
    maze
  )
  maze$rt.raw <- maze$rt
  maze$rt <- exp(residuals(m2) + lme4::fixef(m2)[1])
  maze <- maze |> arrange(item1, item2, type1, type2, workerid, word_number)

  participants <- demographics_uniq

  list(
    participants = participants,
    expectations = expectations,
    cloze = cloze,
    recall_question = recall_question,
    spr = spr,
    spr_all = spr_all,
    maze = maze
  )
}
