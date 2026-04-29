"""
FMP Ticker Fetcher  (v2 — stable API)
======================================
Fetches the master list of stock tickers from Financial Modeling Prep (FMP)
for Middle-East / North-Africa exchanges, then enriches each ticker with
its company name via yfinance (free, unlimited).

Target Exchanges:
  - EGX  (Egyptian Exchange)
  - SAU  (Saudi Exchange / Tadawul)
  - DFM  (Dubai Financial Market)

Note: ADX (Abu Dhabi) is not available as a separate exchange on FMP.
      DFM data may include some Abu Dhabi cross-listed stocks.

API Budget : Exactly 3 FMP calls  (one per exchange).
             Company names come from yfinance (no FMP cost).
Output     : One CSV per exchange  +  a consolidated SQLite database.

Usage:
    pip install requests pandas yfinance
    python fetch_tickers.py
"""

import os
import time
import sqlite3
import logging
from pathlib import Path

import requests
import pandas as pd

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

API_KEY: str = os.getenv("FMP_API_KEY", "E86nzg2waGqVLzmw6hulTGvcR2xWzrFz")

# New stable endpoint — works on Free Tier for all exchanges
BASE_URL: str = "https://financialmodelingprep.com/stable/batch-exchange-quote"

# FMP exchange codes
EXCHANGES: dict[str, str] = {
    "EGX": "EGX",   # Egyptian Exchange
    "KSA": "SAU",   # Saudi Exchange (Tadawul)
    "DFM": "DFM",   # Dubai Financial Market
}

OUTPUT_DIR: Path = Path(__file__).resolve().parent / "ticker_data"
SQLITE_DB:  Path = OUTPUT_DIR / "tickers.db"

REQUEST_TIMEOUT: int = 30
RETRY_DELAY:     int = 3
MAX_RETRIES:     int = 2

# Whether to enrich symbols with company names from yfinance
ENRICH_NAMES: bool = True

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# FMP Fetch
# ---------------------------------------------------------------------------


def fetch_exchange_symbols(exchange_code: str) -> list[dict]:
    """
    Single GET to /stable/batch-exchange-quote?exchange=XXX
    Returns list of dicts with at least {'symbol', 'price', ...}.
    """
    params = {"apikey": API_KEY, "exchange": exchange_code}

    for attempt in range(1, MAX_RETRIES + 2):
        try:
            log.info(
                "  -> Requesting %s (attempt %d/%d)...",
                exchange_code, attempt, MAX_RETRIES + 1,
            )
            resp = requests.get(BASE_URL, params=params, timeout=REQUEST_TIMEOUT)
            resp.raise_for_status()

            data = resp.json()

            if isinstance(data, dict) and "Error Message" in data:
                log.error("  X FMP error: %s", data["Error Message"])
                return []

            log.info("  OK Received %d symbols for %s", len(data), exchange_code)
            return data

        except requests.exceptions.Timeout:
            log.warning("  ! Timeout on attempt %d for %s", attempt, exchange_code)
        except requests.exceptions.HTTPError:
            log.error("  X HTTP %s for %s", resp.status_code, exchange_code)
            if 400 <= resp.status_code < 500:
                return []
        except requests.exceptions.ConnectionError as exc:
            log.warning("  ! Connection error for %s: %s", exchange_code, exc)
        except requests.exceptions.JSONDecodeError:
            log.error("  X Invalid JSON for %s", exchange_code)
            return []
        except Exception as exc:
            log.exception("  X Unexpected error for %s: %s", exchange_code, exc)
            return []

        if attempt <= MAX_RETRIES:
            time.sleep(RETRY_DELAY)

    log.error("  X All retries exhausted for %s", exchange_code)
    return []


# ---------------------------------------------------------------------------
# Name Enrichment via yfinance (free, no API key needed)
# ---------------------------------------------------------------------------


