WITH  workforce as (
select distinct 
replace(business_title, ', ','--') okta_title,
id AS okta_users_id,
worker_id AS workday_employee_number,
okta_department,
wr.hire_date AS okta_hire_date,
lastupdated AS okta_lastupdated,
company,
lower(manager) AS okta_manager,
wr.first_name,
wr.last_name,
display_name,
active AS esd_isactive,
original_hire_date AS esd_dateofhire,
termination_date AS exitdate,
lst_updt_ts,
-- dwh_workforce_id, --removed as its unavailable in new source
status AS okta_status,
wr.email_address AS okta_email
from {{ ref('src_sacs_dim_workforce_refactored') }} AS wr
LEFT JOIN {{ ref('src_okta_users') }} AS ou
ON cast(wr.worker_id as string) = cast(ou.employee_number as string)
where 
--derived_is_active = 1
business_title is not null
--where (esd_isactive = 'Yes' or okta_status = 'ACTIVE')
--and okta_title is not null
),

manager_department_all as (
select distinct
lower(wr.first_name) || '.' || lower(wr.last_name) full_name,
wr.okta_department
from {{ ref('src_sacs_dim_workforce_refactored') }} AS wr
LEFT JOIN {{ ref('src_okta_users') }} AS ou
ON wr.worker_id = ou.employee_number
where status = 'ACTIVE' and active ='Yes' and okta_department is not null and okta_department <> 'Executive'
),
manager_single_department as (
select full_name, count(*)
from manager_department_all
group by 1
having count(*) = 1
),


manager_department as (
select mda.*
from manager_department_all mda
join manager_single_department msd on mda.full_name = msd.full_name
),


workforce_with_inherited_department as (
select okta_title,
okta_users_id,
okta_hire_date,
okta_lastupdated,
workforce.okta_department okta_department_original,
esd_isactive,
esd_dateofhire,
exitdate,
lst_updt_ts,
workday_employee_number,
-- dwh_workforce_id,
okta_status,
okta_email,
coalesce(workforce.okta_department, manager_department.okta_department) okta_department,
case
when workforce.okta_department is not null then 'employee'
when manager_department.okta_department is not null then 'manager'
end dept_source,
company,
okta_manager,
first_name,
last_name,
display_name
from workforce
left join manager_department on okta_manager = full_name
),


dim_school as (
select distinct esd_school_name,
school_type_abbrev,
case
when school_type_abbrev = 'ES' then 'Elementary School'
when school_type_abbrev = 'MS' then 'Middle School'
when school_type_abbrev = 'HS' then 'High School'
end as school_model
from {{ ref('src_sacs_dim_school') }}
where dwh_school_year_id = 22
),


