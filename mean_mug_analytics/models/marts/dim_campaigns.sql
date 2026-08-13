with campaigns as (
    select * from {{ ref('stg_offercampaign') }}
),

final as (
    select
        campaign_id,
        campaign_name,
        target_segment,
        channel,
        discount_rate,
        start_date,
        end_date,
        menu_item_id
    from campaigns
)

select * from final