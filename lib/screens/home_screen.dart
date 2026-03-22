import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accounting_provider.dart';
import '../models/account_model.dart';
import 'add_transaction_screen.dart';
import 'account_settings_screen.dart';
import '../widgets/overview_view.dart';
import '../widgets/scheduled_view.dart';
import 'shared_groups_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AccountingProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getAppBarTitle(), 
              style: const TextStyle(fontWeight: FontWeight.bold)),
            if (_selectedIndex == 0)
              Text(provider.selectedAccount?.name ?? 'Todas las cuentas', 
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
          ],
        ),
        actions: [
          _buildAccountMenu(context, provider),
        ],
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: [
                OverviewView(provider: provider),
                ScheduledView(provider: provider),
                const SharedGroupsScreen(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Resumen'),
          NavigationDestination(icon: Icon(Icons.repeat_outlined), selectedIcon: Icon(Icons.repeat), label: 'Fijos'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'Grupos'),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
          );
        },
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0: return 'Resumen';
      case 1: return 'Gastos Fijos';
      case 2: return 'Grupos Compartidos';
      default: return 'Contabilidad';
    }
  }

  Widget _buildAccountMenu(BuildContext context, AccountingProvider provider) {
    return PopupMenuButton<Object?>(
      icon: const Icon(Icons.account_balance_wallet_outlined),
      onSelected: (value) {
        if (value == 'settings') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AccountSettingsScreen()),
          );
        } else {
          provider.setSelectedAccount(value as AccountModel?);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: null,
          child: Row(
            children: [
              Icon(Icons.all_inclusive, size: 20),
              SizedBox(width: 12),
              Text('Todas las cuentas'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        ...provider.accounts.map((acc) => PopupMenuItem(
          value: acc,
          child: Row(
            children: [
              Icon(acc.icon, color: acc.color, size: 20),
              const SizedBox(width: 12),
              Text(acc.name),
            ],
          ),
        )),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings, size: 20, color: Colors.grey),
              SizedBox(width: 12),
              Text('Gestionar Cuentas'),
            ],
          ),
        ),
      ],
    );
  }
}