workforce_with_school_model as (
select distinct
wf.*,
dim_school.school_type_abbrev,
dim_school.school_model
from workforce_with_inherited_department wf
left join dim_school on replace(replace(wf.company, 'SA ', ''), ' - ', '-') = dim_school.esd_school_name
),
workforce_with_user_groups as (
select *,
case
-- SCHOOL-BASED STAFF WITH TITLE- AND DEPARTMENT-BASED CRITERIA
when school_type_abbrev in ('ES', 'MS', 'HS') and okta_department = 'Support' and okta_title ilike 'assessment%' then 'Assessment (' || school_model || ')'
when school_type_abbrev in ('ES', 'MS', 'HS') and okta_department ilike '%school leadership%' and okta_title ilike '%assistant principal%' then 'Assistant Principals (' || school_model || ')'
when school_type_abbrev in ('ES', 'MS', 'HS') and okta_department ilike '%school leadership%' and okta_title ilike '%senior leader%' then 'School Leadership (' || school_model || ')'
when school_type_abbrev in ('ES', 'MS', 'HS') and okta_department = 'Support' and okta_title ilike '%sprint%' then 'Sprint (' || school_model || ')'
when school_type_abbrev in ('ES', 'MS', 'HS') and okta_department = 'Support' and (okta_title ilike '%social emotional%' or okta_title ilike '%psychologist%') then 'Social Emotional & Psychologists (' || school_model || ')'
when school_type_abbrev in ('ES', 'MS', 'HS') and okta_title ilike '%business operations manager%' then 'Business Operations Managers (' || school_model || ')'
when school_type_abbrev in ('HS') and okta_department = 'Support' and okta_title ilike '%college%' then 'College Access & Guidance (' || school_model || ')'


-- SCHOOL-BASED STAFF WITH DEPARTMENT-BASED CRITERIA
when school_type_abbrev in ('ES', 'MS', 'HS') and okta_department = 'Scholar Talent (Family Group)' then 'Arts and Athletics Teachers (' || school_model || ')'
when school_type_abbrev in ('ES', 'MS', 'HS') and okta_department = 'School Operations' then 'School Operations (' || school_model || ')'
-- when school_type_abbrev in ('ES', 'MS', 'HS') and okta_department = 'Teacher' then 'Teachers (' || school_model || ')'


-- EXECUTIVE LEADERSHIP
when display_name in ('Lisa Sun', 'David Ellner', 'Eva Moskowitz', 'LaMae de Jongh') then 'Executive Leadership'


-- EDNA
when okta_title ilike '%data scien%' and okta_department = 'Enterprise Services' then 'EDNA Data Science'
when okta_manager ='david.dupuis' and okta_department = 'Enterprise Services' then 'EDNA Data Science'
when okta_manager in ('salvador.manzur', 'adam.redstone', 'saroj.adhikari', 'ali.jarvandi') then 'EDNA Engineering & Analytics'
when okta_title ilike '%ED&A%' or okta_title ilike 'Enterprise Data & Analytics' then 'EDNA Engineering & Analytics'
-- NETWORK-BASED STAFF WITH TITLE-BASED CRITERIA
-- when okta_title ilike '%business operations manager%' then 'Business Operations Manager (BOM)' -- THIS HAS BEEN MOVED TO THE SCHOOL-BASED SECTION
when okta_title ilike '%family care%' then 'Family Care'
when okta_title ilike '%family experience%' or okta_title ilike '%family engagement%' then 'Family Engagement'
when okta_title ilike '%marketing%' then 'Marketing'
when okta_title ilike '%operations management%' then 'Operations Management'
when okta_title ilike '%regional operations manager%' then 'Regional Operations Manager (ROM)'
when okta_title ilike '%content design%' then 'Content Design'
when okta_title ilike '%learning quality%' and (okta_title ilike '%lead%' or okta_title ilike 'manager') then 'Learning Quality Management'
when okta_title ilike '%learning quality%' then 'Learning Quality'
when okta_title ilike '%school management%' and (okta_title ilike '%head%' or okta_title ilike '%leader%') then 'School Management'
when okta_title ilike '%edge%' then 'Edge Office'
when okta_title ilike '%EI Data%' then 'Education Institute (EI) Leadership'
-- NETWORK-BASED STAFF WITH TITLE- AND DEPARTMENT-BASED CRITERIA
when (okta_title ilike '%chief%' or okta_title ilike '%head%') and okta_department = 'Finance' then 'FP&A Leadership'
when (okta_title ilike '%lead%' or okta_title ilike '%manager%') and okta_department = 'Finance' then 'FP&A Management'
when (okta_title ilike '%chief%' or okta_title ilike '%head%') and okta_department = 'Public Affairs' then 'Public Affairs Leadership'
when (okta_title ilike '%lead%' or okta_title ilike '%manager%') and okta_department = 'Public Affairs' then 'Public Affairs Management'
when (okta_title ilike '%executive%' or okta_title ilike '%head%' or okta_title ilike '%lead%') and okta_department = 'Education Institute' then 'Education Institute (EI) Leadership'
when (okta_title ilike '%director%' or okta_title ilike '%manager%') and okta_department = 'Education Institute' then 'Education Institute (EI) Management'
when (okta_title ilike '%lead-%' or okta_title ilike '%leader-%' or okta_title ilike '%director%' or okta_title ilike '%executive%' or okta_title ilike '%head%') and okta_department = 'Schooling' then 'Schooling Leadership'
when (okta_title ilike '%lead-%' or okta_title ilike '%leader-%' or okta_title ilike '%director%' or okta_title ilike '%executive%' or okta_title ilike '%head%') and lower(okta_manager) = 'lamae.dejongh' then 'Schooling Leadership'
when okta_title ilike '%manager%' and okta_department = 'Schooling' then 'Schooling Management'
when (okta_title ilike '%chief' or okta_title ilike '%lead') and okta_title ilike '%technology%' and okta_department = 'Enterprise Services' then 'Technology Leadership'
when okta_title ilike '%manager%' and okta_title ilike '%technology%' and okta_department = 'Enterprise Services' then 'Technology Management'
when okta_title ilike '%technology%' and okta_department = 'Enterprise Services' then 'Technology Non-Management'
-- NETWORK-BASED STAFF WITH DEPARTMENT-BASED CRITERIA
when okta_department = 'Advancement' then 'Advancement'
when okta_department = 'Advisory' then 'Advisory'
when okta_department = 'Education Institute' then 'Education Institute (EI) Non-Management'
when okta_department = 'Finance' then 'FP&A Non-Management'
when okta_department = 'Human Capital' then 'Human Capital'
when okta_department = 'Public Affairs' then 'Public Affairs Non-Management'
when okta_department = 'Advancement' then 'Advancement'
when okta_department = 'Schooling' then 'Schooling Non-Management'
else NULL
end looker_user_group
from workforce_with_school_model
),
workforce_data AS (
    SELECT
        *,
        'Current'::varchar as user_group_status,
        DENSE_RANK() OVER(PARTITION BY okta_users_id ORDER BY okta_hire_date DESC,okta_lastupdated::date DESC,esd_dateofhire::date DESC) AS rnk          
    FROM workforce_with_user_groups
)

SELECT 
    workday_employee_number,
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
    okta_lastupdated
FROM workforce_data
where rnk = 1

