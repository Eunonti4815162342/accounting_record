import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/shared_expense_models.dart';

class SharedGroupProvider with ChangeNotifier {
  final String _baseUrl = 'http://localhost:8080/api/v2/shared/groups';
  final _storage = const FlutterSecureStorage();

  List<SharedGroupModel> _groups = [];
  Map<int, Map<int, double>> _groupBalances = {}; // {groupId: {userId: balance}}
  bool _isLoading = false;

  List<SharedGroupModel> get groups => _groups;
  bool get isLoading => _isLoading;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> loadGroups() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(Uri.parse(_baseUrl), headers: await _getHeaders());
      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        _groups = data.map((json) => SharedGroupModel.fromMap(json)).toList();
        
        for (var group in _groups) {
          await loadBalances(group.id!);
        }
      }
    } catch (e) {
      debugPrint("Error loading groups: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadBalances(int groupId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/$groupId/balances'), headers: await _getHeaders());
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        _groupBalances[groupId] = data.map((key, value) => MapEntry(int.parse(key), (value as num).toDouble()));
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading balances for group $groupId: $e");
    }
  }

  double? getUserBalanceInGroup(int groupId, int userId) {
    return _groupBalances[groupId]?[userId];
  }

  Future<void> createGroup(String name, List<int> initialMembers) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: await _getHeaders(),
      body: jsonEncode({
        'name': name,
        'memberIds': initialMembers,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      await loadGroups();
    }
  }

  Future<void> addExpense(GroupExpenseModel expense) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/${expense.groupId}/expenses'),
      headers: await _getHeaders(),
      body: jsonEncode(expense.toMap()),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      await loadBalances(expense.groupId);
    }
  }

  Future<List<GroupExpenseModel>> getExpenses(int groupId) async {
    final response = await http.get(Uri.parse('$_baseUrl/$groupId/expenses'), headers: await _getHeaders());
    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((json) => GroupExpenseModel.fromMap(json)).toList();
    }
    return [];
  }
}
