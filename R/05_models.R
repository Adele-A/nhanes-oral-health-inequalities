# 05_models.R ------------------------------------------------------------------
# Design-based regression for the primary outcome (no dental visit in past 12 mo):
#   (a) unadjusted (each exposure alone)
#   (b) adjusted for all sociodemographic covariates  [PRIMARY]
#   (c) model (b) + self-rated oral health             [EXPLORATORY]
# Each model is reported as adjusted ODDS ratios (svyglm, quasibinomial) AND
# PREVALENCE ratios (svyglm, quasipoisson log link), with 95% CIs on the design
# degrees of freedom. Wald tests (regTermTest) for categorical terms. Sensitivity
# analyses for the missing-income approach. Associations only -- not causal.

suppressPackageStartupMessages({
  library(here); library(survey); library(dplyr); library(ggplot2); library(readr)
})
source(here::here("R", "config.R"))
source(here::here("R", "03_design.R"))

MODEL_COVARS   <- c("age_group", "sex", "race", "educ", "income_cat")
OUTCOME        <- "no_recent_visit"

# Set regression reference levels (documented in docs/decisions.md).
set_reference_levels <- function(design) {
  v <- design$variables
  relev <- function(x, ref) { x <- factor(x); if (ref %in% levels(x)) stats::relevel(x, ref) else x }
  v$age_group       <- relev(v$age_group,       REF_LEVELS$age_group)
  v$sex             <- relev(v$sex,             REF_LEVELS$sex)
  v$race            <- relev(v$race,            REF_LEVELS$race)
  v$educ            <- relev(v$educ,            REF_LEVELS$educ)
  v$income_cat      <- relev(v$income_cat,      REF_LEVELS$income)
  v$income_cat_miss <- relev(v$income_cat_miss, REF_LEVELS$income)
  v$oral_health     <- relev(v$oral_health,     REF_LEVELS$oral_health)
  v$insurance       <- relev(v$insurance,       REF_LEVELS$insurance)
  design$variables <- v
  design
}

# Complete-case adult domain for a set of model variables (outcome + covariates).
model_domain <- function(design, vars) {
  v <- design$variables
  keep <- v$is_adult == 1
  for (vv in c(OUTCOME, vars)) keep <- keep & !is.na(v[[vv]])
  design[keep, ]
}

# Fit OR (quasibinomial) and PR (quasipoisson log) for one formula/domain.
fit_models <- function(domain, rhs) {
  f <- stats::as.formula(paste(OUTCOME, "~", rhs))
  list(
    or = survey::svyglm(f, design = domain, family = stats::quasibinomial()),
    pr = survey::svyglm(f, design = domain, family = stats::quasipoisson(link = "log"))
  )
}

# Tidy a svyglm into exponentiated estimates (OR or PR) with 95% CI and p.
# NHANES has only ~15 design df; svyglm's residual df collapses to ~0 once a
# model has many coefficients, giving NaN t-intervals. Per NCHS practice we use
# the DESIGN degrees of freedom (degf) for inference on each coefficient.
tidy_exp <- function(model, measure, model_label, dd) {
  co <- summary(model, df.resid = dd)$coefficients
  ci <- suppressMessages(stats::confint(model, ddf = dd))
  terms <- rownames(co)
  data.frame(
    model    = model_label,
    measure  = measure,
    term     = terms,
    estimate = exp(co[, "Estimate"]),
    ci_low   = exp(ci[, 1]),
    ci_high  = exp(ci[, 2]),
    p_value  = co[, 4],
    row.names = NULL
  ) |> dplyr::filter(term != "(Intercept)")
}

# Wald test (regTermTest) for every categorical term, on the design df.
wald_tests <- function(model, vars, model_label, dd) {
  dplyr::bind_rows(lapply(vars, function(vv) {
    rt <- survey::regTermTest(model, stats::as.formula(paste0("~", vv)), df = dd)
    data.frame(model = model_label, term = vv,
               df = as.numeric(rt$df), ddf = as.numeric(rt$ddf),
               F = as.numeric(rt$Ftest), p_value = as.numeric(rt$p),
               row.names = NULL)
  }))
}

