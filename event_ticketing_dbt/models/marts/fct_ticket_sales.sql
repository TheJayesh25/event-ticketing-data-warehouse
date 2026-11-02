{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='ticket_id'
) }}

WITH source_tickets AS (

    SELECT *
    FROM {{ ref('stg_tickets') }}

    {% if is_incremental() %}

    WHERE ingestion_timestamp > (
        SELECT MAX(ingestion_timestamp)
        FROM {{ this }}
    )

    {% endif %}

),

deduplicated_tickets AS (

    SELECT *
    FROM source_tickets

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY ticket_id
        ORDER BY ingestion_timestamp DESC
    ) = 1

),

ticket_sales AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key([
            't.ticket_id'
        ]) }} AS ticket_sale_sk,

        t.ticket_id,
        c.customer_sk,
        e.event_id,
        v.venue_id,
        t.sales_channel,
        t.purchase_datetime,
        t.ticket_price,
        t.convenience_fee,
        t.total_amount,
        t.ingestion_timestamp

    FROM deduplicated_tickets t

    LEFT JOIN {{ ref('dim_customer') }} c
        ON t.customer_id = c.customer_id
        AND c.valid_from <= t.purchase_datetime
        AND t.purchase_datetime < c.valid_to

    LEFT JOIN {{ ref('dim_event') }} e
        ON t.event_id = e.event_id

    LEFT JOIN {{ ref('dim_venue') }} v
        ON e.venue_id = v.venue_id

)

SELECT *
FROM ticket_sales