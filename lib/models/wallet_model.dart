class Wallet {
  final String id;
  String name;
  double initialIncome;
  double needsRatio;
  double wantsRatio;
  double savingsRatio;
  List<String> expenseIds;

  Wallet({
    required this.id,
    required this.name,
    this.initialIncome = 5000.0,
    this.needsRatio = 50.0,
    this.wantsRatio = 30.0,
    this.savingsRatio = 20.0,
    List<String>? expenseIds,
  }) : expenseIds = expenseIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'initialIncome': initialIncome,
        'needsRatio': needsRatio,
        'wantsRatio': wantsRatio,
        'savingsRatio': savingsRatio,
        'expenseIds': expenseIds,
      };

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        id: json['id'],
        name: json['name'],
        initialIncome: json['initialIncome']?.toDouble() ?? 5000.0,
        needsRatio: json['needsRatio']?.toDouble() ?? 50.0,
        wantsRatio: json['wantsRatio']?.toDouble() ?? 30.0,
        savingsRatio: json['savingsRatio']?.toDouble() ?? 20.0,
        expenseIds: (json['expenseIds'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      );
}

class Expense {
  final String id;
  final String category; // 'Need', 'Want', 'Saving'
  final double amount;
  final String profileId;
  final DateTime date;

  Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.profileId,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'amount': amount,
        'profileId': profileId,
        'date': date.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'],
        category: json['category'],
        amount: json['amount']?.toDouble() ?? 0.0,
        profileId: json['profileId'],
        date: DateTime.parse(json['date']),
      );
}
