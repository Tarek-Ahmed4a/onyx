import requests
import pandas as pd
import json
from pathlib import Path

def fetch_uae_stocks():
    url = "https://scanner.tradingview.com/uae/scan"
    
    payload = {
        "filter": [
            {"left": "type", "operation": "in_range", "right": ["stock", "dr", "fund"]}
        ],
        "options": {"lang": "en"},
        "markets": ["uae"],
        "symbols": {"query": {"types": []}, "tickers": []},
        "columns": ["name", "description", "exchange"],
        "sort": {"sortBy": "name", "sortOrder": "asc"},
        "range": [0, 500]
    }
    
    headers = {
        "Content-Type": "application/json"
    }
    
    print("Fetching UAE stocks from TradingView...")
    response = requests.post(url, json=payload, headers=headers)
    
    if response.status_code != 200:
        print(f"Error: {response.status_code}")
        return None
    
    data = response.json()
    rows = data.get("data", [])
    
    stocks = []
    for row in rows:
        symbol = row["d"][0]
        name = row["d"][1]
        exchange = row["d"][2]
        stocks.append({
            "symbol": symbol,
            "name": name,
            "exchange": exchange
        })
    
    df = pd.DataFrame(stocks)
    print(f"Successfully fetched {len(df)} UAE stocks.")
    return df

if __name__ == "__main__":
    df = fetch_uae_stocks()
    if df is not None:
        output_dir = Path("ticker_data")
        output_dir.mkdir(exist_ok=True)
        
        # Split into DFM and ADX
        dfm_df = df[df["exchange"] == "DFM"][["symbol", "name"]]
        adx_df = df[df["exchange"] == "ADX"][["symbol", "name"]]
        nasdaq_df = df[df["exchange"] == "NASDAQDUBAI"][["symbol", "name"]]
        
        # Save to CSV
        dfm_df.to_csv(output_dir / "DFM_tickers.csv", index=False, encoding="utf-8-sig")
        adx_df.to_csv(output_dir / "ADX_tickers.csv", index=False, encoding="utf-8-sig")
        
        print(f"Saved {len(dfm_df)} stocks to DFM_tickers.csv")
        print(f"Saved {len(adx_df)} stocks to ADX_tickers.csv")
        
        if len(nasdaq_df) > 0:
            nasdaq_df.to_csv(output_dir / "NASDAQDUBAI_tickers.csv", index=False, encoding="utf-8-sig")
            print(f"Saved {len(nasdaq_df)} stocks to NASDAQDUBAI_tickers.csv")
