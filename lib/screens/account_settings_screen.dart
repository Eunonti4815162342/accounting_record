import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/account_model.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tus Cuentas')),
      body: Consumer<AccountingProvider>(
        builder: (context, provider, child) {
          if (provider.accounts.isEmpty) {
            return const Center(child: Text('No tienes cuentas registradas.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.accounts.length,
            itemBuilder: (context, index) {
              final acc = provider.accounts[index];
              return Card(
                elevation: 0,
                color: acc.color.withValues(alpha: 0.1),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: acc.color,
                    child: Icon(acc.icon, color: Colors.white),
                  ),
                  title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () => _showAccountDialog(context, account: acc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _showDeleteDialog(context, provider, acc),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAccountDialog(context),
        label: const Text('Nueva Cuenta'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, AccountingProvider provider, AccountModel account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar cuenta?'),
        content: Text('Se eliminará "${account.name}" y todas sus transacciones asociadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              provider.removeAccount(account.id!);
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAccountDialog(BuildContext context, {AccountModel? account}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => AccountFormSheet(account: account),
    );
  }
}

class AccountFormSheet extends StatefulWidget {
  final AccountModel? account;
  const AccountFormSheet({super.key, this.account});

  @override
  State<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends State<AccountFormSheet> {
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  late TextEditingController _totalAmountController;
  late Color _selectedColor;
  late IconData _selectedIcon;
  late String _selectedType;
  int? _selectedLinkedAccountId;

  final List<Color> _colors = [
    Colors.indigo, Colors.blue, Colors.teal, Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.pink
  ];

  final List<IconData> _icons = [
    Icons.wallet, Icons.account_balance, Icons.credit_card, Icons.savings, Icons.house, Icons.car_rental, Icons.payments
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name ?? '');
    _balanceController = TextEditingController(text: widget.account?.initialBalance.toString() ?? '0');
    _totalAmountController = TextEditingController(text: widget.account?.totalAmount?.toString() ?? '');
    _selectedColor = widget.account != null ? widget.account!.color : Colors.indigo;
    _selectedIcon = widget.account != null ? widget.account!.icon : Icons.wallet;
    _selectedType = widget.account?.type ?? 'ASSET';
    _selectedLinkedAccountId = widget.account?.linkedAccountId;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    double? currentBalance;
    if (widget.account != null) {
      currentBalance = provider.getAccountBalance(widget.account!);
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.account != null ? 'Editar Cuenta' : 'Nueva Cuenta', 
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (widget.account != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Saldo actual calculado:', style: TextStyle(fontSize: 13)),
                    Text(
                      NumberFormat.currency(symbol: '€').format(currentBalance),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre de la cuenta', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ASSET', label: Text('Activo'), icon: Icon(Icons.account_balance_wallet)),
                      ButtonSegment(value: 'LIABILITY', label: Text('Deuda'), icon: Icon(Icons.money_off)),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (newSelection) => setState(() => _selectedType = newSelection.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _balanceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _selectedType == 'ASSET' ? 'Saldo Base / Ajuste' : 'Cantidad pagada ya',
                helperText: widget.account != null ? 'Modifica este valor para ajustar el saldo sin crear movimientos.' : null,
                border: const OutlineInputBorder(),
                prefixText: '€ ',
              ),
            ),
            if (_selectedType == 'LIABILITY') ...[
              const SizedBox(height: 15),
              TextField(
                controller: _totalAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto total de la deuda (ej. Hipoteca)',
                  border: OutlineInputBorder(),
                  prefixText: '€ ',
                  hintText: 'Ej. 150000',
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<int>(
                value: _selectedLinkedAccountId,
                decoration: const InputDecoration(
                  labelText: 'Se paga habitualmente desde',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                items: Provider.of<AccountingProvider>(context, listen: false)
                    .accounts
                    .where((a) => a.type == 'ASSET')
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedLinkedAccountId = val),
              ),
            ],
            const SizedBox(height: 20),
            const Text('Icono', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _icons.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => setState(() => _selectedIcon = _icons[index]),
                  child: CircleAvatar(
                    backgroundColor: _selectedIcon == _icons[index] ? _selectedColor : Colors.grey.withValues(alpha: 0.1),
                    child: Icon(_icons[index], color: _selectedIcon == _icons[index] ? Colors.white : Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Color', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _colors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => setState(() => _selectedColor = _colors[index]),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _colors[index],
                      shape: BoxShape.circle,
                      border: _selectedColor == _colors[index] ? Border.all(color: Colors.black, width: 2) : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty) {
                  final provider = Provider.of<AccountingProvider>(context, listen: false);
                  final initialBalance = double.tryParse(_balanceController.text) ?? 0.0;
                  final totalAmount = double.tryParse(_totalAmountController.text);
                  
                  final accountData = AccountModel(
                    id: widget.account?.id,
                    name: _nameController.text,
                    iconCodePoint: _selectedIcon.codePoint,
                    colorValue: _selectedColor.toARGB32(),
                    initialBalance: initialBalance,
                    type: _selectedType,
                    totalAmount: totalAmount,
                    linkedAccountId: _selectedLinkedAccountId,
                  );

                  if (widget.account != null) {
                    provider.updateAccount(accountData);
                  } else {
                    provider.addAccount(accountData);
                  }
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _selectedColor,
                foregroundColor: Colors.white,
              ),
              child: Text(widget.account != null ? 'Guardar Cambios' : 'Crear Cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
