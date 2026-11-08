# utils_reliability.R ----------------------------------------------------------
# NCHS Data Presentation Standards for Proportions (Parker et al. 2017,
# Vital Health Stat 2(175)). Flags/suppresses survey proportion estimates that
# do not meet reliability standards, based on:
#   (1) a minimum unweighted denominator,
#   (2) the (relative) width of the Korn-Graubard confidence interval,
#   (3) the design degrees of freedom,
#   (4) the effective sample size.
# Implemented as a pure, vectorizable function with testthat coverage.

source(here::here("R", "config.R"))

# Reliability of a single proportion estimate.
#   estimate   proportion in [0, 1]
#   ci_lower,  ci_upper   Korn-Graubard (beta) 95% CI bounds in [0, 1]
#   n          unweighted denominator (sample size of the subgroup)
#   df         design degrees of freedom (degf(design))
#   se         (optional) design-based standard error of the proportion
# Returns a one-row data.frame: flag in {"reliable","review","suppress"},
# reliable (logical), and a human-readable reason.
assess_proportion <- function(estimate, ci_lower, ci_upper, n, df, se = NA_real_,
                              thresholds = RELIABILITY) {
  if (is.na(estimate) || is.na(n)) {
    return(data.frame(flag = "suppress", reliable = FALSE,
                      reason = "missing estimate or denominator",
                      stringsAsFactors = FALSE))
  }

  reasons <- character(0)

  # (1) minimum denominator
  if (n < thresholds$min_n) {
    reasons <- c(reasons, sprintf("n=%d < %d", n, thresholds$min_n))
  }

  # (2) relative CI width. NCHS evaluates the width relative to the estimate,
  #     using the complement (1 - p) when p > 0.5 (the nearer tail), so a high
  #     prevalence is judged as fairly as its complementary low prevalence.
  abs_ciw <- ci_upper - ci_lower
  denom   <- if (estimate <= 0.5) estimate else (1 - estimate)
  rel_ciw <- if (denom > 0) abs_ciw / denom else Inf
  if (is.finite(rel_ciw) && rel_ciw > thresholds$max_rel_ciw) {
    reasons <- c(reasons, sprintf("relative CI width %.0f%% > %.0f%%",
                                  100 * rel_ciw, 100 * thresholds$max_rel_ciw))
  }

  # (3) design degrees of freedom
  if (!is.na(df) && df < thresholds$min_df) {
    reasons <- c(reasons, sprintf("df=%g < %d", df, thresholds$min_df))
  }

  # (4) effective sample size (when SE is available):
  #     n_eff = p(1-p) / SE^2  -- smaller than n under a complex design.
  if (!is.na(se) && se > 0) {
    n_eff <- estimate * (1 - estimate) / (se^2)
    if (is.finite(n_eff) && n_eff < thresholds$min_neff) {
      reasons <- c(reasons, sprintf("effective n=%.0f < %d", n_eff, thresholds$min_neff))
    }
  }

  # A degenerate 0% or 100% estimate cannot have a meaningful relative width and
  # is flagged for review rather than silently presented.
  if (estimate %in% c(0, 1) && !("suppress" %in% reasons)) {
    reasons <- c(reasons, "estimate at 0% or 100% (complementary-rule review)")
  }

  if (length(reasons) == 0) {
    data.frame(flag = "reliable", reliable = TRUE, reason = "meets NCHS standards",
               stringsAsFactors = FALSE)
  } else {
    # Too-small denominator -> suppress; other failures -> review (present w/ flag).
    too_small <- n < thresholds$min_n
    data.frame(flag = if (too_small) "suppress" else "review",
               reliable = FALSE, reason = paste(reasons, collapse = "; "),
               stringsAsFactors = FALSE)
  }
}

# Apply assess_proportion row-wise over a data.frame of estimates.
# Expects columns: estimate, ci_low, ci_high, n_unweighted, df (and optional se).
add_reliability <- function(df_est) {
  stopifnot(all(c("estimate","ci_low","ci_high","n_unweighted","df") %in% names(df_est)))
  se_col <- if ("se" %in% names(df_est)) df_est$se else rep(NA_real_, nrow(df_est))
  res <- do.call(rbind, lapply(seq_len(nrow(df_est)), function(i) {
    assess_proportion(df_est$estimate[i], df_est$ci_low[i], df_est$ci_high[i],
                      df_est$n_unweighted[i], df_est$df[i], se_col[i])
  }))
  cbind(df_est, reliability_flag = res$flag, reliable = res$reliable,
        reliability_reason = res$reason)
}
