# config.R ---------------------------------------------------------------------
# Shared constants, paths, and factor definitions for the whole pipeline.
# Sourced by every stage script. No analysis logic here.
# Cross-platform: all paths via here::here(); never absolute or setwd().

suppressPackageStartupMessages({
  library(here)
})

# --- Paths --------------------------------------------------------------------
PATHS <- list(
  data_raw   = here::here("data", "raw"),
  out_tables = here::here("outputs", "tables"),
  out_figs   = here::here("outputs", "figures"),
  dash_data  = here::here("dashboard", "data"),
  docs       = here::here("docs"),
  report     = here::here("report")
)

ensure_dirs <- function() {
  for (p in PATHS) if (!dir.exists(p)) dir.create(p, recursive = TRUE, showWarnings = FALSE)
  invisible(TRUE)
}

# --- NHANES 2017-2018 (cycle J) source files ----------------------------------
# Public-domain CDC/NCHS data. CDC migrated NHANES data files to the
# /Nchs/Data/Nhanes/Public/<year>/DataFiles/ path; the old /Nchs/Nhanes/2017-2018/
# path now 302s to the CDC homepage. Verified serving real XPT (SAS transport,
# "HEADER RECORD...LIBRARY HEADER RECORD") on 2026-11-08.
NHANES_CYCLE <- "2017-2018"
NHANES_BASE  <- "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles"
NHANES_FILES <- c(
  DEMO = "DEMO_J.XPT",  # demographics + survey design variables
  OHQ  = "OHQ_J.XPT",   # oral health questionnaire
  HIQ  = "HIQ_J.XPT"    # health insurance (optional covariate)
)
OHQ_CODEBOOK_URL <- "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/OHQ_J.htm"

# --- Survey design columns ----------------------------------------------------
DESIGN_VARS <- list(
  psu     = "SDMVPSU",
  strata  = "SDMVSTRA",
  weight  = "WTINT2YR"   # interview-component weight (OHQ is CAPI; no MEC join)
)

# --- Missing-value codes to recode to NA, per variable ------------------------
# Verified against the OHQ_J / DEMO_J codebooks; re-checked against data in Stage 1.
NA_CODES <- list(
  OHQ030  = c(77, 99),
  OHQ033  = c(7, 9),
  OHQ770  = c(7, 9),
  OHQ845  = c(7, 9),
  DMDEDUC2 = c(7, 9),
  HIQ011  = c(7, 9)
)

# --- Factor level definitions (labels verified against codebook) --------------
# Reference levels are the FIRST level of each factor (documented in docs/decisions.md).

AGE_BREAKS <- c(20, 35, 50, 65, Inf)
AGE_LABELS <- c("20-34", "35-49", "50-64", "65+")

SEX_LEVELS <- c("1" = "Male", "2" = "Female")

# RIDRETH3 (NHANES 2017-2018): codes 1,2,3,4,6,7 (no 5). Re-verified in Stage 1.
RACE_LEVELS <- c(
  "3" = "Non-Hispanic White",
  "4" = "Non-Hispanic Black",
  "1" = "Mexican American",
  "2" = "Other Hispanic",
  "6" = "Non-Hispanic Asian",
  "7" = "Other/Multiracial"
)

# DMDEDUC2 collapsed to 4 categories.
EDUC_MAP <- c("1" = "<High school", "2" = "<High school",
              "3" = "HS grad/GED",
              "4" = "Some college",
              "5" = "College graduate+")
EDUC_LEVELS <- c("College graduate+", "Some college", "HS grad/GED", "<High school")

# Family income-to-poverty ratio (INDFMPIR, top-coded 5.0) -> 4 categories.
INCOME_BREAKS <- c(-Inf, 1.0, 2.0, 4.0, Inf)
INCOME_LABELS <- c("<1.0 (below poverty)", "1.0-1.99", "2.0-3.99", ">=4.0")

# OHQ845 self-rated oral health collapsed to 3 categories.
ORALHEALTH_MAP <- c("1" = "Excellent/Very good", "2" = "Excellent/Very good",
                    "3" = "Good",
                    "4" = "Fair/Poor", "5" = "Fair/Poor")
ORALHEALTH_LEVELS <- c("Excellent/Very good", "Good", "Fair/Poor")

INSURANCE_LEVELS <- c("1" = "Insured", "2" = "Uninsured")

# Reference levels used in regression (documented in docs/decisions.md).
REF_LEVELS <- list(
  age_group   = "20-34",
  sex         = "Male",
  race        = "Non-Hispanic White",
  educ        = "College graduate+",
  income      = ">=4.0",
  oral_health = "Excellent/Very good",
  insurance   = "Insured"
)

# --- NCHS reliability thresholds (Parker et al. 2017) -------------------------
RELIABILITY <- list(
  min_n        = 30,    # minimum unweighted denominator
  max_rel_ciw  = 1.30,  # maximum relative CI width (130%)
  min_df       = 8,     # minimum design degrees of freedom
  min_neff     = 30     # minimum effective sample size
)
