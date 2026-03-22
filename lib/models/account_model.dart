import 'package:flutter/material.dart';

class AccountModel {
  final int? id;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final double initialBalance;
  final String type; // ASSET or LIABILITY
  final double? totalAmount; // For debts like mortgages
  final int? linkedAccountId;

  AccountModel({
    this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    this.initialBalance = 0.0,
    this.type = 'ASSET',
    this.totalAmount,
    this.linkedAccountId,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'initialBalance': initialBalance,
      'type': type,
      'totalAmount': totalAmount,
      'linkedAccountId': linkedAccountId,
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id'],
      name: map['name'] ?? '',
      iconCodePoint: map['iconCodePoint'] ?? 0,
      colorValue: map['colorValue'] ?? 0,
      initialBalance: (map['initialBalance'] ?? 0.0).toDouble(),
      type: map['type'] ?? 'ASSET',
      totalAmount: map['totalAmount'] != null ? (map['totalAmount'] as num).toDouble() : null,
      linkedAccountId: map['linkedAccountId'],
    );
  }

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);
}
