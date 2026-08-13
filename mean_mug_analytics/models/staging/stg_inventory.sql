with source as (
    select * from {{ ref('inventory') }}
),

renamed as (
    select
        -- Identifiers
        "LocationID" as location_id,
        "MenuItemID" as menu_item_id,
        
        -- Dates
        cast("SnapshotDate" as date) as snapshot_date,
        
        -- Metrics
        "OnHandQty" as on_hand_qty
        
    from source
)

select * from renamed