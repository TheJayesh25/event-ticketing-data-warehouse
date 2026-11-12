SELECT
    ticket_id,
    ticket_price,
    convenience_fee,
    total_amount
FROM {{ ref('fct_ticket_sales') }}
WHERE total_amount <> ticket_price + convenience_fee