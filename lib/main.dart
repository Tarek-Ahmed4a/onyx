import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'screens/tasks_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/investments_screen.dart';
import 'screens/expenses_screen.dart';

void main() {
  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Finance App',
      themeMode: ThemeMode.dark, // Force dark mode for global OLED minimalist theme
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000), // OLED Black
        cardColor: const Color(0xFF121212), // Slightly lighter for cards
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFFFFF),
          brightness: Brightness.dark,
          primary: const Color(0xFFFFFFFF), // Primary accent color (White)
          onPrimary: const Color(0xFF000000), // Text on primary
          surface: const Color(0xFF121212),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFE0E0E0)),
          bodyMedium: TextStyle(color: Color(0xFFE0E0E0)),
          bodySmall: TextStyle(color: Color(0xFFE0E0E0)),
          titleLarge: TextStyle(color: Color(0xFFE0E0E0)),
          titleMedium: TextStyle(color: Color(0xFFE0E0E0)),
          titleSmall: TextStyle(color: Color(0xFFE0E0E0)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF121212),
          selectedItemColor: Color(0xFFFFFFFF), // Active icons
          unselectedItemColor: Color(0xFFE0E0E0),
        ),
        useMaterial3: true,
      ),
      home: const MainScaffold(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TasksScreen(),
    CalendarScreen(),
    InvestmentsScreen(),
    ExpensesScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: GNav(
              gap: 8,
              activeColor: const Color(0xFFFFFFFF),
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: const Color(0xFF1E1E1E),
              color: const Color(0xFF555555), // Inactive icon color
              tabs: const [
                GButton(
                  icon: Icons.check_circle_outline,
                  text: 'Tasks',
                ),
                GButton(
                  icon: Icons.calendar_today_outlined,
                  text: 'Calendar',
                ),
                GButton(
                  icon: Icons.trending_up_outlined,
                  text: 'Investments',
                ),
                GButton(
                  icon: Icons.account_balance_wallet_outlined,
                  text: 'Expenses',
                ),
              ],
              selectedIndex: _currentIndex,
              onTabChange: _onTabTapped,
            ),
          ),
        ),
      ),
    );
  }
}
