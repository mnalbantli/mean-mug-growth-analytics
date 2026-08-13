import pandas as pd
import numpy as np
import logging
from datetime import timedelta
import os

# Configure logging to track our chaos injection
logging.basicConfig(level=logging.INFO, format='%(levelname)s - %(message)s')

def inject_chaos(input_dir: str, output_dir: str):
    """
    Reads clean CSVs, injects seeded random chaos, and exports dirty CSVs.
    """
    # 1. Set seed for reproducibility
    # 
    np.random.seed(42)
    logging.info("Random seed set to 42 for reproducible chaos.")

    # Create output directory if it doesn't exist
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Load required datasets based on provided schemas
    try:
        customers = pd.read_csv(f"{input_dir}/customer.csv")
        orders = pd.read_csv(f"{input_dir}/order.csv")
        orderitems = pd.read_csv(f"{input_dir}/orderitem.csv")
        exposure = pd.read_csv(f"{input_dir}/offerexposurelog.csv")
        logging.info("Datasets loaded successfully.")
    except FileNotFoundError as e:
        logging.error(f"Error loading files: {e}")
        return

    # ---------------------------------------------------------
    # CHAOS INJECTION
    # ---------------------------------------------------------

    # 1. Nulls: 3-5% of non-critical fields
    # Targeting Email in customers (where currently 1000 non-null)
    null_frac_email = np.random.uniform(0.03, 0.05)
    email_idx = customers.sample(frac=null_frac_email).index
    customers.loc[email_idx, 'Email'] = np.nan
    logging.info(f"Injected Nulls: {len(email_idx)} into customer['Email'] ({null_frac_email:.1%}).")

    # 2. Duplicate Transactions: Double-submit bugs (1-2%)
    dup_frac = np.random.uniform(0.01, 0.02)
    dup_orders = orders.sample(frac=dup_frac).copy()
    
    if not dup_orders.empty:
        # Shift the OrderTime slightly by 1-5 seconds
        time_shifts = pd.to_timedelta(np.random.randint(1, 6, size=len(dup_orders)), unit='s')
        dup_orders['OrderTime'] = (pd.to_datetime(dup_orders['OrderTime'], format='%H:%M:%S').dt.time)
        dup_orders['OrderTime'] = pd.to_datetime(dup_orders['OrderTime'].astype(str)) + time_shifts
        dup_orders['OrderTime'] = dup_orders['OrderTime'].dt.strftime('%H:%M:%S')
        
        # Generate new OrderIDs to mimic a real double submit bypassing idempotency
        max_order_id = orders['OrderID'].max()
        dup_orders['NewOrderID'] = range(max_order_id + 1, max_order_id + 1 + len(dup_orders))
        
        # Grab corresponding order items and update their OrderIDs
        dup_orderitems = orderitems[orderitems['OrderID'].isin(dup_orders['OrderID'])].copy()
        
        # Map old OrderID to NewOrderID
        id_mapping = dict(zip(dup_orders['OrderID'], dup_orders['NewOrderID']))
        dup_orders['OrderID'] = dup_orders['NewOrderID']
        dup_orders.drop(columns=['NewOrderID'], inplace=True)
        dup_orderitems['OrderID'] = dup_orderitems['OrderID'].map(id_mapping)
        
        # Append duplicates
        orders = pd.concat([orders, dup_orders], ignore_index=True)
        orderitems = pd.concat([orderitems, dup_orderitems], ignore_index=True)
        logging.info(f"Injected Duplicates: {len(dup_orders)} double-submitted orders and their items.")

    # 3. Negative/Impossible Values
    # Negative Totals and Quantities (refund artifacts)
    neg_order_idx = orders.sample(5).index
    orders.loc[neg_order_idx, 'TotalAmount'] *= -1
    
    neg_item_idx = orderitems.sample(5).index
    orderitems.loc[neg_item_idx, 'Quantity'] *= -1
    logging.info("Injected Negatives: 5 negative TotalAmounts and 5 negative Quantities.")

    # OrderDate predates JoinDate
    merged_for_dates = orders.merge(customers[['CustomerID', 'JoinDate']], on='CustomerID', how='inner')
    impossible_date_idx = merged_for_dates.sample(3).index
    for idx in impossible_date_idx:
        join_date = pd.to_datetime(merged_for_dates.loc[idx, 'JoinDate'])
        # Shift OrderDate to 1-10 days BEFORE JoinDate
        bad_date = join_date - timedelta(days=np.random.randint(1, 10))
        # Apply back to the main orders df
        actual_order_idx = orders.index[orders['OrderID'] == merged_for_dates.loc[idx, 'OrderID']][0]
        orders.loc[actual_order_idx, 'OrderDate'] = bad_date.strftime('%Y-%m-%d')
    logging.info("Injected Time-Travel: 3 OrderDates that predate Customer JoinDates.")

    # 4. Referential Orphans: MenuItemID doesn't exist
    orphan_idx = orderitems.sample(4).index
    orderitems.loc[orphan_idx, 'MenuItemID'] = 99999  # Non-existent ID
    logging.info("Injected Orphans: 4 order items pointing to non-existent MenuItemID 99999.")

    # 5. Inconsistent Formatting
    # Mixed date formats in OrderDate (MM/DD/YYYY vs YYYY-MM-DD)
    date_format_idx = orders.sample(frac=0.1).index
    orders.loc[date_format_idx, 'OrderDate'] = pd.to_datetime(orders.loc[date_format_idx, 'OrderDate']).dt.strftime('%m/%d/%Y')
    
    # Trailing whitespace in Email and Name
    space_idx = customers.sample(frac=0.08).index
    customers.loc[space_idx, 'Email'] = customers.loc[space_idx, 'Email'].astype(str) + "   "
    customers.loc[space_idx, 'Name'] = " " + customers.loc[space_idx, 'Name'].astype(str) + "  "
    logging.info("Injected Formatting Errors: Mixed date formats in orders and trailing spaces in customer names/emails.")

    # 6. Case Inconsistency
    # Randomize casing in PaymentType (e.g. App, APP, app)
    def randomize_case(val):
        if pd.isna(val): return val
        choice = np.random.choice(['lower', 'upper', 'title'])
        if choice == 'lower': return str(val).lower()
        if choice == 'upper': return str(val).upper()
        return str(val).title()

    orders['PaymentType'] = orders['PaymentType'].apply(randomize_case)
    
    # Randomize casing in Channel in offerexposurelog
    exposure['Channel'] = exposure['Channel'].apply(randomize_case)
    logging.info("Injected Case Inconsistency: Randomized casing for PaymentType and Channel.")

    # ---------------------------------------------------------
    # GENERATE CHAOS MANIFEST
    # ---------------------------------------------------------
    manifest_path = f"{output_dir}/chaos_manifest.md"
    manifest_content = f"""# Mean Mug Chaos Manifest
    
    This file documents the exact volume of data corruption injected into the synthetic dataset. Use these numbers as the acceptance criteria for dbt testing.

    * **Nulls Injected**: {len(email_idx)} emails removed ({null_frac_email:.1%}).
    * **Duplicates Injected**: {len(dup_orders)} double-submitted orders.
    * **Negative Values**: 5 orders (TotalAmount), 5 items (Quantity).
    * **Time-Travel Errors**: 3 OrderDates predating Customer JoinDates.
    * **Orphans**: 4 order items pointing to non-existent MenuItemID 99999.
    * **Formatting Errors**: {len(date_format_idx)} mixed dates, {len(space_idx)} trailing whitespace issues.
    """
    
    with open(manifest_path, "w") as f:
        f.write(manifest_content)
        
    logging.info(f"Chaos manifest generated successfully at {manifest_path}.")

    # ---------------------------------------------------------
    # EXPORT DIRTY DATA
    # ---------------------------------------------------------
    customers.to_csv(f"{output_dir}/customer_dirty.csv", index=False)
    orders.to_csv(f"{output_dir}/order_dirty.csv", index=False)
    orderitems.to_csv(f"{output_dir}/orderitem_dirty.csv", index=False)
    exposure.to_csv(f"{output_dir}/offerexposurelog_dirty.csv", index=False)
    
    logging.info(f"Chaos injection complete. Files saved to {output_dir}/")

if __name__ == "__main__":
    # Example usage (assumes CSVs are in './clean_data' and outputs to './dirty_data')
    inject_chaos('./raw_data', './dirty_data')
    print("Chaos Injector script ready. Uncomment the execution line to run.")