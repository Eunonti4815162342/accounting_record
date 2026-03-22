import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../services/biometric_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _biometricPassed = false;
  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isAuthenticated) {
      final available = await _biometricService.isBiometricAvailable();
      if (available) {
        final authenticated = await _biometricService.authenticate();
        setState(() {
          _biometricPassed = authenticated;
        });
      } else {
        // Si no hay biometría disponible, dejamos pasar (en el futuro aquí iría el PIN)
        setState(() {
          _biometricPassed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!authProvider.isAuthenticated) {
      return const LoginScreen();
    }

    if (!_biometricPassed) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.blue),
              const SizedBox(height: 24),
              const Text('Aplicación Bloqueada', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _checkBiometrics,
                child: const Text('Desbloquear con Huella'),
              ),
              TextButton(
                onPressed: () => authProvider.logout(),
                child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}
