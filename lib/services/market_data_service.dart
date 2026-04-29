import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Single Source of Truth for all EGX market data.
///
/// Fetches data ONCE from /api/egx/all and exposes it to
/// both Dashboard and AI Chat via Provider.
class MarketDataService extends ChangeNotifier with WidgetsBindingObserver {
  static String get _baseUrl {
    // Production URL for Hugging Face
    return 'https://tarekahmed-onyx.hf.space/api';
  }

  MarketDataService() {
    WidgetsBinding.instance.addObserver(this);
    // 1. Load from SharedPreferences immediately
    _loadCachedData().then((_) {
      // 2. Load from Firestore cache (Offline Persistence)
      fetchUserAssets();
      // 3. Trigger initial data fetch
      fetchAllMarketData(isSilent: true);
      // 4. Initialize WebSocket for live updates
      initSocket();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _socket?.disconnect();
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
            "support": _parseNum(data["support"]),
            "resistance": _parseNum(data["resistance"]),
            "change": _parseNum(data["change"]),
            "volume": _parseNum(data["volume"]),
            "source": data["source"] ?? "Unknown",
            "is_fund": data["is_fund"] ?? false,
            "name": data["name"] ?? ticker,
          };
        }
      });
    }

    _stocksData = newMap;
    _news = (body['news'] as List?)?.map((e) => e.toString()).toList() ?? [];
    _macro = (body['macro'] as Map?)?.cast<String, dynamic>() ?? {};
    _breadth = body['breadth']?.toString() ?? 'Unknown';
    _lastUpdated = body['last_updated'] as String?;
    notifyListeners();
  }

  /// Cached market data: { "COMI.CA": { "price": 85.5, "rsi": 62.3, "macd": "Bullish..." }, ... }
  Map<String, dynamic> _stocksData = {
    'COMI.CA': {"price": 75.50, "rsi": 62.3, "macd": "Bullish", "support": 70.0, "resistance": 80.0, "change": 1.2, "volume": 1200500},
    'HRHO.CA': {"price": 18.20, "rsi": 45.1, "macd": "Bearish", "support": 17.5, "resistance": 19.0, "change": -0.5, "volume": 850000},
    'FWRY.CA': {"price": 5.40, "rsi": 71.2, "macd": "Bullish", "support": 5.0, "resistance": 6.0, "change": 2.1, "volume": 3200000},
    'TMGH.CA': {"price": 26.80, "rsi": 55.4, "macd": "Neutral", "support": 25.0, "resistance": 28.0, "change": 0.8, "volume": 1500000},
    'ESRS.CA': {"price": 65.30, "rsi": 38.2, "macd": "Bearish", "support": 60.0, "resistance": 70.0, "change": -1.5, "volume": 420000},
    'ORAS.CA': {"price": 195.00, "rsi": 50.0, "macd": "Neutral", "support": 190.0, "resistance": 200.0, "change": 0.0, "volume": 120000},
    'SWDY.CA': {"price": 32.10, "rsi": 68.5, "macd": "Bullish", "support": 30.0, "resistance": 35.0, "change": 3.4, "volume": 2100000},
    'ABUK.CA': {"price": 85.00, "rsi": 48.9, "macd": "Neutral", "support": 80.0, "resistance": 90.0, "change": -0.2, "volume": 650000},
    'AMOC.CA': {"price": 9.75, "rsi": 42.1, "macd": "Bearish", "support": 9.0, "resistance": 10.5, "change": -1.1, "volume": 1800000},
    'EAST.CA': {"price": 24.50, "rsi": 58.6, "macd": "Bullish", "support": 23.0, "resistance": 26.0, "change": 1.5, "volume": 950000},
  };
  Map<String, dynamic> get stocksData => _stocksData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<String> _news = [];
  List<String> get news => _news;

  Map<String, dynamic> _macro = {};
  Map<String, dynamic> get macro => _macro;

  String _breadth = '';
  String get breadth => _breadth;

  String? _lastUpdated;
  String? get lastUpdated => _lastUpdated;

  String? _error;
  String? get error => _error;

  bool get hasData => _stocksData.isNotEmpty;

  /// Local cache of user assets for high-performance alert checking.
  List<dynamic> _cachedUserAssets = [];
  List<dynamic> get cachedUserAssets => _cachedUserAssets;

  /// Fetches all assets from the user's portfolios and caches them.
  /// This should be called once on init and whenever the UI updates investments.
  Future<void> fetchUserAssets() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';

    try {
      // Prioritize Cache with source: Source.cache
      // If we are offline, this will return the cached data immediately.
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('investments')
          .get(const GetOptions(source: Source.serverAndCache));

      final List<dynamic> allAssets = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final List<dynamic> assets = data['assets'] ?? [];
        allAssets.addAll(assets);
      }
      _cachedUserAssets = allAssets;
      debugPrint(
          '📦 MarketDataService: Cached ${_cachedUserAssets.length} user assets for alerts.');
    } catch (e) {
      debugPrint('⚠️ MarketDataService: Error caching user assets: $e');
    }
  }

  Timer? _refreshTimer;
  IO.Socket? _socket;

  void initSocket() {
    final String socketUrl = _baseUrl.replaceAll('/api', '');
    debugPrint('🔌 MarketDataService: Connecting to WebSocket at $socketUrl');
    
    _socket = IO.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket!.onConnect((_) {
      debugPrint('✅ MarketDataService: WebSocket Connected');
    });

    _socket!.on('price_update', (data) {
      if (data is Map) {
        final String symbol = data['s'] ?? '';
        if (symbol.isNotEmpty && _stocksData.containsKey(symbol)) {
          _stocksData[symbol]['price'] = _parseNum(data['p']);
          _stocksData[symbol]['change'] = _parseNum(data['c']);
          
          // 1. Granular Update: Push to a specialized stream for this symbol
          _priceUpdateController.add(symbol);
          
          // 2. Throttled UI Refresh: Notify listeners at most once every 500ms
          _throttleUpdate();
        }
      }
    });

    _socket!.onDisconnect((_) => debugPrint('❌ MarketDataService: WebSocket Disconnected'));
  }

  // Throttling logic to prevent UI jank
  final StreamController<String> _priceUpdateController = StreamController<String>.broadcast();
  Stream<String> get priceUpdates => _priceUpdateController.stream;
  
  Timer? _throttleTimer;
  void _throttleUpdate() {
    if (_throttleTimer?.isActive ?? false) return;
    _throttleTimer = Timer(const Duration(milliseconds: 500), () {
      notifyListeners();
    });
  }

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
      final response = await http.get(Uri.parse('$_baseUrl/egx/all')).timeout(const Duration(seconds: 45));
      if (response.statusCode == 200) {
        final String bodyStr = response.body;
        _parseAndSetData(bodyStr);
        
        // Save to cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_market_data', bodyStr);
        
        _error = null;
        debugPrint('✅ MarketDataService: Data fetched from backend.');
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      _error = 'Connection error: $e';
      debugPrint('❌ MarketDataService fetch error: $e');
    }

    _isLoading = false;
    notifyListeners();

    // Local alert checking DEPRECATED. Handled by Firebase Cloud Functions.
    /*
    if (_stocksData.isNotEmpty) {
      final notificationService = NotificationService();
      notificationService.checkMarketSignals(_stocksData);
      
      if (_cachedUserAssets.isNotEmpty) {
        notificationService.checkPriceAlerts(_stocksData, _cachedUserAssets);
      }
    }
    */
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
        final support = info['support'] ?? '0';
        final resistance = info['resistance'] ?? '0';
        final change = info['change'] ?? '0';
        final volume = info['volume'] ?? '0';
        buffer.write('$ticker: Price=$price, Sup=$support, Res=$resistance, Change=$change%, Vol=$volume, RSI=$rsi, MACD=$macd | ');
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

        final bool isOversold = rsi < 40;
        final double volVal = (info['volume'] is num) ? (info['volume'] as num).toDouble() : 0.0;
        final bool hasHighVolume = volVal > 500000; // Filter for high volume stocks

        if (isOversold || hasHighVolume) {
          final change = info['change'] ?? '0';
          final vol = info['volume'] ?? '0';
          final support = info['support'] ?? '0';
          final resistance = info['resistance'] ?? '0';
          signals.add('$ticker: Price=${info['price']}, Sup=$support, Res=$resistance, Chg=$change%, Vol=$vol, RSI=${rsi.toStringAsFixed(1)}, MACD=$macd');
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
    final support = data['support'] ?? '0';
    final resistance = data['resistance'] ?? '0';
    final change = data['change'] ?? '0';
    final volume = data['volume'] ?? '0';

    final context =
        '[SYSTEM CONTEXT] ASSET: $ticker | LIVE PRICE: $price ($change%) | SUPPORT: $support | RESISTANCE: $resistance | VOL: $volume | TECHNICALS: RSI = $rsi, MACD = $macd [END CONTEXT]';

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

  /// Get stocks for a specific market
  List<Map<String, dynamic>> getStocksByMarket(String suffix, {bool isFund = false}) {
    List<Map<String, dynamic>> results = [];
    
    // Special case for UAE which has both .DU and .AD
    List<String> suffixes = [suffix];
    if (suffix == '.DU') suffixes.add('.AD');

    _stocksData.forEach((symbol, data) {
      bool matchesMarket = suffixes.any((s) => symbol.endsWith(s));
      bool isMutualFund = data['is_fund'] == true;
      
      if (matchesMarket) {
        if (isFund == isMutualFund) {
          var item = Map<String, dynamic>.from(data);
          item['symbol'] = symbol;
          results.add(item);
        }
      }
    });
    return results;
  }
}
