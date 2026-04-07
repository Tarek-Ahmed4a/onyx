import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import 'package:logger/logger.dart';

final logger = Logger();

const String kTaskScanner = "com.onyx.marketScanner";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // 1. Check if alerts are enabled in settings
      final prefs = await SharedPreferences.getInstance();
      final alertsEnabled = prefs.getBool('background_alerts_enabled') ?? true;
      if (!alertsEnabled) return Future.value(true);

      // 2. Initialize Firebase (needed for Firestore/Auth)
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return Future.value(true);

      // 3. Fetch Market Data
      const String marketUrl = 'https://tarekahmed-onyx.hf.space/api/egx/all';
      final response = await http
          .get(Uri.parse(marketUrl))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return Future.value(false);

      final data = json.decode(response.body);
      final Map<String, dynamic> stocks = data['stocks'] ?? {};

      // Save for instant-on when user reopens app
      await prefs.setString('cached_market_data', response.body);

      // Initialize Notifications
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
            android: androidSettings, iOS: iosSettings),
      );

      // 4. Fetch User Portfolio
      final portfolios = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('investments')
          .get();

      // 5. Scan and Notify
      for (var ticker in stocks.keys) {
        final info = stocks[ticker];
        final double price = (info['price'] as num?)?.toDouble() ?? 0.0;
        final double rsi = (info['rsi'] as num?)?.toDouble() ?? 0.0;
        final String macd = (info['macd'] as String? ?? '').toLowerCase();

        // Check Market Wide Signals
        if (rsi <= 35 && (macd.contains('bullish'))) {
          await _showNotification(
            flutterLocalNotificationsPlugin,
            "🟢 فرصة شراء",
            "سهم $ticker مؤشراته ممتازة للدخول دلوقتي!",
            ticker.hashCode + 1,
          );
        } else if (rsi >= 70 &&
            (macd.contains('bearish') || macd.contains('weakening'))) {
          await _showNotification(
            flutterLocalNotificationsPlugin,
            "🔴 فرصة بيع/جني أرباح",
            "سهم $ticker وصل لمناطق تشبع شرائي!",
            ticker.hashCode + 2,
          );
        }

        // Check Portfolio Alerts
        for (var doc in portfolios.docs) {
          final pData = doc.data();
          final List<dynamic> assets = pData['assets'] ?? [];
          for (var asset in assets) {
            if (asset['name'] == ticker) {
              final tp = (asset['takeProfit'] as num?)?.toDouble();
              final sl = (asset['stopLoss'] as num?)?.toDouble();

              if (tp != null && price >= tp) {
                await _showNotification(
                  flutterLocalNotificationsPlugin,
                  "🎯 حقق الهدف",
                  "سهم $ticker وصل لسعر البيع اللي حددته ($price)!",
                  ticker.hashCode + 3,
                );
              } else if (sl != null && price <= sl) {
                await _showNotification(
                  flutterLocalNotificationsPlugin,
                  "⚠️ وقف خسارة",
                  "سهم $ticker نزل عن الحد المسموح ($price)، راجع محفظتك!",
                  ticker.hashCode + 4,
                );
              }
            }
          }
        }
      }

      return Future.value(true);
    } catch (e) {
      logger.e("Background Task Error", error: e);
      return Future.value(false);
    }
  });
}

Future<void> _showNotification(FlutterLocalNotificationsPlugin plugin,
    String title, String body, int id) async {
  const androidDetails = AndroidNotificationDetails(
    'onyx_alerts_channel',
    'Market Alerts',
    channelDescription: 'Notifications for market signals and portfolio alerts',
    importance: Importance.high,
    priority: Priority.high,
  );
  const iosDetails = DarwinNotificationDetails();
  const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

  await plugin.show(id, title, body, details);
}

class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      "1",
      kTaskScanner,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}
