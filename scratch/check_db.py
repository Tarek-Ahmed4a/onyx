import sqlite3
import os

db_path = "ticker_data/tickers.db"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()
cursor.execute("PRAGMA table_info(all_tickers)")
print("Columns:", [c[1] for c in cursor.fetchall()])
cursor.execute("SELECT * FROM all_tickers LIMIT 10")
rows = cursor.fetchall()
for row in rows:
    print(row)
conn.close()
