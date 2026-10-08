# Builds the item list for the cloze review app (app.py in this folder).
#
#   Rscript shared/cloze_review/prepare_cloze_review.R      (from the repo root)
#
# Output: shared/cloze_review/review_items.csv, one row per unique
# completion (study x item x response; identical completions from different
# sessions get the same codes, and the hand-judgment files are keyed the
# same way). Columns:
#   study, cloze_item, prompt, response, n_sessions
#   n_not_repeat   how many of those sessions are not repeat participants
#   n_pass_screens how many of those sessions pass the participant-level
#                  screens (complete, not a repeat participant, native
#                  English, US citizen and resident)
#   current codes: cloze_code, coref_*, coref_other_*, first_coref_pronoun,
#                  cloze_nonsense, cloze_nonsense_reason
#   spans          JSON list of the references the coding rules matched:
#                  start (0-based) and end (exclusive) character offsets,
#                  kind (a cloze_code level: she, target_office_np, ...),
#                  text (the matched text)
#   blind_order    1..n for the random blind-recoding sample, NA otherwise
#   priority       TRUE if the completion goes into review mode: its codes
#                  rest on a hand judgment, or it is all caps, a single word,
#                  or long (above the study's 95th percentile in words;
#                  added 2026-10-08 after the blind coding). Bare numbers are
#                  left out: they are always nonsense. So are completions
#                  typed only by repeat participants (already excluded).
#   priority_reasons  which of these ("; "-separated)
#
# Highlights use the same regexes as the coding (cloze_reference_patterns()
# in ../common_schema.R), so they show exactly what the rules saw.

library(tidyverse)
library(here)
library(jsonlite)
source(here("shared", "common_schema.R"))
source(here("analysis", "analysis_data.R"))

blind_sample_size <- 150
blind_sample_seed <- 20261008

cloze <- read_csv(here("combined", "cloze.csv.gz"),
                  col_types = cols(study = col_character(), cloze_item = col_character(), .default = col_guess()))
code_columns <- c("cloze_code", "coref_she", "coref_he", "coref_they", "coref_hedge",
                  "coref_other_she", "coref_other_he", "coref_other_they", "coref_other_hedge",
                  "first_coref_pronoun", "cloze_nonsense", "cloze_nonsense_reason")
key_columns <- c("study", "cloze_item", "response")

items <- cloze |>
  mutate(response = coalesce(response, "")) |>
  summarize(n_sessions = n(), .by = c(all_of(key_columns), prompt, all_of(code_columns)))
# Same completion, same codes: anything else would mean the coding depends on
# more than study, item and text.
if (anyDuplicated(select(items, all_of(key_columns)))) {
  stop("Identical completions with different codes or prompts")
}
stopifnot(sum(items$n_sessions) == nrow(cloze))

analysis_data <- load_analysis_data(default_analysis_settings)
not_repeat_sessions <- analysis_data$sessions |>
  filter(!step_2_repeat) |>
  pull(session_id)
passing_sessions <- analysis_data$sessions |>
  filter(!if_any(all_of(analysis_data$participant_steps))) |>
  pull(session_id)
pass_counts <- cloze |>
  mutate(response = coalesce(response, "")) |>
  summarize(n_pass_screens = sum(session_id %in% passing_sessions),
            n_not_repeat = sum(session_id %in% not_repeat_sessions), .by = all_of(key_columns))
items <- inner_join(items, pass_counts, by = key_columns, relationship = "one-to-one")

# Highlight spans ---------------------------------------------------------------

pronoun_kinds <- c("hedged", "she", "he", "they")

# All matches of every reference pattern in one completion, as a tibble.
# She/he inside a hedge ("his or her") are dropped: the hedge is one reference.
find_spans <- function(text, patterns) {
  spans <- imap(patterns, \(pattern, kind) {
    located <- str_locate_all(text, pattern)[[1]]
    tibble(start = located[, "start"] - 1L, end = located[, "end"], kind = kind)
  }) |>
    list_rbind()
  hedges <- filter(spans, kind == "hedged")
  inside_hedge <- map2_lgl(spans$start, spans$end, \(s, e) any(hedges$start <= s & e <= hedges$end)) &
    spans$kind != "hedged"
  spans <- spans[!inside_hedge, ] |>
    arrange(start) |>
    mutate(text = str_sub(text, start + 1L, end))
  overlapping <- head(spans$end, -1) > tail(spans$start, -1)
  if (any(overlapping)) stop("Overlapping reference matches in: ", text)
  spans
}

patterns_by_study <- map(cloze_coding_settings, \(s) {
  cloze_reference_patterns(s$female_names, s$male_names, s$other_names, s$target_office)
})
items <- items |>
  mutate(span_table = map2(response, study, \(text, s) find_spans(text, patterns_by_study[[s]])))

