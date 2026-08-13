with exposures as (
    select * from {{ ref('stg_offer_exposures') }}
),

final as (
    select
        exposure_id,
        customer_id,
        campaign_id,
        channel,
        exposure_date
    from exposures
)

select * from final