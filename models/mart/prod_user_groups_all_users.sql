WITH user_groups AS (
    SELECT 
        business_titles AS title,
        department_okta AS department,
        network_groups AS group_name
    FROM  {{ ref('src_raw_dbt_lookup_looker_user_groups') }}
),

dim_workforce AS (
    SELECT DISTINCT
        workday_employee_number AS dwh_workforce_id,
        okta_users_id,
        looker_user_group,
        okta_title,
        okta_department_original,
        esd_isactive,
        esd_dateofhire,
        exitdate,
        lst_updt_ts,
        okta_status,
        okta_email,
        okta_department,
        dept_source,
        company,
        okta_manager,
        first_name,
        last_name,
        display_name,
        school_type_abbrev,
        school_model,
        user_group_status,
        okta_hire_date,
        okta_lastupdated,    
        CASE WHEN ug.group_name IS NOT NULL THEN 'network' else 'schooling' 
        end as user_group_type,
        DENSE_RANK() OVER (ORDER BY lst_updt_ts DESC) AS rnk
    FROM {{ ref('stg_user_groups_compare') }} AS stg
    LEFT JOIN user_groups AS ug
    ON stg.looker_user_group=ug.group_name
)

SELECT * FROM dim_workforce
