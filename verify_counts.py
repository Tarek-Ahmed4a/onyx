import sqlite3
import os

db_path = r"d:\tt\ticker_data\tickers.db"
if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute("SELECT count(*) FROM all_tickers")
    tickers_count = cursor.fetchone()[0]
    
    cursor.execute("SELECT count(*) FROM all_funds")
    funds_count = cursor.fetchone()[0]
    
    print(f"Total Tickers in DB: {tickers_count}")
    print(f"Total Funds in DB: {funds_count}")
    
    # Check some samples
    cursor.execute("SELECT symbol FROM all_tickers LIMIT 5")
    print(f"Sample Tickers: {cursor.fetchall()}")
    
    conn.close()
else:
    print("DB not found")
