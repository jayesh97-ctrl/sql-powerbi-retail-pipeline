"""
load_raw.py
Loads the source CSV into a SQLite database as a single untouched
raw table, with one light preprocessing step: normalising InvoiceDate
to ISO 8601. This is the only transformation done outside SQL, because
SQLite has no reliable way to parse "M/D/YYYY H:MM" text dates on its
own — every other cleaning/modelling step lives in the numbered SQL
scripts in sql/, run in order.

Source dataset: UCI "Online Retail" (Dec 2010 - Dec 2011), a real UK-based
online retailer's transaction-level sales. Mirrored via a well-known
teaching repo since the UCI archive itself isn't always reachable:
https://raw.githubusercontent.com/databricks/Spark-The-Definitive-Guide/master/data/retail-data/all/online-retail-dataset.csv
Original source: https://archive.ics.uci.edu/dataset/502/online+retail+ii
"""
import sqlite3
import pandas as pd

RAW_CSV = "raw/online-retail-dataset.csv"
DB_PATH = "data/retail.db"


def main():
    df = pd.read_csv(RAW_CSV, encoding="latin1", dtype=str)
    df["InvoiceDateISO"] = pd.to_datetime(
        df["InvoiceDate"], format="%m/%d/%Y %H:%M"
    ).dt.strftime("%Y-%m-%d %H:%M:%S")

    conn = sqlite3.connect(DB_PATH)
    df.to_sql("raw_online_retail", conn, if_exists="replace", index=False)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_raw_invoice ON raw_online_retail(InvoiceNo)")
    conn.commit()

    n = conn.execute("SELECT COUNT(*) FROM raw_online_retail").fetchone()[0]
    print(f"Loaded {n:,} rows into {DB_PATH}:raw_online_retail")
    conn.close()


if __name__ == "__main__":
    main()
