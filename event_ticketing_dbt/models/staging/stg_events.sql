WITH source_events AS (
    SELECT
        TRIM(event_id) AS event_id,
        TRIM(name) AS event_name,
        TRIM(LOWER(category)) AS event_category,
        CAST(date AS TIMESTAMP) AS event_datetime,
        TRIM(venue_id) AS venue_id
    FROM {{ source('ticketing', 'raw_event') }}
)

SELECT *
FROM source_events