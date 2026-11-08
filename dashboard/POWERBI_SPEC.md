# Power BI dashboard specification

A compact, display-only dashboard over the **pre-computed** design-based estimates in
`dashboard/data/`. Power BI **does not** recompute any proportion, weight, or variance — it
only displays the estimates and their confidence intervals produced by the R pipeline.

> Build note (cross-platform): **Power BI Desktop is Windows-only.** On macOS, build the
> `.pbix` in a Windows virtual machine or on a Windows PC. The Quarto HTML report
> (`report/oral_health_report.html`) is the cross-platform version of these results.

Every page footer: **"US adults, NHANES 2017–2018; associations, not causal effects."**

## Data model

Import the CSVs from `dashboard/data/` and set relationships (see `DATA_DICTIONARY.md`):

- `fact_estimates[outcome]` → `dim_outcome[outcome]`
- `fact_estimates[group_variable]` → `dim_group_variable[group_variable]`
- `fact_estimates[reliability_flag]` → `dim_reliability[reliability_flag]`
- `fact_model_coefficients` stands alone (slice by `model`, `measure`, `covariate`).

Set data types: `estimate`, `ci_*`, `*_pct`, `se`, `p_value` → Decimal number;
`n_unweighted`, `df` → Whole number; `reliable` → True/False.

## Pages

### Page 1 — No recent dental visit, by group
- **Visual:** horizontal bar / dot plot of `estimate_pct` by `group_level`, grouped by
  `group_variable`, filtered to `outcome = "No dental visit in past 12 months"`.
- **Error bars:** add `ci_low_pct` / `ci_high_pct` (Analytics pane → Error bars, or a
  dedicated error-bar visual).
- **Reliability:** conditional formatting — mark rows where `reliability_flag <> "reliable"`
  (e.g. hollow marker / grey) and show a footnote.
- **Slicers:** `group_variable`.

### Page 2 — Reasons for visit & self-reported unmet need
- **Visual A:** 100% stacked bar of `fact_reason_for_visit[weighted_pct]` by `reason`.
- **Visual B:** bar of unmet-need prevalence by income / insurance from `fact_estimates`
  filtered to `outcome = "Self-reported unmet dental need"`, with CI error bars.
- **Visual C:** bar of `fact_unmet_need_reasons[weighted_pct]` by `reason_label`
  (top reasons; cost dominates).

### Page 3 — Adjusted associations (forest plot)
- **Visual:** forest plot from `fact_model_coefficients` filtered to
  `model = "Adjusted (b)"`: `estimate` on a **log axis** by `term`, with `ci_low`/`ci_high`
  error bars and a reference line at **1.0**.
- **Toggle:** slicer on `measure` (OR vs PR).
- **Note text box:** "Odds ratios exceed prevalence ratios because the outcome is common;
  prevalence ratios are the more conservative relative measure."

## DAX measures (ready to paste)

```DAX
Estimate % = SELECTEDVALUE(fact_estimates[estimate_pct])

CI Low % = SELECTEDVALUE(fact_estimates[ci_low_pct])

CI High % = SELECTEDVALUE(fact_estimates[ci_high_pct])

CI Label =
VAR lo = SELECTEDVALUE(fact_estimates[ci_low_pct])
VAR hi = SELECTEDVALUE(fact_estimates[ci_high_pct])
RETURN FORMAT(lo, "0.0") & "–" & FORMAT(hi, "0.0") & "%"

Unweighted n = SUM(fact_estimates[n_unweighted])

Is Reliable = IF(SELECTEDVALUE(fact_estimates[reliable]) = TRUE(), "Reliable", "Flagged")

Reliability Note =
IF(
    SELECTEDVALUE(fact_estimates[reliability_flag]) <> "reliable",
    "⚠ Estimate flagged under NCHS reliability standards (interpret with caution).",
    ""
)

OR or PR = SELECTEDVALUE(fact_model_coefficients[estimate])

OR/PR CI Label =
VAR lo = SELECTEDVALUE(fact_model_coefficients[ci_low])
VAR hi = SELECTEDVALUE(fact_model_coefficients[ci_high])
RETURN FORMAT(lo, "0.00") & "–" & FORMAT(hi, "0.00")

Significant (p<0.05) =
IF(SELECTEDVALUE(fact_model_coefficients[p_value]) < 0.05, "Yes", "No")
```

> These measures only **display** the pre-computed estimates; they never recompute a
> proportion, ratio, or confidence interval. All statistical computation happens in R
> (`R/04_descriptives.R`, `R/05_models.R`) using the complex-survey design.

## Status

Data model and specification are complete; the `.pbix` and screenshots are produced by
Adele and are **not** included here yet. Do not describe the dashboard as "built" until the
`.pbix`/screenshots are added.
