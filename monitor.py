import firebase_admin
from firebase_admin import credentials, firestore, messaging
import yfinance as yf
import pandas as pd
from google import genai
from datetime import datetime
import os
import time
from tvDatafeed import TvDatafeed, Interval
import logging

# كتم رسائل التحذير الخاصة بمكتبة TradingView عشان اللوج يكون نظيف
logging.getLogger('tvDatafeed').setLevel(logging.ERROR)

# --- الإعدادات ---
try:
    ai_client = genai.Client(api_key=os.environ.get('GEMINI_API_KEY'))
except Exception as e:
    print(f"⚠️ خطأ في تهيئة Gemini: {e}")
    ai_client = None

cred = credentials.Certificate('firebase-key.json')
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

# تهيئة الاتصال بـ TradingView كضيف (بدون حساب)
tv_client = TvDatafeed()

EGX_30 = [
    'COMI.CA', 'FWRY.CA', 'TMGH.CA', 'HRHO.CA', 'EKHO.CA', 'ABUK.CA', 'MFPC.CA', 
    'SWDY.CA', 'ETEL.CA', 'EFIH.CA', 'SKPC.CA', 'AMOC.CA', 'PHDC.CA', 'MASR.CA', 
    'ORWE.CA', 'HELI.CA', 'ESRS.CA', 'JUFO.CA', 'CLHO.CA', 'ISPH.CA', 'ADIB.CA', 
    'QNBA.CA', 'CIRA.CA', 'EAST.CA', 'AMER.CA', 'CCAP.CA', 'BTEL.CA', 'EKHOA.CA', 
    'ALCN.CA', 'EMFD.CA'
]

def get_price_data(ticker):
    # 1. المحاولة الأولى: Yahoo Finance (الأدق للبيانات التاريخية)
    try:
        stock = yf.Ticker(ticker)
        hist = stock.history(period='1mo', interval='1d')
        if not hist.empty and len(hist) > 10:
            return hist['Close'], "Yahoo"
    except:
        pass

    # 2. المحاولة الثانية: TradingView مع زيادة وقت الانتظار (Timeout)
    try:
        tv_ticker = ticker.replace('.CA', '')
        # محاولة الاتصال بـ TradingView بحد أقصى 3 مرات في حالة الـ Timeout
        for _ in range(3):
            hist = tv_client.get_hist(symbol=tv_ticker, exchange='EGX', interval=Interval.in_daily, n_bars=30)
            if hist is not None and not hist.empty:
                return hist['close'], "TradingView"
            time.sleep(2)
    except:
        pass

    return None, None

def calculate_rsi(prices, window=14):
    # تنظيف البيانات من أي قيم فارغة قبل الحساب
    prices = prices.dropna()
    if len(prices) < window: return pd.Series([float('nan')] * len(prices))
    
    delta = prices.diff()
    up = delta.clip(lower=0)
    down = -1 * delta.clip(upper=0)
    ema_up = up.ewm(com=window-1, adjust=False).mean()
    ema_down = down.ewm(com=window-1, adjust=False).mean()
    rs = ema_up / ema_down
    rsi = 100 - (100 / (1 + rs))
    return rsi

def get_ai_insight(ticker, price, rsi, trend):
    if not ai_client:
        return "المؤشرات الفنية قوية، راقب السهم."
    
    prompt = f"أنت محلل مالي خبير في البورصة المصرية. سهم {ticker} سعره الآن {price:.2f} ومؤشر الـ RSI هو {rsi:.0f}. اتجاه السهم حالياً هو {trend}. اعطني نصيحة سريعة جداً (جملة واحدة فقط) بالعامية المصرية بلهجة ذكية ومختصرة، هل نشتري أم ننتظر؟ ولماذا؟ ابدأ النصيحة فوراً بدون مقدمات."
    try:
        response = ai_client.models.generate_content(
            model='gemini-2.0-flash', # التحديث لأحدث نسخة مستقرة في الـ API
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
    print("🔍 جاري البحث عن FCM Token في كل مستخدمين النظام...")
    try:
        # البحث في كل الوثائق داخل كوليكشن users
        users_ref = db.collection('users').stream()
        for user in users_ref:
            user_data = user.to_dict()
            
            # 1. فحص إذا كان التوكين في وثيقة المستخدم مباشرة
            if 'fcmToken' in user_data and user_data['fcmToken']:
                print(f"✅ تم العثور على التوكين في وثيقة اليوزر: {user.id}")
                return user_data['fcmToken']
            
            # 2. فحص كوليكشن investments الفرعي داخل كل يوزر
            invs_ref = db.collection('users').document(user.id).collection('investments').stream()
            for inv in invs_ref:
                inv_data = inv.to_dict()
                if 'fcmToken' in inv_data and inv_data['fcmToken']:
                    print(f"✅ تم العثور على التوكين داخل استثمارات اليوزر: {user.id}")
                    return inv_data['fcmToken']
                    
        print("⚠️ لم يتم العثور على أي fcmToken في قاعدة البيانات.")
    except Exception as e:
        print(f"❌ خطأ أثناء البحث عن التوكين: {e}")
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
        print("⚠️ لم يتم العثور على FCM Token.")
        return

    print("🚀 بدء مسح السوق بمصادر بيانات متعددة...")
    
    for ticker in EGX_30:
        prices, source = get_price_data(ticker)

        if prices is None:
            print(f"❌ فشل جلب بيانات {ticker} من جميع المصادر المتاحة.")
            continue

        try:
            current_price = prices.iloc[-1]
            rsi = calculate_rsi(prices).iloc[-1]
            trend = "صاعد" if current_price > prices.iloc[-5] else "هابط"

            # طباعة السهم ومصدر الداتا بتاعه في اللوج للتأكيد
            print(f"📊 {ticker} | المصدر: {source} | السعر: {current_price:.2f} | RSI: {rsi:.0f}")

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
            print(f"⚠️ خطأ أثناء تحليل {ticker}: {e}")

if __name__ == '__main__':
    scan_market()