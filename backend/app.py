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
from datetime import timedelta
import json
import firebase_admin
from firebase_admin import credentials, firestore, messaging


# --- Configuration ---
USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36'
]

def get_headers():
    return {'User-Agent': random.choice(USER_AGENTS)}

app = Flask(__name__)
CORS(app)

EGX_100 = [
'AMER.CA' ,
'ATLC.CA' ,
'TALM.CA' ,
'ISPH.CA' ,
'ABUK.CA' ,
'AIHC.CA' ,
'AIDC.CA' ,
'ASPI.CA' ,
'SCEM.CA' ,
'ASCM.CA' ,
'EMFD.CA' ,
'ACTF.CA' ,
'ALCN.CA' ,
'AMOC.CA' ,
'IDRE.CA' ,
'ISMA.CA' ,
'AFDI.CA' ,
'COMI.CA' ,
'EXPA.CA' ,
'DAPH.CA' ,
'ISMQ.CA' ,
'ICFC.CA' ,
'IFAP.CA' ,
'ZEOT.CA' ,
'OCDI.CA' ,
'SWDY.CA' ,
'EAST.CA' ,
'ELSH.CA' ,
'UEGC.CA' ,
'EGCH.CA' ,
'ENGC.CA' ,
'RMDA.CA' ,
'PRCL.CA' ,
'MEPA.CA' ,
'OBRI.CA' ,
'ARCC.CA' ,
'ECAP.CA' ,
'POUL.CA' ,
'COSG.CA' ,
'CCAP.CA' ,
'CSAG.CA' ,
'IEEC.CA' ,
'PHAR.CA' ,
'ETRS.CA' ,
'ETEL.CA' ,
'EGTS.CA' ,
'MOED.CA' ,
'MPRC.CA' ,
'EHDR.CA' ,
'ARAB.CA' ,
'AMIA.CA' ,
'MPCO.CA' ,
'ORWE.CA' ,
'KABO.CA' ,
'NIPH.CA' ,
'MTIE.CA' ,
'OFH.CA' ,
'ORAS.CA' ,
'OIH.CA' ,
'ORHD.CA' ,
'EFIH.CA' ,
'EFID.CA' ,
'PHDC.CA' ,
'BTFH.CA' ,
'HDBK.CA' ,
'CIEB.CA' ,
'TANM.CA' ,
'BIOC.CA' ,
'SVCE.CA' ,
'JUFO.CA' ,
'GPIM.CA' ,
'GBCO.CA' ,
'DSCW.CA' ,
'RAYA.CA' ,
'RACC.CA' ,
'ZMID.CA' ,
'SIPC.CA' ,
'SKPC.CA' ,
'SDTI.CA' ,
'NCCW.CA' ,
'TAQA.CA' ,
'VLMR.CA' ,
'VLMRA.CA' ,
'FWRY.CA' ,
'CNFN.CA' ,
'LCSW.CA' ,
'MCRO.CA' ,
'HRHO.CA' ,
'TMGH.CA' ,
'MASR.CA' ,
'HELI.CA' ,
'ATQA.CA' ,
'MFPC.CA' ,
'MCQE.CA' ,
'EGAL.CA' ,
'ADIB.CA' ,
'AFMC.CA' ,
'MPCI.CA' ,
'KRDI.CA' ,
'VALU.CA' ,
'UNIP.CA' ,
]

MUTUAL_FUNDS = ['NMF', 'CMS', 'ASO', 'BWA', 'ADA', 'AZG', 'BFA', 'BSB', 'MTF']

WATCHLIST = EGX_100 + MUTUAL_FUNDS

# Initialize Storage with Deques for each ticker (maxlen 100 for 1-minute accumulation)
MARKET_DATA_CACHE = {
    ticker: {
        "price": 0.0,
        "rsi": 50.0,
        "macd": "Neutral",
        "support": 0.0,
        "resistance": 0.0,
        "source": "Initializing",
        "deque": deque(maxlen=100)
    }
    for ticker in WATCHLIST
}

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
    return "Bullish crossover" if m > s else "Bearish divergence"

