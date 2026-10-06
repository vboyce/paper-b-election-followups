# Paper B: election follow-ups (2020 / 2024)

De-identified raw data and rewritten prep pipelines for the two unwritten
election-bias studies (2020: Kamala Harris as VP candidate; 2024: Kamala
Harris as presidential candidate), replicating the published 2016 US /
2017 UK Psych Science paradigm on implicit gender bias toward political
candidates.

This repo is a clean rebuild of the data-prep step for both studies,
starting from the original working copies (kept separately, not part of
this repo's history) after a pipeline/code review turned up several bugs
and inconsistencies that would have undermined a pre-vs-post or
cross-study comparison - see each study's own README for specifics.

- `2020/` - MVP pre-election and post-election rounds (maze + SPR +
  cloze + event-expectation + recall + a race-adjective control
  condition), MTurk.
- `2024/` - mmepr24 pre-election and post-election waves (maze + SPR +
  cloze + event-expectation), Prolific.

Both follow the same layout: `raw/` (de-identified raw data), `prep/` (a
`shared_prep_functions.R` used identically by both rounds/waves of that
study, plus thin per-round/wave driver scripts and a validation script),
`processed/` (the tables the drivers produce). Both studies' processed
tables share one schema, and `combined/` stacks them:

- `OVERVIEW.md` - what the two experiments were, the data at a glance, what
  was planned at the time, and the decisions left for a forward analysis
  plan.
- `DATA.md` - the common data framework: tables, core columns, how to
  regenerate everything.
- `METHODS-SUMMARY.md` - sourced methods detail for both studies.
- `OPEN-QUESTIONS.md` - unknowns that only co-authors could answer, and
  what has been checked.
- `shared/common_schema.R` - core column definitions, schema checks, and
  the shared cloze coder.
- `combined/` - both studies' core columns stacked
  (`combine_studies.R`).

Every session is kept, with exclusion criteria as columns. Each study's
validation script reproduces its original pipeline's counts exactly (2020
via a pseudonymous MTurk linkage built outside this repo; 2024 via the
`workerid`s the original's Prolific-based duplicate check removed); see
each study's `README.md`.

## What's not here (yet)

- The 2020 pilots (pilot-01/02/03) and the informal 2020 gender-pro-maze
  pilot - background/exploratory data, out of scope for now.
- Any actual analysis, including the analysis-stage choices (RT windows,
  residualization, which exclusions to apply) that the processed data
  deliberately leave open.

## License

- Code (`*.R` and other scripts): MIT, see `LICENSE`.
- Data (everything under `*/raw/`, `*/processed/` and `combined/`): CC BY 4.0, see
  `LICENSE-DATA`.

The data are de-identified: no IP addresses, MTurk WorkerIds or Prolific
IDs. See each study's README for how they were removed.
