suppressPackageStartupMessages(library(survey))

test_that("design is built on the FULL sample and the guard enforces it", {
  dat <- fixture_data()
  des <- build_design(dat)
  expect_equal(nrow(des$variables), nrow(dat))
  expect_silent(assert_full_design(des, nrow(dat)))
  expect_error(assert_full_design(des, nrow(dat) - 1), "do not filter")
})

test_that("adult domain keeps only 20+ and matches the data", {
  dat <- fixture_data()
  des <- build_design(dat)
  ad <- adult_design(des)
  expect_true(all(ad$variables$RIDAGEYR >= 20))
  expect_equal(nrow(ad$variables), sum(dat$is_adult))
})

test_that("domain_complete drops missing-outcome and under-20 records", {
  dat <- fixture_data()
  des <- build_design(dat)
  d <- domain_complete(des, "no_recent_visit")
  expect_true(all(d$variables$RIDAGEYR >= 20))
  expect_false(any(is.na(d$variables$no_recent_visit)))
})

test_that("a weighted proportion on the adult domain is a valid probability", {
  dat <- fixture_data()
  des <- build_design(dat)
  d <- domain_complete(des, "no_recent_visit")
  p <- as.numeric(survey::svyciprop(~I(no_recent_visit == 1), d, method = "beta"))
  expect_gte(p, 0); expect_lte(p, 1)
})
