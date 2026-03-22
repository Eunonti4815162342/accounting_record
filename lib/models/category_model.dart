import 'package:flutter/material.dart';

class CategoryModel {
  final int? id;
  final String name;
  final int iconCodePoint;
  final int colorValue;

  CategoryModel({
    this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'],
      name: map['name'],
      iconCodePoint: map['iconCodePoint'],
      colorValue: map['colorValue'],
    );
  }

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);
}
