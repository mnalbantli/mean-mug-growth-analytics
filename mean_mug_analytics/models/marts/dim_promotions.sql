with promotions as (
    select * from {{ ref('stg_promotions') }}
),

final as (
    select
        promo_id,
        promotion_description,
        discount_rate,
        start_date,
        end_date
    from promotions
)

select * from final