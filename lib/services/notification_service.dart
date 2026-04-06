import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  FlutterLocalNotificationsPlugin get plugin => _notificationsPlugin;

  final Map<String, DateTime> _lastNotified = {};
  final Map<String, double> _lastTriggeredValue = {};

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification clicked: ${details.payload}');
      },
    );
  }

  /// Determines if a notification should be triggered based on time cooldown
  /// and price movement thresholds to prevent spam.
  bool _shouldNotify(String key, double currentValue) {
    final now = DateTime.now();
    
    if (!_lastNotified.containsKey(key)) return true;

    final lastTime = _lastNotified[key]!;
    final lastValue = _lastTriggeredValue[key]!;

    // Case 1: Cooled down after 30 minutes
    final isCooledDown = now.difference(lastTime) > const Duration(minutes: 30);
    
    // Case 2: Price moved away significantly (1%) from previous trigger
    // This allows re-notifying if the volatility is high regardless of time.
    final isPriceMoved = (currentValue - lastValue).abs() / lastValue > 0.01;

    return isCooledDown || isPriceMoved;
  }

  void _recordNotification(String key, double value) {
    _lastNotified[key] = DateTime.now();
    _lastTriggeredValue[key] = value;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'onyx_alerts_channel',
      'Market Alerts',
      channelDescription: 'Notifications for market signals and portfolio alerts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(id, title, body, details, payload: payload);
  }

  Future<void> zonedSchedule(
    int id,
    String title,
    String body,
    tz.TZDateTime scheduledDate,
    NotificationDetails details, {
    required AndroidScheduleMode androidScheduleMode,
    required UILocalNotificationDateInterpretation uiLocalNotificationDateInterpretation,
    String? payload,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: androidScheduleMode,
      uiLocalNotificationDateInterpretation: uiLocalNotificationDateInterpretation,
      payload: payload,
    );
  }

  Future<void> cancel(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Checks a list of user assets against live market data and triggers notifications.
  Future<void> checkPriceAlerts(Map<String, dynamic> livePrices, List<dynamic> userAssets) async {
    for (var asset in userAssets) {
      final ticker = asset['name'] as String?;
      if (ticker == null || !livePrices.containsKey(ticker)) continue;

      final data = livePrices[ticker];
      final double currentPrice = (data['price'] as num?)?.toDouble() ?? 0.0;
      final double? takeProfit = (asset['takeProfit'] as num?)?.toDouble();
      final double? stopLoss = (asset['stopLoss'] as num?)?.toDouble();

      // Take Profit Check
      if (takeProfit != null && currentPrice >= takeProfit) {
        final key = '${ticker}_TP';
        if (_shouldNotify(key, currentPrice)) {
          await showNotification(
            id: ticker.hashCode + 3,
            title: "🎯 الهدف اتحقق: $ticker",
            body: "سهم $ticker وصل لسعر البيع اللي حددته ($currentPrice)!",
            payload: ticker,
          );
          _recordNotification(key, currentPrice);
        }
      } 
      // Stop Loss Check
      else if (stopLoss != null && currentPrice <= stopLoss) {
        final key = '${ticker}_SL';
        if (_shouldNotify(key, currentPrice)) {
          await showNotification(
            id: ticker.hashCode + 4,
            title: "⚠️ وقف خسارة: $ticker",
            body: "سهم $ticker نزل تحت الحد اللي حددته ($currentPrice)! راجع محفظتك.",
            payload: ticker,
          );
          _recordNotification(key, currentPrice);
        }
      }
    }
  }

  /// Checks for general market signals (RSI/MACD).
  Future<void> checkMarketSignals(Map<String, dynamic> livePrices) async {
    for (var ticker in livePrices.keys) {
      final info = livePrices[ticker];
      if (info == null) continue;

      final double rsi = (info['rsi'] as num?)?.toDouble() ?? 50.0;
      final String macd = (info['macd'] as String? ?? '').toLowerCase();

      // Optimized Buy Signal: RSI < 35 AND Bullish MACD
      if (rsi < 35 && macd.contains('bullish')) {
        final key = '${ticker}_BUY';
        if (_shouldNotify(key, rsi)) {
          await showNotification(
            id: ticker.hashCode + 1,
            title: "🟢 فرصة شراء: $ticker",
            body: "سهم $ticker مؤشراته بتقول إنه في منطقة دخول كويسة دلوقتى.",
            payload: ticker,
          );
          _recordNotification(key, rsi);
        }
      } 
      // Optimized Sell Signal: RSI > 75 AND Bearish MACD
      else if (rsi > 75 && macd.contains('bearish')) {
        final key = '${ticker}_SELL';
        if (_shouldNotify(key, rsi)) {
          await showNotification(
            id: ticker.hashCode + 2,
            title: "🔴 فرصة بيع: $ticker",
            body: "سهم $ticker دخل منطقة التشبع، فكر في جني الأرباح.",
            payload: ticker,
          );
          _recordNotification(key, rsi);
        }
      }
    }
  }
}
