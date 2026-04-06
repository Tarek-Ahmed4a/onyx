from flask import Flask, request, jsonify, Response
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
import yfinance as yf
import pandas as pd
import os

import requests
from bs4 import BeautifulSoup
from apscheduler.schedulers.background import BackgroundScheduler
import random

# ─── Configuration & User-Agents ─────────────────────────────────────────────
USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Safari/605.1.15',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36'
]

def get_headers():
    return {'User-Agent': random.choice(USER_AGENTS)}

# Fix: Set initial User-Agent for yfinance
yf.utils.user_agent_headers = get_headers()

app = Flask(__name__)

# ─── Global Caching (Last Known Good Data) ────────────────────────────────────
# Stores: { "COMI.CA": { "price": 85.5, "rsi": 62.3, "macd": "Bullish..." }, ... }
LAST_KNOWN_GOOD_DATA = {}

# ─── Official EGX 30 Constituents ─────────────────────────────────────────────
EGX_30 = [
    'ABUK.CA', 'ADIB.CA', 'AMOC.CA', 'ARCC.CA', 'BTFH.CA',
    'CCAP.CA', 'COMI.CA', 'EAST.CA', 'EFID.CA', 'EFIH.CA',
    'EGAL.CA', 'EGCH.CA', 'EMFD.CA', 'ETEL.CA', 'FWRY.CA',
    'GBCO.CA', 'HELI.CA', 'HRHO.CA', 'ISPH.CA', 'JUFO.CA',
    'MCQE.CA', 'ORAS.CA', 'ORHD.CA', 'OIH.CA',  'ORWE.CA',
    'PHDC.CA', 'RAYA.CA', 'RMDA.CA', 'TMGH.CA', 'VLMR.CA'
]

# ─── Fallback Source Scraping ───────────────────────────────────────────────

def _scrape_mubasher():
    """Layer 3: Scrape Mubasher.info (Reliable Egyptian Source)."""
    try:
        url = "https://www.mubasher.info/markets/EGX/stocks"
        resp = requests.get(url, headers=get_headers(), timeout=10)
        if resp.status_code != 200: return {}
        
        soup = BeautifulSoup(resp.text, 'html.parser')
        rows = soup.select('table tbody tr')
        results = {}
        for row in rows:
            cols = row.find_all('td')
            if len(cols) >= 3:
                symbol = cols[0].text.strip()
                price_text = cols[2].text.strip().replace(',', '')
                change_text = cols[3].text.strip().replace('%', '')
                try:
                    results[f"{symbol}.CA"] = {
                        "price": float(price_text),
                        "change": float(change_text),
                        "source": "Mubasher"
                    }
                except: continue
        return results
    except Exception as e:
        print(f"❌ Mubasher Scrape Error: {e}")
        return {}

def _scrape_investing():
    """Layer 2: Scrape Investing.com (Global Fallback)."""
    try:
        url = "https://www.investing.com/equities/egypt"
        resp = requests.get(url, headers=get_headers(), timeout=10)
        if resp.status_code != 200: return {}
        
        soup = BeautifulSoup(resp.text, 'html.parser')
        # Selecting the stocks table (Structure depends on current page)
        rows = soup.select('table.genTbl.closedTbl tbody tr') or soup.find_all('tr')
        results = {}
        for row in rows:
            cols = row.find_all('td')
            if len(cols) >= 5:
                # Identifying by symbol if possible
                text = row.text.upper()
                for ticker in EGX_30:
                    symbol_only = ticker.split('.')[0]
                    if symbol_only in text:
                        try:
                            # Usually Price is col 2, Change % is col 5/6
                            price = float(cols[2].text.strip().replace(',', ''))
                            change = float(cols[6].text.strip().replace('%', '').replace('+', ''))
                            results[ticker] = {
                                "price": price,
                                "change": change,
                                "source": "Investing"
                            }
                        except: continue
        return results
    except Exception as e:
        print(f"❌ Investing Scrape Error: {e}")
        return {}

def calculate_rsi(series, period=14):
    delta = series.diff()
    gain = (delta.where(delta > 0, 0)).ewm(alpha=1/period, adjust=False).mean()
    loss = (-delta.where(delta < 0, 0)).ewm(alpha=1/period, adjust=False).mean()
    rs = gain / loss
    return 100 - (100 / (1 + rs))

def calculate_macd(series, fast=12, slow=26, signal=9):
    ema_fast = series.ewm(span=fast, adjust=False).mean()
    ema_slow = series.ewm(span=slow, adjust=False).mean()
    macd_line = ema_fast - ema_slow
    signal_line = macd_line.ewm(span=signal, adjust=False).mean()
    return macd_line, signal_line

