{{ config(
    materialized='table'
) }}

WITH customer_snapshot AS (

    SELECT
        customer_id,
        customer_name,
        customer_birth_date,
        mobile_number,
        email_address,
        snapshot_date
    FROM {{ ref('stg_customers') }}
    WHERE snapshot_date = (
        SELECT MIN(snapshot_date)
        FROM {{ ref('stg_customers') }}
    )

)

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

FROM customer_snapshot