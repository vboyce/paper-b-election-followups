# One-time setup on Engaging: install the R packages and CmdStan the models
# need into the default per-user R library (~/R/x86_64-pc-linux-gnu-library/4.4,
# set by the r/4.4.0 module; see env.sh). Run through install_packages.slurm.
#
# Deliberately does NOT set R_LIBS_USER: an override pointing at an empty
# library hides the installed packages (see the r-hpc-env notes).

cmdstan_version <- "2.38.0"
# Individual tidyverse packages, not the meta-package (see analysis_data.R).
cran_packages <- c("dplyr", "tidyr", "readr", "purrr", "stringr", "tibble", "here", "brms", "posterior")

user_library <- Sys.getenv("R_LIBS_USER")
stopifnot(nzchar(user_library))
dir.create(user_library, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(user_library, .libPaths()))
message("Installing into: ", user_library)

options(repos = c(stan = "https://stan-dev.r-universe.dev", CRAN = "https://cloud.r-project.org"))
install.packages(c(cran_packages, "cmdstanr"), lib = user_library, Ncpus = 8)

library(cmdstanr)
cmdstanr::install_cmdstan(version = cmdstan_version, cores = 8, overwrite = FALSE)

# Verify everything loads from a fresh perspective, and fail loudly if not.
for (pkg in c(cran_packages, "cmdstanr")) {
  if (!requireNamespace(pkg, quietly = TRUE)) stop("Package did not install: ", pkg)
}
stopifnot(cmdstanr::cmdstan_version() == cmdstan_version)
message("Installed: brms ", packageVersion("brms"), ", cmdstanr ", packageVersion("cmdstanr"),
        ", CmdStan ", cmdstanr::cmdstan_version(), " at ", cmdstanr::cmdstan_path())

# End-to-end check: compile and sample a tiny brms model through cmdstanr.
library(brms)
smoke_data <- data.frame(y = rnorm(50, 600, 100), x = rep(c(-0.5, 0.5), 25))
smoke_fit <- brm(y ~ x, data = smoke_data, family = exgaussian(), backend = "cmdstanr",
                 chains = 2, cores = 2, iter = 500, refresh = 0, seed = 1)
stopifnot(inherits(smoke_fit, "brmsfit"), nrow(as_draws_df(smoke_fit)) == 500)
message("Smoke test passed: brms + cmdstanr fitted a model.")
