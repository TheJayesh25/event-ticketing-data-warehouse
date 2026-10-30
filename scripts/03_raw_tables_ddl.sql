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
  ticket_id	VARCHAR(50),
  customer_id VARCHAR(50),
  event_id VARCHAR(50),
  sales_channel VARCHAR(50),
  purchase_timestamp DATETIME,
  ticket_price NUMBER,	
  convenience_fee NUMBER,
  total_amount NUMBER
);

-- raw_venue
CREATE OR REPLACE TABLE raw_venue (
    venue_id VARCHAR(50),
    venue_name	VARCHAR(150),
    city VARCHAR(100),
    pincode VARCHAR(50)

);


