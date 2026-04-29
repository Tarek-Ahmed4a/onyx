import os
from flask import Flask, request, jsonify, Response
from flask_cors import CORS
from flask_socketio import SocketIO, emit
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
from datetime import timedelta
import json
import firebase_admin
from firebase_admin import credentials, firestore, messaging
import time
try:
    from tvDatafeed import TvDatafeed, Interval
    HAS_TV = True
except ImportError:
    print("⚠️ tvDatafeed not installed. TradingView fallback will be disabled.")
    HAS_TV = False
    
import logging

# Mute noisy logs
logging.getLogger('tvDatafeed').setLevel(logging.ERROR)


# --- Configuration ---
USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36'
]

def get_headers():
    return {'User-Agent': random.choice(USER_AGENTS)}

app = Flask(__name__)
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='eventlet')

import sqlite3

def load_all_symbols():
    # Try multiple possible locations for the DB
    possible_paths = [
        os.path.join(os.path.dirname(__file__), "tickers.db"),
        os.path.join(os.path.dirname(__file__), "..", "tickers.db"),
        os.path.join(os.path.dirname(__file__), "ticker_data", "tickers.db"),
        os.path.join(os.path.dirname(__file__), "..", "ticker_data", "tickers.db"),
        "tickers.db"
    ]
    
    db_path = None
    for p in possible_paths:
        if os.path.exists(p):
            db_path = p
            break

    tickers = []
    funds = []
    
    if not db_path:
        print(f"⚠️ Warning: tickers.db not found in any of {possible_paths}. Using default empty watchlist.")
        return [], []
        
    print(f"📂 Using database at: {db_path}")
    ticker_names = {}
    try:
        conn = sqlite3.connect(db_path)
        # Load all tickers with names
        df_tickers = pd.read_sql("SELECT symbol, name FROM all_tickers", conn)
        for _, row in df_tickers.iterrows():
            ticker_names[row['symbol']] = row['name']
        
        # Load all funds with names
        df_funds = pd.read_sql("SELECT symbol, name FROM all_funds", conn)
        for _, row in df_funds.iterrows():
            ticker_names[row['symbol']] = row['name']
        
        tickers = df_tickers['symbol'].tolist()
        funds = df_funds['symbol'].tolist()
        
        conn.close()
        print(f"✅ [SUCCESS] Loaded {len(tickers)} tickers and {len(funds)} funds with names.")
    except Exception as e:
        print(f"❌ [ERROR] Database loading failed: {e}")
        tickers, funds = [], []
        
    return tickers, funds, ticker_names

ALL_TICKERS, ALL_FUNDS, TICKER_NAMES_MAP = load_all_symbols()

WATCHLIST = list(set(ALL_TICKERS + ALL_FUNDS))
MUTUAL_FUNDS = ALL_FUNDS

# --- Global Cache Buffers ---
MUBASHER_FUNDS_BUFFER = {}
MUBASHER_FUNDS_LAST_FETCH = None

# Initialize Storage with Deques for each ticker (maxlen 100 for 1-minute accumulation)
MARKET_DATA_CACHE = {
    ticker: {
        "price": 0.0,
        "rsi": 50.0,
        "macd": "Neutral",
        "support": 0.0,
        "resistance": 0.0,
        "source": "Initializing",
        "name": TICKER_NAMES_MAP.get(ticker, ticker),
        "deque": deque(maxlen=100)
    }
    for ticker in WATCHLIST
}

# --- Global Clients ---
db = None
tv_client = None

def get_tv_client():
    global tv_client
    if not HAS_TV: return None
    if tv_client is None:
        try:
            tv_client = TvDatafeed()
        except Exception as e:
            print(f"⚠️ Failed to init TvDatafeed: {e}")
    return tv_client

# --- State Persistence Logic ---

def _save_market_state_to_firestore():
    """Saves the current deques (history) to Firestore to persist across restarts."""
    try:
        state_data = {}
        for ticker, data in MARKET_DATA_CACHE.items():
            dq = data.get("deque")
            if dq and len(dq) > 0:
                state_data[ticker] = list(dq)
        
        if state_data:
            db.collection('system_metadata').document('market_state').set({
                "tickers": state_data,
                "last_updated": datetime.utcnow()
            })
            print(f"💾 Market state persisted to Firestore ({len(state_data)} tickers).")
    except Exception as e:
        print(f"❌ Failed to save market state: {e}")