def enrich_with_names(df: pd.DataFrame) -> pd.DataFrame:
    """
    Use yfinance to look up company names for each symbol.
    This is free and does not consume FMP quota.
    Uses multithreading for speed.
    """
    try:
        import yfinance as yf
    except ImportError:
        log.warning(
            "  yfinance not installed — skipping name enrichment. "
            "Run: pip install yfinance"
        )
        df["name"] = ""
        return df

    from concurrent.futures import ThreadPoolExecutor, as_completed

    total = len(df)
    log.info("  Enriching %d symbols with company names (yfinance, threaded)...", total)

    name_map: dict[str, str] = {}
    done_count = 0

    def _lookup(symbol: str) -> tuple[str, str]:
        try:
            info = yf.Ticker(symbol).info
            return symbol, info.get("longName") or info.get("shortName") or ""
        except Exception:
            return symbol, ""

    with ThreadPoolExecutor(max_workers=10) as pool:
        futures = {pool.submit(_lookup, s): s for s in df["symbol"]}
        for future in as_completed(futures):
            sym, name = future.result()
            name_map[sym] = name
            done_count += 1
            if done_count % 50 == 0 or done_count == total:
                log.info("    ... %d/%d done", done_count, total)

    df["name"] = df["symbol"].map(name_map).fillna("")
    found = sum(1 for v in name_map.values() if v)
    log.info("  Enriched %d/%d symbols with names.", found, total)
    return df


# ---------------------------------------------------------------------------
# Extract & Save
# ---------------------------------------------------------------------------


def extract_ticker_data(raw_symbols: list[dict]) -> pd.DataFrame:
    """Extract 'symbol' from batch-exchange-quote response."""
    records = [{"symbol": item.get("symbol", "")} for item in raw_symbols]
    df = pd.DataFrame(records, columns=["symbol"])
    df = df[df["symbol"].str.strip().astype(bool)].reset_index(drop=True)
    return df


def save_csv(df: pd.DataFrame, label: str) -> Path:
    filepath = OUTPUT_DIR / f"{label}_tickers.csv"
    df.to_csv(filepath, index=False, encoding="utf-8-sig")
    log.info("  Saved %d rows -> %s", len(df), filepath)
    return filepath


def save_to_sqlite(frames: dict[str, pd.DataFrame]) -> None:
    conn = sqlite3.connect(SQLITE_DB)
    try:
        combined = []
        for label, df in frames.items():
            table_name = f"{label}_tickers"
            df.to_sql(table_name, conn, if_exists="replace", index=False)
            log.info("  SQLite table '%s' -> %d rows", table_name, len(df))

            tagged = df.copy()
            tagged.insert(0, "exchange", label)
            combined.append(tagged)

        if combined:
            all_df = pd.concat(combined, ignore_index=True)
            all_df.to_sql("all_tickers", conn, if_exists="replace", index=False)
            log.info("  SQLite table 'all_tickers' -> %d rows", len(all_df))
    finally:
        conn.close()

    log.info("  Database saved -> %s", SQLITE_DB)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    if API_KEY == "YOUR_API_KEY":
        log.warning(
            "No API key set. Export FMP_API_KEY or edit the script."
        )

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    log.info("=" * 60)
    log.info("FMP Ticker Fetcher v2 — %d exchanges", len(EXCHANGES))
    log.info("Output directory: %s", OUTPUT_DIR)
    log.info("=" * 60)

    frames: dict[str, pd.DataFrame] = {}
    api_calls = 0

    for label, fmp_code in EXCHANGES.items():
        log.info("[%s] Fetching symbols (FMP code: %s)...", label, fmp_code)
        raw = fetch_exchange_symbols(fmp_code)
        api_calls += 1

        if not raw:
            log.warning("[%s] No data returned — skipping.", label)
            continue

        df = extract_ticker_data(raw)
        log.info("[%s] Extracted %d tickers.", label, len(df))

        # Enrich with company names (free via yfinance)
        if ENRICH_NAMES:
            df = enrich_with_names(df)

        save_csv(df, label)
        frames[label] = df

    # Persist to SQLite
    if frames:
        save_to_sqlite(frames)

    # Summary
    log.info("=" * 60)
    log.info("DONE — FMP API calls used: %d  (out of 250/day limit)", api_calls)
    for label, df in frames.items():
        log.info("  %-4s : %5d tickers", label, len(df))
    if not frames:
        log.warning("No data was fetched. Check your API key and network.")
    log.info("=" * 60)


if __name__ == "__main__":
    main()
