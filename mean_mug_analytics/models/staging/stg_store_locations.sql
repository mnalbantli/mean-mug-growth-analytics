with source as (
    select * from {{ ref('storelocation') }}
),

renamed as (
    select
        -- Identifiers
        "LocationID" as location_id,
        
        -- Location details
        "Address" as address,
        "City" as city,
        
        -- Personnel
        "ManagerName" as manager_name
        
    from source
)

select * from renamed