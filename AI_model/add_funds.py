import yfinance as yf
import sqlite3
import os

def find_extra_funds():
    db_path = "ticker_data/tickers.db"
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Common ETF/Fund suffixes or prefixes
    markets = {
        "EGX": ".CA",
        "KSA": ".SR",
        "UAE": ".AE"
    }
    
    # We will manually add some known ones if not found, 
    # but yfinance search is better
    
    extra_egx = ["EGX30ETF.CA", "AZ-GOLD.CA"]
    for s in extra_egx:
        cursor.execute("INSERT OR IGNORE INTO egx_tickers (symbol, name) VALUES (?, ?)", (s, s.split('.')[0] + " Fund"))
        
    conn.commit()
    conn.close()
    print("Added known Egyptian funds.")

if __name__ == "__main__":
    find_extra_funds()
