with source as (
    select * from {{ ref('offercampaign') }}
),

renamed as (
    select
        -- Identifiers
        "CampaignID" as campaign_id,
        "MenuItemID" as menu_item_id,
        
        -- Campaign details
        "Name" as campaign_name,
        "TargetSegment" as target_segment,
        "Channel" as channel,
        
        -- Metrics
        cast("DiscountRate" as decimal(4,2)) as discount_rate,
        
        -- Dates
        cast("StartDate" as date) as start_date,
        cast("EndDate" as date) as end_date
        
    from source
)

select * from renamed