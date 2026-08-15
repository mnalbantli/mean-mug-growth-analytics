"""
Statistical significance testing for campaign lift (Promo 1 / Promo 2 vs. control).

Test rationale (from exploratory_significance_testing.py):
  - Unit of analysis is the CUSTOMER, not the order. A prior check
    (repeat-customer overlap) found 56-80% of orders per promo group come from
    customers with more than one order in that group, so order-level rows are
    not independent observations. Aggregating to one row per customer per
    group restores independence across rows within each group.
  - Shapiro-Wilk rejected normality for every group/metric, but skewness was
    mild (|skew| < 0.27) in all cases -- at n=450-650 this looks like Shapiro's
    known over-sensitivity at large n rather than a pathological distribution,
    so a t-test is still a reasonable choice.
  - Levene's test rejected equal variances for BOTH comparisons on BOTH
    metrics (all p < 0.005), so the pooled-variance assumption behind a
    standard Student's t-test does not hold. Welch's t-test (equal_var=False)
    is used instead, since it does not assume equal variances.
"""

import logging
import os

import pandas as pd
from scipy import stats

from db_connections import connect

logging.basicConfig(level=logging.INFO, format='%(levelname)s - %(message)s')

DB_PATH = '../mean_mug_analytics/mean_mug.duckdb'
OUTPUT_PATH = 'outputs/significance_testing_results.csv'
ALPHA = 0.05


def glass_delta(test_sample: pd.Series, control_sample: pd.Series) -> float:
    """Glass's delta: mean difference scaled by the CONTROL group's std dev only.

    Preferred over Cohen's d here because Levene's test found unequal
    variances between each test group and control -- Glass's delta avoids
    pooling those variances and instead treats control as the stable
    reference distribution.
    """
    control_std = control_sample.std(ddof=1)
    return (test_sample.mean() - control_sample.mean()) / control_std


def main():
    # 1. Pull the raw order-level data
    con = connect.get_warehouse_connection(DB_PATH)
    df = con.execute(
        'SELECT order_id, customer_id, promo_id, total_amount, total_items_in_basket '
        'FROM fct_orders'
    ).df()
    con.close()
    logging.info(f"Pulled {len(df)} rows from fct_orders.")

    # 2. Same promo_id cleanup as campaign_lift.ipynb: groupby() drops null
    #    keys by default, which would silently exclude the control group.
    df['promo_id'] = df['promo_id'].astype('string')
    df['promo_id'] = df['promo_id'].fillna('No_Promo')

    # 3. Aggregate to one row per customer per promo group
    customer_df = (
        df.groupby(['promo_id', 'customer_id'])
        .agg(
            customer_aov=('total_amount', 'mean'),
            customer_basket_size=('total_items_in_basket', 'mean'),
        )
        .reset_index()
    )
    logging.info(f"Aggregated to {len(customer_df)} customer-group rows.")

    groups = {name: group for name, group in customer_df.groupby('promo_id')}
    control = groups['No_Promo']
    metrics = ['customer_aov', 'customer_basket_size']

    # 4. Welch's t-test + Glass's delta for each comparison and metric
    results = []
    for promo_name in ['1', '2']:
        if promo_name not in groups:
            logging.warning(f"No group found for promo_id={promo_name}, skipping.")
            continue

        test_group = groups[promo_name]
        comparison = f"Promo {promo_name} vs No_Promo"

        for metric in metrics:
            control_vals = control[metric].dropna()
            test_vals = test_group[metric].dropna()

            t_stat, p_value = stats.ttest_ind(
                test_vals, control_vals, equal_var=False
            )
            d = glass_delta(test_vals, control_vals)
            mean_diff = test_vals.mean() - control_vals.mean()
            significant = p_value < ALPHA

            logging.info(
                f"{comparison} | {metric}: mean_diff={mean_diff:.4f}, "
                f"t={t_stat:.4f}, p={p_value:.6f}, d={d:.4f}, "
                f"significant={significant}"
            )

            results.append(
                {
                    'comparison': comparison,
                    'metric': metric,
                    'n_test': len(test_vals),
                    'n_control': len(control_vals),
                    'mean_diff': mean_diff,
                    't_stat': t_stat,
                    'p_value': p_value,
                    'glass_delta': d,
                    'significant_at_0.05': significant,
                }
            )

    summary = pd.DataFrame(results)

    # 5. Output
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    summary.to_csv(OUTPUT_PATH, index=False)
    logging.info(f"Wrote results to {OUTPUT_PATH}")

    pd.set_option('display.width', 140)
    print(summary.to_string(index=False))


if __name__ == '__main__':
    main()
