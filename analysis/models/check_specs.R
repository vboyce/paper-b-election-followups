# Check every spec in model_specs.R without fitting: builds the data for each
# study, checks the priors match model parameters, and
# generates the Stan code. Run locally before submitting fits.
#
#   Rscript analysis/models/check_specs.R

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
source(here("analysis", "models", "fit_model.R"))

model_data <- build_model_data("main")
jobs <- expand_grid(spec = names(model_specs), study = studies_to_fit)

results <- pmap(jobs, \(spec, study) {
  if (is.null(model_specs[[spec]]$formula)) return(tibble(spec, study, rows = NA, status = "no formula"))
  prepared <- prepare_fit(spec, study, "main", model_data)
  # validate_prior errors if a prior names a parameter the model doesn't have.
  validate_prior(prepared$prior, prepared$formula, data = prepared$data, family = prepared$family)
  make_stancode(prepared$formula, data = prepared$data, family = prepared$family, prior = prepared$prior)
  tibble(spec, study, rows = nrow(prepared$data), status = "ok")
}) |>
  list_rbind()
print(results, n = Inf)
