WITH stg_customer AS (
    SELECT 
        ROW_NUMBER() OVER(ORDER BY customer_id, row_updated_at) AS customer_sk,
        customer_id,
        customer_name,
        customer_birth_date,
        mobile_number,
        email_address,
        row_updated_at AS valid_from,
        LEAD(row_updated_at) OVER (PARTITION BY customer_id ORDER BY row_updated_at) AS next_updated_at
    FROM {{ ref('stg_customers') }}
)
SELECT 
    customer_sk,
    customer_id,
    customer_name,
    customer_birth_date,
    mobile_number,
    email_address,
    valid_from,
    COALESCE(next_updated_at, CAST('9999-12-31' AS DATE)) AS valid_to,
    CASE
        WHEN next_updated_at IS NULL THEN TRUE
        ELSE FALSE
    END AS is_current
FROM stg_customer