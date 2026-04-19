import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animations/animations.dart';
import 'dart:ui';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'screens/market_opportunities_screen.dart';
import 'firebase_options.dart';
import 'services/market_data_service.dart';
import 'services/notification_service.dart';
import 'screens/tasks_screen.dart';
import 'screens/investments_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/login_screen.dart';
import 'screens/chat_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Failed to load .env file: $e");
  }

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
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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
            ThemeMode.dark, // Force dark mode for global OLED minimalist theme
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF000000), // OLED Black
          cardColor: const Color(0xFF121212), // Slightly lighter for cards
          cardTheme: CardThemeData(
            color: const Color(0xFF121212),
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFFFFFF),
            brightness: Brightness.dark,
            primary: const Color(0xFFFFFFFF), // Primary accent color (White)
            onPrimary: const Color(0xFF000000), // Text on primary
            surface: const Color(0xFF121212),
          ),
          textTheme: GoogleFonts.outfitTextTheme(
            const TextTheme(
              bodyLarge: TextStyle(color: Color(0xFFE0E0E0)),
              bodyMedium: TextStyle(color: Color(0xFFE0E0E0)),
              bodySmall: TextStyle(color: Color(0xFFA0A0A0)),
              titleLarge: TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
              titleMedium: TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
              titleSmall: TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
              headlineLarge: TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w700),
              headlineMedium: TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w700),
              headlineSmall: TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w700),
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
              color: Colors.white,
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Colors.white,
            unselectedItemColor: Color(0xFF757575),
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: false,
            showUnselectedLabels: false,
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
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Authentication Error:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}), // Trigger rebuild/retry
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // Trigger a single market data fetch on login
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final service =
                Provider.of<MarketDataService>(context, listen: false);
            if (!service.hasData && !service.isLoading) {
              service.fetchAllMarketData();
            }
          });
          return const MainScaffold();
        }

        return const LoginScreen();
      },
    );
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
    // Use try-catch or listen:false for safety in dispose
    try {
      Provider.of<MarketDataService>(context, listen: false)
          .stopPeriodicRefresh();
    } catch (_) {}

    super.dispose();
  }

  final List<Widget> _screens = const [
    TasksScreen(),
    InvestmentsScreen(),
    MarketOpportunitiesScreen(),
    ExpensesScreen(),
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 24.0, left: 24.0, right: 24.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: Colors.white.withValues(alpha: 0.05),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Theme(
                    data: Theme.of(context).copyWith(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: BottomNavigationBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      type: BottomNavigationBarType.fixed,
                      showSelectedLabels: false,
                      showUnselectedLabels: false,
                      currentIndex:
                          _currentIndex < 2 ? _currentIndex : _currentIndex + 1,
                      onTap: (index) {
                        HapticFeedback.lightImpact(); // Premium Haptic Feedback
                        if (index == 2) return;
                        final pageIndex = index > 2 ? index - 1 : index;
                        _onTabTapped(pageIndex);
                      },
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.assignment_turned_in), // Market Analysis (Tasks)
                          label: '',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.trending_up), // My Portfolio (Investments)
                          label: '',
                        ),
                        BottomNavigationBarItem(
                          icon: SizedBox(width: 24, height: 24), // Center placeholder
                          label: '',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.track_changes), // Opportunity Radar
                          label: '',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.account_balance_wallet), // Expenses
                          label: '',
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    child: FloatingActionButton(
                      heroTag: null,
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChatScreen()),
                        );
                      },
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: Icon(
                        Icons.auto_awesome,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
