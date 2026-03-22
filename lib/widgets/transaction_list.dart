import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../providers/accounting_provider.dart';
import '../screens/add_transaction_screen.dart';

class TransactionList extends StatelessWidget {
  final AccountingProvider provider;
  final List<TransactionModel>? list;
  final bool fullList;

  const TransactionList({
    super.key,
    required this.provider,
    this.list,
    this.fullList = false,
  });

  @override
  Widget build(BuildContext context) {
    var transactions = list ?? provider.transactions;
    
    if (provider.selectedAccount == null) {
      transactions = transactions.where((tx) => tx.type != TransactionType.transferIn).toList();
    }

    if (transactions.isEmpty && fullList) {
      return const Center(child: Text('No hay transacciones registradas.'));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: fullList ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final category = provider.getCategoryById(tx.categoryId);
        final isTransfer = tx.type == TransactionType.transferIn || tx.type == TransactionType.transferOut;
        
        String title = category?.name ?? 'Otros';
        String subtitle = DateFormat('dd MMM, yyyy').format(tx.date);
        Color amountColor = tx.type == TransactionType.income ? Colors.green : Colors.redAccent;
        String sign = tx.type == TransactionType.income ? '+' : '-';

        if (isTransfer) {
          final otherAccount = tx.transferAccountId != null ? provider.getAccountById(tx.transferAccountId!) : null;
          amountColor = Colors.blue;
          sign = tx.type == TransactionType.transferOut ? '→' : '←';
          title = tx.type == TransactionType.transferOut 
              ? 'Transferencia a ${otherAccount?.name ?? '...'}' 
              : 'Transferencia desde ${otherAccount?.name ?? '...'}';
        }

        return Dismissible(
          key: Key('tx_${tx.id}_$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => provider.removeTransaction(tx.id!),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => AddTransactionScreen(transaction: tx)));
              },
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isTransfer ? Colors.blue.withValues(alpha: 0.15) : (category?.color ?? Colors.grey).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(isTransfer ? Icons.swap_horiz : (category?.icon ?? Icons.help_outline), color: isTransfer ? Colors.blue : (category?.color ?? Colors.grey), size: 24),
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$sign ${NumberFormat.currency(symbol: '€').format(tx.amount)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: amountColor)),
                  Text(NumberFormat.currency(symbol: '€').format(provider.getTransactionBalance(tx.id!)), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
