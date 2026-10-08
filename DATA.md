# Data: the common framework

Both studies (2020 MVP, 2024 mmepr24) are processed into the same set of
tables, so the same analysis code can run on either study or on both
together. For what the experiments were, see `OVERVIEW.md`; for sourced
methods detail, see `METHODS-SUMMARY.md`.

## Principles

- **Nothing is dropped.** Every session that started a task is kept.
  Exclusion criteria are columns (`excl_*`), so the analysis chooses which
  to apply.
- **Measured values only.** RTs are as recorded. RT windows,
  residualization, accuracy cutoffs and similar choices belong to the
  analysis stage and get applied identically to both studies.
- **One schema.** Every table starts with the *core* columns below, with
  the same names, types and value sets in both studies. Study-specific
  columns follow the core ones in the per-study tables only.
  `shared/common_schema.R` defines the core columns and checks every table
  against them when it is written.

## Layout and regenerating

| Path | Contents |
|---|---|
| `2020/processed/{pre,post}_<table>.csv.gz` | 2020 tables: core + 2020-specific columns |
| `2024/processed/{pre,post}_<table>.csv.gz` | 2024 tables: core + 2024-specific columns |
| `combined/<table>.csv.gz` | Core columns of both studies stacked (`study`, `round` identify the source) |
| `shared/common_schema.R` | Core column definitions, the schema check, the shared cloze coder |

To regenerate everything (each from its own directory):

```
cd 2020/prep && Rscript prep_pre_election.R && Rscript prep_post_election.R && Rscript validate_against_original.R
cd 2024/prep && Rscript prep_pre_election.R && Rscript prep_post_election.R && Rscript validate_against_original.R
cd combined && Rscript combine_studies.R
```

