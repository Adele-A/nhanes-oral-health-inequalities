# 04_descriptives.R ------------------------------------------------------------
# Design-based descriptive statistics for the 20+ domain:
#   - Table 1 (unweighted n, weighted %) of sample characteristics
#   - primary-outcome prevalence (no visit in past 12 mo) by each sociodemographic
#     group, with Korn-Graubard 95% CI, unweighted n, and NCHS reliability flags
#   - secondary outcomes: reason for last visit, self-reported unmet need + reasons
# All proportions are weighted; all CIs are design-based; df from degf(design).

suppressPackageStartupMessages({
  library(here); library(survey); library(dplyr); library(ggplot2); library(readr)
})
source(here::here("R", "config.R"))
source(here::here("R", "03_design.R"))
source(here::here("R", "utils_reliability.R"))

# Grouping covariates used for prevalence breakdowns (label -> column).
GROUP_VARS <- c(
  "Age group"           = "age_group",
  "Sex"                 = "sex",
  "Race/ethnicity"      = "race",
  "Education"           = "educ",
  "Family income (PIR)" = "income_cat_miss",
  "Self-rated oral health" = "oral_health",
  "Insurance"           = "insurance"
)

# Weighted proportion + Korn-Graubard CI for a binary 0/1 variable, overall.
svy_prop <- function(design, var) {
  f  <- stats::as.formula(paste0("~I(", var, " == 1)"))
  ci <- survey::svyciprop(f, design, method = "beta")
  b  <- attr(ci, "ci")
  data.frame(estimate = as.numeric(ci), se = as.numeric(survey::SE(ci)),
             ci_low = b[[1]], ci_high = b[[2]], row.names = NULL)
}

# Prevalence of a binary outcome by the levels of one grouping covariate.
prevalence_by <- function(design, outcome, group, outcome_label, group_label) {
  v <- design$variables
  d <- design[v$is_adult == 1 & !is.na(v[[outcome]]) & !is.na(v[[group]]), ]
  by <- survey::svyby(stats::as.formula(paste0("~I(", outcome, " == 1)")),
                      stats::as.formula(paste0("~", group)),
                      d, survey::svyciprop, vartype = c("se", "ci"), method = "beta")
  # svyby columns with vartype=c("se","ci"): [group, estimate, se, ci_l, ci_u].
  # Use the fixed position for se (grepping "^se" would also catch group "sex").
  ntab   <- table(droplevels(factor(d$variables[[group]])))
  lev     <- as.character(by[[group]])
  data.frame(
    outcome        = outcome_label,
    group_variable = group_label,
    group_level    = lev,
    estimate       = as.numeric(by[[2]]),
    se             = as.numeric(by[[3]]),
    ci_low         = as.numeric(by[["ci_l"]]),
    ci_high        = as.numeric(by[["ci_u"]]),
    df             = survey::degf(d),
    n_unweighted   = as.integer(ntab[lev]),
    row.names = NULL
  )
}

# Overall (all adults) prevalence as a one-row "Overall" group.
prevalence_overall <- function(design, outcome, outcome_label) {
  v <- design$variables
  d <- design[v$is_adult == 1 & !is.na(v[[outcome]]), ]
  p <- svy_prop(d, outcome)
  data.frame(outcome = outcome_label, group_variable = "Overall", group_level = "All adults 20+",
             estimate = p$estimate, se = p$se, ci_low = p$ci_low, ci_high = p$ci_high,
             df = survey::degf(d), n_unweighted = nrow(d$variables), row.names = NULL)
}

# Weighted distribution (n unweighted + weighted %) of a categorical covariate.
weighted_dist <- function(design, var, var_label) {
  v <- design$variables
  d <- design[v$is_adult == 1 & !is.na(v[[var]]), ]
  m <- survey::svymean(stats::as.formula(paste0("~", var)), d)
  lev <- levels(droplevels(factor(d$variables[[var]])))
  ntab <- table(droplevels(factor(d$variables[[var]])))
  nm <- paste0(var, lev)
  data.frame(
    variable = var_label, level = lev,
    n_unweighted = as.integer(ntab[lev]),
    weighted_pct = 100 * as.numeric(coef(m)[nm]),
    weighted_pct_se = 100 * as.numeric(survey::SE(m)[nm]),
    row.names = NULL
  )
}

