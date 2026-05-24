-- =====================================================
-- Phase 3: Data Issues Identification
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
-- =====================================================

SELECT
    transaction_id,
    COUNT(*) AS duplicate_count,
    STRING_AGG(DISTINCT source_batch, ', ') AS batches_present
FROM retail.bronze_transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;





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





SELECT
    COUNT(*) AS total_rows,

    COUNTIF(
        SAFE_CAST(quantity AS INT64) IS NULL
        OR SAFE_CAST(quantity AS INT64) <= 0
    ) AS invalid_quantity_count,

    ROUND(
        COUNTIF(
            SAFE_CAST(quantity AS INT64) IS NULL
            OR SAFE_CAST(quantity AS INT64) <= 0
        ) * 100.0 / COUNT(*),
        2
    ) AS invalid_quantity_pct,

    COUNTIF(
        SAFE_CAST(unit_price AS FLOAT64) IS NULL
        OR SAFE_CAST(unit_price AS FLOAT64) <= 0
    ) AS invalid_unit_price_count,

    ROUND(
        COUNTIF(
            SAFE_CAST(unit_price AS FLOAT64) IS NULL
            OR SAFE_CAST(unit_price AS FLOAT64) <= 0
        ) * 100.0 / COUNT(*),
        2
    ) AS invalid_unit_price_pct

FROM retail.bronze_transactions;





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





WITH duplicate_transactions AS (

    SELECT
        transaction_id
    FROM retail.bronze_transactions
    GROUP BY transaction_id
    HAVING COUNT(*) > 1

),

batch_metrics AS (

    SELECT
        source_batch,

        COUNT(*) AS total_rows,

        COUNTIF(
            transaction_id IN (
                SELECT transaction_id
                FROM duplicate_transactions
            )
        ) AS duplicate_rows,

        COUNTIF(
            product_id IS NULL
            OR TRIM(product_id) = ''
            OR SAFE_CAST(quantity AS INT64) IS NULL
            OR SAFE_CAST(quantity AS INT64) <= 0
            OR SAFE_CAST(unit_price AS FLOAT64) IS NULL
            OR SAFE_CAST(unit_price AS FLOAT64) <= 0
        ) AS invalid_rows,

        COUNTIF(
            TIMESTAMP_DIFF(
                ingestion_time,
                transaction_time,
                MINUTE
            ) > 120
        ) AS late_rows

    FROM retail.bronze_transactions

    GROUP BY source_batch
)

SELECT *
FROM batch_metrics
ORDER BY source_batch;





