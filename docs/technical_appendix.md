# Technical Appendix — Mean Mug Growth Analytics

Full architecture, modeling decisions, and methodology behind the findings in the main [README](../README.md).

## Pipeline

raw CSVs → seeded chaos injection (`chaos_injector.py`, `np.random.seed(42)`, logged in `chaos_manifest.md`) → dbt (staging → intermediate → marts, DuckDB) → Python statistical analysis → BigQuery export → Power BI.

## Data Quality

25+ dbt tests (generic + singular), purpose-built to catch the exact corruption types injected upstream — the before/after contrast is the project's core proof point, not just a compliance checkbox.

## Key Modeling Decisions

- `fct_experiment_assignments` and `fct_campaign_exposures` split from a single exposures table to avoid fan-out at different grains.
- `int_orders_deduped` — window-function deduplication; `int_order_items_cleaned` — orphan-record filtering.
- Campaign lift re-analyzed at customer grain (not order grain) after discovering that 56–80% of orders per promo group came from repeat customers, violating the independence assumption behind an order-level t-test.

## Statistical Methodology — Campaign Lift

- **Variance check:** Levene's test rejected the equal-variance assumption between promo and control groups.
- **Test selection:** Welch's t-test used instead of Student's t-test, appropriate for unequal variances.
- **Effect size:** Glass's delta (control-group SD as the yardstick) used instead of pooled-SD Cohen's d, because the design has a true control group — pooled SD would be inconsistent with the unequal-variance finding.
- **Result:** no comparison reached statistical significance at α = 0.05, for either promo group, on either AOV or basket size.

Full results: `outputs/significance_testing_results.csv`.

## Tech Stack

dbt Core, DuckDB (local warehouse), BigQuery (cloud warehouse), Python (pandas, scipy), Power BI Desktop, Git/GitHub.

## CI/CD

Planned — GitHub Actions running `dbt test` on push/PR. Not yet built.

## Git/GitHub Workflow

Developed on feature branches with PR review before merge — see `add-statistical-significance-testing`, `reorganize-python-connections`.
