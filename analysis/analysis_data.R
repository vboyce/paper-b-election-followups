# Shared analysis data: loads the processed tables and defines the
# exclusions and session sets. Used by analysis/descriptives.Rmd and
# analysis/models/, so both work from the same definitions.
#
#   source(here::here("analysis", "analysis_data.R"))
#   d <- load_analysis_data()          # default settings below
#   d$sessions, d$cloze, d$reading, d$critical_words, d$recall
#   d$session_sets$main                # session_ids in each set
#   d$expectation_sets$main            # same, for the event sliders
#
# The exclusion steps and session sets are described in descriptives.Rmd
# (sections "Default exclusions" and "Session sets").

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

round_levels <- c("pre", "post")
set_levels <- c("main", "comprehension", "strict_timing", "high_attention", "no_us_exclusion", "task_first",
                "original")

default_analysis_settings <- list(
  # RT window (ms): what counts as "too fast" / "too slow".
  rt_min = 180,
  rt_max = 5000,
  # Drop reading sessions with more than this many critical-trial words under rt_min.
  max_words_too_fast = 2,
  # Drop Maze/mazerace sessions whose proportion of critical-trial words
  # chosen correctly on the first try is below this.
  maze_accuracy_min = 0.8
)

read_study <- function(study, table) {
  map(round_levels, \(r) read_csv(here(study, "processed", paste0(r, "_", table, ".csv.gz")),
                                  show_col_types = FALSE, guess_max = 1e6)) |>
    list_rbind()
}

