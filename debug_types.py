import requests
import json

def debug_market_types(market_name):
    url = f"https://scanner.tradingview.com/{market_name}/scan"
    
    # Get everything to see types
    payload = {
        "filter": [],
        "options": {"lang": "en"},
        "markets": [market_name],
        "symbols": {"query": {"types": []}, "tickers": []},
        "columns": ["name", "type", "typespecs"],
        "range": [0, 1000]
    }
    
    response = requests.post(url, json=payload)
    data = response.json()
    rows = data.get("data", [])
    
    types = set()
    typespecs = set()
    for row in rows:
        name = row["d"][0]
        item_type = row["d"][1]
        item_specs = row["d"][2]
        types.add(item_type)
        if item_specs:
            for ts in item_specs:
                typespecs.add(ts)
        
        if item_type == "fund":
            print(f"  Fund Found: {name} (Specs: {item_specs})")
                
    print(f"Market: {market_name}")
    print(f"Types: {types}")
    print(f"Typespecs: {typespecs}")

if __name__ == "__main__":
    debug_market_types("ksa")
    debug_market_types("egypt")
