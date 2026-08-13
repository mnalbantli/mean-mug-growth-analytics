with source as (
    select * from {{ ref('externalfactor') }}
),

renamed as (
    select
        -- Identifiers
        "LocationID" as location_id,
        
        -- Dates
        cast("FactDate" as date) as fact_date,
        
        -- Weather data
        "Weather" as weather,
        "HiTemp" as high_temp,
        "LoTemp" as low_temp,
        
        -- Event data
        "LocalEvent" as local_event
        
    from source
)

select * from renamed