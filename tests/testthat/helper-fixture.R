# Shared setup for tests: load the SYNTHETIC fixture (no network) and source the
# pipeline functions. testthat sources helper-*.R before the test files.
suppressPackageStartupMessages({ library(here); library(readr) })
source(here::here("R", "config.R"))
source(here::here("R", "02_prepare.R"))
source(here::here("R", "03_design.R"))
source(here::here("R", "utils_reliability.R"))

load_fixture_raw <- function() {
  fx <- here::here("tests", "testthat", "fixtures")
  list(
    demo = readr::read_csv(file.path(fx, "demo_fixture.csv"), show_col_types = FALSE),
    ohq  = readr::read_csv(file.path(fx, "ohq_fixture.csv"),  show_col_types = FALSE),
    hiq  = readr::read_csv(file.path(fx, "hiq_fixture.csv"),  show_col_types = FALSE)
  )
}

fixture_data <- function() {
  r <- load_fixture_raw()
  derive_variables(r$demo, r$ohq, r$hiq)
}
