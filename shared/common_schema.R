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
    has_other_candidate_name = "logical", has_target_office_np = "logical", has_other_office_np = "logical",
    has_generic_np = "logical",
    coref_she = "logical", coref_he = "logical", coref_they = "logical", coref_hedge = "logical",
    coref_other_she = "logical", coref_other_he = "logical", coref_other_they = "logical",
    coref_other_hedge = "logical", first_coref_pronoun = "character",
    cloze_nonsense = "logical", cloze_nonsense_reason = "character"
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
    "target_office_np", "other_office_np", "generic_np", "other"
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

# Pronoun patterns shared by the cloze coders below.
cloze_pronoun_patterns <- c(
  hedged = paste0("(?i)\\b(he or she|she or he|he/she|she/he|s/he|him or her|her or him|him/her|her/him|",
                  "his or her|her or his|his/her|her/his)\\b"),
  she = "(?i)\\b(she|her|hers|herself)\\b",
  he = "(?i)\\b(he|him|his|himself)\\b",
  they = "(?i)\\b(they|them|their|theirs|themselves|themself)\\b"
)

# Shared cloze coding, applied identically to both studies.
#
# `cloze_code` is the FIRST referring expression in the completion, i.e.
# what the participant produced at the gap: a hedge ("he or she", "s/he"),
# a pronoun, a candidate's name, or a noun phrase for an office.
# The `has_*` columns record every kind of reference that appears anywhere
# in the completion, so other codings (e.g. "any female pronoun") can be
# derived in analysis.
#
# Office noun phrases are split by office. `target_office` is the office the
# item is about (2020: "vice_president"; 2024: "president").
#   target_office_np  "the vice president", "the next VP" (2020) /
#                     "the president", "the new president" (2024)
#   other_office_np   the other office: "the president" (2020) /
#                     "the vice president" (2024)
#   generic_np        "the winner", "the candidate": neither office
# An office noun counts when it follows a determiner ("the", "next", "our",
# "US"...) or starts the completion ("vice president" after "...protect the
# president and"), so a bare predicate ("will become president") does not.
#
# `female_names` / `male_names` are regexes for the candidates in the
# referent's office (2020: Harris / Pence for vice president; 2024: Harris /
# Trump for president). `other_names` matches candidates for the other
# office (2020: Biden, Trump), whose mention usually means the completion is
# about someone else; NA if there are none. `them_not_referential` marks prompts where a completion
# starting with "them" refers back to something in the prompt rather than to
# the office-holder (2024 item 9, "...many challenges, and one of").
# Each study's candidates and target office, used by both studies' prep and
# by the cloze review app (shared/cloze_review/).
cloze_coding_settings <- list(
  "2020" = list(female_names = "harris|kamala", male_names = "pence", other_names = "biden|trump",
                target_office = "vice_president"),
  "2024" = list(female_names = "harris|kamala", male_names = "trump|donald", other_names = NA,
                target_office = "president")
)

# The regex for each kind of reference, named by cloze_code level. Pronoun
# patterns are cloze_pronoun_patterns; the rest depend on the study.
cloze_reference_patterns <- function(female_names, male_names, other_names, target_office) {
  stopifnot(target_office %in% c("vice_president", "president"))
  # An office noun after a determiner, or at the very start of the completion.
  office_np_re <- function(nouns) {
    paste0("(?i)(\\b(the|next|new|newly elected|incoming|us|u\\.s\\.|our) |^\\s*)(", nouns, ")\\b")
  }
  vice_president_np_re <- office_np_re("vice president|vice-president|vp")
  # "the vice president" can't match here: "president" must follow the
  # determiner (or the start) directly.
  president_np_re <- office_np_re("president|potus")
  c(
    cloze_pronoun_patterns,
    female_candidate_name = paste0("(?i)\\b(", female_names, ")\\b"),
    male_candidate_name = paste0("(?i)\\b(", male_names, ")\\b"),
    # A pattern that can never match when there are no other candidates.
    other_candidate_name = if (is.na(other_names)) "(?!)" else paste0("(?i)\\b(", other_names, ")\\b"),
    target_office_np = if (target_office == "vice_president") vice_president_np_re else president_np_re,
    other_office_np = if (target_office == "vice_president") president_np_re else vice_president_np_re,
    generic_np = "(?i)\\b(the|next|new|newly elected|incoming|us|u\\.s\\.|our) (candidate|winner)\\b"
  )
}

