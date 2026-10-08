# Power BI Setup Guide

This pipeline's output (`data/star_schema/*.csv`) is built and validated entirely in SQL/SQLite. Power BI Desktop itself needs a Windows/Mac GUI to build, so this guide is the exact set of steps to turn those five CSVs into the finished report.

## 1. Import the tables

1. Open Power BI Desktop → **Get Data → Text/CSV**.
2. Import all five files from `data/star_schema/`: `fact_sales.csv`, `dim_date.csv`, `dim_product.csv`, `dim_customer.csv`, `dim_country.csv`.
3. In Power Query, check data types landed correctly: `date_key` and the `*_key`/`is_*` columns as Whole Number, `unit_price`/`line_revenue` as Decimal Number, `full_date` as Date.

## 2. Build the model relationships

In the **Model** view, create these relationships (all one-to-many, single direction, from dimension → fact):

| From | To |
|---|---|
| `dim_date[date_key]` | `fact_sales[date_key]` |
| `dim_product[stock_code]` | `fact_sales[stock_code]` |
| `dim_customer[customer_id]` | `fact_sales[customer_id]` |
| `dim_country[country_key]` | `fact_sales[country_key]` |

This is a standard star schema, so Power BI should auto-detect most of these — just confirm each one's cardinality is 1-to-many before moving on.

## 3. Mark dim_date as a Date table

Select `dim_date` → **Table tools → Mark as date table** → pick `full_date` as the date column. This is required before any time-intelligence DAX (`TOTALYTD`, `SAMEPERIODLASTYEAR`, etc.) will calculate correctly — without it, month-over-month and year-over-year measures silently return wrong numbers rather than erroring.

## 4. Add the measures

Create a new table (**Modeling → New table**, name it `_Measures`, just `_Measures = ROW("x", 1)`) to keep all DAX measures in one place rather than scattered across the physical tables. Add each measure from `docs/dax_measures.md` to it.

## 5. Build the report pages

A reasonable 3-page layout for this dataset:

- **Overview** — KPI cards (Total Revenue, Total Orders, Average Order Value, Cancellation Rate), a revenue-by-month line chart, a revenue-by-region map or bar chart.
- **Products** — top 10 products by revenue (bar chart), a table with product-level revenue/units/returns.
- **Customers** — guest vs identified revenue split, new vs returning customers over time, a customer table sorted by lifetime orders.

## 6. Publish

**Publish → Power BI Service**, then from the published report use **File → Publish to web** (or **Share**) to get a public/embeddable link for your LinkedIn post and GitHub README. If your account doesn't have "Publish to web" enabled, a set of screenshots or a short screen recording works as the fallback evidence.
