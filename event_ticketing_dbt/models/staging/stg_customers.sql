WITH source_customers AS (
    SELECT
        TRIM(customer_id) AS customer_id,
        TRIM(name) AS customer_name,
        TO_DATE(birth_date, 'DD-MM-YYYY') AS customer_birth_date,
        CAST(mobile_no AS VARCHAR) AS mobile_number,
        {{ clean_email('email') }} AS email_address,
        TO_DATE(updated_at, 'DD-MM-YYYY') AS row_updated_at,
        CAST(snapshot_date AS DATE) AS snapshot_date
    FROM {{ source('ticketing', 'raw_customer') }}
)

SELECT *
FROM source_customers