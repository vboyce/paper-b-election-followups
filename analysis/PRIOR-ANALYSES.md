# Prior analyses: 2016/2017, 2020 and 2024 election studies

Internal planning reference, **not paper prose**. It lines up, outcome by outcome, what each study excluded, which comparisons it made, which models it fit and what it concluded, so analyses for the 2020 + 2024 paper can be planned.

Candidate names are replaced by "D candidate", "R candidate" or "female candidate" (2016: female = D presidential candidate; 2017 UK: female = sitting Conservative PM). Cloze category labels that are literally candidate names are written as `name-D` and `name-R`.

**Contents**

1. Sources
2. Design snapshot
3. Participant-level exclusions shared by all outcomes
4. By outcome: 4.1 Event expectations · 4.2 Cloze · 4.3 Reading times: exclusions and measures · 4.4 Reading times, pronoun 1 · 4.5 Reading times, pronoun 2 · 4.6 Mazerace · 4.7 Recall · 4.8 Individual differences
5. Model conventions per study (coding, random effects, priors, inference)
6. Decision points for the 2020 + 2024 paper, by outcome
7. Notes on claims checked

## 1. Sources and citation keys

Paths are relative to `/home/vboyce/Research/backlog/paper-b-election-followups/`. `file:N` means line N.

| Key | Source | How it was read |
|---|---|---|
| **MS** | von der Malsburg, Poppels & Levy (2020), *Psychological Science*, main text. Full-text XML from Europe PMC (PMC7197219). Cited by section heading. | Methods and Results of Exp. 1 and 2 read in full. |
| **SI** | Supplemental Material, `malsburg_supplemental_material_rev.pdf` (local copy, 58 pp.). Cited as `SI p.N`, using printed page numbers. | §2-§5 (pp. 3-33) read in full via `pdftotext`. Appendices and §6 not read. Figure text is garbled in extraction. |
| — | 2016/2017 **analysis code** (`MadamePresident` clone) | **Not available** on this machine when this was compiled (2026-10-06). All 2016/2017 model details below come from prose in MS/SI, not code. |
| **PRE20** | `2020-madame-vice-president/pre-election-round/pre-election-round-data/data-analysis/pre-processing.R` | Read in full. |
| **POST20** | `2020-madame-vice-president/post-election-round-1/data/data-analysis/pre-processing.R` | Diffed against PRE20; exclusion block read. |
| **JOINT20** | `2020-madame-vice-president/pre-post-election-joint-analysis/data-analysis.Rmd` (`.md` = knitted output) | `.Rmd` read in full. `.md` grepped for model output. |
| **WITHIN20** | `…/pre-post-election-joint-analysis/within-participant-analysis/analysis.Rmd` (and `.md`) | Read in full. |
| **DEMO20** | `…/pre-post-election-joint-analysis/demographics-analysis/demographics-analysis.Rmd` (and `.md`) | Skimmed: model formulas and hypothesis outputs only. |
| **ITEMS20**, **MAZE20** | `2020-madame-vice-president/pre-election-round/pre-election-round-ibex/{items.js,Maze.js}` | Targeted reads (`items.js:296-312`, `Maze.js:95-182`). |
| **PRE24**, **POST24** | `2024-mmepr24/analysis/{pre,post}-election-process.Rmd` | PRE24 read in full; POST24 diffed against it, and the SPR block read. |
| **EXPL24** | `2024-mmepr24/analysis/post-election-exploratory.Rmd` (`.pdf` = knitted) | Setup, the "Exploratory Data analysis" section (`:691-1043`) and HSP figure chunks skimmed. Printed results taken from `pdftotext` of the PDF. |
| **EXP24** | `2024-mmepr24/experiment/src/{experiment.js,maze.js}` | Targeted reads. |
| **MSUM** | `paper-b/METHODS-SUMMARY.md` §1.5, 1.6, 2.5, 2.6 | Read; key claims re-checked against code (see §7). |

Per-round 2020 `.org` notebooks and the LingLunch `graphs_and_stats.Rmd` were grepped for model calls; none were found, so they are descriptive only.

---

## 2. Design snapshot