def _load_market_state_from_firestore():
    """Loads persisted deques from Firestore if they are less than 24 hours old."""
    global db
    try:
        if db is None:
            print("⚠️ Firestore client (db) is not initialized yet.")
            return False
        doc = db.collection('system_metadata').document('market_state').get()
        if doc.exists:
            data = doc.to_dict()
            last_updated = data.get("last_updated")
            
            if last_updated:
                delta = datetime.utcnow() - last_updated.replace(tzinfo=None)
                if delta < timedelta(hours=24):
                    tickers_state = data.get("tickers", {})
                    count = 0
                    for ticker, history in tickers_state.items():
                        if ticker in MARKET_DATA_CACHE:
                            MARKET_DATA_CACHE[ticker]["deque"].clear()
                            for p in history:
                                MARKET_DATA_CACHE[ticker]["deque"].append(float(p))
                            # Update current price to last known history point if still zero
                            if MARKET_DATA_CACHE[ticker]["price"] == 0 and history:
                                MARKET_DATA_CACHE[ticker]["price"] = float(history[-1])
                            count += 1
                            # Recalculate indicators immediately after loading history
                            _recalculate_technicals(ticker)
                    print(f"📂 Loaded market state from Firestore ({count} tickers). Freshness: {delta}")
                    return True
                else:
                    print(f"⏳ Persisted market state is too old ({delta}). Skipping.")
        else:
            print("ℹ️ No market state found in Firestore.")
    except Exception as e:
        print(f"⚠️ Failed to load market state: {e}")
    return False

# --- Technical Indicators ---

NEWS_CACHE = []
MACRO_CACHE = {
    "egx100": 0.0,
    "usd_egp": 0.0,
    "gold": 0.0,
    "last_updated": ""
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
    EMA_fast = series.ewm(span=fast, adjust=False).mean()
    EMA_slow = series.ewm(span=slow, adjust=False).mean()
    MACD_line = EMA_fast - EMA_slow
    Signal_line = MACD_line.ewm(span=signal, adjust=False).mean()
    m, s = MACD_line.iloc[-1], Signal_line.iloc[-1]
    if m > s + 0.0001:
        return "Bullish crossover"
    elif m < s - 0.0001:
        return "Bearish divergence"
    else:
        return "Neutral"

# --- Scrapers ---
def _fetch_mubasher_price(ticker):
    try:
        url = f"https://www.mubasher.info/markets/EGX/stocks/{ticker.split('.')[0]}"
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        }
        resp = requests.get(url, headers=headers, timeout=15)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, 'lxml')
            price_tag = soup.select_one('.market-summary__last-price')
            if price_tag:
                return float(price_tag.text.strip().replace(',', ''))
    except Exception as e:
        print(f"Mubasher Error {ticker}: {e}")
    return None

def _fetch_mubasher_news():
    """Scrapes latest EGX headlines from Mubasher."""
    try:
        url = "https://www.mubasher.info/markets/EGX/news"
        resp = requests.get(url, headers=get_headers(), timeout=10)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, 'lxml')
            news_tags = soup.select('.news-list__item-title')
            headlines = [t.text.strip() for t in news_tags[:10]] # Top 10
            return headlines
    except Exception as e:
        print(f"News Fetch Error: {e}")
    return []

def get_stock_news_mubasher(ticker_symbol, limit=3):
    url = f"https://www.mubasher.info/markets/EGX/stocks/{ticker_symbol.upper()}/news"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8'
    }
    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, 'html.parser')
        
        news_items = []
        articles = soup.find_all('div', class_='md:w-2/3')
        
        for article in articles:
            if len(news_items) >= limit:
                break
            title_tag = article.find('a')
            if title_tag:
                title = title_tag.get_text(strip=True)
                time_tag = article.find('time')
                date = time_tag.get_text(strip=True) if time_tag else "Recent"
                news_items.append(f"[{date}] {title}")
                
        if not news_items:
            return ["لا توجد أخبار حديثة لهذا السهم"]
        return news_items
    except Exception as e:
        print(f"[Scraping Error] {ticker_symbol}: {e}")
        return ["السعر اللحظي متوفر لكن الأخبار غير متاحة حالياً"]

def get_macro_news_enterprise(limit=3):
    url = "https://enterprise.press/arabic/"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8'
    }
    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, 'html.parser')
        
        macro_news = []
        headlines = soup.find_all(['h2', 'h3'])
        
        for item in headlines:
            text = item.get_text(strip=True)
            if len(text) > 25 and not any(text in news for news in macro_news):
                macro_news.append(f"[اقتصاد عام] {text}")
            if len(macro_news) >= limit:
                break
        return macro_news if macro_news else []
    except Exception as e:
        print(f"[Enterprise Error]: {e}")
        return []

