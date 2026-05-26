# Cloud Data Engineer (GCP) Take-Home Assignment
## Bronze → Silver Retail Transaction Pipeline

Production-style retail transaction pipeline implemented on GCP BigQuery using a Bronze → Silver medallion architecture.

The solution simulates realistic POS ingestion challenges including replayed transactions, dirty data, late-arriving records, and out-of-order events while focusing on immutable ingestion, replay-aware transformation logic, and operational observability.

---

## Architecture

```text
CSV Batch Files
    ↓
retail.bronze_transactions
    ↓
Data Profiling & Quality Analysis
    ↓
retail.silver_transactions
    ↓
Observability & Reconciliation Layer
    ↓
Analytics & Reporting
```

---

## Key Engineering Concepts

- Medallion architecture (Bronze → Silver)
- Immutable raw ingestion design
- Replay-aware deduplication
- Event-time vs processing-time modeling
- Late-arriving data handling
- Dirty-data preservation philosophy
- Validation-driven Silver transformation
- Operational observability & reconciliation
- BigQuery partitioning and clustering
- Production-style data quality monitoring

---

## Project Structure

```text
cloud-data-engineer-assignment/
│
├── data/
│   └── batches/
│       ├── batch_01.csv
│       ├── batch_02.csv
│       └── batch_03.csv
│
├── sql/
│   ├── 02_bronze_load.sql
│   ├── 03_issues_identification.sql
│   ├── 04_silver_transform.sql
│   └── 05_data_quality.sql
│
├── generate_data.py
├── README.md
└── .gitignore
```

---

## Dataset Characteristics

| Batch | Rows |
|---|---:|
| batch_01.csv | 32,925 |
| batch_02.csv | 33,534 |
| batch_03.csv | 33,541 |
| Total | 100,000 |

Injected ingestion edge cases:

- duplicate transaction IDs replayed across ingestion batches
- missing `product_id` values
- invalid `quantity` values
- invalid `unit_price` values
- late-arriving records (>120 mins)
- significantly late records (>24 hrs)
- out-of-order transaction events

---

## Bronze Layer

**Table:** `retail.bronze_transactions`

The Bronze layer preserves source records exactly as received using append-only ingestion semantics.

Key characteristics:

- immutable raw storage
- dirty-value preservation
- replay-aware ingestion history
- ingestion-time partitioning
- `source_batch` lineage tracking

Schema intentionally stores `quantity` and `unit_price` as `STRING` to preserve malformed upstream values without ingestion failure.

Bronze ingestion is partitioned by `DATE(ingestion_time)` to optimize scan cost and partition pruning.

**Implementation:** `sql/02_bronze_load.sql`

---

## Data Profiling & Quality Analysis

Bronze-layer profiling queries analyze:

- replayed transactions
- completeness issues
- invalid numeric values
- late-arriving records
- significantly late records
- batch-level reconciliation metrics


**Implementation:** `sql/03_issues_identification.sql`

---

## Silver Layer

**Table:** `retail.silver_transactions`

Silver transformations apply replay-aware deduplication, `SAFE_CAST()`-based normalization, validation-driven quality classification, and freshness enrichment to produce analytics-ready transaction records.

Deduplication logic:

```sql
ROW_NUMBER() OVER (
    PARTITION BY transaction_id
    ORDER BY ingestion_time DESC, source_batch DESC
)
```

Generated enrichments include transaction-level revenue calculation, freshness metrics, late-arrival indicators, validation flags, invalid-reason classification, and transformation audit timestamps.

Partitioned by `DATE(transaction_time)` and clustered by `store_id, is_valid`.

**Implementation:** `sql/04_silver_transform.sql`

---

## Data Quality & Observability

Operational monitoring queries provide:

- late-arriving data rate analysis
- significantly late data monitoring
- invalid record classification
- Bronze vs Silver reconciliation
- batch-level reconciliation
- freshness distribution analysis
- business-level revenue validation

Suggested data quality thresholds:

```sql
-- Late data rate:
--   < 10% is considered acceptable
--
-- Invalid record rate:
--   < 5% is considered acceptable
--
-- Duplicate records in Silver:
--   Target = 0 duplicate transaction_id values
```

**Implementation:** `sql/05_data_quality.sql`

---

## Operational Focus

The implementation prioritizes replayability, auditability, and observability over aggressive cleansing. Invalid records are retained with classification flags, deduplication is deferred to Silver using latest-ingestion semantics, and freshness metrics are modeled explicitly to support SLA monitoring and reconciliation workflows.

---

## Design Decisions

- Bronze preserves source data in its original form
- Deduplication is deferred to Silver using latest-ingestion semantics
- Event time and ingestion time are modeled separately for freshness analysis
- Invalid Silver records are retained instead of dropped
- Partitioning and clustering are optimized for analytical and operational query patterns

---

## GCP & BigQuery Setup

**Dataset:** `retail`

**Tables:**
- `retail.bronze_transactions`
- `retail.silver_transactions`

Required permissions:

- BigQuery Data Editor
- BigQuery Job User

The implementation assumes authenticated access to a GCP project with permission to create datasets, tables, and execute BigQuery jobs.

---

## Execution

1. Run `generate_data.py` to generate batch CSVs
2. Load CSV batches into `retail.bronze_transactions` using append-only ingestion
3. Execute SQL scripts in order:

```text
sql/02_bronze_load.sql
sql/03_issues_identification.sql
sql/04_silver_transform.sql
sql/05_data_quality.sql
```

Bronze ingestion configuration:

- source format: CSV
- skip header rows = 1
- append-only loading

---

## Assumptions & Limitations

**Assumptions**
- latest ingestion version is retained
- Bronze preserves source data in “as-is” form
- late-arriving threshold defined as >120 minutes
- duplicate metrics include both original and replayed records
- invalid Silver records are retained with quality flags to support auditability and observability


**Current limitations**
- no orchestration or CI/CD
- no streaming ingestion
- no automated testing or alerting

---

## Future Enhancements

- Airflow orchestration
- dbt-based transformations
- incremental Silver processing
- CI/CD and automated monitoring

---

## Validation Results

Observed results from the executed pipeline:

| Metric | Result |
|---|---:|
| Total Bronze rows | 100,000 |
| Duplicate transaction rows | 2,432 |
| Invalid quantity rows | 1,272 |
| Invalid unit_price rows | 1,209 |
| Missing product_id rows | 1,260 |
| Late-arriving rows (batch_02) | 321 |
| Late-arriving rows (batch_03) | 492 |
| Significantly late rows (batch_03) | 184 |

Silver-layer validation confirmed:

- replay-aware deduplication applied successfully
- invalid records classified using `invalid_reason`
- freshness metrics generated correctly
- Bronze → Silver reconciliation logic executed successfully

---

## Final Outcome

The implemented solution demonstrates:

- production-style medallion architecture
- immutable Bronze ingestion
- replay-aware deduplication
- late-arriving data handling
- validation-driven Silver transformation
- operational observability
- reconciliation-first engineering mindset
- BigQuery optimization strategy
- analytics-ready transaction modeling
