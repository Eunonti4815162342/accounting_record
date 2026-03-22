import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/shared_group_provider.dart';
import '../providers/auth_provider.dart';
import '../models/shared_expense_models.dart';

class SharedGroupsScreen extends StatefulWidget {
  const SharedGroupsScreen({super.key});

  @override
  State<SharedGroupsScreen> createState() => _SharedGroupsScreenState();
}

class _SharedGroupsScreenState extends State<SharedGroupsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<SharedGroupProvider>().loadGroups());
  }

  @override
  Widget build(BuildContext context) {
    final sharedProvider = context.watch<SharedGroupProvider>();
    final authProvider = context.watch<AuthProvider>();
    // Simulación de ID de usuario actual para demostración (debería venir del backend real)
    final currentUserId = 1; 

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos Compartidos', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_home_work_outlined),
            onPressed: () => _showCreateGroupDialog(context),
          ),
        ],
      ),
      body: sharedProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => sharedProvider.loadGroups(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sharedProvider.groups.length,
                itemBuilder: (context, index) {
                  final group = sharedProvider.groups[index];
                  final balance = sharedProvider.getUserBalanceInGroup(group.id!, currentUserId) ?? 0.0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: balance >= 0 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                        child: Icon(Icons.group, color: balance >= 0 ? Colors.green : Colors.red),
                      ),
                      title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Text(
                        balance >= 0 
                          ? 'Te deben: ${NumberFormat.currency(symbol: '€').format(balance)}' 
                          : 'Debes: ${NumberFormat.currency(symbol: '€').format(balance.abs())}',
                        style: TextStyle(color: balance >= 0 ? Colors.green : Colors.red),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // Navegar al detalle del grupo (lo crearemos a continuación)
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Nuevo Grupo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nombre del grupo (ej. Viaje Roma)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<SharedGroupProvider>().createGroup(controller.text, []);
                Navigator.pop(context);
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}
