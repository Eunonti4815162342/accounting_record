import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../models/scheduled_transaction_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static const String _baseUrl = 'http://localhost:8080/api/v2'; 
  final _storage = const FlutterSecureStorage();

  DatabaseService._init();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Accounts CRUD
  Future<List<AccountModel>> getAllAccounts() async {
    final response = await http.get(Uri.parse('$_baseUrl/accounts'), headers: await _getHeaders());
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((json) => AccountModel.fromMap(json)).toList();
    }
    throw Exception('Error al cargar cuentas');
  }

  Future<int> insertAccount(AccountModel account) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/accounts'),
      headers: await _getHeaders(),
      body: json.encode(account.toMap()),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body)['id'];
    }
    throw Exception('Error al crear cuenta');
  }

  Future<void> deleteAccount(int id) async {
    await http.delete(Uri.parse('$_baseUrl/accounts/$id'), headers: await _getHeaders());
  }

  Future<void> updateAccount(AccountModel account) async {
    await http.put(
      Uri.parse('$_baseUrl/accounts/${account.id}'),
      headers: await _getHeaders(),
      body: json.encode(account.toMap()),
    );
  }

  // Categories CRUD
  Future<List<CategoryModel>> getAllCategories() async {
    final response = await http.get(Uri.parse('$_baseUrl/categories'), headers: await _getHeaders());
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((json) => CategoryModel.fromMap(json)).toList();
    }
    throw Exception('Error al cargar categorías');
  }

  // Transactions CRUD
  Future<List<TransactionModel>> getAllTransactions() async {
    final response = await http.get(Uri.parse('$_baseUrl/transactions'), headers: await _getHeaders());
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((json) => TransactionModel.fromMap(json)).toList();
    }
    throw Exception('Error al cargar transacciones');
  }

  Future<int> insertTransaction(TransactionModel transaction) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/transactions'),
      headers: await _getHeaders(),
      body: json.encode(transaction.toMap()),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body)['id'];
    }
    throw Exception('Error al registrar transacción');
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/transactions/${transaction.id}'),
      headers: await _getHeaders(),
      body: json.encode(transaction.toMap()),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al actualizar transacción');
    }
  }

  Future<void> deleteTransaction(int id) async {
    await http.delete(Uri.parse('$_baseUrl/transactions/$id'), headers: await _getHeaders());
  }

  Future<void> insertTransfer(TransactionModel transaction) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/transfers'),
      headers: await _getHeaders(),
      body: json.encode(transaction.toMap()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error al registrar transferencia');
    }
  }

  Future<int> insertScheduledTransaction(ScheduledTransactionModel scheduled) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/scheduled'),
      headers: await _getHeaders(),
      body: json.encode(scheduled.toMap()),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body)['id'];
    }
    throw Exception('Error al programar transacción recurrente');
  }

  Future<List<ScheduledTransactionModel>> getAllScheduledTransactions() async {
    final response = await http.get(Uri.parse('$_baseUrl/scheduled'), headers: await _getHeaders());
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((json) => ScheduledTransactionModel.fromMap(json)).toList();
    }
    throw Exception('Error al cargar transacciones programadas');
  }

  Future<void> deleteScheduledTransaction(int id) async {
    await http.delete(Uri.parse('$_baseUrl/scheduled/$id'), headers: await _getHeaders());
  }
}