# --- Scrapers ---
def _fetch_mubasher_price(ticker):
    try:
        symbol = ticker.split('.')[0]
        url = f"https://www.mubasher.info/markets/EGX/stocks/{symbol}"
        resp = requests.get(url, headers=get_headers(), timeout=5)
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
    """Fetches USD/EGP, Gold, and EGX100 via yfinance."""
    global MACRO_CACHE
    try:
        # Tickers: EGX100 (CASE100.CA), USD/EGP (EGP=X), Gold (GC=F)
        tickers = ["CASE100.CA", "EGP=X", "GC=F"]
        data = yf.download(tickers, period="1d", timeout=10)
        
        if not data.empty and 'Close' in data:
            closes = data['Close'].iloc[-1]
            MACRO_CACHE = {
                "egx100": round(float(closes.get("CASE100.CA", 0.0)), 2),
                "usd_egp": round(float(closes.get("EGP=X", 0.0)), 2),
                "gold": round(float(closes.get("GC=F", 0.0)), 2),
                "last_updated": datetime.utcnow().isoformat()
            }
            print(f"🌍 Macro Indicators Updated: {MACRO_CACHE}")
    except Exception as e:
        print(f"Macro Fetch Error: {e}")

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
}

def _fetch_fund_price(ticker): 
    """Offset-Paginated JSON API scraper for Egyptian Mutual Funds."""
    try:
        keyword = FUND_KEYWORDS.get(ticker)
        if not keyword:
            return None
            
        # Offset pagination by 20 up to 200
        for start_offset in range(0, 220, 20):
            url = f"https://www.mubasher.info/api/1/funds?country=eg&size=20&start={start_offset}"
            print(f"Fetching API: {url} for {ticker}")
            
            resp = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'}, timeout=10)
            print(f"Mubasher API Status: {resp.status_code} (Offset {start_offset})")
            
            if resp.status_code == 200:
                data = resp.json()
                rows = data.get('rows', [])
                
                for row in rows:
                    if keyword in row.get('name', ''):
                        price_val = row.get('price')
                        if price_val is not None:
                            price = float(price_val)
                            print(f"✅ API Success: {ticker} -> {price}")
                            return price
                
                if not rows:
                    break
            else:
                print(f"Failed HTTP Status {resp.status_code} at offset {start_offset}")
                break
                
        print(f"Failed to find match for keyword '{keyword}' across all API offsets for {ticker}")
        
    except Exception as e:
        print(f"Exception for {ticker}: {str(e)}")
        print(f"API Scraping failed for {ticker}, falling back to DB")
        
    return None

# --- Data Engine ---
def _fetch_single_ticker_aggressive(ticker):
    """Accumulates live prices into the deque and recalculates technicals."""
    try:
        data = MARKET_DATA_CACHE.get(ticker)
        if not data: return None
        
        is_fund = ticker in MUTUAL_FUNDS
        
        # 1. Primary Live Price
        live_price = _fetch_fund_price(ticker) if is_fund else _fetch_mubasher_price(ticker)
        
        # Fallback to Firestore DB if live scraping failed (especially for Funds)
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
        
        # 2. History Bootstrap (Only if deque is empty)
        history_dq = data["deque"]
        source = "Fund Scraper" if is_fund else "Mubasher (Live Accumulation)"
        
        if len(history_dq) < 40:
            if not is_fund:
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
                source = "Seed Scraper" if is_fund else "Mubasher (Dummy Seed)"

        # 3. Append latest point
        if live_price:
            history_dq.append(live_price)
            data["price"] = round(float(live_price), 2)
        
        # 4. Technical Recalculation on the Deque
        if len(history_dq) >= 14:
            history_series = pd.Series(list(history_dq))
            data["rsi"] = round(calculate_rsi(history_series), 2)
            data["macd"] = calculate_macd(history_series)
            
            recent_max = history_series.max()
            recent_min = history_series.min()
            current = data["price"]
            
            res = recent_max if current < recent_max else current * 1.05
            sup = recent_min if current > recent_min else current * 0.95
            
            data["support"] = round(float(sup), 2)
            data["resistance"] = round(float(res), 2)
            
            # Ensure RSI is finite
            if not math.isfinite(data["rsi"]): data["rsi"] = 50.0
        
        data["source"] = source
        return data

    except Exception as e:
        print(f"Engine fail {ticker}: {e}")
        return None

