enum TransactionType { income, expense, transferIn, transferOut }

class TransactionModel {
  final int? id;
  final double amount;
  final int categoryId;
  final int accountId;
  final DateTime date;
  final String? note;
  final TransactionType type;
  final int? transferAccountId;
  final int? scheduledId;

  TransactionModel({
    this.id,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    required this.date,
    this.note,
    required this.type,
    this.transferAccountId,
    this.scheduledId,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'categoryId': categoryId,
      'accountId': accountId,
      'date': date.toIso8601String(),
      'note': note,
      'type': _typeToString(type),
      'transferAccountId': transferAccountId,
      'scheduledId': scheduledId,
    };
  }

  static String _typeToString(TransactionType type) {
    switch (type) {
      case TransactionType.income: return 'INCOME';
      case TransactionType.expense: return 'EXPENSE';
      case TransactionType.transferIn: return 'TRANSFER_IN';
      case TransactionType.transferOut: return 'TRANSFER_OUT';
    }
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'],
      accountId: map['accountId'],
      date: DateTime.parse(map['date']),
      note: map['note'],
      type: _typeFromString(map['type']),
      transferAccountId: map['transferAccountId'],
      scheduledId: map['scheduledId'],
    );
  }

  static TransactionType _typeFromString(String type) {
    switch (type.toUpperCase()) {
      case 'INCOME': return TransactionType.income;
      case 'EXPENSE': return TransactionType.expense;
      case 'TRANSFER_IN': return TransactionType.transferIn;
      case 'TRANSFER_OUT': return TransactionType.transferOut;
      default: return TransactionType.expense;
    }
  }
}
