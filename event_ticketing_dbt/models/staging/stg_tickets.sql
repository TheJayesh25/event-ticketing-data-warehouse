WITH source_tickets AS (
    SELECT
        TRIM(ticket_id) AS ticket_id,
        TRIM(customer_id) AS customer_id,
        TRIM(event_id) AS event_id,
        LOWER(TRIM(sales_channel)) AS sales_channel,
        CAST(purchase_timestamp AS TIMESTAMP) AS purchase_datetime,
        ticket_price,
        convenience_fee,
        total_amount
    FROM {{ source('ticketing', 'raw_ticket') }}
)
SELECT * FROM source_tickets

					
