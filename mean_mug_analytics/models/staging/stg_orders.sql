with source as (
    -- The ref function is dbt's superpower. 
    -- It tells dbt to look at your seeds folder and grab the 'order_dirty' table.
    select * from {{ ref('order_dirty') }}
),

renamed as (
    select
        -- Rename columns to snake_case and cast data types
        "OrderID" as order_id,
        "CustomerID" as customer_id,
        "LocationID" as store_location_id,
        "PromoID" as promo_id,
        
        -- Casting the dates and times
        -- Order date has two different time formats, normalizing them with COALESCE, we need to include try_ for strptime.
        cast(COALESCE(
            try_strptime("OrderDate", '%m/%d/%Y'),
            try_strptime("OrderDate", '%Y-%m-%d')
        ) as date) as order_date,
        cast("OrderTime" as time) as order_time,
        
        -- Metric columns
        -- cast("TotalAmount" as decimal(10,2)) as total_amount,
        -- Payment type should be all lower case!
        lower("PaymentType") as payment_type_lower,

        -- Update: Detected negative total_amount, changing negative amounts to "0"
        case 
            when cast("TotalAmount" as decimal(10,2)) < 0 then 0.00
            else cast("TotalAmount" as decimal(10,2))
        end as total_amount
        
    from source
)

select * from renamed