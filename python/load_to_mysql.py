"""Load the cleaned CSV into MySQL. Use --recreate to drop and rebuild the table."""

import argparse
import logging
import os
import sys
from pathlib import Path
from urllib.parse import quote_plus

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

BASE_DIR = Path(__file__).resolve().parents[1]
CSV_FILE = BASE_DIR / "data" / "processed" / "online_retail_cleaned.csv"
SCHEMA_FILE = BASE_DIR / "sql" / "01_create_schema.sql"
DB_NAME = "ecommerce_analytics"
TABLE = "online_retail"
CHUNK_SIZE = 10_000

COLUMNS = [
    "invoice_no", "stock_code", "description", "quantity", "invoice_date", "unit_price",
    "customer_id", "country", "is_cancelled", "total_price", "invoice_year",
    "invoice_month", "invoice_year_month", "day_of_week", "invoice_hour",
]

load_dotenv(BASE_DIR / ".env")
logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(message)s")
log = logging.getLogger(__name__)


def make_engine(database: str | None = None):
    user = os.getenv("MYSQL_USER", "root")
    password = quote_plus(os.getenv("MYSQL_PASSWORD", ""))
    host = os.getenv("MYSQL_HOST", "localhost")
    port = os.getenv("MYSQL_PORT", "3306")
    db = f"/{database}" if database else ""
    return create_engine(f"mysql+pymysql://{user}:{password}@{host}:{port}{db}?charset=utf8mb4", pool_pre_ping=True)


def read_statements(path: Path) -> list[str]:
    lines = [ln for ln in path.read_text(encoding="utf-8").splitlines() if not ln.strip().startswith("--")]
    return [stmt.strip() for stmt in "\n".join(lines).split(";") if stmt.strip()]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--recreate", action="store_true")
    args = parser.parse_args()

    if not CSV_FILE.exists():
        sys.exit("Cleaned CSV not found. Run 01_data_cleaning.py first.")

    with make_engine().begin() as conn:
        if args.recreate:
            conn.execute(text(f"DROP TABLE IF EXISTS {DB_NAME}.{TABLE}"))
        for stmt in read_statements(SCHEMA_FILE):
            conn.execute(text(stmt))

    engine = make_engine(DB_NAME)
    with engine.begin() as conn:
        conn.execute(text(f"TRUNCATE TABLE {TABLE}"))

    chunks = pd.read_csv(
        CSV_FILE, chunksize=CHUNK_SIZE, parse_dates=["invoice_date"],
        dtype={"invoice_no": "string", "stock_code": "string", "customer_id": "Int64", "country": "string"},
    )
    loaded = 0
    for chunk in chunks:
        chunk = chunk[COLUMNS].astype(object)
        chunk.where(chunk.notna(), None).to_sql(TABLE, engine, if_exists="append", index=False, method="multi")
        loaded += len(chunk)
        log.info("Loaded %s rows", f"{loaded:,}")

    with engine.connect() as conn:
        rows, revenue = conn.execute(text(
            f"SELECT COUNT(*), SUM(CASE WHEN is_cancelled = 0 THEN total_price END) FROM {TABLE}"
        )).one()

    csv_revenue = sum(
        c.loc[c["is_cancelled"] == 0, "total_price"].sum()
        for c in pd.read_csv(CSV_FILE, usecols=["total_price", "is_cancelled"], chunksize=100_000)
    )
    log.info("MySQL: %s rows, revenue %s | CSV: %s rows, revenue %s",
             f"{rows:,}", f"{float(revenue):,.2f}", f"{loaded:,}", f"{csv_revenue:,.2f}")
    if rows != loaded or abs(float(revenue) - csv_revenue) > 1:
        sys.exit("Mismatch between MySQL and CSV")
    log.info("Done, data matches")


if __name__ == "__main__":
    main()