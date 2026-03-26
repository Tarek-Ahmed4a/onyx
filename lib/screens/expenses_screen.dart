import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wallet_model.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  bool _isLoading = true;

  List<Wallet> _wallets = [];
  String? _activeWalletId;
  List<Expense> _expenses = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load wallets
    final String? walletsJson = prefs.getString('expense_profiles_data'); // Keeping legacy key for compatibility
    if (walletsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(walletsJson);
        _wallets = decoded.map((p) => Wallet.fromJson(p)).toList();
      } catch (e) {
        debugPrint('Error loading wallets: $e');
      }
    }
    
    if (_wallets.isEmpty) {
      final defaultWallet = Wallet(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Default Wallet',
      );
      _wallets = [defaultWallet];
    }
    
    final savedActiveWallet = prefs.getString('active_profile_id');
    if (savedActiveWallet != null && _wallets.any((p) => p.id == savedActiveWallet)) {
      _activeWalletId = savedActiveWallet;
    } else {
      _activeWalletId = _wallets.first.id;
    }

    // Load expenses
    final String? expensesJson = prefs.getString('expenses_data');
    if (expensesJson != null) {
      try {
        final List<dynamic> decoded = json.decode(expensesJson);
        _expenses = decoded.map((e) => Expense.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Error loading expenses: $e');
      }
    } else {
        // Try DB Migration from legacy schema to current _activeWalletId
        final double? oldNeeds = prefs.getDouble('needs_spent');
        final double? oldWants = prefs.getDouble('wants_spent');
        final double? oldSavings = prefs.getDouble('savings_spent');
        final double? oldIncome = prefs.getDouble('monthly_income');
        
        if (oldIncome != null) {
            final activeWallet = _wallets.firstWhere((p) => p.id == _activeWalletId);
            activeWallet.initialIncome = oldIncome;
            _saveWallets();
        }

        if (oldNeeds != null && oldNeeds > 0) {
            _expenses.add(Expense(id: 'legacy_need', category: 'Need', amount: oldNeeds, profileId: _activeWalletId!, date: DateTime.now()));
        }
        if (oldWants != null && oldWants > 0) {
            _expenses.add(Expense(id: 'legacy_want', category: 'Want', amount: oldWants, profileId: _activeWalletId!, date: DateTime.now()));
        }
        if (oldSavings != null && oldSavings > 0) {
            _expenses.add(Expense(id: 'legacy_saving', category: 'Saving', amount: oldSavings, profileId: _activeWalletId!, date: DateTime.now()));
        }
        if (_expenses.isNotEmpty) {
            _saveExpenses();
        }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveWallets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('expense_profiles_data', json.encode(_wallets.map((p) => p.toJson()).toList()));
    if (_activeWalletId != null) {
        await prefs.setString('active_profile_id', _activeWalletId!);
    }
  }

  Future<void> _saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('expenses_data', json.encode(_expenses.map((e) => e.toJson()).toList()));
  }

  Future<void> _resetExpenses() async {
    setState(() {
      _expenses.removeWhere((e) => e.profileId == _activeWalletId);
    });
    await _saveExpenses();
  }

  void _deleteWallet(Wallet wallet) {
    if (_wallets.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the last wallet.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Wallet?'),
        content: Text('Are you sure you want to delete "${wallet.name}" and all its expenses?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _wallets.remove(wallet);
                if (_activeWalletId == wallet.id) {
                  _activeWalletId = _wallets.first.id;
                }
              });
              _saveWallets();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _addExpense(String category, double amount) {
    if (_activeWalletId == null) return;
    
    final newExpense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: category,
      amount: amount,
      profileId: _activeWalletId!,
      date: DateTime.now(),
    );
    
    setState(() {
      _expenses.add(newExpense);
    });
    _saveExpenses();
  }

  void _showAddWalletDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Wallet'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Wallet Name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              final newWallet = Wallet(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: controller.text.trim(),
              );
              setState(() {
                  _wallets.add(newWallet);
                  _activeWalletId = newWallet.id;
              });
              _saveWallets();
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showWalletSettingsDialog(Wallet wallet) {
    final needsCtrl = TextEditingController(text: wallet.needsRatio.toStringAsFixed(0));
    final wantsCtrl = TextEditingController(text: wallet.wantsRatio.toStringAsFixed(0));
    final savingsCtrl = TextEditingController(text: wallet.savingsRatio.toStringAsFixed(0));
    final incomeCtrl = TextEditingController(text: wallet.initialIncome.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wallet Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: incomeCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monthly Income (\$)'),
              ),
              const SizedBox(height: 16),
              const Text('Rule Breakdown (%)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: needsCtrl, decoration: const InputDecoration(labelText: 'Needs'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: wantsCtrl, decoration: const InputDecoration(labelText: 'Wants'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: savingsCtrl, decoration: const InputDecoration(labelText: 'Savings'), keyboardType: TextInputType.number)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = double.tryParse(needsCtrl.text) ?? 0;
              final w = double.tryParse(wantsCtrl.text) ?? 0;
              final s = double.tryParse(savingsCtrl.text) ?? 0;
              final inc = double.tryParse(incomeCtrl.text) ?? 0;
              
              if ((n + w + s) != 100.0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Percentages must sum exactly to 100.')));
                  return;
              }
              
              setState(() {
                  wallet.needsRatio = n;
                  wallet.wantsRatio = w;
                  wallet.savingsRatio = s;
                  wallet.initialIncome = inc;
              });
              _saveWallets();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    String selectedCategory = 'Need';
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Expense'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  items: ['Need', 'Want', 'Saving'].map((String category) {
                    return DropdownMenuItem(
                        value: category, child: Text(category));
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedCategory = val!;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (\$)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (amountController.text.isNotEmpty) {
                    final double? amount =
                        double.tryParse(amountController.text);
                    if (amount != null) {
                      _addExpense(selectedCategory, amount);
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildCategoryCard(
      String title, double spent, double limit, Color color) {
    final double progress = (limit > 0) ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final bool overBudget = spent > limit;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, 
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: 3,
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 2,
                  child: Text(
                    '\$${spent.toStringAsFixed(0)} / \$${limit.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0), 
              child: LinearProgressIndicator(
                value: progress,
                color: overBudget ? Colors.red : color,
                backgroundColor: color.withAlpha(51),
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            if (overBudget)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                    'Over budget by \$${(spent - limit).toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeWallet = _wallets.firstWhere(
      (p) => p.id == _activeWalletId,
      orElse: () => _wallets.first,
    );

    final activeExpenses = _expenses.where((e) => e.profileId == activeWallet.id).toList();

    double nSpent = 0;
    double wSpent = 0;
    double sSpent = 0;
    for (var e in activeExpenses) {
      if (e.category == 'Need') {
        nSpent += e.amount;
      } else if (e.category == 'Want') {
        wSpent += e.amount;
      } else if (e.category == 'Saving') {
        sSpent += e.amount;
      }
    }

    final nLimit = activeWallet.initialIncome * (activeWallet.needsRatio / 100);
    final wLimit = activeWallet.initialIncome * (activeWallet.wantsRatio / 100);
    final sLimit = activeWallet.initialIncome * (activeWallet.savingsRatio / 100);

    final walletSelector = SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _wallets.length + 1,
        itemBuilder: (context, index) {
          if (index == _wallets.length) {
            return Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: ActionChip(
                label: const Text('+ New', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.transparent,
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                onPressed: _showAddWalletDialog,
              ),
            );
          }

          final wallet = _wallets[index];
          final isActive = wallet.id == _activeWalletId;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onLongPress: () => _deleteWallet(wallet),
              child: ChoiceChip(
                label: Text(wallet.name),
                selected: isActive,
                selectedColor: Theme.of(context).colorScheme.primary.withAlpha(51),
                backgroundColor: const Color(0xFF1E1E1E),
                labelStyle: TextStyle(
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _activeWalletId = wallet.id;
                    });
                    _saveWallets();
                  }
                },
              ),
            ),
          );
        },
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            walletSelector,
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    const Text('Monthly Income',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _showWalletSettingsDialog(activeWallet),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('\$${activeWallet.initialIncome.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(width: 8),
                            Icon(Icons.edit, color: Theme.of(context).colorScheme.primary, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => _showWalletSettingsDialog(activeWallet),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${activeWallet.needsRatio.toStringAsFixed(0)}/${activeWallet.wantsRatio.toStringAsFixed(0)}/${activeWallet.savingsRatio.toStringAsFixed(0)} Breakdown',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.edit, size: 16, color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
                  onPressed: _resetExpenses,
                  tooltip: 'Reset Expenses',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCategoryCard(
                'Needs (${activeWallet.needsRatio.toStringAsFixed(0)}%)', nSpent, nLimit, Colors.blue),
            const SizedBox(height: 12),
            _buildCategoryCard(
                'Wants (${activeWallet.wantsRatio.toStringAsFixed(0)}%)', wSpent, wLimit, Colors.orange),
            const SizedBox(height: 12),
            _buildCategoryCard('Savings (${activeWallet.savingsRatio.toStringAsFixed(0)}%)', sSpent,
                sLimit, Colors.green),
            const SizedBox(height: 100), // Prevent FAB overlap
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddExpenseDialog(context);
        },
        label: const Text('Add Expense'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
