import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/accounting_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/shared_group_provider.dart';
import 'widgets/auth_wrapper.dart';
import 'screens/register_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AccountingProvider()),
        ChangeNotifierProvider(create: (_) => SharedGroupProvider()),
      ],
      child: MaterialApp(
        title: 'Accounting Record',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.blueAccent,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        home: const AuthWrapper(),
        routes: {
          '/register': (context) => const RegisterScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
