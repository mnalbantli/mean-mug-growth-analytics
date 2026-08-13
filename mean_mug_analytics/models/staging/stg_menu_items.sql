with source as (
    select * from {{ ref('menuitem') }}
),

renamed as (
    select
        -- Identifiers
        "MenuItemID" as menu_item_id,
        
        -- Item details
        "ItemName" as item_name,
        "Category" as category,
        
        -- Metric columns
        cast("Price" as decimal(9,2)) as price,
        cast("Cost" as decimal(9,2)) as cost,
        
        -- Status flags
        "Available" as is_available
        
    from source
)

select * from renamed