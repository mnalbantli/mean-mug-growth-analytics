-- The Phase 0 Python script created duplicate rows for certain order_ids. 
-- To make them look like real "double-submit" checkout glitches, 
-- it slightly shifted the order_time forward for the duplicates.  


-- Write a query that returns every column from stg_orders, but strictly guarantees only one row per order_id.
-- Where duplicates exist, you must keep the original transaction—meaning the one with the earliest order_time.

with source as(
    select * from {{ ref('stg_orders') }}
),

deduped as (
    select * from source
    where order_id in (
        select order_id from source
        group by order_id
        having count(*) = 1
    )
)

select * from deduped



