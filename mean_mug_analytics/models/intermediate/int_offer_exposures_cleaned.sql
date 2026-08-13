-- All values checked, relationship check, only lower() needed for the channel variable.
select 
    *
from {{ ref('stg_offer_exposures') }}