def _fetch_macro_indicators():
    """Fetches USD/EGP, Gold, and EGX100 via yfinance with robust Scraper Fallbacks."""
    global MACRO_CACHE
    try:
        tickers = ["CASE100.CA", "EGP=X", "GC=F"]
        data = yf.download(tickers, period="5d", interval="1d", progress=False, timeout=15)
        
        if not data.empty and 'Close' in data:
            closes = data['Close'].iloc[-1]
            def get_val(ticker, default=0.0):
                try:
                    val = closes[ticker]
                    return float(val) if math.isfinite(val) else default
                except: return default

            MACRO_CACHE = {
                "egx100": round(get_val("CASE100.CA"), 2),
                "usd_egp": round(get_val("EGP=X"), 2),
                "gold": round(get_val("GC=F"), 2),
                "last_updated": datetime.utcnow().isoformat()
            }
        else:
            raise ValueError("yfinance empty result")
            
    except Exception as e:
        # --- Fallback 1: TradingView (TvDatafeed) ---
        print(f"🕒 yfinance Macro failed ({e}). Trying TradingView...")
        try:
            tv = get_tv_client()
            if tv:
                # TradingView symbols
                egx = tv.get_hist(symbol='CASE100', exchange='EGX', interval=Interval.in_daily, n_bars=2)
                gold = tv.get_hist(symbol='GOLD', exchange='TVC', interval=Interval.in_daily, n_bars=2)
                usd = tv.get_hist(symbol='USDEGP', exchange='FX_IDC', interval=Interval.in_daily, n_bars=2)
                
                MACRO_CACHE = {
                    "egx100": round(egx['close'].iloc[-1], 2) if egx is not None else MACRO_CACHE['egx100'],
                    "usd_egp": round(usd['close'].iloc[-1], 2) if usd is not None else MACRO_CACHE['usd_egp'],
                    "gold": round(gold['close'].iloc[-1], 2) if gold is not None else MACRO_CACHE['gold'],
                    "last_updated": datetime.utcnow().isoformat()
                }
                print(f"🌍 Macro Indicators (TV): {MACRO_CACHE}")
                return
        except Exception as e2:
            print(f"TradingView Macro error: {e2}")

        # --- Fallback 2: Scrapers ---
        print("🕒 Attempting Scraper Fallbacks...")
        try:
            headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'}
            # 1. USD/EGP Scraper
            usd_price = 48.50 
            resp = requests.get("https://www.mubasher.info/markets/currencies/USD/EGP", headers=headers, timeout=15)
            if resp.status_code == 200:
                soup = BeautifulSoup(resp.text, 'lxml')
                price_tag = soup.select_one('.market-summary__last-price')
                if price_tag: usd_price = float(price_tag.text.strip().replace(',', ''))
            
            # 2. Gold Scraper
            gold_price = 3200.0
            resp = requests.get("https://www.mubasher.info/markets/commodities/GOLD", headers=headers, timeout=15)
            if resp.status_code == 200:
                soup = BeautifulSoup(resp.text, 'lxml')
                price_tag = soup.select_one('.market-summary__last-price')
                if price_tag: gold_price = float(price_tag.text.strip().replace(',', ''))

            # 3. EGX100 Scraper
            egx_val = 10000.0
            resp = requests.get("https://www.mubasher.info/markets/EGX/indices/CASE100", headers=headers, timeout=15)
            if resp.status_code == 200:
                soup = BeautifulSoup(resp.text, 'lxml')
                price_tag = soup.select_one('.market-summary__last-price')
                if price_tag: egx_val = float(price_tag.text.strip().replace(',', ''))

            MACRO_CACHE = {
                "egx100": egx_val,
                "usd_egp": usd_price,
                "gold": gold_price,
                "last_updated": datetime.utcnow().isoformat()
            }
            print(f"🌍 Macro Indicators (Scraped): {MACRO_CACHE}")
        except Exception as e2:
            print(f"Total Macro Failure: {e2}")

def _calculate_market_breadth():
    """Calculates Gainers vs Losers for the AI to understand market tone."""
    gainers = 0
    losers = 0
    neutral = 0
    
    for ticker, data in MARKET_DATA_CACHE.items():
        if ticker in MUTUAL_FUNDS: continue # Focus on stocks
        
        change = data.get('change', 0.0)
        if change > 0.5:
            gainers += 1
        elif change < -0.5:
            losers += 1
        else:
            neutral += 1
            
    total = gainers + losers + neutral
    if total == 0: return "Neutral / No Data"
    
    sentiment = "Strongly Bullish" if gainers > (losers * 2) else "Strongly Bearish" if losers > (gainers * 2) else "Mixed / Sideways"
    return f"{sentiment} (Gainers: {gainers}, Losers: {losers}, Neutral: {neutral})"