def _fetch_single_ticker(ticker):
    """Layer 1: Fetch via yfinance with full technicals."""
    try:
        # Rotate UA for Layer 1
        yf.utils.user_agent_headers = get_headers()
        stock = yf.Ticker(ticker)
        df = stock.history(period="5d") # 5d to ensure we have enough for change + technicals

        if df.empty: return None

        close_prices = df['Close']
        latest_price = float(close_prices.iloc[-1])
        prev_price = float(close_prices.iloc[-2]) if len(close_prices) > 1 else latest_price
        change_pct = ((latest_price - prev_price) / prev_price) * 100

        # Technicals (RSI/MACD)
        rsi_series = calculate_rsi(close_prices, 14)
        rsi_val = rsi_series.iloc[-1] if not rsi_series.empty else 50.0
        
        macd_line, signal_line = calculate_macd(close_prices)
        macd_desc = "Not enough data"
        if not macd_line.empty and not signal_line.empty:
            m = macd_line.iloc[-1]
            s = signal_line.iloc[-1]
            if not pd.isna(m) and not pd.isna(s):
                macd_desc = "Bullish crossover" if m > s else "Bearish divergence"

        return {
            "price": round(latest_price, 2),
            "rsi": round(float(rsi_val), 2) if not pd.isna(rsi_val) else 50.0,
            "macd": macd_desc,
            "change": round(change_pct, 2),
            "source": "yfinance"
        }
    except Exception as e:
        print(f"⚠️ yfinance Failure for {ticker}: {e}")
        return None

# ─── Background Refresh Engine ──────────────────────────────────────────────

def refresh_all_market_data():
    """Multi-Layered Refresh Task."""
    print(f"🕒 [{datetime.now()}] Starting market data refresh...")
    
    # Pre-fetch fallbacks in batch
    investing_data = _scrape_investing()
    mubasher_data = _scrape_mubasher()
    
    new_data = {}
    
    with ThreadPoolExecutor(max_workers=10) as executor:
        future_to_ticker = {executor.submit(_fetch_single_ticker, t): t for t in EGX_30}
        for future in as_completed(future_to_ticker):
            ticker = future_to_ticker[future]
            try:
                # 1. Try yfinance
                result = future.result()
                
                if not result:
                    # 2. Try Investing
                    result = investing_data.get(ticker)
                
                if not result:
                    # 3. Try Mubasher
                    result = mubasher_data.get(ticker)
                
                if result:
                    # Merge with previous technicals if source is placeholder
                    prev = LAST_KNOWN_GOOD_DATA.get(ticker, {})
                    data = {
                        "price": result.get("price", prev.get("price", 0.0)),
                        "rsi": result.get("rsi", prev.get("rsi", 50.0)),
                        "macd": result.get("macd", prev.get("macd", "Neutral")),
                        "change": result.get("change", prev.get("change", 0.0)),
                        "source": result.get("source", "Unknown")
                    }
                    new_data[ticker] = data
                    LAST_KNOWN_GOOD_DATA[ticker] = data
                else:
                    # 4. Ultimate Cache Fallback
                    if ticker in LAST_KNOWN_GOOD_DATA:
                        new_data[ticker] = LAST_KNOWN_GOOD_DATA[ticker]
            except Exception as e:
                print(f"❌ Error refreshing {ticker}: {e}")

    print(f"✅ Refresh complete. Updated {len(new_data)} tickers.")

# Initialize Scheduler
scheduler = BackgroundScheduler()
scheduler.add_job(func=refresh_all_market_data, trigger="interval", seconds=120)
scheduler.start()

@app.route('/api/egx/all', methods=['GET'])
def get_all_egx_data():
    """Batch endpoint: returns data from cached global state."""
    # If cache is empty, try an immediate refresh
    if not LAST_KNOWN_GOOD_DATA:
        refresh_all_market_data()
        
    return jsonify({
        "stocks": LAST_KNOWN_GOOD_DATA,
        "last_updated": datetime.utcnow().isoformat()
    })

@app.route('/api/egx', methods=['GET'])
def get_egx_data():
    ticker = request.args.get('ticker')
    if not ticker:
        return jsonify({"error": "Missing ticker parameter"}), 400

    # Try cache first
    result = LAST_KNOWN_GOOD_DATA.get(ticker)
    if not result:
        result = _fetch_single_ticker(ticker)

    if result is None:
        return jsonify({"error": "No data found for ticker"}), 404

    context_string = f"[SYSTEM CONTEXT] ASSET: {ticker} | LIVE PRICE: {result['price']:.2f} | CHANGE: {result.get('change', 0.0):.2f}% | TECHNICALS: RSI = {result['rsi']:.2f}, MACD = {result['macd']} [END CONTEXT]"
    return Response(context_string, content_type='text/plain; charset=utf-8', status=200)

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(debug=True, host='0.0.0.0', port=port)
