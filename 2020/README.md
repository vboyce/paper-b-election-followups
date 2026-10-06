# 2020 (MVP: Kamala Harris as VP candidate)

## Layout

- `raw/` - de-identified raw data.
  - `{pre,post}_election_ibex_rows.csv.gz`: every data row of the original
    Ibex result logs, in order, as headerless comma-separated lines, with
    the MD5 IP-hash column replaced by a pseudonymous `participant_id`
    (see `prep/deidentify_raw_logs.R`). The mapping is shared across both
    files, so the same IP hash has the same pseudonym in both. The logs'
    comment lines are not kept: they only repeat the column descriptions
    below before every block. The exceptions are the per-submission design
    number, kept in the submissions file, the "Results on <date>" line,
    which repeats column 1, and the browser user-agent, which is dropped.
  - `{pre,post}_election_ibex_submissions.csv`: one row per submission
    (`time`, `participant_id`, `design_number`). `design_number` is Ibex's
    counter for assigning lists/conditions ("Design number was non-random
    = N" in the original log). It is not unique across sessions.
  - `mturk_session_linkage.csv`: one row per Ibex session linking it to its
    MTurk assignment, with the MTurk WorkerId replaced by a `worker`
    pseudonym (shared across rounds). Built outside this repo by
    `private/2020-mturk/build_mturk_linkage.R` (in the parent
    `paper-b-election-followups/` folder) from the original
    `mturk_HIT_results.tsv` files, which contain real WorkerIds and are
    deliberately not in this repo. It contains no WorkerId, AssignmentId
    or HITId; that script fails if anything ID-like reaches the output.
  - `stimuli.tsv` / `stimuli_mazerace.tsv`: experiment materials (identical
    between rounds), including the comprehension-question answer key.
- `prep/`
  - `shared_prep_functions.R`: all parsing/cleaning logic, used identically
    by `prep_pre_election.R` and `prep_post_election.R`.
  - `validate_against_original.R`: checks the output against the original
    analysis's published per-condition counts and stops on any mismatch.
- `processed/` - gzipped CSVs, one set per round (`pre_*`, `post_*`), all
  keyed by `session_id`:
  - `sessions`: one row per Ibex session (all sessions, nothing dropped),
    with demographics, condition, Ibex design number, pseudonyms, MTurk/HIT info, per-session
    RT and accuracy summaries, and all exclusion columns (below).
  - `expectations`, `cloze`, `recall`, `comprehension`, `maze`, `spr`:
    task data for every session.

To regenerate `processed/` from `raw/`, run (from `prep/`):
`Rscript prep_pre_election.R && Rscript prep_post_election.R && Rscript validate_against_original.R`

## Ibex row format (`raw/*_ibex_rows.csv.gz`)

Every row starts with the same 7 columns:

| Col | Content |
|---|---|
| 1 | Time results were received (Unix epoch seconds; one value per submission) |
| 2 | `participant_id` (pseudonym replacing Ibex's MD5 hash of the IP address) |
| 3 | Controller name |
| 4 | Item number |
| 5 | Element number |
| 6 | Type |
| 7 | Group |

The remaining columns depend on the controller (column 3) and the number of
fields, which together always identify the layout (checked in
`prep/deidentify_raw_logs.R`; Ibex URL-encodes commas inside fields):

| Controller | Fields | Columns 8+ | Rows (pre / post) |
|---|---|---|---|
| `Maze` | 15 | 8 word number, 9 word, 10 alternative (distractor), 11 word on (0=left, 1=right), 12 correct, 13 reading time to first answer, 14 sentence, 15 total time to correct answer | 161,564 / 174,353 |
| `DashedSentence` | 12 | 8 word number, 9 word, 10 reading time, 11 newline?, 12 sentence (or sentence MD5) | 109,379 / 92,564 |
| `DashedSentence` | 8 | 8 sentence (or sentence MD5): one row per sentence shown, no word RTs | 18,592 / 18,172 |
| `Question` | 11 | 8 question (NULL if none), 9 answer, 10 whether the answer was correct (NULL if N/A), 11 time taken to answer | 46,017 / 49,361 |
| `Form` | 9 | 8 field name, 9 field value | 14,906 / 14,499 |
| `Slider` | 9 | 8 field name, 9 field value | 13,944 / 13,629 |

All 12-field `DashedSentence` rows (the SPR word RTs) and all `Maze` rows
appear in `processed/*_spr` and `processed/*_maze`. The 8-field
`DashedSentence` rows carry no RTs and aren't used by the prep.

## Exclusions

Nothing is dropped during prep. Each criterion is a TRUE/FALSE column on
the `sessions` table (never NA: a criterion that can't apply, e.g. a Maze
criterion for an SPR participant, is FALSE). An analysis picks its sample
by filtering, e.g. `filter(!excl_original_rule)`, and robustness checks
add `flag_*` columns on top.

### Applied in the original analysis (`excl_*`)

`excl_original_rule` is the union of these. It is the default analysis
sample, i.e. the original criteria with the corrections listed under
"Deviations from the original".

| column | criterion |
|---|---|
| `excl_not_native` | answered "no" to "Are you a native speaker of English?" |
| `excl_repeat_ip` | not the first session from this IP pseudonym in this round |
| `excl_repeat_worker` | not the first session from this MTurk worker in this round |
| `excl_worker_in_pre_round` | (post only) worker submitted any pre-election assignment |
| `excl_spr_rt_too_fast` / `_too_slow` | any SPR word RT ≤ 180 ms / ≥ 10000 ms (practice included) |
| `excl_maze_rt_too_fast` / `_too_slow` | any Maze word RT ≤ 180 ms / ≥ 10000 ms (practice and mazerace included) |
| `excl_no_slider_movement` | all three event-expectation sliders left at 0 |

`excl_original_replication` reproduces the original analysis's exclusion
exactly, including its linkage method and quirks. It exists only so that
`validate_against_original.R` can check this pipeline against the
original counts. Don't use it for analysis.

### Candidate criteria, not applied in the original (`flag_*`)

For robustness checks. Counts are sessions flagged among those *kept*
under `excl_original_rule` (pre: 1605 kept, post: 585 kept), from the
current `processed/` output.

| column | criterion | pre | post |
|---|---|---|---|
| `flag_not_linked_to_mturk` | no MTurk assignment matches this session (can't verify the worker) | 42 | 19 |
| `flag_code_submitted_by_multiple_workers` | more than one MTurk account submitted this session's survey code (code sharing) | 2 | 0 |
| `flag_worker_did_multiple_assignments` | worker submitted more than one assignment this round, so this flags even their *first* session | 208 | 91 |
| `flag_ip_had_multiple_sessions` | IP pseudonym had more than one session this round, first session included | 191 | 90 |
| `flag_ip_in_pre_round` | (post only) IP pseudonym also appears in the pre-election log | 0 | 0 |
| `flag_not_us_resident` | answered "no" to "Do you currently reside in the United States?" | 95 | 32 |
| `flag_not_us_citizen` | answered "no" to "Are you a citizen of the United States?" | 91 | 36 |
| `flag_comprehension_wrong` | answered the single post-passage comprehension question wrong (SPR, Maze, mazerace conditions) | 174 | 66 |
| `flag_maze_accuracy_low` | < 80% of experimental Maze words chosen correctly on the first try | 88 | 72 |
| `flag_pre_on_or_after_election_day` | (pre only) submitted on or after 2020-11-03 00:00 US Eastern | 2 | 0 |
| `flag_post_before_race_called` | (post only) submitted before the race was called (2020-11-07 ~11:25 US Eastern) | 0 | 0 |
| `flag_post_unaware_race_called` | (post only) did not answer "yes" to "Are you aware that major news outlets have officially projected…" | 0 | 18 |

The `sessions` table also has the continuous measures behind these, so
thresholds can be varied. These include `spr_prop_rt_out_of_range` /
`maze_prop_rt_out_of_range` (the share of experimental words outside
180–10000 ms, a less all-or-nothing alternative to the any-word RT
criteria), `maze_accuracy`, `comprehension_correct`,
`worker_n_assignments_round`, `ip_n_sessions_round`, the session ranks,
`mturk_elapsed_sec`, and the HIT's qualification requirements
(`hit_required_*`, e.g. Master qualification or none).

### Why the exclusion rates are so high

HITs were posted over and over: pre-election with 2, 3, 5 or 9
assignments each, and post-election with 1 each (see
`private/2020-mturk/*/create_HIT_log.txt`). MTurk only prevents a worker
from taking the same HIT twice, so the same worker could take the study
again and again through new HITs (up to 175 assignments from one worker
pre-election and 291 post-election; see
`private/2020-mturk/*/mturk_HIT_results.tsv`). Most exclusions are
therefore repeat sessions: 2164 pre and 2978 post by IP, 2202 pre and
3011 post by worker. Post-election also excludes 1991 sessions from
workers who had taken part pre-election.

## Validation against the original pipeline

`validate_against_original.R` compares kept counts per round × condition
with the "not excluded" column of the original `data-analysis.md` tables.
`excl_original_replication` matches all 16 cells exactly (pre 1607, post
589). The script stops if any cell differs.

| | original kept | `excl_original_replication` | `excl_original_rule` |
|---|---|---|---|
| pre-election | 1607 | 1607 | 1605 |
| post-election | 589 | 589 | 585 |

The task tables were also checked once (during the 2026-10-05 rewrite)
against the previous version of this pipeline's output, for every session
kept by both versions. SPR, Maze, recall and expectation rows were
identical. Cloze gained 13 (pre) and 15 (post) rows, all blank responses
that the old version dropped.

## Deviations from the original

Each of these is reflected in `excl_original_rule` but not in
`excl_original_replication`.

1. **MTurk linkage.** The original matched sessions to MTurk on survey code
   plus submission time rounded to the nearest 2 hours. That misses
   sessions whose Ibex receipt and MTurk submission (normally ~10 s apart)
   straddle a rounding boundary. Here the match is survey code plus an
   MTurk submission within −2 min to +60 min of the Ibex receipt, nearest
   in time, one assignment per session. This links 4532 vs 4507 (pre) and
   4453 vs 4385 (post) sessions. The two methods agree on every session
   they both link, except sessions flagged
   `flag_code_submitted_by_multiple_workers`.
2. **Pre-election worker list.** The original's pre-election MTurk file was
   pulled by HIT creation date and also contains 7 post-election
   assignments, so those workers counted as "took part pre-election".
   They are removed here.
3. **Missing SPR RTs.** Ibex logged the RT of a sentence-final word as
   `None` in 7 pre and 1 post sessions. The original took `min()`/`max()`
   without `na.rm`, so those sessions got NA and escaped both SPR RT
   criteria. Here missing RTs are ignored (`spr_n_missing_rt` counts them)
   and the criteria are applied to the remaining words.
4. **Blank cloze responses** are kept in the cloze table (with
   `cloze_pronoun` = NA) rather than dropped.

## Not yet done

- Comprehension accuracy for the SPR practice item isn't scored (no answer
  key in the stimulus files).
- The original's `bot_screening` form is not used: every session has the
  same value, so it carries no information.
- No harmonized schema with the 2024 study yet.
