WITH source_customers AS (

    SELECT
        TRIM(customer_id) AS customer_id,
        TRIM(name) AS customer_name,
        CAST(birth_date AS DATE) AS customer_birth_date,
        CAST(mobile_no AS VARCHAR) AS mobile_number,
        {{ clean_email('email') }} AS email_address,
        CAST(updated_at AS DATE) AS row_updated_at

    FROM {{ source('ticketing', 'raw_customer') }}

)

SELECT *
FROM source_customers