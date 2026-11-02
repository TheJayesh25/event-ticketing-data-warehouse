-- raw_customers
CREATE TABLE TICKETING.RAW.RAW_CUSTOMER (
    customer_id     VARCHAR,
    name            VARCHAR,
    birth_date      VARCHAR,
    mobile_no       VARCHAR,
    email           VARCHAR,
    updated_at      VARCHAR,
    snapshot_date   DATE
);

-- raw_event
CREATE OR REPLACE TABLE raw_event (
    event_id VARCHAR(50),
    name VARCHAR(150),
    category VARCHAR(50),
    date DATETIME,
    venue_id VARCHAR(50),
    venue VARCHAR(50)
);

-- raw_ticket
CREATE OR REPLACE TABLE raw_ticket (
    ticket_id VARCHAR,
    customer_id VARCHAR,
    event_id VARCHAR,
    sales_channel VARCHAR,
    purchase_timestamp TIMESTAMP_NTZ,
    ticket_price NUMBER(10,2),
    convenience_fee NUMBER(10,2),
    total_amount NUMBER(10,2),
    ingestion_timestamp TIMESTAMP_NTZ
);

-- raw_venue
CREATE OR REPLACE TABLE raw_venue (
    venue_id VARCHAR(50),
    venue_name	VARCHAR(150),
    city VARCHAR(100),
    pincode VARCHAR(50)

);


