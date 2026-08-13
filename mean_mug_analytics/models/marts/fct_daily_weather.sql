with weather as (
    select * from {{ ref('stg_external_factors') }}
),

final as (
    select
        fact_date,
        location_id,
        weather,
        high_temp,
        low_temp,
        local_event
    from weather
)

select * from final