FUND_KEYWORDS = {
    'ADA': 'صندوق استثمار شركة الأهلي لإدارة الإستثمارات المالية وايفولف للاستثمار في الذهب',
    'BSB': 'صندوق استثمار بلتون ايفولف للاستثمار في الذهب - سبائك',
    'BFA': 'صندوق استثمار بلتون - إيفولف للاستثمار في الفضة - فضة',
    'BWA': 'صندوق بلتون متعدد الإصدارات للاستثمار في أسهم مؤشر الشريعة EGX33 - الإصدار الأول - وفرة',
    'NMF': 'صندوق استثمار نعيم مصر وفقا لأحكام الشريعة الإسلامية',
    'CMS': 'صندوق استثمار سي آي استس مانجمنت للاسثتمار في مؤشر الشريعة EGX33 - مصر مؤشر شريعة إكويتى',
    'MTF': 'صندوق استثمار شركة مصر للتأمين التكافلي النقدى الإسلامي',
    'AZG': 'صندوق أزيموت للمعادن النفيسة الإسلامي - الإصدار الأول - جولد - AZ', 
    'ASO': 'صندوق أزيموت لفرص الأسهم - فرص الشريعة  AZ', 
    'AZO': 'ازيموت فرص',
    'AZN': 'ازيموت ناصر',
    'AZS': 'ادخار',
    'B35': 'بلتون بي-35',
    'B70': 'بلتون EGX70',
    'BAL': 'بلتون للاستثمار',
    'BCO': 'بلتون القطاع الاسته',
    'BFF': 'بنك القاهره الاول',
    'BFI': 'بلتون القطاع المالي',
    'BIN': 'بلتون القطاع الصناعي',
    'BMM': 'بلتون مية مية',
    'BRE': 'بلتون القطاع العقاري',
    'BSC': 'بي سكيور',
    'C20': 'سي آي 20HD',
    'CCB': 'سي آي استهلاكي',
    'CCM': 'كايرو كابيتال مومنتم',
    'CCS': 'كايرو كابيتال ستريم',
    'CEX': 'سي آي تصدير',
    'CFF': 'سي آي مال ومدفوعا',
    'CI30': 'مؤشر CI EGX30',
    'CIP': 'سي آي للاكتتابات',
    'CRE': 'سي آي عقارات وبناء',
    'CTI': 'سي آي تكنولوجيا',
    'CTQ': 'ذا كوانت',
    'GRA': 'جرانيت',
    'MSI': 'مباشر فضة',
    'NAM': 'بنك الكويت الوطني',
    'NCS': '70 ان أي كابيتال',
    'PCM': 'كاشي PFI',
    'T70': 'ثاندر T70',
    'ZEM': 'زالدي المصري',
    'ZST': 'زالدي ستار'
}

def _fetch_fund_price(ticker): 
    """Offset-Paginated JSON API scraper with per-refresh caching."""
    global MUBASHER_FUNDS_BUFFER, MUBASHER_FUNDS_LAST_FETCH
    try:
        # If cache is fresh (less than 4 minutes old), use it
        now = datetime.utcnow()
        if MUBASHER_FUNDS_LAST_FETCH and (now - MUBASHER_FUNDS_LAST_FETCH).total_seconds() < 240:
            val = MUBASHER_FUNDS_BUFFER.get(ticker)
            if val is not None:
                return val

        # Otherwise, refresh the entire fund buffer
        keyword = FUND_KEYWORDS.get(ticker)
        if not keyword: return None
            
        print(f"🔄 Refreshing Global Fund Buffer for {ticker}...")
        temp_buffer = {}
        
        # Paginate to find all keywords
        for start_offset in range(0, 200, 20):
            url = f"https://www.mubasher.info/api/1/funds?country=eg&size=20&start={start_offset}"
            resp = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'}, timeout=15)
            
            if resp.status_code == 200:
                data = resp.json()
                rows = data.get('rows', [])
                if not rows: break
                
                for row in rows:
                    r_name = row.get('name', '')
                    if r_name and any(k in r_name for k in FUND_KEYWORDS.values()):
                        # Find which ticker this belongs to
                        for t, k in FUND_KEYWORDS.items():
                            if k in r_name:
                                price_val = row.get('price')
                                if price_val and float(price_val) > 0:
                                    temp_buffer[t] = float(price_val)
                                    print(f"✅ Buffered Fund: {t} -> {price_val}")
            else:
                break
        
        if temp_buffer:
            MUBASHER_FUNDS_BUFFER.update(temp_buffer)
            MUBASHER_FUNDS_LAST_FETCH = now
            return MUBASHER_FUNDS_BUFFER.get(ticker)
            
    except Exception as e:
        print(f"Fund Scraping Exception: {e}")
        
    return None

def is_market_open():
    try:
        now_cairo = pd.Timestamp.now(tz='Africa/Cairo')
        if now_cairo.weekday() not in [0, 1, 2, 3, 6]:
            return False
        current_time_float = now_cairo.hour + now_cairo.minute / 60.0
        if not (10.0 <= current_time_float <= 14.5):
            return False
        return True
    except Exception:
        return True

