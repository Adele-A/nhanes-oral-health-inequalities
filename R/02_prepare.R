# 02_prepare.R -----------------------------------------------------------------
# Merge DEMO_J + OHQ_J (+ HIQ_J) on SEQN (left join to DEMO so ALL participants
# are retained for the survey design), recode reserved missing codes to NA, and
# derive the analysis outcomes and categorical covariates.
# IMPORTANT: this does NOT filter to adults -- the full DEMO sample is kept here
# and the 20+ analytic domain is taken later via subset(design, ...).

suppressPackageStartupMessages({
  library(here); library(haven); library(dplyr); library(forcats); library(readr)
})
source(here::here("R", "config.R"))

# Set values listed in `codes` to NA.
recode_na <- function(x, codes) { x[x %in% codes] <- NA; x }

# Map an integer-coded vector to a labelled factor via a named map, then order
# the levels as given (first level = regression reference unless releveled).
map_factor <- function(x, map, levels_order) {
  lab <- unname(map[as.character(x)])
  factor(lab, levels = levels_order)
}

read_raw <- function(raw = PATHS$data_raw) {
  list(
    demo = haven::read_xpt(file.path(raw, NHANES_FILES[["DEMO"]])),
    ohq  = haven::read_xpt(file.path(raw, NHANES_FILES[["OHQ"]])),
    hiq  = haven::read_xpt(file.path(raw, NHANES_FILES[["HIQ"]]))
  )
}

prepare_data <- function(write_cache = TRUE, raw = PATHS$data_raw) {
  r <- read_raw(raw)
  dat <- derive_variables(r$demo, r$ohq, r$hiq)
  if (write_cache) {
    proc_dir <- here::here("data", "processed")
    if (!dir.exists(proc_dir)) dir.create(proc_dir, recursive = TRUE, showWarnings = FALSE)
    saveRDS(dat, file.path(proc_dir, "analytic.rds"))
  }
  dat
}

# Merge + recode + derive, given the three raw data frames. Pure (no I/O) so it
# can be unit-tested on small synthetic fixtures without network or XPT files.
derive_variables <- function(demo, ohq, hiq) {
  demo_keep <- demo |>
    dplyr::select(SEQN, RIDAGEYR, RIAGENDR, RIDRETH3, DMDEDUC2, INDFMPIR,
                  dplyr::all_of(unname(unlist(DESIGN_VARS))))
  ohq_keep <- ohq |>
    dplyr::select(SEQN, OHQ030, OHQ033, OHQ770, OHQ845,
                  dplyr::any_of(paste0("OHQ780", LETTERS[1:11])))
  hiq_keep <- hiq |> dplyr::select(SEQN, HIQ011)

  # Left join onto DEMO -> every DEMO participant kept (design uses full sample).
  dat <- demo_keep |>
    dplyr::left_join(ohq_keep, by = "SEQN") |>
    dplyr::left_join(hiq_keep, by = "SEQN")

  # Recode reserved refusal/don't-know codes to NA (before deriving anything).
  for (v in names(NA_CODES)) if (v %in% names(dat)) dat[[v]] <- recode_na(dat[[v]], NA_CODES[[v]])

  dat <- dat |>
    dplyr::mutate(
      # --- primary outcome: no dental visit in the past 12 months -------------
      # OHQ030 {1,2} -> 0 (visit within 12 mo); {3,4,5,6,7} -> 1; else NA.
      no_recent_visit = dplyr::case_when(
        OHQ030 %in% c(1, 2)             ~ 0L,
        OHQ030 %in% c(3, 4, 5, 6, 7)    ~ 1L,
        TRUE                            ~ NA_integer_
      ),

      # --- secondary: reason for last visit, among visit-within-12-months -----
      reason_visit = dplyr::case_when(
        !(OHQ030 %in% c(1, 2))          ~ NA_character_,  # comparable recall window
        OHQ033 %in% c(1, 2)             ~ "Preventive",
        OHQ033 %in% c(3, 4)             ~ "Problem-driven",
        OHQ033 == 5                     ~ "Other",
        TRUE                            ~ NA_character_
      ),
      reason_visit = factor(reason_visit, levels = c("Preventive", "Problem-driven", "Other")),

      # --- secondary: self-reported unmet dental need -------------------------
      unmet_need = dplyr::case_when(
        OHQ770 == 1 ~ 1L, OHQ770 == 2 ~ 0L, TRUE ~ NA_integer_
      ),

      # --- covariates ---------------------------------------------------------
      age_group = cut(RIDAGEYR, breaks = AGE_BREAKS, labels = AGE_LABELS, right = FALSE),
      sex       = map_factor(RIAGENDR, SEX_LEVELS, unname(SEX_LEVELS)),
      race      = map_factor(RIDRETH3, RACE_LEVELS, unname(RACE_LEVELS)),
      educ      = map_factor(DMDEDUC2, EDUC_MAP, EDUC_LEVELS),
      income_cat = cut(INDFMPIR, breaks = INCOME_BREAKS, labels = INCOME_LABELS, right = FALSE),
      # explicit Missing level for descriptive tables & missing-indicator model
      income_cat_miss = forcats::fct_na_value_to_level(income_cat, level = "Missing"),
      oral_health = map_factor(OHQ845, ORALHEALTH_MAP, ORALHEALTH_LEVELS),
      insurance   = map_factor(HIQ011, INSURANCE_LEVELS, unname(INSURANCE_LEVELS)),

      # analytic-domain indicator (used to build subset(design, ...))
      is_adult = as.integer(RIDAGEYR >= 20)
    )

  dat
}
