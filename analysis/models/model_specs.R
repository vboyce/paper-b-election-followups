# Model specifications: write formulas (and later priors) here.
#
# Each entry of `model_specs` names a dataset from build_model_data()
# (analysis/models/model_data.R) and gives a brms formula and family. A
# formula left as NULL is not fitted; the fitting script stops if asked to
# fit one.
#
# Variables available in every dataset (one value per session):
#   session_id          participant/session (one trial each, so usually not a grouping factor)
#   study               factor: "2020", "2024"
#   study_c             2020 = -0.5, 2024 = +0.5
#   round               factor: "pre", "post"
#   round_c             pre = -0.5, post = +0.5
#   task                "maze", "spr", "cloze" (or "mazerace", not in these datasets)
#   task_order          factor: "task_first", "event_first" (sliders before the task)
#   task_first          TRUE if the critical task came before the sliders
#   expectation_target  factor: "president", "vice_president" (2020 only; NA in 2024)
#   party               factor: "Democrat", "Republican", "Independent", "other / none / didn't say"
#   preference          factor: "democratic_candidate", "republican_candidate", "neither_or_no_answer"
#   expect_prob_dem     the session's slider P(Democratic candidate wins); NA if all sliders were 0
#
# Reading datasets: maze_pronoun_1, maze_pronoun_2, spr_pronoun_1, spr_pronoun_2
#   One row per session. Maze: the pronoun word. SPR: the region = the pronoun
#   and the next three words, pooled (decided 2026-10-08; alternatives in TODO.md).
#   item                sentence item (sentence 1 for *_pronoun_1, sentence 2 for *_pronoun_2),
#                       prefixed with the study: "2020-3", "2024-7"
#   pronoun_1           factor: "he" (reference), "she", "they"
#   pronoun_2           factor: "he" (reference), "she", "they"
#   pronoun_pair        factor: "he–he", "she–she", "they–they", "he–she", "she–he"
#   pair_match          factor: "match", "mismatch" (pronoun 2 = pronoun 1 or not)
#   rt, log_rt          Maze: first-choice time at the pronoun, ms, as recorded.
#                       SPR: arithmetic mean RT over the four region words, ms
#   rt_in_window        Maze: rt within the analysis RT window (180-5000 ms by default).
#                       SPR: every one of the four region words is within it
#   word_position, word, word_length   Maze only: 0, the word shown, its length
#   maze_correct        Maze only: chose the correct word on the first try
#   Filter in the model script, e.g. subset(rt_in_window & maze_correct).
#
# cloze: one row per session (nonsense completions already excluded)
#   item                cloze item, prefixed with the study
#   first_target_pronoun  factor: "he" (reference), "she", "they", "hedged", "none":
#                       first pronoun referring to the target office-holder
#                       (2020: vice president; 2024: president)
#   has_target_pronoun  TRUE if there is one
#   first_is_she        1 = she, 0 = he; NA if the first target pronoun is neither
#   first_is_they       1 = they, 0 = she or he; NA otherwise
#   coref_she, coref_he, coref_they, coref_hedge:   a pronoun of that kind refers to
#                       the target office-holder (anywhere; several can be TRUE)
#   coref_other_*       same, for the holder of the other office
#   has_female_candidate_name (Harris), has_male_candidate_name (2020 Pence, 2024 Trump),
#   has_other_candidate_name (2020 Biden/Trump), has_target_office_np, has_other_office_np,
#   has_generic_np      references anywhere in the completion (see DATA.md)
#   cloze_code          first referring expression of any kind
#
# expectations: one row per session (sessions with all sliders at 0 excluded)
#   expect_prob_dem     slider_dem / (slider_dem + slider_rep + slider_other)
#   prob_dem_two_party  slider_dem / (slider_dem + slider_rep)
#   slider_dem, slider_rep, slider_other   raw slider values (0-100)
#
# recall: one row per Maze/SPR session that answered the recall question
#   item                the reading trial's sentence-1 item
#   pronoun_1, pronoun_2, pronoun_pair   as for the reading datasets
#   recall              factor: "female candidate", "male candidate", "Writer is unsure",
#                       "I don't remember"
#   recall_response     the answer as given (candidate names)

# The tidyverse packages this code uses, loaded individually: the full
# tidyverse meta-package can't be installed on Engaging (no fontconfig /
# freetype headers for its font dependencies).
library(dplyr)
library(tidyr)
library(readr)
library(purrr)
library(stringr)
library(tibble)
library(brms)

# Settings shared by every fit. Each study (2020, 2024) is fitted separately.
fit_settings <- list(
  chains = 4,
  cores = 4,                         # chains run in parallel
  iter = 2000,                       # per chain, including warmup
  warmup = 1000,
  control = list(adapt_delta = 0.95),
  backend = "cmdstanr",
  seed = 2026
)
studies_to_fit <- c("2020", "2024")

# Priors ---------------------------------------------------------------------

