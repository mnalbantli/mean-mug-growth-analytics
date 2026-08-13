-- This test validates that GROUP BY and HAVING logic actually worked by searching for any duplicate order_ids in the cleaned intermediate model.

select
    order_id,
    count(*) as row_count
from {{ ref('int_orders_deduped') }}
group by order_id
having count(*) > 1