-- ============================================================
-- 01_data_quality_checks.sql
-- Profiles the raw Online Retail dataset BEFORE any cleaning.
-- Run against: raw_online_retail (loaded as-is from the source CSV,
-- every column typed as TEXT so nothing is silently coerced/lost).
-- ============================================================

-- Row count baseline
SELECT COUNT(*) AS total_rows FROM raw_online_retail;

-- Missing values per column that matters for analysis
SELECT
    SUM(CASE WHEN Description IS NULL OR TRIM(Description) = '' THEN 1 ELSE 0 END) AS missing_description,
    SUM(CASE WHEN CustomerID  IS NULL OR TRIM(CustomerID)  = '' THEN 1 ELSE 0 END) AS missing_customer_id
FROM raw_online_retail;

-- Cancelled orders: UCI's documentation states InvoiceNo is prefixed with
-- 'C' for a cancellation. These are real transactions (a return), not junk,
-- but they need separate handling from completed sales.
SELECT COUNT(*) AS cancelled_rows
FROM raw_online_retail
WHERE InvoiceNo LIKE 'C%';

-- Quantity / UnitPrice outside a normal sales range
SELECT
    SUM(CASE WHEN CAST(Quantity AS REAL) < 0 THEN 1 ELSE 0 END)  AS negative_quantity,
    SUM(CASE WHEN CAST(Quantity AS REAL) = 0 THEN 1 ELSE 0 END)  AS zero_quantity,
    SUM(CASE WHEN CAST(UnitPrice AS REAL) < 0 THEN 1 ELSE 0 END) AS negative_unit_price,
    SUM(CASE WHEN CAST(UnitPrice AS REAL) = 0 THEN 1 ELSE 0 END) AS zero_unit_price
FROM raw_online_retail;

-- Exact duplicate rows (same invoice, product, quantity, price, timestamp,
-- customer — i.e. the row was captured twice, not two genuine line items)
SELECT COUNT(*) AS duplicate_rows
FROM (
    SELECT InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country,
           COUNT(*) AS n
    FROM raw_online_retail
    GROUP BY InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country
    HAVING COUNT(*) > 1
);

-- "Non-product" stock codes: fees, postage, and adjustments mixed into the
-- same column as real products. These would inflate product-level reporting
-- if left in (e.g. "POST" looks like a top-selling SKU purely from volume).
SELECT StockCode, COUNT(*) AS n
FROM raw_online_retail
WHERE StockCode IN ('POST','DOT','M','D','S','AMAZONFEE','CRUK','BANK CHARGES','PADS','C2')
GROUP BY StockCode
ORDER BY n DESC;

-- Country naming inconsistencies worth standardising (e.g. "EIRE" for Ireland,
-- "Unspecified" / "European Community" as non-country placeholders)
SELECT DISTINCT Country FROM raw_online_retail ORDER BY Country;
