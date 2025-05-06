WITH ds AS (
    SELECT
        *
    FROM
        {{ source('public', 'DIM_SCHOOL') }}
)

SELECT * FROM ds