# --- Data Engine ---
def _fetch_single_ticker_aggressive(ticker):
    """Accumulates live prices into the deque and recalculates technicals."""
    try:
        data = MARKET_DATA_CACHE.get(ticker)
        if not data: return None
        
        is_fund = ticker in MUTUAL_FUNDS
        clean_ticker = ticker.split('.')[0]
        
        # 1. Primary Live Price
        live_price = None
        source = "Initializing"
        
        # Try yfinance first for everything (as requested by user)
        try:
            yf_ticker = ticker
            # Ensure suffixes are correct for yfinance
            # EGX -> .CA (already there)
            # KSA -> .SR (already there)
            # DFM -> .DU (already there)
            # ADX -> .AD (already there)
            
            ticker_obj = yf.Ticker(yf_ticker)
            # Use fast_info or info (fast_info is better for just price)
            live_price = ticker_obj.fast_info.get('last_price')
            if live_price is not None and math.isfinite(live_price) and live_price > 0:
                source = f"yfinance (Live)"
            else:
                live_price = None
        except Exception as e:
            # If yfinance is blocked (common on HF), print and continue to scrapers
            print(f"⚠️ yfinance blocked/failed for {ticker}: {e}")
            pass 

        # Fallback to Scrapers if yfinance failed or returned nothing
        if live_price is None:
            if is_fund:
                live_price = _fetch_fund_price(clean_ticker)
                source = "Fund Scraper (Mubasher)"
            else:
                live_price = _fetch_mubasher_price(ticker)
                source = "Mubasher Scraper (Live)"
        
        # Final Fallback to Firestore DB
        if live_price is None:
            try:
                if firebase_admin._apps:
                    db = firestore.client()
                    users_ref = db.collection('users')
                    for user_doc in users_ref.stream():
                        inv_ref = users_ref.document(user_doc.id).collection('investments')
                        for portfolio in inv_ref.stream():
                            p_data = portfolio.to_dict()
                            for asset in p_data.get('assets', []):
                                if asset.get('name') == ticker:
                                    val = float(asset.get('buyPrice', 0.0))
                                    if val > 0:
                                        live_price = val
                                        break
                            if live_price is not None: break
                        if live_price is not None: break
            except Exception as e:
                print(f"Firestore fallback error {ticker}: {e}")
        
        # 2. History Bootstrap (Warm-up)
        history_dq = data["deque"]
        source = "Fund Scraper" if is_fund else "Mubasher (Live Accumulation)"
        
        if len(history_dq) < 40:
            # ONLY bootstrap if it's a priority or has no data
            # To avoid slowing down, we skip bootstrapping for the bulk list on startup
            if not is_fund and len(history_dq) == 0:
                try:
                    # Only fetch if we really have 0 data
                    df = yf.download(ticker, period="2d", interval="5m", progress=False, timeout=5)
                    
                    if not df.empty:
                        # Robust column extraction (handles MultiIndex or Single Index)
                        closes_series = None
                        if isinstance(df.columns, pd.MultiIndex):
                            # Case: MultiIndex (Ticker, Column) or (Column, Ticker)
                            if 'Close' in df.columns.get_level_values(0):
                                closes_series = df['Close']
                            elif 'Close' in df.columns.get_level_values(1):
                                closes_series = df.xs('Close', axis=1, level=1)
                        else:
                            # Case: Single Index
                            if 'Close' in df.columns:
                                closes_series = df['Close']

                        if closes_series is not None:
                            if isinstance(closes_series, pd.DataFrame):
                                if ticker in closes_series.columns:
                                    closes_series = closes_series[ticker]
                                else:
                                    closes_series = closes_series.iloc[:, 0]
                                
                            history_dq.clear()
                            closes_list = closes_series.dropna().tail(80).tolist()
                            for p in closes_list:
                                history_dq.append(float(p))

                    if len(history_dq) >= 20:
                        source = f"Robust Bootstrap (yf {len(history_dq)}pts)"
                        print(f"✅ {ticker} warmed up with {len(history_dq)} yf points.")
                    else:
                        # [Fallback] Try TvDatafeed for warm-up
                        try:
                            tv = get_tv_client()
                            if tv:
                                tv_ticker = ticker.replace('.CA', '')
                                hist = tv.get_hist(symbol=tv_ticker, exchange='EGX', interval=Interval.in_1_minute, n_bars=80)
                                if hist is not None and not hist.empty:
                                    history_dq.clear()
                                    for p in hist['close'].tail(80).tolist():
                                        history_dq.append(float(p))
                                    source = f"TradingView Bootstrap ({len(history_dq)}pts)"
                                    print(f"✅ {ticker} warmed up via TV.")
                        except Exception as tv_e:
                            print(f"⚠️ TV Bootstrap failed for {ticker}: {tv_e}")
                except Exception as e:
                    print(f"⚠️ Bootstrap failed for {ticker}: {e}")
            
            # If still empty (Funds or yf failed), only then use a minimal seed to avoid crash
            if len(history_dq) < 40 and live_price:
                # Note: We keep this as a last-resort safety net, but yf should handle most stocks
                if len(history_dq) == 0:
                    for _ in range(40):
                        history_dq.append(live_price)
                    source = "Safety Seed (Static)"

        # 3. Append latest point
        if live_price:
            data["price"] = round(float(live_price), 2)
            
            should_append = False
            if is_market_open():
                should_append = True
            elif len(history_dq) == 0:
                should_append = True
            elif len(history_dq) > 0 and history_dq[-1] != float(live_price):
                should_append = True
                
            if should_append:
                history_dq.append(float(live_price))
                
        # 4. Technical Recalculation
        _recalculate_technicals(ticker)
        
        data["source"] = source
        
        # 5. Broadcast via WebSocket
        # 5. Broadcast via WebSocket (Minimal Payload for Speed)
        socketio.emit('price_update', {
            's': ticker,
            'p': data['price'],
            'c': data.get('change', 0.0)
        })
        
        return data

    except Exception as e:
        print(f"Engine Error {ticker}: {e}")
        return None

