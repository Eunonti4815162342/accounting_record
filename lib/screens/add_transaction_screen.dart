import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../models/account_model.dart';

import '../models/scheduled_transaction_model.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transaction;
  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late TransactionType _selectedType;
  CategoryModel? _selectedCategory;
  AccountModel? _selectedAccount;
  AccountModel? _selectedDestinationAccount;
  late DateTime _selectedDate;
  bool _isRecurrent = false;
  String _frequency = 'MONTHLY';

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    
    _amountController = TextEditingController(text: widget.transaction?.amount.toString() ?? '');
    _noteController = TextEditingController(text: widget.transaction?.note ?? '');
    _selectedType = widget.transaction?.type ?? TransactionType.expense;
    _selectedDate = widget.transaction?.date ?? DateTime.now();
    
    // Verificar si el ID programado realmente existe en la lista del provider
    final scheduledId = widget.transaction?.scheduledId;
    if (scheduledId != null && provider.scheduledTransactions.any((st) => st.id == scheduledId)) {
      _isRecurrent = true;
    } else {
      _isRecurrent = false;
    }

    if (widget.transaction != null) {
      _selectedAccount = provider.getAccountById(widget.transaction!.accountId);
      _selectedCategory = provider.getCategoryById(widget.transaction!.categoryId);
      if (widget.transaction!.transferAccountId != null) {
        _selectedDestinationAccount = provider.getAccountById(widget.transaction!.transferAccountId!);
      }
    } else {
      if (provider.accounts.isNotEmpty) {
        _selectedAccount = provider.selectedAccount ?? provider.accounts.first;
        if (provider.accounts.length > 1) {
          _selectedDestinationAccount = provider.accounts.firstWhere((acc) => acc.id != _selectedAccount?.id);
        }
      }
      if (provider.categories.isNotEmpty) {
        try {
          _selectedCategory = provider.categories.firstWhere((cat) => cat.name.toLowerCase().contains('transferencia'));
        } catch (e) {
          _selectedCategory = provider.categories.first;
        }
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitData() async {
    if (_formKey.currentState!.validate() && _selectedCategory != null && _selectedAccount != null) {
      if (_selectedType == TransactionType.transferOut && _selectedDestinationAccount == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una cuenta destino')));
        return;
      }
      
      final provider = Provider.of<AccountingProvider>(context, listen: false);
      final double amount = double.parse(_amountController.text);
      
      try {
        if (widget.transaction != null) {
          // MODO EDICIÓN
          int? currentScheduledId = widget.transaction!.scheduledId;
          
          // Verificar si el ID existe en el provider; si no, tratarlo como null
          if (currentScheduledId != null && !provider.scheduledTransactions.any((st) => st.id == currentScheduledId)) {
            currentScheduledId = null;
          }

          // Si activamos Recurrente y antes no lo era, creamos la programación PRIMERO para obtener el ID
          if (_isRecurrent && currentScheduledId == null) {
            final scheduled = ScheduledTransactionModel(
              name: _noteController.text.isNotEmpty ? _noteController.text : (_selectedCategory?.name ?? 'Recurrente'),
              amount: amount,
              categoryId: _selectedCategory!.id!,
              accountId: _selectedAccount!.id!,
              transferAccountId: _selectedType == TransactionType.transferOut ? _selectedDestinationAccount?.id : null,
              type: _selectedType == TransactionType.transferOut ? 'TRANSFER' : (_selectedType == TransactionType.income ? 'INCOME' : 'EXPENSE'),
              frequency: _frequency,
              nextExecutionDate: _selectedDate.add(const Duration(days: 30)), 
            );
            currentScheduledId = await provider.addScheduledTransaction(scheduled);
          }

          final updatedTx = TransactionModel(
            id: widget.transaction!.id,
            amount: amount,
            categoryId: _selectedCategory!.id!,
            accountId: _selectedAccount!.id!,
            transferAccountId: _selectedType == TransactionType.transferOut ? _selectedDestinationAccount?.id : null,
            date: _selectedDate,
            note: _noteController.text.isEmpty ? null : _noteController.text,
            type: _selectedType,
            scheduledId: currentScheduledId, // Vínculo asegurado
          );
          await provider.editTransaction(updatedTx);
        } else if (_isRecurrent) {
          // MODO CREACIÓN RECURRENTE
          final scheduled = ScheduledTransactionModel(
            name: _noteController.text.isNotEmpty ? _noteController.text : (_selectedCategory?.name ?? 'Recurrente'),
            amount: amount,
            categoryId: _selectedCategory!.id!,
            accountId: _selectedAccount!.id!,
            transferAccountId: _selectedType == TransactionType.transferOut ? _selectedDestinationAccount?.id : null,
            type: _selectedType == TransactionType.transferOut ? 'TRANSFER' : (_selectedType == TransactionType.income ? 'INCOME' : 'EXPENSE'),
            frequency: _frequency,
            nextExecutionDate: _selectedDate,
          );
          // Al llamar a addScheduledTransaction, el servidor ya procesa y genera la transacción de hoy si coincide.
          await provider.addScheduledTransaction(scheduled);
          
          // NO llamamos a _saveNormalTransaction para evitar duplicados si la fecha es hoy.
          // El backend ya lo hace en ScheduledTransactionServiceImpl.save -> schedulingService.processScheduledTransactions()
        } else {
          // MODO NORMAL (CREACIÓN)
          await _saveNormalTransaction(provider, amount);
        }
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una categoría')));
    } else if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una cuenta')));
    }
  }

  Future<void> _saveNormalTransaction(AccountingProvider provider, double amount, {int? sId}) async {
    if (_selectedType == TransactionType.transferOut) {
      final tx = TransactionModel(
        amount: amount,
        categoryId: _selectedCategory!.id!,
        accountId: _selectedAccount!.id!,
        transferAccountId: _selectedDestinationAccount!.id!,
        date: _selectedDate,
        note: _noteController.text,
        type: TransactionType.transferOut,
        scheduledId: sId,
      );
      await provider.addTransfer(tx);
    } else {
      final tx = TransactionModel(
        amount: amount,
        categoryId: _selectedCategory!.id!,
        accountId: _selectedAccount!.id!,
        date: _selectedDate,
        note: _noteController.text,
        type: _selectedType,
        scheduledId: sId,
      );
      await provider.addTransaction(tx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AccountingProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.transaction != null ? 'Editar Movimiento' : 'Nueva Transacción')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTypeSelector(),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Monto (€)',
                  prefixIcon: const Icon(Icons.euro),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                ),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa un monto';
                  if (double.tryParse(value) == null) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                _selectedType == TransactionType.transferOut ? 'Cuenta Origen' : 'Cuenta', 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 8),
              _buildAccountSelector(provider.accounts, true),
              
              if (_selectedType == TransactionType.transferOut) ...[
                const SizedBox(height: 24),
                const Text('Cuenta Destino', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildAccountSelector(provider.accounts, false),
              ],
              
              const SizedBox(height: 24),
              const Text('Categoría', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildCategoryAutocomplete(provider.categories),
              const SizedBox(height: 24),
              ListTile(
                title: const Text('Fecha'),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
                tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Nota (opcional)',
                  prefixIcon: const Icon(Icons.note_alt_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('¿Es un gasto recurrente?'),
                subtitle: const Text('Se generará automáticamente según la frecuencia'),
                value: _isRecurrent,
                onChanged: (val) => setState(() => _isRecurrent = val),
                secondary: const Icon(Icons.repeat),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              if (_isRecurrent) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<String>(
                    value: _frequency,
                    decoration: const InputDecoration(labelText: 'Frecuencia'),
                    items: const [
                      DropdownMenuItem(value: 'DAILY', child: Text('Diario')),
                      DropdownMenuItem(value: 'WEEKLY', child: Text('Semanal')),
                      DropdownMenuItem(value: 'MONTHLY', child: Text('Mensual')),
                      DropdownMenuItem(value: 'YEARLY', child: Text('Anual')),
                    ],
                    onChanged: (val) => setState(() => _frequency = val!),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submitData,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: _selectedType == TransactionType.income 
                    ? Colors.green 
                    : (_selectedType == TransactionType.transferOut ? Colors.blue : Colors.redAccent),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _selectedType == TransactionType.transferOut ? 'Confirmar Transferencia' : 'Confirmar Transacción', 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SegmentedButton<TransactionType>(
      segments: const [
        ButtonSegment(value: TransactionType.expense, label: Text('Gasto'), icon: Icon(Icons.remove_circle_outline)),
        ButtonSegment(value: TransactionType.income, label: Text('Ingreso'), icon: Icon(Icons.add_circle_outline)),
        ButtonSegment(value: TransactionType.transferOut, label: Text('Transf.'), icon: Icon(Icons.swap_horiz)),
      ],
      selected: {_selectedType},
      onSelectionChanged: (newSelection) {
        setState(() {
          _selectedType = newSelection.first;
        });
      },
    );
  }

  Widget _buildAccountSelector(List<AccountModel> accounts, bool isSource) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final acc = accounts[index];
          final isSelected = isSource ? (_selectedAccount?.id == acc.id) : (_selectedDestinationAccount?.id == acc.id);
          return ChoiceChip(
            label: Text(acc.name),
            selected: isSelected,
            avatar: Icon(acc.icon, size: 16, color: isSelected ? Colors.white : acc.color),
            onSelected: (selected) {
              setState(() {
                if (isSource) {
                  _selectedAccount = selected ? acc : null;
                } else {
                  _selectedDestinationAccount = selected ? acc : null;
                  
                  // LOGICA DE VINCULO AUTOMATICO
                  if (selected && acc.type == 'LIABILITY' && acc.linkedAccountId != null) {
                    _selectedType = TransactionType.transferOut;
                    final source = accounts.firstWhere((a) => a.id == acc.linkedAccountId);
                    _selectedAccount = source;
                    // Intentar poner categoría Hipoteca
                    try {
                      _selectedCategory = Provider.of<AccountingProvider>(context, listen: false)
                          .categories.firstWhere((c) => c.name.toLowerCase().contains('hipoteca'));
                    } catch (_) {}
                  }
                }
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryAutocomplete(List<CategoryModel> categories) {
    return Autocomplete<CategoryModel>(
      displayStringForOption: (CategoryModel option) => option.name,
      initialValue: TextEditingValue(text: _selectedCategory?.name ?? ''),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') {
          return const Iterable<CategoryModel>.empty();
        }
        return categories.where((CategoryModel option) {
          return option.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (CategoryModel selection) {
        setState(() {
          _selectedCategory = selection;
        });
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Buscar categoría...',
            prefixIcon: Icon(_selectedCategory?.icon ?? Icons.search, color: _selectedCategory?.color),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            filled: true,
          ),
          onFieldSubmitted: (value) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 32,
              height: 300,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final CategoryModel option = options.elementAt(index);
                  return ListTile(
                    leading: Icon(option.icon, color: option.color),
                    title: Text(option.name),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
