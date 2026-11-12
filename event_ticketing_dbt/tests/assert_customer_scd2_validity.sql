SELECT
    customer_sk,
    customer_id,
    valid_from,
    valid_to,
    is_current
FROM {{ ref('dim_customer') }}
WHERE
    valid_to <= valid_from
    OR (
        is_current = TRUE
        AND valid_to <> TO_DATE('9999-12-31')
    )
    OR (
        is_current = FALSE
        AND valid_to = TO_DATE('9999-12-31')
    )