const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

const db = admin.firestore();

/**
 * Periodically monitors the EGX market during active hours.
 * Schedule: Every 10 minutes, Sunday to Thursday, from 10:00 to 14:30 Cairo Time.
 * Note: Firebase schedule uses UTC. Cairo is UTC+2 or UTC+3 (DST).
 * Cairo 10:00-14:30 is approx 08:00-12:30 UTC (Standard) or 07:00-11:30 UTC (DST).
 */
exports.monitorMarket = functions.pubsub
  .schedule("every 10 minutes from 10:00 to 15:00")
  .timeZone("Africa/Cairo")
  .onRun(async (context) => {
    try {
      console.log("🚀 Starting ONYX Market Monitor...");

      // 1. Fetch Live Market Data
      const response = await axios.get("https://tarekahmed-onyx.hf.space/api/egx/all");
      if (response.status !== 200) {
        throw new Error(`API returned ${response.status}`);
      }

      const marketData = response.data.stocks; // { "COMI.CA": { price, rsi, macd, ... }, ... }
      if (!marketData) return null;

      // 2. Process Individual User Alerts (Target Price & Stop Loss)
      await processUserAlerts(marketData);

      // 3. Process Global Market Screener (Opportunity Radar)
      await processMarketScreener(marketData);

      console.log("✅ Market Monitor completed successfully.");
    } catch (error) {
      console.error("❌ Market Monitor Error:", error);
    }
    return null;
  });

/**
 * Checks all users' investments for target price and stop loss triggers.
 */
async function processUserAlerts(marketData) {
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
  const signals = [];

  for (const ticker in marketData) {
    const data = marketData[ticker];
    const price = parseFloat(data.price);
    const rsi = parseFloat(data.rsi);
    const macd = (data.macd || "").toLowerCase();
    
    // Note: Volume Spike and 52-week breakout require historical data.
    // If the API doesn't provide it, we use placeholders or RSI/MACD logic.
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
        message: `${ticker} is seeing unusual activity! Volume is ${ (volume / avgVolume).toFixed(1) }x the average.`,
        value: `${ (volume / avgVolume).toFixed(1) }x`
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
  } catch (error) {
    console.error("FCM Error:", error);
  }
}
