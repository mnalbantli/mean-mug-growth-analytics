with source as (
    select * from {{ ref('promotion') }}
),

renamed as (
    select
        -- Identifiers
        "PromoID" as promo_id,
        
        -- Promotion details
        "Description" as promotion_description,
        
        -- Metrics
        "DiscountRate" as discount_rate,
        
        -- Dates
        cast("StartDate" as date) as start_date,
        cast("EndDate" as date) as end_date
        
    from source
)

select * from renamed