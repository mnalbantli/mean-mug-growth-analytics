with assignments as (
    select * from {{ ref('stg_experiment_assignments') }}
),

final as (
    select
        customer_id,
        campaign_id,
        variant,
        assignment_time
    from assignments
)

select * from final