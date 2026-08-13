with menu_items as (
    select * from {{ ref('stg_menu_items') }}
),

final as (
    select
        menu_item_id,
        item_name,
        category,
        -- To find the seasonal items, I ran a DISTINCT query to find all unique items and chose the seasonal ones (can be done via asking the marketing dp)
        case 
            when item_name in (
                'Winter Veggie Breakfast Wrap',
                'Iced Peppermint Cold Brew',
                'Peppermint Mocha',
                'Toasted Marshmallow Latte',
                'Maple Pecan Bar',
                'Maple Brown Sugar Latte',
                'Gingerbread Cookie',
                'Turkey Cranberry Panini',
                'Winterberry Herbal Tea',
                'Chocolate Peppermint Scone',
                'Cranberry Orange Muffin',
                'Gingerbread Latte'
            ) then true
            else false
        end as is_seasonal
    from menu_items
)

select * from final