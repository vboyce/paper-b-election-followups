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

Both follow the same layout: `raw/` (de-identified/checked-safe raw data),
`prep/` (a `shared_prep_functions.R` used identically by both rounds/waves
of that study, plus thin per-round/wave driver scripts), `processed/`
(the tidy per-task CSVs the drivers produce). See each study's `README.md`
for what's fixed relative to the original pipeline, what limitations
remain (mainly: neither study's original cross-submission dedup is fully
reproducible here, since it depended on real MTurk/Prolific IDs that are
deliberately not part of this repo), and a validation comparison against
the original pipeline's output.

## What's not here (yet)

- The 2020 pilots (pilot-01/02/03) and the informal 2020 gender-pro-maze
  pilot - background/exploratory data, out of scope for now.
- A harmonized schema *across* 2020 and 2024 (e.g. a shared column naming
  convention for "RT at the target pronoun" regardless of study/task).
  Both studies are now internally consistent (pre vs post use identical
  logic within each study), but making the two studies' outputs
  comparable to each other is a separate follow-up step.
- Any actual analysis - this repo currently only takes raw data to
  cleaned, per-task tables.
