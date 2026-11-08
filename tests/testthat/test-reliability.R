test_that("a well-estimated proportion is flagged reliable", {
  r <- assess_proportion(estimate = 0.40, ci_lower = 0.35, ci_upper = 0.45,
                         n = 500, df = 15, se = 0.025)
  expect_true(r$reliable)
  expect_equal(r$flag, "reliable")
})

test_that("small denominator is suppressed", {
  r <- assess_proportion(estimate = 0.40, ci_lower = 0.10, ci_upper = 0.80,
                         n = 12, df = 15, se = 0.18)
  expect_false(r$reliable)
  expect_equal(r$flag, "suppress")
})

test_that("a wide relative CI (adequate n) is flagged for review", {
  r <- assess_proportion(estimate = 0.05, ci_lower = 0.01, ci_upper = 0.20,
                         n = 200, df = 15, se = 0.05)
  expect_false(r$reliable)
  expect_equal(r$flag, "review")
})

test_that("too few degrees of freedom is flagged", {
  r <- assess_proportion(estimate = 0.40, ci_lower = 0.33, ci_upper = 0.47,
                         n = 300, df = 4, se = 0.03)
  expect_false(r$reliable)
  expect_match(r$reason, "df")
})

test_that("a degenerate 0% estimate is not silently presented", {
  r <- assess_proportion(estimate = 0, ci_lower = 0, ci_upper = 0.02,
                         n = 300, df = 15, se = 0.005)
  expect_false(r$reliable)
})

test_that("add_reliability appends flag columns to a data frame", {
  df <- data.frame(estimate = c(0.4, 0.4), ci_low = c(0.35, 0.10),
                   ci_high = c(0.45, 0.80), n_unweighted = c(500, 12),
                   df = c(15, 15), se = c(0.025, 0.18))
  out <- add_reliability(df)
  expect_true(all(c("reliability_flag", "reliable", "reliability_reason") %in% names(out)))
  expect_equal(out$reliability_flag, c("reliable", "suppress"))
})
