with source as (
    -- The ref function is dbt's superpower. 
    -- It tells dbt to look at your seeds folder and grab the 'order_dirty' table.
    select * from {{ ref('orderitem_dirty') }}
),

renamed as (
    select
        -- Rename columns to snake_case and cast data types
        "OrderID" as order_id,
        "OrderItemID" as order_item_id,
        "MenuItemID" as menu_item_id,
        
        -- Metric columns
        cast("Quantity" as decimal(5,2)) as quantity,
        cast("PriceEach" as decimal(5,2)) as price_each,
        cast("LineTotal" as decimal(10,2)) as line_total
        
    from source
)

select * from renamed