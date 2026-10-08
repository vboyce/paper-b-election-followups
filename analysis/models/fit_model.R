# Fit one model from model_specs.R for one study, and save the brmsfit.
#
#   Rscript analysis/models/fit_model.R <spec> <study> [set]
#   Rscript analysis/models/fit_model.R maze_pronoun_1 2024
#   Rscript analysis/models/fit_model.R spr_pronoun_1 2020 high_attention
#
# Output: analysis/models/fits/<spec>_<study>_<set>.rds
# Run from the repo root (here() finds it from paper-b.Rproj).

# The tidyverse packages this code uses, loaded individually: the full
# tidyverse meta-package can't be installed on Engaging (no fontconfig /
# freetype headers for its font dependencies).
library(dplyr)
library(tidyr)
library(readr)
library(purrr)
library(stringr)
library(tibble)
library(here)
library(brms)
source(here("analysis", "models", "model_data.R"))
source(here("analysis", "models", "model_specs.R"))

# Everything a fit needs, built and checked; used by check_specs.R too.
prepare_fit <- function(spec_name, study, set = "main", model_data = NULL) {
  if (!spec_name %in% names(model_specs)) stop("No spec called '", spec_name, "' in model_specs.R")
  spec <- model_specs[[spec_name]]
  if (is.null(spec$formula)) stop("Spec '", spec_name, "' has no formula yet")
  if (!study %in% studies_to_fit) stop("study must be one of: ", paste(studies_to_fit, collapse = ", "))

  if (is.null(model_data)) model_data <- build_model_data(set)
  df <- model_data[[spec$data]] |>
    filter(study == !!study) |>
    spec$rows()
  if (nrow(df) == 0) stop("No rows left for ", spec_name, " / ", study)
  # One trial per session: a model with one row per session must not repeat sessions.
  if (anyDuplicated(df$session_id)) stop(spec_name, " / ", study, ": a session appears more than once")

  label <- paste0(spec_name, "_", study, "_", set)
  list(label = label, data = df, formula = spec$formula, family = spec$family, prior = spec$prior)
}

fit_one <- function(prepared) {
  out_dir <- here("analysis", "models", "fits")
  dir.create(out_dir, showWarnings = FALSE)
  out_file <- file.path(out_dir, paste0(prepared$label, ".rds"))
  message("Fitting ", prepared$label, " on ", nrow(prepared$data), " rows -> ", out_file)
  model_data <- prepared$data
  fit <- brm(prepared$formula, data = model_data, family = prepared$family, prior = prepared$prior,
             chains = fit_settings$chains, cores = fit_settings$cores, iter = fit_settings$iter,
             warmup = fit_settings$warmup, control = fit_settings$control, backend = fit_settings$backend,
             seed = fit_settings$seed, file = out_file, file_refit = "on_change")
  print(summary(fit))
  invisible(fit)
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 2 || length(args) > 3) {
    stop("Usage: Rscript analysis/models/fit_model.R <spec> <study> [set]")
  }
  set <- if (length(args) == 3) args[3] else "main"
  fit_one(prepare_fit(args[1], args[2], set))
}