# The has_* columns are the same matches, so each kind of span must be found
# exactly where the coding found that kind of reference.
has_columns <- c(she = "has_she", he = "has_he", hedged = "has_hedge",
                 female_candidate_name = "has_female_candidate_name",
                 male_candidate_name = "has_male_candidate_name",
                 other_candidate_name = "has_other_candidate_name",
                 target_office_np = "has_target_office_np", other_office_np = "has_other_office_np",
                 generic_np = "has_generic_np")
has_check <- cloze |>
  mutate(response = coalesce(response, "")) |>
  distinct(across(all_of(c(key_columns, has_columns)))) |>
  inner_join(select(items, all_of(key_columns), span_table), by = key_columns, relationship = "one-to-one")
for (kind in names(has_columns)) {
  # A hedge also contains a she/he match, which the coding counts in has_she/has_he.
  found <- map_lgl(has_check$span_table, \(sp) kind %in% sp$kind)
  in_hedge_only <- if (kind %in% c("she", "he")) {
    map2_lgl(has_check$response, found, \(text, f) !f & str_detect(text, cloze_pronoun_patterns[[kind]]))
  } else {
    FALSE
  }
  stopifnot(all((found | in_hedge_only) == has_check[[has_columns[[kind]]]]))
}

items <- items |>
  mutate(spans = map_chr(span_table, \(sp) as.character(toJSON(sp, dataframe = "rows")))) |>
  select(-span_table)

# Priority: completions whose codes rest on a hand judgment ----------------------

key_of <- function(df) paste(df$study, df$cloze_item, df$response, sep = "\r")
item_keys <- key_of(items)

coref_judgments <- read_cloze_coreference_judgments(here("shared", "cloze_coreference_judgments.csv"))
pasted_text <- read_cloze_pasted_text(here("shared", "cloze_pasted_text.csv"))
single_words <- read_cloze_single_word_judgments(here("shared", "cloze_single_word_judgments.csv"))
# Judgments for completions that aren't in the data would mean the files are stale.
stopifnot(all(key_of(coref_judgments) %in% item_keys), all(key_of(pasted_text) %in% item_keys))

# Same normalization as flag_cloze_nonsense() uses for single-word judgments.
normalized <- str_squish(str_remove_all(tolower(str_squish(items$response)), "[[:punct:]]"))
single_word_keys <- paste(single_words$study, single_words$cloze_item, single_words$word, sep = "\r")
is_judged_single_word <- str_count(normalized, "\\S+") == 1 &
  paste(items$study, items$cloze_item, normalized, sep = "\r") %in% single_word_keys
stopifnot(sum(is_judged_single_word) >= nrow(single_words))

n_words <- str_count(str_squish(items$response), "\\S+")
long_cutoff <- tapply(n_words, items$study, \(n) quantile(n, .95))
reasons <- cbind(
  "coreference judged by hand" = item_keys %in% key_of(coref_judgments),
  "pasted-text judgment" = item_keys %in% key_of(pasted_text),
  "single-word judgment" = is_judged_single_word,
  "all caps" = str_count(items$response, "[A-Za-z]") >= 2 & !str_detect(items$response, "[a-z]"),
  "single word" = n_words == 1,
  "long" = n_words > long_cutoff[items$study]
)
# Bare numbers are always nonsense (by rule), so they need no review.
is_number_only <- str_detect(items$response, "^[0-9[:space:][:punct:]]+$")
reasons[is_number_only, ] <- FALSE
# Completions only repeat participants typed are excluded already, so they
# need no review either.
reasons[items$n_not_repeat == 0, ] <- FALSE
items$priority_reasons <- apply(reasons, 1, \(row) if (any(row)) paste(colnames(reasons)[row], collapse = "; ") else NA)
items$priority <- !is.na(items$priority_reasons)

# Blind sample: uniform over non-blank unique completions ---------------------------

set.seed(blind_sample_seed)
candidates <- which(str_trim(items$response) != "")
stopifnot(length(candidates) >= blind_sample_size)
sampled <- sample(candidates, blind_sample_size)
items$blind_order <- NA_integer_
items$blind_order[sampled] <- seq_len(blind_sample_size)

out <- items |>
  arrange(study, as.integer(cloze_item), response) |>
  select(all_of(key_columns), prompt, n_sessions, n_not_repeat, n_pass_screens, all_of(code_columns), spans, blind_order, priority,
         priority_reasons)
write_csv(out, here("shared", "cloze_review", "review_items.csv"), na = "")

message(nrow(out), " unique completions; ", sum(out$priority), " priority; ",
        sum(!is.na(out$blind_order)), " in the blind sample (",
        sum(out$priority & !is.na(out$blind_order)), " of them also priority)")
print(count(out, priority_reasons))
