// lib/core/providers/auth_provider.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/ngo_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider({AuthService? authService}) : _authService = authService ?? AuthService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  NgoModel? _ngo;
  NgoModel? get ngo => _ngo;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  // Initialize and check status on startup
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loggedIn = await _authService.isLoggedIn();
      if (loggedIn) {
        final ngoId = await _authService.getNgoId() ?? '';
        final name = await _authService.getNgoName() ?? '';
        final email = ''; // Optional/not stored or mock placeholder

        // Reconstruct basic NGO info from storage or mock
        _ngo = NgoModel(
          ngoId: ngoId,
          name: name,
          email: email,
          crisisTypes: [],
          locations: [],
          createdAt: '',
        );
        _isAuthenticated = true;
      } else {
        _ngo = null;
        _isAuthenticated = false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isAuthenticated = false;
      _ngo = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _ngo = await _authService.login(email, password);
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isAuthenticated = false;
      _ngo = null;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Register
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required List<String> crisisTypes,
    required List<String> locations,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Register NGO
      await _authService.register(
        name: name,
        email: email,
        password: password,
        crisisTypes: crisisTypes,
        locations: locations,
      );
      
      // Auto login after registration
      return await login(email, password);
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authService.logout();
    _ngo = null;
    _isAuthenticated = false;
    _isLoading = false;
    
    notifyListeners();
  }

  // Clear error message manually
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
