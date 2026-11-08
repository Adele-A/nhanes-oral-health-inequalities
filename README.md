# Inequalities in Dental-Care Use among U.S. Adults (NHANES 2017–2018)

An independent portfolio project demonstrating **complex-survey methodology** in R: a
pre-specified analysis plan, a correctly specified NHANES survey design (weights, strata,
PSUs), design-based estimates with confidence intervals and reliability flags, and
survey-weighted regression reporting both odds ratios and prevalence ratios.

> **Independent portfolio project — not affiliated with CDC/NCHS.** All findings are
> **associations** in cross-sectional data, never causal effects. Results describe **U.S.**
> adults and do **not** transfer to other health systems (e.g. Germany), which differ in
> insurance and dental-care organization.

## Research question

How is **not having visited a dentist in the past 12 months** among U.S. adults (20+)
associated with age, sex, race/ethnicity, education, family income, self-rated oral health,
and health-insurance coverage?

## Key results

Among **5,569** interviewed adults aged 20+ (survey design built on the full NHANES sample
of 9,254), an estimated **41.3%** (95% CI 36.4–46.3) had **no dental visit in the past
12 months**. The estimate is weighted and design-based (15 degrees of freedom).

Marked gradients (weighted prevalence, 95% CI; see `outputs/tables/prevalence_by_group.csv`):

| Group | No recent visit |
|---|---|
| Education: college graduate+ → < high school | 25.1% (21.9–28.6) → **60.1%** (54.8–65.2) |
| Income (PIR): ≥ 4.0 → < 1.0 (below poverty) | 25.4% (21.0–30.3) → **58.5%** (51.6–65.1) |
| Insurance: insured → uninsured | 36.6% (32.9–40.5) → **70.2%** (63.3–76.4) |
| Self-rated oral health: excellent/very good → fair/poor | 28.5% (24.0–33.3) → **59.0%** (52.8–65.1) |

After mutual adjustment for all sociodemographic covariates (model b), lower education and
lower income remained associated with higher odds of no recent visit — e.g. < high school
vs college graduate+ **OR 2.55** (1.75–3.73); below poverty vs ≥ 4.0 PIR **OR 2.84**
(2.07–3.88); women vs men **OR 0.62** (0.55–0.70). Because the outcome is common, prevalence
ratios are reported alongside and are closer to 1 (e.g. below poverty **PR 1.82**); they are
the more conservative relative measure. Full estimates: `outputs/tables/model_coefficients.csv`.

Separately, **18.2%** (16.3–20.2) of adults reported needing dental care in the past year
but being unable to get it; the most common reason was cost.

See the full report: [`report/oral_health_report.html`](report/oral_health_report.html).

## Data and survey design

- **Source:** CDC/NCHS NHANES 2017–2018 public-use files `DEMO_J`, `OHQ_J`, `HIQ_J`
  (public domain), downloaded from
  <https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/>. Raw files are **not**
  committed (see `.gitignore`); `data/raw/MANIFEST.json` records the source URLs, download
  date, and SHA-256 checksums.
- **Design:** `svydesign(id = ~SDMVPSU, strata = ~SDMVSTRA, weights = ~WTINT2YR, nest = TRUE)`
  built on the **full** sample; the 20+ analytic subpopulation is taken as a survey
  **domain** via `subset()` (never by filtering before the design is built). `WTINT2YR`
  (interview weight) is used because the oral-health items are part of the household
  interview, not the MEC examination.

## Methods

- Weighted proportions with 95% **Korn–Graubard** CIs (`svyciprop(method = "beta")`), with
  unweighted denominators and **NCHS reliability flags** (Parker et al. 2017).
- Survey-weighted regression (`svyglm`): **odds ratios** (`quasibinomial`) and **prevalence
  ratios** (`quasipoisson`, log link); Wald tests (`regTermTest`); all inference on the
  **design** degrees of freedom.
- Sensitivity analyses for missing income (complete-case vs missing-indicator) and
  diagnostics for sparse cells and convergence.

The analysis plan was pre-specified and frozen before any association was estimated
(`docs/analysis_plan.md`); variable definitions are documented and verified against the
codebook (`docs/variable_map.md`); discretionary choices are logged (`docs/decisions.md`).

## How to run

Reproduce everything with one command (downloads data, computes all estimates, renders the
report):

```bash
Rscript run_all.R
```

First-time setup restores the exact package versions with `renv`:

```r
install.packages("renv")
renv::restore()
```

### Prerequisites

- **R ≥ 4.3** (developed on 4.6). macOS: <https://cran.r-project.org/bin/macosx/>.
  Windows: <https://cran.r-project.org/bin/windows/base/>.
- **Quarto** (HTML report; no LaTeX required): <https://quarto.org/docs/get-started/>.
- **Windows PATH note:** if `Rscript` is not recognized, add R's `bin` directory to your
  PATH (e.g. `C:\Program Files\R\R-4.6.2\bin`), or run from RStudio via
  `source("run_all.R")`. On macOS, `Rscript` is on the PATH after a standard install.
- Internet access is needed **once** to download the NHANES files. If CDC is unreachable,
  the pipeline stops and asks you to place the XPT files in `data/raw/` manually.

## Repository structure

```
run_all.R                      # single entry point (download → … → render)
R/   config.R 01_download.R 02_prepare.R 03_design.R
     04_descriptives.R 05_models.R 06_exports.R utils_reliability.R
report/oral_health_report.qmd  # Quarto HTML report
docs/  PLAN.md analysis_plan.md variable_map.md decisions.md
outputs/ tables/ figures/       # computed estimates & plots
dashboard/ data/ POWERBI_SPEC.md DATA_DICTIONARY.md  # Power BI star schema (display-only)
data/raw/MANIFEST.json          # source/provenance (raw data gitignored)
tests/testthat/                 # offline tests on a synthetic fixture
```

## Power BI

`dashboard/data/` holds clean star-schema CSVs of the **pre-computed** estimates, with
`DATA_DICTIONARY.md`, ready-to-paste DAX measures, and `POWERBI_SPEC.md`. Power BI cannot
compute design-based variance, so it only **displays** these estimates. The `.pbix` and
screenshots are built by Adele and are **not included yet** — the Quarto HTML report is the
cross-platform results version in the meantime.

## Tests & CI

`tests/testthat/` runs offline on a small **synthetic** fixture (no network, no real NHANES
download): preparation/recoding, the survey-design guard, the NCHS reliability function, and
the regression helpers. GitHub Actions runs a syntax check and the test suite on
`ubuntu-latest`, `windows-latest`, and `macos-latest`.

## Limitations

Cross-sectional (associations only, no causal inference); self-report (recall and
social-desirability bias); "no recent visit" is a utilization indicator, not proven unmet
need; data predate the COVID-19 pandemic; ~13% of adults were missing family income; small
subgroups carry wide CIs (NCHS-flagged); **U.S. results do not transfer to Germany or other
systems.**

## Disclaimer

Independent portfolio project for methodological demonstration. Not clinical, policy, or
public-health guidance. NHANES data are public domain (CDC/NCHS); this project is not
endorsed by or affiliated with CDC or NCHS.

## References

- CDC/NCHS. NHANES 2017–2018 data files & codebooks (DEMO_J, OHQ_J, HIQ_J).
- CDC/NCHS. NHANES Analytic and Reporting Guidelines.
- Parker JD, Talih M, Malec DJ, et al. (2017). *NCHS Data Presentation Standards for
  Proportions.* Vital Health Stat 2(175).
- Lumley T. *survey: analysis of complex survey samples* (R package).
