with source as (
    select * from {{ ref('experimentassignment') }}
),

renamed as (
    select
        -- Identifiers
        "CustomerID" as customer_id,
        "CampaignID" as campaign_id,
        
        "Variant" as variant,
        
        -- casting the timestamp
        cast("AssignedAt" as timestamp) as assignment_time
        
    from source
)

select * from renamed