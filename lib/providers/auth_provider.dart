import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  String? _token;
  bool _isAuthenticated = false;
  bool _isLoading = true;

  String? get token => _token;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    _token = await _authService.getToken();
    _isAuthenticated = _token != null;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _token = await _authService.login(email, password);
    if (_token != null) {
      _isAuthenticated = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> register(String name, String email, String password) async {
    return await _authService.register(name, email, password);
  }

  Future<void> logout() async {
    await _authService.logout();
    _token = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
