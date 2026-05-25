-- =====================================================
-- Phase 3: Data Issues Identification
-- =====================================================
-- Objective:
-- Analyze Bronze layer data quality issues before
-- building the Silver transformation layer.
--
-- This script identifies:
-- 1. Duplicate transactions
-- 2. Missing fields
-- 3. Invalid numeric values
-- 4. Late-arriving data
-- 5. Significantly late data
-- 6. Cross-batch quality metrics
--
-- Production Concepts Demonstrated:
-- - Data observability
-- - Replay-aware ingestion analysis
-- - Event time vs processing time handling
-- - Operational SLA monitoring
-- - Reconciliation thinking
-- - Dirty-data profiling
-- =====================================================


-- =====================================================
-- 1. Duplicate Transaction Analysis
-- =====================================================
-- Identifies replayed or duplicated transactions
-- across ingestion batches.
--
-- Operational Impact:
-- - Inflated revenue calculations
-- - Duplicate inventory movement
-- - Incorrect business reporting
-- =====================================================

SELECT
    transaction_id,
    COUNT(*) AS duplicate_count,
    STRING_AGG(DISTINCT source_batch, ', ') AS batches_present

FROM retail.bronze_transactions

GROUP BY transaction_id

HAVING COUNT(*) > 1

ORDER BY duplicate_count DESC;

-- =====================================================
-- 2. Missing Field Analysis
-- =====================================================
-- Measures completeness of critical business fields.
--
-- Both NULL values and empty strings are validated
-- because enterprise source systems frequently contain both.
--
-- Operational Impact:
-- - Broken dimensional joins
-- - Incomplete reporting
-- - Reduced analytics reliability
-- =====================================================

SELECT
    COUNT(*) AS total_rows,

    COUNTIF(
        transaction_id IS NULL
        OR TRIM(transaction_id) = ''
    ) AS missing_transaction_id_count,

    ROUND(
        COUNTIF(
            transaction_id IS NULL
            OR TRIM(transaction_id) = ''
        ) * 100.0 / COUNT(*),
        2
    ) AS missing_transaction_id_pct,

    COUNTIF(
        product_id IS NULL
        OR TRIM(product_id) = ''
    ) AS missing_product_id_count,

    ROUND(
        COUNTIF(
            product_id IS NULL
            OR TRIM(product_id) = ''
        ) * 100.0 / COUNT(*),
        2
    ) AS missing_product_id_pct

FROM retail.bronze_transactions;

-- =====================================================
-- 3. Invalid Numeric Value Analysis
-- =====================================================
-- Profiles invalid numeric values before Silver
-- transformation and casting.
--
-- SAFE_CAST() is intentionally used to gracefully
-- handle malformed source values without query failure.
--
-- Validates:
-- - Numeric conversion success
-- - Business-rule compliance (> 0)
--
-- Operational Impact:
-- - Incorrect revenue calculations
-- - Invalid inventory movement
-- - Reporting inaccuracies
-- =====================================================

WITH validated_numeric_data AS (

    SELECT
        *,
        SAFE_CAST(quantity AS INT64) AS quantity_int,
        SAFE_CAST(unit_price AS FLOAT64) AS unit_price_float

    FROM retail.bronze_transactions

)

SELECT
    COUNT(*) AS total_rows,

    COUNTIF(
        quantity_int IS NULL
        OR quantity_int <= 0
    ) AS invalid_quantity_count,

    ROUND(
        COUNTIF(
            quantity_int IS NULL
            OR quantity_int <= 0
        ) * 100.0 / COUNT(*),
        2
    ) AS invalid_quantity_pct,

    COUNTIF(
        unit_price_float IS NULL
        OR unit_price_float <= 0
    ) AS invalid_unit_price_count,

    ROUND(
        COUNTIF(
            unit_price_float IS NULL
            OR unit_price_float <= 0
        ) * 100.0 / COUNT(*),
        2
    ) AS invalid_unit_price_pct

FROM validated_numeric_data;

