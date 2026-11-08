# PLAN.md — Project roadmap

**Project:** Oral Health & Prevention — Inequalities in Dental Care Use (NHANES 2017–2018)
**Author:** Adele Amanzhol (GitHub `Adele-A`) · independent portfolio project
**Stack:** R ≥ 4.3 (`survey`, `srvyr`, `haven`, `nhanesA`), Quarto (HTML), `renv`, `testthat`
**Entry point:** `Rscript run_all.R`

This file is the high-level roadmap and the record of preflight status and key design
decisions. The **pre-specified statistical plan** lives in
[`analysis_plan.md`](analysis_plan.md) and is frozen in its own commit before any
association estimate is computed. The authoritative task spec is
`../init-prompts/03_oral_health_nhanes_inequalities.md`.

---

## Research question

How is dental-care use by U.S. adults *associated with* age, income, education, sex,
race/ethnicity (and optionally health-insurance coverage) and self-rated oral health?
Cross-sectional associations only — no causal claims.

---

## Preflight status (checked 2026-11-08)

| Check | Status | Note |
|---|---|---|
| R | ✅ 4.6.2 | Installed at `C:\Program Files\R\R-4.6.2`. **Not on persistent PATH** — a PATH edit was blocked by the sandbox; R is invoked with its bin prepended inline this session. For local `Rscript run_all.R` to work, R's `bin` must be added to PATH (see README setup). |
| Quarto | ✅ 1.11.9 | On PATH. HTML rendering only (no LaTeX required). |
| Network / CDC | ✅ | `DEMO_J.XPT`, `OHQ_J.XPT`, `HIQ_J.XPT` reachable at `https://wwwn.cdc.gov/Nchs/Nhanes/2017-2018/` (HTTP 200). |
| renv + CRAN packages | ⏳ not yet installed | Fresh R library. Stage 1 installs `renv`, then the analysis packages, then snapshots `renv.lock` (CRAN binary builds only — no compilation). |
| git | ✅ | Repo initialized, branch `main`, no commits yet. |
| Remote | ⏳ | `Adele-A/nhanes-oral-health-inequalities` exists (public, empty). `origin` added and pushed per-stage after Stage 0 approval. |

---

## Repository structure (target)

```
├── README.md
├── run_all.R                    # download → prepare → design → estimates → models → exports → render
├── renv.lock · .Rprofile
├── R/
│   ├── 01_download.R            # fetch XPT from CDC, write data/raw + MANIFEST.json
│   ├── 02_prepare.R            # merge on SEQN, recodes, codebook checks
│   ├── 03_design.R            # svydesign on FULL DEMO_J sample
│   ├── 04_descriptives.R
│   ├── 05_models.R
│   ├── 06_exports.R            # star-schema CSVs for Power BI
│   └── utils_reliability.R    # NCHS proportion reliability (Parker et al. 2017)
├── report/oral_health_report.qmd
├── docs/ PLAN.md · analysis_plan.md · variable_map.md · decisions.md
├── outputs/ tables/ · figures/
├── dashboard/ data/ · POWERBI_SPEC.md · DATA_DICTIONARY.md
├── data/raw/                    # gitignored except MANIFEST.json
└── tests/testthat/              # runs on small synthetic fixture, no network
```

---

## Stages

- **Stage 0 — Plan (stop).** Preflight; this `PLAN.md` + draft `analysis_plan.md`.
  Report to controller, wait for "ок". ← *current*
- **Stage 1 — Download & prepare.** `renv` + packages; download `DEMO_J`/`OHQ_J`/`HIQ_J`;
  merge on `SEQN` (left join to DEMO — all participants kept for the design);
  `variable_map.md`; recode 7/9/77/99 → NA; `testthat` checks (SEQN unique, codebook
  frequencies, no under-20 in analytic subset).
- **Stage 2 — Freeze analysis plan.** Finalize `analysis_plan.md` after variable checks,
  before any association estimate. Separate commit **"Pre-specify analysis plan"**.
