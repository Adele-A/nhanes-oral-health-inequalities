suppressPackageStartupMessages(library(survey))
source(here::here("R", "05_models.R"))

test_that("reference levels are set as specified", {
  dat <- fixture_data()
  des <- set_reference_levels(build_design(dat))
  expect_equal(levels(des$variables$income_cat)[1], REF_LEVELS$income)
  expect_equal(levels(des$variables$educ)[1], REF_LEVELS$educ)
  expect_equal(levels(des$variables$race)[1], REF_LEVELS$race)
})

test_that("OR and PR models fit and tidy to finite estimates with design df", {
  dat <- fixture_data()
  des <- set_reference_levels(build_design(dat))
  dom <- model_domain(des, "income_cat")
  dd  <- survey::degf(dom)
  m <- fit_models(dom, "income_cat")
  or <- tidy_exp(m$or, "OR", "test", dd)
  pr <- tidy_exp(m$pr, "PR", "test", dd)
  expect_true(all(is.finite(or$estimate)))
  expect_true(all(is.finite(or$ci_low)) && all(is.finite(or$ci_high)))
  expect_true(all(or$estimate > 0))                 # odds ratios are positive
  expect_true(all(is.finite(pr$estimate)))
  expect_true(all(c("ci_low", "ci_high", "p_value") %in% names(or)))
})

test_that("Wald test runs on the design df", {
  dat <- fixture_data()
  des <- set_reference_levels(build_design(dat))
  dom <- model_domain(des, "income_cat")
  dd  <- survey::degf(dom)
  m <- fit_models(dom, "income_cat")
  w <- wald_tests(m$or, "income_cat", "test", dd)
  expect_equal(w$ddf, dd)
  expect_true(is.finite(w$p_value))
})
