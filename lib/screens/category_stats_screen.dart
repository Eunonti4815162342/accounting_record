import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import 'add_transaction_screen.dart';

class CategoryStatsScreen extends StatefulWidget {
  const CategoryStatsScreen({super.key});

  @override
  State<CategoryStatsScreen> createState() => _CategoryStatsScreenState();
}

class _CategoryStatsScreenState extends State<CategoryStatsScreen> {
  bool _isYearly = false;
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AccountingProvider>(context);
    final stats = _calculateStats(provider);
    final double totalAmount = stats.values.fold(0, (sum, item) => sum + item['amount']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis por Categoría'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                const Text('Mes', style: TextStyle(fontSize: 12)),
                Switch(
                  value: _isYearly,
                  onChanged: (val) => setState(() => _isYearly = val),
                ),
                const Text('Año', style: TextStyle(fontSize: 12)),
              ],
            ),
          )
        ],
      ),
      body: stats.isEmpty
          ? const Center(child: Text('No hay datos para mostrar'))
          : Column(
              children: [
                const SizedBox(height: 20),
                SizedBox(
                  height: 250,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _buildChartSections(stats, totalAmount),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: stats.length,
                    itemBuilder: (context, index) {
                      final categoryId = stats.keys.elementAt(index);
                      final data = stats[categoryId]!;
                      final CategoryModel? category = provider.getCategoryById(categoryId);
                      final percentage = (data['amount'] / totalAmount) * 100;
                      final categoryTransactions = _getTransactionsForCategory(provider, categoryId);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
                        child: ExpansionTile(
                          shape: const RoundedRectangleBorder(side: BorderSide.none),
                          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                          leading: CircleAvatar(
                            backgroundColor: category?.color.withValues(alpha: 0.1),
                            child: Icon(category?.icon ?? Icons.category, color: category?.color, size: 20),
                          ),
                          title: Text(category?.name ?? 'Otros', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${percentage.toStringAsFixed(1)}% del total'),
                          trailing: Text(
                            NumberFormat.currency(symbol: '€').format(data['amount']),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          children: categoryTransactions.map((tx) {
                            final isTransfer = tx.type == TransactionType.transferIn || tx.type == TransactionType.transferOut;
                            final account = provider.getAccountById(tx.accountId);
                            return ListTile(
                              dense: true,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => AddTransactionScreen(transaction: tx)),
                                );
                              },
                              leading: Icon(
                                isTransfer ? Icons.swap_horiz : Icons.circle, 
                                size: 12, 
                                color: isTransfer ? Colors.blue : Colors.grey
                              ),
                              title: Text(tx.note ?? (isTransfer ? 'Transferencia' : 'Gasto'), style: const TextStyle(fontSize: 13)),
                              subtitle: Text('${DateFormat('dd/MM').format(tx.date)} - ${account?.name}', style: const TextStyle(fontSize: 11)),
                              trailing: Text(
                                NumberFormat.currency(symbol: '€').format(tx.amount),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  List<TransactionModel> _getTransactionsForCategory(AccountingProvider provider, int categoryId) {
    final now = DateTime.now();
    return provider.transactions.where((tx) {
      if (tx.categoryId != categoryId) return false;
      
      // Incluir si es gasto normal
      if (tx.type == TransactionType.expense) {
        if (_isYearly) return tx.date.year == now.year;
        return tx.date.month == now.month && tx.date.year == now.year;
      }

      // Incluir si es pago de deuda (transferencia a cuenta LIABILITY)
      if (tx.type == TransactionType.transferOut && tx.transferAccountId != null) {
        final destAccount = provider.getAccountById(tx.transferAccountId!);
        if (destAccount?.type == 'LIABILITY') {
          if (_isYearly) return tx.date.year == now.year;
          return tx.date.month == now.month && tx.date.year == now.year;
        }
      }

      return false;
    }).toList();
  }

  Map<int, Map<String, dynamic>> _calculateStats(AccountingProvider provider) {
    final now = DateTime.now();
    final transactions = provider.transactions.where((tx) {
      // 1. Incluimos gastos normales
      if (tx.type == TransactionType.expense) {
        if (_isYearly) return tx.date.year == now.year;
        return tx.date.month == now.month && tx.date.year == now.year;
      }

      // 2. Incluimos transferencias SALIENTES solo si van a una cuenta de DEUDA (Pago de hipoteca, etc.)
      if (tx.type == TransactionType.transferOut && tx.transferAccountId != null) {
        final destAccount = provider.getAccountById(tx.transferAccountId!);
        if (destAccount?.type == 'LIABILITY') {
          if (_isYearly) return tx.date.year == now.year;
          return tx.date.month == now.month && tx.date.year == now.year;
        }
      }

      return false; // Ignoramos ingresos y traspasos entre activos (ahorro)
    }).toList();

    Map<int, Map<String, dynamic>> categoryStats = {};

    for (var tx in transactions) {
      if (!categoryStats.containsKey(tx.categoryId)) {
        categoryStats[tx.categoryId] = {'amount': 0.0};
      }
      categoryStats[tx.categoryId]!['amount'] += tx.amount;
    }

    // Ordenar por monto de mayor a menor
    final sortedKeys = categoryStats.keys.toList()
      ..sort((a, b) => categoryStats[b]!['amount'].compareTo(categoryStats[a]!['amount']));
    
    return Map.fromIterable(sortedKeys, key: (k) => k, value: (k) => categoryStats[k]!);
  }

  List<PieChartSectionData> _buildChartSections(Map<int, Map<String, dynamic>> stats, double total) {
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    
    return List.generate(stats.length, (i) {
      final isTouched = i == _touchedIndex;
      final fontSize = isTouched ? 18.0 : 12.0;
      final radius = isTouched ? 60.0 : 50.0;
      
      final categoryId = stats.keys.elementAt(i);
      final data = stats[categoryId]!;
      final category = provider.getCategoryById(categoryId);
      final percentage = (data['amount'] / total) * 100;

      return PieChartSectionData(
        color: category?.color ?? Colors.grey,
        value: data['amount'],
        title: isTouched ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }
}
