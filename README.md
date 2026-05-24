# Cloud Data Engineer (GCP) Take-Home Assignment
## Bronze → Silver Retail Transaction Pipeline

---

# 1. Project Overview

This project implements a production-style Bronze → Silver retail transaction pipeline using:

- Python 3.8+
- Google BigQuery
- Google Cloud Platform (GCP)
- SQL
- Optional Google Cloud Storage (GCS)

The solution simulates a realistic retail POS ingestion environment with:

- dirty data
- duplicate transactions
- late-arriving records
- replay-aware ingestion behavior
- operational data quality monitoring

The pipeline follows medallion architecture principles:

```text
Raw CSV Batch Files
        ↓
Bronze Layer (Immutable Raw Storage)
        ↓
Silver Layer (Validated Analytics-Ready Data)
        ↓
Operational Quality Monitoring
```

---

# 2. Assignment Objectives

The project was designed to:

- preserve raw source data exactly as received
- identify and profile data quality issues
- handle replayed and duplicate transactions
- process late-arriving data
- safely transform dirty records
- create analytics-ready Silver tables
- implement production-style quality monitoring
- demonstrate operational observability and reconciliation thinking

---

# 3. Technologies Used

| Technology | Purpose |
|---|---|
| Python | Data generation |
| Pandas | CSV generation and manipulation |
| Google BigQuery | Data warehouse and SQL processing |
| SQL | Bronze/Silver transformations and quality monitoring |
| Git & GitHub | Version control |
| PowerShell | Local execution |

---

