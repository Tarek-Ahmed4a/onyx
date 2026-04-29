import requests
import pandas as pd
from pathlib import Path

def fetch_market_funds(market_name):
    url = f"https://scanner.tradingview.com/{market_name}/scan"
    
    payload = {
        "filter": [],
        "options": {"lang": "en"},
        "markets": [market_name],
        "symbols": {"query": {"types": []}, "tickers": []},
        "columns": ["name", "description", "exchange", "type", "typespecs"],
        "sort": {"sortBy": "name", "sortOrder": "asc"},
        "range": [0, 1000]
    }
    
    headers = {
        "Content-Type": "application/json"
    }
    
    print(f"Fetching data for {market_name}...")
    response = requests.post(url, json=payload, headers=headers)
    
    if response.status_code != 200:
        print(f"Error for {market_name}: {response.status_code}")
        return []
    
    data = response.json()
    rows = data.get("data", [])
    
    funds = []
    fund_keywords = {"fund", "etf", "reit", "trust", "index"}
    
    for row in rows:
        symbol = row["d"][0]
        name = row["d"][1]
        exchange = row["d"][2]
        item_type = str(row["d"][3]).lower()
        item_specs = [str(s).lower() for s in row["d"][4]] if row["d"][4] else []
        
        # Check if it's a fund based on type or typespecs
        is_fund = (item_type == "fund") or any(s in ["etf", "reit", "fund", "etn", "mutual"] for s in item_specs)
        
        # Fallback: check name/description for keywords if needed, 
        # but type/typespecs is usually reliable
        
        if is_fund:
            funds.append({
                "symbol": symbol,
                "name": name,
                "exchange": exchange,
                "type": item_type,
                "specs": ",".join(item_specs)
            })
    
    return funds

def main():
    markets = ["egypt", "ksa", "uae", "qatar"]
    output_dir = Path("ticker_data")
    output_dir.mkdir(exist_ok=True)
    
    all_funds = []
    
    for m in markets:
        funds = fetch_market_funds(m)
        if funds:
            df = pd.DataFrame(funds)
            # Add suffix for EGX if needed, but TradingView symbols usually fine.
            # However, for consistency with the user's previous requests:
            if m == "egypt":
                df["symbol"] = df["symbol"].apply(lambda x: f"{x}.CA" if not x.endswith(".CA") else x)
            
            filename = f"{m.upper()}_funds.csv"
            df.to_csv(output_dir / filename, index=False, encoding="utf-8-sig")
            print(f"  Saved {len(df)} funds to {filename}")
            
            df["market"] = m
            all_funds.append(df)
            
    if all_funds:
        combined_df = pd.concat(all_funds, ignore_index=True)
        combined_df.to_csv(output_dir / "all_funds.csv", index=False, encoding="utf-8-sig")
        print(f"\nSaved total {len(combined_df)} funds to all_funds.csv")

if __name__ == "__main__":
    main()
