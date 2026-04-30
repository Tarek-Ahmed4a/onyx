import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/market_data_service.dart';

class StockDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> stock;

  const StockDetailsScreen({super.key, required this.stock});

  @override
  State<StockDetailsScreen> createState() => _StockDetailsScreenState();
}

class _StockDetailsScreenState extends State<StockDetailsScreen> {
  String selectedPeriod = '1M';
  final List<String> periods = ['1D', '1W', '1M', '3M', '1Y', 'ALL'];
  List<FlSpot> _spots = [];
  bool _isLoadingChart = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingChart = true;
    });
    
    final marketData = Provider.of<MarketDataService>(context, listen: false);
    String apiPeriod = '1mo';
    if (selectedPeriod == '1D') apiPeriod = '1d';
    else if (selectedPeriod == '1W') apiPeriod = '5d';
    else if (selectedPeriod == '1M') apiPeriod = '1mo';
    else if (selectedPeriod == '3M') apiPeriod = '3mo';
    else if (selectedPeriod == '1Y') apiPeriod = '1y';
    else if (selectedPeriod == 'ALL') apiPeriod = 'max';
    
    final fetchedSpots = await marketData.fetchHistory(widget.stock['symbol'], period: apiPeriod);
    
    if (mounted) {
      setState(() {
        _spots = fetchedSpots;
        _isLoadingChart = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.stock['price'] ?? 0.0;
    final changePercent = widget.stock['change'] ?? 0.0;
    final symbol = widget.stock['symbol'] ?? '';
    final name = widget.stock['name'] ?? symbol;
    
    final isPositive = changePercent >= 0;
    final primaryColor = isPositive ? const Color(0xFF34C759) : const Color(0xFFFF3B30);
    final changeAmount = (price * changePercent / 100).abs();

    // Calculate Y-axis bounds
    double minY = 0;
    double maxY = 10;
    if (_spots.isNotEmpty) {
      minY = _spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
      maxY = _spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
      
      double padding = (maxY - minY) * 0.1;
      minY -= padding;
      maxY += padding;
      if (minY < 0) minY = 0;
    }

    final marketData = context.watch<MarketDataService>();
    final newsList = marketData.news;

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
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: _isLoadingChart 
                      ? const Center(child: CircularProgressIndicator(color: Colors.black))
                      : _spots.isEmpty 
                          ? Center(child: Text("No chart data available.", style: TextStyle(color: Colors.grey.shade600)))
                          : LineChart(
                              LineChartData(
                                minY: minY,
                                maxY: maxY,
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: (maxY - minY) > 0 ? (maxY - minY) / 4 : 1,
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
                                    spots: _spots,
                                    isCurved: false,
                                    color: primaryColor,
                                    barWidth: 2,
                                    isStrokeCapRound: true,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: primaryColor.withValues(alpha: 0.1),
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
                            if (!isSelected) {
                              setState(() {
                                selectedPeriod = period;
                              });
                              _loadHistory();
                            }
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
            if (newsList.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text("No recent news available."),
              )
            else
              ...newsList.take(5).map((newsStr) {
                // News strings are typically like "TITLE" or we can just show the string as title
                return Column(
                  children: [
                    const Divider(color: Color(0xFFE5E5EA), height: 1),
                    _buildNewsItem(
                      newsStr,
                      'MARKET NEWS',
                      'RECENT',
                    ),
                  ],
                );
              }),
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
                  maxLines: 3,
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
        ],
      ),
    );
  }
}

