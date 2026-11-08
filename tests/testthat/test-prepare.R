test_that("fixture is read and full sample is retained after merge", {
  raw <- load_fixture_raw()
  dat <- fixture_data()
  expect_equal(nrow(dat), nrow(raw$demo))          # left join to DEMO keeps everyone
  expect_false(any(duplicated(dat$SEQN)))          # SEQN unique
})

test_that("reserved missing codes are recoded to NA", {
  dat <- fixture_data()
  expect_false(any(dat$OHQ030 %in% c(77, 99), na.rm = TRUE))
  expect_false(any(dat$DMDEDUC2 %in% c(7, 9), na.rm = TRUE))
  expect_false(any(dat$OHQ845 %in% c(7, 9), na.rm = TRUE))
  expect_false(any(dat$HIQ011 %in% c(7, 9), na.rm = TRUE))
})

test_that("primary outcome is coded correctly from OHQ030", {
  dat <- fixture_data()
  expect_true(all(dat$no_recent_visit %in% c(0L, 1L, NA)))
  # {1,2} -> 0 ; {3..7} -> 1
  expect_true(all(dat$no_recent_visit[dat$OHQ030 %in% c(1, 2)] == 0))
  expect_true(all(dat$no_recent_visit[dat$OHQ030 %in% c(3, 4, 5, 6, 7)] == 1))
  expect_true(all(is.na(dat$no_recent_visit[is.na(dat$OHQ030)])))
})

test_that("no one under 20 enters the analytic (adult) subset", {
  dat <- fixture_data()
  adults <- dat[dat$is_adult == 1, ]
  expect_true(all(adults$RIDAGEYR >= 20))
  expect_equal(sum(dat$is_adult), sum(dat$RIDAGEYR >= 20))
})

test_that("derived factors have the expected levels", {
  dat <- fixture_data()
  expect_setequal(levels(dat$race), unname(RACE_LEVELS))
  expect_true("Missing" %in% levels(dat$income_cat_miss))
  expect_setequal(levels(dat$oral_health), ORALHEALTH_LEVELS)
  # education never defined for under-20s
  expect_true(all(is.na(dat$educ[dat$RIDAGEYR < 20])))
})

test_that("reason_visit is only defined for visits within 12 months", {
  dat <- fixture_data()
  expect_true(all(is.na(dat$reason_visit[!(dat$OHQ030 %in% c(1, 2))])))
})
