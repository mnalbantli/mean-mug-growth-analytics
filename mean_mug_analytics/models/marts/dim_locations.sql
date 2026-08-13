with locations as (
    select * from {{ ref('stg_store_locations') }}
),

final as (
    select
        location_id,
        city,
        manager_name,
        address
    from locations
)

select * from final