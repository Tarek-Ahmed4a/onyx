import firebase_admin
from firebase_admin import credentials, firestore, messaging
import yfinance as yf
import pandas as pd
from google import genai
from datetime import datetime
import os
import time

# --- الإعدادات ---
# ربط Gemini بالمكتبة الجديدة
try:
    ai_client = genai.Client(api_key=os.environ.get('GEMINI_API_KEY'))
except Exception as e:
    print(f"⚠️ خطأ في تهيئة Gemini: {e}")
    ai_client = None

# ربط Firebase
cred = credentials.Certificate('firebase-key.json')
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

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

def get_ai_insight(ticker, price, rsi, trend):
    if not ai_client:
        return "المؤشرات الفنية قوية، راقب السهم."
    
    prompt = f"أنت محلل مالي خبير في البورصة المصرية. سهم {ticker} سعره الآن {price:.2f} ومؤشر الـ RSI هو {rsi:.0f}. اتجاه السهم حالياً هو {trend}. اعطني نصيحة سريعة جداً (جملة واحدة فقط) بالعامية المصرية بلهجة ذكية ومختصرة، هل نشتري أم ننتظر؟ ولماذا؟ ابدأ النصيحة فوراً بدون مقدمات."
    try:
        response = ai_client.models.generate_content(
            model='gemini-1.5-pro',
            contents=prompt
        )
        return response.text.strip()
    except Exception as e:
        print(f"⚠️ خطأ Gemini مع {ticker}: {e}")
        return "تحليل فني بناءً على المؤشرات الحالية."

def already_sent_today(ticker, alert_type):
    today = datetime.now().strftime('%Y-%m-%d')
    doc_id = f"{ticker}_{alert_type}_{today}"
    return db.collection('alerts_history').document(doc_id).get().exists

def mark_as_sent(ticker, alert_type):
    today = datetime.now().strftime('%Y-%m-%d')
    doc_id = f"{ticker}_{alert_type}_{today}"
    db.collection('alerts_history').document(doc_id).set({
        'ticker': ticker, 'type': alert_type, 'date': today, 'timestamp': firestore.SERVER_TIMESTAMP
    })

def get_fcm_token():
    docs = list(db.collection_group('investments').stream())
    for doc in docs:
        assets = doc.to_dict().get('assets', [])
        for asset in assets:
            token = asset.get('fcmToken')
            if token: return token
    return None

def send_push(token, title, body):
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            token=token,
        )
        messaging.send(message)
        print(f"✅ تم إرسال الإشعار بنجاح: {title}")
    except Exception as e:
        print(f"⚠️ خطأ Firebase في إرسال الإشعار: {e}")

def scan_market():
    token = get_fcm_token()
    if not token:
        print("⚠️ لم يتم العثور على FCM Token في قاعدة البيانات. السكريبت سيتوقف.")
        return

    print("🚀 بدء مسح السوق...")
    
    for ticker in EGX_30:
        try:
            stock = yf.Ticker(ticker)
            hist = stock.history(period='1mo')
            if hist.empty:
                continue
                
            current_price = hist['Close'].iloc[-1]
            rsi = calculate_rsi(hist['Close']).iloc[-1]
            trend = "صاعد" if current_price > hist['Close'].iloc[-5] else "هابط"

            alert_type = None
            if rsi < 35 and not already_sent_today(ticker, 'BUY'):
                alert_type = 'BUY'
                title = f"💡 فرصة شراء: {ticker}"
            elif rsi > 65 and not already_sent_today(ticker, 'SELL'):
                alert_type = 'SELL'
                title = f"⚠️ جني أرباح: {ticker}"

            if alert_type:
                ai_advice = get_ai_insight(ticker, current_price, rsi, trend)
                send_push(token, title, ai_advice)
                mark_as_sent(ticker, alert_type)
            
            time.sleep(1)
        except Exception as e:
            print(f"⚠️ خطأ عام في {ticker}: {e}")

if __name__ == '__main__':
    scan_market()