def _recalculate_technicals(ticker):
    """Calculates RSI, MACD, Support, and Resistance based on the current deque."""
    data = MARKET_DATA_CACHE.get(ticker)
    if not data: return
    
    history_dq = data["deque"]
    if len(history_dq) >= 14:
        try:
            history_series = pd.Series(list(history_dq))
            data["rsi"] = round(calculate_rsi(history_series), 2)
            data["macd"] = calculate_macd(history_series)
            
            recent_max = history_series.max()
            recent_min = history_series.min()
            current = data.get("price", 0.0)
            
            res = recent_max if current < recent_max else current * 1.05
            sup = recent_min if current > recent_min else current * 0.95
            
            data["support"] = round(float(sup), 2)
            data["resistance"] = round(float(res), 2)
            
            # Ensure RSI is finite
            if not math.isfinite(data["rsi"]): data["rsi"] = 50.0
        except Exception as e:
            print(f"Technical calculation error for {ticker}: {e}")

def refresh_market_data():
    """Iterates through all tickers, updates prices, and calculates indicators."""
    print(f"🕒 Refreshing {len(WATCHLIST)} tickers + News + Macro...")
    
    # 1. Macro Indicators Fallback
    _fetch_macro_indicators()
    
    # 2. Sequential Stock Refresh with Rate Limiting
    # 2. Parallel Ticker Refresh with ThreadPool
    with ThreadPoolExecutor(max_workers=5) as executor:
        futures = {executor.submit(_fetch_single_ticker_aggressive, ticker): ticker for ticker in WATCHLIST}
        for future in as_completed(futures):
            ticker = futures[future]
            try:
                future.result()
            except Exception as e:
                print(f"Error refreshing {ticker}: {e}")
            
    # 3. Persistence Save
    _save_market_state_to_firestore()
    print("✅ Market state synchronized.")

scheduler = BackgroundScheduler()
# Increased interval to 5 minutes to avoid job overlap and yfinance rate limits
scheduler.add_job(func=refresh_market_data, trigger="interval", seconds=300)

def setup_firebase():
    global db
    if not firebase_admin._apps:
        cred_json = os.environ.get('FIREBASE_CREDENTIALS')
        if cred_json:
            try:
                cred_dict = json.loads(cred_json)
                cred = credentials.Certificate(cred_dict)
                firebase_admin.initialize_app(cred)
                db = firestore.client()
                print("Firebase Initialized and db client ready.")
            except Exception as e:
                print(f"Error initializing Firebase: {e}")
        else:
            print("FIREBASE_CREDENTIALS not found in environment.")
    else:
        db = firestore.client()

setup_firebase()

def initialize_system():
    print("🚀 Initializing ONYX System State...")
    _load_market_state_from_firestore()
    # Initial refresh to get current prices
    refresh_market_data()
    # Force an immediate save of the warmed up state to Firestore
    _save_market_state_to_firestore()

initialize_system()

def cleanup_old_signals():
    global db
    try:
        if db is None: return
        cutoff = datetime.utcnow() - timedelta(hours=24)
        signals_ref = db.collection('market_signals')
        query = signals_ref.where(filter=firestore.FieldFilter('timestamp', '<', cutoff))
        docs = query.stream()
        count = 0
        for doc in docs:
            doc.reference.delete()
            count += 1
        print(f"Cleaned up {count} old signals.")
    except Exception as e:
        print(f"Cleanup error: {e}")

cleanup_old_signals()

