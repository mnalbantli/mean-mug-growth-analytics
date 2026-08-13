-- Duplicate blank values in "email" column. 

select
    nullif(trim(email), '')
from {{ ref("stg_customers") }} 


with source as(
    select * from {{ ref('stg_customers') }}
),

denull as (
    select *, nullif(trim(email), '') 
    from source
    )
)

select * from denull