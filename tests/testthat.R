library(testthat)
library(here)
test_dir(here::here("tests", "testthat"), reporter = "summary", stop_on_failure = TRUE)
