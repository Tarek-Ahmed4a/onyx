import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

/// Single Source of Truth for all EGX market data.
///
/// Fetches data ONCE from /api/egx/all and exposes it to
/// both Dashboard and AI Chat via Provider.
class MarketDataService extends ChangeNotifier with WidgetsBindingObserver {
  static const String _baseUrl = 'https://tarekahmed-onyx.hf.space/api';

  MarketDataService() {
    WidgetsBinding.instance.addObserver(this);
    _loadCachedData();
    fetchUserAssets(); // Initial fetch of assets for alerting
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('🚀 MarketDataService: App resumed - Refreshing...');
      fetchAllMarketData(isSilent: true);
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedJson = prefs.getString('cached_market_data');
      if (cachedJson != null) {
        _parseAndSetData(cachedJson);
        debugPrint('📦 MarketDataService: Local cache loaded.');
      }
    } catch (e) {
      debugPrint('⚠️ MarketDataService: Cache load error: $e');
    }
  }

  void _parseAndSetData(String bodyStr) {
    final Map<String, dynamic> body = json.decode(bodyStr);
    final dynamic stocksRaw = body['stocks'];

    final Map<String, dynamic> newMap = {};
    if (stocksRaw is Map) {
      stocksRaw.forEach((ticker, data) {
        if (data is Map) {
          newMap[ticker] = {
            "price": _parseNum(data["price"]),
            "rsi": _parseNum(data["rsi"], defaultVal: 50.0),
            "macd": data["macd"] ?? "Neutral",
            "source": data["source"] ?? "Unknown",
          };
        }
      });
    }

    _stocksData = newMap;
    _lastUpdated = body['last_updated'] as String?;
    notifyListeners();
  }

  /// Cached market data: { "COMI.CA": { "price": 85.5, "rsi": 62.3, "macd": "Bullish..." }, ... }
  Map<String, dynamic> _stocksData = {};
  Map<String, dynamic> get stocksData => _stocksData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastUpdated;
  String? get lastUpdated => _lastUpdated;

  String? _error;
  String? get error => _error;

  bool get hasData => _stocksData.isNotEmpty;

  /// Local cache of user assets for high-performance alert checking.
  List<dynamic> _cachedUserAssets = [];

  /// Fetches all assets from the user's portfolios and caches them.
  /// This should be called once on init and whenever the UI updates investments.
  Future<void> fetchUserAssets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _cachedUserAssets = [];
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('investments')
          .get();

      final List<dynamic> allAssets = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final List<dynamic> assets = data['assets'] ?? [];
        allAssets.addAll(assets);
      }
      _cachedUserAssets = allAssets;
      debugPrint('📦 MarketDataService: Cached ${_cachedUserAssets.length} user assets for alerts.');
    } catch (e) {
      debugPrint('⚠️ MarketDataService: Error caching user assets: $e');
    }
  }

  Timer? _refreshTimer;

  /// Start a periodic refresh of market data.
  void startPeriodicRefresh({int seconds = 60}) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: seconds), (timer) {
      fetchAllMarketData(isSilent: true);
    });
    debugPrint('🚀 MarketDataService: Periodic refresh started ($seconds sec)');
  }

  /// Stop the periodic refresh timer.
  void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    debugPrint('🛑 MarketDataService: Periodic refresh stopped');
  }

  /// Fetch all 30 EGX tickers from the backend in one call.
  /// Set [isSilent] to true to update data without triggering loading UI.
  Future<void> fetchAllMarketData({bool isSilent = false}) async {
    if (!isSilent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/egx/all'))
          .timeout(const Duration(seconds: 45)); // Extended timeout

      if (response.statusCode == 200) {
        // Wrap everything else in its own try-catch for granular failure handling
        try {
          final Map<String, dynamic> body = json.decode(response.body);
          final dynamic stocksRaw = body['stocks'];

          final Map<String, dynamic> newMap = {};

          if (stocksRaw is Map) {
            stocksRaw.forEach((ticker, data) {
              try {
                if (data is Map) {
                  newMap[ticker] = {
                    "price": _parseNum(data["price"]),
                    "rsi": _parseNum(data["rsi"], defaultVal: 50.0),
                    "macd": data["macd"] ?? "Neutral",
                    "source": data["source"] ?? "Unknown",
                  };
                }
              } catch (e) {
                debugPrint('⚠️ MarketDataService skipping ticker $ticker: $e');
              }
            });
          }

          _stocksData = newMap;
          _lastUpdated = body['last_updated'] as String?;
          _error = null;

          // Save for offline/instant-on
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_market_data', response.body);

          debugPrint(
              '✅ MarketDataService: Loaded ${_stocksData.length} tickers');
        } catch (je) {
          _error = 'JSON Parsing Error: $je';
          debugPrint('❌ MarketDataService JSON Error: $je');
          // Don't clear _stocksData here to keep stale data visible
        }
      } else {
        _error = 'Server returned ${response.statusCode}';
        debugPrint('❌ MarketDataService: $_error');
      }
    } catch (e) {
      _error = 'Connection error: $e';
      debugPrint('❌ MarketDataService fetch error: $e');
    }

    _isLoading = false;
    notifyListeners();

    // Perform high-performance alert check using local cache (No Firestore Reads)
    if (_stocksData.isNotEmpty) {
      final notificationService = NotificationService();
      // 1. Check general market technical signals (RSI/MACD)
      notificationService.checkMarketSignals(_stocksData);
      
      // 2. Check specific price alerts for cached assets
      if (_cachedUserAssets.isNotEmpty) {
        notificationService.checkPriceAlerts(_stocksData, _cachedUserAssets);
      }
    }
  }

  /// Get cached data for a specific ticker.
  /// Returns null if ticker not found.
  Map<String, dynamic>? getStockData(String ticker) {
    if (_stocksData.containsKey(ticker)) {
      return Map<String, dynamic>.from(_stocksData[ticker]);
    }
    return null;
  }

  /// Build the <FULL_MARKET_SCAN> XML context string for Gemini injection.
  /// Uses cached data — zero HTTP calls.
  String buildFullMarketScanContext() {
    if (_stocksData.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('<FULL_MARKET_SCAN>');

    _stocksData.forEach((ticker, info) {
      if (info is Map) {
        final price = info['price'] ?? '?';
        final rsi = info['rsi'] ?? '?';
        final macd = info['macd'] ?? 'Unknown';
        buffer.write('$ticker: Price=$price, RSI=$rsi, MACD=$macd | ');
      }
    });

    buffer.writeln('\n</FULL_MARKET_SCAN>');
    return buffer.toString();
  }

  /// Builds a concise, pre-filtered market scan for the AI to save tokens.
  /// Only includes stocks with:
  /// - RSI <= 35 (Oversold)
  /// - RSI >= 70 (Overbought)
  /// - MACD status containing "bullish" or "bearish"
  String generateOptimizedMarketScan() {
    if (_stocksData.isEmpty) return '';

    final List<String> signals = [];

    _stocksData.forEach((ticker, info) {
      if (info is Map) {
        final double rsi =
            (info['rsi'] is num) ? (info['rsi'] as num).toDouble() : 50.0;
        final String macd = (info['macd'] as String? ?? '').toLowerCase();

        final bool isOversold = rsi <= 35;
        final bool isOverbought = rsi >= 70;
        final bool isMacdSignal =
            macd.contains('bullish') || macd.contains('bearish');

        if (isOversold || isOverbought || isMacdSignal) {
          signals.add('$ticker: RSI=${rsi.toStringAsFixed(1)},MACD=$macd');
        }
      }
    });

    if (signals.isEmpty) {
      return '<FULL_MARKET_SCAN> Market neutral. No strong technical signals today. </FULL_MARKET_SCAN>';
    }

    return '<FULL_MARKET_SCAN> ${signals.join(' | ')} </FULL_MARKET_SCAN>';
  }

  /// Build <MARKET_DATA_INTERNAL> for a specific ticker from cache.
  /// Used when the user mentions a specific stock in chat.
  String buildMarketDataContext(String ticker) {
    final data = getStockData(ticker);
    if (data == null) return '';

    final price = data['price'] ?? '?';
    final rsi = data['rsi'] ?? '?';
    final macd = data['macd'] ?? 'Unknown';

    final context =
        '[SYSTEM CONTEXT] ASSET: $ticker | LIVE PRICE: $price | TECHNICALS: RSI = $rsi, MACD = $macd [END CONTEXT]';

    return '<MARKET_DATA_INTERNAL>\n$context\n</MARKET_DATA_INTERNAL>';
  }

  /// Safely converts dynamic data into a double, handling "NaN", "N/A" and nulls.
  double _parseNum(dynamic value, {double defaultVal = 0.0}) {
    if (value == null || value == "N/A") return defaultVal;

    double? result;
    if (value is num) {
      result = value.toDouble();
    } else if (value is String) {
      if (value.toLowerCase() == 'nan') return defaultVal;
      result = double.tryParse(value);
    }

    // Check for NaN or Infinity which can break Dart's internal double operations
    if (result == null || result.isNaN || result.isInfinite) {
      return defaultVal;
    }

    return result;
  }
}
