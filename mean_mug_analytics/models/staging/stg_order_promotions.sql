with source as (
    select * from {{ ref('orderpromotion') }}
),

renamed as (
    select
        -- Identifiers
        "OrderID" as order_id,
        "PromoID" as promo_id
    from source
)

select * from renamed