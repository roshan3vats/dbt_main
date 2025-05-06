WITH user_groups AS (

    SELECT *
    FROM {{ source('public', 'LOOKER_USER_GROUP') }}
)

SELECT * FROM user_groups
