import requests
from bs4 import BeautifulSoup
import pandas as pd
import os
from pathlib import Path

def fetch_egypt_stocks_investing():
    url = "https://sa.investing.com/equities/egypt"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }
    
    print("Fetching Egyptian stocks from Investing.com...")
    response = requests.get(url, headers=headers)
    
    if response.status_code != 200:
        print(f"Error: {response.status_code}")
        return None
    
    soup = BeautifulSoup(response.text, 'html.parser')
    
    # Investing.com table might be dynamic or static. 
    # Let's try to find the table with stocks.
    # Usually it's in a table with id 'cross_rate_markets_stocks_1' or similar
    table = soup.find('table', {'id': 'cross_rate_markets_stocks_1'})
    
    if not table:
        # Try finding any table with many rows
        tables = soup.find_all('table')
        for t in tables:
            if len(t.find_all('tr')) > 50:
                table = t
                break
    
    if not table:
        print("Could not find the stocks table.")
        return None
    
    stocks = []
    rows = table.find_all('tr')[1:] # Skip header
    for row in rows:
        cols = row.find_all('td')
        if len(cols) > 1:
            name_cell = cols[1]
            name = name_cell.text.strip()
            # Symbol is often in a link or a data attribute
            # Let's try to find it. Sometimes it's in a <a> tag href
            # Example: /equities/commercial-intl-bank
            # But the actual ticker might be in a different column or hidden.
            
            # In Investing.com, the ticker is sometimes visible in the 'Symbol' column if it exists.
            # Otherwise, we might have to settle for the name or look deeper.
            
            # Let's see if there's a symbol column
            # On sa.investing.com/equities/egypt, symbols are usually in the 2nd column alongside names or in a tooltip.
            
            stocks.append({
                "name": name,
                "investing_link": name_cell.find('a')['href'] if name_cell.find('a') else ""
            })
            
    df = pd.DataFrame(stocks)
    print(f"Successfully fetched {len(df)} stocks from Investing.com.")
    return df

if __name__ == "__main__":
    # Note: Investing.com is harder to scrape due to anti-bot.
    # This is a basic attempt.
    df = fetch_egypt_stocks_investing()
    if df is not None:
        output_dir = Path("ticker_data")
        output_dir.mkdir(exist_ok=True)
        output_path = output_dir / "EGX_investing_names.csv"
        df.to_csv(output_path, index=False, encoding="utf-8-sig")
        print(f"Saved to {output_path}")
