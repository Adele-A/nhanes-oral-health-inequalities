# CLAUDE.md — Oral Health & Dental Care Use (NHANES 2017–2018)

**Authoritative task spec:** `../init-prompts/03_oral_health_nhanes_inequalities.md`.
Read it in full and follow it. This file holds the durable guardrails only.

Independent portfolio project for Adele Amanzhol (GitHub `Adele-A`). Stack: R ≥ 4.3,
`survey`, Quarto, renv. Entry point: `Rscript run_all.R`. Value = correct complex-survey
methodology, not "interesting" findings.

## Guardrails (always)
- **Language:** talk to the user in Russian; all repo content in English.
- **Honesty:** independent portfolio project; associations only — "associated with", never
  "causes"; no policy recommendations beyond the data; references must be real (NHANES docs,
  Parker et al. 2017, `survey` docs); never fabricate variable codes — verify against codebook.
- **Stop at Stage 0:** `docs/PLAN.md` + draft `docs/analysis_plan.md`, show them, wait for "ок".
- **Pre-specify:** finalize and commit `docs/analysis_plan.md` **before** computing any
  association estimates (separate commit "Pre-specify analysis plan").
- **Git:** stage-by-stage commits after tests; `git init` if needed (branch `main`);
  **never push without explicit confirmation.**
- **Data:** `data/raw/` gitignored except `MANIFEST.json`; download via `nhanesA`/`read_xpt`;
  stop if CDC URLs are unreachable and ask for manual XPT placement.
- **Cross-platform (Win+macOS):** `here::here()`/`file.path()`, no `setwd()`; `readr` utf-8;
  `renv.lock` with CRAN binary packages only (no Rtools/Xcode compile); Quarto **HTML**
  rendering must not require LaTeX; `.gitattributes eol=lf`; CI matrix ubuntu/windows/macos.
- **Power BI:** export only **pre-computed estimates with CIs** (never weighted microdata —
  Power BI can't do design-based variance); Adele builds `.pbix`; Quarto HTML is the
  cross-platform results version.

## Project-specific traps (see spec §3–4)
- Build `svydesign` on the **full** DEMO_J sample; take 20+/valid-outcome subsets via
  `subset(design, ...)` — never filter before building the design.
- Weights: `WTINT2YR` (interview component), not `WTMEC2YR`.
- Recode 7/9/77/99 to NA; apply NCHS reliability standards (Parker et al. 2017).
- Report both odds ratios and prevalence ratios; degrees of freedom from `degf(design)`.

## Environment
R 4.6 and Quarto 1.11 are being installed during setup — before starting, confirm
`Rscript --version` and `quarto --version` work (reopen the terminal if PATH is stale), then
`install.packages("renv"); renv::restore()`. Details: `../init-prompts/ENVIRONMENT.md`.