code_cloze_response <- function(response, female_names, male_names, other_names, them_not_referential,
                                target_office) {
  stopifnot(length(them_not_referential) %in% c(1, length(response)), !anyNA(them_not_referential),
            target_office %in% c("vice_president", "president"))
  them_not_referential <- rep_len(them_not_referential, length(response))
  patterns <- cloze_reference_patterns(female_names, male_names, other_names, target_office)
  hedge_re <- patterns[["hedged"]]
  she_re <- patterns[["she"]]
  he_re <- patterns[["he"]]
  they_re <- patterns[["they"]]
  female_re <- patterns[["female_candidate_name"]]
  male_re <- patterns[["male_candidate_name"]]
  other_re <- patterns[["other_candidate_name"]]
  target_office_re <- patterns[["target_office_np"]]
  other_office_re <- patterns[["other_office_np"]]
  generic_re <- patterns[["generic_np"]]

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
    target_office_np = first_position(text, target_office_re),
    other_office_np = first_position(text, other_office_re),
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
    has_target_office_np = str_detect(text, target_office_re),
    has_other_office_np = str_detect(text, other_office_re),
    has_generic_np = str_detect(text, generic_re)
  )
}

# Shared flag for cloze completions that are obvious nonsense, applied
# identically to both studies. `cloze_nonsense_reason` is one of:
#   blank             nothing typed
#   filler_or_number  only "yes", "no", "ok", "idk" or similar, or only digits
#   pasted_id         the participant's (redacted) Prolific ID
#   copied_context    a word-for-word piece of the prompt's first (context)
#                     sentence, e.g. "next presidential"; a cut-off last
#                     word ("next presidentia") still counts
#   pasted_text       pasted text (news articles, encyclopedia text, ads,
#                     essays repeating the prompt), per the hand judgments in
#                     shared/cloze_pasted_text.csv
#   single_word       one word that is not a sensible continuation of this
#                     item, per the hand judgments in
#                     shared/cloze_single_word_judgments.csv
# Everything else is NA / not flagged. Single words judged sensible (e.g.
# "safety" after "...well-equipped to guarantee") are kept. Multi-word
# completions are only flagged as copied context or pasted text.
#
# Stops if a single-word completion has no judgment, so new data can't
# slip through unjudged.
# Read the judgments with read_cloze_single_word_judgments().
read_cloze_single_word_judgments <- function(path = "../../shared/cloze_single_word_judgments.csv") {
  judgments <- read_csv(path, col_types = cols(study = col_character(), cloze_item = col_character(),
                                               word = col_character(), n_responses = col_integer(),
                                               sensible = col_logical(), reason_if_not = col_character()))
  stopifnot(!anyNA(judgments$sensible), !anyDuplicated(select(judgments, study, cloze_item, word)),
            all(!is.na(judgments$reason_if_not) == !judgments$sensible))
  judgments
}

read_cloze_pasted_text <- function(path = "../../shared/cloze_pasted_text.csv") {
  pasted <- read_csv(path, col_types = cols(study = col_character(), cloze_item = col_character(),
                                            response = col_character(), pasted = col_logical(),
                                            note = col_character()))
  stopifnot(!anyNA(pasted$pasted), !anyDuplicated(select(pasted, study, cloze_item, response)))
  pasted
}

