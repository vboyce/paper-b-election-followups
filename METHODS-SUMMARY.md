# Methods summary: 2020 MVP and 2024 mmepr24 election experiments

Internal reference document. **This is not paper prose.** It exists so the researcher can check each claim against its source. Every claim has a citation.

## Citation conventions

- Paths are relative to `/home/vboyce/Research/backlog/paper-b-election-followups/` unless they start with `/`.
- `file:N` means line N and `file:N-M` means lines N to M.
- **(computed)** marks a number I calculated from a data file. These numbers are not stated anywhere in the sources. The "How this was compiled" section describes how each was computed.
- **(inferred from …)** marks a conclusion I drew rather than one a source states.
- `MP-git <hash>` cites a commit message in the git history of the full clone at `/home/vboyce/Research/MadamePresident`, read with `git log --format='%h %ad %s'`. I read commit messages only. I did not read diffs of any file that contains AWS keys.

## How this was compiled

**Read in full or nearly in full:**

- **2020 Ibex code.** Pre-election `items.js`, `README.md`, `Makefile` and `tsv2json.R` (`2020-madame-vice-president/pre-election-round/pre-election-round-ibex/`). The other Ibex files were not read in full, but `stimuli.tsv`, `stimuli_mazerace.tsv`, `Form.js`, `DashedSentence.js`, `Maze.js` and `Slider.js` were diffed between rounds. `Maze.js` was grepped for its error-handling and "redo" logic.
- **Post-election Ibex diff.** I diffed every shared file against the pre-election copy. Only `items.js` differs, by one line.
- **2020 pre-processing.** Both rounds' `pre-processing.R` (pre read fully, post diffed against pre).
- **2020 per-round analysis output.**
  - The participant-count tables in both rounds' `data-analysis.org` and `data-analysis.md`.
  - The first ~660 lines of the pre-election `.org`.
  - The rest of the pre-election `.org` and the post-election `.org` were only skimmed.
- **2020 joint analysis.** In `pre-post-election-joint-analysis/`: the setup and SPR/Maze chunks of `data-analysis.Rmd`, the outputs of `data-analysis.md`, and the first 60 lines plus the model chunk of `within-participant-analysis/analysis.Rmd`.
- **Other 2020 files.**
  - `event-expectation-component-ibex/experiment_script/README.md`, and a diff of its `items.js` against the pre-election `items.js`.
  - The head of `pre_maze.txt` and `post-maze.txt`.
  - The power-analysis chunk of `pilot-02/data-analysis/power-analysis.Rmd`.
- **2020 talks.**
  - Slide text extracted with a small Python zip/XML script from `talks/U_of_P_LingLunch/LingLunch presentation.pptx` (70 slides) and `talks/CUNY 2021/CUNY 2021.pptx` (24 slides).
  - `pdftotext` of `talks/CUNY 2021/CUNY 2021.pdf`.
  - A heading/filter grep of `talks/U_of_P_LingLunch/graphs_and_stats.Rmd`.
  - Speaker notes were **not** extracted.
- **2020 MTurk materials** (`private/2020-mturk/`):
  - All `.py` and `.sh` scripts. Credential lines were filtered out on display, and none contained a key: `grep` for `AKIA` and secret-key patterns found nothing.
  - **Aggregate facts were computed** from `create_HIT_log.txt` (Python) and `mturk_HIT_results.tsv` (R/tidyverse). The scripts printed only counts, ranges and quantiles, never IDs. They lived in the session scratchpad and are not saved in any repo.
  - Line counts only for `assignments-to-be-rejected*.txt`.
- **2020 raw Ibex logs.** `paper-b/2020/raw/{pre,post}_election_ibex_rows.csv.gz` (these numbers were first computed from the full logs with comment lines, `*_election_results.txt`, replaced on 2026-10-06 by these files, whose data rows are byte-identical), used for computed session counts, condition counts and items-per-session counts (`grep`/`awk`).
- **paper-b 2020 prep.** `paper-b/README.md`, `paper-b/2020/README.md` and all of `paper-b/2020/prep/*.R`, except `deidentify_raw_logs.R`, which was not read.
- **MadamePresident clone.** Git commit messages only, for the pre-election HIT script and the `items.js` history, plus one non-secret diff of the post-election `items.js` (commit `096ff70`).
- **2024 experiment code.** `2024-mmepr24/experiment/src/` files `experiment.js`, `custom_helper.js`, `instructions.js`, `cloze_stim.js` and `comp_q.js` (all fully), plus the head of `maze_stim.js` and targeted greps of `maze.js` and `spr.js`. Also `experiment/notes.md`.
- **2024 analysis.**
  - `analysis/pre-election-process.Rmd` (fully) and `post-election-process.Rmd` (diffed against pre).
  - Targeted sections of `analysis/post-election-exploratory.Rmd`.
  - `pdftotext` of `analysis/{pre,post}-election-process.pdf` and `post-election-exploratory.pdf` (for printed counts).
  - `pdftotext` of every figure PDF in `output/HSP2025-abstract/` and `output/HSP2025-poster/`.
- **2024 data.**
  - **Computed** aggregates from `data/mme_{pre,post}_election-trials.csv` and `data/processed/{pre,post}_participants.csv`. No Submission IDs or Prolific IDs were printed.
  - `paper-b/2024/README.md`, both driver scripts, and the header comment and exclusion block of `paper-b/2024/prep/shared_prep_functions.R`.
- **Context.** `STATUS.md`, sections 1, 2 and 4 of `pipelines-and-code-review.Rmd`, and the last two sections of `2020-2024-prep-pipeline-summary.md`.

**Not read:**

- The 2020 pilots' data and analyses, except the power-analysis output.
- `demographics-analysis/`.
- `graphs_and_stats.md` and the knitted outputs of the joint analysis beyond the count lines.
- Talk speaker notes.
- `MadamePresident/README.org` and `manuscript/`.
- `Form.js`, `Slider.js`, `two-sliders.js`, `DashedSentence.js` and `MazeSeparator.js` in full.
- 2024 `slider.js`, `cloze.js`, `maze_helper.js`, `spr_helper.js` and `deploy/`.
- `pre-election-exploratory.Rmd`.
- `paper-b/2020/raw/mturk_session_linkage.csv`: only its header row and pseudonymity pattern were checked when this summary was compiled (it was created in parallel; see `paper-b/2020/README.md`).
- The HSP 2025 abstract and poster **text**. Only figure PDFs exist in `output/`, and no abstract or poster text file was found in the repo.

---

# Experiment 1: 2020 "Madame Vice President" (MVP)

## 1.1 Recruitment

### Platform and hosting

- **Platform.** Amazon Mechanical Turk. HITs were created with boto3 `create_hit` in `us-east-1`, against the production endpoint; the sandbox line is commented out (`private/2020-mturk/pre-election-round/create_HIT.py:2-9,75`).
- **How the experiment was reached.** The HIT is an `HTMLQuestion` containing a link to an external Ibex experiment and a box for the completion code (`create_HIT.py:15-73`).
- **Experiment software.** Ibex, installed by cloning upstream Ibex. Local testing used `make` (`2020-madame-vice-president/pre-election-round/pre-election-round-ibex/Makefile:1-22`, `README.md:17-21`).

### HIT settings

These come from the HIT scripts as they now exist in `private/2020-mturk/`.

