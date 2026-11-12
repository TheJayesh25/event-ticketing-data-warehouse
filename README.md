# Event Ticketing Data Warehouse

An end-to-end event ticketing data warehouse built with **Amazon S3, Snowflake, and dbt**.

The project takes raw event, venue, customer, and ticket-sales data through ingestion, transformation, dimensional modeling, historical tracking, incremental processing, and data-quality validation to produce an analytics-ready warehouse.

The project is intentionally small enough to understand end-to-end, while incorporating patterns used in production data platforms: **dimensional modeling, SCD Type 2, SCD Type 0, incremental MERGE processing, point-in-time dimension lookups, surrogate keys, source contracts, and automated data-quality tests.**

---

## Architecture

```text
                    Source Parquet Files
                           │
                           ▼
                    ┌─────────────┐
                    │  Amazon S3  │
                    └──────┬──────┘
                           │
                     COPY INTO
                           │
                           ▼
                    ┌─────────────┐
                    │   Snowflake  │
                    │     RAW      │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │ dbt STAGING │
                    │   Cleaning  │
                    │ Standardize │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │ dbt MARTS   │
                    │ Dimensions  │
                    │    + Fact   │
                    └──────┬──────┘
                           │
                           ▼
                    Analytics / BI
```

### Technology

| Layer | Technology | Purpose |
|---|---|---|
| Object storage | Amazon S3 | Source file storage |
| Data warehouse | Snowflake | Raw storage and analytical warehouse |
| Transformation | dbt | SQL transformations, modeling and testing |
| Programming | SQL / Jinja | Transformations and incremental logic |
| Data format | Parquet | Source data delivery format |

---

## Business Context

The warehouse models an event ticketing business where customers purchase individual tickets for scheduled events.

The resulting warehouse is designed to answer questions such as:

- How many tickets were sold for each event?
- How much revenue did each event generate?
- Which venues generated the most ticket sales?
- Which customers made the most purchases?
- How does revenue vary by sales channel?
- How do sales change over time?
- Which event categories perform best?
- What customer information was valid when a historical ticket was purchased?

The final model is centered around the **ticket sale as the business process**.

---

## Data Model

The warehouse follows a dimensional modeling approach.

```text
                    ┌─────────────────┐
                    │  DIM_CUSTOMER   │
                    │      SCD2       │
                    └────────┬────────┘
                             │
                             │ customer_sk
                             │
                             ▼
┌──────────────┐       ┌─────────────────┐       ┌──────────────┐
│  DIM_EVENT   │◄──────│ FCT_TICKET_SALES│──────►│  DIM_VENUE   │
│    SCD0      │       │                 │       │     SCD0     │
└──────────────┘       └─────────────────┘       └──────────────┘
```

### Fact grain

`fct_ticket_sales` has a grain of:

> **One row per individual ticket sold to a customer for an event.**

This grain is established before choosing measures or dimensions and prevents ambiguity when calculating ticket counts, revenue, customer purchases, and event performance.

A ticket count is therefore derived using `COUNT(*)` rather than stored as a redundant measure.

### Dimensions

#### `dim_customer`

SCD Type 2 dimension retaining historical customer versions.

A customer can have multiple records over time:

```text
customer_id | customer_sk | email              | valid_from | valid_to   | is_current
------------|--------------|--------------------|------------|------------|-----------
C001        | ...          | old@email.com      | 2026-02-01 | 2026-08-15 | FALSE
C001        | ...          | new@email.com      | 2026-08-15 | 9999-12-31 | TRUE
```

Ticket sales use a **point-in-time lookup**:

```text
customer_id
AND valid_from <= purchase_datetime
AND purchase_datetime < valid_to
```

This ensures historical purchases are associated with the customer attributes that were valid when the purchase occurred rather than the customer's current state.

The source provides `updated_at` as the customer record's effective update date, so this is used for `valid_from` rather than the snapshot delivery date.

#### `dim_event`

SCD Type 0 dimension containing the current state of events.

`event_id` is the business key and the dimension is incrementally maintained using `MERGE`.

The project assumes that an event's venue assignment is immutable once ticket sales begin. This allows the fact table to retain the event-to-venue relationship without requiring historical versions of the event dimension.

#### `dim_venue`

SCD Type 0 dimension containing the current state of venues.

New venues are inserted and changes to existing venue attributes are updated through incremental `MERGE` processing.

#### `fct_ticket_sales`

The central transaction fact.

It contains:

- ticket identifier
- customer surrogate key
- event identifier
- venue identifier
- sales channel
- purchase timestamp
- ticket price
- convenience fee
- total amount
- ingestion timestamp

`total_amount` is used as the project's revenue measure and is defined as:

```text
ticket_price + convenience_fee
```

The individual components are retained so the calculation remains transparent.

---

## Data Flow

### 1. Source ingestion

Source datasets are delivered as Parquet files and stored in S3.

The current project uses a manual Snowflake ingestion process through an external stage and `COPY INTO`.