def scan_market():
    try:
        global db
        if not is_market_open():
            print("Outside EGX trading hours. Skipping scan.")
            return
            
        print("Starting Market Scan...")
        tickers_str = " ".join(WATCHLIST)
        data = None
        try:
            data = yf.download(tickers_str, period="2mo", interval="1d", group_by="ticker", auto_adjust=False, prepost=False, threads=True, timeout=20)
        except Exception as yfe:
            print(f"⚠️ Bulk yfinance download failed: {yfe}")
        
        if db is None: 
            return
        
        for ticker in WATCHLIST:
            stock_data = MARKET_DATA_CACHE.get(ticker)
            if not stock_data or stock_data['price'] == 0:
                continue
                
            current_price = stock_data['price']
            current_rsi = stock_data['rsi']
            
            volume_spike = False
            try:
                # Get historical data for volume analysis
                df = None
                if data is not None and not data.empty:
                    if ticker in WATCHLIST:
                        if len(WATCHLIST) == 1: df = data
                        else: df = data.get(ticker)
                
                # Fallback to TvDatafeed for volume if yfinance failed
                if (df is None or df.empty) and ticker in WATCHLIST:
                    try:
                        tv = get_tv_client()
                        if tv:
                            tv_ticker = ticker.replace('.CA', '')
                            df = tv.get_hist(symbol=tv_ticker, exchange='EGX', interval=Interval.in_daily, n_bars=30)
                            if df is not None:
                                df.rename(columns={'volume': 'Volume'}, inplace=True)
                    except: pass

                if df is not None and not df.empty and len(df) > 1:
                    avg_vol = df['Volume'].iloc[-30:-1].mean()
                    current_vol = df['Volume'].iloc[-1]
                    if avg_vol > 0 and current_vol > (3 * avg_vol):
                        volume_spike = True
            except Exception as e:
                pass
                
            if current_rsi < 30 or volume_spike:
                signal_type = "RSI_REVERSAL" if current_rsi < 30 else "VOLUME_SPIKE"
                if current_rsi < 30 and volume_spike:
                    signal_type = "PRICE_BREAKOUT"
                    
                msg = f"{ticker} is showing strong opportunities at {current_price} EGP."
                
                recently_alerted = False
                try:
                    recent_signals = db.collection('market_signals') \
                        .where(filter=firestore.FieldFilter('ticker', '==', ticker)) \
                        .where(filter=firestore.FieldFilter('type', '==', signal_type)) \
                        .order_by('timestamp', direction=firestore.Query.DESCENDING) \
                        .limit(1).stream()
                    
                    recent_list = list(recent_signals)
                    if recent_list:
                        last_alert_time = recent_list[0].to_dict().get('timestamp')
                        if last_alert_time:
                            import pytz
                            if last_alert_time.tzinfo is None:
                                last_alert_time = last_alert_time.replace(tzinfo=pytz.UTC)
                            if (datetime.now(pytz.UTC) - last_alert_time).total_seconds() < 3600 * 4:
                                recently_alerted = True
                except Exception as e:
                    # Likely missing index error, log it but don't stop the scan
                    if "index" in str(e).lower():
                        print(f"⚠️ Index required for signal check ({ticker}). Please create it in Firebase Console.")
                    else:
                        print(f"Signal check error: {e}")

                if not recently_alerted:
                    db.collection('market_signals').add({
                        'ticker': ticker,
                        'type': signal_type,
                        'message': msg,
                        'value': str(current_price),
                        'timestamp': firestore.SERVER_TIMESTAMP
                    })
                    
                    try:
                        message = messaging.Message(
                            notification=messaging.Notification(
                                title="Market Opportunity 🎯",
                                body=f"{ticker}: {signal_type.replace('_', ' ')} logic triggered"
                            ),
                            topic='market_opportunities'
                        )
                        messaging.send(message)
                    except Exception as me:
                        pass
                
        users_ref = db.collection('users')
        for user_doc in users_ref.stream():
            uid = user_doc.id
            inv_ref = users_ref.document(uid).collection('investments')
            for portfolio in inv_ref.stream():
                p_data = portfolio.to_dict()
                assets = p_data.get('assets', [])
                updated_assets = False
                
                for asset in assets:
                    ticker = asset.get('name')
                    target = asset.get('takeProfit')
                    stop_loss = asset.get('stopLoss')
                    token = asset.get('fcmToken')
                    
                    stock_data = MARKET_DATA_CACHE.get(ticker)
                    if stock_data and stock_data['price'] > 0:
                        cp = stock_data['price']
                        hit_type = None
                        
                        if target and target > 0 and cp >= target:
                            hit_type = "Target Reached"
                            asset['takeProfit'] = None 
                            updated_assets = True
                            
                        elif stop_loss and stop_loss > 0 and cp <= stop_loss:
                            hit_type = "Stop Loss Hit"
                            asset['stopLoss'] = None
                            updated_assets = True
                            
                        if hit_type and token:
                            try:
                                msg = messaging.Message(
                                    notification=messaging.Notification(
                                        title=f"Alert: {ticker}",
                                        body=f"{ticker} has hit its {hit_type} at {cp}"
                                    ),
                                    token=token
                                )
                                messaging.send(msg)
                            except Exception as e:
                                pass
                                
                if updated_assets:
                    portfolio.reference.update({'assets': assets})
                    
    except Exception as e:
        print(f"Scan Market Error: {e}")
    finally:
        # [Persistence] Save deques to Firestore after every scan
        _save_market_state_to_firestore()