| Setting | Value | Source |
|---|---|---|
| Title | "Read a few sentences and answer some questions." | `create_HIT.py:76` |
| Description | "Takes 5 minutes!" | `create_HIT.py:77` |
| Reward | `'0.55'` (USD per assignment) | `create_HIT.py:79` |
| MaxAssignments (in the script) | 1 | `create_HIT.py:80` |
| LifetimeInSeconds | `24*60*60` (24 h) | `create_HIT.py:81` |
| AssignmentDurationInSeconds | `60*60` (1 h) | `create_HIT.py:82` |
| AutoApprovalDelay | 3 days | `create_HIT.py:83` |
| Qualifications | ≥50 HITs approved; Locale = US; Adult; ≥95% approval; Masters "Exists" | `create_HIT.py:85-105` |

- **Instructions on the HIT page:**
  - Red text: "Please participate only once in this survey. Participants who participate multiple times will not be approved." (`create_HIT.py:29`)
  - MIT consent paragraph (`create_HIT.py:30`).
- **UniqueTurker.** The HIT embeds a UniqueTurker script with `ut_id = "MadameVicePresident"` that hides the form when "the maximum number of HITs allowed" is reached (`create_HIT.py:62-69`). The actual per-worker limit is set on the UniqueTurker website, not in the code. **Not found in the repo.**

> **Warning:** these settings do **not** describe the pre-election round as run. `private/2020-mturk/pre-election-round/create_HIT.py` is byte-identical to `post-election-round-1/create_HIT_all_reqs.py` (`diff` gives no output). `MP-git 3a486f0` (2020-11-07, "moved mturk files into round-specific folders & split create_HIT.py into 3 files") suggests the pre-round copy was saved at the post-round split. The actual pre-round settings changed during collection; see the next subsection.

### Pre-election round: how HITs were actually posted

- **Launch cadence.** `create_HIT_log.txt` records 2,896 HIT launches. The first was at 2020-10-30 10:18:02-04:00 and the last at 2020-11-02 16:35:02-05:00. 2,869 of 2,895 gaps between launches were 1 minute **(computed)** (`private/2020-mturk/pre-election-round/create_HIT_log.txt`). This suggests one HIT per minute from a scheduled job (inferred from the cadence; no crontab was found). The wrapper script appends each launch to the log (`private/2020-mturk/pre-election-round/create_and_log_HIT.sh:1-5`).
- **Reward.** $0.55 on all 2,896 launches **(computed)** (same log).
- **MaxAssignments was never 1 in the pre round.** Values logged **(computed)** (same log):

  | From (log time) | MaxAssignments |
  |---|---|
  | 10-30 10:18 EDT | 5 |
  | 10-30 11:37 EDT | 9 |
  | 10-31 19:35 EDT | 2 |
  | 11-01 09:56 EST | 5 |
  | 11-01 17:32 EST | 9 |
  | 11-01 18:52 EST | 5 |
  | 11-01 19:40 EST | 2 |
  | 11-01 19:41 EST onward | 3 |

  Totals: 1,255 HITs × 3, 922 × 2, 500 × 9, 219 × 5.
- **Git commit messages agree:**
  - "started data collection" (`MP-git 63c0efb`, 2020-10-30 10:20 EDT)
  - "switched to 9 assignments per HIT (up from 5) to make sure we finish in time" (`MP-git fdf4509`, 10-30 11:36)
  - "changed number of assignments per HIT from 9 to 2" (`MP-git dcdd89f`, 10-31 19:40)
  - "changed create_HIT.py to 5 assignments per HIT" (`MP-git 342af05`, 11-01 09:55)