-- =====================================================
-- 4. Late-Arriving Data Analysis
-- =====================================================
-- Measures ingestion delay between:
-- - transaction_time (event time)
-- - ingestion_time (processing time)
--
-- Definition:
-- Late-arriving = delay > 120 minutes
--
-- Operational Impact:
-- - Freshness SLA violations
-- - Delayed dashboard visibility
-- - Late downstream processing
-- =====================================================

SELECT
    COUNT(*) AS total_rows,

    COUNTIF(
        TIMESTAMP_DIFF(
            ingestion_time,
            transaction_time,
            MINUTE
        ) > 120
    ) AS late_arriving_count,

    ROUND(
        COUNTIF(
            TIMESTAMP_DIFF(
                ingestion_time,
                transaction_time,
                MINUTE
            ) > 120
        ) * 100.0 / COUNT(*),
        2
    ) AS late_arriving_pct

FROM retail.bronze_transactions;

-- =====================================================
-- 5. Significantly Late Data Analysis
-- =====================================================
-- Identifies severely delayed records.
--
-- Definition:
-- Significantly late = delay > 1440 minutes (>24 hours)
--
-- Operational Impact:
-- - Upstream export failures
-- - Recovery/replay scenarios
-- - Severe SLA violations
-- =====================================================

SELECT
    COUNT(*) AS total_rows,

    COUNTIF(
        TIMESTAMP_DIFF(
            ingestion_time,
            transaction_time,
            MINUTE
        ) > 1440
    ) AS significantly_late_count,

    ROUND(
        COUNTIF(
            TIMESTAMP_DIFF(
                ingestion_time,
                transaction_time,
                MINUTE
            ) > 1440
        ) * 100.0 / COUNT(*),
        2
    ) AS significantly_late_pct

FROM retail.bronze_transactions;

-- =====================================================
-- 6. Cross-Batch Quality Metrics
-- =====================================================
-- Generates operational batch-level quality metrics
-- for reconciliation and observability.
--
-- Metrics Included:
-- - Total rows
-- - Duplicate rows
-- - Invalid rows
-- - Late-arriving rows
--
-- Operational Impact:
-- - Upstream source profiling
-- - Batch-level reconciliation
-- - Ingestion quality monitoring
-- - Operational diagnostics
-- =====================================================

WITH duplicate_transaction_ids AS (

    SELECT
        transaction_id

    FROM retail.bronze_transactions

    GROUP BY transaction_id

    HAVING COUNT(*) > 1

),

validated_batch_data AS (

    SELECT
        *,
        SAFE_CAST(quantity AS INT64) AS quantity_int,
        SAFE_CAST(unit_price AS FLOAT64) AS unit_price_float

    FROM retail.bronze_transactions

),

batch_metrics AS (

    SELECT
        source_batch,

        COUNT(*) AS total_rows,

        COUNTIF(
            transaction_id IN (
                SELECT transaction_id
                FROM duplicate_transaction_ids
            )
        ) AS duplicate_rows,

        ROUND(
            COUNTIF(
                transaction_id IN (
                    SELECT transaction_id
                    FROM duplicate_transaction_ids
                )
            ) * 100.0 / COUNT(*),
            2
        ) AS duplicate_rows_pct,

        COUNTIF(
            product_id IS NULL
            OR TRIM(product_id) = ''
            OR quantity_int IS NULL
            OR quantity_int <= 0
            OR unit_price_float IS NULL
            OR unit_price_float <= 0
        ) AS invalid_rows,

        ROUND(
            COUNTIF(
                product_id IS NULL
                OR TRIM(product_id) = ''
                OR quantity_int IS NULL
                OR quantity_int <= 0
                OR unit_price_float IS NULL
                OR unit_price_float <= 0
            ) * 100.0 / COUNT(*),
            2
        ) AS invalid_rows_pct,

        COUNTIF(
            TIMESTAMP_DIFF(
                ingestion_time,
                transaction_time,
                MINUTE
            ) > 120
        ) AS late_rows,

        ROUND(
            COUNTIF(
                TIMESTAMP_DIFF(
                    ingestion_time,
                    transaction_time,
                    MINUTE
                ) > 120
            ) * 100.0 / COUNT(*),
            2
        ) AS late_rows_pct

    FROM validated_batch_data

    GROUP BY source_batch
)

SELECT *
FROM batch_metrics
ORDER BY source_batch;