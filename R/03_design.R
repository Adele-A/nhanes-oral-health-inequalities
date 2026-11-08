# 03_design.R ------------------------------------------------------------------
# Build the NHANES complex-survey design on the FULL DEMO sample, then take the
# analytic subpopulation (adults 20+, non-missing outcome) as a survey DOMAIN via
# subsetting -- never by filtering the data before svydesign().

suppressPackageStartupMessages({
  library(here); library(survey)
})
source(here::here("R", "config.R"))

# Build svydesign on ALL participants (every DEMO row).
build_design <- function(dat) {
  # Single-PSU strata (if any) get a centered adjustment rather than an error.
  options(survey.lonely.psu = "adjust")
  survey::svydesign(
    id      = ~SDMVPSU,
    strata  = ~SDMVSTRA,
    weights = ~WTINT2YR,
    nest    = TRUE,
    data    = dat
  )
}

# Guard: the design must be built on the full sample, not a pre-filtered subset.
assert_full_design <- function(design, n_full) {
  n_design <- nrow(design$variables)
  if (!identical(as.integer(n_design), as.integer(n_full))) {
    stop(sprintf("Design built on %d rows but full sample has %d -- do not filter before svydesign().",
                 n_design, n_full), call. = FALSE)
  }
  invisible(TRUE)
}

# Domain = adults 20+ (keeps full design structure; correct for variance).
adult_design <- function(design) subset(design, is_adult == 1)

# Domain of adults with a non-missing value of `var` (complete-case for one
# outcome/covariate). Uses design row-subsetting so it accepts a dynamic column
# name and remains a proper survey domain.
domain_complete <- function(design, var) {
  v <- design$variables
  keep <- (v$is_adult == 1) & !is.na(v[[var]])
  design[keep, ]
}
