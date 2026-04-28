import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animations/animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/market_data_service.dart';
import 'services/notification_service.dart';
import 'screens/investments_screen.dart';
import 'screens/chat_screen.dart';
import 'config/api_keys.dart';
import 'screens/market_screen.dart';
import 'models/mock_market_data.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load API keys from Git-ignored config file
  await ApiKeys.load();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Offline Persistence for Firestore (Professional Architecture)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Initialize FCM asynchronously to avoid blocking cold starts offline
  Future.microtask(() async {
    try {
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);
      }
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission();
      debugPrint('User granted permission: ${settings.authorizationStatus}');

      String? token = await messaging.getToken();
      if (token != null) {
        debugPrint("🚀 FCM TOKEN: $token");

        if (FirebaseAuth.instance.currentUser != null) {
          String uid = FirebaseAuth.instance.currentUser!.uid;
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'fcmToken': token,
          }, SetOptions(merge: true));
          debugPrint("🚀 FCM TOKEN synced to Firestore: $token");
        } else {
          debugPrint("User not logged in, FCM token not synced to Firestore.");
        }
      } else {
        debugPrint("FCM token is null.");
      }
    } catch (e) {
      debugPrint("Could not setup FCM: $e");
    }
  });

  try {
    tz.initializeTimeZones();
    await NotificationService().init();

    if (!kIsWeb) {
      // Background polling deprecated in favor of professional FCM
      // await BackgroundService.init();
    }
  } catch (e) {
    debugPrint(e.toString());
  }

  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MarketDataService(),
      child: MaterialApp(
        title: 'Onyx',
        themeMode:
            ThemeMode.light, // Force light mode for the new White Theme
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF2F2F7), // Neutral Gray
          cardColor: const Color(0xFFFFFFFF), // White
          cardTheme: CardThemeData(
            color: const Color(0xFFFFFFFF),
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF000000),
            brightness: Brightness.light,
            primary: const Color(0xFF000000), // Primary accent color (Black)
            onPrimary: const Color(0xFFFFFFFF), // Text on primary
            surface: const Color(0xFFFFFFFF),
          ),
          textTheme: GoogleFonts.interTextTheme(
            TextTheme(
              bodyLarge: const TextStyle(color: Color(0xFF000000)),
              bodyMedium: const TextStyle(color: Color(0xFF000000)),
              bodySmall: const TextStyle(color: Color(0xFF666666)),
              titleLarge: GoogleFonts.manrope(
                  color: const Color(0xFF000000), fontWeight: FontWeight.w600),
              titleMedium: GoogleFonts.manrope(
                  color: const Color(0xFF000000), fontWeight: FontWeight.w600),
              titleSmall: GoogleFonts.manrope(
                  color: const Color(0xFF000000), fontWeight: FontWeight.w600),
              headlineLarge: GoogleFonts.manrope(
                  color: const Color(0xFF000000), fontWeight: FontWeight.w700),
              headlineMedium: GoogleFonts.manrope(
                  color: const Color(0xFF000000), fontWeight: FontWeight.w700),
              headlineSmall: GoogleFonts.manrope(
                  color: const Color(0xFF000000), fontWeight: FontWeight.w700),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: Colors.black,
            ),
            iconTheme: IconThemeData(color: Colors.black),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Color(0xFF000000),
            unselectedItemColor: Color(0xFF999999),
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          ),
          useMaterial3: true,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    // Authentication disabled, go directly to MainScaffold
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = Provider.of<MarketDataService>(context, listen: false);
      if (!service.hasData && !service.isLoading) {
        service.fetchAllMarketData();
      }
    });
    return const MainScaffold();
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  bool _isAuthorized = false;
  bool _isAuthenticating = false;
  final LocalAuthentication auth = LocalAuthentication();
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _checkAppLock();
    _pageController = PageController(initialPage: _currentIndex);

    // Start automatic market data updates (60s)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MarketDataService>(context, listen: false)
          .startPeriodicRefresh(seconds: 60);
    });
  }

  Future<void> _checkAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    final isLocked = prefs.getBool('app_lock_enabled') ?? false;

    if (!isLocked) {
      if (mounted) setState(() => _isAuthorized = true);
      return;
    }

    _authenticate();
  }

  Future<void> _authenticate() async {
    try {
      setState(() {
        _isAuthenticating = true;
      });
      final bool authenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to access Onyx',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (mounted) {
        setState(() {
          _isAuthorized = authenticated;
          _isAuthenticating = false;
        });
      }
    } on PlatformException catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();

    // Stop automatic updates when leaving the main app area
    // Use Try-catch or listen:false for safety in dispose
    try {
      Provider.of<MarketDataService>(context, listen: false)
          .stopPeriodicRefresh();
    } catch (_) {}

    super.dispose();
  }

  final List<Widget> _screens = const [
    InvestmentsScreen(),
    MarketScreen(marketName: 'Egyptian Market', stocks: MockMarketData.egyptStocks, funds: MockMarketData.egyptFunds),
    ChatScreen(),
    MarketScreen(marketName: 'Tadawul', stocks: MockMarketData.saudiStocks),
    MarketScreen(marketName: 'DFM & ADX', stocks: MockMarketData.uaeStocks),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.white24),
              const SizedBox(height: 24),
              const Text(
                'Onyx is Locked',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              if (!_isAuthenticating)
                ElevatedButton.icon(
                  onPressed: _authenticate,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Unlock with Biometrics'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true, // Needed for floating transparent nav bar
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(0, 'WALLET', Icons.account_balance_wallet_outlined),
                _buildNavItem(1, 'EGX', Icons.flag_outlined),
                _buildNavItem(2, 'AI CHAT', Icons.smart_toy_outlined),
                _buildNavItem(3, 'TADAWUL', Icons.mosque_outlined),
                _buildNavItem(4, 'DFM', Icons.public_outlined),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _onTabTapped(index);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF000000) : const Color(0xFF8E8E93),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? const Color(0xFF000000) : const Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