flag_cloze_nonsense <- function(response, prompt, study, cloze_item, judgments, pasted_text) {
  stopifnot(length(response) == length(prompt), length(response) == length(cloze_item),
            length(study) %in% c(1, length(response)))
  study <- rep_len(as.character(study), length(response))
  text <- str_squish(coalesce(response, ""))
  # Lower case, punctuation removed: the form the judgments are keyed on.
  normalized <- str_squish(str_remove_all(tolower(text), "[[:punct:]]"))
  n_words <- if_else(text == "", 0L, str_count(text, "\\S+"))

  context_sentence <- str_extract(prompt, "^.*?\\.(?=\\s|$)")
  stopifnot(!anyNA(context_sentence))
  context_words <- str_split(str_squish(str_remove_all(tolower(context_sentence), "[[:punct:]]")), " ")
  response_words <- str_split(normalized, " ")
  copies_context <- map2_lgl(response_words, context_words, is_copied_word_sequence)

  is_filler_or_number <- str_detect(normalized, "^(yes|no|yeah|yep|nope|ok|okay|idk|na|[0-9 ]+)$")
  is_pasted_id <- str_detect(text, "REDACTED_PROLIFIC_ID")
  is_pasted_text <- tibble(study, cloze_item = as.character(cloze_item), response) |>
    left_join(select(pasted_text, study, cloze_item, response, pasted),
              by = c("study", "cloze_item", "response"), relationship = "many-to-one") |>
    pull(pasted) |>
    coalesce(FALSE)

  single_word_keys <- tibble(study, cloze_item = as.character(cloze_item), word = normalized) |>
    mutate(row = row_number()) |>
    filter(n_words == 1, !is_filler_or_number, !is_pasted_id)
  judged <- single_word_keys |>
    left_join(mutate(judgments, study = as.character(study), cloze_item = as.character(cloze_item)),
              by = c("study", "cloze_item", "word"), relationship = "many-to-one")
  if (anyNA(judged$sensible)) {
    missing <- distinct(filter(judged, is.na(sensible)), study, cloze_item, word)
    stop("Single-word cloze completions without a judgment in cloze_single_word_judgments.csv:\n",
         paste(capture.output(print(missing, n = Inf)), collapse = "\n"))
  }
  single_word_nonsense <- rep(FALSE, length(response))
  single_word_nonsense[judged$row] <- !judged$sensible

  reason <- case_when(
    text == "" ~ "blank",
    is_filler_or_number ~ "filler_or_number",
    is_pasted_id ~ "pasted_id",
    copies_context ~ "copied_context",
    is_pasted_text ~ "pasted_text",
    single_word_nonsense ~ "single_word"
  )
  tibble(cloze_nonsense = !is.na(reason), cloze_nonsense_reason = reason)
}

# TRUE if `words` (at least two) appear as a contiguous run in
# `context_words`; the last word may be cut off (a prefix of the context
# word).
is_copied_word_sequence <- function(words, context_words) {
  n <- length(words)
  if (n < 2 || n > length(context_words)) return(FALSE)
  for (start in seq_len(length(context_words) - n + 1)) {
    window <- context_words[start:(start + n - 1)]
    if (all(window[-n] == words[-n]) && startsWith(window[n], words[n])) return(TRUE)
  }
  FALSE
}

# Shared coreference coding: does a pronoun in the completion refer to the
# office-holder the item is about (2020: the vice president; 2024: the
# president)? One logical column per pronoun kind: coref_she, coref_he,
# coref_they, coref_hedge ("he or she", "his/her"...). The has_* columns
# from code_cloze_response() say whether a pronoun appears at all; these say
# whether it refers to the office-holder. coref_other_* say whether it
# refers to the holder of the OTHER office (2020: the president, e.g. "if
# the president cannot perform his duties"; 2024: the vice president).
#
# Coded by rule when the completion is simple: exactly one pronoun kind,
# no candidate name of the other office, not both candidates' names, no
# mention of the other office, and (for "they") no other group of people
# it could refer to. Then that pronoun refers to the office-holder, and no
# pronoun refers to the other office-holder (it isn't mentioned). (A
# hand check of 65 rule-coded completions found one error.) Every other
# completion with a pronoun is coded by hand in
# shared/cloze_coreference_judgments.csv, keyed by study, item and the
# exact response; the prep stops if one is missing.
read_cloze_coreference_judgments <- function(path = "../../shared/cloze_coreference_judgments.csv") {
  judgments <- read_csv(path, col_types = cols(study = col_character(), cloze_item = col_character(),
                                               response = col_character(), .default = col_logical(),
                                               note = col_character()))
  stopifnot(!anyNA(select(judgments, starts_with("coref_"))),
            !anyDuplicated(select(judgments, study, cloze_item, response)))
  judgments
}