Both validation scripts stop on any mismatch with the original pipelines'
counts (details in each study's README).

## Sessions

| Study | Round | Sessions | Unit |
|---|---|---|---|
| 2020 | pre | 4,648 | One Ibex submission |
| 2020 | post | 4,543 | One Ibex submission |
| 2024 | pre | 1,290 | One run of the experiment that reached a task (a proliferate `workerid` can hold more than one run) |
| 2024 | post | 1,288 | Same as pre |

`session_id` is `<study>-<round>-<number>`: `2020-pre-0001`, or for 2024
`2024-pre-<workerid>-<run>`, e.g. `2024-pre-1736-2`. It is unique across
both studies and is the key in every table.

## Tables and core columns

### `sessions` (one row per session)

| Column | Type | Meaning |
|---|---|---|
| `study`, `round` | chr | `2020`/`2024`; `pre`/`post` |
| `session_id` | chr | See above |
| `condition` | chr | Original condition label, e.g. `event-maze` |
| `task` | chr | Critical task: `cloze`, `maze`, `spr`, `mazerace` (2020 only) |
| `task_order` | chr | `task_first` or `event_first` (event-expectation sliders before the task) |
| `expectation_target` | chr | Office the sliders and preference question asked about: `president`, or `vice_president` (2020 only, random half of sessions) |
| `age` | int | Self-reported |
| `gender`, `education`, `political_affiliation` | chr | Self-reported; same answer options in both studies |
| `news_consumption` | chr | `daily`, `weekly`, `monthly`, `less than monthly`, `never` |
| `us_citizen`, `us_resident`, `native_english` | lgl | Self-reported screening questions |
| `election_pref` | chr | Preferred candidate (or "I don't care" / "I'd rather not say") |
| `expect_prob_dem`, `expect_prob_rep`, `expect_prob_other` | dbl | Event expectation: each slider divided by the sum of the three (NA if all three were 0) |
| `recall_response` | chr | "Who does the writer believe will be [office]?" answer, NA if not asked |
| `comprehension_n`, `comprehension_n_correct` | int | Comprehension questions answered / answered correctly |
| `maze_accuracy` | dbl | Proportion of critical-trial Maze words chosen correctly on the first try (NA for non-Maze sessions) |
| `excl_task_original` | lgl | Excluded from this session's task analysis under the original pipeline's rules (with the corrections listed in the study README) |
| `excl_task_original_replication` | lgl | Same, reproducing the original exactly (no corrections). Equals `excl_task_original` for 2024 |
| `excl_expectations_original`, `excl_expectations_original_replication` | lgl | Same, for the event-expectation data. 2020 applied one rule to everything; 2024 didn't apply the comprehension or Maze-error criteria to expectations |

The individual criteria behind these columns, and other candidate
criteria, are study-specific columns (`excl_*`, `flag_*`), documented in
each study's README.

### `expectations` (one row per candidate per session)

`study`, `round`, `session_id`, `expectation_target`, `candidate_party`
(`dem`/`rep`/`other`), `candidate_name` (`Kamala Harris`, `Mike Pence`,
`Joe Biden`, `Donald Trump`, `someone else`), `slider_value` (0–100 as
recorded), `probability` (slider / sum of the session's three sliders; NA if
all were 0).

Which names go with which party depends on `expectation_target`: 2020
vice-president sessions rated Harris/Pence, 2020 president sessions
Biden/Trump, 2024 sessions Harris/Trump.

### `cloze` (one row per completion)

| Column | Meaning |
|---|---|
| `cloze_item` | Item number within the study (2020: 1–12; 2024: 1–5, 8–12). Items are not shared across studies |
| `prompt` | The text shown before the blank |
| `response` | The completion as typed (Ibex comma encoding decoded) |
| `cloze_code` | Shared coding of the **first** referring expression in the completion (see below) |
| `has_she`, `has_he`, `has_they`, `has_hedge`, `has_female_candidate_name`, `has_male_candidate_name`, `has_other_candidate_name`, `has_target_office_np`, `has_other_office_np`, `has_generic_np` | Whether each kind of reference appears anywhere in the completion (categories as for `cloze_code`, below) |
| `coref_she`, `coref_he`, `coref_they`, `coref_hedge` | Whether a pronoun of that kind in the completion refers to the holder of the **target office**, the office the item is about (2020: the vice president; 2024: the president). `has_*` = the pronoun appears at all (see below) |
| `coref_other_she`, `coref_other_he`, `coref_other_they`, `coref_other_hedge` | Whether a pronoun of that kind refers to the holder of the **other office** (2020: the president, as in "if the president cannot perform *his* duties"; 2024: the vice president) |
| `first_coref_pronoun` | Which kind of pronoun referring to the target office-holder comes first: `she`, `he`, `they`, `hedged`, or `none`. A hedge ("his or her") counts as one hedge, not as "his" and "her" |
| `cloze_nonsense` | The completion is obvious nonsense (see below) |
| `cloze_nonsense_reason` | Why: `blank`, `filler_or_number`, `pasted_id`, `copied_context`, `pasted_text` or `single_word`; NA if not flagged |

`cloze_code` values: `she`, `he`, `they`, `hedged` ("he or she", "s/he",
"his or her"…), `female_candidate_name` (Harris), `male_candidate_name`
(2020: Pence; 2024: Trump), `other_candidate_name` (2020 only: Biden or
Trump, candidates for the other office), `target_office_np` (a noun phrase
for the office the item is about; 2020: "the vice president", "the next
VP"; 2024: "the president", "the new president"), `other_office_np` (the
other office; 2020: "the president"; 2024: "the vice president"),
`generic_np` ("the winner", "the candidate": neither office), `other` (no
reference found), `blank`. Office nouns count after a determiner ("the",
"next", "our", "US"…) or at the very start of the completion ("vice
president" after "…protect the president and"), not as a bare predicate
("will become president").

The shared coder is `code_cloze_response()` in `shared/common_schema.R`.
Each study also keeps its original coding as `cloze_code_original`. The two
mostly agree; the main differences are:
- 2020's original coding had no generic-NP category ("the vice president
  will…" was `none`).
- The original codings disagreed about precedence when a completion
  mentions both a name and a pronoun. 2020 ranked names first, 2024
  pronouns first. The shared code uses whichever comes first; the
  `has_*` columns keep the rest.
- 2024 original-coding bug: it was meant to skip "them" when it refers back
  to item 9's prompt ("…many challenges, and one of"). Its check tested the
  response instead of the prompt, so it never applied, and about 31 such
  completions were coded as singular *they*. The shared coder handles this
  correctly.

`coref_*` is set by `code_cloze_coreference()` in `shared/common_schema.R`.
A completion is coded by rule when it is simple: exactly one pronoun kind,
no name of a candidate for the other office, not both candidates' names, no
mention of the other office, and, for *they*, no other group of people it
could refer to ("the people", "Congress"...). Then that pronoun refers to the
office-holder. A hand check of 65 rule-coded completions found one error
("…claim the election was stolen from him", where *him* is Trump as the
loser). Every other completion with a pronoun (about 100) is coded by hand
in `shared/cloze_coreference_judgments.csv`, keyed by study, item and exact
response, with a note on non-obvious cases. Examples coded as not referring
to the office-holder: "the vice president will act as president if the
president cannot perform *his* duties" (2020), "…wherever he goes and
*they* will report" (*they* = the press). The prep stops if a completion
needing a hand judgment has none. Pasted text among them is flagged by
`cloze_nonsense` (reason `pasted_text`).

`cloze_nonsense` is set by `flag_cloze_nonsense()` in
`shared/common_schema.R`, identically for both studies:
- `blank`: nothing typed.
- `filler_or_number`: only "yes", "no", "ok", "idk" or similar, or only
  digits (e.g. "1", "34", which recur across many 2020 items).
- `pasted_id`: the participant's Prolific ID (redacted in this repo).
- `copied_context`: a word-for-word piece of the context sentence, at least
  two words, e.g. "next presidential", "January 20, 2021".
- `pasted_text`: pasted text, judged by hand in `shared/cloze_pasted_text.csv`
  (news articles, encyclopedia text, an ad, another item's stimulus, and
  essays that repeat the prompt before continuing). Found by reviewing every
  completion of 15+ words or containing "..."; the file also lists 6
  polished, generated-sounding completions that are *not* flagged
  (`pasted` = FALSE), for review.
- `single_word`: one word judged not to be a sensible continuation of that
  item ("aircraft" after "…well-equipped to guarantee"). Judgments are by
  hand, in `shared/cloze_single_word_judgments.csv` (one row per study x item
  x word, with a reason for each "not sensible"). Sensible single words,
  including pronouns and names, are not flagged. The prep stops if a
  single-word completion has no judgment.

Short off-topic completions that are neither copied nor pasted ("winning
moment") are not flagged.

### `reading` (one row per word, Maze/mazerace/SPR, critical and practice trials)

| Column | Meaning |
|---|---|
| `task` | `maze`, `spr`, `mazerace` |
| `is_practice` | Practice trial (not a critical item) |
| `sen1_item`, `sen2_item` | Item numbers of the two critical sentences (study-specific numbering); for mazerace, `sen1_item` is the race-sentence frame and `sen2_item` is NA |
| `pro1_type`, `pro2_type` | `she`, `he` or `they` in sentence 1 and sentence 2 |
| `race_adjective` | Mazerace only: `black`, `white`, `Black`, `White` |
| `word_index` | Position in the trial, from 1 |
| `sentence_index`, `word_index_in_sentence` | 0 = context sentence, 1 and 2 = critical sentences (NA for practice) |
| `word` | The word shown |
| `is_pro1`, `is_pro2`, `is_race_adjective` | The critical word(s) of the trial |
| `rt` | Maze: time to the first choice; SPR: reading time; ms, as recorded |
| `maze_correct` | Maze: first choice was the correct word |
| `maze_distractor` | Maze: the distractor word |
| `maze_correct_side` | Maze: `left`/`right` position of the correct word. **NA for 2024 critical trials** (logged for practice trials only) |
| `maze_time_to_correct` | Maze: total time until the correct word was chosen |

Each critical gender trial is a context sentence plus two different critical
sentences; every critical trial has exactly one `is_pro1` word and one
`is_pro2` word (checked at prep time), and every mazerace trial one
`is_race_adjective` word.

### `comprehension` (one row per question answered)

`task`, `question`, `answer`, `correct_answer`, `correct`. 2020 asked one
question after each Maze/SPR/mazerace trial; 2024 one after each Maze/SPR
trial.

### `recall` (one row per answer)

`recall_response`: who the participant thinks the writer of the sentences
believes will hold the office (candidate name, "Writer is unsure" or "I
don't remember").

## Known data quirks

- **2024 runs.** Two `workerid`s per wave hold two complete runs, each with
  its own condition. Each run is a session; both carry
  `excl_duplicate_submission`, as in the original.
- **2024 sessions that never reached a task** (37 pre, 61 post runs: browser
  check or instructions only) are not kept.
- **2024 SPR practice text** isn't logged; it is filled in from the
  experiment code ("Press space in order to reveal the next word.").
- **2024 news question** is missing for 728 of 1,290 pre-election sessions,
  mostly early ones (and 7 post): `news_consumption` is NA there.
- **All sliders at 0** (2020: 15 pre, 14 post sessions): `slider_value` is
  kept, `probability` and `expect_prob_*` are NA.
- **2020 `asked_about_vp`** was always FALSE in this repo's outputs before
  2026-10-06 (a parsing bug, now fixed); `expectation_target` relies on it.
