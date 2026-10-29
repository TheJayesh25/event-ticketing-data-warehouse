{% macro clean_email(column_name) %}
    CASE
        WHEN REGEXP_LIKE(
            {{ column_name }},
            '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
        )
        THEN TRIM(LOWER({{ column_name }}))
        ELSE NULL
    END
{% endmacro %}