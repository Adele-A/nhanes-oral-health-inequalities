# Variable map — NHANES 2017-2018 (cycle J)

For every variable used in the analysis: source file, survey question / meaning,
target universe, original coding, recode applied, and the codebook reference.
Original code frequencies below were **verified against the downloaded public-use
files** (not copied from the prompt) on 2026-11-09. Codebook:
<https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/OHQ_J.htm> (OHQ_J) and the
corresponding DEMO_J / HIQ_J codebooks.

Row counts of the source files: `DEMO_J` = 9254, `OHQ_J` = 8897, `HIQ_J` = 9254. `SEQN`
is unique in each. Analysis merges OHQ_J and HIQ_J onto DEMO_J by `SEQN` (left join), so
all 9254 DEMO participants are retained for the survey design.

## Identifiers & design variables (DEMO_J)

| Variable | Meaning | Recode |
|---|---|---|
| `SEQN` | Respondent ID; merge key | none |
| `SDMVPSU` | Masked variance unit (PSU) | design `id` |
| `SDMVSTRA` | Masked variance stratum | design `strata` |
| `WTINT2YR` | Full-sample 2-year **interview** weight | design `weights` (OHQ is a CAPI interview module; no MEC join → not `WTMEC2YR`) |

## Demographic covariates (DEMO_J)

| Variable | Question / meaning | Target | Observed codes (n) | Recode → analysis variable |
|---|---|---|---|---|
| `RIDAGEYR` | Age in years (top-coded 80) | all | range 0–80 | `age_group` = cut 20–34 / 35–49 / 50–64 / 65+ (analysis restricted to 20+) |
| `RIAGENDR` | Sex | all | 1=4557, 2=4697 | `sex`: 1→Male, 2→Female |
| `RIDRETH3` | Race/Hispanic origin (w/ NH Asian) | all | 1=1367, 2=820, 3=3150, 4=2115, 6=1168, 7=634 | `race`: 1→Mexican American, 2→Other Hispanic, 3→Non-Hispanic White, 4→Non-Hispanic Black, 6→Non-Hispanic Asian, 7→Other/Multiracial |
| `DMDEDUC2` | Education level — **Adults 20+** | 20+ | 1=479, 2=638, 3=1325, 4=1778, 5=1336, 7=2, 9=11, NA=3685 | `educ` (4 cat): {1,2}→<High school, 3→HS grad/GED, 4→Some college, 5→College graduate+; 7/9→NA. (NA=3685 are the under-20s.) |
| `INDFMPIR` | Family income-to-poverty ratio (top-coded 5.0) | all | missing 1231/9254 = 13.3% | `income_cat` = cut <1.0 / 1.0–1.99 / 2.0–3.99 / ≥4.0; `income_cat_miss` adds explicit "Missing" level |

## Oral health questionnaire (OHQ_J)

| Variable | Question | Target | Observed codes (n) | Recode → analysis variable |
|---|---|---|---|---|
| `OHQ030` | When did you last visit a dentist | 1+ yr | 1=4070, 2=1361, 3=1001, 4=527, 5=471, 6=913, 7=524, 99=28, NA=2 | **Primary outcome** `no_recent_visit`: {1,2}→0 (visit ≤12 mo), {3,4,5,6,7}→1 (no visit >12 mo), 77/99→NA. (77 absent in data; 99=don't know.) |
| `OHQ033` | Main reason for last dental visit | visited (OHQ030 1–6) | 1=4963, 2=703, 3=1810, 4=688, 5=180, 7=2, 9=25, NA=526 | `reason_visit` among OHQ030∈{1,2}: {1,2}→Preventive, {3,4}→Problem-driven, 5→Other; 7/9→NA |
| `OHQ770` | Past yr needed dental care but couldn't get it | see codebook | 1=1340, 2=7027, 9=4, NA=526 | `unmet_need`: 1→1, 2→0, 7/9→NA (descriptive secondary outcome) |
| `OHQ780A–K` | Reasons could not get dental care (check-all) | OHQ770==1 | multi-response | described as frequencies among `unmet_need==1` |
| `OHQ845` | Rate the health of your teeth and gums | 1+ yr | 1=1687, 2=2134, 3=2820, 4=1580, 5=666, 9=8, NA=2 | `oral_health` (3 cat): {1,2}→Excellent/Very good, 3→Good, {4,5}→Fair/Poor; 7/9→NA |

## Health insurance (HIQ_J, optional covariate)

| Variable | Question | Observed codes (n) | Recode → analysis variable |
|---|---|---|---|
| `HIQ011` | Covered by health insurance | 1=8157, 2=1072, 7=7, 9=18 | `insurance`: 1→Insured, 2→Uninsured; 7/9→NA |

## Notes

- Reserved codes (7/9 for one-digit items, 77/99 for two-digit `OHQ030`) are recoded to
  `NA` **before** deriving any outcome or covariate (`R/02_prepare.R`, verified by test).
- Exact target universes for `OHQ030`, `OHQ033`, `OHQ770`, `OHQ845` are documented in the
  OHQ_J codebook (linked above); the analysis restricts to interviewed adults 20+ via a
  survey **domain** (`subset(design, ...)`), never by pre-filtering the data.
