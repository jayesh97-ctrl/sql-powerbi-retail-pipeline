# Data Quality Checklist

Findings from `sql/01_data_quality_checks.sql`, run against the raw source table before any cleaning, and how each was resolved in `sql/02_staging_clean.sql`.

| # | Issue found | Scale | Resolution | Why |
|---|---|---|---|---|
| 1 | Exact duplicate rows | 4,879 rows | Deduplicated with `ROW_NUMBER()` over every column, keep first occurrence | Source extract captured some lines twice; keeping duplicates would double-count revenue |
| 2 | Missing `CustomerID` | 135,080 rows (~25%) | Kept, flagged `is_guest_order = 1` | Dropping a quarter of all transactions would understate revenue; the business still shipped and billed these orders |
| 3 | Missing `Description` | 1,454 rows | Replaced with `'UNKNOWN ITEM'` placeholder | A handful of stock codes had blank descriptions in the source; kept visible as unknown rather than silently inherited from another row |
| 4 | Cancelled orders (`InvoiceNo` starts with `C`) | 9,288 rows | Flagged `is_cancelled = 1`, excluded from `is_valid_sale_line` | A cancellation is a real event (a return), not noise — it should be reportable on its own, not deleted or blended into gross sales |
| 5 | Negative `Quantity` | 10,624 rows | Kept (mostly = cancellations above), excluded from valid-sale revenue via `is_valid_sale_line` | Confirms cancellations behave as expected (negative quantity almost always pairs with `is_cancelled = 1`) |
| 6 | Zero/negative `UnitPrice` | 2,515 rows (zero) + 2 rows (negative) | Zero-price lines kept (often free promotional items) but excluded from `is_valid_sale_line`; the 2 negative-price rows are a data entry error and excluded entirely | A free item isn't a data error and shouldn't be deleted, but it also shouldn't count as revenue |
| 7 | Non-product stock codes (`POST`, `DOT`, `M`, `D`, `S`, `AMAZONFEE`, `CRUK`, `BANK CHARGES`, `PADS`, `C2`) | ~2,900 rows | Flagged `is_adjustment_line = 1` in both `stg_online_retail` and `dim_product`, excluded from `is_valid_sale_line` | These are postage, fees, and manual adjustments mixed into the product column — left in, "POST" would rank as a top-selling SKU purely from transaction volume |
| 8 | Inconsistent country naming (`EIRE`, `Unspecified`, `European Community`) | 38 raw values → 36 clean | `EIRE` → `Ireland`; `Unspecified`/`European Community` set to `NULL` (not real countries) | Standard country names are needed for any geographic rollup or map visual in Power BI |

## Post-build validation (`sql/04_validation_queries.sql`)

- `fact_sales` row count matches `stg_online_retail` exactly (536,641 = 536,641) — every staging row made it into the fact table, nothing silently lost during modelling.
- Zero orphaned foreign keys across `dim_date`, `dim_product`, and `dim_customer`.
- Total valid-sale revenue: **£10,258,969.74**, with the United Kingdom accounting for ~85% of it — consistent with this being a UK-based retailer, which is the expected sanity-check result.
