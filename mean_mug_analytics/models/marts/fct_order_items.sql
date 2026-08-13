with order_items as (
    select * from {{ ref('int_order_items_cleaned') }}
),

final as (
    select 
        order_item_id,
        -- Select foreign keys (order_id, menu_item_id)
        order_id, menu_item_id,
        -- Select numeric measures (like quantity, line_total, or discount_amount)
        quantity, price_each, line_total
    from order_items
)

select * from final