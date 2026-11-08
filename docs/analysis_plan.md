# Pre-specified analysis plan

**Project:** Inequalities in Dental Care Use among U.S. Adults — NHANES 2017–2018
**Status:** FROZEN. Finalized after variable verification and committed in a dedicated
commit ("Pre-specify analysis plan") **before** any association estimate was computed.
Approved by the project controller.
**Design principle:** every number in the report is design-based (weights, strata, PSU);
every estimate carries a 95% CI; all findings are **associations in cross-sectional data**,
never causal effects.

> This is an independent portfolio project, not affiliated with CDC/NCHS. Variable codes
> below are taken from the NHANES 2017–2018 OHQ_J and DEMO_J codebooks and were re-verified
> against the downloaded data (see `docs/variable_map.md`) before this plan was frozen.

---

## 1. Research question

Among U.S. adults aged 20+, how is **dental-care utilization** associated with age, sex,
race/ethnicity, education, family income, self-rated oral health, and (optionally)
health-insurance coverage?

## 2. Data source

NHANES 2017–2018 (cycle suffix `_J`), public-use files from CDC/NCHS:

- `DEMO_J` — demographics and **survey-design variables** (`SDMVPSU`, `SDMVSTRA`,
  `WTINT2YR`, `RIDAGEYR`, `RIAGENDR`, `RIDRETH3`, `DMDEDUC2`, `INDFMPIR`).
- `OHQ_J` — Oral Health Questionnaire (`OHQ030`, `OHQ033`, `OHQ770`, `OHQ780A–K`, `OHQ845`).
- `HIQ_J` (optional) — insurance (`HIQ011`).

Merge: **left join OHQ_J (and HIQ_J) onto DEMO_J by `SEQN`** so that *all* DEMO_J
participants are retained — the survey design must be built on the full sample.

## 3. Study population

Interviewed adults aged **20 years and older** (`RIDAGEYR >= 20`). Rationale: `DMDEDUC2`
(education) is collected only for 20+, so restricting to 20+ keeps education defined for the
whole analytic domain. The restriction is applied as a **survey domain** via
`subset(design, RIDAGEYR >= 20 & !is.na(<outcome>))`, **never** by filtering the data before
building the design.

## 4. Weights and survey design

OHQ is an interview-component (CAPI, in-home) questionnaire with no MEC examination join, so
the correct weight is the **2-year interview weight `WTINT2YR`** (not `WTMEC2YR`).

```r
design <- survey::svydesign(
  id      = ~SDMVPSU,
  strata  = ~SDMVSTRA,
  weights = ~WTINT2YR,
  nest    = TRUE,
  data    = demo_ohq_full   # ALL DEMO_J records
)
```