- **Qualification requirements changed during the round.** The HIT-level requirements recorded per assignment in `mturk_HIT_results.tsv` (4,699 assignments) **(computed)** (`private/2020-mturk/pre-election-round/mturk_HIT_results.tsv`):

  | Requirements (US locale / Master / %approved / #approved) | Assignments | Timing (ET) |
  |---|---|---|
  | none / none / 0 / 0 | 2,518 | 2,514 on 10-30, plus 4 submitted 11-09 (see open questions) |
  | US / no / 90 / 50 | 477 | 10-30 17:23 to 10-31 05:36 |
  | US / no / 95 / 100 | 1 | 10-30 |
  | US / no / 95 / 50 | 1,270 | mostly 11-01 (1,240) |
  | US / Master / 95 / 50 | 433 | 10-30 to 11-03 |

  So about 54% of pre-round MTurk assignments came from HITs with **no US-locale or approval requirement**, all on the first day (2020-10-30). Commit messages: "added worker qualification requirement" (`MP-git 549b659`, 10-30 17:40 EDT) and "added Master Worker requirement" (`MP-git e832c3d`, 10-30 18:18 EDT).
- **Masters and non-Masters HITs coexisted** after 10-30 (computed counts by date). That means the Masters line was toggled more than once. No commit message documents this (inferred from the TSV).
- **First-day split in the analysis.** The original analysis splits counts at "before Friday 6pm" (2020-10-30 18:00) (`2020-madame-vice-president/pre-election-round/pre-election-round-data/data-analysis/data-analysis.org:313-351`; `.md:279-296`).

### Post-election round: how HITs were posted

- **Three HIT variants per minute.** Each run of `create_and_log_HIT.sh` launches three HITs: all requirements, no Masters requirement, and no requirements at all (`private/2020-mturk/post-election-round-1/create_and_log_HIT.sh:5-10`).
- **How the variants differ:**
  - `create_HIT_no_master_req.py` comments out only the Masters requirement (`create_HIT_no_master_req.py:85-105`; diff vs `create_HIT_all_reqs.py`).
  - `create_HIT_no_reqs.py` comments out the whole `QualificationRequirements` list, **including the US locale and adult requirements** (`create_HIT_no_reqs.py:85-105`).
- **Launch log** **(computed)** (`private/2020-mturk/post-election-round-1/create_HIT_log.txt`):
  - 7,176 launches between 2020-11-07 13:14:03-05:00 and 2020-11-09 22:42:04-05:00.
  - MaxAssignments = 1 and reward $0.55 on every launch.
  - 2,390 launches of each labeled variant, plus 6 unlabeled.
  - Gaps between batches were 1 minute (2,386 cases), with 3 HITs per batch.
- **Assignments by variant** **(computed)** (`private/2020-mturk/post-election-round-1/mturk_HIT_results.tsv`):

  | Variant | Assignments | Distinct workers |
  |---|---|---|
  | No requirements | 2,449 | 846 |
  | US, no Masters | 2,449 | 593 |
  | US + Masters | 149 | 123 |

### Repeat participation and rejection

- **Repeat assignments were flagged for rejection.** `get_mturk_info.py` (post) sorts assignments by SubmitTime and writes the AssignmentId of every non-first assignment by a worker to `assignments-to-be-rejected.txt` (`private/2020-mturk/post-election-round-1/get_mturk_info.py:126-151`).
  - That file has 3,590 lines; `assignments-to-be-rejected-by-5pm.txt` has 214 (`wc -l`).
- **Rejection script.** `reject-assignments.py` reads the `-by-5pm` file and rejects assignments still in "Submitted" status with feedback "Our records indicate that you had previously participated in this HIT…" (`private/2020-mturk/post-election-round-1/reject-assignments.py:13-30`).
- Whether rejections were actually run, and how many, is **not found**: there is no rejection log in `private/2020-mturk/`.
- **No rejection script exists for the pre round** (`private/2020-mturk/pre-election-round/` file listing).

### Collection dates (time zones stated)

| Round | Source | First | Last |
|---|---|---|---|
| Pre | Ibex result-receipt timestamps (epoch → UTC) **(computed)** `paper-b/2020/raw/pre_election_ibex_rows.csv.gz` | 2020-10-30 14:22 UTC (10:22 EDT) | 2020-11-03 21:57 UTC (16:57 EST, election day) |
| Pre | MTurk SubmitTime **(computed)** `private/…/pre-election-round/mturk_HIT_results.tsv` | 2020-10-30 10:29 EDT | 2020-11-03 16:57 EST, excluding 7 stray post-round rows (open questions) |
| Pre | `get_mturk_info.py` retrieval window | 2020-10-30 10:00 (UTC−4) | 2020-11-02 16:40 (UTC−5) (`private/…/pre-election-round/get_mturk_info.py:25-30`) |
| Post | Ibex timestamps **(computed)** `paper-b/2020/raw/post_election_ibex_rows.csv.gz` | 2020-11-07 18:24 UTC (13:24 EST) | 2020-11-10 15:14 UTC (10:14 EST) |
| Post | MTurk SubmitTime **(computed)** | 2020-11-07 13:25 EST | 2020-11-10 08:23 EST |
| Post | `get_mturk_info.py` window | 2020-11-07 13:00 (UTC−5) | 2020-11-10 13:00 (UTC−5) (`private/…/post-election-round-1/get_mturk_info.py:22-27`) |

The pre-processing scripts convert Ibex times with `tz = "UTC"` (`2020-madame-vice-president/pre-election-round/pre-election-round-data/data-analysis/pre-processing.R:259-262`).

### Intended vs. actual N

- **Intended N: not found as an explicit target.**
  - Looked in: `items.js` (the condition weights cite an external Google Sheet that is not in the repo; `items.js:17-19`), the `.org` analyses, the talks and the HIT scripts.
  - The closest thing is a pilot power calculation: `power.t.test(delta = 0.17074/0.6378, power = 0.8)` gives n ≈ 220 per group (`2020-madame-vice-president/pilot-02/data-analysis/power-analysis.Rmd:110-114`; output `power-analysis.md:958-965`). What this n was meant to apply to is not stated.
  - The commit message "to make sure we finish in time" (`MP-git fdf4509`) implies a deadline (inferred: election day).
- **Raw Ibex sessions:** pre **4,648**, post **4,543** (computed as unique time + participant-hash pairs of `,code,` rows in `paper-b/2020/raw/*_election_ibex_rows.csv.gz`). This matches the originals' per-condition totals (`…/post-election-round-1/data/data-analysis/data-analysis.md:188-197` gives 4,543) and `paper-b/2020/README.md:93-96`.
- **MTurk assignments** **(computed)** (`mturk_HIT_results.tsv`, each round):
  - Pre: 4,699 assignments, 925 distinct HITs with ≥1 assignment, **2,350 distinct workers**.
  - Post: 5,047 assignments in 5,047 HITs, **1,457 distinct workers**.
- **Repeat workers** **(computed)** (same files):
  - Pre: maximum **175** assignments by one worker; 355 workers did more than one.
  - Post: maximum **291**; 352 workers did more than one.
  - 507 post-round workers also appear in the pre-round TSV, accounting for 2,427 post-round assignments.
  - (The joint analysis prints `max(xtabs(~WorkerId, d_pre_election))` = 206, but that counts *data rows*, not sessions: `pre-post-election-joint-analysis/data-analysis.md:107-110`.)
- **Kept after the original exclusions:** pre **1,607**, post **589**, total **2,196** (pre: `…/pre-election-round-data/data-analysis/data-analysis.md:185-198`; post: `…/post-election-round-1/data/data-analysis/data-analysis.md:188-197`; totals summed by me). The talks state "2196 AMT participants" (LingLunch slide 15) and "2 experiments (N = 2196)" (CUNY 2021 slide 12). The per-condition numbers on LingLunch slide 15 (410, 306, 388, 338, 225, 171, 197, 161) equal the sum of pre and post kept counts per condition (e.g., cloze-event 299 + 111 = 410).

## 1.2 Design

### Conditions and how they were assigned

There are eight between-participant conditions, each a task order × task: `cloze-event`, `event-cloze`, `event-maze`, `event-mazerace`, `event-spr`, `maze-event`, `mazerace-event`, `spr-event` (`items.js:20-54`).

- **Assignment.** Each participant is assigned client-side by `Math.random()` drawing from a 102-slot array with weights 12 : 6 : 8 : 8 : 12 : 16 : 16 : 24, in the order above (`items.js:17-54`). The weights are said to match proportions in an external Google Sheet (`items.js:17-19`), which is not in the repo.
- **Earlier design.** The shared event-expectation component used a uniform 1-of-8 draw instead (`event-expectation-component-ibex/experiment_script/items.js` vs the pre-round `items.js`, diff lines 18-28; also `pipelines-and-code-review.Rmd:70-72`).
- **Observed raw sessions per condition** **(computed)** (`paper-b/2020/raw/*_election_ibex_rows.csv.gz`):

  | Round | cloze-event | event-cloze | event-maze | event-mazerace | event-spr | maze-event | mazerace-event | spr-event |
  |---|---|---|---|---|---|---|---|---|
  | Pre | 619 | 343 | 395 | 380 | 445 | 778 | 756 | 932 |
  | Post | 543 | 327 | 445 | 391 | 397 | 789 | 881 | 770 |

  These match the original totals.

### Counterbalancing (between participants, random client-side)

- **`event_expectation_display_order`.** `dem_first` or `rep_first`, which controls whether the Democratic candidate is listed first (`items.js:115`, `118-124`).
  - Raw sessions: pre 2,306 dem_first / 2,342 rep_first; post 2,294 / 2,249 **(computed)**.
- **`event_expectation_vice`** (later renamed `asked_about_vp` in the analysis). `true` means the slider and preference questions ask about the **vice** president (Harris vs. Pence); `false` means president (Biden vs. Trump) (`items.js:116-124`; renamed at `pre-processing.R:30-32`).
  - Raw sessions: pre 2,321 true / 2,327 false; post 2,260 / 2,283 **(computed)**.
- Both values are logged through dummy `DashedSentence` items (`items.js:376-379`).
- **Note:** both lines use `Math.round(Math.random()) < 0.5`, which is a 50/50 draw (`items.js:115-116`).

### Sentence-level manipulation (within the single critical trial)

- **Pronoun pairs.** For SPR and Maze, each trial is the context sentence plus two different critical sentences (i ≠ j). There are five pronoun combinations, he-he, he-she, she-he, she-she and they-they (`hh, hs, sh, ss, tt`), so 12 × 11 × 5 = 660 items per task (`items.js:259-314`; count inferred from the loops).
- **Mazerace.** Each trial is the context sentence plus one race sentence with four adjective variants: black, white, Black, White (`items.js:321-351`).
- **One critical item per participant.** All critical items carry Ibex group `1` (e.g. `[["maze", 1], …]`), and the sequence includes `setcounter` (`items.js:83`, `247`, `300-310`, `346-349`). In the data, every session has exactly **one** cloze, maze, SPR or mazerace item **(computed)**: all 962 / 1,173 / 1,377 / 1,136 pre sessions and 870 / 1,234 / 1,167 / 1,272 post sessions with that task have exactly one item number. That item is presumably chosen by Ibex's Latin-square counter rather than at random (inferred from Ibex group semantics; not verified in Ibex source). The log header reads "Design number was non-random = 3" (`paper-b/2020/raw/pre_election_ibex_rows.csv.gz`, comment header).

## 1.3 Materials

### Critical stimuli

- **Source files.** `stimuli.tsv` has 12 items and `stimuli_mazerace.tsv` has 10 rows. Both are identical between rounds (`diff -q`; `paper-b/2020/README.md:52-53`). They are converted to JSON with `tsv2json.R` and pasted into `items.js` (`items.js:97-104`; `tsv2json.R:10-14`).
- **Context sentence (all items).** "January 20, 2021, is the start of the next presidential and vice-presidential term in the United States." (`stimuli.tsv:2`)
- **Example critical sentence.** "Because the vice president breaks ties in the US Senate, if there is a 50–50 party split in 2021 then he|she|they may cast many tie-breaking votes." (`stimuli.tsv:2`)
- **Pronoun forms.** Some items use `his|her|their` or `him|her|them` instead of `he|she|they` (`stimuli.tsv:4,6,7,9`; also `pre-processing.R:187-196`).
- **All 12 sentences** are listed on LingLunch slides 63-64 and in `items.js:104`.

### Maze distractors

- **Source.** The distractors are fixed strings in `ContextAlternatives` and `SentenceAlternatives`, starting with "x-x-x" (`stimuli.tsv:2-13`; `items.js:104`). The same distractor string is used for every pronoun variant of a sentence (`items.js:297`).
- **Generation method.** The talk calls the task "A-maze measure of decision times between correct word and high-surprisal foil" and cites Boyce, Futrell & Levy (2020, JML) (LingLunch slides 15, 24). The generation itself is not documented in the repo (inferred: A-maze auto-generation).
- **Manual edits.** The `Notes` column records them, e.g. "Replaced critical word alternative 'dog' with 'walks'" (`stimuli.tsv:2`, Notes column). `event-expectation-component-ibex/post-maze.txt` still has "dog" (`post-maze.txt:1`).
- **Redo mode.** Maze runs with `redo: true` (`items.js:14`). After a wrong choice the participant sees "Incorrect. Please try again." and must choose the correct word (`Maze.js:111-112`).

### Mazerace control

- **Sentence frames.** There are two frames:
  - "The vice president will be black|white|Black|White and this is likely to be mentioned in discussions of US race relations."
  - "The vice president will be a black|white|Black|White person and …"
- Each frame appears in 5 rows with different distractor strings (`stimuli_mazerace.tsv:2-11`; `items.js:99`; LingLunch slide 65).
- **Comprehension question.** One question: "Is the race of the vice president going to be relevant in discussions of race relations?" (`items.js:99`, `346-349`).

### Cloze prompts

- **What participants see.** The context sentence plus the critical sentence truncated just before the pronoun slot. The regex removes the `x|y|z` triplet and everything after it (`items.js:243-245`).
- **Instruction text.** "Below is a fragment of a sentence. Please guess how the sentence continued and use the text field to enter the complete rest of the sentence." (`items.js:245`)
- Example as displayed: LingLunch slide 20 and CUNY slide 12.

### Comprehension questions

- **Two yes/no questions per SPR or Maze trial,** one per critical sentence (`items.js:300-310`). The default answer options are yes/no (`items.js:9-13`).
- Example: "Will the vice president hold the nuclear launch codes?" (`stimuli.tsv:4`).
- The TSV `Answer` column is **not** passed to the Question controller (`items.js:300-310`; `tsv2json.R:11` keeps it but `items.js` never uses `.Answer`). Answers are therefore not scored at run time, and the original exclusions do not use them (inferred from `items.js` and `pre-processing.R:336-360`).

### Event expectation (sliders)

- **Heading.** "Who do you think will be the US ${vice }president in February 2021?" (`items.js:186`)
- **Instruction.** "Use the sliders below to indicate each candidate's chance of winning the election." (`items.js:187`)
- **Three sliders.**
  - Rows: candidate 1, candidate 2 and "Someone else".
  - Each runs 0-100, starts at 0 and is ticked 0/25/50/75/100% (`items.js:189-226`).
  - Candidates are Harris/Pence (VP version) or Biden/Trump (president version), ordered by `display_order` (`items.js:118-124`).
- **Normalization.** The analysis normalizes each slider by the sum of all three (`pre-processing.R:126-141`).
- **The wording was the same in the post-election round**, i.e. after the race was called (`diff` of `items.js` shows only the awareness line).

### Recall

- **Who sees it.** Only in conditions where SPR, Maze or Mazerace is the second task (`event-spr`, `event-maze`, `event-mazerace`) (`items.js:358`, `93`).
- **Question.** "Think about the writer of the sentences you read on the previous page. Who does the writer believe will be the US vice president in February 2021?"
- **Options.** Harris, Pence, "Writer is unsure", "I don't remember"; the Harris/Pence order follows `display_order` (`items.js:359-364`).

### Questionnaire

- **Preface.** "Now please answer a couple of questions about your background…" (`items.js:385`).
- **News exposure**, asked **before** the first task: "How often do you hear or read about the presidential race for the White House?" Options: daily / weekly / monthly / less than monthly / never (`items.js:386`; sequence position `items.js:86`).
- **Questions asked after the tasks:**
  - Preference: "Who would you *prefer* to win the upcoming US [vice-]presidential election?" Options: candidate 1, candidate 2, "I don't care", "I'd rather not say" (`items.js:387-389`). The word "upcoming" is unchanged in the post round.
  - Age, as free text with 2 characters (`items.js:390`).
  - Gender: Female / Male / Non-binary / Other / Rather not say (`items.js:391`).
  - Home state, a dropdown including territories and "[other]" (`items.js:392`).
  - Education, 7 levels (`items.js:393`).
  - Political affiliation: Democrat / Republican / Independent / Other / None / Rather not say (`items.js:394`).
  - US citizen, native English speaker, and currently residing in the US, each yes/no (`items.js:395-397`).
- **Order.** These items form one block, displayed with `anyOf("questionnaire")` (`items.js:95`). Whether that randomizes their order is not verified.

### Bot screening

- **Wording.** "To verify that you are not a robot, please answer the following question. Jackie is considering several options for dinner: chicken, pasta, steak. She doesn't like the first and the last option because she had both recently. Please type her remaining option in the textbox below, using no lower-case letters:"
- **Validation.** Only the exact string `PASTA` is accepted. Anything else shows "Wrong answer. Please try again." (`items.js:374`)
- **Effect.** Participants cannot continue until they answer correctly, so this screens at entry and produces no exclusions (`items.js:85` comment "Form that proceeds on correct answer only").

### Post-election-only awareness question

- **Wording.** "Are you aware that major news outlets have officially projected that the Biden-Harris ticket has defeated the Trump-Pence ticket?" A yes/no question placed in the questionnaire block (`2020-madame-vice-president/post-election-round-1/ibex/items.js:398`).
- **Coverage.** All 4,543 raw post sessions answered it: 4,303 "yes" and 240 "no" **(computed)** (`paper-b/2020/raw/post_election_ibex_rows.csv.gz`).
- **Timing.** The line was committed to git at 2020-11-08 09:48 EST (`MP-git 096ff70`), after collection began (11-07 13:14 EST). Since all sessions, including the first one (11-07 18:24 UTC), contain the question, it was live from the start and the commit came later (inferred from data plus git).

### Consent and completion

- **Consent screen.** It names the MIT Computational Psycholinguistics Laboratory; lists Chelsea Ajunwa, Veronica Boyce, Roger Levy, Till Poppels and Titus von der Malsburg as running the study; and says "By continuing you give your consent to participate" (`items.js:373`).
- **Completion code.** A random integer from 0 to 999,999, shown at the end (`items.js:2-4`). Because codes can collide, the original pipeline matched Ibex sessions to MTurk records on code plus submit time rounded to 2 h (`pre-processing.R:276-315`).

## 1.4 Procedure

**Session order** (`items.js:78-95`):

1. Welcome/consent
2. Bot screening
3. News question
4. Task 1 instructions
5. Task 1 practice
6. Task 1 critical item
7. Task 2 instructions
8. Task 2 practice
9. Task 2 critical item
10. Recall (event-first SPR/Maze/Mazerace conditions only)
11. Questionnaire instructions
12. Questionnaire

**Instructions and practice:**

- **Maze and Mazerace** use the same instructions and practice (`items.js:66-74`).
  - Instructions: place fingers on 'e' and 'i', choose the word that continues the sentence, "as quickly as you can, but without making too many errors" (`items.js:399`).
  - Practice: one three-sentence item, "This sentence is for practice. Here is another practice item. Now the actual task will begin." (`items.js:400`)
- **SPR.**
  - Instructions: press Space word by word; read carefully because questions follow (`items.js:401`).
  - Practice: "Press space in order to reveal the next word.", followed by "Did the sentence you just read contain the word 'reveal'?" (`items.js:402`).
  - Context and the two sentences are separated by blank lines (`"\n\n"`) in SPR and by spaces in Maze (`items.js:287-291`).
  - The modified `DashedSentence.js` "removed preview of the spaces between words" (`pre-election-round-ibex/README.md:12-15`).
- **Cloze and event tasks.** The sequence asks for `cloze-instructions`, `cloze-practice`, `event-instructions` and `event-practice` (`items.js:61-64`, `87-92`), but no items with those labels are defined in `items.js`. These tasks therefore had **no separate instruction or practice screens**; the instructions are inline on the item itself (inferred from `items.js`).

**Approximate duration:**

- The HIT advertised "Takes 5 minutes!" (`create_HIT.py:77`).
- MTurk accept-to-submit time **(computed)** (`mturk_HIT_results.tsv`):
  - Pre: median 7.45 min, IQR 3.38-22.23, mean 14.44.
  - Post: median 8.28 min, IQR 3.55-18.91.
  - This includes time spent outside the experiment, such as pasting the code.

## 1.5 Exclusions

### Original pipeline: pre-election round

Source: `2020-madame-vice-president/pre-election-round/pre-election-round-data/data-analysis/pre-processing.R`. Exclusions are applied per participant ("sid") and only non-excluded participants are written to `clean-data.rds` (`:362-368`).

| Criterion | Code | Line |
|---|---|---|
| Not a native English speaker (`native != "yes"`) | `excl = ifelse(native == "yes", FALSE, TRUE)` | `:339` |
| Repeat submission from the same IP hash (any session after the first per md5) | `repeat.md5` | `:321-326`, `:340` |
| Repeat MTurk WorkerId within the round (any session after the first) | `repeat.WorkerId`, joined from `../../mturk/mturk_HIT_results.tsv` | `:294-315`, `:328-331`, `:341` |
| Any SPR word RT ≥ 10,000 ms or ≤ 180 ms (includes the practice item) | `spr_max_rt < 10000`, `spr_min_rt > 180` | `:343-350` |
| Any Maze word RT ≥ 10,000 ms or ≤ 180 ms (includes practice and mazerace) | `maze_max_rt`, `maze_min_rt` | `:351-352` |
| All three sliders left at 0 | `candidate_value_dem == 0 & … == 0` | `:353-357` |

Notes on how these are implemented:

- The comment at `:336` reads "Exclusion of trials with RTs < 180ms and RTs > 10000ms", but the code drops the **whole participant** if any single word is out of range (`:343-352`).
- Practice items are included in the RT check because the extraction regexes match `spr(-practice)?` and `maze(-practice|race)?` (`:66`, `:82`).
- **No** exclusion uses US residence, US citizenship, comprehension-question accuracy or Maze accuracy (`:336-360`).

### Original pipeline: post-election round

Source: `2020-madame-vice-president/post-election-round-1/data/data-analysis/pre-processing.R`. The criteria are the same as pre (native `:349`; md5 `:350`; WorkerId `:351`; RT `:360-363`; slider `:364-368`), **plus one more**:

- Anyone whose WorkerId appears anywhere in the pre-round `mturk_HIT_results.tsv` is excluded (`previousWorkerIds`, `:327-328`; flag `:341`; exclusion `:352`).

The joint analysis drops these participants again with `filter(! WorkerIdInPreviousRound)` (`pre-post-election-joint-analysis/data-analysis.Rmd:26-28`).

### Resulting counts (original `.md` outputs)

| Round | Raw | Kept | Excluded | Source |
|---|---|---|---|---|
| Pre | 4,648 | 1,607 | 3,041 | `…/pre-election-round-data/data-analysis/data-analysis.md:185-198` (sums by me) |
| Post | 4,543 | 589 | 3,954 | `…/post-election-round-1/data/data-analysis/data-analysis.md:188-197` |

### How paper-b's prep differs

Source: `paper-b/2020/prep/shared_prep_functions.R`, `paper-b/2020/README.md`.

*Updated 2026-10-05 after the 2020 prep rewrite; `paper-b/2020/README.md` ("Exclusions", "Deviations from the original") is the authoritative description.*

- **All sessions are kept.** Each criterion is a column on `processed/{pre,post}_sessions.csv.gz`. The `excl_*` columns are the original criteria; `excl_original_rule` combines them with corrections, and the `flag_*` columns are candidate robustness criteria.
- **WorkerId-based checks are now applied.** They use pseudonymous workers from `raw/mturk_session_linkage.csv`, which is built outside the repo by `private/2020-mturk/build_mturk_linkage.R`.
- **Original counts reproduced.** `excl_original_replication` reproduces the original counts exactly (pre 1,607, post 589; checked per condition by `prep/validate_against_original.R`). The corrected rule keeps 1,605 and 585.
- **Fix: Mazerace fan-out.** paper-b deduplicates the mazerace stimulus lookup by `sens` (see `build_stimulus_lookup()` in `shared_prep_functions.R`).

## 1.6 Planned and reported analyses (as they exist)

- **Per-round descriptive notebooks.** The `.org` and `.md` files contain:
  - Exclusion plots.
  - N by condition, by Masters requirement and by submission time.
  - Recall and event-expectation bar plots.
  - SPR RTs at the pronoun and the 4 following words.
  - Maze RT at pronoun 1 and pronoun 2, split by pronoun-2 × pronoun-1 type.
  - Mazerace RT.
  - Cloze response tables.

  Source: headings in `…/pre-election-round-data/data-analysis/data-analysis.org:23-1072`. The post `.org` adds awareness plots (`post …/data-analysis.org:549-637`).
- **Joint pre/post analysis** (Roger Levy, dated 6 Dec 2020) (`pre-post-election-joint-analysis/data-analysis.Rmd:1-5`):
  - Maze RT at pronoun 1 is modeled with `brm(maze_word_rt ~ NRound * Npro1_type + (… | sen1_number))`, with separate she-vs-they and she-vs-he subsets and per-round fits (`:244-266`). Pronoun 2 uses `lmer`/`brm` with Round × pro1 × pro2 (`:310-315`).
  - Cloze is modeled with `brm(shePronoun ~ NRound + (NRound | cloze_item), family = bernoulli)` (`:486-491`).
  - Mazerace uses `glm` on accuracy and `lm` on RT by Race × Capitalized (`:418-445`).
  - Event expectations: "**TODO:** statistical analysis" (`:163`).
  - Maze RTs are **not** filtered for accuracy. Redo mode means RT is the first-try RT (inferred from `Maze.js`; not verified).
- **Within-participant analysis** (Till Poppels, 2021-02-03). This is a regression of maze RT on each participant's own normalized Dem probability × pronoun (`brm(maze_word_rt ~ prob_dem_centered * Npro1_type + …)`). It is not a pre/post same-person analysis (`pre-post-election-joint-analysis/within-participant-analysis/analysis.Rmd:1-5`, `110-125`). The code review found its "he/she only" filter is a no-op because of a typo, `singular_they` (`pipelines-and-code-review.Rmd:105-112`).
- **Talks.**
  - The UPenn LingLunch talk is titled "Bias against 'she' pronouns can be rapidly overcome by changing event expectations" (`LingLunch presentation.pptx`, slide 1). It reports cloze she/he, A-maze RTs at the pronoun (pre vs. post), recall, mazerace and event expectations (slides 15-61, 65-70). Its figures are descriptive (`pipelines-and-code-review.Rmd:403-423`).
  - CUNY 2021 has the same title and N = 2196. It shows production and A-maze comprehension only, ending with "Stay tuned!" (`CUNY 2021.pptx`, slides 11-23).

## 1.7 Open questions and inconsistencies (2020)

1. **MaxAssignments.** The "known" claim that every HIT had MaxAssignments = 1 holds **only for the post round**. In the pre round, MaxAssignments was 5, 9, 2, 5, 9, 5, 2, then 3 (log and git). The `create_HIT.py` saved under `private/2020-mturk/pre-election-round/` is the post-round "all requirements" version, not the script used in the pre round.
2. **Pre-round qualifications.** About 54% of pre-round MTurk assignments (2,514 on 2020-10-30, before ~17:40 EDT) came from HITs with **no** locale or approval requirements. The original exclusions do not screen on US residence or citizenship. The questionnaire collects both (`items.js:395,397`), but they are never used for exclusion. Masters and non-Masters HITs alternated during the round without documentation.
3. **Post-round no-requirements variant.** One third of post HITs (2,449 assignments, 846 workers) had no US-locale requirement.
4. **Stray post-round rows in the pre-round TSV.** The pre-round `mturk_HIT_results.tsv` contains **7 assignments that also appear in the post-round TSV**: same AssignmentIds, submitted on 2020-11-09 ET **(computed)**.
   - Likely cause: `get_mturk_info.py` adds the first page of `list_hits()` without the time-window filter (`private/…/pre-election-round/get_mturk_info.py:34-35`), and the TSV was apparently regenerated after the post round started (inferred).
   - Effect: those workers would land in the post round's `previousWorkerIds` (`post pre-processing.R:327-328`) and be wrongly excluded. Not quantified.
5. **Pre-round end date.** The pre-round end is variously 2020-11-02 16:40 (`get_mturk_info.py` window), 11-02 16:35 (last HIT launch) or 11-03 16:57 EST (last Ibex result and MTurk submission; HITs had a 24 h lifetime). The user-supplied "late Oct–Nov 3" matches the data. Data collection started 10-30, not "late October" generally.
6. **Post-round end date.** The user-supplied range is "Nov 7–10". The data run from 11-07 13:24 EST to 11-10 10:14 EST (Ibex) or 08:23 EST (MTurk). The last HIT launch was 11-09 22:42 EST.
7. **Stale `.org` results.** Each `.org` contains several **stale** RESULTS tables for the same count query, with different totals:
   - Pre `.org:214-224`, `:374-385` and `:387-397`.
   - Post `.org:212-221` (total 1,227) and `:334-343` (total 4,424).

   The `.md` exports match the raw data (4,648 / 4,543). The captions "Exclusions only take into account native language requirement so far" are also stale (`pre .org:208`).
8. **Comment vs. code on RT exclusion.** The comment says RT exclusion is per trial (`pre-processing.R:336`); the code excludes the whole participant, and the RT check includes the practice items.
9. **Rejections.** Whether the post-round rejections were carried out is unknown: there is no log, the TSV only includes `Submitted` and `Approved` statuses (`get_mturk_info.py:76`), and the user's note did not say. There was no repeat-rejection procedure in the pre round.
10. **UniqueTurker.** The per-worker limit is not recorded. Given that one worker did 175 or 291 assignments, it evidently did not cap participation at 1 (inferred).
11. **Stimulus typos.** "Feburary" in item 11 (`stimuli.tsv:12`; LingLunch slide 64 shows "February"). Comprehension question 2 is missing a verb: "Will the speaker of the House of Representatives the first in line…" (`stimuli.tsv:3`).
12. **Wording not updated after the election.** The event-expectation and preference wording ("will be … in February 2021", "upcoming … election") was not changed for the post round.
13. **Cloze and event tasks** have no instruction or practice screens (`items.js:61-64` refer to labels that are not defined).
14. **Linkage file.** `paper-b/2020/raw/mturk_session_linkage.csv` was created on 2026-10-05 by `private/2020-mturk/build_mturk_linkage.R` to close the +318 gap; see `paper-b/2020/README.md`.

---

# Experiment 2: 2024 "mmepr24"

## 2.1 Recruitment

### Platform

The study ran on Prolific, using the "proliferate" back-end for data submission. Evidence:

- `proliferate.js` posts to `proliferate.alps.science` (`2024-mmepr24/experiment/src/proliferate.js:3-6`).
- The consent text mentions "the demographic information you provided to Prolific" (`experiment/src/instructions.js:1-8`).
- The debrief says "Press continue to be redirected to Prolific" (`instructions.js:358-360`).

**Hosting.** The bundled `deploy/` folder is published to GitHub Pages without being rebuilt (`.github/workflows/static.yml`; `pipelines-and-code-review.Rmd:182`).

### Dates (from Prolific "Started at" and "Completed at", converted to America/New_York)

| Wave | First start | Last completion | Source |
|---|---|---|---|
| Pre | 2024-10-31 12:14 EDT | 2024-10-31 20:29 EDT (single day) | **(computed)** `2024-mmepr24/data/processed/pre_participants.csv` |
| Post | 2024-11-08 11:45 EST | 2024-11-11 15:02 EST | **(computed)** `data/processed/post_participants.csv` |

- The process notebook also plots a completion timeline in America/New_York (`analysis/pre-election-process.Rmd:331-359`).
- Election day was 2024-11-05. That date is general knowledge and is not stated in the repo.

### Payment, eligibility and intended N

- **Payment, Prolific screeners and intended N: not found.**
  - Looked in: `experiment/` (all `src`, `notes.md`), `analysis/*.Rmd`, `README.md` (which is just "# mmepr24"), `.gitignore`, the output PDFs, and `paper-b/2024/`.
  - The Prolific export and study settings are deliberately untracked (`.gitignore`: `data/prolific_*.csv`, `data/prolific_*.pdf`).
- **Observed eligibility pattern.** All approved participants have Prolific "Country of residence" = United States: 1,279/1,279 pre, and 1,272/1,273 post (the other is CONSENT_REVOKED) **(computed)**. This suggests a US-residence screener (inferred).
- **Device restriction.** The in-experiment browser check excludes mobile devices with "You must use a laptop/desktop computer…" (`experiment/src/experiment.js:88-100`).
  - The minimum-width parameter is misspelled `minumum_width` (`experiment.js:91`), so presumably only the height limit (700) is enforced (inferred; jsPsych parameter name not verified).
  - Mobile check results: 1 pre and 6 post sessions flagged mobile **(computed)**.
- **No bot or attention screen** like 2020's bot_screening. None was found in `experiment.js:311-386`.

### Actual N (raw)

| | Pre | Post | Source |
|---|---|---|---|
| Distinct proliferate `workerid`s in trial export | 1,325 | 1,345 | **(computed)** `data/mme_*_election-trials.csv` |
| … with an assigned condition | 1,288 | 1,286 | **(computed)** same |
| … reaching the final survey | 1,283 | 1,281 | **(computed)** same |
| Rows in `*_participants.csv` (matched to the Prolific export; Status) | 1,279 (all APPROVED) | 1,273 (1,272 APPROVED, 1 RETURNED) | **(computed)** `data/processed/*_participants.csv` |

`workerid` ranges do not overlap between waves (pre 1385-2982, post 3262-4939) **(computed)**.

## 2.2 Design

### Conditions

There are 6 between-participant conditions: `cloze-event`, `event-cloze`, `maze-event`, `event-maze`, `spr-event`, `event-spr` (`experiment/src/custom_helper.js:27-52`; `experiment.js:354-381`). There is **no mazerace condition**.

- **Assignment.** Client-side `Math.random()` with cumulative cut-points 0.256 / 0.384 / 0.538 / 0.615 / 0.872 / 1. The code comment says "2/3 task first, 1/3 task second; 5:3:5 cloze:maze:spr" (`custom_helper.js:28-35`).
- **Observed per condition** (`*_participants.csv`) **(computed)**. The same numbers are printed in `analysis/post-election-exploratory.pdf`, HSP abstract section.

  | Wave | cloze-event | event-cloze | event-maze | event-spr | maze-event | spr-event |
  |---|---|---|---|---|---|---|
  | Pre | 333 | 161 | 102 | 163 | 189 | 331 |
  | Post | 354 | 155 | 99 | 151 | 181 | 333 |

### Counterbalancing (random, client-side)

- **Slider order.** Harris first or Trump first, by `pop_random` (`custom_helper.js:92-136`).
- **Order of the preference options.** Harris/Trump or Trump/Harris, via two survey versions (`experiment.js:56-58`; `instructions.js:62-68`, `220-226`).
- **Order of the recall options** (`experiment.js:62-65`).
- **There is no VP/president factor.** The 2020 `asked_about_vp` is absent; only the presidency is asked about (`instructions.js:10-12`).

### Critical trial

- **Maze and SPR** (one trial):
  - Starter sentence plus two different items, drawn at random from 10 (items 1-5 and 8-12).
  - Pronoun pair drawn from {she-she, she-he, he-he, he-she, they-they}.
  - One comprehension question, about one of the two items (`custom_helper.js:54-84`).
- **SPR** uses the same `maze_item` timeline variable (`experiment.js:328-337`).
- **Cloze:** one prompt chosen at random from 10 (`custom_helper.js:86-90`).

## 2.3 Materials

- **Starter sentence.** "The next US president will be sworn into office in January 2025." Its distractor is "x-x-x seen OKAY screaming ones mom ditch find prices eye Reached wood." (`experiment/src/maze_stim.js`, first entry).
- **Example item.** "After moving into the Oval Office, one of the first things that she|he|they will do is hold a staff briefing." (`maze_stim.js`, item 1).
  - There are 31 entries: start, plus 10 items × {she, he, they} (computed with `grep`).
  - Each item's distractor string is shared across its pronoun versions (`maze_stim.js`, item 1 entries). A-maze generation is presumably the same as 2020 (inferred; not documented).
  - The analysis notes that items 3 and 11 contain a second pronoun that does not refer to the president (`analysis/pre-election-process.Rmd:113-114`).
- **Cloze prompts.** 10 prompts, each the starter sentence plus a fragment ending before the pronoun. Example: "…one of the first things that " (`experiment/src/cloze_stim.js:1-52`).
  - The instruction differs slightly from 2020: "Please guess how the sentence continues…" (`instructions.js:14-17`).
  - Blank responses are not allowed: "Please complete the sentence." (`experiment.js:175-182`).
- **Comprehension questions.** 10 yes/no questions, e.g. "Will the president have access to the nuclear launch codes?" (yes) (`experiment/src/comp_q.js:1-52`). Each participant answers one.
- **Event expectation.**
  - Heading: "Who do you think will be the US president in February 2025?"
  - Instruction: "Use the sliders below to indicate each candidate's chance." (`instructions.js:10-12`). Unlike 2020, it has no "of winning the election".
  - Three sliders, Kamala Harris / Donald Trump / Someone else, each starting at 0 and ticked 0-100% (`custom_helper.js:92-136`).
  - The two candidate sliders must be moved (`require_movement: [true, true, false]`, `experiment.js:203`).
- **Recall** (event-maze and event-spr only).
  - Question: "Think about the writer of the sentences you read on the previous page. Who does the writer believe will be the US president in February 2025?"
  - Options: Harris, Trump, "Writer is unsure", "I don't remember" (`experiment.js:257-278`, `367-380`).
- **Final survey.** The same questions as 2020, now including news exposure, which 2020 asked before the tasks (`instructions.js:42-198`).
  - Preference: "Who would you PREFER to win the upcoming US presidential election?"
  - Age, gender, state, education, political affiliation.
  - Citizen, native English and US residence are required items (`isRequired: true`) (`instructions.js:176-196`).
- **No post-election awareness question, bot-screening question or mazerace items** exist in the code (`experiment.js`, `instructions.js` full read). The repo holds a single version of the experiment, so there is no evidence the post wave used different code. Whether the code was changed between waves is unknown, since this copy has no git history (`STATUS.md:30`).

## 2.4 Procedure

**Order** (`experiment.js:311-386`):

1. Browser check
2. Consent
3. Task 1
4. Task 2
5. Recall (event-maze and event-spr only)
6. Survey
7. Debrief
8. Data submission

**Per task:**

- **Maze block:** instructions, practice, critical trial, comprehension question (`experiment.js:316-319`).
  - The instructions are the same as 2020's plus "you will have to guess which word comes next" (`instructions.js:19-28`).
  - The practice sentence is identical to 2020's (`experiment.js:280-288`).
  - Redo mode defaults to true, with a 500 ms delay after an error (`experiment/src/maze.js:41-53`).
- **SPR block:** instructions, practice, practice question, critical trial, comprehension question (`experiment.js:328-336`). The practice text is identical to 2020's (`experiment.js:244-255`). SPR style is `"word"` (`experiment.js:224`; `spr.js:13-17`).
- **Cloze and event:** a single screen each, with no practice (`experiment.js:320-327`).

**Duration.**

- Prolific "Time taken" (in seconds; unit inferred) **(computed)**: pre median 2.38 min (IQR 1.76-3.34), post median 2.58 min.
- Last jsPsych `time_elapsed` per worker gives a median of 2.04 min (pre) and 2.21 min (post) **(computed)**.

## 2.5 Exclusions

### Original pipeline

Source: `2024-mmepr24/analysis/pre-election-process.Rmd`. Post is identical except as noted.

| Criterion | Applies to | Line |
|---|---|---|
| Proliferate workerid linked to more than one Prolific ID, or Prolific ID linked to more than one workerid | all | `:260-311` |
| Must answer yes to US resident, US citizen and native English | all | `:313-320` |
| Comprehension question answered correctly (the single question) | maze, SPR, recall (`use_comp_q = T`); **not** expectations or cloze (`use_comp_q = F`) | `:225`, `:322-329`, `:388`, `:401`, `:404` |
| SPR: drop words with RT ≤ 180 or ≥ 5,000 ms, and words whose next 3 words fail the same window | SPR | `:452-454`, `:493-509` |
| Maze: drop participants whose error count exceeds floor(mean + 2 SD); then drop error trials | Maze | `:516-520`, `:533-539` |

- **Completion-code check is dead code.** It is computed (`:227-229`), but the filter is commented out (`:317-318`).
- **RTs are residualized** by an `lmer` on log RT. Predictors are participant geometric-mean RT (before pronoun 1), word number, length, comma, period and first-in-sentence, with all 2-way interactions plus (1 | item). Maze adds `prev_incorrect` (`:461-490`, `:541-566`).
- **Post differs in the SPR order.** The post wave applies the SPR RT window and next-3-words filter **before** fitting the residualization model; pre applies it after (`post-election-process.Rmd:472-489` vs `pre-election-process.Rmd:493-509`).
- **Printed counts** (`analysis/{pre,post}-election-process.pdf`):
  - Pre: participant screening 1,279 → 1,255; comprehension accuracy 0.928; 9% of maze participants removed for errors; 12% of SPR RTs excluded.
  - Post: 1,273 → 1,246; accuracy 0.930; 8.9% removed for maze errors; 12% of SPR RTs excluded.
  - The post PDF also lists 3 workerids linked to more than one Prolific ID and 10 Prolific IDs linked to more than one workerid. Those IDs are deliberately not reproduced here.

### How paper-b's prep differs

Source: `paper-b/2024/prep/shared_prep_functions.R:8-53`, `paper-b/2024/README.md:19-55`.

- **One shared function for both waves.**
  - The SPR window is applied before residualization in **both** waves.
  - Both waves use the post-wave cloze "ambiguous NP" regex and the post-wave quote-safe JSON parser.
  - The cloze override for workerids 1676 and 2291 is applied to pre only.
- **Missing cross-account check.** The cross-Prolific-account duplicate check cannot be reproduced; only duplicate submissions under the same workerid are caught (`shared_prep_functions.R:280-303`).
- **Same thresholds:** 180 / 5,000 ms and mean + 2 SD for maze errors (`shared_prep_functions.R:59-61`).
- **Resulting participants kept:** pre 1,279 → 1,281; post 1,273 → 1,279 (`paper-b/2024/README.md:43-47`).

## 2.6 Planned and reported analyses (as they exist)

- **HSP 2025 abstract and poster.** Only figure PDFs exist; the abstract and poster text was **not found** (`output/HSP2025-abstract/`, `output/HSP2025-poster/` listing).
  - Figure content (from `pdftotext`):
    - Event-expectation probabilities by candidate, pre vs. post.
    - Cloze response-type fractions: Harris, she, Trump, he, hedged, they, NP.
    - Maze and SPR "log residualized RT" at pronoun 1 (she/he/they) and pronoun 2 (match/mismatch).
    - Histograms of P(Trump).
  - These figures are generated by `analysis/post-election-exploratory.Rmd:129-316` (abstract) and `:320-683` (poster).
- **Exploratory tests** (`analysis/post-election-exploratory.Rmd`):
  - One-sample t-tests of per-participant P(Trump) against 0.5 in each wave (`:697-725`).
  - Maze: `lm(log(rt) ~ pronoun_gender * batch)` on residualized RTs at pronoun 1, with `emmeans` pairwise contrasts and `pairs(..., interaction = TRUE)` for whether each contrast changed pre→post (`:740-790`). Pronoun 2 is analyzed the same way with a `match` factor (`:802-810`).
  - SPR: the same structure on `rt_gmean`, the geometric mean of the pronoun and the next 3 words (`:835-846`, `:895-902`).
  - Cloze: `prop.test` of she vs. he, and a binomial HPDI comparison of task orders (`:1000-1030`).
  - The analysts' prose summaries (e.g. "in post-election data, RT of female pronouns is significantly larger…") are at `:776-797` (e.g. `:777`). These are exploratory interpretations, not verified by me.
- **Cross-wave check.** `post-election-exploratory.Rmd:118-126` warns if a workerid appears in both waves. Because workerid ranges are disjoint, this check cannot detect anyone (inferred; computed ranges above).

## 2.7 Open questions and inconsistencies (2024)

1. **Not in the repo:** payment amount, Prolific screeners or quotas, and intended N. Political affiliation in the Prolific export is roughly balanced: pre D 377 / I 549 / R 353 **(computed)**. Whether this reflects a quota is unknown.
2. **Repeat participation across waves.** Whether pre-wave participants were blocked from the post wave on Prolific is **not found**. No cross-wave exclusion exists in either the original or the paper-b pipeline.
3. **SPR residualization order** differed between the original pre and post scripts. paper-b fixes this, so its output differs from the HSP figures, which were made from the original processed CSVs.
4. **Comprehension filter is not uniform.** It applies to maze, SPR and recall but not to expectations or cloze. The single question per participant makes "correct" a one-shot criterion.
5. **Browser check.** The `minumum_width` typo probably disables the width check (inferred).
6. **Exploratory participant counts are pre-screening.** The `participants` tables used for the exploratory condition counts (`post-election-exploratory.Rmd:137-139`) count all approved participants (1,279 / 1,273), not the screened set (1,255 / 1,246). Reported condition Ns would therefore depend on which table is used.

---

# Cross-study differences worth knowing before any comparison

These are restated from the cited sections above.

| | 2020 MVP | 2024 mmepr24 |
|---|---|---|
| Platform | MTurk (Ibex) | Prolific (jsPsych + proliferate) |
| Target office | VP (Harris/Pence) for the sentences; slider and preference randomly VP or president | President (Harris/Trump) |
| Mazerace control | Yes | No |
| Pronoun pairs | hh, hs, sh, ss, tt (5) | ss, sh, hh, hs, tt (5) |
| Comprehension questions | 2 per trial, not scored or used | 1 per trial, used to exclude from maze/SPR/recall |
| Maze accuracy exclusion | None | mean + 2 SD errors; error words dropped |
| RT window | Participant dropped if any word < 180 or > 10,000 ms | Word-level 180-5,000 ms (SPR); residualized log RT |
| US / citizen screening in analysis | Not applied (native English only) | Applied (residence, citizen, English) |
| News question | Before tasks | In final survey |
| Bot screen | Yes ("PASTA") | No |
| Awareness question (post) | Yes | No |
