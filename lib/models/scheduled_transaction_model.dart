class ScheduledTransactionModel {
  final int? id;
  final String name;
  final double amount;
  final int categoryId;
  final int accountId;
  final int? transferAccountId;
  final String type; // INCOME, EXPENSE, TRANSFER
  final String frequency; // DAILY, WEEKLY, MONTHLY, YEARLY
  final DateTime nextExecutionDate;
  final bool active;

  ScheduledTransactionModel({
    this.id,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    this.transferAccountId,
    required this.type,
    required this.frequency,
    required this.nextExecutionDate,
    this.active = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'amount': amount,
      'categoryId': categoryId,
      'accountId': accountId,
      'transferAccountId': transferAccountId,
      'type': type,
      'frequency': frequency,
      'nextExecutionDate': nextExecutionDate.toIso8601String().split('T')[0],
      'active': active,
    };
  }

  factory ScheduledTransactionModel.fromMap(Map<String, dynamic> map) {
    return ScheduledTransactionModel(
      id: map['id'],
      name: map['name'] ?? 'Recurrente',
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'] ?? map['category_id'],
      accountId: map['accountId'] ?? map['account_id'],
      transferAccountId: map['transferAccountId'] ?? map['transfer_account_id'],
      type: map['type'] ?? 'EXPENSE',
      frequency: map['frequency'] ?? 'MONTHLY',
      nextExecutionDate: DateTime.parse(map['nextExecutionDate'] ?? map['next_execution_date']),
      active: map['active'] ?? true,
    );
  }
}