# RT outcomes (raw ms, ex-Gaussian). brms's exgaussian(): mu = the mean RT
# (Gaussian mean + tail mean), sigma = SD of the Gaussian part, beta = mean
# of the exponential tail. Effects (b) are on mu, in ms.
# Values chosen 2026-10-07 from all critical-sentence words (in-window; Maze
# correct on first try). An ex-Gaussian fit gives Maze: mean 1086, Gaussian
# SD 98, tail mean 484 (per-session tails 231-589, 10th-90th pct); SPR: mean
# 543, Gaussian SD 55, tail mean 280 (per-session 48-252). RT SD: Maze 521,
# SPR 377. The intercept, effects and random-effect SDs share one prior SD
# per task. brms's default prior on beta, gamma(1, 0.1), has mean 10 ms, far
# too small for RTs in ms, so beta always gets an explicit prior here.
rt_priors <- function(intercept_mean, prior_sd, tail_mean, tail_sd, sigma_sd) {
  c(
    set_prior(sprintf("normal(%d, %d)", intercept_mean, prior_sd), class = "Intercept"),
    set_prior(sprintf("normal(0, %d)", prior_sd), class = "b"),
    set_prior(sprintf("normal(0, %d)", prior_sd), class = "sd"),
    set_prior("lkj(1)", class = "cor"),
    set_prior(sprintf("normal(%d, %d)", tail_mean, tail_sd), class = "beta"),
    set_prior(sprintf("normal(0, %d)", sigma_sd), class = "sigma")
  )
}
# At the pronoun itself Maze RTs run higher (2026-10-08 fits: mean 1298-1404,
# tail 699-782), still within about 1 prior SD; kept the all-word priors on
# purpose and let the data move the estimates.
maze_priors <- rt_priors(intercept_mean = 1000, prior_sd = 500, tail_mean = 500, tail_sd = 250, sigma_sd = 200)
# Checked 2026-10-08 against the pooled SPR region (mean of pronoun + 3, in
# window): ex-Gaussian maximum-likelihood fits per study x pronoun give mean
# 499-564, Gaussian SD 47-68, tail mean 234-257, inside the SPR priors.
spr_priors <- rt_priors(intercept_mean = 600, prior_sd = 400, tail_mean = 300, tail_sd = 150, sigma_sd = 100)

# Logistic / multinomial outcomes (logit scale).
logit_priors <- c(
  set_prior("normal(0, 1)", class = "Intercept"),
  set_prior("normal(0, 1)", class = "b"),
  set_prior("normal(0, 1)", class = "sd"),
  set_prior("lkj(1)", class = "cor")
)
# For the categorical family each non-reference category has its own linear
# predictor (mushe, muthey, muhedged), so the priors are set per category.
categorical_priors <- function(categories) {
  map(categories, \(category) {
    dpar <- paste0("mu", category)
    c(
      set_prior("normal(0, 1)", class = "Intercept", dpar = dpar),
      set_prior("normal(0, 1)", class = "b", dpar = dpar),
      set_prior("normal(0, 1)", class = "sd", dpar = dpar)
    )
  }) |>
    reduce(c) |>
    c(set_prior("lkj(1)", class = "cor"))
}

# Row filters (applied before fitting) ----------------------------------------

maze_rows <- function(df) filter(df, rt_in_window, maze_correct)
spr_rows <- function(df) filter(df, rt_in_window)

# Specs ------------------------------------------------------------------------
# Maximal random effects by item. Back off if a model doesn't fit well.

model_specs <- list(
  maze_pronoun_1 = list(
    data = "maze_pronoun_1",
    rows = maze_rows,
    formula = bf(rt ~ pronoun_1 * round_c + (pronoun_1 * round_c | item)),
    family = exgaussian(),
    prior = maze_priors
  ),
  # pronoun_pair rather than pronoun_2 * pair_match: "they" only occurs in
  # matching pairs, so they x mismatch would be an empty cell.
  maze_pronoun_2 = list(
    data = "maze_pronoun_2",
    rows = maze_rows,
    formula = bf(rt ~ pronoun_pair * round_c + (pronoun_pair * round_c | item)),
    family = exgaussian(),
    prior = maze_priors
  ),
  spr_pronoun_1 = list(
    data = "spr_pronoun_1",
    rows = spr_rows,
    formula = bf(rt ~ pronoun_1 * round_c + (pronoun_1 * round_c | item)),
    family = exgaussian(),
    prior = spr_priors
  ),
  spr_pronoun_2 = list(
    data = "spr_pronoun_2",
    rows = spr_rows,
    formula = bf(rt ~ pronoun_pair * round_c + (pronoun_pair * round_c | item)),
    family = exgaussian(),
    prior = spr_priors
  ),
  # Among completions whose first target pronoun is she or he.
  cloze_she_vs_he = list(
    data = "cloze",
    rows = \(df) filter(df, !is.na(first_is_she)),
    formula = bf(first_is_she ~ round_c + (round_c | item)),
    family = bernoulli(),
    prior = logit_priors
  ),
  # Among completions whose first target pronoun is they, she or he.
  cloze_they_vs_gendered = list(
    data = "cloze",
    rows = \(df) filter(df, !is.na(first_is_they)),
    formula = bf(first_is_they ~ round_c + (round_c | item)),
    family = bernoulli(),
    prior = logit_priors
  ),
  # Among completions with a target pronoun: he (reference), she, they,
  # hedged ("both"). Hedged is very rare (0 in 2020 post, 1 in 2024 post).
  cloze_multinomial = list(
    data = "cloze",
    rows = \(df) filter(df, has_target_pronoun) |> mutate(first_target_pronoun = droplevels(first_target_pronoun)),
    formula = bf(first_target_pronoun ~ round_c + (round_c | item)),
    family = categorical(),
    prior = categorical_priors(c("she", "they", "hedged"))
  )
)

# TODO (Veronica): add versions with gender / politics (party, preference) as predictors.