A test asserts the design is built on the full sample (`nrow == nrow(DEMO_J)`). Degrees of
freedom come from `survey::degf(design)` (≈ #PSUs − #strata), **not** the number of
observations.

## 5. Outcomes

### 5.1 Primary outcome — no dental visit in the past 12 months

Derived from `OHQ030` ("time since last dental visit"):

| `OHQ030` | Meaning | Primary outcome |
|---|---|---|
| 1 | ≤ 6 months | 0 (visit in past 12 mo) |
| 2 | > 6 mo – 1 year | 0 |
| 3 | > 1 – 2 years | 1 (no visit in past 12 mo) |
| 4 | > 2 – 3 years | 1 |
| 5 | > 3 – 5 years | 1 |
| 6 | > 5 years | 1 |
| 7 | Never | 1 |
| 77 / 99 / missing | Refused / don't know / NA | NA |

Framed as a **utilization indicator** ("no recent dental visit"), explicitly **not** proven
unmet need.

### 5.2 Secondary outcomes (descriptive)

- **Reason for last visit** (`OHQ033`), among respondents with a visit in the **past 12
  months** (`OHQ030 ∈ {1,2}`) so the recall window is comparable: preventive `{1,2}` vs.
  problem-driven `{3,4}`; `5` = "other" shown separately; `7/9 → NA`. Codebook target
  population re-checked in Stage 1.
- **Self-reported unmet need** (`OHQ770 == 1`) and its reasons (`OHQ780A–K`) — described
  separately; this is a distinct measure and is **not** conflated with the primary outcome.

## 6. Exposures / covariates

| Variable | Source | Categories |
|---|---|---|
| Age group | `RIDAGEYR` | 20–34 / 35–49 / 50–64 / 65+ |
| Sex | `RIAGENDR` | Male / Female |
| Race/ethnicity | `RIDRETH3` | Mexican American / Other Hispanic / Non-Hispanic White / Non-Hispanic Black / Non-Hispanic Asian / Other–Multiracial (per codebook labels) |
| Education | `DMDEDUC2` | < high school (1–2) / HS or GED (3) / some college (4) / college graduate+ (5); 7/9 → NA |
| Family income (PIR) | `INDFMPIR` | < 1.0 / 1.0–1.99 / 2.0–3.99 / ≥ 4.0 (top-coded 5.0) |
| Self-rated oral health | `OHQ845` | excellent/very good (1–2) / good (3) / fair/poor (4–5); 7/9 → NA |
| Insurance (optional) | `HIQ011` | insured (1) / not insured (2); 7/9 → NA |

Age-group rationale: 65+ marks Medicare eligibility (traditional Medicare excludes routine
dental), relevant to utilization. All categorical covariates modeled as factors with an
explicit reference level documented in `decisions.md`.

## 7. Missing data

Report the proportion missing for every analysis variable (especially `INDFMPIR`, ≈ 10%+,
and `DMDEDUC2`). **Recommended handling (to confirm at Stage 2):**

- **Primary regression:** complete-case on all model covariates.
- **Descriptive proportions:** additionally show a "Missing" income group so no one is
  silently dropped from Table 1 / prevalence tables.
- **Sensitivity:** a **missing-indicator** model that retains the full sample (income
  "Missing" as its own level), compared with the complete-case model.
- **Optional extension (not required):** multiple imputation with `mice` + `mitools`/`survey`
  pooling, noted as future work.

## 8. Self-rated oral health — modeling role

The association between self-rated oral health and utilization is **bidirectional** (poor
oral health can prompt problem-driven visits; lack of visits can worsen oral health).
Therefore:

- **Primary adjusted model (b):** sociodemographic covariates only.
- **Exploratory model (c):** adds self-rated oral health, interpreted cautiously and
  explicitly as an association that may reflect reverse causation.

## 9. Statistical methods

### 9.1 Proportions with 95% CI

`survey::svyciprop(~I(outcome), domain_design, method = "beta")` (Korn–Graubard interval, as
used in NCHS publications), reported by each sociodemographic group with the **unweighted n**
beside each estimate. `"logit"` intervals computed as a cross-check.

### 9.2 Estimate reliability (NCHS presentation standards, Parker et al. 2017)

Implemented in `R/utils_reliability.R` with `testthat` coverage. An estimate is flagged /
suppressed when it fails the NCHS Data Presentation Standards for Proportions, based on:

- effective/absolute sample size (e.g. denominator or effective sample size too small),
- degrees of freedom of the design,
- relative and absolute width of the (Korn–Graubard) confidence interval.

The exact thresholds follow Parker et al. (2017), *Vital Health Stat* 2(175); the function
returns a flag per estimate and the report shows flagged estimates as unreliable rather than
hiding them.

### 9.3 Regression

Built on the same domain design (`subset`), with design df throughout:

- **(a) Unadjusted:** each exposure alone.
- **(b) Adjusted (primary):** all sociodemographic covariates.
- **(c) + oral health (exploratory):** model (b) plus `OHQ845`.

Two complementary effect measures for the frequent binary outcome:

- **Adjusted odds ratios:** `svyglm(outcome ~ ..., design, family = quasibinomial())`.
- **Prevalence ratios:** `svyglm(outcome ~ ..., design, family = quasipoisson(link = "log"))`
  (log-Poisson with survey-robust SEs), because with a common outcome (~⅓ of adults) ORs
  overstate the relative risk. Predicted marginal prevalences reported alongside.

Overall significance of categorical terms via `survey::regTermTest` (Wald). 95% CIs on
**every** table and figure (including a forest plot of adjusted estimates).

### 9.4 Diagnostics & sensitivity

Sparse-cell checks, convergence, category collinearity; sensitivity analyses for the
missing-income approach (§7) and for an alternative income/age categorization.

## 10. Causal language

All results are associations in cross-sectional data. Wording: "associated with", "higher
prevalence among" — never "causes", "leads to", "reduces". No policy recommendations beyond
what the data support.

## 11. Limitations (to carry into report & README)

Cross-sectional (no causal inference); self-report (recall, social-desirability bias); "no
recent visit" ≠ unmet need; pre-pandemic 2017–2018 data; U.S.-only — **not transferable to
Germany** (different insurance and dental-care systems); missing income; small-subgroup
limits.

## 12. References (real sources only)

- CDC/NCHS. NHANES 2017–2018 questionnaires, datasets & codebooks (DEMO_J, OHQ_J, HIQ_J).
- CDC/NCHS. NHANES Analytic and Reporting Guidelines.
- Parker JD, et al. (2017). *National Center for Health Statistics Data Presentation
  Standards for Proportions.* Vital Health Stat 2(175).
- Lumley T. `survey`: analysis of complex survey samples (R package documentation).
