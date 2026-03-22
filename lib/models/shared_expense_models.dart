class SharedGroupModel {
  final int? id;
  final String name;
  final List<int> memberIds;

  SharedGroupModel({this.id, required this.name, required this.memberIds});

  factory SharedGroupModel.fromMap(Map<String, dynamic> map) {
    return SharedGroupModel(
      id: map['id'],
      name: map['name'],
      memberIds: List<int>.from(map['memberIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'memberIds': memberIds,
    };
  }
}

class GroupExpenseModel {
  final int? id;
  final int groupId;
  final String description;
  final double totalAmount;
  final int paidByUserId;
  final DateTime date;
  final List<ExpenseSplitModel> splits;

  GroupExpenseModel({
    this.id,
    required this.groupId,
    required this.description,
    required this.totalAmount,
    required this.paidByUserId,
    required this.date,
    required this.splits,
  });

  factory GroupExpenseModel.fromMap(Map<String, dynamic> map) {
    return GroupExpenseModel(
      id: map['id'],
      groupId: map['groupId'],
      description: map['description'],
      totalAmount: (map['totalAmount'] as num).toDouble(),
      paidByUserId: map['paidByUserId'],
      date: DateTime.parse(map['date']),
      splits: (map['splits'] as List).map((s) => ExpenseSplitModel.fromMap(s)).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'description': description,
      'totalAmount': totalAmount,
      'paidByUserId': paidByUserId,
      'date': date.toIso8601String(),
      'splits': splits.map((s) => s.toMap()).toList(),
    };
  }
}

class ExpenseSplitModel {
  final int userId;
  final double amount;

  ExpenseSplitModel({required this.userId, required this.amount});

  factory ExpenseSplitModel.fromMap(Map<String, dynamic> map) {
    return ExpenseSplitModel(
      userId: map['userId'],
      amount: (map['amount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
    };
  }
}
