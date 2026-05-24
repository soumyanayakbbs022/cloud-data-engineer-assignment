-- =========================================================
-- Phase 5: Data Quality Monitoring & Operational Checks
--
-- Objective:
-- Implement production-style quality monitoring queries
-- for Bronze and Silver layers.
--
-- This phase focuses on:
--   - reconciliation
--   - observability
--   - freshness monitoring
--   - SLA analysis
--   - invalid record tracking
--   - operational quality reporting
--
-- These queries simulate enterprise operational dashboards
-- and production monitoring checks.
-- =========================================================

-- =========================================================
-- Query 1: Late-Arriving Data Rate
--
-- Definition:
-- Late-arriving = freshness > 120 minutes
--
-- Purpose:
-- Monitor upstream ingestion delays and SLA adherence.
-- =========================================================

SELECT

    COUNT(*) AS total_rows,

    COUNTIF(is_late = TRUE) AS late_rows,

    ROUND(
        COUNTIF(is_late = TRUE) * 100.0 / COUNT(*),
        2
    ) AS late_percentage

FROM retail.silver_transactions;

-- =========================================================
-- Query 2: Late Data Rate by Store
--
-- Purpose:
-- Identify stores with abnormal ingestion delays.
-- =========================================================

SELECT

    store_id,

    COUNT(*) AS total_rows,

    COUNTIF(is_late = TRUE) AS late_rows,

    ROUND(
        COUNTIF(is_late = TRUE) * 100.0 / COUNT(*),
        2
    ) AS late_percentage

FROM retail.silver_transactions

GROUP BY store_id

ORDER BY late_percentage DESC;

-- =========================================================
-- Query 3: Significantly Late Data Monitoring
--
-- Definition:
-- Significantly late = freshness > 1440 minutes
--
-- Purpose:
-- Detect severe upstream delays and replay scenarios.
-- =========================================================

SELECT

    COUNT(*) AS total_rows,

    COUNTIF(is_significantly_late = TRUE) AS significantly_late_rows,

    ROUND(
        COUNTIF(is_significantly_late = TRUE) * 100.0 / COUNT(*),
        2
    ) AS significantly_late_percentage

FROM retail.silver_transactions;

-- =========================================================
-- Query 4: Invalid Record Counts by Reason
--
-- Purpose:
-- Monitor major data quality failure categories
-- impacting downstream analytics.
--
-- Production Use Cases:
--   - operational alerting
--   - upstream issue diagnosis
--   - data quality dashboards
-- =========================================================

SELECT

    invalid_reason,

    COUNT(*) AS invalid_record_count,

    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM retail.silver_transactions),
        2
    ) AS invalid_percentage

FROM retail.silver_transactions

WHERE is_valid = FALSE

GROUP BY invalid_reason

ORDER BY invalid_record_count DESC;

-- =========================================================
-- Query 5: Bronze vs Silver Reconciliation
--
-- Purpose:
-- Validate transformation consistency between layers.
--
-- Important:
-- Silver row count should be lower due to:
--   - duplicate removal
-- =========================================================

SELECT

    bronze.total_bronze_rows,

    silver.total_silver_rows,

    bronze.total_bronze_rows - silver.total_silver_rows
        AS removed_duplicate_rows

FROM (

    SELECT
        COUNT(*) AS total_bronze_rows
    FROM retail.bronze_transactions

) bronze

CROSS JOIN (

    SELECT
        COUNT(*) AS total_silver_rows
    FROM retail.silver_transactions

) silver;

-- =========================================================
-- Query 6: Batch-Level Bronze to Silver Reconciliation
--
-- Purpose:
-- Monitor transformation impact per ingestion batch.
-- =========================================================

WITH bronze_batch AS (

    SELECT

        source_batch,

        COUNT(*) AS bronze_rows

    FROM retail.bronze_transactions

    GROUP BY source_batch

),

silver_batch AS (

    SELECT

        source_batch,

        COUNT(*) AS silver_rows

    FROM retail.silver_transactions

    GROUP BY source_batch

)

SELECT

    bronze_batch.source_batch,

    bronze_batch.bronze_rows,

    silver_batch.silver_rows,

    bronze_batch.bronze_rows - silver_batch.silver_rows
        AS removed_rows

FROM bronze_batch

LEFT JOIN silver_batch
    ON bronze_batch.source_batch = silver_batch.source_batch

ORDER BY bronze_batch.source_batch;

-- =========================================================
-- Query 7: Freshness Distribution Analysis
--
-- Purpose:
-- Analyze ingestion delay distribution patterns.
-- =========================================================

SELECT

    CASE

        WHEN freshness_minutes <= 30
        THEN '0-30 mins'

        WHEN freshness_minutes <= 120
        THEN '31-120 mins'

        WHEN freshness_minutes <= 1440
        THEN '121 mins - 24 hrs'

        ELSE '>24 hrs'

    END AS freshness_bucket,

    COUNT(*) AS row_count

FROM retail.silver_transactions

GROUP BY freshness_bucket

ORDER BY row_count DESC;

-- =========================================================
-- Query 8: Revenue by Store (Valid Records Only)
--
-- Purpose:
-- Validate business-ready analytics output.
--
-- Important:
-- Only valid Silver records are included.
-- =========================================================

SELECT

    store_id,

    ROUND(SUM(total_amount), 2) AS total_revenue,

    COUNT(*) AS valid_transaction_count

FROM retail.silver_transactions

WHERE is_valid = TRUE

GROUP BY store_id

ORDER BY total_revenue DESC;

-- =========================================================
-- Suggested Production Alert Thresholds
--
-- Late-arriving percentage:
--   Warning  > 5%
--   Critical > 15%
--
-- Significantly late percentage:
--   Warning  > 1%
--   Critical > 5%
--
-- Invalid record percentage:
--   Warning  > 2%
--   Critical > 10%
--
-- Reconciliation mismatch:
--   Any unexpected row-count mismatch should trigger
--   operational investigation.
--
-- These thresholds simulate enterprise operational
-- monitoring and SLA governance practices.
-- =========================================================