import firebase_admin
from firebase_admin import credentials, firestore, messaging
import yfinance as yf

# الربط بفايربيز
cred = credentials.Certificate('firebase-key.json')
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

def check_prices():
    print("🔍 بتصل بقاعدة البيانات...")
    
    assets_ref = db.collection_group('investments') 
    docs = list(assets_ref.stream())

    if not docs:
        print("⚠️ الداتابيز لسه فاضية!")
        return

    print(f"✅ لقيت {len(docs)} بروفايل في الداتابيز. ببدأ الفحص...\n")

    for doc in docs:
        profile_data = doc.to_dict()
        assets_list = profile_data.get('assets', []) 
        
        if not assets_list:
            continue
            
        for asset in assets_list:
            ticker = asset.get('name') 
            token = asset.get('fcmToken')
            target = asset.get('takeProfit')
            stop_loss = asset.get('stopLoss')
            
            if not ticker:
                continue
            if not token:
                print(f"❌ سهم {ticker} مفيهوش 'fcmToken'. عامل سكيب.")
                continue

            print(f"⏳ بسحب السعر لسهم {ticker} من ياهو فاينانس...")
            try:
                stock = yf.Ticker(ticker)
                
                # 🔥 التعديل هنا: هنسحب آخر 5 أيام بدل يوم واحد
                hist = stock.history(period='5d')
                
                # حماية: لو ياهو مرجعش داتا خالص
                if hist.empty:
                    print(f"⚠️ ياهو فاينانس مرجعش أي بيانات لسهم {ticker}. ممكن الكود غلط.")
                    print("-" * 30)
                    continue
                    
                current_price = hist['Close'].iloc[-1]
                print(f"📈 السعر الحي: {current_price:.2f} | التارجت: {target}")

                if target and current_price >= target:
                    print("🎯 السعر عدى التارجت! ببعت الإشعار للموبايل...")
                    send_push(token, "🎯 الهدف تحقق!", f"سهم {ticker} وصل لسعر {current_price:.2f}")
                elif stop_loss and current_price <= stop_loss:
                    print("🛡️ السعر نزل لوقف الخسارة! ببعت الإشعار للموبايل...")
                    send_push(token, "🛡️ تنبيه وقف الخسارة!", f"سهم {ticker} نزل لسعر {current_price:.2f}")
                else:
                    print("⏳ السعر لسه موصلش لأي تارجت.")
                    
            except Exception as e:
                print(f"⚠️ حصلت مشكلة في سحب سعر {ticker}: {e}")
            
            print("-" * 30)

def send_push(token, title, body):
    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        token=token,
    )
    try:
        response = messaging.send(message)
        print(f"✅ الإشعار وصل للموبايل بنجاح! كود العملية: {response}")
    except Exception as e:
        print(f"❌ فشل إرسال الإشعار: {e}")

if __name__ == '__main__':
    check_prices()