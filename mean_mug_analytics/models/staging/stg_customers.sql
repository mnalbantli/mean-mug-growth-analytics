with source as (
    select * from {{ ref('customer_dirty') }}
),

renamed as (
    select
        -- Identifiers
        "CustomerID" as customer_id,
        "SegmentID" as segment_id,
        
        -- Customer details with explicit naming
        "Name" as customer_name,
        "Email" as email,
        
        -- Dates and metrics
        cast("JoinDate" as date) as join_date,
        "LoyaltyPoints" as loyalty_points
        
    from source
)

select * from renamed