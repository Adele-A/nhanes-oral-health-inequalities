# 06_exports.R -----------------------------------------------------------------
# Build clean star-schema CSVs for Power BI from the PRE-COMPUTED, design-based
# estimates. Power BI cannot compute design-based variance, so it receives only
# finished estimates with CIs (never weighted microdata). UTF-8, '.' decimal.

suppressPackageStartupMessages({
  library(here); library(dplyr); library(readr)
})
source(here::here("R", "config.R"))

# Parse a model term like "income_cat<1.0 (below poverty)" into variable + level.
parse_term <- function(term) {
  vars <- c("age_group", "sex", "race", "educ", "income_cat_miss", "income_cat",
            "oral_health", "insurance")
  for (v in vars) if (startsWith(term, v)) {
    return(data.frame(covariate = v, level = sub(paste0("^", v), "", term)))
  }
  data.frame(covariate = term, level = NA_character_)
}

build_exports <- function(descr, models, write = TRUE) {
  dash <- PATHS$dash_data
  if (!dir.exists(dash)) dir.create(dash, recursive = TRUE, showWarnings = FALSE)

  # --- fact_estimates: prevalence estimates across outcomes & groups ----------
  keep_cols <- c("outcome", "group_variable", "group_level", "estimate",
                 "ci_low", "ci_high", "se", "n_unweighted", "df",
                 "reliability_flag", "reliable")
  fact_estimates <- dplyr::bind_rows(
    descr$prevalence[, intersect(keep_cols, names(descr$prevalence))],
    descr$unmet[,     intersect(keep_cols, names(descr$unmet))]
  ) |>
    dplyr::mutate(estimate_pct = 100 * estimate,
                  ci_low_pct  = 100 * ci_low,
                  ci_high_pct = 100 * ci_high,
                  estimate_id = dplyr::row_number())

  # --- fact_model_coefficients ------------------------------------------------
  parsed <- dplyr::bind_rows(lapply(models$coefficients$term, parse_term))
  fact_model <- models$coefficients |>
    dplyr::mutate(covariate = parsed$covariate, level = parsed$level,
                  coef_id = dplyr::row_number())

  # --- fact_reason & fact_unmet_reasons ---------------------------------------
  fact_reason <- descr$reason
  fact_unmet_reasons <- descr$unmet_reasons

  # --- dimension tables -------------------------------------------------------
  dim_outcome <- data.frame(
    outcome = c("No dental visit in past 12 months", "Self-reported unmet dental need"),
    definition = c("OHQ030 in {3,4,5,6,7}; utilization indicator, not proven unmet need",
                   "OHQ770 == 1 (needed dental care in past year but could not get it)"),
    higher_means = c("less recent dental-care use", "more self-reported unmet need")
  )
  dim_reliability <- data.frame(
    reliability_flag = c("reliable", "review", "suppress"),
    meaning = c("Meets NCHS Data Presentation Standards for Proportions (Parker et al. 2017)",
                "Present with caution: wide CI / low df / small effective n",
                "Do not present: unweighted denominator < 30")
  )
  dim_group <- data.frame(group_variable = unique(fact_estimates$group_variable))

  if (write) {
    readr::write_csv(fact_estimates,      file.path(dash, "fact_estimates.csv"))
    readr::write_csv(fact_model,          file.path(dash, "fact_model_coefficients.csv"))
    readr::write_csv(fact_reason,         file.path(dash, "fact_reason_for_visit.csv"))
    readr::write_csv(fact_unmet_reasons,  file.path(dash, "fact_unmet_need_reasons.csv"))
    readr::write_csv(dim_outcome,         file.path(dash, "dim_outcome.csv"))
    readr::write_csv(dim_reliability,     file.path(dash, "dim_reliability.csv"))
    readr::write_csv(dim_group,           file.path(dash, "dim_group_variable.csv"))
  }

  invisible(list(fact_estimates = fact_estimates, fact_model = fact_model,
                 dim_outcome = dim_outcome, dim_reliability = dim_reliability,
                 dim_group = dim_group))
}