# --- Orchestrator -------------------------------------------------------------
run_models <- function(design, write = TRUE) {
  ensure_dirs()
  options(survey.lonely.psu = "adjust")
  design <- set_reference_levels(design)

  coefs <- list(); walds <- list()

  # (a) Unadjusted: each exposure alone
  for (vv in MODEL_COVARS) {
    dom <- model_domain(design, vv)
    dd  <- survey::degf(dom)
    m <- fit_models(dom, vv)
    lab <- paste0("Unadjusted: ", vv)
    coefs[[length(coefs)+1]] <- tidy_exp(m$or, "OR", lab, dd)
    coefs[[length(coefs)+1]] <- tidy_exp(m$pr, "PR", lab, dd)
    walds[[length(walds)+1]] <- wald_tests(m$or, vv, lab, dd)
  }

  # (b) Adjusted (primary): all sociodemographic covariates
  dom_b <- model_domain(design, MODEL_COVARS)
  dd_b  <- survey::degf(dom_b)
  m_b <- fit_models(dom_b, paste(MODEL_COVARS, collapse = " + "))
  coefs[[length(coefs)+1]] <- tidy_exp(m_b$or, "OR", "Adjusted (b)", dd_b)
  coefs[[length(coefs)+1]] <- tidy_exp(m_b$pr, "PR", "Adjusted (b)", dd_b)
  walds[[length(walds)+1]] <- wald_tests(m_b$or, MODEL_COVARS, "Adjusted (b)", dd_b)
  n_b <- nrow(dom_b$variables)

  # (c) Adjusted + self-rated oral health (exploratory)
  covars_c <- c(MODEL_COVARS, "oral_health")
  dom_c <- model_domain(design, covars_c)
  dd_c  <- survey::degf(dom_c)
  m_c <- fit_models(dom_c, paste(covars_c, collapse = " + "))
  coefs[[length(coefs)+1]] <- tidy_exp(m_c$or, "OR", "Adjusted + oral health (c)", dd_c)
  coefs[[length(coefs)+1]] <- tidy_exp(m_c$pr, "PR", "Adjusted + oral health (c)", dd_c)
  walds[[length(walds)+1]] <- wald_tests(m_c$or, covars_c, "Adjusted + oral health (c)", dd_c)
  n_c <- nrow(dom_c$variables)

  coef_df <- dplyr::bind_rows(coefs)
  wald_df <- dplyr::bind_rows(walds)

  # Sensitivity + diagnostics
  sens <- sensitivity_income(design)
  diag <- model_diagnostics(design, dom_b, m_b$or)

  if (write) {
    readr::write_csv(coef_df, file.path(PATHS$out_tables, "model_coefficients.csv"))
    readr::write_csv(wald_df, file.path(PATHS$out_tables, "model_wald_tests.csv"))
    readr::write_csv(sens,    file.path(PATHS$out_tables, "sensitivity_income.csv"))
    readr::write_csv(diag$sparse_cells, file.path(PATHS$out_tables, "diagnostics_sparse_cells.csv"))
    make_forest(coef_df)
  }

  invisible(list(coefficients = coef_df, wald = wald_df, sensitivity = sens,
                 diagnostics = diag, n_adjusted_b = n_b, n_adjusted_c = n_c,
                 model_b = m_b, model_c = m_c))
}

# Sensitivity: complete-case income vs missing-indicator income (full sample).
sensitivity_income <- function(design) {
  cc_covars <- MODEL_COVARS
  mi_covars <- c("age_group", "sex", "race", "educ", "income_cat_miss")
  dom_cc <- model_domain(design, cc_covars)
  dom_mi <- model_domain(design, mi_covars)
  m_cc <- survey::svyglm(stats::as.formula(paste(OUTCOME, "~", paste(cc_covars, collapse = " + "))),
                         design = dom_cc, family = stats::quasibinomial())
  m_mi <- survey::svyglm(stats::as.formula(paste(OUTCOME, "~", paste(mi_covars, collapse = " + "))),
                         design = dom_mi, family = stats::quasibinomial())
  dplyr::bind_rows(
    tidy_exp(m_cc, "OR", "Income complete-case", survey::degf(dom_cc)) |>
      dplyr::mutate(n = nrow(dom_cc$variables)),
    tidy_exp(m_mi, "OR", "Income missing-indicator", survey::degf(dom_mi)) |>
      dplyr::mutate(n = nrow(dom_mi$variables))
  )
}

# Diagnostics: sparse cells (outcome x covariate), convergence, separation check.
model_diagnostics <- function(design, dom_b, model_or) {
  v <- dom_b$variables
  sparse <- dplyr::bind_rows(lapply(MODEL_COVARS, function(vv) {
    tab <- table(v[[vv]], v[[OUTCOME]])
    data.frame(covariate = vv, level = rownames(tab),
               n_outcome0 = as.integer(tab[, 1]), n_outcome1 = as.integer(tab[, 2]),
               min_cell = pmin(tab[, 1], tab[, 2]), row.names = NULL)
  }))
  list(
    sparse_cells = sparse,
    converged = isTRUE(model_or$converged),
    min_cell_overall = min(sparse$min_cell),
    design_df = survey::degf(dom_b)
  )
}

# Forest plot of adjusted (model b) odds ratios with 95% CI.
make_forest <- function(coef_df) {
  fd <- coef_df |>
    dplyr::filter(model == "Adjusted (b)", measure == "OR") |>
    dplyr::mutate(term = factor(term, levels = rev(term)))
  p <- ggplot2::ggplot(fd, ggplot2::aes(estimate, term)) +
    ggplot2::geom_vline(xintercept = 1, linetype = "dashed", colour = "grey50") +
    ggplot2::geom_errorbar(ggplot2::aes(xmin = ci_low, xmax = ci_high),
                           orientation = "y", width = 0.25) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_x_log10() +
    ggplot2::labs(
      title = "Adjusted odds of no dental visit in past 12 months",
      subtitle = "US adults 20+, NHANES 2017-2018; model (b), 95% CI, log scale",
      x = "Adjusted odds ratio (reference = first level)", y = NULL,
      caption = "Associations, not causal effects.") +
    ggplot2::theme_minimal(base_size = 11)
  ggplot2::ggsave(file.path(PATHS$out_figs, "forest_adjusted_or.png"),
                  p, width = 8, height = 7, dpi = 150)
  invisible(p)
}
