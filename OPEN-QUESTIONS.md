# Open questions / possible follow-ups

Things we don't know that someone else (co-authors, past RAs) might be able
to answer. Each entry records what has already been checked, so that a
question only needs to go to someone else if it really matters.

Status: **open** = unresolved, **partial** = worked around but not fully
answered, **closed** = answered (keep the entry, note how).

---

## 1. Was the 2020 study preregistered? — open

- **Who might know:** Till Poppels, Titus von der Malsburg, Roger Levy.
- **Checked (2026-10-06):**
  - OSF API, every public registration on each of these accounts:
    Veronica Boyce (`7e2rw`), Titus von der Malsburg (`pfkez`), Till
    Poppels (`hyd6t`, `n3ta9`), Roger Levy (`wsqet`). The only related
    ones are the original 2016/17 elections paper (`osf.io/xmutz`, Dec 2019)
    and MisterCheerleader 4 (Paper A). Nothing for 2020.
  - OSF title search across all public registrations for "Madame",
    "Kamala", "Vice President", "election", "president", "pronoun".
    Nothing from this group.
  - Local text search for "prereg", "osf.io" and "AsPredicted" across
    `2020-madame-vice-president/` and the full `MadamePresident` mega-repo.
    The only preregistration is FrauKindergärtner's (on AsPredicted; a
    different study).
  - Slide text and speaker notes of both 2020 talks (CUNY 2021, UPenn
    LingLunch). No mention.
  - Veronica's Google Drive (2026-10-06): a full-text search
    for a prereg term ("preregistration", "pre-registration",
    "preregister", "pre-register", "AsPredicted", "osf") AND a project term
    ("Harris", "Madame", "Mme", "election", "Pence", "mmepr"). The only
    project hit was "Mme President 2024", which links the 2016 materials
    (`osf.io/gx5tr`), not a preregistration. Also read in full: "Madame Vice
    President: project organization" and "Madame Vice President CUNY
    2021" (abstract draft + comments). Neither mentions a preregistration.
- **Closest thing to a plan written in advance:** the "Madame Vice
  President: project organization" Google Doc has research questions and a
  planned analysis list ("Replicate all analyses from 2016, plus more";
  test each for a pre vs post interaction). Comments on it are dated
  2020-09-22, before data collection (10/30–11/10). But the doc was edited
  until 2020-11-17, so the version history would have to show which parts
  existed beforehand. Roger's power analysis
  (`2020-madame-vice-president/pilot-02/data-analysis/power-analysis.Rmd`)
  is also pre-data-collection.
- **Not checkable by us:** private AsPredicted entries; embargoed or
  private OSF registrations.
- **Email (Gmail, which also receives Veronica's MIT and Stanford mail;
  2026-10-06):** AsPredicted emails every listed author when a
  preregistration is created and when each author approves it. All 51
  AsPredicted emails were listed: they cover 2018–2022 studies (maze
  replications, MisterCheerleader 4, others), and none falls between
  Aug 2020 and Jan 2021. OSF notifications from Aug–Dec 2020 have no
  registration for this study. A body-text search for
  "preregistration"/"pre-registration"/"prereg"/"pre-reg" plus a project
  term (Harris, Madame, Mme, election, Pence, mmepr, "vice president",
  MVP) found no project emails (18 hits, all newsletters or unrelated).
- **Conclusion so far:** no evidence of a preregistration on which Veronica
  was an author. A registration by another author (e.g. Till), with Veronica
  not listed, can't be ruled out from her records.

## 2. Was the 2024 study preregistered? — open

- **Who might know:** Jacob Hoover Vigly (ran the Prolific data collection
  and the original analysis).
- **Checked (2026-10-06):** same OSF and local searches as #1, plus Jacob
  Hoover Vigly's OSF account (`vbszf`): no registrations. The 2024 analysis
  PDFs and HSP 2025 abstract/poster figures don't mention one.
  Google Drive: same search as #1; also read in full "Mme President 2024"
  (planning notes, Oct 2024: design, sample-size reasoning, jsPsych port)
  and "Madame President 2024 crucial analyses" (Dec 2024, post-hoc results
  write-up). Neither mentions a preregistration. The planning doc's
  sample-size reasoning was written before data collection (created
  2024-10-23).
- **Email:** same AsPredicted/OSF/keyword searches as #1; no AsPredicted
  emails after 2022, and no OSF registration notification for this study
  in Aug–Dec 2024.
- **Conclusion so far:** same as #1.
- Other 2024 co-authors who might know (from the Dec 2024 author-order
  email): Jacob Hoover Vigly, Socolof, Michaelov, Titus von der Malsburg,
  Roger Levy.

## 3. Why were 2 pre / 6 post 2024 participants excluded as duplicates? — closed (reproduced; not pursuing further)

- **Background:** the original 2024 pipeline used a private file linking
  each proliferate `workerid` to a Prolific ID (never in the public repo;
  Veronica doesn't have it). Besides same-`workerid` duplicate surveys, it
  removed `workerid`s linked to more than one Prolific ID and `workerid`s
  whose Prolific ID was linked to more than one `workerid` (in practice,
  one Prolific account starting the study more than once).
- **Resolved (2026-10-06):** the original's processed participant tables
  are exactly ours minus pre `1916, 2483` and post
  `3621, 3776, 3990, 4121, 4184, 4308`. These are now the
  `excl_original_prolific_dedup` column, and `2024/prep/
  validate_against_original.R` reproduces the original's counts exactly.
- **Not knowable without the private file:** which rule caught each one.
- **Decision (Veronica, 2026-10-06):** trust Prolific's controls that the
  post-election wave excluded pre-election participants and that there is
  about one response per person. So neither the per-case reasons nor
  cross-wave overlap (which nothing in the data can detect, because
  `workerid`s are wave-specific) will be followed up.

## 4. Prolific `Submission id` column in the public mmepr24 repo — not pursuing (decision 2026-10-06)

- The original public `2024-mmepr24` processed participant files include
  genuine Prolific submission IDs next to demographics. This needs a
  decision before any data release: scrub them going forward and/or rewrite
  that repo's history. `paper-b/` doesn't contain them.
- **Decision (Veronica, 2026-10-06):** leave the `mmepr24` repo as it is.

## 5. Prolific IDs typed into 2024 cloze responses — closed for `paper-b/`; not pursuing for `mmepr24` (decision 2026-10-06)

- Found 2026-10-06 by scanning all `paper-b/2024` CSVs for 24-hex-character
  strings (the Prolific ID format). Three cloze `response` values were
  Prolific IDs: pre workerid 1773; post workerids 3963, 3372.
- **Fixed in `paper-b/` (2026-10-06):** `2024/prep/redact_raw_free_text.R`
  replaces them with `REDACTED_PROLIFIC_ID` in `raw/` (byte sizes drop by
  exactly 4 bytes per ID, so nothing else changed). Regenerating
  `processed/` changed only those 3 cloze cells, which are still coded
  `other`. Git history was rewritten with `git filter-repo` before the repo
  got a remote, so no commit contains them.
- **Still public:** the same raw trial files
  (`data/mme_{pre,post}_election-trials.csv`) are in the public GitHub repo
  `vboyce/mmepr24`, so the 3 IDs are public there. Decision (Veronica,
  2026-10-06): leave that repo as it is (see also #4).
- Other identifier scans (2026-10-06, all `paper-b/` raw + processed files,
  including gzipped): no MTurk-WorkerId-shaped strings (`A` + 12–14
  uppercase/digits), no email addresses, no phone numbers. Long digit strings
  in `expectations`/`sessions` files are decimal slider proportions, not IDs.