load_analysis_data <- function(settings = default_analysis_settings) {
  stopifnot(setequal(names(settings), names(default_analysis_settings)),
            settings$rt_min < settings$rt_max,
            settings$max_words_too_fast >= 0,
            between(settings$maze_accuracy_min, 0, 1))

  sessions_core <- read_csv(here("combined", "sessions.csv.gz"), show_col_types = FALSE)
  cloze <- read_csv(here("combined", "cloze.csv.gz"), show_col_types = FALSE) |>
    mutate(study = as.character(study), round = factor(round, levels = round_levels))
  reading <- read_csv(here("combined", "reading.csv.gz"), show_col_types = FALSE, guess_max = 1e6) |>
    mutate(study = as.character(study), round = factor(round, levels = round_levels))
  recall <- read_csv(here("combined", "recall.csv.gz"), show_col_types = FALSE) |>
    mutate(study = as.character(study), round = factor(round, levels = round_levels))

  # Study-specific columns needed for the exclusions.
  extras_2020 <- read_study("2020", "sessions") |>
    transmute(session_id, aware,
              repeat_participant = excl_repeat_ip | excl_repeat_worker | excl_worker_in_pre_round,
              incomplete = FALSE)
  extras_2024 <- read_study("2024", "sessions") |>
    transmute(session_id, aware = NA_character_,
              repeat_participant = excl_duplicate_submission | excl_original_prolific_dedup,
              incomplete = excl_no_survey)
  sessions <- sessions_core |>
    left_join(bind_rows(extras_2020, extras_2024), by = "session_id", relationship = "one-to-one") |>
    mutate(study = as.character(study), round = factor(round, levels = round_levels))
  stopifnot(nrow(sessions) == nrow(sessions_core), !anyNA(sessions$repeat_participant))

  # Words of each session's critical trial (context + critical sentences).
  critical_words <- filter(reading, !is_practice)

  # Per-session quality measures over the critical trial (no practice).
  # Missing RTs (a few in 2020 SPR) count as neither too fast nor too slow.
  session_quality <- critical_words |>
    group_by(session_id) |>
    summarize(words = n(),
              n_too_fast = sum(coalesce(rt < settings$rt_min, FALSE)),
              n_too_slow = sum(coalesce(rt > settings$rt_max, FALSE)),
              # NA for SPR, which has no word choices.
              maze_accuracy_recomputed = mean(maze_correct),
              .groups = "drop")
  # The prep's maze_accuracy column is the same critical-trial measure.
  accuracy_check <- inner_join(select(sessions, session_id, maze_accuracy), session_quality, by = "session_id")
  stopifnot(isTRUE(all.equal(accuracy_check$maze_accuracy, accuracy_check$maze_accuracy_recomputed)))
  session_quality <- select(session_quality, -maze_accuracy_recomputed)
  has_critical_trial <- unique(critical_words$session_id)
  # For the strict_timing set: any critical-trial word outside the window
  # (missing RTs count as outside).
  outside_window_sessions <- critical_words |>
    filter(!coalesce(rt >= settings$rt_min & rt <= settings$rt_max, FALSE)) |>
    distinct(session_id)

  sessions <- sessions |>
    left_join(session_quality, by = "session_id", relationship = "one-to-one") |>
    mutate(
      is_reading = task != "cloze",
      is_maze = task %in% c("maze", "mazerace"),
      step_1_incomplete = incomplete,
      step_2_repeat = repeat_participant,
      step_3_not_native = !coalesce(native_english, FALSE),
      step_4_not_us = !coalesce(us_citizen, FALSE) | !coalesce(us_resident, FALSE),
      step_5_no_critical_trial = is_reading & !session_id %in% has_critical_trial,
      step_6_too_fast = is_reading & coalesce(n_too_fast > settings$max_words_too_fast, TRUE),
      step_7_maze_accuracy = is_maze & !coalesce(maze_accuracy >= settings$maze_accuracy_min, FALSE),
      step_8_cloze_nonsense = task == "cloze" & session_id %in% filter(cloze, cloze_nonsense)$session_id
    )
  # Every cloze session has exactly one completion, so step 8 can't miss one.
  stopifnot(setequal(filter(sessions, task == "cloze")$session_id, cloze$session_id),
            !anyDuplicated(cloze$session_id))
  # Every Maze/mazerace session with words logged has an accuracy.
  stopifnot(!anyNA(filter(sessions, is_maze, !is.na(words))$maze_accuracy))
  step_cols <- names(sessions)[str_starts(names(sessions), "step_")]
  participant_steps <- step_cols[1:4]
  stopifnot(identical(participant_steps, c("step_1_incomplete", "step_2_repeat", "step_3_not_native",
                                           "step_4_not_us")),
            !anyNA(select(sessions, all_of(step_cols))))

  sessions <- sessions |>
    mutate(excl_participant = if_any(all_of(participant_steps)),
           excl_participant_without_us = if_any(all_of(setdiff(participant_steps, "step_4_not_us"))),
           excl_main = if_any(all_of(step_cols)),
           excl_main_without_us = if_any(all_of(setdiff(step_cols, "step_4_not_us"))),
           sliders_all_zero = is.na(expect_prob_dem),
           comprehension_correct = comprehension_n > 0 & comprehension_n_correct == comprehension_n,
           any_word_outside_window = is_reading & session_id %in% outside_window_sessions$session_id)

  session_sets <- list(
    main = filter(sessions, !excl_main),
    comprehension = filter(sessions, !excl_main, !is_reading | comprehension_correct),
    strict_timing = filter(sessions, !excl_main, !any_word_outside_window),
    high_attention = filter(sessions, !excl_main, !is_reading | comprehension_correct, !any_word_outside_window,
                            !sliders_all_zero),
    no_us_exclusion = filter(sessions, !excl_main_without_us),
    task_first = filter(sessions, !excl_main, task_order == "task_first"),
    original = filter(sessions, !excl_task_original)
  ) |>
    map(\(df) df$session_id)
  stopifnot(identical(names(session_sets), set_levels))

  # The sliders use the same session sets as the task data (a session that
  # fails its task's quality check is dropped from both), minus sessions with
  # all sliders at 0. The original set uses each study's original slider rule.
  expectation_sets <- session_sets |>
    map(\(ids) filter(sessions, session_id %in% ids, !sliders_all_zero)$session_id)
  expectation_sets$original <- filter(sessions, !excl_expectations_original, !sliders_all_zero)$session_id
  stopifnot(identical(names(expectation_sets), set_levels))

  list(settings = settings, sessions = sessions, cloze = cloze, reading = reading,
       critical_words = critical_words, recall = recall, step_cols = step_cols,
       participant_steps = participant_steps, session_sets = session_sets,
       expectation_sets = expectation_sets)
}
