# To do

Open work items for Paper B. Questions only someone else can answer go in
`OPEN-QUESTIONS.md` instead.

## Cloze coding: codebook and reliability check

The cloze completions are tagged partly by rule and partly by hand
(Claude, 2026-10-07). None of it has been checked by a person yet.

- **Codebook.** Write one document describing how every cloze column is
  assigned, with decision rules and examples:
  - `cloze_code`, `has_*`: regex rules in `code_cloze_response()`
    (`shared/common_schema.R`)
  - `coref_*`, `coref_other_*`: rule for simple completions, hand
    judgments in `shared/cloze_coreference_judgments.csv` for the rest
  - `cloze_nonsense`: rules plus hand judgments in
    `shared/cloze_single_word_judgments.csv` and
    `shared/cloze_pasted_text.csv`

  `DATA.md` (cloze section) has the current summary to start from.
- **Spot check / inter-rater reliability (Veronica).** Use the review app
  in `shared/cloze_review/` (see its README):
  1. Blind recode: 150 unique completions, uniform random sample (fixed
     seed), codes hidden; `report.py agreement` gives percent agreement and
     kappa per column. A uniform sample is thin for rare codes (e.g. 2020
     "she"); add a stratified top-up if the kappas are too uncertain.
  2. Review: the 286 completions whose codes rest on hand judgments, codes
     shown and prefilled; `report.py changes` lists the corrections, which
     then go into the judgment files in `shared/`.

  Rule-coded coreference (627 completions; a 65-item check by Claude found
  1 error) is checked only through the random sample.
- **Done (2026-10-08).** Blind coding: `cloze_code` 94.7% agreement (kappa
  .93), coreference 100%, nonsense 88.7% (kappa .61). Rule fixes from it:
  office adjectives count, office nouns after "of", misspellings, titles
  before names count as the name. Review of 289 priority completions done;
  all hand decisions (417 completions) are applied in the prep via
  `shared/cloze_hand_review.csv`. Robustness set `all_pronoun_clozes` keeps
  nonsense-flagged completions with a pronoun referring to the office-holder
  (adds 6 sessions, all 2024 *they*); we rely on it instead of refining
  pasted / AI-generated detection.
- Optional: collapse the nonsense reasons (`single_word` and
  `doesnt_make_sense` were used interchangeably for single words) if the
  reason is ever used.
- Optional: "precident" misspelling for the office noun (only hand-coded
  so far).

## Party affiliation vs. stated candidate preference

Among 2020 post-election sessions passing the quality checks, only 62% of
self-described Republicans preferred the Republican candidate (79%
pre-election; 90–94% for quality-passing 2020 Democrats, 90–97% for both
parties in 2024 before quality checks). Not a
coding error (checked 2026-10-07: preference is parsed from the candidate
name; the drop holds for both the president and vice-president questions).
Decide later whether to: group by stated preference instead of / as well
as affiliation; treat affiliation–preference disagreement as a consistency
check; or leave as is.

## Models (see analysis/models/)

- Focus is mainly on Maze (the clearer measure); SPR is secondary.
- SPR region (decided 2026-10-08): arithmetic mean RT (ms, linear scale) of
  the pronoun and the next three words, one row per session, ex-Gaussian like
  Maze. A session's region is dropped if any of the four words is outside the
  RT window. Alternatives to consider later:
  - word-level model with word position (and word length) as predictors and
    session random effects, instead of averaging
  - the pronoun alone, or spillover words only
  - sum or geometric mean instead of the arithmetic mean (2016: log of
    pronoun + 4 summed; 2024: geometric mean of pronoun + 3)
  - residualized RTs (2016, 2024) vs. raw
  - keep the region when only some words are out of window (mean of the rest)
- RT models use `exgaussian()` (decided 2026-10-07: RTs are strongly
  right-skewed; ex-Gaussian fit Maze best, shifted lognormal fit SPR slightly
  better). Open: whether the tail (`beta`) should also vary by condition.
- Add model versions with gender / politics (party, preference) as predictors.

## Robustness: demographic match

Pre and post samples are different people, so a pre/post difference could
partly reflect who was recruited in each round. Possible robustness check:
compare rounds on demographically matched samples (or reweight one round to
the other's demographics). Not yet decided which variables to match on.