| | 2016 US / 2017 UK | 2020 ("MVP") | 2024 ("mmepr24") |
|---|---|---|---|
| Platform | US: MTurk, using Qualtrics (beliefs) and Ibex (cloze, SPR) (MS "Participants", "Apparatus"). UK: Prolific (SI p.25-26) | MTurk + Ibex (MSUM §1.1; PRE20:294) | Prolific + jsPsych/proliferate (MSUM §2.1) |
| Target office | US president / UK prime minister | **Vice** president in the sentences. Slider and preference ask about VP or president, at random (ITEMS20 via MSUM §1.2) | President |
| Time points | US: 10 pre-election rounds + 2 post (after election; after inauguration) (MS "Data collection"; SI Table S1, p.13). UK: 1 pre + 1 post (SI p.26) | 1 pre round (Oct 30-Nov 3) + 1 post round (Nov 7-10) (MSUM §1.7 items 5-6) | 1 pre wave (Oct 31) + 1 post wave (Nov 8-11) (MSUM §2.1) |
| Tasks per participant | **One** task only (beliefs, cloze or SPR), one trial (SI p.11-12) | **Two** tasks: event-expectation sliders + one of cloze / Maze / SPR / mazerace, order counterbalanced; one critical trial (MSUM §1.2) | **Two** tasks: sliders + one of cloze / Maze / SPR, order counterbalanced; one critical trial (MSUM §2.2) |
| Comprehension passage | Stage-setting sentence + 2 sentences. 5 conditions: she/he crossed for pronouns 1 and 2, plus they-they. 12 sentences → 132 ordered pairs (SI p.11). They added from batch 2 (SI p.11, p.13) | Context + 2 of 12 sentences; hh, hs, sh, ss, tt (MSUM §1.2) | Starter + 2 of 10 sentences; same 5 pronoun pairs (MSUM §2.2) |
| Extra measures | Naturalness rating; 2 comprehension questions (SI p.12) | Recall of writer's belief (event-first conditions); mazerace control; comprehension question(s) (see §6, item on comprehension) | Recall (event-first Maze/SPR); 1 scored comprehension question (MSUM §2.3) |
| Recruited N | US 24,863 (MS "Participants"); UK 2,609 = 1,609 pre + 1,000 post (SI p.26); Exp 0: 1,897 (SI p.3) | Raw sessions: pre 4,648, post 4,543 (MSUM §1.5) | Approved: pre 1,279, post 1,273 (PRE24/POST24 printed counts; MSUM §2.5) |
| N after exclusions, per task | Targets per round: 280 beliefs, 560 cloze, 1,120 SPR (MS "Data collection"). Post-exclusion N per task: **not found**. Exp 0: 1,496 (SI p.6) | Pre: cloze 463, Maze 339, mazerace 356, SPR 449 (sum 1,607). Post: 172 / 138 / 143 / 136 (sum 589). Summed from `…/pre-election-round-data/data-analysis/data-analysis.md:188-198` and `…/post-election-round-1/data/data-analysis/data-analysis.md:188-197` | Pre: cloze 485, Maze 244, SPR 445. Post: 497 / 235 / 432 (EXPL24:929-937; EXPL24.pdf p.37). Sliders: pre 1,255, post 1,243 (EXPL24.pdf p.31) |

---

## 3. Participant-level exclusions shared by all outcomes

These apply to a participant's data in every outcome, unless the outcome tables in §4 say otherwise. "Participant" = whole session dropped; with one critical trial per participant, trial-level and participant-level exclusion coincide for SPR/Maze in all three studies.

| Criterion | 2016 US / 2017 UK | 2020 | 2024 |
|---|---|---|---|
| Native English | Excluded if self-reported non-native (SI p.13-14; MS "Data preprocessing") | Excluded if `native != "yes"` (PRE20:339; POST20:349) | Excluded unless "Yes" (PRE24:315) |
| US/UK residence | Excluded if non-resident (same sources) | **Not applied** (PRE20:336-360) | Excluded unless "Yes" (PRE24:315) |
| Citizenship | Excluded if non-citizen (same sources). UK: Prolific prescreen on all three as well (SI p.26) | **Not applied** (PRE20:336-360) | Excluded unless "Yes" (PRE24:315) |
| % removed by the language/residence/citizenship screen | US: beliefs 8.3%, cloze 6.8%, SPR 5.8% (SI p.13-14). UK: 5.8% / 1.4% / 1.1% (SI p.27) | Native-only screen; % not separately reported | 1,279 → 1,255 pre; 1,273 → 1,246 post (PRE24/POST24 PDFs) |
| Repeat participants within round | UniqueTurker; duplicates removed by WorkerId: beliefs 11%, cloze 12%, SPR 13% (SI p.9, p.13-14). UK: **not mentioned** | Any session after the first per IP-hash (`repeat.md5`) or per WorkerId (`repeat.WorkerId`) (PRE20:321-341) | workerid linked to more than one Prolific ID or more than one survey, or Prolific ID linked to more than one workerid (PRE24:260-311). Completion-code check commented out (PRE24:317-318) |
| Repeat across rounds | UniqueTurker blocked overlap "across experiments" (SI p.9) | Post: excluded if WorkerId appears anywhere in the pre-round MTurk file (POST20:327-328, :352); re-applied in JOINT20:27 | **None** (no cross-wave check in PRE24/POST24; MSUM §2.7 item 2) |
| Bot screen | Not mentioned | Entry gate ("PASTA" question), so it produces no exclusions (MSUM §1.3) | None (MSUM §2.1) |
| All sliders at 0 | Belief-task participants only (the other tasks had no sliders): US 0.12%, UK 1% (SI p.13, p.27) | Removed if all three sliders were left at 0 (PRE20:353-357) — applies to **every** task's participants | Cannot occur: the two candidate sliders must be moved (EXP24 `experiment.js:203`) |
| Any word RT ≤ 180 or ≥ 10,000 ms | n/a (trial-level rule; see §4.3) | **Drops the whole participant**, for every outcome including cloze and sliders. Practice items included; Maze includes mazerace (PRE20:343-352). The comment at PRE20:336 says "trials", but the code drops the participant | n/a (word-level rules; see §4.3) |
| Post-election awareness | n/a | Asked post-round (POST20:104-108) but **not** used to exclude | Not asked |

