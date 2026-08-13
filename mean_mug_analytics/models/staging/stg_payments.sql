with source as (
    select * from {{ ref('payment') }}
),

renamed as (
    select
        -- Identifiers
        "OrderID" as order_id,
        "TxnRef" as transaction_ref,
        
        -- Payment details
        "Method" as payment_method,
        
        -- Financials
        "Amount" as amount,
        
        -- Status flags
        "Status" as payment_status
        
    from source
)

select * from renamed