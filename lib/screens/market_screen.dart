import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/market_data_service.dart';
import 'stock_details_screen.dart';
import 'profile_screen.dart';

class MarketScreen extends StatefulWidget {
  final String marketName;
  final String marketSuffix;

  const MarketScreen({super.key, required this.marketName, required this.marketSuffix});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  String _selectedFilter = 'Stocks';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search ticker or name...',
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : Text(
                widget.marketName,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 22,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.black),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.black),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
            sliver: SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Stocks'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Mutual Funds'),
                  ],
                ),
              ),
            ),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Market Overview',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'VIEW ALL',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          
          Selector<MarketDataService, List<String>>(
            selector: (context, service) {
              // We only care about the LIST of symbols here, not their prices.
              // This selector will only trigger a rebuild of the ListView structure
              // if the filtered list of symbols changes.
              return _getDisplayedItems(context, service).map((s) => s['symbol'] as String).toList();
            },
            shouldRebuild: (prev, next) {
              if (prev.length != next.length) return true;
              for (int i = 0; i < prev.length; i++) {
                if (prev[i] != next[i]) return true;
              }
              return false;
            },
            builder: (context, symbolList, _) {
              if (symbolList.isEmpty) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index.isOdd) return const Divider(height: 1, color: Color(0xFFF2F2F7));
                      final itemIndex = index ~/ 2;
                      final symbol = symbolList[itemIndex];
                      return StockListItem(symbol: symbol, marketSuffix: widget.marketSuffix);
                    },
                    childCount: symbolList.length * 2 - 1,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getDisplayedItems(BuildContext context, MarketDataService service) {
    // Note: service is passed from Selector, or fetched with listen: false if called elsewhere.
    List<Map<String, dynamic>> items = service.getStocksByMarket(
      widget.marketSuffix, 
      isFund: _selectedFilter == 'Mutual Funds'
    );
    
    if (_searchQuery.isNotEmpty) {
      items = items.where((s) => 
        (s['symbol'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) || 
        (s['name'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    return items;
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class StockListItem extends StatelessWidget {
  final String symbol;
  final String marketSuffix;

  const StockListItem({super.key, required this.symbol, required this.marketSuffix});

  @override
  Widget build(BuildContext context) {
    return Selector<MarketDataService, Map<String, dynamic>?>(
      selector: (context, service) => service.stocksData[symbol],
      builder: (context, currentData, child) {
        if (currentData == null) return const SizedBox.shrink();
        
        final displayName = currentData['name'] ?? symbol;
        final price = (currentData['price'] as num?)?.toDouble() ?? 0.0;
        final changePercent = (currentData['change'] as num?)?.toDouble() ?? 0.0;
        final rsi = (currentData['rsi'] as num?)?.toDouble() ?? 50.0;
        final isPositive = changePercent >= 0;
        final indicatorStatus = rsi < 40 ? 'positive' : (rsi > 70 ? 'negative' : 'neutral');

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => StockDetailsScreen(stock: currentData)),
            );
          },
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.center,
                  child: Text(symbol.isNotEmpty ? symbol[0] : '?', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(symbol, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      Text(indicatorStatus.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                        color: indicatorStatus == 'positive' ? Colors.green : (indicatorStatus == 'negative' ? Colors.red : Colors.grey))),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${price.toStringAsFixed(2)} ${marketSuffix == '.CA' ? 'EGP' : (marketSuffix == '.SR' ? 'SAR' : 'AED')}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, color: isPositive ? Colors.green : Colors.red, size: 12),
                        Text('${isPositive ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isPositive ? Colors.green : Colors.red)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
