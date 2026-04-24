import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/connectivity_indicator.dart';
import '../widgets/elite_header.dart';
import '../widgets/elite_card.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';

class MarketOpportunitiesScreen extends StatefulWidget {
  const MarketOpportunitiesScreen({super.key});

  @override
  State<MarketOpportunitiesScreen> createState() => _MarketOpportunitiesScreenState();
}

class _MarketOpportunitiesScreenState extends State<MarketOpportunitiesScreen> {
  late final Stream<QuerySnapshot> _signalsStream;

  @override
  void initState() {
    super.initState();
    _signalsStream = FirebaseFirestore.instance
        .collection('market_signals')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _signalsStream,
            builder: (context, snapshot) {
              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    title: const Text('Radar', style: TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.black,
                    floating: true,
                    pinned: true,
                    elevation: 0,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.calendar_today_outlined,
                            color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const CalendarScreen()),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.account_circle_outlined,
                            color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ProfileScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                  const SliverToBoxAdapter(
                    child: EliteHeader(title: 'Signals & Opportunities'),
                  ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Error loading signals: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              else if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.radar, size: 64, color: Colors.white10),
                        SizedBox(height: 16),
                        Text(
                          'Scanning EGX for Alpha Signals...',
                          style: TextStyle(color: Colors.white30),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      return _SignalCard(data: data);
                    },
                    childCount: snapshot.data!.docs.length,
                  ),
                ),
            ],
          );
        },
      ),
      const ConnectivityIndicator(),
      ],
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _SignalCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? 'UNKNOWN';
    final ticker = data['ticker'] as String? ?? 'Unknown';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final message = data['message'] as String? ?? '';
    final value = data['value']?.toString() ?? '';

    Color accentColor;
    IconData icon;

    switch (type) {
      case 'VOLUME_SPIKE':
        accentColor = Colors.orangeAccent;
        icon = Icons.equalizer;
        break;
      case 'RSI_REVERSAL':
        accentColor = Colors.greenAccent;
        icon = Icons.trending_up;
        break;
      case 'PRICE_BREAKOUT':
        accentColor = Colors.purpleAccent;
        icon = Icons.bolt;
        break;
      default:
        accentColor = Colors.white70;
        icon = Icons.info_outline;
    }

    return EliteCard(
      glowColor: accentColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: accentColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    type.replaceAll('_', ' '),
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                DateFormat('HH:mm | dd MMM').format(timestamp),
                style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ticker,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (value.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Value: $value',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
