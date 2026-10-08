# DAX Measures

All measures use `fact_sales[is_valid_sale_line] = 1` to mean "a genuine completed sale" (not cancelled, not a postage/fee adjustment line, positive quantity and price) — see `docs/data_dictionary.md` for why that flag exists instead of filtering rows out upstream.

Add these to a dedicated `_Measures` table (see `docs/powerbi_setup_guide.md` step 4).

```dax
Total Revenue =
CALCULATE(
    SUM(fact_sales[line_revenue]),
    fact_sales[is_valid_sale_line] = 1
)
```

```dax
Total Orders =
CALCULATE(
    DISTINCTCOUNT(fact_sales[invoice_no]),
    fact_sales[is_valid_sale_line] = 1
)
```

```dax
Total Units Sold =
CALCULATE(
    SUM(fact_sales[quantity]),
    fact_sales[is_valid_sale_line] = 1
)
```

```dax
Average Order Value =
DIVIDE([Total Revenue], [Total Orders])
```

```dax
Cancelled Revenue =
CALCULATE(
    SUM(fact_sales[line_revenue]),
    fact_sales[is_cancelled] = TRUE
)
```

```dax
Cancellation Rate =
VAR CancelledOrders =
    CALCULATE(DISTINCTCOUNT(fact_sales[invoice_no]), fact_sales[is_cancelled] = TRUE)
VAR AllOrders =
    DISTINCTCOUNT(fact_sales[invoice_no])
RETURN
    DIVIDE(CancelledOrders, AllOrders)
```

```dax
Guest Order % =
VAR GuestOrders =
    CALCULATE(DISTINCTCOUNT(fact_sales[invoice_no]), fact_sales[is_guest_order] = TRUE)
VAR AllOrders =
    DISTINCTCOUNT(fact_sales[invoice_no])
RETURN
    DIVIDE(GuestOrders, AllOrders)
```

```dax
-- Time intelligence — requires dim_date marked as the Date table (setup guide step 3)
Revenue PY =
CALCULATE([Total Revenue], SAMEPERIODLASTYEAR(dim_date[full_date]))
```

```dax
Revenue YoY % =
DIVIDE([Total Revenue] - [Revenue PY], [Revenue PY])
```

```dax
Revenue MTD =
TOTALMTD([Total Revenue], dim_date[full_date])
```

```dax
-- New vs returning: a customer's first-ever order date lives on dim_customer,
-- so "new in period" means their first order falls inside the filter context
New Customers =
CALCULATE(
    DISTINCTCOUNT(dim_customer[customer_id]),
    FILTER(
        dim_customer,
        dim_customer[first_order_date] >= MIN(dim_date[full_date]) &&
        dim_customer[first_order_date] <= MAX(dim_date[full_date])
    )
)
```

```dax
Returning Customer Revenue =
CALCULATE(
    [Total Revenue],
    FILTER(dim_customer, dim_customer[lifetime_orders] > 1),
    fact_sales[is_guest_order] = FALSE
)
```

## Why these specifically

- **`Total Revenue` / `Total Orders` / `Average Order Value`** are the three numbers any stakeholder asks for first — they anchor every KPI card on the Overview page.
- **`Cancellation Rate`** turns the `is_cancelled` flag from the cleaning stage into something a non-technical stakeholder can act on, rather than leaving it buried in the model.
- **`Guest Order %`** surfaces the ~25% missing-CustomerID issue as a business metric (how much of our reporting is "unattributed") instead of hiding it.
- **Time-intelligence measures** (`Revenue PY`, `Revenue YoY %`, `Revenue MTD`) are the measures that actually require `dim_date` to be a proper continuous calendar — they're also the ones that silently return wrong numbers if that setup step is skipped, which is worth being able to explain in an interview.
