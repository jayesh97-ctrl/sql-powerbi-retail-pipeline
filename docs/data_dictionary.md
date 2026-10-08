# Data Dictionary — Online Retail Reporting Pipeline

Star schema: one fact table (`fact_sales`) + four dimensions (`dim_date`, `dim_product`, `dim_customer`, `dim_country`). Grain of `fact_sales` is one row per invoice line item (same grain as the source data) — nothing is pre-aggregated, so Power BI can slice to any level.

## fact_sales (536,641 rows)

| Column | Type | Description |
|---|---|---|
| `sales_key` | integer | Surrogate primary key for the fact table |
| `invoice_no` | text | Source invoice number. Prefixed `C` for a cancellation (e.g. `C536379`) |
| `date_key` | integer (FK → dim_date) | Transaction date as `YYYYMMDD` |
| `stock_code` | text (FK → dim_product) | Product code |
| `customer_id` | text (FK → dim_customer, nullable) | Null when `is_guest_order = 1` |
| `is_guest_order` | 0/1 | 1 when the source row had no customer ID (~25% of rows) |
| `country_key` | integer (FK → dim_country) | Shipping country for the order |
| `quantity` | integer | Units on this line. Negative for cancellations/returns |
| `unit_price` | real | Price per unit in GBP |
| `line_revenue` | real | `quantity × unit_price`, rounded to 2dp |
| `is_cancelled` | 0/1 | 1 when `invoice_no` starts with `C` |
| `is_adjustment_line` | 0/1 | 1 for non-product codes (postage, bank charges, manual adjustments — see data quality checklist) |
| `is_valid_sale_line` | 0/1 | **Use this as the filter for any revenue/volume measure.** 1 only when the line is a genuine completed sale: not cancelled, not an adjustment code, positive quantity, positive price |

## dim_date (374 rows — one per calendar day, 1 Dec 2010 – 9 Dec 2011)

| Column | Description |
|---|---|
| `date_key` | `YYYYMMDD` integer, joins to `fact_sales.date_key` |
| `full_date` | ISO date |
| `year`, `month`, `month_name`, `quarter` | Standard calendar breakdowns |
| `day_of_month`, `day_of_week_num` (0=Sunday), `day_name` | Day-level breakdowns |
| `is_weekend` | 1 for Saturday/Sunday |

## dim_product (4,070 rows — one per stock code)

| Column | Description |
|---|---|
| `stock_code` | Primary key, joins to `fact_sales.stock_code` |
| `product_description` | Canonical description (most frequent variant seen for that code in the source — descriptions had minor typos/case differences across rows) |
| `is_adjustment_line` | 1 for non-product codes: `POST` (postage), `DOT` (dotcom postage), `M` (manual adjustment), `D` (discount), `S` (samples), `AMAZONFEE`, `CRUK` (charity donation), `BANK CHARGES`, `PADS`, `C2` (carriage) |

## dim_country (36 rows)

| Column | Description |
|---|---|
| `country_key` | Primary key, joins to `fact_sales.country_key` |
| `country` | Standardised country name (`EIRE` → `Ireland`; `Unspecified`/`European Community` excluded as not real countries) |
| `region` | `UK` / `Europe (ex-UK)` / `Rest of World` grouping for quick regional rollups |

## dim_customer (4,372 rows — identified customers only)

| Column | Description |
|---|---|
| `customer_id` | Primary key, joins to `fact_sales.customer_id` (guest orders have no match here by design) |
| `primary_country` | Country the customer ordered from most often |
| `first_order_date`, `last_order_date` | Customer lifetime span in this dataset |
| `lifetime_orders` | Distinct invoice count for the customer |

## Design decisions worth knowing

- **Guest orders are kept, not dropped.** ~25% of rows have no `CustomerID`. Deleting them would silently remove a quarter of all revenue from reporting. They're flagged with `is_guest_order` instead, so revenue/volume reporting stays complete while customer-level reporting (retention, lifetime value) correctly excludes what it can't attribute.
- **Cancellations and adjustment lines are kept, not dropped.** A return is a real business event — hiding it would overstate net sales. Both are flagged (`is_cancelled`, `is_adjustment_line`) and excluded from `is_valid_sale_line`, so a report can show gross sales, cancellations, and net sales separately rather than only one blended number.
- **Nothing is deleted outright except exact duplicate rows** (5,268 extra copies, same invoice/product/qty/price/timestamp/customer/country captured twice). The 2 rows with a corrupted negative unit price are kept but excluded from `is_valid_sale_line`.
