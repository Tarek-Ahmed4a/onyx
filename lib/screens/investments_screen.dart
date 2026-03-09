import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Asset {
  final String id;
  String name;
  double buyPrice;
  double currentPrice;
  double quantity;

  Asset({
    required this.id,
    required this.name,
    required this.buyPrice,
    required this.currentPrice,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'buyPrice': buyPrice,
        'currentPrice': currentPrice,
        'quantity': quantity,
      };

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
        id: json['id'],
        name: json['name'],
        buyPrice: (json['buyPrice'] as num).toDouble(),
        currentPrice: (json['currentPrice'] as num).toDouble(),
        quantity: (json['quantity'] as num).toDouble(),
      );
}

class Portfolio {
  final String id;
  String name;
  List<Asset> assets;

  Portfolio({
    required this.id,
    required this.name,
    List<Asset>? assets,
  }) : assets = assets ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'assets': assets.map((a) => a.toJson()).toList(),
      };

  factory Portfolio.fromJson(Map<String, dynamic> json) => Portfolio(
        id: json['id'],
        name: json['name'],
        assets: (json['assets'] as List<dynamic>?)
                ?.map((item) => Asset.fromJson(item))
                .toList() ??
            [],
      );
}

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  List<Portfolio> _portfolios = [];
  String? _activePortfolioId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPortfolios();
  }

  Future<void> _loadPortfolios() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dataJson = prefs.getString('investments_portfolios_data');

    if (dataJson != null) {
      final List<dynamic> decoded = json.decode(dataJson);
      setState(() {
        _portfolios = decoded.map((item) => Portfolio.fromJson(item)).toList();
        if (_portfolios.isNotEmpty) {
          _activePortfolioId = _portfolios.first.id;
        }
        _isLoading = false;
      });
    } else {
      final defaultPortfolio = Portfolio(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Main Portfolio',
      );
      setState(() {
        _portfolios = [defaultPortfolio];
        _activePortfolioId = defaultPortfolio.id;
        _isLoading = false;
      });
      await _savePortfolios();
    }
  }

  Future<void> _savePortfolios() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded =
        json.encode(_portfolios.map((p) => p.toJson()).toList());
    await prefs.setString('investments_portfolios_data', encoded);
  }

  void _addPortfolio(String name) {
    if (name.trim().isEmpty) return;
    final newPortfolio = Portfolio(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
    );
    setState(() {
      _portfolios.add(newPortfolio);
      _activePortfolioId = newPortfolio.id;
    });
    _savePortfolios();
  }

  void _deletePortfolio(Portfolio portfolio) {
    if (_portfolios.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the last profile.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile?'),
        content: Text(
            'Are you sure you want to delete "${portfolio.name}" and all its assets?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _portfolios.remove(portfolio);
                if (_activePortfolioId == portfolio.id) {
                  _activePortfolioId = _portfolios.first.id;
                }
              });
              _savePortfolios();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _addAsset(String name, double buyPrice, double currentPrice, double quantity) {
    if (_activePortfolioId == null) return;
    final activePortfolio =
        _portfolios.firstWhere((p) => p.id == _activePortfolioId);

    final newAsset = Asset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      buyPrice: buyPrice,
      currentPrice: currentPrice,
      quantity: quantity,
    );

    setState(() {
      activePortfolio.assets.add(newAsset);
    });
    _savePortfolios();
  }

  void _deleteAsset(Asset asset) {
    if (_activePortfolioId == null) return;
    final activePortfolio =
        _portfolios.firstWhere((p) => p.id == _activePortfolioId);

    setState(() {
      activePortfolio.assets.remove(asset);
    });
    _savePortfolios();
  }

  void _showAddPortfolioDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Profile'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Profile Name'),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _addPortfolio(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showAddAssetDialog() {
    final nameController = TextEditingController();
    final buyPriceController = TextEditingController();
    final currentPriceController = TextEditingController();
    final quantityController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Asset'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Asset Name (e.g., AAPL)'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                  textCapitalization: TextCapitalization.characters,
                ),
                TextFormField(
                  controller: buyPriceController,
                  decoration: const InputDecoration(labelText: 'Buy Price'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (double.tryParse(value) == null) return 'Invalid number';
                    return null;
                  },
                ),
                TextFormField(
                  controller: currentPriceController,
                  decoration: const InputDecoration(labelText: 'Current Price'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (double.tryParse(value) == null) return 'Invalid number';
                    return null;
                  },
                ),
                TextFormField(
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (double.tryParse(value) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _addAsset(
                  nameController.text,
                  double.parse(buyPriceController.text),
                  double.parse(currentPriceController.text),
                  double.parse(quantityController.text),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final activePortfolio = _portfolios.firstWhere(
      (p) => p.id == _activePortfolioId,
      orElse: () => _portfolios.first,
    );

    double totalSpent = 0;
    double currentValue = 0;

    for (var asset in activePortfolio.assets) {
      totalSpent += asset.buyPrice * asset.quantity;
      currentValue += asset.currentPrice * asset.quantity;
    }

    double totalRoiPercentage = 0;
    if (totalSpent > 0) {
      totalRoiPercentage = ((currentValue - totalSpent) / totalSpent) * 100;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investments',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _portfolios.length + 1,
              itemBuilder: (context, index) {
                if (index == _portfolios.length) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ActionChip(
                      label: const Text('+ New profile'),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.primary),
                      onPressed: _showAddPortfolioDialog,
                    ),
                  );
                }

                final portfolio = _portfolios[index];
                final isActive = portfolio.id == _activePortfolioId;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onLongPress: () => _deletePortfolio(portfolio),
                    child: ChoiceChip(
                      label: Text(portfolio.name),
                      selected: isActive,
                      selectedColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withAlpha(51),
                      backgroundColor: Theme.of(context).cardColor,
                      labelStyle: TextStyle(
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).textTheme.bodyMedium?.color,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _activePortfolioId = portfolio.id;
                          });
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Dashboard Summary Card
          Card(
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${activePortfolio.name} Dashboard',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleLarge?.color),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Spent', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('\$${totalSpent.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Current Value', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('\$${currentValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total ROI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        Text(
                          '${totalRoiPercentage > 0 ? '+' : ''}${totalRoiPercentage.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: totalRoiPercentage > 0
                                ? Colors.greenAccent
                                : (totalRoiPercentage < 0
                                    ? Colors.redAccent
                                    : Theme.of(context).textTheme.bodyLarge?.color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Assets',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ),

          Expanded(
            child: activePortfolio.assets.isEmpty
                ? Center(
                    child: Text(
                      'No assets added yet.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: activePortfolio.assets.length,
                    itemBuilder: (context, index) {
                      final asset = activePortfolio.assets[index];
                      final assetRoi = ((asset.currentPrice - asset.buyPrice) /
                              asset.buyPrice) *
                          100;

                      return Dismissible(
                        key: Key(asset.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteAsset(asset),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        asset.name,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Qty: ${asset.quantity}',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade400),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text('Buy: \$${asset.buyPrice.toStringAsFixed(2)}',
                                              style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text('Cur: \$${asset.currentPrice.toStringAsFixed(2)}',
                                              style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '${assetRoi > 0 ? '+' : ''}${assetRoi.toStringAsFixed(2)}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: assetRoi > 0
                                            ? Colors.greenAccent
                                            : (assetRoi < 0
                                                ? Colors.redAccent
                                                : Theme.of(context).textTheme.bodyLarge?.color),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAssetDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
