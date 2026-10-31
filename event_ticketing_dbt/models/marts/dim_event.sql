{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='event_id'
) }}

SELECT
    event_id,
    event_name,
    event_category,
    event_datetime,
    venue_id
FROM {{ ref('stg_events') }}