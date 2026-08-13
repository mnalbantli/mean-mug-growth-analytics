with source as (
    select * from {{ ref('offerexposurelog_dirty') }}
),

renamed as (
    select
        -- Identifiers
        "ExposureID" as exposure_id,
        "CustomerID" as customer_id,
        "CampaignID" as campaign_id,
        
        -- channel rename, lowercase
        lower("Channel") as channel,
        
        -- casting the timestamp
        cast("ExposureAt" as timestamp) as exposure_date
        
    from source
)

select * from renamed