import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  StreamSubscription? _portfoliosSub;

  @override
  void dispose() {
    _portfoliosSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPortfolios();
  }

  Future<void> _loadPortfolios() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _portfoliosSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('investments')
        .snapshots()
        .listen((snapshot) async {
      final loadedPortfolios = snapshot.docs.map((doc) => Portfolio.fromJson(doc.data())).toList();

      if (loadedPortfolios.isEmpty) {
        final defaultPortfolio = Portfolio(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Main Profile',
        );
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('investments')
            .doc(defaultPortfolio.id)
            .set(defaultPortfolio.toJson());
        return;
      }

      if (mounted) {
        setState(() {
          _portfolios = loadedPortfolios;
          if (_activePortfolioId == null || !loadedPortfolios.any((p) => p.id == _activePortfolioId)) {
            _activePortfolioId = loadedPortfolios.first.id;
          }
          _isLoading = false;
        });
      }
    });
  }

  void _addPortfolio(String name) async {
    if (name.trim().isEmpty) return;
    final newPortfolio = Portfolio(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).collection('investments').doc(newPortfolio.id).set(newPortfolio.toJson());
    setState(() => _activePortfolioId = newPortfolio.id);
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
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                await FirebaseFirestore.instance.collection('users').doc(uid).collection('investments').doc(portfolio.id).delete();
              }
              if (!context.mounted) return;
              Navigator.pop(context);
              if (mounted) {
                setState(() {
                  if (_activePortfolioId == portfolio.id) {
                    _activePortfolioId = _portfolios.firstWhere((p) => p.id != portfolio.id).id;
                  }
                });
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _addAsset(String name, double buyPrice, double currentPrice, double quantity) async {
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

    activePortfolio.assets.add(newAsset);
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('investments').doc(activePortfolio.id).set(activePortfolio.toJson());
    }
  }

  void _deleteAsset(Asset asset) async {
    if (_activePortfolioId == null) return;
    final activePortfolio =
        _portfolios.firstWhere((p) => p.id == _activePortfolioId);

    activePortfolio.assets.remove(asset);
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('investments').doc(activePortfolio.id).set(activePortfolio.toJson());
    }
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
        backgroundColor: const Color(0xFF000000),
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
                      label: const Text('+ New', style: TextStyle(color: Colors.white)),
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
      body: SafeArea(
        child: Column(
          children: [
          // Dashboard Summary Card
          Card(
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${activePortfolio.name} Dashboard',
                    style: TextStyle(
                        fontSize: 16,
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
                          Text('Total Spent', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text('\$${totalSpent.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Current Value', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text('\$${currentValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total ROI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        Flexible(
                          child: Text(
                            '${totalRoiPercentage > 0 ? '+' : ''}${totalRoiPercentage.toStringAsFixed(2)}%',
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: totalRoiPercentage > 0
                                  ? Colors.greenAccent
                                  : (totalRoiPercentage < 0
                                      ? Colors.redAccent
                                      : Theme.of(context).textTheme.bodyLarge?.color),
                            ),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
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
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: activePortfolio.assets.length + 1,
                    itemBuilder: (context, index) {
                      if (index == activePortfolio.assets.length) {
                        return const SizedBox(height: 100);
                      }
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
                            padding: const EdgeInsets.all(12.0),
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
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Qty: ${asset.quantity}',
                                        style: TextStyle(
                                            fontSize: 11,
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
                                              style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium?.color)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text('Cur: \$${asset.currentPrice.toStringAsFixed(2)}',
                                              style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium?.color)),
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
                                        fontSize: 13,
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
    ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAssetDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
