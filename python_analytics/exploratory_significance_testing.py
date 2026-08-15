"""
Exploratory script — checks the assumptions behind a naive t-test on campaign
lift (AOV, basket size) before committing to a test in campaign_lift.ipynb.

Aggregates fct_orders to one row per customer per promo group (to avoid the
repeat-customer clustering issue found separately), then reports distribution
shape (mean, std, skew, Shapiro-Wilk) and equal-variance checks (Levene's)
for each group. Not the final analysis — informs which test is valid.
"""

import pandas as pd
from scipy import stats

from db_connections import connect

con = connect.get_warehouse_connection("../mean_mug_analytics/mean_mug.duckdb")
df = con.execute(
    "SELECT order_id, customer_id, promo_id, total_amount, total_items_in_basket "
    "FROM fct_orders"
).df()
con.close()

# Same cleanup as campaign_lift.ipynb: groupby() drops null keys by default,
# which would silently exclude the control group.
df["promo_id"] = df["promo_id"].astype("string")
df["promo_id"] = df["promo_id"].fillna("No_Promo")

# Aggregate to one row per customer per promo group, so each observation fed
# into the significance tests below is an independent customer, not an order
# (orders from the same repeat customer are not independent draws).
customer_df = (
    df.groupby(["promo_id", "customer_id"])
    .agg(
        customer_aov=("total_amount", "mean"),
        customer_basket_size=("total_items_in_basket", "mean"),
    )
    .reset_index()
)

groups = {
    name: group
    for name, group in customer_df.groupby("promo_id")
}

metrics = ["customer_aov", "customer_basket_size"]

print("=" * 80)
print("PER-GROUP DISTRIBUTION SUMMARY (one row per customer)")
print("=" * 80)

rows = []
for promo_name, group in groups.items():
    for metric in metrics:
        values = group[metric].dropna()
        n = len(values)
        mean = values.mean()
        std = values.std(ddof=1)
        skew = stats.skew(values)

        # Shapiro-Wilk requires n >= 3
        if n >= 3:
            shapiro_stat, shapiro_p = stats.shapiro(values)
        else:
            shapiro_stat, shapiro_p = float("nan"), float("nan")

        rows.append(
            {
                "promo_id": promo_name,
                "metric": metric,
                "n": n,
                "mean": mean,
                "std": std,
                "skewness": skew,
                "shapiro_stat": shapiro_stat,
                "shapiro_p": shapiro_p,
                "normal_at_0.05": shapiro_p >= 0.05 if n >= 3 else None,
            }
        )

summary = pd.DataFrame(rows)
pd.set_option("display.width", 140)
pd.set_option("display.max_columns", None)
print(summary.to_string(index=False))

print()
print("=" * 80)
print("LEVENE'S TEST FOR EQUAL VARIANCES (vs. No_Promo control)")
print("=" * 80)

control = groups["No_Promo"]
levene_rows = []
for promo_name in ["1", "2"]:
    if promo_name not in groups:
        continue
    test_group = groups[promo_name]
    for metric in metrics:
        stat, p = stats.levene(
            control[metric].dropna(), test_group[metric].dropna()
        )
        levene_rows.append(
            {
                "comparison": f"Promo {promo_name} vs No_Promo",
                "metric": metric,
                "levene_stat": stat,
                "levene_p": p,
                "equal_variance_at_0.05": p >= 0.05,
            }
        )

levene_summary = pd.DataFrame(levene_rows)
print(levene_summary.to_string(index=False))
