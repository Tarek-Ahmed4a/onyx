import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/connectivity_indicator.dart';

class MarketOpportunitiesScreen extends StatelessWidget {
  const MarketOpportunitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
            .collection('market_signals')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120.0,
                floating: false,
                pinned: true,
                backgroundColor: Colors.black,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
                  title: const Text(
                    'Opportunity Radar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.blueAccent.withValues(alpha: 0.2),
                          Colors.black,
                        ],
                      ),
                    ),
                  ),
                ),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
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
