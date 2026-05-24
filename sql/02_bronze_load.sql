-- =====================================================
-- Phase 2: Bronze Layer Load
-- Objective:
-- Load raw POS transaction batches into Bronze layer
-- exactly as received without transformations.
-- =====================================================

CREATE TABLE IF NOT EXISTS retail.bronze_transactions (
    transaction_id    STRING,
    store_id          STRING,
    product_id        STRING,
    quantity          STRING,
    unit_price        STRING,
    transaction_time  TIMESTAMP,
    ingestion_time    TIMESTAMP,
    source_batch      STRING
)
PARTITION BY DATE(ingestion_time);