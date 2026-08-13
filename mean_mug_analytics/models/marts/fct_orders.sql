
WITH orders as(
    select
        *
    from {{ ref('int_orders_deduped') }}
),

order_items as(
    select
        order_id,
        count(menu_item_id) as total_items_in_basket
    from {{ ref('int_order_items_cleaned') }}
    group by order_id
),

final as(
    select
        * exclude(oi.order_id)
    from orders o
    left join order_items oi ON o.order_id = oi.order_id
)

from final