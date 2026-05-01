import sqlite3
import sys

# Reconfigure stdout to use UTF-8 encoding
sys.stdout.reconfigure(encoding='utf-8')

try:
    conn = sqlite3.connect('ticker_data/tickers.db')
    cursor = conn.cursor()
    cursor.execute("SELECT symbol, name FROM all_funds")
    all_funds = cursor.fetchall()
    
    # Check if there are any non-EGX funds
    non_egx = [f for f in all_funds if ".SR" in f[0] or ".AD" in f[0] or ".DU" in f[0]]
    print(f"Total funds: {len(all_funds)}")
    print(f"Non-EGX funds: {len(non_egx)}")
    for f in non_egx[:5]:
        print(f)
except Exception as e:
    print(f"Error: {e}")
