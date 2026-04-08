const admin = require("firebase-admin");
const axios = require("axios");

// 1. Initialize Firebase Admin
if (!process.env.FIREBASE_SERVICE_ACCOUNT) {
  console.error("❌ FIREBASE_SERVICE_ACCOUNT environment variable is missing!");
  process.exit(1);
}

try {
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log("✅ Firebase Admin initialized.");
} catch (error) {
  console.error("❌ Failed to initialize Firebase Admin:", error);
  process.exit(1);
}

const db = admin.firestore();

/**
 * Main function to run the scanner.
 */
async function runScanner() {
  try {
    console.log("🚀 Starting ONYX Market Scanner (GitHub Actions)...");

    // 2. Fetch Live Market Data
    const response = await axios.get("https://tarekahmed-onyx.hf.space/api/egx/all");
    if (response.status !== 200) {
      throw new Error(`API returned ${response.status}`);
    }

    const marketData = response.data.stocks;
    if (!marketData) {
      console.log("⚠️ No market data found.");
      return;
    }

    // 3. Cleanup Old Market Signals (Older than 24h)
    await cleanupOldSignals();

    // 4. Process Individual User Alerts (Target Price & Stop Loss)
    await processUserAlerts(marketData);

    // 5. Process Global Market Screener (Opportunity Radar)
    await processMarketScreener(marketData);

    console.log("✅ Market Scanner completed successfully.");
  } catch (error) {
    console.error("❌ Scanner Error:", error);
    process.exit(1);
  }
}

/**
 * Deletes market signals older than 24 hours.
 */
async function cleanupOldSignals() {
  console.log("🧹 Cleaning up old market signals (24h+)...");
  const yesterday = new Date();
  yesterday.setHours(yesterday.getHours() - 24);

  try {
    const oldSnapshot = await db
      .collection("market_signals")
      .where("timestamp", "<", yesterday)
      .get();

    if (oldSnapshot.empty) {
      console.log("✅ No old signals found.");
      return;
    }

    const batch = db.batch();
    oldSnapshot.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    console.log(`✅ Deleted ${oldSnapshot.size} stale signals.`);
  } catch (error) {
    console.error("⚠️ Cleanup Error:", error);
  }
}

/**
 * Checks all users' investments for target price and stop loss triggers.
 */
async function processUserAlerts(marketData) {
  console.log("📊 Processing User Alerts...");
  const usersSnapshot = await db.collection("users").get();

  for (const userDoc of usersSnapshot.docs) {
    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;
    if (!fcmToken) continue;

    const userId = userDoc.id;
    const investmentsSnapshot = await db.collection("users").doc(userId).collection("investments").get();

    for (const portfolioDoc of investmentsSnapshot.docs) {
      const assets = portfolioDoc.data().assets || [];

      for (const asset of assets) {
        const ticker = asset.name;
        if (!ticker || !marketData[ticker]) continue;

        const liveData = marketData[ticker];
        const currentPrice = parseFloat(liveData.price);
        const targetPrice = parseFloat(asset.takeProfit);
        const stopLoss = parseFloat(asset.stopLoss);

        // Check Target Price
        if (targetPrice && currentPrice >= targetPrice) {
          await sendPushNotification(fcmToken, {
            title: `🎯 Target Reached: ${ticker}`,
            body: `${ticker} reached your target price of ${currentPrice}!`,
            data: { ticker, type: "TARGET_PRICE" }
          });
        }
        // Check Stop Loss
        else if (stopLoss && currentPrice <= stopLoss) {
          await sendPushNotification(fcmToken, {
            title: `⚠️ Stop Loss Triggered: ${ticker}`,
            body: `${ticker} dropped to ${currentPrice}. Consider checking your portfolio.`,
            data: { ticker, type: "STOP_LOSS" }
          });
        }
      }
    }
  }
}

/**
 * Scans all stocks for "Alpha" signals and broadcasts to the global topic.
 */
async function processMarketScreener(marketData) {
  console.log("🔍 Running Market Screener...");
  const signals = [];

  for (const ticker in marketData) {
    const data = marketData[ticker];
    const price = parseFloat(data.price);
    const rsi = parseFloat(data.rsi);
    const macd = (data.macd || "").toLowerCase();
    
    // Note: Volume Spike and 52-week breakout require historical data.
    const volume = parseFloat(data.volume || 0);
    const avgVolume = parseFloat(data.avgVolume10d || 0);
    const high52w = parseFloat(data.high52w || 0);

    // RSI Reversal Logic
    if (rsi < 30 && macd.includes("bullish")) {
      signals.push({
        ticker,
        type: "RSI_REVERSAL",
        message: `${ticker} is oversold (RSI: ${rsi.toFixed(1)}) with a bullish MACD crossover. Potential reversal.`,
        value: rsi.toFixed(1)
      });
    }

    // Volume Spike Logic
    if (avgVolume > 0 && volume > avgVolume * 3) {
      signals.push({
        ticker,
        type: "VOLUME_SPIKE",
        message: `${ticker} is seeing unusual activity! Volume is ${(volume / avgVolume).toFixed(1)}x the average.`,
        value: `${(volume / avgVolume).toFixed(1)}x`
      });
    }

    // Price Breakout Logic
    if (high52w > 0 && price >= high52w) {
      signals.push({
        ticker,
        type: "PRICE_BREAKOUT",
        message: `${ticker} just broke its 52-week high! Strong bullish momentum detected.`,
        value: price.toFixed(2)
      });
    }
  }

  // Broadcast signals and save to Firestore
  for (const signal of signals) {
    const signalData = {
      ...signal,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };

    // 1. Save to History
    await db.collection("market_signals").add(signalData);

    // 2. Broadcast to Topic
    await admin.messaging().send({
      topic: "market_opportunities",
      notification: {
        title: `🚀 Signal: ${signal.ticker}`,
        body: signal.message
      },
      data: {
        ticker: signal.ticker,
        type: signal.type,
        click_action: "FLUTTER_NOTIFICATION_CLICK"
      }
    });
    console.log(`📡 Signal broadcasted for ${signal.ticker}`);
  }
}

async function sendPushNotification(token, payload) {
  try {
    await admin.messaging().send({
      token: token,
      notification: {
        title: payload.title,
        body: payload.body
      },
      data: payload.data
    });
    console.log(`🔔 Notification sent to token: ${token.substring(0, 10)}...`);
  } catch (error) {
    console.error("❌ FCM Error:", error);
  }
}

// Start the scanner
runScanner();
