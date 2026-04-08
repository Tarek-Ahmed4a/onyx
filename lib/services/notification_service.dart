import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  FlutterLocalNotificationsPlugin get plugin => _notificationsPlugin;

  final Map<String, DateTime> _lastNotified = {};
  final Map<String, double> _lastTriggeredValue = {};

  Future<void> subscribeToMarketOpportunities() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('market_opportunities');
      debugPrint("🚀 Successfully subscribed to market_opportunities topic.");
    } catch (e) {
      debugPrint("❌ Failed to subscribe to market_opportunities: $e");
    }
  }

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

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

    // Request Android permissions for exact alarms and notifications
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();
  }

  // ==========================================
  // 🔘 LOCAL TASK ALERTS (Offline-First)
  // ==========================================

  Future<void> scheduleTaskReminder(String id, String title, DateTime scheduledAt) async {
    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(scheduledAt, tz.local);

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    try {
      await _notificationsPlugin.zonedSchedule(
        id.hashCode,
        'Task Reminder',
        title,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders_channel',
            'Task Reminders',
            channelDescription: 'Notifications for scheduled tasks',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Critical for offline precise background wakeup
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Error scheduling task reminder: $e');
    }
  }

  Future<void> cancelTaskReminder(String id) async {
    await _notificationsPlugin.cancel(id.hashCode);
  }

  // ==========================================
  // 🌍 REMOTE MARKET SIGNALS (Needs Internet)
  // ==========================================

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

  /* DEPRECATED: Handled by Cloud Functions 
  Future<void> checkMarketSignals(Map<String, dynamic> livePrices) async {
    ...
  }
  */
}
