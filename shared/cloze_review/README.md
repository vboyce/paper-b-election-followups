# Cloze review app

A small Streamlit app for checking the cloze codes (`cloze_code`, `coref_*`,
`first_coref_pronoun`, `cloze_nonsense`) by hand. It has two modes:

- **Blind recode (random sample):** 150 unique completions drawn uniformly at
  random (fixed seed) from all non-blank ones. The current codes are hidden.
  Agreement with the current codes (percent agreement and Cohen's kappa) is
  the reliability check. Do this before review mode.
- **Review (hand-judged completions):** the 286 completions whose current
  codes rest on a hand judgment (coreference judged by hand, pasted-text
  judgments, single-word judgments). The current codes are shown and
  prefilled, so you confirm or correct them.

In both modes the references the coding rules matched are highlighted:
pronouns (numbered and coloured), candidate names (solid underline), and
office / winner noun phrases (dashed underline). The highlights use the same
regexes as the coding (`cloze_reference_patterns()` in `../common_schema.R`).
Anything the rules missed is not highlighted; note it in the Note field.

## What you code for each completion

- **Each numbered pronoun:** who it refers to: the target office-holder
  (2020: the vice president; 2024: the president), the other office-holder,
  or someone / something else. The `coref_*` columns and
  `first_coref_pronoun` are derived from these answers.
- **First referring expression (`cloze_code`):** the first expression of any
  of the listed kinds, whoever it refers to. Office nouns count after a
  determiner ("the", "next", "our", ...) or at the very start of the
  completion, so "will become president" doesn't count. If there is none,
  choose "none of these".
- **Nonsense:** whether the completion is not a real attempt (and why).
  The reasons are the same as for `cloze_nonsense_reason` in `DATA.md`.

## Running it

From the repo root (`paper-b/`), with the project's Python environment:

```
python3 -m venv .venv && .venv/bin/pip install streamlit pandas pytest   # once
Rscript shared/cloze_review/prepare_cloze_review.R   # rebuilds review_items.csv
.venv/bin/streamlit run shared/cloze_review/app.py
```

`prepare_cloze_review.R` needs to be re-run only if the cloze data or
coding changes. Decisions are saved on every "Save and next" to
`decisions/blind.csv` and `decisions/review.csv` (one row per completion;
saving again replaces the earlier row). Decisions are keyed by a hash of
study, item and response text, so they survive regenerating
`review_items.csv`.

## Reports

```
.venv/bin/python shared/cloze_review/report.py agreement   # blind sample vs. current codes
.venv/bin/python shared/cloze_review/report.py changes     # review: corrections to make
```

`agreement` writes `decisions/blind_agreement.csv` (n, percent agreement and
kappa per code) and `decisions/blind_disagreements.csv`. Coreference columns
are scored only over completions that contain that kind of pronoun, since
everywhere else both sides are trivially FALSE. Kappa is NaN when both sides
use a single value. `changes` writes `decisions/review_changes.csv`: one row
per completion and code where your answer differs from the current code.

Corrections are not applied automatically. They go into the hand-judgment
files in `shared/` (`cloze_coreference_judgments.csv` and the others), and
the prep is then re-run. A correction to a rule-coded completion means
changing the rule or adding a hand judgment for it.

## Files

- `prepare_cloze_review.R`: builds `review_items.csv` (unique completions,
  current codes, highlight spans, blind sample, priority).
- `app.py`: the Streamlit UI.
- `review_logic.py`: everything except the UI (highlighting, referents to
  codes, saving, agreement).
- `report.py`: the agreement and changes reports.
- `tests/`: `pytest` tests for `review_logic.py`, plus end-to-end tests of
  `app.py` (Streamlit's `AppTest`) on the real `review_items.csv`. Run them with
  `cd shared/cloze_review && ../../.venv/bin/pytest`.
