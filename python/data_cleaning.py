"""Download Online Retail from UCI (if missing), clean it, save to data/processed/."""

import logging
import re
from pathlib import Path

import pandas as pd

BASE_DIR = Path(__file__).resolve().parents[1]
RAW_FILE = BASE_DIR / "data" / "raw" / "online_retail_raw.csv"
OUT_FILE = BASE_DIR / "data" / "processed" / "online_retail_cleaned.csv"

NON_PRODUCT_CODES = {
    "POST", "DOT", "M", "C2", "D", "S", "B", "CRUK", "PADS",
    "BANK CHARGES", "AMAZONFEE", "AMAZON FEE", "ADJUST", "ADJUST2",
}
NON_PRODUCT_PATTERN = re.compile(r"^(GIFT_\d+_\d+|DCGS.*|TEST\d*)$")

RENAME = {
    "InvoiceNo": "invoice_no", "StockCode": "stock_code", "Description": "description",
    "Quantity": "quantity", "InvoiceDate": "invoice_date", "UnitPrice": "unit_price",
    "CustomerID": "customer_id", "Country": "country",
}

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(message)s")
log = logging.getLogger(__name__)


def download_raw() -> None:
    from ucimlrepo import fetch_ucirepo

    log.info("Downloading dataset from UCI...")
    df = fetch_ucirepo(id=352).data.original
    RAW_FILE.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(RAW_FILE, index=False)
    log.info("Saved raw: %s rows", f"{len(df):,}")


def load_raw() -> pd.DataFrame:
    if not RAW_FILE.exists():
        download_raw()
    df = pd.read_csv(RAW_FILE, dtype={"InvoiceNo": str, "StockCode": str}).rename(columns=RENAME)
    df["invoice_date"] = pd.to_datetime(df["invoice_date"], format="mixed")
    return df


def step(df: pd.DataFrame, before: int, label: str) -> None:
    log.info("%-28s -%6s -> %s", label, f"{before - len(df):,}", f"{len(df):,}")


def clean(df: pd.DataFrame) -> pd.DataFrame:
    n_raw = len(df)

    df["invoice_no"] = df["invoice_no"].str.strip().str.upper()
    df["stock_code"] = df["stock_code"].str.strip().str.upper()
    df["description"] = df["description"].astype("string").str.strip().str.replace(r"\s+", " ", regex=True)
    df["country"] = (
        df["country"].astype("string").str.strip()
        .replace({"EIRE": "Ireland", "RSA": "South Africa", "Unspecified": pd.NA})
    )

    n = len(df)
    df = df.drop_duplicates()
    step(df, n, "Duplicates")

    n = len(df)
    non_product = df["stock_code"].isin(NON_PRODUCT_CODES) | df["stock_code"].str.match(NON_PRODUCT_PATTERN)
    df = df[~non_product]
    step(df, n, "Non-product codes")

    n = len(df)
    df = df[df["unit_price"] > 0]
    step(df, n, "Price <= 0")

    n = len(df)
    cancel = df["invoice_no"].str.startswith("C")
    df = df[(cancel & (df["quantity"] < 0)) | (~cancel & (df["quantity"] > 0))]
    step(df, n, "Invalid quantity")

    # One most-common description per stock_code
    mode_desc = (
        df.assign(d=df["description"].str.upper()).dropna(subset=["d"])
        .groupby("stock_code")["d"].agg(lambda s: s.value_counts().idxmax())
    )
    df["description"] = df["stock_code"].map(mode_desc)
    n = len(df)
    df = df.dropna(subset=["description"]).drop_duplicates()
    step(df, n, "Missing description")

    df["customer_id"] = df["customer_id"].astype("Int64")
    df["is_cancelled"] = df["invoice_no"].str.startswith("C").astype("int8")
    df["total_price"] = (df["quantity"] * df["unit_price"]).round(2)
    df["invoice_year"] = df["invoice_date"].dt.year.astype("int16")
    df["invoice_month"] = df["invoice_date"].dt.month.astype("int8")
    df["invoice_year_month"] = df["invoice_date"].dt.strftime("%Y-%m")
    df["day_of_week"] = df["invoice_date"].dt.day_name()
    df["invoice_hour"] = df["invoice_date"].dt.hour.astype("int8")

    log.info("Removed %s of %s rows", f"{n_raw - len(df):,}", f"{n_raw:,}")
    return df.sort_values(["invoice_date", "invoice_no"]).reset_index(drop=True)


def main() -> None:
    df = clean(load_raw())
    assert df["unit_price"].gt(0).all() and df["description"].notna().all() and not df.duplicated().any()

    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUT_FILE, index=False)
    sales = df.loc[df["is_cancelled"] == 0, "total_price"].sum()
    log.info("Saved %s: %s rows, %s invoices, %s customers, revenue %s",
             OUT_FILE.name, f"{len(df):,}", f"{df['invoice_no'].nunique():,}",
             f"{df['customer_id'].nunique():,}", f"{sales:,.2f}")


if __name__ == "__main__":
    main()
