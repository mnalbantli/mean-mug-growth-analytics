with source as (
    select * from {{ ref('customersegment') }}
),

renamed as (
    select
        -- Identifiers
        "SegmentID" as segment_id,
        
        "SegmentName" as segment_name
        
    from source
)

select * from renamed