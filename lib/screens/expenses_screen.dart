import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  // Mock data for tracking 50/30/20 rules
  double _monthlyIncome = 5000.0;
  bool _isLoading = true;

  double _needsSpent = 2100.0;
  double _wantsSpent = 1600.0;
  double _savingsSpent = 800.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final double? income = prefs.getDouble('monthly_income');
    final double? needs = prefs.getDouble('needs_spent');
    final double? wants = prefs.getDouble('wants_spent');
    final double? savings = prefs.getDouble('savings_spent');
    
    if (mounted) {
      setState(() {
        if (income != null) _monthlyIncome = income;
        if (needs != null) _needsSpent = needs;
        if (wants != null) _wantsSpent = wants;
        if (savings != null) _savingsSpent = savings;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveIncome(double newIncome) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('monthly_income', newIncome);
  }

  Future<void> _saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('needs_spent', _needsSpent);
    await prefs.setDouble('wants_spent', _wantsSpent);
    await prefs.setDouble('savings_spent', _savingsSpent);
  }

  Future<void> _resetExpenses() async {
    setState(() {
      _needsSpent = 0.0;
      _wantsSpent = 0.0;
      _savingsSpent = 0.0;
    });
    await _saveExpenses();
  }

  void _showEditIncomeDialog() {
    final controller = TextEditingController(text: _monthlyIncome.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Monthly Income'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Monthly Income (\$)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final double? amount = double.tryParse(controller.text);
              if (amount != null && amount >= 0) {
                setState(() {
                  _monthlyIncome = amount;
                });
                _saveIncome(amount);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addExpense(String category, double amount) {
    setState(() {
      if (category == 'Need') {
        _needsSpent += amount;
      } else if (category == 'Want') {
        _wantsSpent += amount;
      } else if (category == 'Saving') {
        _savingsSpent += amount;
      }
    });
    _saveExpenses();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final double needsLimit = _monthlyIncome * 0.5;
    final double wantsLimit = _monthlyIncome * 0.3;
    final double savingsLimit = _monthlyIncome * 0.2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Expenses'),
      ),
      body: SafeArea(
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
                      onTap: _showEditIncomeDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('\$${_monthlyIncome.toStringAsFixed(2)}',
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
                const Text('50/30/20 Rule Breakdown',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
                  onPressed: _resetExpenses,
                  tooltip: 'Reset Expenses',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCategoryCard(
                'Needs (50%)', _needsSpent, needsLimit, Colors.blue),
            const SizedBox(height: 12),
            _buildCategoryCard(
                'Wants (30%)', _wantsSpent, wantsLimit, Colors.orange),
            const SizedBox(height: 12),
            _buildCategoryCard('Savings/Investments (20%)', _savingsSpent,
                savingsLimit, Colors.green),
            const SizedBox(height: 100), // Prevent FAB overlap, increased to 100
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
          mainAxisSize: MainAxisSize.min, // Make card height dynamic
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: 3,
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
              padding: const EdgeInsets.symmetric(horizontal: 4.0), // Padding for progress bar
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
                    final double? amount = double.tryParse(amountController.text);
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
}
