import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/wallet_model.dart';
import 'profile_screen.dart';
import 'calendar_screen.dart';

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
  StreamSubscription? _walletsSub;
  StreamSubscription? _expensesSub;

  @override
  void dispose() {
    _walletsSub?.cancel();
    _expensesSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _walletsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('profiles')
        .snapshots()
        .listen((snapshot) async {
      final loadedWallets = snapshot.docs.map((doc) => Wallet.fromJson(doc.data())).toList();

      if (loadedWallets.isEmpty) {
        final defaultWallet = Wallet(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Default Wallet',
        );
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('profiles')
            .doc(defaultWallet.id)
            .set(defaultWallet.toJson());
        return;
      }

      if (mounted) {
        setState(() {
          _wallets = loadedWallets;
          if (_activeWalletId == null || !loadedWallets.any((p) => p.id == _activeWalletId)) {
            _activeWalletId = loadedWallets.first.id;
          }
          _isLoading = false;
        });
      }
    });

    _expensesSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .snapshots()
        .listen((snapshot) {
      final loadedExpenses = snapshot.docs.map((doc) => Expense.fromJson(doc.data())).toList();
      if (mounted) {
        setState(() => _expenses = loadedExpenses);
      }
    });
  }

  Future<void> _resetExpenses() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _activeWalletId == null) return;
    
    final batch = FirebaseFirestore.instance.batch();
    final activeExps = _expenses.where((e) => e.profileId == _activeWalletId);
    for (var ex in activeExps) {
        final docRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('expenses').doc(ex.id);
        batch.delete(docRef);
    }
    await batch.commit();
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
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                await FirebaseFirestore.instance.collection('users').doc(uid).collection('profiles').doc(wallet.id).delete();
              }
              if (!context.mounted) return;
              Navigator.pop(context);
              if (mounted) {
                  setState(() {
                    if (_activeWalletId == wallet.id) {
                      _activeWalletId = _wallets.firstWhere((p) => p.id != wallet.id).id;
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

  void _addExpense(String category, double amount) async {
    if (_activeWalletId == null) return;
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final newExpense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: category,
      amount: amount,
      profileId: _activeWalletId!,
      date: DateTime.now(),
    );
    
    await FirebaseFirestore.instance.collection('users').doc(uid).collection('expenses').doc(newExpense.id).set(newExpense.toJson());
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
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final newWallet = Wallet(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: controller.text.trim(),
              );
              
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                  await FirebaseFirestore.instance.collection('users').doc(uid).collection('profiles').doc(newWallet.id).set(newWallet.toJson());
              }
              
              if (!context.mounted) return;
              Navigator.pop(context);
              if (mounted) {
                  setState(() {
                      _activeWalletId = newWallet.id;
                  });
              }
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
            onPressed: () async {
              final n = double.tryParse(needsCtrl.text) ?? 0;
              final w = double.tryParse(wantsCtrl.text) ?? 0;
              final s = double.tryParse(savingsCtrl.text) ?? 0;
              final inc = double.tryParse(incomeCtrl.text) ?? 0;
              
              if ((n + w + s) != 100.0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Percentages must sum exactly to 100.')));
                  return;
              }
              
              wallet.needsRatio = n;
              wallet.wantsRatio = w;
              wallet.savingsRatio = s;
              wallet.initialIncome = inc;

              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                  await FirebaseFirestore.instance.collection('users').doc(uid).collection('profiles').doc(wallet.id).set(wallet.toJson());
              }
              
              if (!context.mounted) return;
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
                  // ignore: deprecated_member_use
                  value: selectedCategory,
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF0F0F0F),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, 
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                ),
                Text(
                  '\$${spent.toStringAsFixed(0)} / \$${limit.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                color: color,
                backgroundColor: color.withValues(alpha: 0.1),
                minHeight: 8,
              ),
            ),
            if (overBudget)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                        'Over by \$${(spent - limit).toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.grey.shade600,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.edit_outlined, size: 10, color: Colors.grey.shade600),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    if (_activeWalletId == null && _wallets.isNotEmpty) {
      _activeWalletId = _wallets.first.id;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Wallet Locked',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please sign in to track your expenses.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
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

    double totalExpenses = 0;
    for (var e in activeExpenses) {
      totalExpenses += e.amount;
    }

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
                  }
                },
              ),
            ),
          );
        },
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CalendarScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            walletSelector,
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                children: [
                  // Unified Summary Card
                  Card(
                    margin: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                    color: const Color(0xFF1A1A1A),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOTAL EXPENSES',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.refresh, size: 18, color: Colors.grey.shade600),
                                onPressed: _resetExpenses,
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$${totalExpenses.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                _buildSummaryMetric(
                                  label: 'INCOME',
                                  value: '\$${activeWallet.initialIncome.toStringAsFixed(0)}',
                                  onTap: () => _showWalletSettingsDialog(activeWallet),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BUDGET BREAKDOWN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '${activeWallet.needsRatio.toStringAsFixed(0)}/${activeWallet.wantsRatio.toStringAsFixed(0)}/${activeWallet.savingsRatio.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildCategoryCard('Needs', nSpent, nLimit, Colors.blueAccent),
                        const SizedBox(height: 12),
                        _buildCategoryCard('Wants', wSpent, wLimit, Colors.orangeAccent),
                        const SizedBox(height: 12),
                        _buildCategoryCard('Savings', sSpent, sLimit, Colors.greenAccent),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  
                  if (activeExpenses.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                      child: Text(
                        'RECENT EXPENSES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    ...activeExpenses.reversed.take(10).map((expense) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: const Color(0xFF0F0F0F),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: expense.category == 'Need' 
                                ? Colors.blueAccent.withAlpha(51)
                                : expense.category == 'Want'
                                    ? Colors.orangeAccent.withAlpha(51)
                                    : Colors.greenAccent.withAlpha(51),
                            child: Icon(
                              expense.category == 'Need' 
                                  ? Icons.shopping_bag_outlined 
                                  : expense.category == 'Want'
                                      ? Icons.celebration_outlined
                                      : Icons.savings_outlined,
                              size: 18,
                              color: expense.category == 'Need' 
                                  ? Colors.blueAccent 
                                  : expense.category == 'Want'
                                      ? Colors.orangeAccent
                                      : Colors.greenAccent,
                            ),
                          ),
                          title: Text(
                            expense.category,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text(
                            '${expense.date.day}/${expense.date.month}/${expense.date.year}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          trailing: Text(
                            '-\$${expense.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddExpenseDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
