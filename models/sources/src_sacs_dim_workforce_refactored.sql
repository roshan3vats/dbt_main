WITH dim_workforce_refactored AS (

    SELECT * FROM {{ source('public', 'DIM_WORKFORCE') }}

)

SELECT * FROM dim_workforce_refactored
