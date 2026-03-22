import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/scheduled_transaction_model.dart';
import 'projection_dialog.dart';

class ScheduledView extends StatelessWidget {
  final AccountingProvider provider;

  const ScheduledView({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final activeScheduled = provider.scheduledTransactions.where((st) => st.active).toList();
    final activos = activeScheduled.where((st) => st.type == 'INCOME').toList();
    final pasivos = activeScheduled.where((st) => st.type != 'INCOME').toList();
    
    double monthlyNet = 0;
    for (var st in activeScheduled) {
      if (st.type == 'INCOME') monthlyNet += st.amount;
      else monthlyNet -= st.amount;
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadData(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Planificación Fija', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => ProjectionDialog.show(context, provider),
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Simular 5 años'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Activos Fijos (Ingresos)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 12),
            if (activos.isEmpty) const Text('No hay ingresos programados', style: TextStyle(color: Colors.grey, fontSize: 13))
            else ...activos.map((st) => _buildScheduledItem(context, st)),
            const SizedBox(height: 32),
            const Text('Pasivos Fijos (Gastos y Transf.)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
            const SizedBox(height: 12),
            if (pasivos.isEmpty) const Text('No hay gastos programados', style: TextStyle(color: Colors.grey, fontSize: 13))
            else ...pasivos.map((st) => _buildScheduledItem(context, st)),
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 16),
            const Text('Resumen de Flujo Mensual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildFixedExpenseStats(context, monthlyNet, monthlyNet * 12),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledItem(BuildContext context, ScheduledTransactionModel st) {
    final category = provider.getCategoryById(st.categoryId);
    final account = provider.getAccountById(st.accountId);
    final destAccount = st.transferAccountId != null ? provider.getAccountById(st.transferAccountId!) : null;
    final isIncome = st.type == 'INCOME';
    final isTransfer = st.type == 'TRANSFER' || st.type == 'TRANSFER_OUT';
    
    Color typeColor = isIncome ? Colors.green : (isTransfer ? Colors.blue : Colors.redAccent);
    String label = isIncome ? 'Ingreso' : (isTransfer ? 'Transferencia' : 'Gasto');
    String accLabel = isTransfer ? 'De ${account?.name ?? "..."} a ${destAccount?.name ?? "..."}' : 'en ${account?.name ?? "..."}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: typeColor.withValues(alpha: 0.1), child: Icon(isTransfer ? Icons.swap_horiz : (isIncome ? Icons.add_circle_outline : (category?.icon ?? Icons.repeat)), color: typeColor)),
        title: Text(st.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$label mensual $accLabel'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(NumberFormat.currency(symbol: '€').format(st.amount), style: TextStyle(fontWeight: FontWeight.bold, color: typeColor)),
            IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey), onPressed: () => provider.removeScheduledTransaction(st.id!)),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedExpenseStats(BuildContext context, double monthly, double yearly) {
    bool isSurplus = monthly >= 0;
    Color themeColor = isSurplus ? Colors.green : Colors.redAccent;
    String label = isSurplus ? ' (Ahorro)' : ' (Déficit)';
    return Row(children: [
      Expanded(child: _buildStatCard('Al Mes$label', monthly.abs(), themeColor)),
      const SizedBox(width: 12),
      Expanded(child: _buildStatCard('Al Año$label', yearly.abs(), isSurplus ? Colors.teal : Colors.redAccent)),
    ]);
  }

  Widget _buildStatCard(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(NumberFormat.currency(symbol: '€').format(amount), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
