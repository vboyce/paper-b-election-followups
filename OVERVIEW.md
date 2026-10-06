# Overview: the 2020 and 2024 election studies

Two unpublished follow-ups to von der Malsburg et al. (2020, *Psychological
Science*), which tracked pronoun use for the future US president around the
2016 election (and the UK prime minister in 2017). Both follow-ups ask the
same question with a female candidate who could win: does the bias against
*she* for a future office-holder track people's expectations about who will
win, and does it change once the outcome is known?

This file is a summary. `METHODS-SUMMARY.md` has the sourced detail,
`DATA.md` describes the data tables, and `OPEN-QUESTIONS.md` lists what is
still unknown.

## The two studies side by side

| | 2020 "Madame Vice President" (MVP) | 2024 "mmepr24" |
|---|---|---|
| Female candidate | Kamala Harris, for **vice president** (vs. Mike Pence) | Kamala Harris, for **president** (vs. Donald Trump) |
| Outcome | Harris won | Trump won |
| Collection | Pre: Oct 30 – Nov 2(3), 2020. Post: Nov 7 – 10, 2020 (from the race call) | Pre: Oct 31, 2024. Post: Nov 8 – 11, 2024 |
| Platform | MTurk; Ibex | Prolific; jsPsych + proliferate |
| Design | Between participants: each session does **one** critical trial of one task, plus the event-expectation sliders, in a random order | Same |
| Tasks | Cloze (production), A-Maze, SPR, and a **mazerace** control (race adjective instead of pronoun) | Cloze, A-Maze, SPR |
| Critical items | 12 new VP sentences; Maze/SPR trials are context + two sentences, pronoun pair from he-he, he-she, she-he, she-she, they-they | 10 sentences from the 2016 president items; same pair structure |
| Event expectation | Three sliders (Dem, Rep, someone else). Random half asked about VP (Harris/Pence), half about president (Biden/Trump) | Three sliders (Harris, Trump, other), president only |
| Other measures | Recall (who does the writer think will win?), one comprehension question, demographics incl. US residence/citizenship, election preference; post round: "aware the race was called?" | Recall, one comprehension question, demographics incl. US residence/citizenship, election preference |
| Screening applied originally | Native English, repeat sessions, RT bounds (not residence/citizenship) | Residence, citizenship, native English, duplicates, comprehension, Maze errors |
| Task-first : event-first | about 2 : 1 | about 2 : 1 (copied from 2020) |

The biggest cross-study differences are the office (VP vs. president), the
outcome (the female candidate won in 2020 and lost in 2024), the platform,
the item sets (not shared), and exclusion practice. The table at the end of
`METHODS-SUMMARY.md` lists every difference with sources.

## Data at a glance

Sessions per task (all sessions / kept by the original pipeline's rules for
that task):

| Study | Task | Pre | Post |
|---|---|---|---|
| 2020 | cloze | 962 / 462 | 870 / 172 |
| 2020 | maze | 1,173 / 339 | 1,234 / 136 |
| 2020 | mazerace | 1,136 / 356 | 1,272 / 142 |
| 2020 | spr | 1,377 / 448 | 1,167 / 135 |
| 2024 | cloze | 495 / 485 | 514 / 497 |
| 2024 | maze | 297 / 244 | 283 / 235 |
| 2024 | spr | 498 / 447 | 491 / 439 |

2020's original exclusions removed most sessions: mainly repeat sessions
(MTurk workers retaking the study through reposted HITs; post-election
also excluded everyone who took part pre-election), then too-fast RTs.
The 2020 README explains why. The 2024 SPR numbers are before the original's word-level RT
window, which removed a few more sessions (445 pre / 432 post).

Event expectations exist for nearly every session (2020: 9,162 of 9,191 with
usable sliders; 2024: 2,575 of 2,578).

## What was planned at the time

From the planning emails and documents (private notes in
`planning-records/PLANS-SUMMARY.md`, not part of the public repo):

- **Neither study was preregistered**, and neither had a written analysis
  plan before its data came in. `OPEN-QUESTIONS.md` items 1–2 list what was
  searched.
- **2020, before data:** Roger's proposal email (Aug 2020) and a
  pilot-based power analysis. The project document lists research
  questions (do cloze completions and reading times track event
  expectations; does language track the change in expectations; secondary:
  VP vs. president wording, Maze vs. SPR, whether the expectation task
  affects the linguistic tasks), but it was edited until after collection,
  so it can't be shown that the list predates the data. A within-participant link between expectation
  and pronoun behaviour was a stated reason for pairing the tasks, after a
  reviewer of the 2016 paper asked for it.
- **2020, after data:** a joint pre/post analysis (Bayesian mixed models of
  Maze RT at the pronoun by round × pronoun; cloze *she* by round), a
  within-participant analysis, and two talks (UPenn LingLunch, CUNY 2021).
  Exclusion rules were settled during and after collection.
- **2024, before data:** design and logistics (tasks, items, sample sizes
  estimated from the 2020 error bars, Prolific settings), and email
  discussion of what the study could ask (e.g. whether the bias against
  *she* has shrunk since 2016). No written predictions, analyses or
  exclusion criteria.
- **2024, after data:** exploratory linear models of residualized RT at the
  pronoun with pre/post contrasts, cloze proportion tests, and an HSP 2025
  abstract and poster. A comparison with 2016 became the headline there,
  although before data the collaborators had expected that comparison to be
  hard to interpret.

## Decisions for a forward analysis plan

The processed data deliberately leave these open (see `DATA.md`):

1. **Which comparisons.** Pre vs. post within each study; 2020 vs. 2024 (VP
   vs. president, win vs. loss); either vs. 2016; within-participant
   expectation × pronoun behaviour.
2. **Exclusions.** Original rules (very different between studies), or one
   shared set built from the common columns (e.g. US residence/citizenship,
   native English, comprehension, Maze accuracy) applied to both.
3. **RTs.** Window, transformation, residualization (2024's original
   residualized log RT; 2020's used raw RT), spillover region for SPR, and
   whether to use Maze RTs after errors.
4. **Cloze coding.** First reference (`cloze_code`) vs. any mention
   (`has_*`), and whether names and generic NPs count as non-pronoun
   responses or are dropped.
5. **Design factors.** Task order (2 : 1, and order effects were seen),
   2020's VP vs. president slider wording, and pronoun 2 (match/mismatch
   with pronoun 1).
6. **Models.** One model class per outcome for both studies (the code
   review recommended mixed models with explicit interaction terms), and
   whether to run them in brms (needs the cluster).
