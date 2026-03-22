import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../services/database_service.dart';

import '../models/scheduled_transaction_model.dart';

class AccountingProvider with ChangeNotifier {
  List<AccountModel> _accounts = [];
  List<CategoryModel> _categories = [];
  List<TransactionModel> _transactions = [];
  List<ScheduledTransactionModel> _scheduledTransactions = [];
    bool _isLoading = true;
    AccountModel? _selectedAccount; // null significa "Todas las cuentas"
    Map<int, double> _transactionBalances = {}; // Cache de saldos post-transacción
  
    List<AccountModel> get accounts => _accounts;
    List<CategoryModel> get categories => _categories;
    List<ScheduledTransactionModel> get scheduledTransactions => _scheduledTransactions;
    
    double getTransactionBalance(int txId) => _transactionBalances[txId] ?? 0.0;
  
    List<TransactionModel> get transactions {
  
    if (_selectedAccount == null) return _transactions;
    return _transactions.where((tx) => tx.accountId == _selectedAccount!.id).toList();
  }
  bool get isLoading => _isLoading;
  AccountModel? get selectedAccount => _selectedAccount;

  AccountingProvider() {
    loadData();
  }

  void setSelectedAccount(AccountModel? account) {
    _selectedAccount = account;
    notifyListeners();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      _accounts = await DatabaseService.instance.getAllAccounts();
      _categories = await DatabaseService.instance.getAllCategories();
      _transactions = await DatabaseService.instance.getAllTransactions();
      
      try {
        _scheduledTransactions = await DatabaseService.instance.getAllScheduledTransactions();
      } catch (e) {
        debugPrint("Error loading scheduled transactions: $e");
        _scheduledTransactions = []; // Fallback a lista vacía para evitar fallos mayores
      }
      
      _calculateHistoricalBalances();
    } catch (e) {
      debugPrint("Error loading data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _calculateHistoricalBalances() {
    Map<int, double> tempBalances = {};
    Map<int, double> currentRunningBalances = {};

    // 1. Obtener el saldo actual de cada cuenta
    for (var acc in _accounts) {
      currentRunningBalances[acc.id!] = getAccountBalance(acc);
    }

    // 2. Iterar transacciones (vienen ordenadas DESC: de más reciente a más antigua)
    // El saldo de la más reciente ES el saldo actual.
    for (var tx in _transactions) {
      tempBalances[tx.id!] = currentRunningBalances[tx.accountId]!;
      
      // 3. Deshacer el impacto de la transacción para obtener el saldo previo
      if (tx.type == TransactionType.income || tx.type == TransactionType.transferIn) {
        currentRunningBalances[tx.accountId] = currentRunningBalances[tx.accountId]! - tx.amount;
      } else {
        currentRunningBalances[tx.accountId] = currentRunningBalances[tx.accountId]! + tx.amount;
      }
    }
    _transactionBalances = tempBalances;
  }

  Future<void> removeScheduledTransaction(int id) async {
    await DatabaseService.instance.deleteScheduledTransaction(id);
    await loadData();
  }

  Future<void> addAccount(AccountModel account) async {
    await DatabaseService.instance.insertAccount(account);
    await loadData();
  }

  Future<void> updateAccount(AccountModel account) async {
    await DatabaseService.instance.updateAccount(account);
    await loadData();
  }

  Future<void> removeAccount(int id) async {
    await DatabaseService.instance.deleteAccount(id);
    if (_selectedAccount?.id == id) {
      _selectedAccount = null;
    }
    await loadData();
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    await DatabaseService.instance.insertTransaction(transaction);
    await loadData();
  }

  Future<void> editTransaction(TransactionModel transaction) async {
    await DatabaseService.instance.updateTransaction(transaction);
    await loadData();
  }

  Future<void> addTransfer(TransactionModel transfer) async {
    await DatabaseService.instance.insertTransfer(transfer);
    await loadData();
  }

  Future<int?> addScheduledTransaction(ScheduledTransactionModel scheduled) async {
    final response = await DatabaseService.instance.insertScheduledTransaction(scheduled);
    // Esperamos un momento para que el servidor genere las transacciones reales
    await Future.delayed(const Duration(milliseconds: 1000));
    await loadData();
    return response;
  }

  Future<void> removeTransaction(int id) async {
    await DatabaseService.instance.deleteTransaction(id);
    await loadData();
  }

  double get totalBalance {
    double liquidBalance = 0;
    // Solo sumamos el saldo de las cuentas de ACTIVO (dinero real disponible)
    for (var acc in _accounts.where((a) => a.type == 'ASSET')) {
      liquidBalance += acc.initialBalance;
      // Añadir transacciones de esta cuenta de activo
      final accTransactions = _transactions.where((t) => t.accountId == acc.id);
      for (var tx in accTransactions) {
        if (tx.type == TransactionType.income || tx.type == TransactionType.transferIn) {
          liquidBalance += tx.amount;
        } else {
          liquidBalance -= tx.amount;
        }
      }
    }
    
    // Si hay una cuenta seleccionada específicamente, devolvemos solo su balance
    if (_selectedAccount != null) {
      double accBal = _selectedAccount!.initialBalance;
      final accTxs = _transactions.where((t) => t.accountId == _selectedAccount!.id);
      for (var tx in accTxs) {
        if (tx.type == TransactionType.income || tx.type == TransactionType.transferIn) {
          accBal += tx.amount;
        } else {
          accBal -= tx.amount;
        }
      }
      return accBal;
    }

    return liquidBalance;
  }

  double get totalAssets {
    double assets = 0.0;
    
    for (var acc in _accounts.where((acc) => acc.type == 'ASSET')) {
      assets += acc.initialBalance;
      
      final accTxs = _transactions.where((tx) => tx.accountId == acc.id);
      for (var tx in accTxs) {
        if (tx.type == TransactionType.income || tx.type == TransactionType.transferIn) {
          assets += tx.amount;
        } else {
          assets -= tx.amount;
        }
      }
    }
    return assets;
  }

  double get totalLiabilities {
    double totalRemainingDebt = 0.0;
    
    for (var acc in _accounts.where((a) => a.type == 'LIABILITY')) {
      // Deuda Inicial Real = Monto Total - Lo que ya se había pagado al crear la cuenta
      double initialDebt = (acc.totalAmount ?? 0.0) - acc.initialBalance;
      
      // Calcular variaciones por transacciones (TRANSFER_IN reduce deuda, TRANSFER_OUT o EXPENSE la aumenta)
      double transactionImpact = 0.0;
      final accountTransactions = _transactions.where((tx) => tx.accountId == acc.id);
      
      for (var tx in accountTransactions) {
        if (tx.type == TransactionType.income || tx.type == TransactionType.transferIn) {
          transactionImpact -= tx.amount; // Pago reduce la deuda pendiente
        } else {
          transactionImpact += tx.amount; // Cargo aumenta la deuda pendiente
        }
      }
      
      totalRemainingDebt += (initialDebt + transactionImpact);
    }
    
    return totalRemainingDebt;
  }

  double get netWorth => totalAssets - totalLiabilities;

  double get totalIncome {
    // Definimos ingresos como cualquier entrada de dinero (+): INCOME o TRANSFER_IN
    return transactions
        .where((tx) => tx.type == TransactionType.income || tx.type == TransactionType.transferIn)
        .fold(0, (sum, tx) => sum + tx.amount);
  }

  double get totalExpenses {
    // Definimos gastos como cualquier salida de dinero (-): EXPENSE o TRANSFER_OUT
    return transactions
        .where((tx) => tx.type == TransactionType.expense || tx.type == TransactionType.transferOut)
        .fold(0, (sum, tx) => sum + tx.amount);
  }

  double _calculateBalance(List<TransactionModel> txs) {
    double balance = 0;
    for (var tx in txs) {
      if (tx.type == TransactionType.income || tx.type == TransactionType.transferIn) {
        balance += tx.amount;
      } else {
        balance -= tx.amount;
      }
    }
    return balance;
  }

  CategoryModel? getCategoryById(int id) {
    try {
      return _categories.firstWhere((cat) => cat.id == id);
    } catch (e) {
      return null;
    }
  }

  AccountModel? getAccountById(int id) {
    try {
      return _accounts.firstWhere((acc) => acc.id == id);
    } catch (e) {
      return null;
    }
  }

  double getAccountBalance(AccountModel account) {
    // Calculamos el impacto neto de los movimientos: (Ingresos + Entradas) - (Gastos + Salidas)
    double movementsImpact = 0.0;
    final accTxs = _transactions.where((t) => t.accountId == account.id);
    
    for (var tx in accTxs) {
      if (tx.type == TransactionType.income || tx.type == TransactionType.transferIn) {
        movementsImpact += tx.amount;
      } else {
        movementsImpact -= tx.amount;
      }
    }

    if (account.type == 'LIABILITY') {
      // DEUDA PENDIENTE = Monto Total - (Lo pagado inicial + Impacto de movimientos)
      // Si movementsImpact es positivo (un pago/ingreso), sube 'alreadyPaid' y baja la deuda final.
      double totalToPay = account.totalAmount ?? 0.0;
      double currentlyPaid = account.initialBalance + movementsImpact;
      
      return -(totalToPay - currentlyPaid);
    } else {
      // ACTIVO = Saldo Inicial + Impacto de movimientos
      return account.initialBalance + movementsImpact;
    }
  }
}
