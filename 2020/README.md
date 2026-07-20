# 2020 (MVP: Kamala Harris as VP candidate)

## Layout

- `raw/` - de-identified raw data. `pre_election_results.txt` /
  `post_election_results.txt` are the original Ibex result logs with the
  MD5 IP-hash column replaced by a pseudonymous participant ID (see
  `prep/deidentify_raw_logs.R` for how, and why - the mapping is shared
  across both files, so the same underlying IP hash gets the same
  pseudonym in both, which is what makes the cross-round exclusion below
  possible). `stimuli.tsv` / `stimuli_mazerace.tsv` are the experiment
  materials (identical between the pre- and post-election rounds).
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

Neither check can be reproduced exactly without that file. As a proxy,
this pipeline instead:

- excludes repeat submissions detectable from the pseudonymous
  participant ID (a stand-in for the original MD5 IP hash) *within* one
  round (`excl_reason` = `repeat_participant`) - this reproduces the
  original's `repeat.md5` check exactly, since the pseudonym is just a
  1:1 relabeling of the same hash;
- for the post-election round, additionally excludes anyone whose
  pseudonymous ID also appears anywhere in the pre-election round's raw
  log (`excl_reason` = `participated_in_previous_round`), since the
  pseudonym mapping is shared across both rounds.

That second check only catches someone who used the *same computer/IP* in
both rounds - it will miss a repeat participant who switched IP/browser
but used the same MTurk account, which is exactly what the original
WorkerId-based check *would* have caught and this can't. `process_round()`
prints a message noting this every run.

**Validation against the original pipeline:** cross-checking against the
original's published per-condition participant counts (`data-analysis.md`
in each round's folder), the *total* number of raw sessions parsed
matches exactly (4648 pre-election, 4543 post-election). The number of
participants *kept after exclusions* is close but still somewhat higher
here than in the original, entirely attributable to the missing
WorkerId-based check:

|                | original kept | this pipeline's kept | difference |
|----------------|---------------|-----------------------|------------|
| pre-election   | 1607          | 1647                  | +40        |
| post-election  |  589          |  907                  | +318       |

Before adding the cross-round IP-hash check, post-election's gap was
+338; the check closes 20 of those 338 (the participants who repeated
from the same IP). The remaining +318 gap is participants the original
WorkerId-based check would have caught that this repo's pipeline
structurally cannot: mainly people who did both rounds from a different
IP/browser under the same MTurk account.

**If a paper is going to be built on the post-election data, this
remaining gap should be resolved before drawing conclusions from it** -
e.g. by having someone with access to the original private
`mturk_HIT_results.tsv` files compute just the *list* of pseudonymous
participant IDs that should be excluded (without ever bringing the real
WorkerIds into this repo) and adding that as a small extra exclusion
input file.