---

## 4. By outcome

Each table has the same rows: **exclusions** specific to this outcome (beyond §3), the **measure**, the **comparisons** run, the **model** (exact formula where code exists) and **inference**, and what the authors **concluded** (their interpretation, quoted or paraphrased; none re-run here). Study-wide model conventions (coding, priors, random effects) are in §5.

### 4.1 Event expectations

| | 2016 US / 2017 UK | 2020 | 2024 |
|---|---|---|---|
| Exclusions | §3 screen + duplicates + all-zero sliders | §3 rules (incl. the RT rule from the participant's other task) | §3 screen + duplicates; **no** comprehension or Maze-accuracy filter; P(R candidate) `drop_na`'d (EXPL24:699) |
| Measure | Each slider ÷ sum of the participant's scores; P(female) = P(female candidate) (SI p.13). UK: P(female PM) = P(female candidate) + other named women; unnamed "other" gives a lower (34%) / upper (42%) bound (SI p.27-28). No sum-to-100 constraint (SI p.12) | Each slider ÷ sum of D + R + "someone else" (PRE20:126-141) | Each slider ÷ sum of D + R + "other" (PRE24:82) |
| Comparisons | Change over the pre-election period; pre vs post (batch 10 vs 11) | None | Each wave vs 0.5 |
| Model | Beta regression on P(female), "slightly scaled (factor 0.99)" to avoid 0/1. Over time: batch time in months, centered, by-batch random intercepts (SI p.15). Pre vs post: time −0.5/+0.5, **no** by-batch intercepts (SI p.16) | "**TODO:** statistical analysis" — none run (JOINT20:163) | `t.test(p, mu = 0.5)` on per-participant P(R candidate), per batch (EXPL24:697-708) |
| Inference | Posterior mean, 95% CrI, P(β > 0) | — | p-value |
| Concluded | US: P(female) rose over the pre period (β = 0.082 log-odds/month, P = .97) and dropped after the election (β = −1.7) (SI p.15-16). UK: post-election P(female PM) between 34% and 42% (SI p.28) | Plots only (JOINT20:99-163) | Pre mean P(R) = 0.488, not different from 0.5 (p = .085). Post 0.920, p < .001 (EXPL24.pdf p.31; EXPL24:729) |

### 4.2 Cloze

| | 2016 US / 2017 UK | 2020 | 2024 |
|---|---|---|---|
| Exclusions | §3 screen + duplicates. Analyses use **only pronoun trials** (41% US, 44% UK) (SI p.14, p.16, p.27) | §3 rules (participant RT rule n/a: no reading task). Models use only pronoun responses in the compared categories | §3 screen + duplicates; **no** comprehension filter (cloze had no question). Test uses she + he responses only |
| Coding | Regex. Four types: she (she/her), he (he/his/him), they (they/their/them), gender-hedged (he or she, he/she…) (SI p.14) | Regex with **precedence** (later overwrites earlier): none → male → female → neutral → both (male & female) → `name-D/R` (VP and presidential candidates). A name anywhere overrides any pronoun (PRE20:143-169). The male pattern is written `\\him\\b` (missing `b`); whether "him" is matched was not verified | `case_when`, so the **first** match wins: hedged → female → male → neutral (meant to exclude a "them" after "…one of", but the check tests the response, not the prompt) → `name-R` → `name-D` → ambiguous NP → OTHER (PRE24:407-426). Post uses a broader NP regex (POST24 diff at :423/:431). Pronoun beats name (opposite of 2020). Manual overrides for two pre responses (PRE24:428-432) |
| Comparisons | US pre: each pronoun type vs the round-level belief. UK: pre vs post | she vs he by round; she vs they/both by round | she vs he against 50%, **pre only**; task order (pre only) |
| Model | US: one Bernoulli logistic model per pronoun type (e.g. she yes/no). Predictor: logit of the **round-level** belief from the separate belief task. By-item random intercepts + slopes; by-batch intercepts (SI p.16, p.23). UK: logistic, time −0.5/+0.5, maximal random effects (SI p.29) | `brm(shePronoun ~ NRound + (NRound \| cloze_item), data = filter(d_cloze, cloze_pronoun %in% c("female","male")), family = "bernoulli")` (JOINT20:486-489). Same formula with `c("female","they","both")` (JOINT20:491). **Bug:** the category is called `"neutral"`, not `"they"`, so the second model is actually she vs "both" (PRE20:164). Its output: intercept 5.79, CrI [1.16, 18.2] (JOINT20 `.md:2167-2168`) | `prop.test(F_count, M_count + F_count)` (EXPL24:1000-1040). Binomial 95% HPDI (`binomialCRIs`) for task order. Figures collapse types: female = {`name-D`, she}, male = {`name-R`, he}, neutral = {hedged, they, NP} (EXPL24:186-194, :984-990) |
| Inference | Posterior mean, 95% CrI, P(β > 0) | Posterior mean, 95% CrI | p-value; HPDI overlap |
| Concluded | US: as belief in a female president rose, he decreased and **they**, not she, increased (MS "Results"; SI p.16-17). UK: they 65% → 48%, she 24% → 47% pre → post (SI p.29) | She rate among she + he rose post-election (NRound 1.33, CrI [0.18, 2.94]); "same is true" for she vs they (JOINT20:497) — unsupported, given the filter bug | Pre she vs he: p = 0.077 (EXPL24.pdf p.37). Task order effect "not significant" by HPDI (EXPL24:1020) |

### 4.3 Reading times: exclusions and measures (SPR and Maze)

| | 2016 US / 2017 UK | 2020 | 2024 |
|---|---|---|---|
| Exclusions, SPR | §3 screen + duplicates. RT = 0 / undefined trials removed (US 0.043%, UK 0.15%; SI p.6, p.14, p.27). **Any word < 180 or > 5,000 ms → trial removed** (19% of US trials per MS; UK 22%, SI p.27). SI says "data from participants"; SI p.6 fn.1 says "removed the complete trial" | §3 rules, including the participant-level RT rule (≤ 180 / ≥ 10,000 ms on any word) | §3 screen + duplicates + **comprehension question correct** (PRE24:322-329, :452). Word-level window 180 < RT < 5,000; a word is kept only if it **and the next 3 words** are in the window (PRE24:453, :493-503); 12% of SPR RTs out of window. Pre: window applied *after* residualization; post: *before* (POST24:472-489 vs PRE24:479-509) |
| Exclusions, Maze | n/a (no Maze) | §3 rules, including the participant-level RT rule. **No accuracy filter**; redo mode, RT is first-try (MAZE20:103-110, :170-178; PRE20:82-91) | §3 screen + duplicates + comprehension correct. Participant excluded if errors > floor(mean + 2 SD) over Maze participants (PRE24:516-520): 9% pre, 8.9% post. **Error words dropped** (`filter(correct)`, PRE24:539). **No RT window** (PRE24:513-567) |
| Measure, SPR | Pronoun + 4 following words, **summed**, then log; sentence-final word never included (SI p.17-18, fn.4). RTs residualized first (see §5) | Pronoun + 4 words, **raw sum** (JOINT20:168-212) | Pronoun + **next 3** words, **geometric mean** (`rt_gmean`) of residualized RTs (PRE24:493-507). **Post:** `rt_gmean` is computed from **raw** RTs before residualization and never recomputed (POST24:472-489, then :510-512), so pre and post are on different scales (inferred from code order) |
| Measure, Maze | n/a | First-try RT at the **pronoun word only**, raw ms (JOINT20:222, :244; MAZE20:176) | First-try RT (EXP24 `maze.js:348-351`) at the pronoun word, residualized (with `prev_incorrect`), then log (EXPL24:741-745) |
| Transformation | Residualized log RT (§5) | Raw ms (§5) | Residualized log RT (§5) |

### 4.4 Reading times: pronoun 1 (first critical sentence)

| | 2016 US / 2017 UK | 2020 | 2024 |
|---|---|---|---|
| Comparisons, SPR | she vs he, she vs they; pronoun × pre-election belief; pronoun × pre/post (batch 10 vs 11) | None (plots only) | Pairwise pronoun contrasts within each wave; each contrast × wave |
| Comparisons, Maze | n/a | she vs they × round; she vs he × round (pairwise subsets); pronoun within each round | Pairwise pronoun contrasts within each wave; each contrast × wave |
| Model, SPR | Linear model on log summed region; random intercepts and slopes for batches and stimulus sentences (SI p.17-18). Belief: logit(belief) predictor, by-item intercepts + slopes for belief, by-batch intercepts, effects reported **per pronoun** (SI p.18). Pre/post: pronoun **treatment-coded (he = baseline)** × election **−0.5/+0.5** (SI p.18). UK "similar" (SI p.29-33) | No model (JOINT20:166-212) | `lm(log(rt_gmean) ~ pronoun_gender * batch, … is_pron1)` + `emmeans` `pairs(by = "batch")` and `pairs(interaction = TRUE)` (EXPL24:836-884) |
| Model, Maze | n/a | `brm(maze_word_rt ~ NRound * Npro1_type + (NRound * Npro1_type \| sen1_number), d1)` (she vs they; JOINT20:244-245). `brm(maze_word_rt ~ NRound * Npro1_type + (NRound * pro1_type \| sen1_number), d2)` (she vs he; the slope uses the **factor** `pro1_type`; JOINT20:246-247). Within-round: `brm(maze_word_rt ~ Npro1_type + (Npro1_type \| sen1_number), …)`; post fits use `(pro1_type \| sen1_number)` (JOINT20:263-266) | `lm(log(rt) ~ pronoun_gender * batch, data = maze \|> filter(is_target, is_pron1))` + `emmeans(~ pronoun_gender : batch)`, `pairs(by = "batch")`, `pairs(interaction = TRUE)` (EXPL24:741-790) |
| Inference, SPR | Posterior mean, 95% CrI, P(β > 0); effects also in ms after back-transformation (MS "Data analysis") | — | p-values from `emmeans` (adjustment not verified) |
| Inference, Maze | — | Posterior mean, 95% CrI; "significant" if the CrI excludes 0 (JOINT20:256, :276) | p-values from `emmeans` |
| Concluded, SPR | US: she slower than he (β = 0.13, ≈ 302 ms) and than they; little change with pre-election belief; she and they disadvantages **grew** after the election (MS "Results"; SI p.18). UK: pre she ≈ he and they fastest; post she and they faster than he (MS Exp 2 "Results") | Not analyzed | Pre and post: she slower than he and they; he ≈ they. No pre/post interaction "significant" (EXPL24:862-890). The post he-they p-value in the prose (0.5474) is copied from pre; the PDF prints 0.9492 (EXPL24:871 vs EXPL24.pdf p.34) |
| Concluded, Maze | n/a | she penalty vs he and vs they pre-election, gone or reversed post. Round × pronoun "significant" in both subsets (JOINT20:256, :276). she vs they: −155 ms [−259, −54]; she vs he: −219 ms [−300, −133] (JOINT20 `.md:576-599`) | Pre: she > he > they in RT, all p < .05. Post: she slower than both; he ≈ they. he-vs-she gap **increased** post (−0.452 log units, p < .0001) (EXPL24:776-798; EXPL24.pdf p.31-33) |

### 4.5 Reading times: pronoun 2 (second critical sentence)

| | 2016 US / 2017 UK | 2020 | 2024 |
|---|---|---|---|
| Measure, SPR | Region as §4.3; also the pronoun alone (SI p.21). Match/mismatch with pronoun 1 (SI p.20) | Raw region sum (plots only) | `rt_gmean` as §4.3 (same pre/post scale issue); `match = type1 == type2` (EXPL24:100-101) |
| Measure, Maze | n/a | First-try RT at pronoun 2, raw ms (JOINT20:310) | As Maze in §4.3; `match = type1 == type2` (EXPL24:100-101) |
| Comparisons, SPR | Pronoun 2 (he/she) × match × belief | None | Pronoun × wave × match |
| Comparisons, Maze | n/a | Round × pronoun 1 × pronoun 2 (she vs he) | Pronoun × wave × match |
| Model, SPR | Pronoun (he −0.5 / she +0.5) × match (match −0.5 / mismatch +0.5) × logit(belief), all interactions; hierarchical over 12 stimulus sets and batches. Run on region and on the pronoun alone (SI p.20-21) | No model | `lm(log(rt_gmean) ~ pronoun_gender * batch * match, … is_pron2)` (EXPL24:896-919) |
| Model, Maze | n/a | Exploratory `lmer(maze_word_rt ~ NRound * Npro1_type * Npro2_type + (… \|\| sen1_number) + (… \|\| sen2_number) + (… \|\| maze_item_no))` and a `maze_item_no`-only version (REML = F). Reported: `brm(maze_word_rt ~ NRound * Npro1_type * Npro2_type + (NRound * Npro1_type * Npro2_type \| sen1_number) + (… \| sen2_number) + (… \| maze_item_no))` (JOINT20:310-315, :321) | `lm(log(rt) ~ pronoun_gender * batch * match, … is_pron2)`; `pairs(by = c("match","batch"), interaction = TRUE)` (EXPL24:803-826) |
| Concluded, SPR | US: large mismatch cost; she slower than he even after a gendered antecedent; additive (MS "Results"). UK: mismatch cost; no reliable she effect (MS Exp 2) | Not analyzed | Fitted; no prose conclusion found |
| Concluded, Maze | n/a | "Clear interaction" Round × pronoun 2: she gets relatively faster post-election (NRound:Npro2_type −171 [−268, −71]) (JOINT20:324; `.md:1261`) | Fitted; no prose conclusion found |

### 4.6 Mazerace (2020 only)

| | 2020 |
|---|---|
| Exclusions | As Maze in §4.3 |
| Measure | First-try RT and first-try accuracy at the race adjective (JOINT20:329-345) |
| Comparisons | Race (black/white) × Capitalized × Round; per-round and per-frame subsets |
| Model | Accuracy: `glm(maze_word_correct=="yes" ~ NRound*Race*Capitalized, family="binomial")`; Race and Capitalized coded ±1 (JOINT20:343, :416-425). RT: `lm(maze_word_rt ~ NRound*Race*Capitalized*Item_type)`, `lm(maze_word_rt ~ NRound*Race*Capitalized)`, and subsets (JOINT20:432-445) |
| Inference | p-values |
| Concluded | Round × Race: black/Black got faster post-election (JOINT20:452) |

### 4.7 Recall

| | 2016 US / 2017 UK | 2020 | 2024 |
|---|---|---|---|
| Exclusions | n/a | As the participant's reading task (§4.3) | Comprehension correct (recall shown only to reading-task participants; PRE24:388, :401, :404); **no** Maze-error cutoff |
| Measure | n/a | 4 options: writer believes D / R / unsure / don't remember; event-first conditions (JOINT20:46-93) | Same question (EXPL24:71) |
| Comparisons | n/a | Response × round (he-he, they-they); he-he vs she-she | None |
| Model | n/a | `chisq.test` (JOINT20:77-92) | No test found |
| Concluded | n/a | No pre/post effect; he leads to more "writer is unsure" than she (JOINT20:95) | Not analyzed |

### 4.8 Individual differences (demographics, within-participant)

| | 2016 US / 2017 UK | 2020 | 2024 |
|---|---|---|---|
| Data | All tasks | Maze she vs they (demographics); maze-event + event-maze, both rounds pooled (within-participant) | — |
| Model | Separate models per demographic variable (and per pronoun), because a joint model had too many parameters. Party treatment-coded with Dem baseline; gender ±0.5; education (some college or not) ±0.5; age centered per decade (SI p.21-25) | Demographics: JOINT20 she-vs-they model plus `(NRound * Npro1_type \| gender/state/political_affiliation/age_bin/education)` (demo1). demo4/5 use `family = lognormal()`, `poly(age_centered,3) + mo(education)`, priors `normal(7,1)` intercept, `normal(0,1)` b/sd/sigma, `lkj(8)`; `hypothesis('NRound:Npro1_type < 0')` (DEMO20:186-198, :366-386, :572-590, :683-700). Within-participant: `brm(maze_word_rt ~ prob_dem_centered * Npro1_type + (candidate_prob_dem * Npro1_type \| sen1_number) + (candidate_prob_dem * Npro1_type \| condition), adapt_delta = 0.99)`; the fixed effect uses the scaled predictor and the random slopes the **unscaled** one; `condition` has only 2 levels (WITHIN20:114-125) | Exploratory plots only (EXPL24:1128-1405) |
| Concluded | See SI p.21-25 | With demographic random slopes, P(interaction < 0) falls from 0.999 to 0.73-0.81 (DEMO20 `.md:325, 417, 526, 640, 892, 1116`). The knitted within-participant `.md` was run with the `"singular_they"` no-op filter (they included); no numeric output printed (mcmc_plot only); no conclusion stated | — |

---

## 5. Model conventions per study

| | 2016 US / 2017 UK | 2020 | 2024 |
|---|---|---|---|
| Software | brms → Stan (NUTS), 4 chains × 2,000 iterations, half warmup (SI §2, p.3) | `brm` with **default family (Gaussian on raw ms) and default priors** — no `prior` or `family` argument (inferred from the calls); DEMO20 later uses lognormal with priors (§4.8) | `lm` (OLS) + `emmeans` |
| Random effects | Maximal: "all population-level parameters were allowed to also vary on the group-level" (SI p.3); by item and by batch | By item only (`sen1_number`; plus `sen2_number`/pair for pronoun 2); no participant effects (one trial per participant) | None |
| Priors | Improper flat on population-level parameters; LKJ(η = 1) on correlations; half-Student-t(3) on SDs; half-Cauchy on the residual SD (SI p.3) | brms defaults | n/a |
| Pronoun coding | Treatment, he = baseline (pre/post SPR); ±0.5 in pronoun-2 and Exp 0 models (SI p.7-8, p.18, p.20) | Pairwise subsets, feminine +1 vs other −1 (`Npro1_type`, `Npro2_type`; JOINT20:37) | 3-level factor, default treatment contrasts (inferred); inference via `emmeans` pairwise, so coding doesn't affect the reported contrasts |
| Pre/post coding | ±0.5 | `NRound` ±1 (JOINT20:37) | `batch` factor, `fct_rev`'d so post is the reference (EXPL24:744) |
| RT transformation | Log RT, **residualized**, back-transformed (residual + intercept, exponentiated) (SI p.6-7). Residualization model in prose only: log RT ~ participant reading speed (geometric mean RT before first pronoun) + word length + word position + punctuation + stimulus set, with all two-way interactions; exact formula **not found** | **Raw ms**, no log, no residualization (JOINT20:245-266) | Log RT residualized, back-transformed (PRE24:489-490, :565-566); models use `log()` of that. SPR residualization (PRE24:479-486): `log(rt) ~ 1 + (scale(log(gmean_rt)) + scale(word_number) + scale(nchar) + is_first_in_sent + comma + period)^2 + (1 \| item)`; Maze (PRE24:554-562) adds `prev_incorrect` inside the `^2`; `lme4::lmer`. Baseline `gmean_rt` uses `word_number < pron_pos_s1` (PRE24:466-469), mixing a passage position with a within-sentence position, so the baseline comes from only the first few starter words, varying by item (inferred) |
| Inference | Posterior mean, 95% CrI, P(β > 0); "reliable" if > 95% of the posterior mass is on one side of 0 (MS "Data analysis") | Posterior mean and 95% CrI from `summary()$fixed`; "significant" if the CrI excludes 0 (JOINT20:256, :276, :324, :497); p-values for mazerace and recall | p-values (`emmeans` default adjustment; not verified which) |

---

## 6. Decision points for the 2020 + 2024 paper, by outcome

**All outcomes**

1. **Participant exclusions.** Residence/citizenship was applied in 2016 and 2024, not 2020 (available as columns in paper-b). Repeat participants: 2016 by WorkerId; 2020 within round (IP + WorkerId) and across rounds (WorkerId); 2024 within wave only (Prolific's controls trusted across waves; `OPEN-QUESTIONS.md` #3).
--> if we have residence/citizenship for 2020, use that as an exclusion, but add not doing it to the robustness checks list. 
2. **Slider all-zero exclusion.** 2016 and 2020 drop such participants; 2024 cannot produce them. Decide whether a non-belief task's data should depend on slider behaviour.
--> let's not drop for 2020 & 2024, add as a robustness check. 
3. **Inference framework.** 2016 Bayesian (flat priors, P(β > 0)); 2020 Bayesian with default priors; 2024 frequentist OLS. Choose one, and specify priors if Bayesian.
--> Bayesian, I'll figure out prior when I write the models. 
4. **Pre/post coding.** ±0.5 (2016), ±1 (2020), factor (2024). ±0.5 gives interpretable effects (suggested, not decided).
--> agree with +/- .5 negative for before, positive for after
5. **Random effects with one trial per participant.** Maximal by item + batch (2016), by item (2020), none (2024). Decide whether to model sentence-1 item, sentence-2 item and/or the pair; pooling 2020 + 2024 also raises a study/round grouping question.
--> I'll do model spec myself when we get there

**Event expectations**

6. Beta regression on P(female) (2016), none (2020), t-test vs 0.5 (2024). Decide the DV (P(D) vs P(female); the 2020 VP vs president question), and whether "someone else" stays in the normalization (2020/2024 include it).
--> no need to model this

**Cloze**

7. **Coding.** Precedence differs (2020 names override pronouns; 2024 pronouns override names); only 2016 and 2024 detect hedges explicitly. paper-b's shared `cloze_code` (first reference) re-codes both studies the same way.
--> I need to know more about what happened and what the options look like with examples; probably will end up being robustness check
8. **Denominator and model.** 2016: pronoun trials only, per-pronoun logistic with belief as predictor. 2020: she vs he Bernoulli with round (the she-vs-they model is broken). 2024: `prop.test`, pre only.
--> let's do she v he & they v (gendered); or she, they, he as mulitnomial w/ he as baseline -- this is a model thing so I'll work on it

**Reading times (SPR and Maze)**

9. **RT plausibility window and level.** 180-5,000 ms, any word → drop trial (2016); 180-10,000 ms, any word incl. practice → drop participant (2020); 180-5,000 ms per word with a next-3-words rule, SPR only (2024). Choose one window and one level, and whether practice items count.
--> okay, two things here -- 1 is whether we are trying to restrict to maximally "attentive" participants (which should at least be a robustness check) where we should restrict cross-task and cross-sentence on maze-accuracy, and SPR/Maze times 180-5000; let's do time-course graphs in viz and figure out windowing afterwards. Maze at least will be on target word, SPR will be an adventure. 
10. **RT scale.** Residualized log (2016), raw ms (2020; lognormal in DEMO20), residualized log then OLS (2024). If residualizing: one fitting order relative to the window, and a fixed baseline-speed definition (see the 2024 indexing issue, §5).
--> modeling issue; return to afterwards, but probably raw / log x residualized are all robustness checks 
11. **SPR region.** Sum of pronoun + 4 words, log (2016); sum of pronoun + 4, raw, plots only (2020); geometric mean of pronoun + 3 (2024). Also whether the region may run into the sentence-final word (2016 excluded it).
--> let's look visually and then figure it out 
12. **Maze measure and accuracy.** 2020: first-try RT at the pronoun, no accuracy filter. 2024: participant cutoff (mean + 2 SD errors), error words dropped, `prev_incorrect` in residualization. Decide on a participant accuracy threshold, and whether to keep the pronoun RT if the pronoun itself was an error.
--> let's plot on-pronoun accuracy by condition as well 
13. **Pronoun coding and *they*.** He-baseline treatment (2016), pairwise ±1 subsets (2020), 3-level factor + `emmeans` (2024). One 3-level model with planned contrasts, or separate binary models?
--> I'll handle modeling, but we'll start with he as default planned contrasts I think? 
14. **Comprehension questions.** 2016 reported but didn't exclude; 2020 didn't use them; 2024 used one scored question for Maze/SPR/recall. ITEMS20:300-310 defines two questions (`q1`, `q2`) per 2020 trial, but paper-b's processed 2020 data has exactly one question per session: check whether one of the two was chosen at random or the extraction misses one before using 2020 comprehension.
--> I'm pretty sure we used 1 q / trial; let's viz the comp q accuracy and add this is a robustness check for the "maximally attentive" subclass
*Checked 2026-10-07:* the raw 2020 Ibex logs have exactly one question per Maze/SPR/mazerace submission (3,686 pre, 3,673 post), and in all 4,951 Maze/SPR sessions it is the question about sentence 1 (matched against `2020/raw/stimuli.tsv`). The second `Question` in `items.js` was never logged.

---

## 7. Notes on claims checked

- **Confirmed against code:**
  - 2020 exclusion list and line numbers (PRE20:336-360; POST20:327-363).
  - 2020 Maze RT is first-try (MAZE20:103-110, :170-178).
  - JOINT20 model formulas.
  - 2024 exclusion order, thresholds and residualization formula.
  - 2024 Maze RT is first-try (EXP24 `maze.js:348-351`).
- **Correction to the WITHIN20 "singular_they" bug (MSUM §1.6; `pipelines-and-code-review.Rmd:105-112`).** The bug is in the knitted `analysis.md:31,54` only. The current `analysis.Rmd:91,118` has the correct `"singular they"` (byte-checked).
- **New findings, not in MSUM:**
  - The cloze `"they"` vs `"neutral"` mismatch (JOINT20:491; confirmed independently).
  - Post-2024 `rt_gmean` is computed from raw RTs (POST24:472-489).
  - The `gmean_rt` baseline indexing issue (PRE24:466-469).
  - The SPR p-value copy error (EXPL24:871).
- **Maze practice not in the 2024 error count (checked).** In the pre-wave trials file, every worker with Maze data has exactly 1 `maze` row (the critical trial). So the practice item does not enter the error cutoff.
