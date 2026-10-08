-- ============================================================
-- 02_staging_clean.sql
-- Builds a typed, deduplicated staging table from raw_online_retail.
-- Every cleaning decision below is deliberate and documented inline
-- (and in docs/data_quality_checklist.md) rather than silently dropped.
-- ============================================================

DROP TABLE IF EXISTS stg_online_retail;

CREATE TABLE stg_online_retail AS
WITH deduped AS (
    -- Collapse exact duplicate rows (same invoice/product/qty/price/time/
    -- customer/country captured more than once in the source extract).
    -- ROW_NUMBER() over the full set of columns keeps exactly one copy.
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY InvoiceNo, StockCode, Description, Quantity,
                            InvoiceDate, UnitPrice, CustomerID, Country
               ORDER BY InvoiceNo
           ) AS rn
    FROM raw_online_retail
),
typed AS (
    SELECT
        InvoiceNo,
        StockCode,
        -- Non-product codes (postage, bank charges, manual adjustments,
        -- samples, Amazon fees) are flagged rather than deleted, so the
        -- fact table can still reconcile to source row counts but product-
        -- level reporting can exclude them with one filter.
        CASE WHEN StockCode IN ('POST','DOT','M','D','S','AMAZONFEE','CRUK','BANK CHARGES','PADS','C2')
             THEN 1 ELSE 0 END AS is_adjustment_line,
        NULLIF(TRIM(Description), '') AS description,
        CAST(Quantity AS INTEGER) AS quantity,
        -- Source dates arrive as "M/D/YYYY H:MM" text (ambiguous to parse in
        -- pure SQL), so InvoiceDateISO was normalised to ISO 8601 once at
        -- ingestion (see scripts/load_raw.py) — every tool downstream
        -- (SQLite, Power BI, pandas) then parses it identically.
        InvoiceDateISO AS invoice_date,
        CAST(UnitPrice AS REAL) AS unit_price,
        NULLIF(TRIM(CustomerID), '') AS customer_id,
        CASE WHEN TRIM(Country) IN ('Unspecified','European Community') THEN NULL
             WHEN TRIM(Country) = 'EIRE' THEN 'Ireland'
             WHEN TRIM(Country) = 'RSA' THEN 'South Africa'
             ELSE TRIM(Country)
        END AS country,
        InvoiceNo LIKE 'C%' AS is_cancelled
    FROM deduped
    WHERE rn = 1
)
SELECT
    InvoiceNo            AS invoice_no,
    StockCode            AS stock_code,
    is_adjustment_line,
    COALESCE(description, 'UNKNOWN ITEM') AS description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END AS is_guest_order,
    country,
    is_cancelled,
    -- A line is usable for revenue reporting only if it's a genuine sale:
    -- not a cancellation, not an adjustment code, and has a positive price.
    -- Rows failing this stay in the table (full auditability) but are
    -- excluded from fact_sales revenue measures via this flag.
    CASE WHEN is_cancelled = 0
          AND is_adjustment_line = 0
          AND quantity > 0
          AND unit_price > 0
         THEN 1 ELSE 0 END AS is_valid_sale_line
FROM typed;

CREATE INDEX idx_stg_invoice  ON stg_online_retail(invoice_no);
CREATE INDEX idx_stg_customer ON stg_online_retail(customer_id);
CREATE INDEX idx_stg_stock    ON stg_online_retail(stock_code);
