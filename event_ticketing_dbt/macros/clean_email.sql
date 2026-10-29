{% macro clean_email(column_name) %}
    case 
        -- dbt compiles the correct regex function based on your target profile
        when {{ dbt.regexp_like(column_name, "'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'") }}
        then trim(lower({{ column_name }}))
        else null
    end
{% endmacro %}
