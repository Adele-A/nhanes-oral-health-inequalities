#!/usr/bin/env Rscript
# run_all.R --------------------------------------------------------------------
# Single entry point for the whole analysis, reproducible from a clean clone:
#   download -> prepare -> design -> descriptives -> models -> exports -> render
# Run with:  Rscript run_all.R        (or source("run_all.R") in RStudio)
# No arguments; no manual steps. Requires renv::restore() to have been run first.

suppressPackageStartupMessages(library(here))

source(here::here("R", "config.R"))
source(here::here("R", "01_download.R"))
source(here::here("R", "02_prepare.R"))
source(here::here("R", "03_design.R"))
source(here::here("R", "utils_reliability.R"))
source(here::here("R", "04_descriptives.R"))
source(here::here("R", "05_models.R"))
source(here::here("R", "06_exports.R"))

step <- function(msg) message("\n==> ", msg)

render_report <- function() {
  qmd <- here::here("report", "oral_health_report.qmd")
  if (requireNamespace("quarto", quietly = TRUE)) {
    quarto::quarto_render(qmd, quiet = TRUE)
    return(invisible(TRUE))
  }
  q <- Sys.which("quarto")
  if (nzchar(q)) {
    status <- system2(q, c("render", shQuote(qmd)))
    if (!identical(status, 0L)) warning("quarto render returned status ", status)
  } else {
    warning("Quarto CLI not found on PATH; skipping HTML report render. ",
            "Install Quarto (https://quarto.org) to build report/oral_health_report.html")
  }
  invisible(TRUE)
}

main <- function() {
  ensure_dirs()

  step("1/7 Download NHANES 2017-2018 files (cached if present)")
  download_nhanes()

  step("2/7 Prepare: merge on SEQN, recode, derive outcomes & covariates")
  dat <- prepare_data(write_cache = TRUE)

  step("3/7 Build survey design on the FULL sample")
  design <- build_design(dat)
  assert_full_design(design, nrow(dat))

  step("4/7 Descriptive statistics (weighted %, 95% CI, reliability flags)")
  descr <- run_descriptives(design, write = TRUE)

  step("5/7 Regression models (OR + PR, Wald tests, sensitivity, forest plot)")
  models <- run_models(design, write = TRUE)

  step("6/7 Export star-schema CSVs for Power BI")
  build_exports(descr, models, write = TRUE)

  step("7/7 Render Quarto HTML report")
  render_report()

  # Console summary (key numbers; README figures must match these outputs)
  ov <- descr$prevalence[descr$prevalence$group_variable == "Overall", ]
  message("\n-------------------------------------------------------------")
  message(sprintf("Analytic adults 20+ (design subset): %d", nrow(subset(design, is_adult == 1)$variables)))
  message(sprintf("Overall no-visit-in-12mo prevalence: %.1f%% (95%% CI %.1f-%.1f)",
                  100*ov$estimate, 100*ov$ci_low, 100*ov$ci_high))
  message(sprintf("Design degrees of freedom: %d", survey::degf(subset(design, is_adult == 1))))
  message("Outputs: outputs/tables, outputs/figures, dashboard/data, report/oral_health_report.html")
  message("-------------------------------------------------------------")
  invisible(list(dat = dat, design = design, descr = descr, models = models))
}

if (sys.nframe() == 0L) {
  main()
}
