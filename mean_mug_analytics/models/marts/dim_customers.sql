with customer_orders_summary as (
    select
        customer_id,
        -- Calculate 4 metrics:
        -- 1. First order date
        min(order_date) as first_order,
        -- 2. Most recent order date (from Query 4)
        max(order_date) as last_order,
        -- 3. Total lifetime orders (from Query 4)
        count(order_id) as total_orders,
        -- 4. Total lifetime spend (from Query 4)
        sum(total_amount) as total_spend
    from {{ ref('int_orders_deduped') }}
    group by customer_id
),

customers as (
    select * from {{ ref('stg_customers') }}
),

final as (
    -- We will write the LEFT JOIN here in the next step
    select * exclude(cos.customer_id)
    from customers c
    left join customer_orders_summary cos ON c.customer_id = cos.customer_id
)

select * from final