code_cloze_coreference <- function(response, study, cloze_item, reference_columns, target_office, judgments,
                                   them_not_referential) {
  stopifnot(target_office %in% c("vice_president", "president"), nrow(reference_columns) == length(response),
            length(them_not_referential) %in% c(1, length(response)), !anyNA(them_not_referential))
  them_not_referential <- rep_len(them_not_referential, length(response))
  study <- rep_len(as.character(study), length(response))
  text <- coalesce(response, "")
  refs <- reference_columns
  other_office_re <- if (target_office == "vice_president") {
    "(?i)(?<!vice[- ])\\bpresident\\b"
  } else {
    "(?i)\\bvice[- ]president\\b"
  }
  # Groups a "they" could refer to instead of the office-holder.
  other_people_re <- paste0("(?i)\\b(people|americans|citizens|voters|congress|senate|house|leaders|staff|",
                            "members|officials|republicans|democrats|party|parties|wife|husband|spouse|",
                            "children|kids|first lady|everyone|nobody|someone|anyone|others|world|country|nation)\\b")
  n_kinds <- refs$has_she + refs$has_he + refs$has_they + refs$has_hedge
  simple <- n_kinds == 1 &
    !refs$has_other_candidate_name &
    !(refs$has_female_candidate_name & refs$has_male_candidate_name) &
    !str_detect(text, other_office_re) &
    !(refs$has_they & str_detect(text, other_people_re))

  coref_cols <- c("coref_she", "coref_he", "coref_they", "coref_hedge",
                  "coref_other_she", "coref_other_he", "coref_other_they", "coref_other_hedge")
  by_rule <- tibble(coref_she = refs$has_she, coref_he = refs$has_he,
                    coref_they = refs$has_they, coref_hedge = refs$has_hedge,
                    coref_other_she = FALSE, coref_other_he = FALSE,
                    coref_other_they = FALSE, coref_other_hedge = FALSE)
  no_pronoun <- tibble(!!!set_names(as.list(rep(FALSE, length(coref_cols))), coref_cols))

  needs_hand <- n_kinds > 0 & !simple
  hand <- tibble(study, cloze_item = as.character(cloze_item), response) |>
    left_join(judgments, by = c("study", "cloze_item", "response"), relationship = "many-to-one")
  missing <- needs_hand & is.na(hand$coref_she)
  if (any(missing)) {
    stop("Cloze completions needing a hand coreference judgment in cloze_coreference_judgments.csv:\n",
         paste0(study[missing], " item ", cloze_item[missing], ": ", response[missing], collapse = "\n"))
  }

  out <- no_pronoun[rep(1, length(response)), ]
  out[simple & n_kinds > 0, ] <- by_rule[simple & n_kinds > 0, ]
  out[needs_hand, ] <- select(hand, all_of(coref_cols))[needs_hand, ]

  # first_coref_pronoun: which kind of pronoun referring to the target
  # office-holder comes first (she / he / they / hedged; "none" if there is
  # none). Hedges are blanked out before locating she/he, so "his or her"
  # doesn't also count as "his" and "her"; a non-referential leading "them"
  # (2024 item 9) is blanked out too. Blanking keeps character positions.
  blank_out <- function(x, pattern) str_replace_all(x, pattern, \(m) strrep(" ", nchar(m)))
  without_hedges <- blank_out(text, cloze_pronoun_patterns[["hedged"]])
  without_hedges <- if_else(them_not_referential, blank_out(without_hedges, "(?i)^\\s*them\\b"), without_hedges)
  position_if_coref <- function(x, pattern, is_coref) {
    pos <- as.double(str_locate(x, pattern)[, "start"])
    if_else(is_coref & !is.na(pos), pos, Inf)
  }
  positions <- cbind(
    hedged = position_if_coref(text, cloze_pronoun_patterns[["hedged"]], out$coref_hedge),
    she = position_if_coref(without_hedges, cloze_pronoun_patterns[["she"]], out$coref_she),
    he = position_if_coref(without_hedges, cloze_pronoun_patterns[["he"]], out$coref_he),
    they = position_if_coref(without_hedges, cloze_pronoun_patterns[["they"]], out$coref_they)
  )
  any_coref <- out$coref_she | out$coref_he | out$coref_they | out$coref_hedge
  # Every coref_* = TRUE must point at a pronoun actually in the text.
  stopifnot(all(is.finite(positions[, "hedged"]) == out$coref_hedge),
            all(is.finite(positions[, "she"]) == out$coref_she),
            all(is.finite(positions[, "he"]) == out$coref_he),
            all(is.finite(positions[, "they"]) == out$coref_they))
  out$first_coref_pronoun <- if_else(any_coref, colnames(positions)[max.col(-positions, ties.method = "first")],
                                     "none")
  out
}
