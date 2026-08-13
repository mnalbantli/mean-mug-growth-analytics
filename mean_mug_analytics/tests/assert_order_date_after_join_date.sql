-- A customer's first_order date can never happen after their last_order date, and an order cannot happen in the future.

select
    customer_id,
    first_order,
    last_order
from {{ ref('dim_customers') }}
where first_order > last_order
   or last_order > current_date