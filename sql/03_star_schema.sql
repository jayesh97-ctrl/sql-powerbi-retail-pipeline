-- ============================================================
-- 03_star_schema.sql
-- Builds a star schema (one fact table + four dimensions) from
-- stg_online_retail, ready to import into Power BI as separate tables
-- linked on the *_key columns below.
-- ============================================================

-- ---------- dim_date ----------
-- One row per calendar day spanning the dataset's date range, so Power BI
-- gets a real date table (continuous, no gaps) rather than only the dates
-- that happened to have a transaction.
DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date AS
WITH RECURSIVE date_range(d) AS (
    SELECT date((SELECT MIN(invoice_date) FROM stg_online_retail))
    UNION ALL
    SELECT date(d, '+1 day')
    FROM date_range
    WHERE d < (SELECT date(MAX(invoice_date)) FROM stg_online_retail)
)
SELECT
    CAST(strftime('%Y%m%d', d) AS INTEGER) AS date_key,
    d                                       AS full_date,
    CAST(strftime('%Y', d) AS INTEGER)      AS year,
    CAST(strftime('%m', d) AS INTEGER)      AS month,
    CASE CAST(strftime('%m', d) AS INTEGER)
        WHEN 1 THEN 'January' WHEN 2 THEN 'February' WHEN 3 THEN 'March'
        WHEN 4 THEN 'April' WHEN 5 THEN 'May' WHEN 6 THEN 'June'
        WHEN 7 THEN 'July' WHEN 8 THEN 'August' WHEN 9 THEN 'September'
        WHEN 10 THEN 'October' WHEN 11 THEN 'November' WHEN 12 THEN 'December'
    END AS month_name,
    (CAST(strftime('%m', d) AS INTEGER) + 2) / 3 AS quarter,
    CAST(strftime('%d', d) AS INTEGER)      AS day_of_month,
    CAST(strftime('%w', d) AS INTEGER)      AS day_of_week_num, -- 0=Sunday
    CASE strftime('%w', d)
        WHEN '0' THEN 'Sunday' WHEN '1' THEN 'Monday' WHEN '2' THEN 'Tuesday'
        WHEN '3' THEN 'Wednesday' WHEN '4' THEN 'Thursday' WHEN '5' THEN 'Friday'
        WHEN '6' THEN 'Saturday'
    END AS day_name,
    CASE WHEN strftime('%w', d) IN ('0','6') THEN 1 ELSE 0 END AS is_weekend
FROM date_range;

-- ---------- dim_product ----------
-- One row per stock code. Where the same code has slightly different
-- description text across rows (typos/case differences in the source),
-- the most frequent description is kept as the canonical label.
DROP TABLE IF EXISTS dim_product;
CREATE TABLE dim_product AS
WITH ranked AS (
    SELECT
        stock_code,
        description,
        is_adjustment_line,
        COUNT(*) AS n,
        ROW_NUMBER() OVER (PARTITION BY stock_code ORDER BY COUNT(*) DESC) AS rn
    FROM stg_online_retail
    GROUP BY stock_code, description, is_adjustment_line
)
SELECT
    stock_code,
    description AS product_description,
    is_adjustment_line
FROM ranked
WHERE rn = 1;

-- ---------- dim_country ----------
DROP TABLE IF EXISTS dim_country;
CREATE TABLE dim_country AS
SELECT
    ROW_NUMBER() OVER (ORDER BY country) AS country_key,
    country,
    CASE
        WHEN country = 'United Kingdom' THEN 'UK'
        WHEN country IN ('France','Germany','Netherlands','Belgium','Spain','Portugal',
                          'Italy','Ireland','Poland','Austria','Denmark','Sweden','Finland',
                          'Norway','Switzerland','Cyprus','Greece','Malta','Lithuania',
                          'Channel Islands','Czech Republic','Iceland') THEN 'Europe (ex-UK)'
        WHEN country IS NULL THEN 'Unknown'
        ELSE 'Rest of World'
    END AS region
FROM (SELECT DISTINCT country FROM stg_online_retail WHERE country IS NOT NULL);

-- ---------- dim_customer ----------
-- Real customers only (guest/unidentified orders are handled in fact_sales
-- via is_guest_order rather than invented with a fake customer id).
DROP TABLE IF EXISTS dim_customer;
CREATE TABLE dim_customer AS
SELECT
    customer_id,
    -- A customer can appear against more than one country in messy source
    -- data; take the country they ordered from most often as their home market.
    (SELECT country FROM stg_online_retail s2
      WHERE s2.customer_id = s1.customer_id AND country IS NOT NULL
      GROUP BY country ORDER BY COUNT(*) DESC LIMIT 1) AS primary_country,
    MIN(invoice_date) AS first_order_date,
    MAX(invoice_date) AS last_order_date,
    COUNT(DISTINCT invoice_no) AS lifetime_orders
FROM stg_online_retail s1
WHERE customer_id IS NOT NULL
GROUP BY customer_id;

-- ---------- fact_sales ----------
-- Grain: one row per invoice line (same grain as the source). Every row
-- from staging is kept for full auditability; is_valid_sale_line is the
-- single filter Power BI measures use to get "real sale revenue".
DROP TABLE IF EXISTS fact_sales;
CREATE TABLE fact_sales AS
SELECT
    ROW_NUMBER() OVER (ORDER BY s.invoice_no, s.stock_code) AS sales_key,
    s.invoice_no,
    CAST(strftime('%Y%m%d', s.invoice_date) AS INTEGER) AS date_key,
    s.stock_code,
    s.customer_id,
    s.is_guest_order,
    c.country_key,
    s.quantity,
    s.unit_price,
    ROUND(s.quantity * s.unit_price, 2) AS line_revenue,
    s.is_cancelled,
    s.is_adjustment_line,
    s.is_valid_sale_line
FROM stg_online_retail s
LEFT JOIN dim_country c ON c.country = s.country;

CREATE INDEX idx_fact_date     ON fact_sales(date_key);
CREATE INDEX idx_fact_product  ON fact_sales(stock_code);
CREATE INDEX idx_fact_customer ON fact_sales(customer_id);
CREATE INDEX idx_fact_country  ON fact_sales(country_key);
