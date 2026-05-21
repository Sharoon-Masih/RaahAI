// lib/core/services/api_service.dart

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ApiService {
  final http.Client _client;
  final FlutterSecureStorage _storage;

  // Global callback for handling 401 Unauthorized errors
  static VoidCallback? onUnauthorized;

  ApiService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  // Helper to build headers
  Future<Map<String, String>> _getHeaders(Map<String, String>? customHeaders) async {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final ngoId = await _storage.read(key: 'assigned_ngo_id');
    if (ngoId != null) {
      headers['assigned-ngo-id'] = ngoId;
    }

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    return headers;
  }

  // Handle Response checks and throw clean exceptions or trigger 401
  void _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      if (onUnauthorized != null) {
        onUnauthorized!();
      }
      throw Exception('Session expired. Please log in again.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = 'Request failed with status ${response.statusCode}';
      try {
        final errorJson = jsonDecode(response.body);
        if (errorJson is Map && errorJson.containsKey('detail')) {
          errorMessage = errorJson['detail'].toString();
        }
      } catch (_) {
        // Fallback if not JSON or doesn't have detail
      }
      throw Exception(errorMessage);
    }
  }

  // GET Request
  Future<http.Response> get(String path, {Map<String, String>? headers, Map<String, String>? queryParameters}) async {
    final requestHeaders = await _getHeaders(headers);
    
    Uri uri = Uri.parse('${ApiConstants.baseUrl}$path');
    if (queryParameters != null) {
      uri = uri.replace(queryParameters: queryParameters);
    }

    try {
      final response = await _client
          .get(uri, headers: requestHeaders)
          .timeout(ApiConstants.timeoutDuration);
      
      _handleResponse(response);
      return response;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: $e');
    }
  }

  // POST Request
  Future<http.Response> post(String path, {Map<String, String>? headers, dynamic body}) async {
    final requestHeaders = await _getHeaders(headers);
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    final encodedBody = body != null ? jsonEncode(body) : null;

    try {
      final response = await _client
          .post(uri, headers: requestHeaders, body: encodedBody)
          .timeout(ApiConstants.timeoutDuration);
      
      _handleResponse(response);
      return response;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: $e');
    }
  }

  // Streamed POST for spreadsheet upload
  Future<http.StreamedResponse> sendMultipart(
    String path, {
    required List<int> fileBytes,
    required String fileName,
    Map<String, String>? fields,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    final request = http.MultipartRequest('POST', uri);

    // Get authorization headers
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final ngoId = await _storage.read(key: 'assigned_ngo_id');
    if (ngoId != null) {
      request.headers['assigned-ngo-id'] = ngoId;
    }

    if (fields != null) {
      request.fields.addAll(fields);
    }

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
    );
    request.files.add(multipartFile);

    try {
      final streamedResponse = await _client.send(request).timeout(ApiConstants.timeoutDuration);
      if (streamedResponse.statusCode == 401) {
        if (onUnauthorized != null) {
          onUnauthorized!();
        }
        throw Exception('Session expired. Please log in again.');
      }
      return streamedResponse;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

// Typing definitions for callbacks
typedef VoidCallback = void Function();