def take_daily_snapshots():
    """Background job that calculates total portfolio value for all users and saves a snapshot."""
    global db
    print("Initiating Daily Portfolio Snapshots...")
    if db is None: return
    try:
        users_ref = db.collection('users')
        user_docs = users_ref.stream()
        
        count = 0
        for user_doc in user_docs:
            uid = user_doc.id
            inv_ref = users_ref.document(uid).collection('investments')
            for portfolio in inv_ref.stream():
                p_data = portfolio.to_dict()
                assets = p_data.get('assets', [])
                total_val = 0.0
                
                for asset in assets:
                    ticker = asset.get('name')
                    qty = asset.get('quantity', 0)
                    if not ticker or qty <= 0: continue
                    
                    price = 0.0
                    cached_data = MARKET_DATA_CACHE.get(ticker)
                    if cached_data and cached_data['price'] > 0:
                        price = cached_data['price']
                    else:
                        price = asset.get('buyPrice', 0.0)
                        
                    total_val += (price * float(qty))
                
                if total_val > 0:
                    snapshot_ref = portfolio.reference.collection('portfolio_snapshots')
                    snapshot_ref.add({
                        'timestamp': firestore.SERVER_TIMESTAMP,
                        'total_value': round(total_val, 2)
                    })
                    count += 1
                    
        print(f"✅ Daily Portfolio Snapshots completed successfully. ({count} portfolios)")
    except Exception as e:
        print(f"Error taking daily snapshots: {e}")

scheduler.add_job(func=scan_market, trigger="interval", minutes=15)
scheduler.add_job(
    func=take_daily_snapshots,
    trigger="cron",
    day_of_week='sun,mon,tue,wed,thu',
    hour=14,
    minute=45,
    timezone='Africa/Cairo'
)
scheduler.add_job(
    func=cleanup_old_signals,
    trigger="cron",
    hour=2,
    minute=0,
    timezone='Africa/Cairo'
)
scheduler.start()

# Trigger an initial refresh in the background immediately on startup
import threading
threading.Thread(target=refresh_market_data).start()

@app.route('/api/egx/all')
def get_all():
    ticker_symbol = request.args.get('ticker_symbol') or request.args.get('ticker')
    market_news_str = ""
    if ticker_symbol:
        macro_news = get_macro_news_enterprise(limit=2)
        clean_ticker = ticker_symbol.upper().replace('.CA', '')
        stock_news = get_stock_news_mubasher(clean_ticker, limit=3)
        
        combined_news = macro_news + stock_news
        market_news_str = "\n".join(combined_news)
        
    # If cache is empty, trigger a background refresh (non-blocking)
    all_zero = all(v['price'] == 0.0 for v in MARKET_DATA_CACHE.values())
    if all_zero:
        import threading
        threading.Thread(target=refresh_market_data).start()
    
    # Safe JSON sanitization: prevent NaN or Infinity from breaking JSON spec
    safe_stocks = {}
    for k, v in MARKET_DATA_CACHE.items():
        # Clean up name: pandas might have put float('nan')
        name_val = v.get("name", k)
        if isinstance(name_val, float) and math.isnan(name_val):
            name_val = None
            
        stock_data = {
            "price": v.get("price", 0.0),
            "rsi": v.get("rsi", 50.0),
            "macd": v.get("macd", "Neutral"),
            "support": v.get("support", 0.0),
            "resistance": v.get("resistance", 0.0),
            "change": v.get("change", 0.0),
            "volume": v.get("volume", 0),
            "source": str(v.get("source", "Unknown")),
            "name": str(name_val) if name_val is not None else None,
            "is_fund": bool(v.get("is_fund", False))
        }
        # Final pass: check for any accidental NaN values in floats
        for field in ['price', 'rsi', 'support', 'resistance', 'change']:
            val = stock_data[field]
            if isinstance(val, float) and not math.isfinite(val):
                stock_data[field] = 50.0 if field == 'rsi' else 0.0
                
        safe_stocks[k] = stock_data        
    return jsonify({
        "stocks": safe_stocks,
        "news": NEWS_CACHE,
        "macro": MACRO_CACHE,
        "breadth": _calculate_market_breadth(),
        "market_news": market_news_str,
        "last_updated": datetime.utcnow().isoformat()
    })

@app.route('/')
def health_check():
    return jsonify({"status": "ONYX Radar is awake and running"}), 200

@app.route('/api/debug')
def debug_stats():
    return jsonify({
        "total_tickers_in_memory": len(WATCHLIST),
        "total_funds_in_memory": len(MUTUAL_FUNDS),
        "cache_size": len(MARKET_DATA_CACHE),
        "db_path_resolved": os.path.join(os.path.dirname(__file__), "..", "ticker_data", "tickers.db"),
        "db_exists": os.path.exists(os.path.join(os.path.dirname(__file__), "..", "ticker_data", "tickers.db"))
    })

if __name__ == '__main__':
    # When running locally via 'python app.py'
    app.run(debug=False, host='0.0.0.0', port=int(os.environ.get('PORT', 7860)))