-- Create a new file in your models/intermediate/ folder called int_order_items_cleaned.sql. 
--Write a query that returns all columns from the stg_order_items table, 
-- but strictly filters out any rows where the menu_item_id does not have a matching ID in the stg_menuitem table.

WITH trans_data as (
    select * from {{ ref('stg_order_items') }}
),

ref_catalog as (
    select * from {{ ref('stg_menu_items') }}
),

final as (
    select td.*
    from trans_data as td
    inner join ref_catalog as rc ON td.menu_item_id = rc.menu_item_id 
)

select * from final