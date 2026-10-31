{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='customer_sk'
) }}

WITH latest_snapshot AS (

    SELECT *
    FROM {{ ref('stg_customers') }}
    WHERE snapshot_date = (
        SELECT MAX(snapshot_date)
        FROM {{ ref('stg_customers') }}
    )

)

{% if is_incremental() %}

, current_customers AS (

    SELECT *
    FROM {{ this }}
    WHERE is_current = TRUE

),

changed_customers AS (

    SELECT
        s.customer_id,
        s.customer_name,
        s.customer_birth_date,
        s.mobile_number,
        s.email_address,
        s.snapshot_date
    FROM latest_snapshot s
    INNER JOIN current_customers d
        ON s.customer_id = d.customer_id
    WHERE
        COALESCE(s.customer_name, '') != COALESCE(d.customer_name, '')
        OR COALESCE(s.customer_birth_date, '1900-01-01')
            != COALESCE(d.customer_birth_date, '1900-01-01')
        OR COALESCE(s.mobile_number, '') != COALESCE(d.mobile_number, '')
        OR COALESCE(s.email_address, '') != COALESCE(d.email_address, '')

),

new_customers AS (

    SELECT
        s.customer_id,
        s.customer_name,
        s.customer_birth_date,
        s.mobile_number,
        s.email_address,
        s.snapshot_date
    FROM latest_snapshot s
    LEFT JOIN current_customers d
        ON s.customer_id = d.customer_id
    WHERE d.customer_id IS NULL

),

expired_versions AS (

    SELECT
        d.customer_sk,
        d.customer_id,
        d.customer_name,
        d.customer_birth_date,
        d.mobile_number,
        d.email_address,
        d.valid_from,
        c.snapshot_date AS valid_to,
        FALSE AS is_current
    FROM current_customers d
    INNER JOIN changed_customers c
        ON d.customer_id = c.customer_id

),

new_versions AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'customer_id',
            'snapshot_date'
        ]) }} AS customer_sk,
        customer_id,
        customer_name,
        customer_birth_date,
        mobile_number,
        email_address,
        snapshot_date AS valid_from,
        TO_DATE('9999-12-31') AS valid_to,
        TRUE AS is_current
    FROM changed_customers

),

new_customer_versions AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'customer_id',
            'snapshot_date'
        ]) }} AS customer_sk,
        customer_id,
        customer_name,
        customer_birth_date,
        mobile_number,
        email_address,
        snapshot_date AS valid_from,
        TO_DATE('9999-12-31') AS valid_to,
        TRUE AS is_current
    FROM new_customers

)

SELECT * FROM expired_versions

UNION ALL

SELECT * FROM new_versions

UNION ALL

SELECT * FROM new_customer_versions

{% else %}

SELECT
    {{ dbt_utils.generate_surrogate_key([
        'customer_id',
        'snapshot_date'
    ]) }} AS customer_sk,
    customer_id,
    customer_name,
    customer_birth_date,
    mobile_number,
    email_address,
    snapshot_date AS valid_from,
    TO_DATE('9999-12-31') AS valid_to,
    TRUE AS is_current
FROM latest_snapshot

{% endif %}