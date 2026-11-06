// lib/services/admin_api_service.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/carousel_item.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AdminApiService {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000/api';
    return 'http://localhost:8000/api';
  }

  static String? _adminToken;
  static String? get token => _adminToken;

  // Currently logged-in admin info (populated on login).
  static String? adminName;
  static String? adminEmail;
  static String? adminRole;

  static void setToken(String token) {
    _adminToken = token;
  }

  static Future<String?> _ensureToken() async {
    if (_adminToken == null || _adminToken!.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      _adminToken = prefs.getString('adminToken');
    }
    return _adminToken;
  }

  static Future<bool> _handleUnauthorized(int statusCode) async {
    if (statusCode == 401 || statusCode == 403) {
      await logout();
      return true;
    }
    return false;
  }

  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': _adminToken != null ? 'Token $_adminToken' : '',
    };
  }

  // ==================== AUTH ====================

  static Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/admin/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _adminToken = data['token'];
          adminName = data['user']['name'];
          adminEmail = data['user']['email'];
          adminRole = data['user']['role'];

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('adminToken', _adminToken!);
          await prefs.setString('adminName', adminName ?? '');
          await prefs.setString('adminEmail', adminEmail ?? '');
          await prefs.setString('adminRole', adminRole ?? '');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('❌ Login error: $e');
      return false;
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    _adminToken = prefs.getString('adminToken');
    adminName = prefs.getString('adminName');
    adminEmail = prefs.getString('adminEmail');
    adminRole = prefs.getString('adminRole');
    return _adminToken != null && _adminToken!.isNotEmpty;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('adminToken');
    await prefs.remove('adminName');
    await prefs.remove('adminEmail');
    await prefs.remove('adminRole');
    _adminToken = null;
    adminName = null;
    adminEmail = null;
    adminRole = null;
  }

  // ==================== DASHBOARD ====================

  static Future<Map<String, dynamic>> getStats() async {
    try {
      final t = await _ensureToken();
      final response = await http.get(
        Uri.parse('$baseUrl/users/admin/dashboard/stats/'),
        headers: {'Authorization': 'Token $t'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data['data']);
      }
      await _handleUnauthorized(response.statusCode);
      return {};
    } catch (e) {
      print('❌ getStats error: $e');
      return {};
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingApprovals() async {
    try {
      final t = await _ensureToken();
      final response = await http.get(
        Uri.parse('$baseUrl/users/admin/dashboard/pending/'),
        headers: {'Authorization': 'Token $t'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      print('❌ getPendingApprovals error: $e');
      return [];
    }
  }

  // ==================== ADMINS ====================

  static Future<List<Map<String, dynamic>>> getAdmins() async {
    try {
      final t = await _ensureToken();
      final response = await http.get(
        Uri.parse('$baseUrl/users/admin/admins/'),
        headers: {'Authorization': 'Token $t'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      print('❌ getAdmins error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> addAdmin({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final t = await _ensureToken();
      final response = await http.post(
        Uri.parse('$baseUrl/users/admin/admins/add/'),
        headers: {
          'Authorization': 'Token $t',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'role': role,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<bool> removeAdmin(String userId) async {
    try {
      final t = await _ensureToken();
      final response = await http.post(
        Uri.parse('$baseUrl/users/admin/admins/$userId/remove/'),
        headers: {'Authorization': 'Token $t'},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ removeAdmin error: $e');
      return false;
    }
  }

  // ==================== RECIPES ====================

  static Future<List<Map<String, dynamic>>> getRecipes() async {
    try {
      final t = await _ensureToken();
      final response = await http.get(
        Uri.parse('$baseUrl/users/admin/recipes/'),
        headers: {'Authorization': 'Token $t'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      print('❌ getRecipes error: $e');
      return [];
    }
  }

  static Future<bool> approveRecipe(String recipeId) async {
    try {
      final t = await _ensureToken();
      final response = await http.post(
        Uri.parse('$baseUrl/users/admin/recipes/$recipeId/approve/'),
        headers: {'Authorization': 'Token $t'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteRecipe(String recipeId) async {
    try {
      final t = await _ensureToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/users/admin/recipes/$recipeId/'),
        headers: {'Authorization': 'Token $t'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ==================== INGREDIENTS ====================

  static Future<List<Map<String, dynamic>>> getIngredientPosts() async {
    try {
      final t = await _ensureToken();
      final response = await http.get(
        Uri.parse('$baseUrl/users/admin/ingredients/'),
        headers: {'Authorization': 'Token $t'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      print('❌ getIngredientPosts error: $e');
      return [];
    }
  }

  static Future<bool> approveIngredient(String postId) async {
    try {
      final t = await _ensureToken();
      final response = await http.post(
        Uri.parse('$baseUrl/users/admin/ingredients/$postId/approve/'),
        headers: {'Authorization': 'Token $t'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteIngredient(String postId) async {
    try {
      final t = await _ensureToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/users/admin/ingredients/$postId/'),
        headers: {'Authorization': 'Token $t'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ==================== USERS ====================

  static Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final t = await _ensureToken();
      final response = await http.get(
        Uri.parse('$baseUrl/users/admin/users/'),
        headers: {'Authorization': 'Token $t'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      print('❌ getUsers error: $e');
      return [];
    }
  }

  static Future<bool> deleteUser(String userId) async {
    try {
      final t = await _ensureToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/users/admin/users/$userId/'),
        headers: {'Authorization': 'Token $t'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ==================== CAROUSEL ====================

  static Future<List<CarouselItem>> getCarouselItems() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/carousel/'));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => CarouselItem.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('❌ Get carousel items error: $e');
      return [];
    }
  }

    /// Admin: fetch ALL carousel items (including inactive).
  static Future<List<CarouselItem>> getAllCarouselItems() async {
    try {
      final t = await _ensureToken();
      if (t == null || t.isEmpty) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/carousel/admin/'),
        headers: {'Authorization': 'Token $t'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> data =
            decoded is List ? decoded : (decoded['data'] as List? ?? []);
        return data.map((json) => CarouselItem.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('❌ getAllCarouselItems error: $e');
      return [];
    }
  }

  static Future<CarouselItem> createCarouselItem({
    required String title,
    required List<String> tags,
    required Uint8List imageBytes,
    required String imageFilename,
    required int order,
    required bool isActive,
  }) async {
    final t = await _ensureToken();
    if (t == null || t.isEmpty) {
      throw Exception('Please login to Admin panel first');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/carousel/create/'),
    );

    request.headers['Authorization'] = 'Token $t';
    request.fields['title'] = title;
    request.fields['tags'] = jsonEncode(tags);
    request.fields['order'] = order.toString();
    request.fields['is_active'] = isActive.toString();

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: imageFilename,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 201) {
      return CarouselItem.fromJson(jsonDecode(responseBody));
    } else {
      throw Exception('Failed to create: ${response.statusCode} - $responseBody');
    }
  }

  static Future<void> toggleCarouselItemActive(String id, bool isActive) async {
    final t = await _ensureToken();
    final response = await http.patch(
      Uri.parse('$baseUrl/carousel/$id/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $t',
      },
      body: jsonEncode({'is_active': isActive}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to toggle status: ${response.statusCode}');
    }
  }

  static Future<void> deleteCarouselItem(String id) async {
    final t = await _ensureToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/carousel/$id/'),
      headers: {'Authorization': 'Token $t'},
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete: ${response.statusCode}');
    }
  }

  static Future<bool> reorderCarouselItems(List<String> ids) async {
    try {
      final t = await _ensureToken();
      if (t == null || t.isEmpty) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/carousel/reorder/'),
        headers: {
          'Authorization': 'Token $t',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ids': ids}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ reorderCarouselItems error: $e');
      return false;
    }
  }

  // ==================== INSTRUCTOR APPLICATIONS ====================

  static Future<List<Map<String, dynamic>>> getInstructorApplications({
    String status = 'all',
  }) async {
    try {
      final t = await _ensureToken();
      if (t == null || t.isEmpty) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/bookings/admin/instructor-applications/?status=$status'),
        headers: {'Authorization': 'Token $t'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      }
      await _handleUnauthorized(response.statusCode);
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getInstructorApplicationDetail(String id) async {
    try {
      final t = await _ensureToken();
      if (t == null || t.isEmpty) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/bookings/admin/instructor-applications/$id/'),
        headers: {'Authorization': 'Token $t'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> approveInstructorApplication(String id) async {
    try {
      final t = await _ensureToken();
      if (t == null || t.isEmpty) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/bookings/admin/instructor-applications/$id/approve/'),
        headers: {'Authorization': 'Token $t'},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> rejectInstructorApplication({
    required String id,
    required String reason,
  }) async {
    try {
      final t = await _ensureToken();
      if (t == null || t.isEmpty) {
        return {'success': false, 'error': 'Not logged in'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/bookings/admin/instructor-applications/$id/reject/'),
        headers: {
          'Authorization': 'Token $t',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'reason': reason}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== REJECT POST ====================

  static Future<Map<String, dynamic>> rejectPost({
    required String postType,
    required String postId,
    required String reason,
    String note = '',
  }) async {
    try {
      final t = await _ensureToken();
      if (t == null || t.isEmpty) {
        return {'success': false, 'error': 'Not logged in'};
      }
      final response = await http.post(
        Uri.parse('$baseUrl/users/admin/reject-post/'),
        headers: {
          'Authorization': 'Token $t',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'post_type': postType,
          'post_id': postId,
          'reason': reason,
          'note': note,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<bool> approvePost({
    required String postType,
    required String postId,
  }) async {
    try {
      final t = await _ensureToken();
      if (t == null || t.isEmpty) return false;
      final url = postType == 'recipe'
          ? '$baseUrl/users/admin/recipes/$postId/approve/'
          : '$baseUrl/users/admin/ingredients/$postId/approve/';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Authorization': 'Token $t'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // ADMIN REPORTS
  // ============================================================

  static Future<Map<String, dynamic>> adminGetReports({
    String status = 'pending',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reports/?status=$status'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> adminResolveReport({
    required String reportId,
    required String action, // 'keep' | 'remove'
    String adminNote = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reports/$reportId/resolve/'),
        headers: _getHeaders(),
        body: jsonEncode({
          'action': action,
          'admin_note': adminNote,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      String errorMsg = 'Failed: ${response.statusCode}';
      try {
        final d = jsonDecode(response.body);
        if (d['error'] != null) errorMsg = d['error'].toString();
      } catch (_) {}
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== REFUNDS ====================

  static Future<Map<String, dynamic>> getRefunds({
    String status = 'pending_admin',
  }) async {
    try {
      final t = await _ensureToken();
      if (t == null || t.isEmpty) {
        return {'success': false, 'error': 'Not logged in'};
      }
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/admin/refunds/?status=$status'),
        headers: {'Authorization': 'Token $t'},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> resolveRefund({
    required String refundId,
    required String decision, // 'full' | 'half' | 'none'
    String adminNote = '',
  }) async {
    try {
      final t = await _ensureToken();
      if (t == null || t.isEmpty) {
        return {'success': false, 'error': 'Not logged in'};
      }
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/admin/refunds/$refundId/resolve/'),
        headers: {
          'Authorization': 'Token $t',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'decision': decision,
          'admin_note': adminNote,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      String errorMsg = 'Failed: ${response.statusCode}';
      try {
        final d = jsonDecode(response.body);
        if (d['error'] != null) errorMsg = d['error'].toString();
      } catch (_) {}
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }
}