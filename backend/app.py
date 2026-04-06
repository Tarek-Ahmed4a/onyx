import os
from flask import Flask, request, jsonify, Response
from flask_cors import CORS
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
import yfinance as yf
import pandas as pd
import requests
from bs4 import BeautifulSoup
from apscheduler.schedulers.background import BackgroundScheduler
import random
import math
from collections import deque

# --- Configuration ---
USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36'
]

def get_headers():
    return {'User-Agent': random.choice(USER_AGENTS)}

app = Flask(__name__)
CORS(app)

EGX_30 = [
    'ABUK.CA', 'ADIB.CA', 'AMOC.CA', 'ARCC.CA', 'BTFH.CA',
    'CCAP.CA', 'COMI.CA', 'EAST.CA', 'EFID.CA', 'EFIH.CA',
    'EGAL.CA', 'EGCH.CA', 'EMFD.CA', 'ETEL.CA', 'FWRY.CA',
    'GBCO.CA', 'HELI.CA', 'HRHO.CA', 'ISPH.CA', 'JUFO.CA',
    'MCQE.CA', 'ORAS.CA', 'ORHD.CA', 'OIH.CA',  'ORWE.CA',
    'PHDC.CA', 'RAYA.CA', 'RMDA.CA', 'TMGH.CA', 'VLMR.CA'
]

# Initialize Storage with Deques for each ticker (maxlen 100 for 1-minute accumulation)
MARKET_DATA_CACHE = {
    ticker: {
        "price": 0.0,
        "rsi": 50.0,
        "macd": "Neutral",
        "source": "Initializing",
        "deque": deque(maxlen=100)
    }
    for ticker in EGX_30
}

# --- Technicals ---
def calculate_rsi(series, period=14):
    if len(series) < period: return 50.0
    delta = series.diff()
    gain = (delta.where(delta > 0, 0)).ewm(alpha=1/period, adjust=False).mean()
    loss = (-delta.where(delta < 0, 0)).ewm(alpha=1/period, adjust=False).mean()
    rs = gain / loss
    rsi = 100 - (100 / (1 + rs))
    return float(rsi.iloc[-1])

def calculate_macd(series, fast=12, slow=26, signal=9):
    if len(series) < slow: return "Neutral"
    ema_fast = series.ewm(span=fast, adjust=False).mean()
    ema_slow = series.ewm(span=slow, adjust=False).mean()
    macd_line = ema_fast - ema_slow
    signal_line = macd_line.ewm(span=signal, adjust=False).mean()
    m, s = macd_line.iloc[-1], signal_line.iloc[-1]
    return "Bullish crossover" if m > s else "Bearish divergence"

# --- Scrapers ---
def _fetch_mubasher_price(ticker):
    try:
        symbol = ticker.split('.')[0]
        url = f"https://www.mubasher.info/markets/EGX/stocks/{symbol}"
        resp = requests.get(url, headers=get_headers(), timeout=5) # Reduced timeout
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, 'lxml')
            price_tag = soup.select_one('.market-summary__last-price')
            if price_tag:
                return float(price_tag.text.strip().replace(',', ''))
    except Exception as e:
        print(f"Mubasher Error {ticker}: {e}")
    return None

# --- Data Engine ---
def _fetch_single_ticker_aggressive(ticker):
    """Accumulates live prices into the deque and recalculates technicals."""
    try:
        data = MARKET_DATA_CACHE.get(ticker)
        if not data: return None
        
        # 1. Primary Live Price (Mubasher)
        live_price = _fetch_mubasher_price(ticker)
        
        # 2. History Bootstrap (Only if deque is empty)
        history_dq = data["deque"]
        source = "Mubasher (Live Accumulation)"
        
        if len(history_dq) < 40:
            # Attempt one-time bootstrap from yfinance
            try:
                stock = yf.Ticker(ticker)
                df = stock.history(period="1mo", timeout=3)
                if not df.empty:
                    # Fill deque with historical points
                    history_dq.clear()
                    for p in df['Close'].tolist():
                        history_dq.append(p)
                    source = "Hybrid (yf Bootstrap + Live)"
            except: pass
            
            # If still empty or yf failed, seed with dummy history
            if len(history_dq) < 40 and live_price:
                history_dq.clear()
                for _ in range(40):
                    history_dq.append(live_price)
                source = "Mubasher (Dummy Seed)"

        # 3. Append latest point
        if live_price:
            history_dq.append(live_price)
            data["price"] = round(float(live_price), 2)
        
        # 4. Technical Recalculation on the Deque
        if len(history_dq) >= 14:
            history_series = pd.Series(list(history_dq))
            data["rsi"] = round(calculate_rsi(history_series), 2)
            data["macd"] = calculate_macd(history_series)
            
            # Ensure RSI is finite
            if not math.isfinite(data["rsi"]): data["rsi"] = 50.0
        
        data["source"] = source
        return data

    except Exception as e:
        print(f"Engine fail {ticker}: {e}")
        return None

def refresh_market_data():
    print(f"🕒 Refreshing 30 tickers (Live Accumulation)...")
    with ThreadPoolExecutor(max_workers=30) as executor:
        futures = {executor.submit(_fetch_single_ticker_aggressive, t): t for t in EGX_30}
        for f in as_completed(futures):
            # The function updates MARKET_DATA_CACHE[ticker] directly
            f.result() 
    print(f"✅ Market state synchronized.")

scheduler = BackgroundScheduler()
scheduler.add_job(func=refresh_market_data, trigger="interval", seconds=60)
scheduler.start()

@app.route('/api/egx/all')
def get_all():
    # If the app just started and cache is empty of prices, force one refresh
    all_zero = all(v['price'] == 0.0 for v in MARKET_DATA_CACHE.values())
    if all_zero: refresh_market_data()
    
    # Safe JSON sanitization: prevent NaN or Infinity from breaking JSON spec
    safe_stocks = {}
    for k, v in MARKET_DATA_CACHE.items():
        # Mask out the deque object from JSON response
        stock_data = {
            "price": v["price"],
            "rsi": v["rsi"],
            "macd": v["macd"],
            "source": v["source"]
        }
        # Final pass: check for any accidental NaN values
        if not math.isfinite(stock_data['rsi']): stock_data['rsi'] = 50.0
        if not math.isfinite(stock_data['price']): stock_data['price'] = 0.0
        safe_stocks[k] = stock_data
        
    return jsonify({
        "stocks": safe_stocks,
        "last_updated": datetime.utcnow().isoformat()
    })

@app.route('/force_sync')
def force():
    refresh_market_data()
    return jsonify({"status": "done", "count": len(MARKET_DATA_CACHE)})

if __name__ == '__main__':
    refresh_market_data()
    app.run(debug=False, host='0.0.0.0', port=int(os.environ.get('PORT', 7860)))