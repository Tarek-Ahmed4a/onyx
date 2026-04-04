import os
import sys
import json
import time
import logging
import firebase_admin
from firebase_admin import credentials, firestore, messaging
import yfinance as yf
import pandas as pd
from google import genai
from google.genai import types
from datetime import datetime
from tvDatafeed import TvDatafeed, Interval

# 1. Strict Initialization Sequence
firebase_creds_str = os.environ.get('FIREBASE_CREDENTIALS')
if not firebase_creds_str:
    print("❌ خطأ: متغير البيئة FIREBASE_CREDENTIALS غير موجود.")
    sys.exit(1)

try:
    creds_dict = json.loads(firebase_creds_str)
    print(f"🔑 جاري الاتصال بمشروع Firebase: {creds_dict.get('project_id')}")
except json.JSONDecodeError as e:
    print(f"❌ خطأ في تحليل JSON الخاص ببيانات الاعتماد: {e}")
    sys.exit(1)

cred = credentials.Certificate(creds_dict)
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)

db = firestore.client()

# 2. Diagnostic Radar
try:
    print("📡 جاري فحص الاتصال بقاعدة البيانات (Diagnostic Radar)...")
    users_docs = list(db.collection('users').stream())
    users_count = len(users_docs)
    print(f"👥 إجمالي عدد المستخدمين في مجموعة 'users': {users_count}")
    
    if users_count == 0:
        print("⚠️ تحذير حرج: قاعدة البيانات فارغة أو أن بيانات الاعتماد تشير إلى المشروع الخاطئ!")
except Exception as e:
    print(f"❌ خطأ أثناء الاتصال بقاعدة البيانات: {e}")

# كتم رسائل التحذير الخاصة بمكتبة TradingView عشان اللوج يكون نظيف
logging.getLogger('tvDatafeed').setLevel(logging.ERROR)

# --- الإعدادات ---
try:
    ai_client = genai.Client(api_key=os.environ.get('GEMINI_API_KEY'))
except Exception as e:
    print(f"⚠️ خطأ في تهيئة Gemini: {e}")
    ai_client = None

# تهيئة الاتصال بـ TradingView كضيف (بدون حساب)
tv_client = TvDatafeed()

EGX_30 = [
    'COMI.CA', 'FWRY.CA', 'TMGH.CA', 'HRHO.CA', 'EKHO.CA', 'ABUK.CA', 'MFPC.CA', 
    'SWDY.CA', 'ETEL.CA', 'EFIH.CA', 'SKPC.CA', 'AMOC.CA', 'PHDC.CA', 'MASR.CA', 
    'ORWE.CA', 'HELI.CA', 'JUFO.CA', 'CLHO.CA', 'ISPH.CA', 'ADIB.CA', 
    'CIRA.CA', 'EAST.CA', 'AMER.CA', 'CCAP.CA', 'EKHOA.CA', 
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
    
    prompt = f"سهم {ticker} سعره الآن {price:.2f} ومؤشر الـ RSI هو {rsi:.0f}. اتجاه السهم حالياً هو {trend}. اعطني نصيحة سريعة جداً (جملة واحدة فقط) بالعامية المصرية بلهجة ذكية ومختصرة، هل نشتري أم ننتظر؟ ولماذا؟ ابدأ النصيحة فوراً بدون مقدمات."
    system_instruction = "You are a senior technical analyst for the Egyptian Exchange (EGX). Analyze the provided Price and RSI. Provide a concise, professional 'Buy/Sell/Hold' recommendation based on oversold/overbought conditions (RSI < 30 is oversold, > 70 is overbought)."
    
    for attempt in range(2):
        try:
            response = ai_client.models.generate_content(
                model='gemini-3.1-pro',
                contents=prompt,
                config=types.GenerateContentConfig(
                    system_instruction=system_instruction,
                    temperature=0.4,
                    top_p=0.9
                )
            )
            return response.text.strip()
        except Exception as e:
            if "429" in str(e) or "RESOURCE_EXHAUSTED" in str(e):
                if attempt == 0:
                    print(f"⏳ وصول للحد الأقصى لطلبات Gemini (429). سننتظر 10 ثوانٍ والمحاولة مرة أخرى...")
                    time.sleep(10)
                    continue
            print(f"⚠️ خطأ Gemini مع {ticker}: {e}")
            break
            
    return "تحليل فني بناءً على المؤشرات الحالية."

def deep_search_token(data):
    """دالة بحث عميق بتلف جوه أي نوع بيانات لحد ما تلاقي التوكين"""
    if isinstance(data, dict):
        if 'fcmToken' in data and data['fcmToken']:
            return str(data['fcmToken']).strip()
        for v in data.values():
            res = deep_search_token(v)
            if res: return res
            
    elif isinstance(data, list):
        for item in data:
            res = deep_search_token(item)
            if res: return res
            
    elif isinstance(data, str):
        # لو فلاتر حفظ الداتا كنص، البايثون هيعملها Decode ويدور جواها
        if 'fcmToken' in data:
            try:
                parsed = json.loads(data)
                res = deep_search_token(parsed)
                if res: return res
            except:
                pass
    return None

def get_fcm_token():
    print("🔍 جاري البحث المباشر بـ Collection Group...")
    try:
        # السر هنا: استخدام collection_group عشان نتخطى الوثائق الوهمية
        invs_ref = db.collection_group('investments').stream()
        count = 0
        
        for inv in invs_ref:
            count += 1
            # بنبعت الداتا لدالة البحث العميق اللي عملناها
            token = deep_search_token(inv.to_dict())
            if token:
                print("✅ تم العثور على التوكين بنجاح!")
                return token
                
        print(f"⚠️ تم فحص {count} وثيقة استثمار، التوكين مش موجود جواهم.")
    except Exception as e:
        print(f"❌ خطأ أثناء البحث عن التوكين: {e}")
    return None

# -- استبدل جزء الرادار اللي تحت خالص بده --
print("📡 (Diagnostic Radar) جاري فحص الاتصال بقاعدة البيانات...")
try:
    all_invs = list(db.collection_group('investments').stream())
    print(f"📊 إجمالي وثائق الاستثمار المكتشفة: {len(all_invs)}")
except Exception as e:
    print(f"❌ خطأ في الاتصال: {e}")

def send_push(token, title, body):
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            token=token,
        )
        messaging.send(message)
        print(f"✅ تم إرسال الإشعار بنجاح: {title}")
    except Exception as e:
        if "Requested entity was not found" in str(e):
            print("⚠️ التوكين الحالي غير صالح أو منتهي الصلاحية. برجاء فتح التطبيق من الموبايل لتحديث التوكين.")
        else:
            print(f"⚠️ خطأ Firebase في إرسال الإشعار: {e}")

