import requests
import pandas as pd
import json
import os
from pathlib import Path

def fetch_egypt_stocks_tradingview():
    url = "https://scanner.tradingview.com/egypt/scan"
    
    payload = {
        "filter": [{"left": "name", "operation": "nempty"}],
        "options": {"lang": "en"},
        "markets": ["egypt"],
        "symbols": {"query": {"types": []}, "tickers": []},
        "columns": ["name", "description", "logoid", "update_mode", "type", "typespecs", "exchange"],
        "sort": {"sortBy": "name", "sortOrder": "asc"},
        "range": [0, 1000]
    }
    
    headers = {
        "Content-Type": "application/json"
    }
    
    print("Fetching Egyptian stocks from TradingView...")
    response = requests.post(url, json=payload, headers=headers)
    
    if response.status_code != 200:
        print(f"Error: {response.status_code}")
        print(response.text)
        return None
    
    data = response.json()
    rows = data.get("data", [])
    
    stocks = []
    for row in rows:
        # row["d"] contains the columns in order: [name, description, logoid, ...]
        symbol = row["d"][0]
        name = row["d"][1]
        stocks.append({
            "symbol": f"{symbol}.CA",
            "name": name
        })
    
    df = pd.DataFrame(stocks)
    print(f"Successfully fetched {len(df)} stocks.")
    return df

if __name__ == "__main__":
    df = fetch_egypt_stocks_tradingview()
    if df is not None:
        output_dir = Path("ticker_data")
        output_dir.mkdir(exist_ok=True)
        
        output_path = output_dir / "EGX_tickers.csv"
        df.to_csv(output_path, index=False, encoding="utf-8-sig")
        print(f"Saved to {output_path}")
        
        # Also show the first few
        print("\nFirst 10 stocks (formatted for EGX):")
        print(df.head(10))
