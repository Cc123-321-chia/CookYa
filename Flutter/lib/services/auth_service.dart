// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class AuthService {
  static String get baseUrl => ApiService.baseUrl;

  // 存储 token 的 key
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  String? _token;
  Map<String, dynamic>? _currentUser;

  String? get token => _token;

  Map<String, dynamic>? get currentUser => _currentUser;

  bool get isLoggedIn => _token != null;

  AuthService() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        return {
          'success': true,
          'token': data['token'],
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/register/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        _token = data['token'];
        _currentUser = data;
        return {
          'success': true,
          'token': data['token'],
          'user': data,
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? error['username']?.first ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
  }

  Map<String, String> getAuthHeaders() {
    if (_token != null) {
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Token $_token',
      };
    }
    return {'Content-Type': 'application/json'};
  }

  Map<String, String> getAuthFileHeaders() {
    if (_token != null) {
      return {
        'Authorization': 'Token $_token',
      };
    }
    return {};
  }
}

final authService = AuthService();