# --- Orchestrator -------------------------------------------------------------
run_descriptives <- function(design, write = TRUE) {
  ensure_dirs()
  options(survey.lonely.psu = "adjust")

  # Table 1: sample characteristics (weighted %) + weighted mean age
  table1 <- dplyr::bind_rows(lapply(names(GROUP_VARS), function(lbl)
    weighted_dist(design, GROUP_VARS[[lbl]], lbl)))

  # Primary-outcome prevalence by every group (+ overall) with reliability flags
  prev <- dplyr::bind_rows(
    prevalence_overall(design, "no_recent_visit", "No dental visit in past 12 months"),
    dplyr::bind_rows(lapply(names(GROUP_VARS), function(lbl)
      prevalence_by(design, "no_recent_visit", GROUP_VARS[[lbl]],
                    "No dental visit in past 12 months", lbl)))
  )
  prev <- add_reliability(prev)

  # Secondary: unmet need prevalence overall + by income and insurance
  unmet <- dplyr::bind_rows(
    prevalence_overall(design, "unmet_need", "Self-reported unmet dental need"),
    prevalence_by(design, "unmet_need", "income_cat_miss",
                  "Self-reported unmet dental need", "Family income (PIR)"),
    prevalence_by(design, "unmet_need", "insurance",
                  "Self-reported unmet dental need", "Insurance")
  )
  unmet <- add_reliability(unmet)

  # Secondary: reason for last visit (weighted %), among visit within 12 months
  reason <- reason_distribution(design)

  # Secondary: reasons unmet need could not be met (OHQ780A-K) among unmet_need==1
  unmet_reasons <- unmet_need_reasons(design)

  if (write) {
    readr::write_csv(table1,        file.path(PATHS$out_tables, "table1_characteristics.csv"))
    readr::write_csv(prev,          file.path(PATHS$out_tables, "prevalence_by_group.csv"))
    readr::write_csv(unmet,         file.path(PATHS$out_tables, "unmet_need_by_group.csv"))
    readr::write_csv(reason,        file.path(PATHS$out_tables, "reason_for_visit.csv"))
    readr::write_csv(unmet_reasons, file.path(PATHS$out_tables, "unmet_need_reasons.csv"))
    make_prevalence_figure(prev)
  }

  invisible(list(table1 = table1, prevalence = prev, unmet = unmet,
                 reason = reason, unmet_reasons = unmet_reasons))
}

# Weighted distribution of reason_visit (among adults with a visit in 12 months),
# overall and by income.
reason_distribution <- function(design) {
  v <- design$variables
  d <- design[v$is_adult == 1 & !is.na(v$reason_visit), ]
  overall <- survey::svymean(~reason_visit, d)
  lev <- levels(d$variables$reason_visit)
  out <- data.frame(
    group_variable = "Overall", group_level = "All adults with visit <=12 mo",
    reason = lev,
    weighted_pct = 100 * as.numeric(coef(overall)[paste0("reason_visit", lev)]),
    weighted_pct_se = 100 * as.numeric(survey::SE(overall)[paste0("reason_visit", lev)]),
    n_unweighted = as.integer(table(d$variables$reason_visit)[lev]),
    row.names = NULL
  )
  out
}

# Frequencies of reasons unmet dental need could not be met (OHQ780A-K),
# among those reporting unmet need. Multi-response: each flagged as 1 if == 1.
unmet_need_reasons <- function(design) {
  v <- design$variables
  cols <- intersect(paste0("OHQ780", LETTERS[1:11]), names(v))
  if (length(cols) == 0) return(data.frame())
  d <- design[v$is_adult == 1 & !is.na(v$unmet_need) & v$unmet_need == 1, ]
  # OHQ780A-K are "check all that apply": each column holds its own item code
  # (e.g. 10, 11, 12, ...) when endorsed, NA when not, 77/99 for refused/DK.
  # Endorsed = non-missing and not a refusal/DK code.
  labels780 <- vapply(cols, function(cc) {
    lb <- attr(v[[cc]], "label"); if (is.null(lb)) cc else lb }, character(1))
  rows <- lapply(cols, function(cc) {
    dd <- d
    x <- dd$variables[[cc]]
    dd$variables$.flag <- as.integer(!is.na(x) & !(x %in% c(77, 99)))
    ci <- survey::svyciprop(~I(.flag == 1), dd, method = "beta")
    b  <- attr(ci, "ci")
    data.frame(reason_var = cc,
               reason_label = unname(labels780[cc]),
               weighted_pct = 100 * as.numeric(ci),
               ci_low = 100 * b[[1]], ci_high = 100 * b[[2]],
               n_endorsed = sum(dd$variables$.flag == 1, na.rm = TRUE),
               row.names = NULL)
  })
  dplyr::bind_rows(rows)
}

# Forest-style figure: prevalence (with CI) by group, reliability-shaded.
make_prevalence_figure <- function(prev) {
  plot_df <- prev |>
    dplyr::filter(group_variable != "Overall") |>
    dplyr::mutate(group_level = factor(group_level, levels = rev(unique(group_level))),
                  flag = ifelse(reliable, "reliable", "flagged"))
  p <- ggplot2::ggplot(plot_df, ggplot2::aes(estimate, group_level)) +
    ggplot2::geom_errorbar(ggplot2::aes(xmin = ci_low, xmax = ci_high),
                           orientation = "y", width = 0.25) +
    ggplot2::geom_point(ggplot2::aes(shape = flag), size = 2) +
    ggplot2::scale_x_continuous(labels = scales::percent_format(accuracy = 1),
                                limits = c(0, 1)) +
    ggplot2::scale_shape_manual(values = c(reliable = 16, flagged = 1), name = NULL) +
    ggplot2::facet_grid(rows = ggplot2::vars(group_variable), scales = "free_y", space = "free_y") +
    ggplot2::labs(
      title = "No dental visit in the past 12 months, by group",
      subtitle = "US adults 20+, NHANES 2017-2018; weighted % with 95% CI (Korn-Graubard)",
      x = "Weighted prevalence", y = NULL,
      caption = "Associations, not causal effects. Open circles = NCHS reliability-flagged.") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(strip.text.y = ggplot2::element_text(angle = 0, hjust = 0),
                   legend.position = "bottom")
  ggplot2::ggsave(file.path(PATHS$out_figs, "prevalence_by_group.png"),
                  p, width = 8, height = 9, dpi = 150)
  invisible(p)
}
