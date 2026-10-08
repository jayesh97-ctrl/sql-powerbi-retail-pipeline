-- ============================================================
-- 04_validation_queries.sql
-- Post-build checks: row counts reconcile, no orphaned foreign keys,
-- revenue totals are sane. These are the checks to re-run after any
-- change to the SQL above, before trusting the Power BI report on top.
-- ============================================================

-- fact_sales should have exactly as many rows as the staging table
-- (every line is kept; nothing silently dropped during modelling)
SELECT
    (SELECT COUNT(*) FROM stg_online_retail) AS staging_rows,
    (SELECT COUNT(*) FROM fact_sales)        AS fact_rows;

-- No fact row should reference a date_key missing from dim_date
SELECT COUNT(*) AS orphan_dates
FROM fact_sales f
LEFT JOIN dim_date d ON f.date_key = d.date_key
WHERE d.date_key IS NULL;

-- No fact row should reference a stock_code missing from dim_product
SELECT COUNT(*) AS orphan_products
FROM fact_sales f
LEFT JOIN dim_product p ON f.stock_code = p.stock_code
WHERE p.stock_code IS NULL;

-- No non-guest fact row should reference a customer_id missing from dim_customer
SELECT COUNT(*) AS orphan_customers
FROM fact_sales f
LEFT JOIN dim_customer c ON f.customer_id = c.customer_id
WHERE f.is_guest_order = 0 AND c.customer_id IS NULL;

-- Total valid-sale revenue, for a sanity check against the source data
-- (cross-check this number against a pandas groupby on the raw CSV)
SELECT ROUND(SUM(line_revenue), 2) AS total_valid_revenue
FROM fact_sales
WHERE is_valid_sale_line = 1;

-- Top 10 countries by valid-sale revenue — a standard "does this look
-- right" check: UK should dominate heavily, since this is a UK retailer.
SELECT co.country, ROUND(SUM(f.line_revenue), 2) AS revenue
FROM fact_sales f
JOIN dim_country co ON co.country_key = f.country_key
WHERE f.is_valid_sale_line = 1
GROUP BY co.country
ORDER BY revenue DESC
LIMIT 10;
