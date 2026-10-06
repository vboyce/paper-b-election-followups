# The common data framework shared by the 2020 and 2024 studies.
#
# Each study's prep writes the same set of tables per round (sessions,
# expectations, cloze, reading, comprehension, recall). Every table starts
# with the CORE columns defined here, with identical names, types and value
# sets in both studies; study-specific columns follow. combined/
# combine_studies.R stacks the core columns of both studies.
#
# Processed tables hold measured values and exclusion flags only. Analysis
# decisions (RT windows, residualization, accuracy cutoffs, which exclusion
# columns to apply) belong to the analysis stage, applied identically to
# both studies.
#
# Column meanings are documented in DATA.md at the repo root.

library(tidyverse)

core_columns <- list(
  sessions = c(
    study = "character", round = "character", session_id = "character",
    condition = "character", task = "character", task_order = "character",
    expectation_target = "character",
    age = "integer", gender = "character", education = "character",
    political_affiliation = "character", news_consumption = "character",
    us_citizen = "logical", us_resident = "logical", native_english = "logical",
    election_pref = "character",
    expect_prob_dem = "double", expect_prob_rep = "double", expect_prob_other = "double",
    recall_response = "character",
    comprehension_n = "integer", comprehension_n_correct = "integer",
    maze_accuracy = "double",
    excl_task_original = "logical", excl_task_original_replication = "logical",
    excl_expectations_original = "logical", excl_expectations_original_replication = "logical"
  ),
  expectations = c(
    study = "character", round = "character", session_id = "character",
    expectation_target = "character", candidate_party = "character",
    candidate_name = "character", slider_value = "double", probability = "double"
  ),
  cloze = c(
    study = "character", round = "character", session_id = "character",
    cloze_item = "character", prompt = "character", response = "character",
    cloze_code = "character",
    has_she = "logical", has_he = "logical", has_they = "logical", has_hedge = "logical",
    has_female_candidate_name = "logical", has_male_candidate_name = "logical",
    has_other_candidate_name = "logical", has_generic_np = "logical"
  ),
  reading = c(
    study = "character", round = "character", session_id = "character",
    task = "character", is_practice = "logical",
    sen1_item = "character", sen2_item = "character",
    pro1_type = "character", pro2_type = "character", race_adjective = "character",
    word_index = "integer", sentence_index = "integer", word_index_in_sentence = "integer",
    word = "character", is_pro1 = "logical", is_pro2 = "logical", is_race_adjective = "logical",
    rt = "double",
    maze_correct = "logical", maze_distractor = "character",
    maze_correct_side = "character", maze_time_to_correct = "double"
  ),
  comprehension = c(
    study = "character", round = "character", session_id = "character",
    task = "character", question = "character", answer = "character",
    correct_answer = "character", correct = "logical"
  ),
  recall = c(
    study = "character", round = "character", session_id = "character",
    recall_response = "character"
  )
)

# Allowed values for categorical core columns (NA always allowed).
core_values <- list(
  study = c("2020", "2024"),
  round = c("pre", "post"),
  task = c("cloze", "maze", "spr", "mazerace"),
  task_order = c("task_first", "event_first"),
  expectation_target = c("president", "vice_president"),
  news_consumption = c("daily", "weekly", "monthly", "less than monthly", "never"),
  candidate_party = c("dem", "rep", "other"),
  candidate_name = c("Kamala Harris", "Mike Pence", "Joe Biden", "Donald Trump", "someone else"),
  cloze_code = c(
    "blank", "hedged", "she", "he", "they",
    "female_candidate_name", "male_candidate_name", "other_candidate_name",
    "generic_np", "other"
  ),
  pro1_type = c("she", "he", "they"),
  pro2_type = c("she", "he", "they"),
  race_adjective = c("black", "white", "Black", "White"),
  maze_correct_side = c("left", "right"),
  recall_response = c("Kamala Harris", "Mike Pence", "Donald Trump", "Writer is unsure", "I don't remember")
)

