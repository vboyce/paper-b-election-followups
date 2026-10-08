# Model-ready data: one data frame per outcome, built from the shared
# exclusions in analysis/analysis_data.R. The variables are listed in
# analysis/models/model_specs.R.
#
#   source(here::here("analysis", "models", "model_data.R"))
#   md <- build_model_data()                  # main session set
#   md <- build_model_data(set = "high_attention")
#
# Rows are measured values only: RT filters (window, Maze first-try
# accuracy) are columns (`rt_in_window`, `maze_correct`) for the model script
# to apply, not applied here.

# The tidyverse packages this code uses, loaded individually: the full
# tidyverse meta-package can't be installed on Engaging (no fontconfig /
# freetype headers for its font dependencies).
library(dplyr)
library(tidyr)
library(readr)
library(purrr)
library(stringr)
library(tibble)
library(here)
source(here("analysis", "analysis_data.R"))

build_model_data <- function(set = "main", settings = default_analysis_settings) {
  d <- load_analysis_data(settings)
  stopifnot(set %in% set_levels)
  kept <- d$session_sets[[set]]
  kept_expectations <- d$expectation_sets[[set]]

  party_levels <- c("Democrat", "Republican", "Independent", "other / none / didn't say")
  session_predictors <- d$sessions |>
    transmute(
      session_id,
      study = factor(study, levels = c("2020", "2024")),
      study_c = if_else(study == "2020", -0.5, 0.5),
      round = factor(round, levels = round_levels),
      round_c = if_else(round == "pre", -0.5, 0.5),
      task,
      task_order = factor(task_order, levels = c("task_first", "event_first")),
      task_first = task_order == "task_first",
      expectation_target = factor(expectation_target, levels = c("president", "vice_president")),
      party = factor(if_else(political_affiliation %in% party_levels[1:3], political_affiliation, party_levels[4]),
                     levels = party_levels),
      preference = factor(case_when(
        election_pref %in% c("Joe Biden", "Kamala Harris") ~ "democratic_candidate",
        election_pref %in% c("Donald Trump", "Mike Pence") ~ "republican_candidate",
        .default = "neither_or_no_answer"
      ), levels = c("democratic_candidate", "republican_candidate", "neither_or_no_answer")),
      expect_prob_dem
    )
  stopifnot(!anyNA(select(session_predictors, -expectation_target, -expect_prob_dem)))

  # Pronoun factors use "he" as the reference level.
  pronoun_factor <- function(x) factor(x, levels = c("he", "she", "they"))
  pair_levels <- c("he–he", "she–she", "they–they", "he–she", "she–he")

  # Reading: one row per session x word, relative to the given pronoun.
  # Maze keeps the pronoun only; SPR the pronoun and the next three words
  # (pooled into one region by spr_region()).
  reading_rows <- function(sentence, pronoun_flag, item_column, task_name) {
    words <- d$critical_words |> filter(session_id %in% kept, task == task_name)
    pronoun_position <- words |>
      filter(sentence_index == sentence, .data[[pronoun_flag]]) |>
      select(session_id, pronoun_word = word_index_in_sentence)
    positions <- if (task_name == "maze") 0 else 0:3
    words |>
      filter(sentence_index == sentence) |>
      inner_join(pronoun_position, by = "session_id", relationship = "many-to-one") |>
      mutate(word_position = word_index_in_sentence - pronoun_word) |>
      filter(word_position %in% positions) |>
      transmute(
        session_id,
        item = factor(paste(study, .data[[item_column]], sep = "-")),
        pronoun_1 = pronoun_factor(pro1_type),
        pronoun_2 = pronoun_factor(pro2_type),
        pronoun_pair = factor(paste0(pro1_type, "–", pro2_type), levels = pair_levels),
        pair_match = factor(if_else(pro1_type == pro2_type, "match", "mismatch"), levels = c("match", "mismatch")),
        word_position, word, word_length = nchar(word),
        rt, log_rt = log(rt),
        rt_in_window = coalesce(rt >= settings$rt_min & rt <= settings$rt_max, FALSE),
        maze_correct
      ) |>
      inner_join(session_predictors, by = "session_id", relationship = "many-to-one")
  }

  # SPR region: one row per session, RT = arithmetic mean (ms) of the pronoun
  # and the next three words. In the window only if all four words are.
  # (Every SPR sentence has at least five words after each pronoun, so the
  # region never reaches the sentence-final word.)
  spr_region <- function(word_rows) {
    stopifnot(all(count(word_rows, session_id)$n == 4),
              setequal(word_rows$word_position, 0:3))
    word_rows |>
      summarize(rt = mean(rt), rt_in_window = all(rt_in_window),
                .by = c(session_id, item, pronoun_1, pronoun_2, pronoun_pair, pair_match)) |>
      mutate(log_rt = log(rt)) |>
      inner_join(session_predictors, by = "session_id", relationship = "one-to-one")
  }

  # Cloze: one row per session. Outcome columns are described in model_specs.R.
  cloze <- d$cloze |>
    filter(session_id %in% kept) |>
    transmute(
      session_id,
      item = factor(paste(study, cloze_item, sep = "-")),
      first_target_pronoun = factor(first_coref_pronoun, levels = c("he", "she", "they", "hedged", "none")),
      has_target_pronoun = first_coref_pronoun != "none",
      first_is_she = case_when(first_coref_pronoun == "she" ~ 1L, first_coref_pronoun == "he" ~ 0L),
      first_is_they = case_when(first_coref_pronoun == "they" ~ 1L, first_coref_pronoun %in% c("she", "he") ~ 0L),
      coref_she, coref_he, coref_they, coref_hedge,
      coref_other_she, coref_other_he, coref_other_they, coref_other_hedge,
      has_female_candidate_name, has_male_candidate_name, has_other_candidate_name,
      has_target_office_np, has_other_office_np, has_generic_np,
      cloze_code
    ) |>
    inner_join(session_predictors, by = "session_id", relationship = "one-to-one")

  expectations <- session_predictors |>
    filter(session_id %in% kept_expectations) |>
    inner_join(read_csv(here("combined", "expectations.csv.gz"), show_col_types = FALSE) |>
                 select(session_id, candidate_party, slider_value) |>
                 pivot_wider(names_from = candidate_party, values_from = slider_value, names_prefix = "slider_"),
               by = "session_id", relationship = "one-to-one") |>
    mutate(prob_dem_two_party = slider_dem / (slider_dem + slider_rep))
  stopifnot(!anyNA(expectations$expect_prob_dem))

  recall_levels <- c("female candidate", "male candidate", "Writer is unsure", "I don't remember")
  recall <- d$recall |>
    filter(session_id %in% kept) |>
    inner_join(distinct(filter(d$critical_words, task %in% c("maze", "spr")), session_id, sen1_item,
                        pro1_type, pro2_type),
               by = "session_id", relationship = "one-to-one") |>
    transmute(
      session_id,
      # The reading trial's sentence-1 item.
      item = factor(paste(study, sen1_item, sep = "-")),
      pronoun_1 = pronoun_factor(pro1_type),
      pronoun_2 = pronoun_factor(pro2_type),
      pronoun_pair = factor(paste0(pro1_type, "–", pro2_type), levels = pair_levels),
      recall_response,
      recall = factor(case_when(
        recall_response == "Kamala Harris" ~ "female candidate",
        recall_response %in% c("Mike Pence", "Donald Trump") ~ "male candidate",
        .default = recall_response
      ), levels = recall_levels)
    ) |>
    inner_join(session_predictors, by = "session_id", relationship = "one-to-one")
  stopifnot(!anyNA(recall$recall))

  list(
    maze_pronoun_1 = reading_rows(1, "is_pro1", "sen1_item", "maze"),
    maze_pronoun_2 = reading_rows(2, "is_pro2", "sen2_item", "maze"),
    spr_pronoun_1 = spr_region(reading_rows(1, "is_pro1", "sen1_item", "spr")),
    spr_pronoun_2 = spr_region(reading_rows(2, "is_pro2", "sen2_item", "spr")),
    cloze = cloze,
    expectations = expectations,
    recall = recall
  )
}
