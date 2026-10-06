# 2024 (mmepr24: Kamala Harris as presidential candidate)

## Layout

- `raw/` - raw data as exported from the experiment: `mme_pre_election-trials.csv`
  / `mme_post_election-trials.csv` (jsPsych/proliferate trial exports, which
  carry only the small internal `workerid` integer, not Prolific IDs) and the
  exported stimulus metadata CSVs (`exported_cloze_stim.csv`,
  `exported_comp_q.csv`, `exported_maze_stim.csv`). The two trial exports
  differ from the originals in one way: three participants typed their
  Prolific ID into a cloze response box, and `prep/redact_raw_free_text.R`
  replaces those with `REDACTED_PROLIFIC_ID` (one-time step, kept for
  provenance; everything else in the files is byte-for-byte identical).
- `prep/`
  - `shared_prep_functions.R`: all parsing and exclusion logic, used
    identically by `prep_pre_election.R` and `prep_post_election.R`.
  - `validate_against_original.R`: checks the output against the original
    pipeline's processed tables and stops on any mismatch.
- `processed/` - gzipped CSVs, one set per wave (`pre_*`, `post_*`), in the
  common framework shared with 2020 (core columns first; see `../DATA.md`),
  all keyed by `session_id`:
  - `sessions`: one row per session (see below), nothing dropped, with
    demographics, condition, per-session summaries and all exclusion
    columns.
  - `expectations`, `cloze`, `reading` (Maze and SPR words, critical and
    practice), `comprehension`, `recall`: task data for every session.

To regenerate `processed/` from `raw/`, run (from `prep/`):
`Rscript prep_pre_election.R && Rscript prep_post_election.R && Rscript validate_against_original.R`

## Sessions

A proliferate `workerid` can hold more than one run of the experiment (its
trial counter restarts). Each run that reached a task is a session,
`session_id` = `2024-<wave>-<workerid>-<run>`:

| | Pre | Post |
|---|---|---|
| Sessions (runs that reached a task) | 1,290 | 1,288 |
| Runs that never reached a task (browser check / instructions only), not kept | 37 | 61 |
| `workerid`s with two complete runs (both runs flagged `excl_duplicate_submission`) | 2 | 2 |

## Exclusion columns

Each criterion of the original pipeline (`analysis/*-process.Rmd`) is a
column; nothing is filtered.

| Column | Criterion |
|---|---|
| `excl_no_survey` | Run has no end-of-study survey (didn't finish) |
| `excl_duplicate_submission` | The `workerid` submitted the survey more than once (across runs) |
| `excl_original_prolific_dedup` | Removed by the original's Prolific-ID-based duplicate checks (see below): pre `workerid` 1916, 2483; post 3621, 3776, 3990, 4121, 4184, 4308 |
| `excl_not_us_resident`, `excl_not_us_citizen`, `excl_not_native_english` | Answered no (or didn't answer) |
| `excl_comprehension_wrong` | Maze/SPR session that got its comprehension question wrong |
| `excl_maze_errors_over_cutoff` | Maze session with more errors than mean + 2 SD of the Maze sessions passing the criteria above (cutoff 16 errors in both waves) |
| `excl_expectations_original` | Original rule for event expectations and cloze: any of the first six |
| `excl_recall_original` | Original rule for recall: the above plus comprehension |
| `excl_task_original` | Original rule for the session's task: the above plus the Maze-error cutoff |

The `*_replication` columns equal the original-rule columns: there are no
corrections to the 2024 rules here.

**Prolific duplicates.** The original removed duplicates using a private
file linking each `workerid` to a Prolific ID (not in this repo). It
removed (1) `workerid`s with more than one survey response, (2)
`workerid`s linked to more than one Prolific ID, and (3) `workerid`s whose
Prolific ID was linked to more than one `workerid`. (1) is computed from
the trial data. (2) and (3) can't be, so the `workerid`s they removed are
listed by hand in the drivers. They were found by comparing this
pipeline's output with the original's processed participant tables, which
were exactly ours minus these `workerid`s. Prolific's own controls are
trusted to prevent the same person taking part in both waves or under two
accounts.

## Validation against the original pipeline

`validate_against_original.R` rebuilds each original table's participant
count from the exclusion columns (distinct `workerid`s, as in the
original's output in `2024-mmepr24/data/processed/`):

| Table | Pre (original = this repo) | Post (original = this repo) |
|---|---|---|
| participants | 1,279 | 1,273 |
| expectations | 1,255 | 1,246 |
| cloze | 485 | 497 |
| recall | 241 | 228 |
| maze (after error cutoff) | 244 | 235 |
| SPR before exclusions | 496 | 488 |

SPR after exclusions: 447 pre / 439 post here, vs. 445 / 432 in the
original. The original additionally dropped words outside a 180–5000 ms
window (applied to each word and the next three), which removed a few more
sessions. That word-level step is an analysis choice and isn't applied here.

## Differences from the original pipeline

- **Nothing is dropped and RTs aren't transformed.** The original filtered
  participants per table, dropped Maze words after errors, trimmed SPR RTs
  and replaced RTs with residuals from a mixed model. Those choices move
  to the shared analysis stage; the original's pre-election SPR also
  filtered the RT window after fitting the residualization model, but
  post-election before.
- **Cloze coding.** `cloze_code` uses the shared classifier. The original
  coding is kept as `cloze_code_original`, using the post-election version
  of its regexes for both waves (a strict superset of the pre-election one)
  plus a hand-checked override for `workerid` 1676 and 2291 on item 12
  (pre-election only; those `workerid`s don't exist post-election). The
  original's rule for skipping a non-referential "them" after item 9's
  prompt tested the response instead of the prompt, so it never applied;
  the shared classifier applies it.
- **`ParseJSONColumn`** uses the post-election version's extra
  quote-normalizing rule for both waves (the pre-election version fails on
  post-election responses that contain a quoted word).
- **Political affiliation fix** (pre-election only): a survey bug stored
  political affiliation under "news" for some participants; it is moved
  back, as in the original.
- The original's completion-code check was dead code (computed, never
  applied) and isn't ported.

## Not recoverable from the raw data

- The correct word's side (`maze_correct_side`) for critical Maze trials:
  the plugin's `order` field is empty for them (logged for practice only).
- The SPR practice sentence isn't logged; it is filled in from the
  experiment code (`experiment/src/experiment.js:244-250`).
- The news-consumption answer for 728 of 1,290 pre-election sessions
  (mostly early ones) and 7 post-election.