- **Stage 3 — Design & descriptives.** `svydesign` on full sample; `subset()` for the
  20+ domain; Table 1 (unweighted n, weighted %); primary-outcome proportions with 95% CI
  by group + reliability flags; secondary outcomes.
- **Stage 4 — Regression.** Unadjusted; adjusted (sociodemographic); + oral health.
  Odds ratios **and** prevalence ratios with CI; forest plot; sensitivity analyses;
  diagnostics (sparse cells, convergence, collinearity).
- **Stage 5 — Quarto report.** `oral_health_report.qmd` → HTML; rendered from `run_all.R`.
- **Stage 6 — Power BI export.** Star-schema CSVs, `DATA_DICTIONARY.md`, DAX measures,
  `POWERBI_SPEC.md`. No `.pbix` (Adele builds it); HTML report is the cross-platform version.
- **Stage 7 — README & final check.** Clean re-run reproduces everything; CI green on
  ubuntu/windows/macos; README numbers match `outputs/`.

After each stage: run tests → short Russian report to the controller (commit sha +
push/CI status) → `git commit` → `git push`.

---

## Key design decisions (recommendations — see `analysis_plan.md` for detail)

These are the contentious choices flagged in the spec. Recommendations are made here and
carried into the pre-specified plan; the controller can veto any before Stage 2.

1. **Study population:** interviewed adults **20+** (`RIDAGEYR >= 20`), because `DMDEDUC2`
   is defined only for 20+.
2. **Weights:** `WTINT2YR` (interview component — OHQ is a CAPI household questionnaire,
   no MEC join). Design: `id = ~SDMVPSU`, `strata = ~SDMVSTRA`, `nest = TRUE`, built on the
   **full** DEMO_J sample; analytic domain via `subset()`.
3. **Primary outcome:** *no dental visit in the past 12 months* —
   `OHQ030 ∈ {3,4,5,6,7} → 1`, `{1,2} → 0`, `{77,99,missing} → NA`. Framed as a
   **utilization indicator**, not proven unmet need.
4. **Age groups:** 20–34 / 35–49 / 50–64 / 65+ (65+ marks Medicare eligibility, which does
   not cover routine dental — relevant to utilization).
5. **Education (4 cat.):** < high school (`DMDEDUC2` 1–2) / HS or GED (3) / some college (4)
   / college graduate+ (5).
6. **Income (`INDFMPIR`, 4 cat.):** < 1.0 / 1.0–1.99 / 2.0–3.99 / ≥ 4.0.
   **Missing-income handling (contentious):** *recommended* — primary regression is
   complete-case on model covariates; descriptive proportions additionally show a "Missing"
   income group; a **missing-indicator** sensitivity model retains the full sample. (Optional
   `mice` multiple imputation noted as a possible extension, not required.)
7. **Self-rated oral health (`OHQ845`, 3 cat.):** excellent/very good (1–2) / good (3) /
   fair/poor (4–5). **Role (contentious):** the primary adjusted model is sociodemographic
   only; oral health is added in a **separate** model, interpreted cautiously because the
   relationship is bidirectional (poor oral health → problem-driven visits; no visits →
   worse oral health).
8. **Proportions:** `svyciprop(method = "beta")` (Korn–Graubard, as in NCHS publications),
   with unweighted n beside every estimate.
9. **Reliability:** NCHS Data Presentation Standards for Proportions (Parker et al. 2017) —
   flag/suppress unreliable estimates (small effective sample, wide CI, few df). Implemented
   as a tested function (`utils_reliability.R`); df from `degf(design)`.
10. **Regression:** `svyglm(quasibinomial())` → adjusted ORs; `svyglm(quasipoisson(log))`
    → prevalence ratios; `regTermTest` (Wald) for categorical significance; df from the design.

---

## Honesty guardrails (always)

Independent portfolio project; associations only ("associated with", never "causes"); no
policy recommendations beyond the data; real references only (NHANES docs, Parker et al.
2017, `survey` docs); no fabricated variable codes (verified against the OHQ_J codebook);
U.S. results do not transfer to Germany. Raw data gitignored except `MANIFEST.json`.