This keeps the ingestion process explicit and easy to inspect while leaving the architecture ready for future automation.

### 2. RAW layer

The RAW layer preserves source-oriented structures with minimal transformation.

The four source entities are:

- `RAW_CUSTOMER`
- `RAW_EVENT`
- `RAW_VENUE`
- `RAW_TICKET`

The RAW layer acts as the boundary between source ingestion and transformation.

### 3. STAGING layer

dbt staging models standardize source data without applying significant business logic.

Examples include:

- trimming identifiers and text
- standardizing casing
- parsing dates and timestamps
- cleaning email addresses
- standardizing postal codes
- normalizing sales-channel values
- retaining ingestion metadata

The staging layer provides a consistent interface for downstream models.

### 4. MARTS layer

The marts layer applies business logic and dimensional modeling.

It contains:

```text
dim_customer
dim_event
dim_venue
fct_ticket_sales
```

---

## Incremental Processing

Incremental processing is used where the business process benefits from it rather than applying it indiscriminately.

### Event and venue dimensions

Both dimensions use:

```text
incremental + MERGE
```

with their respective business keys:

```text
dim_event  → event_id
dim_venue  → venue_id
```

This supports:

- inserting new records
- updating existing records
- retaining records that are absent from the latest delivery

The absence of a record from a source delivery is therefore **not interpreted as a deletion**.

### Ticket fact

Ticket deliveries follow an incremental delivery contract.

The initial delivery contains historical ticket sales. Subsequent deliveries may contain:

- new ticket IDs
- corrections to previously delivered ticket IDs

The RAW ticket layer retains delivery records, while the fact model uses `ingestion_timestamp` as its incremental watermark.

The fact is then merged using:

```text
ticket_id
```

as the business key.

This is important because `purchase_datetime` cannot be used as the watermark: a correction can arrive after the original purchase date.

### Why `ingestion_timestamp` is retained

The ingestion timestamp serves two purposes:

1. It identifies when a record entered the warehouse pipeline.
2. It provides a reliable watermark for incremental processing.

This separates **business event time** from **pipeline delivery time**.

---

## Customer Snapshot and SCD Type 2 Strategy

Customer data is delivered as periodic snapshots rather than a CDC stream.

Each snapshot represents the authoritative customer state for that delivery.

The model therefore distinguishes between:

- `snapshot_date` — when the snapshot was delivered
- `row_updated_at` — when the customer record was updated

These have different meanings and are deliberately not interchangeable.

`row_updated_at` determines the SCD2 validity period:

```text
valid_from = row_updated_at
valid_to   = next version's row_updated_at
```

The current version uses:

```text
9999-12-31
```

as its open-ended `valid_to`.

### Source limitation

Because the source is snapshot-based rather than CDC-based, changes that occur between two snapshots cannot be reconstructed unless they are represented in the delivered data.

For example, if a customer changes their email twice between two snapshots and only the final state is delivered, the intermediate state cannot be recovered.

That limitation is explicitly accepted as part of the source contract rather than being hidden by the warehouse model.

---

## Data Quality

Data quality is implemented at multiple levels.

### Structural tests

`models.yml` defines model-level tests such as:

- `not_null`
- `unique`
- relationship integrity

Examples:

```text
dim_customer.customer_sk
dim_event.event_id
dim_venue.venue_id
fct_ticket_sales.ticket_id
fct_ticket_sales.customer_sk
fct_ticket_sales.event_id
fct_ticket_sales.venue_id
```

### Source tests

`sources.yml` validates assumptions about the RAW layer, including required source fields and source-level uniqueness where appropriate.

Importantly, uniqueness is not applied where the source contract allows multiple records.

For example:

```text
RAW_CUSTOMER.customer_id
```

is not globally unique because multiple customer snapshots are retained.

Likewise:

```text
RAW_TICKET.ticket_id
```

is not required to be unique because a corrected ticket can appear in a later delivery.

### Business-rule tests

Custom singular dbt tests validate business logic that generic schema tests cannot express.

Current assertions include:

#### Revenue consistency

```text
total_amount = ticket_price + convenience_fee
```

#### SCD2 validity

Customer versions must have valid temporal boundaries and correctly identify the current version.

#### SCD2 overlap

Two versions of the same customer must never have overlapping validity periods.

Together, these tests validate both **structural integrity** and **business correctness**.

---

## Key Design Decisions

### 1. Ticket sales are the fact grain

The fact is modeled at individual-ticket grain rather than event-day or customer-day grain.

This preserves maximum analytical flexibility and allows higher-level metrics to be derived through aggregation.

### 2. Customer is SCD Type 2

Customer attributes can change and historical reporting requires the customer's state at purchase time.

Therefore, customer history is preserved rather than overwritten.

### 3. Event and venue are SCD Type 0

The project does not require historical versions of these dimensions.

The current state is sufficient under the defined business rules.

### 4. Event venue is treated as immutable after sales begin

This business rule makes the event-to-venue relationship stable for historical ticket sales.

