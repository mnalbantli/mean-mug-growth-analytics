# Mean Mug Chaos Manifest
    
    This file documents the exact volume of data corruption injected into the synthetic dataset. Use these numbers as the acceptance criteria for dbt testing.

    * **Nulls Injected**: 37 emails removed (3.7%).
    * **Duplicates Injected**: 55 double-submitted orders.
    * **Negative Values**: 5 orders (TotalAmount), 5 items (Quantity).
    * **Time-Travel Errors**: 3 OrderDates predating Customer JoinDates.
    * **Orphans**: 4 order items pointing to non-existent MenuItemID 99999.
    * **Formatting Errors**: 282 mixed dates, 80 trailing whitespace issues.
    