def refresh_market_data():
    global NEWS_CACHE
    print(f"🕒 Refreshing {len(WATCHLIST)} tickers + News + Macro...")
    
    # 1. Refresh News
    new_news = _fetch_mubasher_news()
    if new_news:
        NEWS_CACHE = new_news
        
    # 2. Refresh Macro Indicators
    _fetch_macro_indicators()
        
    # 3. Refresh Stock Data
    with ThreadPoolExecutor(max_workers=30) as executor:
        futures = {executor.submit(_fetch_single_ticker_aggressive, t): t for t in WATCHLIST}
        for f in as_completed(futures):
            f.result() 
    print(f"✅ Market state synchronized.")

scheduler = BackgroundScheduler()
scheduler.add_job(func=refresh_market_data, trigger="interval", seconds=60)

def setup_firebase():
    if not firebase_admin._apps:
        cred_json = os.environ.get('FIREBASE_CREDENTIALS')
        if cred_json:
            try:
                cred_dict = json.loads(cred_json)
                cred = credentials.Certificate(cred_dict)
                firebase_admin.initialize_app(cred)
                print("Firebase Initialized.")
            except Exception as e:
                print(f"Error initializing Firebase: {e}")
        else:
            print("FIREBASE_CREDENTIALS not found in environment.")

setup_firebase()

def cleanup_old_signals():
    try:
        if not firebase_admin._apps: return
        db = firestore.client()
        cutoff = datetime.utcnow() - timedelta(hours=24)
        signals_ref = db.collection('market_signals')
        query = signals_ref.where('timestamp', '<', cutoff)
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
        now_cairo = pd.Timestamp.now(tz='Africa/Cairo')
        if now_cairo.weekday() not in [0, 1, 2, 3, 6]:
            print("Outside EGX trading days (Fri-Sat).")
            return
            
        current_time_float = now_cairo.hour + now_cairo.minute / 60.0
        if not (10.0 <= current_time_float <= 14.5):
            print(f"Outside EGX hours ({now_cairo.strftime('%H:%M')}).")
            return
            
        print("Starting Market Scan...")
        tickers_str = " ".join(EGX_100)
        data = yf.download(tickers_str, period="2mo", interval="1d", group_by="ticker", auto_adjust=False, prepost=False, threads=True)
        
        if not firebase_admin._apps: 
            return
            
        db = firestore.client()
        
        for ticker in WATCHLIST:
            stock_data = MARKET_DATA_CACHE.get(ticker)
            if not stock_data or stock_data['price'] == 0:
                continue
                
            current_price = stock_data['price']
            current_rsi = stock_data['rsi']
            
            volume_spike = False
            try:
                if ticker in EGX_100:
                    if len(EGX_100) == 1:
                        df = data
                    else:
                        df = data[ticker]
                    if not df.empty and len(df) > 1:
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
                
                recent_signals = db.collection('market_signals').where('ticker', '==', ticker).where('type', '==', signal_type).order_by('timestamp', direction=firestore.Query.DESCENDING).limit(1).stream()
                recent_list = list(recent_signals)
                recently_alerted = False
                if recent_list:
                    last_alert_time = recent_list[0].to_dict().get('timestamp')
                    if last_alert_time:
                        try:
                            # Handling Datetime With Timezone
                            import pytz
                            if last_alert_time.tzinfo is None:
                                last_alert_time = last_alert_time.replace(tzinfo=pytz.UTC)
                            if (datetime.now(pytz.UTC) - last_alert_time).total_seconds() < 3600 * 4:
                                recently_alerted = True
                        except Exception as e:
                            pass

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

def take_daily_snapshots():
    """Background job that calculates total portfolio value for all users and saves a snapshot."""
    print("Initiating Daily Portfolio Snapshots...")
    if not firebase_admin._apps: return
    try:
        db = firestore.client()
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
scheduler.start()

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
            "support": v.get("support", 0.0),
            "resistance": v.get("resistance", 0.0),
            "source": v["source"]
        }
        # Final pass: check for any accidental NaN values
        if not math.isfinite(stock_data['rsi']): stock_data['rsi'] = 50.0
        if not math.isfinite(stock_data['price']): stock_data['price'] = 0.0
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

@app.route('/force_sync')
def force():
    refresh_market_data()
    return jsonify({"status": "done", "count": len(MARKET_DATA_CACHE)})

if __name__ == '__main__':
    refresh_market_data()
    app.run(debug=False, host='0.0.0.0', port=int(os.environ.get('PORT', 7860)))