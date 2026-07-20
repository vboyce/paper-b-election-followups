# 2020 (MVP: Kamala Harris as VP candidate)

## Layout

- `raw/` - de-identified raw data. `pre_election_results.txt` /
  `post_election_results.txt` are the original Ibex result logs with the
  MD5 IP-hash column replaced by a per-file pseudonymous participant ID
  (see `prep/deidentify_raw_logs.R` for how, and why). `stimuli.tsv` /
  `stimuli_mazerace.tsv` are the experiment materials (identical between
  the pre- and post-election rounds).
- `prep/` - `shared_prep_functions.R` holds all the parsing/cleaning logic,
  used identically by `prep_pre_election.R` and `prep_post_election.R` so
  the two rounds can't silently drift apart in exclusion criteria or
  column handling.
- `processed/` - tidy, per-task CSVs written by the prep scripts:
  `{pre,post}_participants.csv`, `_expectations.csv`, `_cloze.csv`,
  `_recall.csv`, `_maze.csv`, `_spr.csv`.

To regenerate `processed/` from `raw/`, run (from `prep/`):
`Rscript prep_pre_election.R && Rscript prep_post_election.R`

## Known limitation: no MTurk WorkerId

The original pipeline (see the source `2020-madame-vice-president/` copy)
excluded repeat participants using the real MTurk WorkerId, joined in from
`mturk_HIT_results.tsv` - a file excluded from this repo because it
contained plaintext AWS keys and real MTurk WorkerIds (see the top-level
`STATUS.md`). The post-election round additionally used WorkerId to
exclude anyone who had already done the pre-election round.

Neither of those checks is reproducible here. This prep pipeline instead
only catches repeat submissions detectable from the pseudonymous
per-file participant ID (a stand-in for the original MD5 IP hash) within
one round - `process_round()` prints a message noting this every run.

This is not a small effect: cross-validating against the original
pipeline's published per-condition participant counts
(`data-analysis.md` in each round's folder), the *total* number of raw
sessions parsed matches exactly (4648 pre-election, 4543 post-election),
but the number of participants *kept after exclusions* is higher here
than in the original:

|        | original kept | this pipeline's kept | difference |
|--------|---------------|------------------------|------------|
| pre-election  | 1607 | 1647 | +40  |
| post-election |  589 |  927 | +338 |

The pre-election gap (+40) is small and plausibly just the participants
whose repeat submissions used a different IP but the same MTurk account.
The post-election gap (+338) is much larger, because it's also missing
the cross-round "did this person already do the pre-election round"
exclusion - about 7% of post-election sessions here are not excluded that
the original pipeline would have caught.

**If a paper is going to be built on the post-election data, this should
be resolved before drawing conclusions from it** - e.g. by having someone
with access to the original private `mturk_HIT_results.tsv` files compute
just the *list* of pseudonymous participant IDs that should be excluded
(without ever bringing the real WorkerIds into this repo) and adding that
as a small extra exclusion input file.
