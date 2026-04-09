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
        "source": "Initializing",
        "deque": deque(maxlen=100)
    }
    for ticker in WATCHLIST
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

def _fetch_fund_price(ticker):
    """Fallback web scraper for Egyptian Mutual Funds"""
    try:
        # First attempt: standard /funds/ URL
        url = f"https://www.mubasher.info/markets/EGX/funds/{ticker}"
        resp = requests.get(url, headers=get_headers(), timeout=5)
        soup = BeautifulSoup(resp.text, 'lxml')
        price_tag = soup.select_one('.market-summary__last-price')
        if price_tag:
            return float(price_tag.text.strip().replace(',', ''))
        
        # Second attempt fallback: /stocks/ URL since some (like AZG) trade like equities
        url_alt = f"https://www.mubasher.info/markets/EGX/stocks/{ticker}"
        resp_alt = requests.get(url_alt, headers=get_headers(), timeout=5)
        soup_alt = BeautifulSoup(resp_alt.text, 'lxml')
        price_tag_alt = soup_alt.select_one('.market-summary__last-price')
        if price_tag_alt:
            return float(price_tag_alt.text.strip().replace(',', ''))

    except Exception as e:
        print(f"Fund Scraping Error {ticker}: {e}")
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
            
            # Ensure RSI is finite
            if not math.isfinite(data["rsi"]): data["rsi"] = 50.0
        
        data["source"] = source
        return data

    except Exception as e:
        print(f"Engine fail {ticker}: {e}")
        return None

def refresh_market_data():
    print(f"🕒 Refreshing {len(WATCHLIST)} tickers (Live Accumulation)...")
    with ThreadPoolExecutor(max_workers=30) as executor:
        futures = {executor.submit(_fetch_single_ticker_aggressive, t): t for t in WATCHLIST}
        for f in as_completed(futures):
            # The function updates MARKET_DATA_CACHE[ticker] directly
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