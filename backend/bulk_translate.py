import os
import json
import sqlite3
from deep_translator import GoogleTranslator
import time

def get_all_names():
    db_paths = [
        "ticker_data/tickers.db",
        "backend/tickers.db",
        "tickers.db"
    ]
    db_path = None
    for p in db_paths:
        if os.path.exists(p):
            db_path = p
            break
            
    if not db_path:
        print("Error: tickers.db not found")
        return []
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT symbol, name FROM all_tickers")
    tickers = cursor.fetchall()
    cursor.execute("SELECT symbol, name FROM all_funds")
    funds = cursor.fetchall()
    conn.close()
    return tickers + funds

def main():
    print("Fetching all names from DB...")
    items = get_all_names()
    print(f"Found {len(items)} items to translate.")
    
    translations = {}
    translator = GoogleTranslator(source='en', target='ar')
    
    # We'll use a small cache to avoid re-translating same words if any
    name_cache = {}
    
    for i, (symbol, name) in enumerate(items):
        if not name or name.strip() == "":
            continue
        try:
            if name in name_cache:
                ar_name = name_cache[name]
            else:
                ar_name = translator.translate(name)
                name_cache[name] = ar_name
                # Flush output
                print(f"[{i+1}/{len(items)}] Translating: {symbol}", flush=True)
            
            translations[symbol] = ar_name
        except Exception as e:
            print(f"Error translating {symbol}: {e}", flush=True)
            
        # Save progress every 20 items
        if (i + 1) % 20 == 0:
            output_path = "backend/ticker_translations.json"
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            with open(output_path, "w", encoding="utf-8") as f:
                json.dump(translations, f, ensure_ascii=False, indent=4)
            print(f"--- Saved progress ({len(translations)} items) ---", flush=True)
            time.sleep(2)
        elif (i + 1) % 5 == 0:
            time.sleep(0.5)
    
    output_path = "backend/ticker_translations.json"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(translations, f, ensure_ascii=False, indent=4)
    
    print(f"Success! Saved {len(translations)} translations to {output_path}")

if __name__ == "__main__":
    main()
