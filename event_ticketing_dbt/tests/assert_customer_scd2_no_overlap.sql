WITH customer_versions AS (

    SELECT
        customer_id,
        valid_from,
        valid_to
    FROM {{ ref('dim_customer') }}

),

overlapping_versions AS (

    SELECT
        a.customer_id,
        a.valid_from AS a_valid_from,
        a.valid_to AS a_valid_to,
        b.valid_from AS b_valid_from,
        b.valid_to AS b_valid_to
    FROM customer_versions a
    INNER JOIN customer_versions b
        ON a.customer_id = b.customer_id
        AND a.valid_from < b.valid_from
        AND a.valid_to > b.valid_from

)

SELECT *
FROM overlapping_versions