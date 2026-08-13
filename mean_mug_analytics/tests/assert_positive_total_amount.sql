-- This test scans the fact table and fails if any order claims to have made less than zero dollars.
select
    order_id,
    customer_id,
    total_amount
from {{ ref('fct_orders') }}
where total_amount < 0