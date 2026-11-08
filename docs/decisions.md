# Analysis decisions log

Records the contentious / discretionary choices, the option chosen, and the rationale.
Finalized at Stage 2 (before any association estimate). Approved by project controller.

## Reference levels (regression)

| Covariate | Reference level | Rationale |
|---|---|---|
| `age_group` | 20–34 | youngest adult group |
| `sex` | Male | arbitrary, documented |
| `race` | Non-Hispanic White | largest group; conventional NCHS reference |
| `educ` | College graduate+ | highest education (expected highest utilization) |
| `income_cat` | ≥4.0 | highest income band |
| `oral_health` | Excellent/Very good | best self-rated health |
| `insurance` | Insured | majority category |

## Discretionary decisions

1. **Study population — adults 20+.** `DMDEDUC2` (education) is collected only for 20+, so
   restricting to 20+ keeps education defined across the analytic domain. Applied as a
   survey domain via `subset(design, is_adult == 1 & !is.na(outcome))`, never by filtering
   before the design is built.

2. **Weight — `WTINT2YR`.** The oral-health questions are part of the in-home CAPI
   interview; there is no MEC examination join, so the interview weight is correct, not
   `WTMEC2YR`.

3. **Primary outcome coding.** `no_recent_visit` = `OHQ030 ∈ {3,4,5,6,7} → 1`, `{1,2} → 0`,
   `{77,99,NA} → NA`. Framed as a **utilization indicator**, explicitly not proven unmet need.

4. **Age groups** 20–34 / 35–49 / 50–64 / 65+. 65+ marks Medicare eligibility; traditional
   Medicare excludes routine dental, which is relevant to utilization. A sensitivity analysis
   uses a finer split.

5. **Education** collapsed to 4 categories (< HS / HS-GED / some college / college grad+) to
   avoid sparse cells in the smallest `DMDEDUC2` level.

6. **Income** categorized from `INDFMPIR` into < 1.0 / 1.0–1.99 / 2.0–3.99 / ≥ 4.0 (standard
   poverty bands; `INDFMPIR` is top-coded at 5.0).

7. **Missing income (13.3%).** *Primary regression* = complete-case on model covariates.
   *Descriptive tables* additionally show an explicit "Missing" income group so no one is
   silently dropped. *Sensitivity* = missing-indicator model (income "Missing" as its own
   level) retaining the full sample. (Multiple imputation with `mice` noted as a possible
   extension, not implemented.)

8. **Self-rated oral health (`OHQ845`) role.** The relationship with utilization is
   **bidirectional** (poor oral health can prompt problem-driven visits; lack of visits can
   worsen oral health). Therefore the primary adjusted model is sociodemographic only; a
   separate exploratory model adds `oral_health`, interpreted cautiously as an association
   possibly reflecting reverse causation. It is **not** entered into the primary adjusted
   model as an ordinary confounder.

9. **CI method.** Proportions use `svyciprop(method = "beta")` (Korn–Graubard), as in NCHS
   publications; `"logit"` computed as a cross-check.

10. **Reliability.** NCHS Data Presentation Standards for Proportions (Parker et al. 2017):
    minimum unweighted denominator 30; relative Korn–Graubard CI width ≤ 130%; design
    df ≥ 8; effective sample size ≥ 30. Implemented in `R/utils_reliability.R` with tests.

11. **Effect measures.** Adjusted odds ratios (`svyglm`, `quasibinomial`) **and** prevalence
    ratios (`svyglm`, `quasipoisson(log)`), because the outcome is common (~⅓ of adults,
    weighted) so ORs overstate relative risk. Design df throughout (`degf(design)`).
