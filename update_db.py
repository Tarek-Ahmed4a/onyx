import sqlite3
import pandas as pd
from pathlib import Path

def update_sqlite_db():
    output_dir = Path("ticker_data")
    db_path = output_dir / "tickers.db"
    
    # Define exchanges and categories
    categories = ["tickers", "funds"]
    exchanges = ["EGX", "KSA", "DFM", "ADX", "NASDAQDUBAI", "UAE"] 
    
    conn = sqlite3.connect(db_path)
    
    all_tickers_list = []
    all_funds_list = []
    
    print("Updating SQLite database...")
    
    # 1. Process individual tables
    for cat in categories:
        for ex in exchanges:
            filename = f"{ex}_{cat}.csv"
            csv_path = output_dir / filename
            
            if csv_path.exists():
                df = pd.read_csv(csv_path)
                # 2. Append suffixes to funds for regional mapping in the app
                if cat == "funds":
                    suffix_map = {
                        "EGX": ".CA",
                        "KSA": ".SR",
                        "DFM": ".DU",
                        "ADX": ".AD",
                        "UAE": ".DU" # Default UAE to DFM suffix
                    }
                    if ex in suffix_map:
                        df['symbol'] = df['symbol'].apply(lambda x: f"{x}{suffix_map[ex]}" if not str(x).endswith(suffix_map[ex]) else x)

                table_name = f"{ex}_{cat}".lower()
                df.to_sql(table_name, conn, if_exists="replace", index=False)
                print(f"  Updated table '{table_name}' with {len(df)} rows.")
                
                if cat == "tickers":
                    all_tickers_list.append(df)
                else:
                    all_funds_list.append(df)
            
    # 2. Create Master Tables dynamically
    if all_tickers_list:
        master_tickers = pd.concat(all_tickers_list).drop_duplicates(subset=["symbol"])
        master_tickers.to_sql("all_tickers", conn, if_exists="replace", index=False)
        master_tickers.to_csv(output_dir / "all_tickers.csv", index=False)
        print(f"  [SUCCESS] Created master table 'all_tickers' with {len(master_tickers)} total rows.")
        
    if all_funds_list:
        master_funds = pd.concat(all_funds_list).drop_duplicates(subset=["symbol"])
        master_funds.to_sql("all_funds", conn, if_exists="replace", index=False)
        master_funds.to_csv(output_dir / "all_funds.csv", index=False)
        print(f"  [SUCCESS] Created master table 'all_funds' with {len(master_funds)} total rows.")

    conn.close()
    print("Database sync complete.")

if __name__ == "__main__":
    update_sqlite_db()
