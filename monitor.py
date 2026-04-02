import firebase_admin
from firebase_admin import credentials, firestore, messaging
import yfinance as yf
import pandas as pd
from datetime import datetime
import time

# الربط بفايربيز
cred = credentials.Certificate('firebase-key.json')
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

# 🔥 قائمة الـ 30 سهم (الأقوى في البورصة المصرية)
EGX_30 = [
    'COMI.CA', 'FWRY.CA', 'TMGH.CA', 'HRHO.CA', 'EKHO.CA', 'ABUK.CA', 'MFPC.CA', 
    'SWDY.CA', 'ETEL.CA', 'EFIH.CA', 'SKPC.CA', 'AMOC.CA', 'PHDC.CA', 'MASR.CA', 
    'ORWE.CA', 'HELI.CA', 'ESRS.CA', 'JUFO.CA', 'CLHO.CA', 'ISPH.CA', 'ADIB.CA', 
    'QNBA.CA', 'CIRA.CA', 'EAST.CA', 'AMER.CA', 'CCAP.CA', 'BTEL.CA', 'EKHOA.CA', 
    'ALCN.CA', 'EMFD.CA'
]

def calculate_rsi(prices, window=14):
    delta = prices.diff()
    up = delta.clip(lower=0)
    down = -1 * delta.clip(upper=0)
    ema_up = up.ewm(com=window-1, adjust=False).mean()
    ema_down = down.ewm(com=window-1, adjust=False).mean()
    rs = ema_up / ema_down
    return 100 - (100 / (1 + rs))

def already_sent_today(ticker, alert_type):
    """بيتحقق من فايربيز لو الإشعار ده اتبعت النهارده ولا لأ"""
    today = datetime.now().strftime('%Y-%m-%d')
    doc_id = f"{ticker}_{alert_type}_{today}"
    doc_ref = db.collection('alerts_history').document(doc_id)
    return doc_ref.get().exists

def mark_as_sent(ticker, alert_type):
    """بيسجل في فايربيز إن الإشعار اتبعت خلاص"""
    today = datetime.now().strftime('%Y-%m-%d')
    doc_id = f"{ticker}_{alert_type}_{today}"
    db.collection('alerts_history').document(doc_id).set({
        'ticker': ticker,
        'type': alert_type,
        'date': today,
        'timestamp': firestore.SERVER_TIMESTAMP
    })

def get_my_token():
    docs = list(db.collection_group('investments').stream())
    for doc in docs:
        assets = doc.to_dict().get('assets', [])
        for asset in assets:
            token = asset.get('fcmToken')
            if token: return token
    return None

def scan_market():
    token = get_my_token()
    if not token: return

    print(f"🚀 بدء مسح الـ {len(EGX_30)} سهم...")
    
    for ticker in EGX_30:
        try:
            stock = yf.Ticker(ticker)
            hist = stock.history(period='1mo')
            if hist.empty: continue
                
            current_price = hist['Close'].iloc[-1]
            rsi = calculate_rsi(hist['Close']).iloc[-1]
            
            # منطق إرسال الإشعار لمرة واحدة في اليوم
            if rsi < 30 and not already_sent_today(ticker, 'BUY'):
                send_push(token, f"💡 فرصة شراء: {ticker}", f"السهم مضغوط (RSI: {rsi:.0f}). السعر: {current_price:.2f}")
                mark_as_sent(ticker, 'BUY')
                print(f"✅ إشعار شراء لـ {ticker} اتبعت.")
                
            elif rsi > 70 and not already_sent_today(ticker, 'SELL'):
                send_push(token, f"⚠️ جني أرباح: {ticker}", f"السهم متضخم (RSI: {rsi:.0f}). السعر: {current_price:.2f}")
                mark_as_sent(ticker, 'SELL')
                print(f"✅ إشعار بيع لـ {ticker} اتبعت.")
            
            time.sleep(0.5) # حماية من الحظر
        except Exception as e:
            print(f"⚠️ خطأ في {ticker}: {e}")

def send_push(token, title, body):
    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        token=token,
    )
    messaging.send(message)

if __name__ == '__main__':
    scan_market()