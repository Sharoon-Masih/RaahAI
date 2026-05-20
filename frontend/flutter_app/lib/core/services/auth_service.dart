// lib/core/services/auth_service.dart

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/ngo_model.dart';

class AuthService {
  final http.Client _client;
  final FlutterSecureStorage _storage;

  AuthService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  // Storage Keys
  static const String _keyToken = 'jwt_token';
  static const String _keyNgoId = 'assigned_ngo_id';
  static const String _keyNgoName = 'ngo_name';
  static const String _keyNgoEmail = 'ngo_email';

  // Login
  Future<NgoModel> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    ).timeout(ApiConstants.timeoutDuration);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final ngo = NgoModel.fromJson(data);

      // Save credentials. The backend response model (NGOResponse) does not contain a JWT token,
      // so we generate a mock token for the secure storage layer as requested.
      final mockToken = 'mock_jwt_token_${ngo.ngoId}';
      await _storage.write(key: _keyToken, value: mockToken);
      await _storage.write(key: _keyNgoId, value: ngo.ngoId);
      await _storage.write(key: _keyNgoName, value: ngo.name);
      await _storage.write(key: _keyNgoEmail, value: ngo.email);

      return ngo;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['detail'] ?? 'Login failed. Invalid email or password.');
    }
  }

  // Register
  Future<NgoModel> register({
    required String name,
    required String email,
    required String password,
    required List<String> crisisTypes,
    required List<String> locations,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.register}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'crisis_types': crisisTypes,
        'locations': locations,
      }),
    ).timeout(ApiConstants.timeoutDuration);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return NgoModel.fromJson(data);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['detail'] ?? 'Registration failed.');
    }
  }

  // Logout
  Future<void> logout() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyNgoId);
    await _storage.delete(key: _keyNgoName);
    await _storage.delete(key: _keyNgoEmail);
  }

  // Getters
  Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  Future<String?> getNgoId() async {
    return await _storage.read(key: _keyNgoId);
  }

  Future<String?> getNgoName() async {
    return await _storage.read(key: _keyNgoName);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    final ngoId = await getNgoId();
    return token != null && ngoId != null;
  }
}
