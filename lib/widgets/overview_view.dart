import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/account_model.dart';
import '../models/transaction_model.dart';
import '../screens/category_stats_screen.dart';
import 'transaction_list.dart';

class OverviewView extends StatelessWidget {
  final AccountingProvider provider;

  const OverviewView({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final debtAccounts = provider.accounts.where((acc) => acc.type == 'LIABILITY').toList();
    
    return RefreshIndicator(
      onRefresh: () => provider.loadData(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(context),
            const SizedBox(height: 24),
            const Text('Tus Cuentas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildAccountsList(context),
            if (debtAccounts.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('Estado de Deudas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...debtAccounts.map((debt) => _buildDebtProgressCard(context, debt)),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Movimientos de este mes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.pie_chart_outline, color: Colors.blue),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CategoryStatsScreen())),
                  tooltip: 'Analizar categorías',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMonthlyTransactions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Patrimonio Neto', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text(NumberFormat.currency(symbol: '€').format(provider.netWorth), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildSimpleSummaryItem('Activos', provider.totalAssets, Icons.account_balance_wallet, Colors.greenAccent),
              const SizedBox(width: 16),
              _buildSimpleSummaryItem('Deudas', provider.totalLiabilities, Icons.money_off, Colors.redAccent),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSimpleSummaryItem(String label, double amount, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(NumberFormat.compactCurrency(symbol: '€').format(amount), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsList(BuildContext context) {
    if (provider.accounts.isEmpty) return const SizedBox();
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: provider.accounts.length,
        itemBuilder: (context, index) {
          final acc = provider.accounts[index];
          final balance = provider.getAccountBalance(acc);
          final isSelected = provider.selectedAccount?.id == acc.id;
          return GestureDetector(
            onTap: () => provider.setSelectedAccount(isSelected ? null : acc),
            child: Container(
              width: 160,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? acc.color.withValues(alpha: 0.2) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: isSelected ? Border.all(color: acc.color, width: 2) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(acc.icon, color: acc.color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                    if (acc.linkedAccountId != null) const Icon(Icons.link, size: 14, color: Colors.blueGrey),
                  ]),
                  Text(NumberFormat.currency(symbol: '€').format(balance), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: balance < 0 ? Colors.red : null)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDebtProgressCard(BuildContext context, AccountModel debt) {
    double paid = debt.initialBalance;
    for (var tx in provider.transactions.where((t) => t.accountId == debt.id)) {
      if (tx.type == TransactionType.income || tx.type == TransactionType.transferIn) paid += tx.amount;
      else paid -= tx.amount;
    }
    final total = debt.totalAmount ?? (paid > 0 ? paid : 1.0);
    final progress = (paid / total).clamp(0.0, 1.0);
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [Icon(debt.icon, color: debt.color, size: 20), const SizedBox(width: 8), Text(debt.name, style: const TextStyle(fontWeight: FontWeight.bold))]),
              Text('${(progress * 100).toStringAsFixed(1)}%', style: TextStyle(color: debt.color, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress, backgroundColor: debt.color.withValues(alpha: 0.1), color: debt.color, borderRadius: BorderRadius.circular(10), minHeight: 8),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Pagado: ${NumberFormat.compactCurrency(symbol: '€').format(paid)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Total: ${NumberFormat.compactCurrency(symbol: '€').format(total)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTransactions(BuildContext context) {
    final now = DateTime.now();
    final monthlyTransactions = provider.transactions.where((tx) => tx.date.month == now.month && tx.date.year == now.year).toList();
    if (monthlyTransactions.isEmpty) return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 40.0), child: Text('Sin movimientos este mes')));
    return TransactionList(provider: provider, list: monthlyTransactions);
  }
}