It avoids introducing unnecessary event-versioning complexity while keeping the fact-to-venue relationship explicit.

### 5. Surrogate keys are used for customer history

`customer_sk` identifies a specific version of a customer.

This separates the stable business identifier:

```text
customer_id
```

from the historical warehouse identity:

```text
customer_sk
```

### 6. Point-in-time joins are used for customer attribution

The fact does not simply join to the current customer record.

Instead, the purchase timestamp determines which SCD2 version is applicable.

This is essential for historically correct reporting.

### 7. Incremental processing uses delivery time, not business event time

`ingestion_timestamp` is used for ticket incremental processing.

This allows late corrections to old purchases to be processed without relying on the original purchase timestamp.

### 8. Missing source records are not treated as deletions

The incremental MERGE logic does not delete target records simply because they are absent from a later delivery.

This reflects the source contract: deliveries represent received records, not authoritative deletion snapshots.

### 9. No separate ticket dimension

A ticket is the transaction itself, so creating a `dim_ticket` would add little analytical value.

The ticket identifier is retained as a business key in the fact.

### 10. No date dimension

A dedicated date dimension was intentionally omitted because the project is small and the current analytical requirements do not require fiscal calendars, holiday attributes, relative-date logic, or other calendar metadata.

The purchase timestamp remains directly available in the fact.

---

## Project Structure

```text
event-ticketing-data-warehouse/
│
├── models/
│   ├── staging/
│   │   ├── stg_customers.sql
│   │   ├── stg_events.sql
│   │   ├── stg_tickets.sql
│   │   └── stg_venues.sql
│   │
│   ├── marts/
│   │   ├── dim_customer.sql
│   │   ├── dim_event.sql
│   │   ├── dim_venue.sql
│   │   └── fct_ticket_sales.sql
│   │
│   ├── models.yml
│   └── sources.yml
│
├── tests/
│   ├── assert_customer_scd2_no_overlap.sql
│   ├── assert_customer_scd2_validity.sql
│   └── assert_total_amount.sql
│
├── macros/
│   ├── clean_email.sql
│   └── generate_schema_name.sql
│
├── dbt_project.yml
├── packages.yml
└── README.md
```

---

## dbt Project Configuration

The project uses separate schemas for transformation layers:

```text
RAW
STAGING
MARTS
```

Staging models are materialized as views, while marts use table or incremental materializations depending on the model's processing requirements.

The project also uses `dbt_utils` for deterministic surrogate-key generation.

---

## Testing and Validation Strategy

The project validates the warehouse at several levels:

```text
Source contracts
      │
      ▼
Staging transformations
      │
      ▼
Dimension integrity
      │
      ▼
Fact relationships
      │
      ▼
Business-rule assertions
```

Examples of validation include:

- source required fields are populated
- business keys are unique where the source contract requires uniqueness
- dimension surrogate keys are unique
- fact records resolve to valid dimensions
- ticket IDs are unique in the final fact
- revenue components reconcile
- SCD2 validity ranges are consistent
- customer versions do not overlap

This separates **data quality validation** from transformation logic rather than relying solely on successful model execution as evidence of correctness.

---

## Current Ingestion Workflow

The current ingestion process is intentionally manual:

```text
Parquet
   ↓
S3
   ↓
Snowflake External Stage
   ↓
COPY INTO RAW
   ↓
dbt
   ↓
STAGING
   ↓
MARTS
```

The ingestion process is kept separate from dbt transformation logic.

This allows the project to demonstrate the warehouse and transformation architecture without pretending that ingestion orchestration has already been productionized.

---

## Future Improvements

The current implementation deliberately focuses on the warehouse and transformation layer.

Potential production-oriented extensions include:

- **Snowpipe** for automated S3-to-Snowflake ingestion
- **Airflow or another orchestrator** for pipeline scheduling and dependency management
- CDC/event-based customer ingestion for exact change history
- automated ingestion metadata and batch identifiers
- explicit deletion handling if the source introduces deletion semantics
- a dedicated date dimension if analytical requirements expand
- CI/CD execution of dbt tests
- environment-specific dbt configurations
- monitoring and alerting around pipeline failures and data-quality violations
- BI dashboards consuming the MARTS layer

These are extensions to the current design rather than components represented as already implemented.

---

## What This Project Demonstrates

This project focuses on demonstrating the reasoning required to build a reliable analytical data model rather than simply moving data between systems.

Key areas covered include:

- dimensional modeling
- fact grain definition
- SCD Type 0 and Type 2 modeling
- surrogate-key design
- point-in-time dimension lookups
- incremental MERGE processing
- late-arriving corrections
- ingestion versus business-event timestamps
- source contracts and snapshot semantics
- data-quality testing
- referential integrity
- business-rule validation
- separation of RAW, STAGING, and MARTS layers
- explicit handling of source-system limitations
- production-oriented design trade-offs

The design favors **clear business semantics, traceable transformations, and appropriate complexity** rather than introducing patterns that the source data or project requirements do not justify.