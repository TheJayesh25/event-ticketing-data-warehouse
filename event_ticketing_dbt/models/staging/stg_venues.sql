WITH source_venues AS (
    SELECT
        TRIM(venue_id) AS venue_id,
        TRIM(venue_name) AS venue_name,
        INITCAP(TRIM(city)) AS city,
        regexp_replace(pincode, '[^0-9]', '') AS PINCODE
    FROM {{ source('ticketing', 'raw_venue') }}
)
SELECT * FROM source_venues
