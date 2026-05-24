-- =========================================================
-- Phase 4: Silver Layer Transformation
-- Objective:
-- Create analytics-ready Silver table from Bronze layer
-- by applying:
--   - deduplication
--   - validation
--   - safe type casting
--   - freshness enrichment
--   - operational quality flags
--
-- Silver Layer Responsibilities:
--   - retain latest transaction version
--   - identify invalid records
--   - calculate freshness metrics
--   - support downstream analytics/reporting
-- =========================================================

-- =========================================================
-- Final Silver Table Creation
--
-- Partitioning:
--   DATE(transaction_time)
--
-- Clustering:
--   store_id
--   is_valid
--
-- Purpose:
--   - optimize analytics queries
--   - reduce BigQuery scan costs
--   - improve operational filtering
-- =========================================================

CREATE OR REPLACE TABLE retail.silver_transactions

PARTITION BY DATE(transaction_time)

CLUSTER BY store_id, is_valid

AS

-- =========================================================
-- Step 1: Rank duplicate transactions
--
-- Logic:
-- Retain latest version of each transaction_id
-- using:
--   1. latest ingestion_time
--   2. latest source_batch
--
-- This simulates replay-aware ingestion handling.
-- =========================================================

WITH bronze_ranked AS (

    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY transaction_id
            ORDER BY ingestion_time DESC, source_batch DESC
        ) AS row_num

    FROM retail.bronze_transactions

),


-- =========================================================
-- Step 2: Keep latest transaction version only
--
-- SAFE_CAST is used to prevent pipeline failures caused
-- by dirty Bronze values such as:
--   - N/A
--   - negative values
--   - malformed numeric strings
-- =========================================================

deduplicated AS (

    SELECT
        transaction_id,
        store_id,
        product_id,

        SAFE_CAST(quantity AS INT64) AS quantity,

        SAFE_CAST(unit_price AS FLOAT64) AS unit_price,

        transaction_time,
        ingestion_time,
        source_batch

    FROM bronze_ranked

    WHERE row_num = 1

),

-- =========================================================
-- Step 3: Apply validation and enrichment logic
--
-- Adds:
--   - freshness metrics
--   - late-arrival indicators
--   - validity checks
--   - invalid reason classification
-- =========================================================

validated AS (

    SELECT

        transaction_id,
        store_id,
        product_id,
        quantity,
        unit_price,

        transaction_time,
        ingestion_time,
        source_batch,


        -- =================================================
        -- Business enrichment
        -- =================================================

        CASE
            WHEN quantity > 0
                AND unit_price > 0
            THEN quantity * unit_price
            ELSE NULL
        END AS total_amount,

        TIMESTAMP_DIFF(
            ingestion_time,
            transaction_time,
            MINUTE
        ) AS freshness_minutes,


        -- =================================================
        -- Late-arriving indicators
        -- =================================================

        TIMESTAMP_DIFF(
            ingestion_time,
            transaction_time,
            MINUTE
        ) > 120 AS is_late,

        TIMESTAMP_DIFF(
            ingestion_time,
            transaction_time,
            MINUTE
        ) > 1440 AS is_significantly_late,


        -- =================================================
        -- Validation status
        -- =================================================

        CASE

            WHEN transaction_id IS NULL
                 OR TRIM(transaction_id) = ''
            THEN FALSE

            WHEN product_id IS NULL
                 OR TRIM(product_id) = ''
            THEN FALSE

            WHEN quantity IS NULL
                 OR quantity <= 0
            THEN FALSE

            WHEN unit_price IS NULL
                 OR unit_price <= 0
            THEN FALSE

            WHEN transaction_time IS NULL
            THEN FALSE

            ELSE TRUE

        END AS is_valid,


        -- =================================================
        -- Invalid reason classification
        -- =================================================

        CASE

            WHEN transaction_id IS NULL
                 OR TRIM(transaction_id) = ''
            THEN 'Missing transaction_id'

            WHEN product_id IS NULL
                 OR TRIM(product_id) = ''
            THEN 'Missing product_id'

            WHEN quantity IS NULL
            THEN 'Invalid quantity format'

            WHEN quantity <= 0
            THEN 'Invalid quantity value'

            WHEN unit_price IS NULL
            THEN 'Invalid unit_price format'

            WHEN unit_price <= 0
            THEN 'Invalid unit_price value'

            WHEN transaction_time IS NULL
            THEN 'Missing transaction_time'

            ELSE NULL

        END AS invalid_reason,


        -- =================================================
        -- Audit column
        -- =================================================

        CURRENT_TIMESTAMP() AS silver_processed_at

    FROM deduplicated

)

SELECT *
FROM validated;