def scan_market():
    token = get_fcm_token()
    if not token:
        print("⚠️ لم يتم العثور على FCM Token.")
        return

    print("🚀 بدء مسح السوق بمصادر بيانات متعددة...")
    market_summary = {}

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

            market_summary[ticker] = {
                "price": round(float(current_price), 2),
                "rsi": round(float(rsi), 0)
            }

            alert_type = None
            if rsi < 30:
                alert_type = 'BUY'
                title = f"💡 فرصة شراء: {ticker}"
            elif rsi > 70:
                alert_type = 'SELL'
                title = f"⚠️ جني أرباح: {ticker}"

            if alert_type:
                # Smart Deduplication Check
                history_docs = db.collection('alerts_history').where('ticker', '==', ticker).stream()
                
                last_record = None
                latest_time = None
                for doc in history_docs:
                    data = doc.to_dict()
                    ts = data.get('timestamp')
                    if ts is not None:
                        if latest_time is None:
                            latest_time = ts
                            last_record = data
                        else:
                            try:
                                if ts > latest_time:
                                    latest_time = ts
                                    last_record = data
                            except TypeError:
                                pass

                # Compare with last record
                if last_record and 'price' in last_record and 'rsi' in last_record:
                    if round(last_record['price'], 2) == round(current_price, 2) and round(last_record['rsi'], 0) == round(rsi, 0):
                        print(f"ℹ️ لم يتغير السعر أو RSI لـ {ticker}، لن يتم إرسال إشعار مكرر.")
                        continue
                        
                ai_advice = get_ai_insight(ticker, current_price, rsi, trend)
                send_push(token, title, ai_advice)
                
                # IMMEDIATELY AFTER: Save the new state
                db.collection('alerts_history').add({
                    'ticker': ticker,
                    'type': alert_type,
                    'price': round(current_price, 2),
                    'rsi': round(rsi, 0),
                    'timestamp': firestore.SERVER_TIMESTAMP
                })
                
                # Strict rate limiting for Gemini-3.1-pro
                time.sleep(10)
            
            time.sleep(1)
        except Exception as e:
            print(f"⚠️ خطأ أثناء تحليل {ticker}: {e}")

    try:
        db.collection('market_status').document('latest').set({
            "stocks": market_summary,
            "last_updated": firestore.SERVER_TIMESTAMP
        })
        print("✅ تم رفع حالة السوق (Market Status) بنجاح.")
    except Exception as e:
        print(f"⚠️ فشل تحديث حالة السوق: {e}")

    # إرسال إشعار حالة نهائي بعد الانتهاء من فحص جميع الأسهم
    send_push(token, "نظام ONYX", "✅ تم فحص السوق بالكامل بنجاح")

if __name__ == '__main__':
    scan_market()