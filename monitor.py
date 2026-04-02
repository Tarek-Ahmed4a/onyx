import firebase_admin
from firebase_admin import credentials, firestore, messaging
import yfinance as yf
import pandas as pd
import google.generativeai as genai
from datetime import datetime
import os
import time

# --- الإعدادات ---
# ربط Gemini (بيسحب المفتاح من Secrets)
genai.configure(api_key=os.environ.get('GEMINI_API_KEY'))
ai_model = genai.GenerativeModel('gemini-1.5-flash')

# ربط Firebase
cred = credentials.Certificate('firebase-key.json')
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

# قائمة الـ 30 سهم (البورصة المصرية)
EGX_30 = [
    'COMI.CA', 'FWRY.CA', 'TMGH.CA', 'HRHO.CA', 'EKHO.CA', 'ABUK.CA', 'MFPC.CA', 
    'SWDY.CA', 'ETEL.CA', 'EFIH.CA', 'SKPC.CA', 'AMOC.CA', 'PHDC.CA', 'MASR.CA', 
    'ORWE.CA', 'HELI.CA', 'ESRS.CA', 'JUFO.CA', 'CLHO.CA', 'ISPH.CA', 'ADIB.CA', 
    'QNBA.CA', 'CIRA.CA', 'EAST.CA', 'AMER.CA', 'CCAP.CA', 'BTEL.CA', 'EKHOA.CA', 
    'ALCN.CA', 'EMFD.CA'
]

# --- الدوال المساعدة ---

def calculate_rsi(prices, window=14):
    delta = prices.diff()
    up = delta.clip(lower=0)
    down = -1 * delta.clip(upper=0)
    ema_up = up.ewm(com=window-1, adjust=False).mean()
    ema_down = down.ewm(com=window-1, adjust=False).mean()
    rs = ema_up / ema_down
    return 100 - (100 / (1 + rs))

def get_ai_insight(ticker, price, rsi, trend):
    """بيسأل Gemini عن رأيه في الفرصة"""
    prompt = f"""
    أنت محلل مالي خبير في البورصة المصرية. سهم {ticker} سعره الآن {price:.2f} ومؤشر الـ RSI هو {rsi:.0f}. 
    اتجاه السهم حالياً هو {trend}. 
    اعطني نصيحة سريعة جداً (جملة واحدة فقط) بالعامية المصرية بلهجة ذكية ومختصرة، هل نشتري أم ننتظر؟ ولماذا؟
    ابدأ النصيحة فوراً بدون مقدمات.
    """
    try:
        response = ai_model.generate_content(prompt)
        return response.text.strip()
    except:
        return "المؤشرات الفنية بتقول إن فيه حركة قوية، راقب السهم كويس."

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

# --- المحرك الرئيسي ---

def scan_market():
    token = get_fcm_token()
    if not token: return

    print(f"🚀 بدء مسح السوق بذكاء Gemini...")
    
    for ticker in EGX_30:
        try:
            stock = yf.Ticker(ticker)
            hist = stock.history(period='1mo')
            if hist.empty: continue
                
            current_price = hist['Close'].iloc[-1]
            rsi = calculate_rsi(hist['Close']).iloc[-1]
            
            # تحديد الاتجاه ببساطة
            trend = "صاعد" if current_price > hist['Close'].iloc[-5] else "هابط"

            if rsi < 35 and not already_sent_today(ticker, 'BUY'):
                ai_advice = get_ai_insight(ticker, current_price, rsi, trend)
                send_push(token, f"💡 فرصة شراء: {ticker}", ai_advice)
                mark_as_sent(ticker, 'BUY')
                
            elif rsi > 65 and not already_sent_today(ticker, 'SELL'):
                ai_advice = get_ai_insight(ticker, current_price, rsi, trend)
                send_push(token, f"⚠️ جني أرباح: {ticker}", ai_advice)
                mark_as_sent(ticker, 'SELL')
            
            time.sleep(1) # حماية من الحظر
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