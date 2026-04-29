import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StockDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> stock;

  const StockDetailsScreen({super.key, required this.stock});

  @override
  State<StockDetailsScreen> createState() => _StockDetailsScreenState();
}

class _StockDetailsScreenState extends State<StockDetailsScreen> {
  String selectedPeriod = '1M';
  final List<String> periods = ['1D', '1W', '1M', '3M', '1Y', 'ALL'];

  @override
  Widget build(BuildContext context) {
    final price = widget.stock['price'] ?? 0.0;
    final changePercent = widget.stock['change'] ?? 0.0;
    final symbol = widget.stock['symbol'] ?? '';
    final name = widget.stock['name'] ?? symbol;
    
    final isPositive = changePercent >= 0;
    final primaryColor = isPositive ? const Color(0xFF34C759) : const Color(0xFFFF3B30);
    final changeAmount = (price * changePercent / 100).abs();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_circle, color: Color(0xFF1E293B), size: 28),
            Spacer(),
            Text(
              'ONYX',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 20,
              ),
            ),
            Spacer(),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tags
            Row(
              children: [
                _buildTag(symbol),
                const SizedBox(width: 8),
                _buildTag('EQUITIES'),
              ],
            ),
            const SizedBox(height: 12),
            
            // Name
            Text(
              name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),

            // Price & Change
            Text(
              '${price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  color: primaryColor,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${isPositive ? '+' : '-'}${changeAmount.toStringAsFixed(2)} (${changePercent.abs().toStringAsFixed(2)}%)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'TODAY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Chart Card
            Container(
              padding: const EdgeInsets.only(top: 24, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // FL Chart Mock
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.shade200,
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _generateMockSpots(),
                            isCurved: false,
                            color: const Color(0xFF1B5E20), // Dark green line like in image
                            barWidth: 2,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF2F2F7)),
                  const SizedBox(height: 8),
                  
                  // Period Selector
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: periods.map((period) {
                        final isSelected = selectedPeriod == period;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedPeriod = period;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFE5E5EA) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              period,
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Latest News Section
            const Text(
              'Latest News',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE5E5EA), height: 1),
            _buildNewsItem(
              'Apple Vision Pro sees early success in enterprise...',
              'FINANCIAL TIMES',
              '2H AGO',
            ),
            const Divider(color: Color(0xFFE5E5EA), height: 1),
            _buildNewsItem(
              'Analysts upgrade AAPL price target amidst strong iPhone...',
              'BLOOMBERG',
              '5H AGO',
            ),
            const Divider(color: Color(0xFFE5E5EA), height: 1),
            _buildNewsItem(
              'Supply chain reports indicate stabilization in...',
              'REUTERS',
              '1D AGO',
            ),
            const Divider(color: Color(0xFFE5E5EA), height: 1),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNewsItem(String title, String source, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      source,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Mock Image
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(4),
              image: const DecorationImage(
                image: NetworkImage('https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?auto=format&fit=crop&q=80&w=200'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _generateMockSpots() {
    // Generate some random points based on the selected period
    // The image shows a jagged line chart
    return [
      const FlSpot(0, 1),
      const FlSpot(1, 1.2),
      const FlSpot(2, 0.8),
      const FlSpot(3, 1.8),
      const FlSpot(4, 1.5),
      const FlSpot(5, 2.5),
      const FlSpot(6, 2.2),
      const FlSpot(7, 3.2),
      const FlSpot(8, 3.0),
    ];
  }
}
