{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='venue_id'
) }}

SELECT
    venue_id,
    venue_name,
    city,
    pincode
FROM {{ ref('stg_venues') }}