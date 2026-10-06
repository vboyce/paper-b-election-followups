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
- `prep/` - `shared_prep_functions.R` holds all the parsing/cleaning logic,
  used identically by `prep_pre_election.R` and `prep_post_election.R`.
- `processed/` - tidy, per-wave CSVs written by the prep scripts:
  `{pre,post}_participants.csv`, `_expectations.csv`, `_cloze.csv`,
  `_recall_question.csv`, `_maze.csv`, `_spr.csv`, `_spr_all.csv`.

To regenerate `processed/` from `raw/`, run (from `prep/`):
`Rscript prep_pre_election.R && Rscript prep_post_election.R`

## What changed relative to the original `analysis/*-process.Rmd`

See the file-level comment at the top of `prep/shared_prep_functions.R` for
the full list with reasoning. In short:

- Pre and post now go through one shared function, so they can't drift
  apart in exclusion criteria or column handling the way the two original
  Rmds had (different SPR residualization order, different cloze regex,
  a workerid override that only made sense in one wave).
- The SPR RT window is filtered *before* fitting the residualization model
  in both waves (previously pre filtered after, post filtered before).
- No dependency on `data/mme_*-workerids.csv` / `data/prolific_export_*.csv`
  - neither is part of this repo (real Prolific IDs). This means the
  "same person under two different Prolific accounts" exclusion isn't
  reproducible here; `process_wave()` prints a message every run noting
  this. Participant screening (residence/citizenship/English) still works,
  since those were asked directly in the experiment's own survey.

## Validation against the original processed output

Row counts were compared against the original `2024-mmepr24/data/processed/*.csv`
(both waves). They're close but not identical, entirely for the two
reasons above:

|                    | pre: original -> this repo | post: original -> this repo |
|--------------------|------------------------------|--------------------------------|
| participants kept  | 1279 -> 1281 (+2)             | 1273 -> 1279 (+6)               |
| expectations rows  | 3765 -> 3771 (+6 = 2×3)       | 3738 -> 3756 (+18 = 6×3)         |
| spr (residualized) | 20204 -> 20141 (-63, see below) | 19933 -> 19977 (+44, matches participant delta) |

The small increase in kept participants (+2 pre, +6 post) is the expected
size of the missing cross-Prolific-account dedup, and shows up
proportionally through expectations/maze/spr row counts. The pre-election
SPR table also drops by 63 rows independent of that, because fixing the
residualization-order inconsistency changes pre-election's result slightly
(post's original order already matches what this repo now uses for both
waves, so post's SPR count moves only with the participant-count delta).