# Puts the core columns first (in their defined order) and stops if any is
# missing, has the wrong type, or holds a value outside its allowed set.
# Returns the table with core columns first, study-specific columns after.
check_core_schema <- function(df, table) {
  spec <- core_columns[[table]]
  if (is.null(spec)) stop("Unknown core table: ", table)
  missing <- setdiff(names(spec), names(df))
  if (length(missing) > 0) stop(table, ": missing core columns: ", toString(missing))
  wrong_type <- names(spec)[map_chr(names(spec), \(col) typeof(df[[col]])) != spec]
  if (length(wrong_type) > 0) {
    stop(table, ": core columns with the wrong type: ",
         toString(paste0(wrong_type, " (", map_chr(wrong_type, \(col) typeof(df[[col]])),
                         ", expected ", spec[wrong_type], ")")))
  }
  for (col in intersect(names(spec), names(core_values))) {
    bad <- setdiff(unique(na.omit(df[[col]])), core_values[[col]])
    if (length(bad) > 0) stop(table, ": unexpected values in ", col, ": ", toString(bad))
  }
  if (anyNA(df$session_id)) stop(table, ": NA session_id")
  if (table == "sessions" && anyDuplicated(df$session_id)) stop("sessions: duplicate session_id")
  select(df, all_of(names(spec)), everything())
}

# Shared cloze coding, applied identically to both studies.
#
# `cloze_code` is the FIRST referring expression in the completion, i.e.
# what the participant produced at the gap: a hedge ("he or she", "s/he"),
# a pronoun, a candidate's name, or a generic noun phrase ("the president").
# The `has_*` columns record every kind of reference that appears anywhere
# in the completion, so other codings (e.g. "any female pronoun") can be
# derived in analysis.
#
# `female_names` / `male_names` are regexes for the candidates in the
# referent's office (2020: Harris / Pence for vice president; 2024: Harris /
# Trump for president). `other_names` matches candidates for the other
# office (2020: Biden, Trump), whose mention usually means the completion is
# about someone else; NA if there are none. `them_not_referential` marks prompts where a completion
# starting with "them" refers back to something in the prompt rather than to
# the office-holder (2024 item 9, "...many challenges, and one of").
code_cloze_response <- function(response, female_names, male_names, other_names, them_not_referential) {
  stopifnot(length(them_not_referential) %in% c(1, length(response)), !anyNA(them_not_referential))
  them_not_referential <- rep_len(them_not_referential, length(response))
  hedge_re <- "(?i)\\b(he or she|she or he|he/she|she/he|s/he|him or her|her or him|his or her|her or his)\\b"
  she_re <- "(?i)\\b(she|her|hers|herself)\\b"
  he_re <- "(?i)\\b(he|him|his|himself)\\b"
  they_re <- "(?i)\\b(they|them|their|theirs|themselves|themself)\\b"
  generic_re <- paste0(
    "(?i)\\b(the|next|new|newly elected|incoming|us|u\\.s\\.|our) ",
    "(vice president|vice-president|president|potus|vp|candidate|winner)\\b"
  )
  female_re <- paste0("(?i)\\b(", female_names, ")\\b")
  male_re <- paste0("(?i)\\b(", male_names, ")\\b")
  # A pattern that can never match when there are no other candidates.
  other_re <- if (is.na(other_names)) "(?!)" else paste0("(?i)\\b(", other_names, ")\\b")

  text <- coalesce(response, "")
  is_blank <- str_trim(text) == ""
  # Drop a leading non-referential "them" before locating the first
  # reference, so "them is ..." after "one of" isn't coded as they.
  for_they <- if_else(them_not_referential, str_remove(text, "(?i)^\\s*them\\b"), text)

  first_position <- function(x, pattern) {
    pos <- as.double(str_locate(x, pattern)[, "start"])
    replace_na(pos, Inf)
  }
  positions <- cbind(
    hedged = first_position(text, hedge_re),
    she = first_position(text, she_re),
    he = first_position(text, he_re),
    # Offset keeps positions comparable after the possible "them" removal.
    they = first_position(for_they, they_re) + (nchar(text) - nchar(for_they)),
    female_candidate_name = first_position(text, female_re),
    male_candidate_name = first_position(text, male_re),
    other_candidate_name = first_position(text, other_re),
    generic_np = first_position(text, generic_re)
  )
  # A hedge starts with a pronoun at the same position; the hedge wins ties
  # because it is listed first.
  earliest <- max.col(-positions, ties.method = "first")
  any_reference <- apply(is.finite(positions), 1, any)
  code <- if_else(any_reference, colnames(positions)[earliest], "other")
  code[is_blank] <- "blank"

  tibble(
    cloze_code = code,
    has_she = str_detect(text, she_re),
    has_he = str_detect(text, he_re),
    has_they = str_detect(for_they, they_re),
    has_hedge = str_detect(text, hedge_re),
    has_female_candidate_name = str_detect(text, female_re),
    has_male_candidate_name = str_detect(text, male_re),
    has_other_candidate_name = str_detect(text, other_re),
    has_generic_np = str_detect(text, generic_re)
  )
}