# 4. Project Structure

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
├── .gitignore
└── venv/
```

---

# 5. GCP & BigQuery Setup

## 5.1 GCP Project

Created dedicated GCP project:

```text
cloud-data-engineer-assignment
```

## 5.2 BigQuery Dataset

Created dataset:

```text
retail
```

Tables created:

```text
retail.bronze_transactions
retail.silver_transactions
```

---

# 6. Phase 1 — Data Generation

## Objective

Generate realistic retail POS transaction batches with controlled data quality issues.

## Output Files

```text
data/batches/
├── batch_01.csv
├── batch_02.csv
└── batch_03.csv
```

## Total Dataset Volume

| Batch | Rows |
|---|---:|
| batch_01.csv | 32,925 |
| batch_02.csv | 33,533 |
| batch_03.csv | 33,542 |
| Total | 100,000 |

## Simulated Data Issues

Exactly 5% erroneous rows were injected.

| Error Type | Description |
|---|---|
| Duplicate transaction IDs | Replay-aware duplicate ingestion |
| Missing product_id | Incomplete dimensional data |
| Invalid quantity | 0, negative, malformed values |
| Invalid unit_price | negative or malformed values |
| Late-arriving records | freshness > 120 mins |
| Significantly late records | freshness > 24 hours |
| Out-of-order events | event time ordering mismatch |

## Key Engineering Concepts

- event time vs processing time modeling
- deterministic error injection
- replay-aware ingestion simulation
- immutable raw-data philosophy
- late-data simulation
- production-style batch generation

---

# 7. Phase 2 — Bronze Layer

## Objective

Implement immutable raw ingestion layer.

## Bronze Table

```sql
CREATE TABLE IF NOT EXISTS retail.bronze_transactions (
    transaction_id STRING,
    store_id STRING,
    product_id STRING,
    quantity STRING,
    unit_price STRING,
    transaction_time TIMESTAMP,
    ingestion_time TIMESTAMP,
    source_batch STRING
)
PARTITION BY DATE(ingestion_time);
```

## Bronze Design Principles

| Principle | Implementation |
|---|---|
| Preserve raw truth | no cleansing/filtering |
| Replayability | append-only ingestion |
| Dirty-data preservation | quantity/unit_price stored as STRING |
| Auditability | source_batch metadata |
| Cost optimization | ingestion-time partitioning |

## Important Implementation Details

- append-only loading used
- dirty values intentionally preserved
- header parsing issue resolved using:
  - skip header rows = 1

---

# 8. Phase 3 — Data Issues Identification

## Objective

Profile Bronze-layer data quality issues before Silver transformations.

## SQL File

```text
sql/03_issues_identification.sql
```

## Implemented Quality Checks

| Quality Check | Purpose |
|---|---|
| Duplicate detection | replay analysis |
| Missing field analysis | completeness monitoring |
| Invalid numeric validation | dirty-data profiling |
| Late-arriving analysis | freshness SLA monitoring |
| Significantly late analysis | outage/replay detection |
| Batch-level summaries | operational observability |

## Important SQL Concepts Used

- COUNTIF()
- SAFE_CAST()
- TIMESTAMP_DIFF()
- STRING_AGG()
- CTEs
- GROUP BY
- HAVING

---

# 9. Phase 4 — Silver Layer

## Objective

Transform Bronze raw data into analytics-ready Silver layer.

## Silver Table

```text
retail.silver_transactions
```

## Deduplication Strategy

Implemented using:

```sql
ROW_NUMBER() OVER (
    PARTITION BY transaction_id
    ORDER BY ingestion_time DESC, source_batch DESC
)
```

Purpose:

- retain latest transaction version
- support replay-aware ingestion
- remove duplicate revenue impact

## SAFE_CAST Transformation

Bronze stored:

```text
quantity STRING
unit_price STRING
```

Silver transformed them into:

```text
quantity INT64
unit_price FLOAT64
```

using:

```sql
SAFE_CAST()
```

Benefits:

- resilient dirty-data handling
- graceful pipeline execution
- operational robustness

## Validation Logic

Implemented validation rules for:

| Field | Validation Rule |
|---|---|
| transaction_id | not NULL / not empty |
| product_id | not NULL / not empty |
| quantity | > 0 |
| unit_price | > 0 |
| transaction_time | not NULL |

Generated:

- is_valid
- invalid_reason

## Freshness Enrichment

Generated:

- freshness_minutes
- is_late
- is_significantly_late

using:

```sql
TIMESTAMP_DIFF()
```

## Additional Enrichment

Generated:

- total_amount
- silver_processed_at

## Partitioning & Clustering

```sql
PARTITION BY DATE(transaction_time)
CLUSTER BY store_id, is_valid
```

Benefits:

- partition pruning
- lower scan cost
- optimized analytics filtering

---

# 10. Phase 5 — Data Quality Monitoring

## Objective

Implement production-style operational quality monitoring queries.

## SQL File

```text
sql/05_data_quality.sql
```

## Implemented Monitoring Queries

| Query | Purpose |
|---|---|
| Late-arriving data rate | SLA monitoring |
| Store-level late analysis | operational diagnostics |
| Significantly late monitoring | outage detection |
| Invalid record monitoring | quality observability |
| Bronze vs Silver reconciliation | pipeline validation |
| Batch-level reconciliation | ingestion diagnostics |
| Freshness distribution | SLA trend analysis |
| Revenue validation | business-readiness validation |

## Operational Alerting Concepts

Suggested thresholds:

| Metric | Warning | Critical |
|---|---|---|
| Late-arriving percentage | >5% | >15% |
| Significantly late percentage | >1% | >5% |
| Invalid record percentage | >2% | >10% |

---

# 11. How to Run the Project

## Step 1 — Clone Repository

```powershell
git clone <your-github-repo-url>
cd cloud-data-engineer-assignment
```

## Step 2 — Create Virtual Environment

```powershell
python -m venv venv
```

## Step 3 — Activate Virtual Environment

```powershell
.\venv\Scripts\Activate
```

## Step 4 — Install Dependencies

```powershell
pip install pandas google-cloud-bigquery
```

## Step 5 — Generate Data

```powershell
python generate_data.py
```

Generated files:

```text
data/batches/
```

## Step 6 — Create Bronze Table

Run:

```text
sql/02_bronze_load.sql
```

inside BigQuery.

## Step 7 — Load CSV Batches into Bronze

Load:

- batch_01.csv
- batch_02.csv
- batch_03.csv

into:

```text
retail.bronze_transactions
```

Configuration:

- append-only loading
- skip header rows = 1

## Step 8 — Run Data Profiling Queries

Run:

```text
sql/03_issues_identification.sql
```

## Step 9 — Create Silver Table

Run:

```text
sql/04_silver_transform.sql
```

## Step 10 — Execute Data Quality Monitoring

Run:

```text
sql/05_data_quality.sql
```

---

# 12. Assumptions

The following assumptions were made:

- duplicate transactions simulate replay/retry behavior
- latest ingestion version should be retained
- Bronze must preserve dirty values exactly
- invalid Silver rows should be retained with flags
- event time and ingestion time are intentionally different
- freshness calculations are based on ingestion delay

---

# 13. Limitations

Current implementation limitations:

- no orchestration framework (Airflow/Dataform/dbt)
- no automated scheduling
- no streaming ingestion
- no automated alerting integration
- no unit testing framework
- no CI/CD pipeline
- no GCS integration layer

---

# 14. Future Improvements

Potential production enhancements:

- implement orchestration using Airflow
- integrate GCS landing zone
- add dbt transformation framework
- implement CI/CD pipelines
- add automated alerting
- add schema evolution handling
- add unit and integration testing
- implement data contracts
- integrate monitoring dashboards

---

# 15. Key Production Engineering Concepts Demonstrated

This assignment demonstrates:

- medallion architecture understanding
- immutable Bronze ingestion design
- replay-aware deduplication
- dirty-data preservation philosophy
- late-arriving data handling
- event-time vs processing-time reasoning
- operational observability
- reconciliation thinking
- BigQuery optimization awareness
- maintainable SQL engineering
- analytics-ready modeling
- enterprise-style quality monitoring

---

# 16. Final Architecture

```text
CSV Batch Files
        ↓
retail.bronze_transactions
        ↓
Data Profiling Queries
        ↓
retail.silver_transactions
        ↓
Operational Quality Monitoring
        ↓
Analytics & Reporting
```

---

# 17. Final Outcome

The completed solution successfully implements:

✅ realistic POS transaction simulation
✅ Bronze raw ingestion layer
✅ dirty-data preservation
✅ replay-aware duplicate handling
✅ Silver transformation layer
✅ validation-driven cleansing
✅ late-arriving data monitoring
✅ analytics-ready transaction modeling
✅ reconciliation framework
✅ operational quality monitoring
✅ BigQuery optimization strategy
✅ production-style engineering practices

The final implementation resembles a simplified enterprise retail lakehouse pipeline built on GCP and BigQuery.

