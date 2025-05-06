WITH users AS (

    SELECT
        *
    FROM
        {{ source('public', 'OKTA_USER') }}
)

SELECT * FROM users
