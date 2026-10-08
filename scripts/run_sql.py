"""
run_sql.py <sql_file> [<sql_file> ...]
Runs one or more .sql scripts against data/retail.db in order, printing
any SELECT results. Statements are split on ';' after stripping full-line
comments, so each script can freely mix DDL, DML, and documentation
comments.
"""
import sqlite3
import sys

DB_PATH = "data/retail.db"


def run_file(conn, path):
    print(f"\n=== {path} ===")
    sql = open(path, encoding="utf-8").read()
    clean = "\n".join(l for l in sql.split("\n") if not l.strip().startswith("--"))
    for stmt in clean.split(";"):
        stmt = stmt.strip()
        if not stmt:
            continue
        cur = conn.execute(stmt)
        if cur.description:
            cols = [d[0] for d in cur.description]
            rows = cur.fetchall()
            print(cols)
            for r in rows[:20]:
                print(r)
            if len(rows) > 20:
                print(f"... ({len(rows)} rows total)")
    conn.commit()


if __name__ == "__main__":
    conn = sqlite3.connect(DB_PATH)
    for path in sys.argv[1:]:
        run_file(conn, path)
    conn.close()
