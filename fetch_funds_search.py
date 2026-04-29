import requests
import pandas as pd
from pathlib import Path

def search_symbols(query, country, search_type="fund"):
    url = "https://symbol-search.tradingview.com/symbol_search"
    params = {
        "text": query,
        "type": search_type,
        "country": country,
        "lang": "en"
    }
    
    response = requests.get(url, params=params)
    if response.status_code != 200:
        return []
    
    results = response.json()
    symbols = []
    for item in results:
        # Example item: {'symbol': 'EGX30ETF', 'description': 'EGX 30 Index ETF', 'type': 'fund', 'exchange': 'EGX', ...}
        symbols.append({
            "symbol": item.get("symbol"),
            "name": item.get("description"),
            "exchange": item.get("exchange"),
            "type": item.get("type"),
            "country": country
        })
    return symbols

def main():
    countries = ["EG", "SA", "AE", "QA"]
    queries = ["", "ETF", "Fund", "REIT"]
    
    all_results = []
    
    for country in countries:
        print(f"Searching for funds in {country}...")
        country_results = []
        for q in queries:
            results = search_symbols(q, country)
            for r in results:
                if r not in country_results:
                    country_results.append(r)
        
        print(f"  Found {len(country_results)} unique funds.")
        all_results.extend(country_results)

    if all_results:
        df = pd.DataFrame(all_results)
        # Format Egyptian symbols
        df.loc[df["country"] == "EG", "symbol"] = df.loc[df["country"] == "EG", "symbol"].apply(
            lambda x: f"{x}.CA" if not str(x).endswith(".CA") else x
        )
        
        output_dir = Path("ticker_data")
        output_dir.mkdir(exist_ok=True)
        df.to_csv(output_dir / "all_funds_search.csv", index=False, encoding="utf-8-sig")
        print(f"\nSaved total {len(df)} funds to all_funds_search.csv")

if __name__ == "__main__":
    main()
