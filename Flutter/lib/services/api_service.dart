// lib/services/api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/carousel_item.dart';
import '../models/recipe.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String? _savedBaseUrl;

  // App 启动时调用一次
  static Future<void> loadSavedBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _savedBaseUrl = prefs.getString('api_base_url');
  }

  // 用户在设置页填完后调用
  static Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', url);
    _savedBaseUrl = url;
  }

  static String get baseUrl {
    // 1) 用户手动设置的（最高优先级）
    if (_savedBaseUrl != null && _savedBaseUrl!.isNotEmpty) {
      return _savedBaseUrl!;
    }
    // 2) 编译时传入的（--dart-define）
    const override = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (override.isNotEmpty) return override;
    // 3) 平台默认
    if (kIsWeb) return 'http://localhost:8000/api';
    return 'http://192.168.1.100:8000/api';  // fallback
  }

  static String resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    // 相对路径 /media/xxx → 直接拼
    if (url.startsWith('/')) {
      final host = baseUrl.replaceAll(RegExp(r'/api/?$'), '');
      return '$host$url';
    }

    // 🔥 完整 URL → 提取 path，重新拼当前 host
    if (url.startsWith('http://') || url.startsWith('https://')) {
      try {
        final uri = Uri.parse(url);
        final host = baseUrl.replaceAll(RegExp(r'/api/?$'), '');
        // 路径部分（/media/xxx.jpg）
        return '$host${uri.path}';
      } catch (e) {
        return url;
      }
    }

    return url;
  }

  static String? authToken;

  // ==================== CURRENT USER ====================
  static String? currentUserId;
  static bool currentUserIsCulinaryInstructor = false;

  static void setCurrentUser(Map<String, dynamic> user) {
    currentUserId = user['user_id']?.toString();
    currentUserIsCulinaryInstructor = user['is_culinary_instructor'] == true;
  }

  static bool isMyClass(String instructorUserId) {
    return currentUserId != null && currentUserId == instructorUserId;
  }

  // ==================== Homework (Dishes) ====================

  static Future<Map<String, dynamic>> getMyHomeworks() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recipes/my-homeworks/'),
        headers: {'Authorization': 'Token $authToken'},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getUserHomeworks(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recipes/users/$userId/homeworks/'),
        headers: {if (authToken != null) 'Authorization': 'Token $authToken'},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getRecipeHomeworks(String recipeId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recipes/$recipeId/homeworks/'),
        headers: {if (authToken != null) 'Authorization': 'Token $authToken'},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> submitHomework({
    required String recipeId,
    required String review,
    required String rating,
    String? imageBase64,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/recipes/$recipeId/homeworks/');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Token $authToken';
      request.fields['review'] = review;
      request.fields['rating'] = rating;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        request.fields['image_base64'] = imageBase64;
      }
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      final errorData = jsonDecode(response.body);
      return {'success': false, 'error': errorData['error'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateHomework({
    required String homeworkId,
    String? review,
    String? rating,
    String? imageBase64,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/homeworks/$homeworkId/');
      final request = http.MultipartRequest('PATCH', uri);
      request.headers['Authorization'] = 'Token $authToken';
      if (review != null) request.fields['review'] = review;
      if (rating != null) request.fields['rating'] = rating;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        request.fields['image_base64'] = imageBase64;
      }
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteHomework(String homeworkId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/homeworks/$homeworkId/'),
        headers: {'Authorization': 'Token $authToken'},
      );
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': authToken != null ? 'Token $authToken' : '',
    };
  }

  // ============================================================
  // AUTH API METHODS
  // ============================================================

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/login/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        authToken = data['data']['token'];
        setCurrentUser(data['data']['user']);
        return {
          'success': true,
          'token': data['data']['token'],
          'user': data['data']['user'],
        };
      } else {
        return {'success': false, 'error': data['error'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/register/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
          'confirm_password': confirmPassword,
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      } else {
        String errorMsg = 'Registration failed';
        if (data['error'] is Map) {
          if (data['error']['username'] != null) {
            errorMsg = data['error']['username'][0];
          } else if (data['error']['email'] != null) {
            errorMsg = data['error']['email'][0];
          } else if (data['error']['password'] != null) {
            errorMsg = data['error']['password'][0];
          } else if (data['error']['confirm_password'] != null) {
            errorMsg = data['error']['confirm_password'][0];
          }
        } else if (data['error'] is String) {
          errorMsg = data['error'];
        }
        return {'success': false, 'error': errorMsg};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> changePassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/change-password/'),
        headers: _getHeaders(),
        body: json.encode({
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Password changed'};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> changeEmail({
    required String newEmail,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/change-email/'),
        headers: _getHeaders(),
        body: json.encode({'new_email': newEmail}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Email changed'};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteAccount({
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/delete-account/'),
        headers: _getHeaders(),
        body: json.encode({'password': password}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        authToken = null;
        currentUserId = null;
        currentUserIsCulinaryInstructor = false;
        return {'success': true, 'message': data['message'] ?? 'Account deleted'};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/users/logout/'),
        headers: _getHeaders(),
      );
      authToken = null;
      currentUserId = null;
      currentUserIsCulinaryInstructor = false;
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/profile/'),
        headers: _getHeaders(),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        setCurrentUser(data['data']);
        return {'success': true, 'user': data['data']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? username,
    String? bio,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/profile/update/'),
        headers: _getHeaders(),
        body: json.encode({
          if (username != null) 'username': username,
          if (bio != null) 'bio': bio,
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'user': data['data']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateProfileWithAvatar({
    String? username,
    String? bio,
    File? avatar,
  }) async {
    try {
      final token = authToken;
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/users/profile/update/'),
      );
      request.headers['Authorization'] = 'Token $token';
      if (username != null) request.fields['username'] = username;
      if (bio != null) request.fields['bio'] = bio;
      if (avatar != null) {
        request.files.add(
          await http.MultipartFile.fromPath('avatar', avatar.path),
        );
      }
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'] ?? 'Profile updated',
        };
      } else {
        String errorMsg = 'Failed to update profile';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          } else if (errorData['message'] != null) {
            errorMsg = errorData['message'].toString();
          }
        } catch (_) {}
        return {
          'success': false,
          'error': errorMsg,
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ============================================================
  // CAROUSEL API METHODS
  // ============================================================

  static Future<List<CarouselItem>> getCarouselItems() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/carousel/'),
        headers: authToken != null ? {'Authorization': 'Token $authToken'} : {},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => CarouselItem.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // RECIPE API METHODS
  // ============================================================

  static Future<List<Recipe>> searchRecipesByKeywords(List<String> keywords) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recipes/search-by-keywords/?keywords=${keywords.join(',')}'),
        headers: authToken != null ? {'Authorization': 'Token $authToken'} : {},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Recipe.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Search by keywords error: $e');
      return [];
    }
  }

  static Future<List<Recipe>> getAllRecipes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recipes/'),
        headers: authToken != null ? {'Authorization': 'Token $authToken'} : {},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Recipe.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get all recipes error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getLikedRecipes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recipes/liked/'),
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

  static Future<Map<String, dynamic>> getRecipeIngredients(String recipeId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recipes/$recipeId/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getRecipeDetails(String recipeId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recipes/$recipeId/'),
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

  static Future<Map<String, dynamic>> getRecipesByIds(List<String> recipeIds) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/recipes/batch/'),
        headers: _getHeaders(),
        body: jsonEncode({'ids': recipeIds}),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> toggleLikeRecipe(String recipeId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/recipes/$recipeId/like/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'liked': data['liked'],
          'likes_count': data['likes_count'],
        };
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteRecipe(String recipeId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/recipes/$recipeId/delete/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Recipe deleted'};
      }
      String errorMsg = 'Failed: ${response.statusCode}';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData['error'] != null) errorMsg = errorData['error'].toString();
      } catch (_) {}
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteComment(String commentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/comments/$commentId/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Comment deleted'};
      }
      String errorMsg = 'Failed: ${response.statusCode}';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData['error'] != null) errorMsg = errorData['error'].toString();
      } catch (_) {}
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getCurrentUserId() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/profile/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'id': data['data']['id']?.toString() ?? '',
          'user_id': data['data']['user_id']?.toString() ?? '',
          'username': data['data']['username']?.toString() ?? '',
        };
      }
      return {'success': false, 'error': 'Failed to load profile'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> addRecipeComment({
    required String recipeId,
    required String text,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/recipes/$recipeId/comments/'),
        headers: _getHeaders(),
        body: jsonEncode({'text': text}),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getRecipeComments(String recipeId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recipes/$recipeId/comments/'),
        headers: authToken != null ? {'Authorization': 'Token $authToken'} : {},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ============================================================
  // INGREDIENT API METHODS
  // ============================================================

  static Future<Map<String, dynamic>> getIngredientPosts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ingredients/'),
        headers: authToken != null ? {'Authorization': 'Token $authToken'} : {},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> createIngredientPost({
    required String title,
    required String content,
    required List<String> tags,
    required List<File> photos,
    File? video,
    File? videoCover,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/ingredients/create/'),
      );
      request.headers['Authorization'] = 'Token $authToken';
      request.fields['title'] = title;
      request.fields['content'] = content;
      request.fields['tags'] = jsonEncode(tags);
      for (int i = 0; i < photos.length; i++) {
        try {
          final file = await http.MultipartFile.fromPath('photo_urls', photos[i].path);
          request.files.add(file);
        } catch (e) {
          debugPrint('Error adding photo $i: $e');
        }
      }
      if (video != null) {
        try {
          final videoFile = await http.MultipartFile.fromPath('video_url', video.path);
          request.files.add(videoFile);
        } catch (e) {
          debugPrint('Error adding video: $e');
        }
      }
      if (videoCover != null) {
        try {
          final coverFile = await http.MultipartFile.fromPath('video_cover_url', videoCover.path);
          request.files.add(coverFile);
        } catch (e) {
          debugPrint('Error adding video cover: $e');
        }
      }
      final response = await request.send();
      final responseBody = await http.Response.fromStream(response);
      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(responseBody.body)};
      }
      String errorMessage = 'Failed to create post';
      try {
        final errorData = jsonDecode(responseBody.body);
        if (errorData is Map) {
          if (errorData['error'] != null) {
            errorMessage = errorData['error'].toString();
          } else if (errorData['message'] != null) {
            errorMessage = errorData['message'].toString();
          }
        }
      } catch (e) {
        errorMessage = 'Server error: ${response.statusCode}';
      }
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getIngredientPost(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ingredients/$id/'),
        headers: authToken != null ? {'Authorization': 'Token $authToken'} : {},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> toggleLikeIngredientPost(String id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ingredients/$id/like/'),
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

  static Future<Map<String, dynamic>> getIngredientComments(String postId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ingredients/$postId/comments/'),
        headers: authToken != null ? {'Authorization': 'Token $authToken'} : {},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> addIngredientComment({
    required String postId,
    required String text,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ingredients/$postId/comments/'),
        headers: _getHeaders(),
        body: jsonEncode({'text': text}),
      );
      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getLikedIngredientPosts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ingredients/liked/'),
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

  static Future<Map<String, dynamic>> getMyIngredientComments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ingredients/my-comments/'),
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

  static Future<Map<String, dynamic>> deleteIngredientComment(String commentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/ingredients/comments/$commentId/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Comment deleted'};
      }
      String errorMsg = 'Failed: ${response.statusCode}';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData['error'] != null) errorMsg = errorData['error'].toString();
      } catch (_) {}
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteIngredientPost(String postId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/ingredients/$postId/delete/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Post deleted'};
      }
      String errorMsg = 'Failed: ${response.statusCode}';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData['error'] != null) errorMsg = errorData['error'].toString();
      } catch (_) {}
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateIngredientPost({
    required String postId,
    required String title,
    required String content,
    required List<String> tags,
    required List<String> existingPhotoUrls,
    required List<File> newPhotos,
    String? existingVideoUrl,
    File? newVideo,
    String? existingVideoCoverUrl,
    File? newVideoCover,
    bool removeVideo = false,
    bool removeVideoCover = false,
  }) async {
    try {
      final token = authToken;
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/ingredients/$postId/update/'),
      );
      request.headers['Authorization'] = 'Token $token';
      request.fields['title'] = title;
      request.fields['content'] = content;
      request.fields['tags'] = jsonEncode(tags);
      request.fields['existing_photo_urls'] = jsonEncode(existingPhotoUrls);
      for (int i = 0; i < newPhotos.length; i++) {
        try {
          final file = await http.MultipartFile.fromPath(
            'new_photos',
            newPhotos[i].path,
            filename: 'new_photo_$i.jpg',
          );
          request.files.add(file);
        } catch (e) {
          debugPrint('Error adding new photo $i: $e');
        }
      }
      if (removeVideo) {
        request.fields['remove_video'] = 'true';
      } else if (newVideo != null) {
        final videoFile = await http.MultipartFile.fromPath(
          'new_video',
          newVideo.path,
          filename: 'new_video.mp4',
        );
        request.files.add(videoFile);
      } else if (existingVideoUrl != null) {
        request.fields['existing_video_url'] = existingVideoUrl;
      }
      if (removeVideoCover) {
        request.fields['remove_video_cover'] = 'true';
      } else if (newVideoCover != null) {
        final coverFile = await http.MultipartFile.fromPath(
          'new_video_cover',
          newVideoCover.path,
          filename: 'new_cover.jpg',
        );
        request.files.add(coverFile);
      } else if (existingVideoCoverUrl != null) {
        request.fields['existing_video_cover_url'] = existingVideoCoverUrl;
      }
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        'success': false,
        'error': 'Server error: ${response.statusCode}',
        'details': response.body,
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // ============================================================
  // GROCERY API METHODS
  // ============================================================

  static Future<Map<String, dynamic>> getGroceryLists() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groceries/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      String errorMsg = 'Failed to load grocery lists';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData['error'] != null) {
          errorMsg = errorData['error'].toString();
        }
      } catch (_) {}
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> createGroceryList({
    required String title,
    required String shoppingDate,
    bool isGenerated = false,
    String? remark,                                 // 🔥 新增
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final body = <String, dynamic>{
        'title': title,
        'shopping_date': shoppingDate,
        'is_generated': isGenerated,
        if (remark != null && remark.isNotEmpty) 'remark': remark,   // 🔥
      };
      if (items != null && items.isNotEmpty) body['items'] = items;
      final response = await http.post(
        Uri.parse('$baseUrl/groceries/'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      String errorMsg = 'Failed to create grocery list';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData['error'] != null) {
          errorMsg = errorData['error'].toString();
        }
      } catch (_) {}
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getGroceryList(String listId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groceries/$listId/'),
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

  static Future<Map<String, dynamic>> updateGroceryList({
    required String listId,
    String? title,
    String? shoppingDate,
    bool? isGenerated,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (shoppingDate != null) body['shopping_date'] = shoppingDate;
      if (isGenerated != null) body['is_generated'] = isGenerated;
      if (items != null) body['items'] = items;
      final response = await http.put(
        Uri.parse('$baseUrl/groceries/$listId/'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteGroceryList(String listId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/groceries/$listId/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 204 || response.statusCode == 200) {
        return {'success': true, 'message': 'Deleted successfully'};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> addGroceryItem({
    required String listId,
    required String name,
    String category = 'Others',
    double quantity = 1.0,
    String unit = 'pcs',
    String? recipeName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groceries/$listId/items/'),
        headers: _getHeaders(),
        body: jsonEncode({
          'name': name,
          'category': category,
          'quantity': quantity,
          'unit': unit,
          if (recipeName != null) 'recipe_name': recipeName,
        }),
      );
      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateGroceryItem({
    required String itemId,
    String? name,
    String? category,
    double? quantity,
    String? unit,
    bool? isChecked,
    String? recipeName,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (category != null) body['category'] = category;
      if (quantity != null) body['quantity'] = quantity;
      if (unit != null) body['unit'] = unit;
      if (isChecked != null) body['is_checked'] = isChecked;
      if (recipeName != null) body['recipe_name'] = recipeName;
      final response = await http.put(
        Uri.parse('$baseUrl/groceries/items/$itemId/'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteGroceryItem(String itemId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/groceries/items/$itemId/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 204 || response.statusCode == 200) {
        return {'success': true, 'message': 'Deleted successfully'};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> toggleGroceryItem(String itemId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/groceries/items/$itemId/toggle/'),
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

  static Future<Map<String, dynamic>> bulkUpdateGroceryItems({
    required String listId,
    required String action,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groceries/$listId/items/bulk/'),
        headers: _getHeaders(),
        body: jsonEncode({'action': action}),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> createGroceryListFromMealPlan({
    required String title,
    required String shoppingDate,
    required Map<String, Map<String, List<String>>> mealPlan,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groceries/from-meal-plan/'),
        headers: _getHeaders(),
        body: jsonEncode({
          'title': title,
          'shopping_date': shoppingDate,
          'meal_plan': mealPlan,
        }),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      String errorMsg = 'Failed to create list from meal plan';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData['error'] != null) errorMsg = errorData['error'].toString();
      } catch (_) {}
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ============================================================
  // FOLLOW API METHODS
  // ============================================================

  static Future<Map<String, dynamic>> getUserProfileByUserId(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/profile/$userId/'),
        headers: authToken != null ? {'Authorization': 'Token $authToken'} : {},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> followUser(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/follow/$userId/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'message': data['message'] ?? 'Followed'};
      }
      String errorMsg = 'Failed: ${response.statusCode}';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData['error'] != null) errorMsg = errorData['error'].toString();
      } catch (_) {}
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> unfollowUser(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/unfollow/$userId/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'message': data['message'] ?? 'Unfollowed'};
      }
      String errorMsg = 'Failed: ${response.statusCode}';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData['error'] != null) errorMsg = errorData['error'].toString();
      } catch (_) {}
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> checkFollow(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/check-follow/$userId/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'is_following': data['data']?['is_following'] == true,
        };
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getFollowers(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/followers/$userId/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'count': data['count'] ?? 0,
          'data': data['data'] ?? [],
        };
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getFollowing(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/following/$userId/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'count': data['count'] ?? 0,
          'data': data['data'] ?? [],
        };
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ============================================================
  // BOOKING API METHODS
  // ============================================================

  static Future<Map<String, dynamic>> getCookingClasses() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/classes/'),
        headers: authToken != null ? {'Authorization': 'Token $authToken'} : {},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> toggleSaveClass(String classId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/classes/$classId/save/'),
        headers: _getHeaders(),
      );
      final data = jsonDecode(response.body);
      return {'success': data['success'] == true, 'saved': data['saved']};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getMySavedClasses() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/my-saved/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createBooking({
    required String classId,
    required String date,
    required String slotId,
    required int quantity,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/classes/$classId/book/'),
        headers: _getHeaders(),
        body: jsonEncode({
          'date': date,
          'slot_id': slotId,
          'quantity': quantity,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': data['error'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getMyBookings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/my-bookings/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/bookings/$bookingId/cancel/'),
        headers: _getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getInstructorOrders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/instructor/orders/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

    static Future<Map<String, dynamic>> instructorConfirmBooking(
    String bookingId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$baseUrl/bookings/instructor/bookings/$bookingId/confirm/',
        ),
        headers: _getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> instructorRejectBooking(
    String bookingId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$baseUrl/bookings/instructor/bookings/$bookingId/reject/',
        ),
        headers: _getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

    static Future<Map<String, dynamic>> instructorCancelBooking(
    String bookingId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$baseUrl/bookings/instructor/bookings/$bookingId/cancel/',
        ),
        headers: _getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> submitReview({
    required String bookingId,
    required int rating,
    required String comment,
    File? image,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/bookings/bookings/$bookingId/review/'),
      );
      request.headers['Authorization'] = 'Token $authToken';
      request.fields['rating'] = rating.toString();
      request.fields['comment'] = comment;
      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath('image', image.path));
      }
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getClassReviews({
    required String classId,
    String filter = 'all',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/classes/$classId/reviews/?filter=$filter'),
        headers: authToken != null ? {'Authorization': 'Token $authToken'} : {},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getMyInstructorProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/instructor/profile/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getInstructorProfileDetail(String instructorId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/instructor/profile/$instructorId/'),
        headers: authToken != null ? {'Authorization': 'Token $authToken'} : {},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> applyInstructor({
    required String shopName,
    required String description,
    required String address,
    required String phone,
    required String email,
    String? classTitle,
    String? classDescription,
    String? price,
    String? schedule,
    List<String> tags = const [],
    List<String> dishes = const [],
    List<String> certificates = const [],
    File? avatar,
    File? coverPhoto,
    File? businessLicense,
    File? foodLicense,
    File? healthCertificate,
    File? chefCertification,
    File? insurance,
    File? foodSafetyCertificate,
    List<File> shopPhotos = const [],
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/bookings/instructor/apply/'),
      );
      request.headers['Authorization'] = 'Token $authToken';
      request.fields['shop_name'] = shopName;
      request.fields['description'] = description;
      request.fields['address'] = address;
      request.fields['phone'] = phone;
      request.fields['email'] = email;
      request.fields['class_title'] = classTitle ?? '';
      request.fields['class_description'] = classDescription ?? '';
      request.fields['price'] = price ?? '';
      request.fields['schedule'] = schedule ?? '';
      request.fields['tags'] = jsonEncode(tags);
      request.fields['dishes'] = jsonEncode(dishes);
      request.fields['certificates'] = jsonEncode(certificates);

      if (avatar != null) {
        request.files.add(await http.MultipartFile.fromPath('avatar', avatar.path));
      }
      if (coverPhoto != null) {
        request.files.add(await http.MultipartFile.fromPath('cover_photo', coverPhoto.path));
      }
      if (businessLicense != null) {
        request.files.add(await http.MultipartFile.fromPath('business_license', businessLicense.path));
      }
      if (foodLicense != null) {
        request.files.add(await http.MultipartFile.fromPath('food_license', foodLicense.path));
      }
      if (healthCertificate != null) {
        request.files.add(await http.MultipartFile.fromPath('health_certificate', healthCertificate.path));
      }
      if (chefCertification != null) {
        request.files.add(await http.MultipartFile.fromPath('chef_certification', chefCertification.path));
      }
      if (insurance != null) {
        request.files.add(await http.MultipartFile.fromPath('insurance', insurance.path));
      }
      if (foodSafetyCertificate != null) {
        request.files.add(await http.MultipartFile.fromPath('food_safety_certificate', foodSafetyCertificate.path));
      }
      for (final photo in shopPhotos) {
        request.files.add(await http.MultipartFile.fromPath('shop_photos', photo.path));
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> editInstructorProfile({
    required String shopName,
    required String description,
    required String address,
    required String phone,
    required String email,
    String? classTitle,
    String? classDescription,
    String? price,
    String? schedule,
    List<String> tags = const [],
    List<String> dishes = const [],
    List<String> certificates = const [],
    File? avatar,
    File? coverPhoto,
    File? businessLicense,
    File? foodLicense,
    File? healthCertificate,
    File? chefCertification,
    File? insurance,
    File? foodSafetyCertificate,
    List<File> shopPhotos = const [],
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/bookings/instructor/edit/'),
      );
      request.headers['Authorization'] = 'Token $authToken';
      request.fields['shop_name'] = shopName;
      request.fields['description'] = description;
      request.fields['address'] = address;
      request.fields['phone'] = phone;
      request.fields['email'] = email;
      request.fields['class_title'] = classTitle ?? '';
      request.fields['class_description'] = classDescription ?? '';
      request.fields['price'] = price ?? '';
      request.fields['schedule'] = schedule ?? '';
      request.fields['tags'] = jsonEncode(tags);
      request.fields['dishes'] = jsonEncode(dishes);
      request.fields['certificates'] = jsonEncode(certificates);

      if (avatar != null) {
        request.files
            .add(await http.MultipartFile.fromPath('avatar', avatar.path));
      }
      if (coverPhoto != null) {
        request.files.add(
            await http.MultipartFile.fromPath('cover_photo', coverPhoto.path));
      }
      if (businessLicense != null) {
        request.files.add(await http.MultipartFile.fromPath(
            'business_license', businessLicense.path));
      }
      if (foodLicense != null) {
        request.files.add(
            await http.MultipartFile.fromPath('food_license', foodLicense.path));
      }
      if (healthCertificate != null) {
        request.files.add(await http.MultipartFile.fromPath(
            'health_certificate', healthCertificate.path));
      }
      if (chefCertification != null) {
        request.files.add(await http.MultipartFile.fromPath(
            'chef_certification', chefCertification.path));
      }
      if (insurance != null) {
        request.files
            .add(await http.MultipartFile.fromPath('insurance', insurance.path));
      }
      if (foodSafetyCertificate != null) {
        request.files.add(await http.MultipartFile.fromPath(
            'food_safety_certificate', foodSafetyCertificate.path));
      }
      for (final photo in shopPhotos) {
        request.files
            .add(await http.MultipartFile.fromPath('shop_photos', photo.path));
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== Instructor Class CRUD ====================

  static Future<Map<String, dynamic>> createClass({
    required String title,
    required String description,
    required String location,
    required double price,
    String classType = 'in_person',
    String schedule = '',
    List<String> tags = const [],
    List<String> dishes = const [],
    List<String> certificates = const [],
    File? image,
    File? coverVideo,
    List<File> images = const [],
    List<File> videos = const [],
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/bookings/instructor/classes/create/'),
      );
      request.headers['Authorization'] = 'Token $authToken';
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['location'] = location;
      request.fields['price'] = price.toString();
      request.fields['class_type'] = classType;
      request.fields['schedule'] = schedule;
      request.fields['tags'] = jsonEncode(tags);
      request.fields['dishes'] = jsonEncode(dishes);
      request.fields['certificates'] = jsonEncode(certificates);

      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath('image', image.path));
      }
      if (coverVideo != null) {
        request.files.add(await http.MultipartFile.fromPath('cover_video', coverVideo.path));
      }
      for (final f in images) {
        request.files.add(await http.MultipartFile.fromPath('images', f.path));
      }
      for (final f in videos) {
        request.files.add(await http.MultipartFile.fromPath('videos', f.path));
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateClass({
    required String classId,
    required String title,
    required String description,
    required String location,
    required double price,
    String classType = 'in_person',
    String schedule = '',
    List<String>? tags,
    List<String>? dishes,
    List<String>? certificates,
    File? image,
    File? coverVideo,
    List<File> newImages = const [],
    List<File> newVideos = const [],
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/bookings/instructor/classes/$classId/update/'),
      );
      request.headers['Authorization'] = 'Token $authToken';
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['location'] = location;
      request.fields['price'] = price.toString();
      request.fields['class_type'] = classType;
      request.fields['schedule'] = schedule;
      if (tags != null) request.fields['tags'] = jsonEncode(tags);
      if (dishes != null) request.fields['dishes'] = jsonEncode(dishes);
      if (certificates != null) {
        request.fields['certificates'] = jsonEncode(certificates);
      }
      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath('image', image.path));
      }
      if (coverVideo != null) {
        request.files.add(await http.MultipartFile.fromPath('cover_video', coverVideo.path));
      }
      for (final f in newImages) {
        request.files.add(await http.MultipartFile.fromPath('new_images', f.path));
      }
      for (final f in newVideos) {
        request.files.add(await http.MultipartFile.fromPath('new_videos', f.path));
      }
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteClass({
    required String classId,
    bool force = false,
  }) async {
    try {
      final request = http.Request(
        'DELETE',
        Uri.parse('$baseUrl/bookings/instructor/classes/$classId/delete/'),
      );
      request.headers['Authorization'] = 'Token $authToken';
      request.headers['Content-Type'] = 'application/json';
      if (force) {
        request.body = jsonEncode({'force': true});
      }
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== Availability ====================

  static Future<Map<String, dynamic>> getAvailabilities(String classId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/classes/$classId/availability/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> setAvailability({
    required String classId,
    required String startDate,
    required String endDate,
    required bool isDailySame,
    String setType = 'weekly',
    List<Map<String, dynamic>> slots = const [],
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/classes/$classId/availability/'),
        headers: _getHeaders(),
        body: jsonEncode({
          'start_date': startDate,
          'end_date': endDate,
          'is_daily_same': isDailySame,
          'set_type': setType,
          'slots': slots,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteAvailability({
    required String availabilityId,
    bool force = false,
  }) async {
    try {
      final request = http.Request(
        'DELETE',
        Uri.parse('$baseUrl/bookings/availability/$availabilityId/delete/'),
      );
      request.headers['Authorization'] = 'Token $authToken';
      request.headers['Content-Type'] = 'application/json';
      if (force) {
        request.body = jsonEncode({'force': true});
      }
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteAvailabilitySlot({
    required String slotId,
    bool force = false,
  }) async {
    try {
      final request = http.Request(
        'DELETE',
        Uri.parse('$baseUrl/bookings/slots/$slotId/delete/'),
      );
      request.headers['Authorization'] = 'Token $authToken';
      request.headers['Content-Type'] = 'application/json';
      if (force) {
        request.body = jsonEncode({'force': true});
      }
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getClassDaySlots({
    required String classId,
    required String date,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/classes/$classId/day-slots/?date=$date'),
        headers: authToken != null ? {'Authorization': 'Token $authToken'} : {},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getClassWeekOverview({
    required String classId,
    required String start,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/classes/$classId/week-overview/?start=$start'),
        headers: authToken != null ? {'Authorization': 'Token $authToken'} : {},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

    static Future<Map<String, dynamic>> getClassMonthOverview({
    required String classId,
    required int year,
    required int month,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/bookings/classes/$classId/month-overview/?year=$year&month=$month',
        ),
        headers: authToken != null
            ? {'Authorization': 'Token $authToken'}
            : {},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== Payment Cards ====================

  static Future<Map<String, dynamic>> getPaymentCards() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/payment-cards/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> addPaymentCard({
    required String cardNumber,
    required int expMonth,
    required int expYear,
    String holderName = '',
    bool isDefault = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/payment-cards/'),
        headers: _getHeaders(),
        body: jsonEncode({
          'card_number': cardNumber,
          'exp_month': expMonth,
          'exp_year': expYear,
          'holder_name': holderName,
          'is_default': isDefault,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      }
      String errorMsg = 'Failed to add card';
      if (data['error'] is String) {
        errorMsg = data['error'];
      } else if (data['error'] is Map) {
        errorMsg = data['error'].toString();
      }
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deletePaymentCard(String cardId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/bookings/payment-cards/$cardId/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> setDefaultPaymentCard(String cardId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/payment-cards/$cardId/default/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> payBooking({
    required String bookingId,
    required String cardId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/bookings/$bookingId/pay/'),
        headers: _getHeaders(),
        body: jsonEncode({'card_id': cardId}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': data['error'] ?? 'Payment failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> cancelUnpaidBooking(
      String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/bookings/$bookingId/cancel-unpaid/'),
        headers: _getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============================================================
  // CHAT API METHODS
  // ============================================================

  static Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String text,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/chat/send/'),
        headers: _getHeaders(),
        body: jsonEncode({
          'receiver_id': receiverId,
          'text': text,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': data['error'] ?? 'Send failed'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getMessages({
    required String otherUserId,
    String? since,
  }) async {
    try {
      final url = since == null
          ? '$baseUrl/users/chat/messages/$otherUserId/'
          : '$baseUrl/users/chat/messages/$otherUserId/?since=$since';
      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data'] ?? []};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getConversations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/chat/conversations/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data'] ?? []};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ============================================================
  // CALL API METHODS
  // ============================================================
  static Future<Map<String, dynamic>> sendMediaMessage({
    required String receiverId,
    required String messageType, // 'image' | 'video'
    required File file,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/users/chat/send/'),
      );
      request.headers['Authorization'] = 'Token $authToken';
      request.fields['receiver_id'] = receiverId;
      request.fields['message_type'] = messageType;
      request.files.add(
        await http.MultipartFile.fromPath('media', file.path),
      );
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': data['error'] ?? 'Send failed'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> sendStickerMessage({
    required String receiverId,
    required int stickerId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/chat/send/'),
        headers: _getHeaders(),
        body: jsonEncode({
          'receiver_id': receiverId,
          'message_type': 'sticker',
          'sticker_id': stickerId,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': data['error'] ?? 'Send failed'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> initiateCall({
    required String receiverId,
    required String peerId,
    required String callType,   // 'video' 或 'voice'
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/chat/initiate-call/'),
        headers: _getHeaders(),
        body: jsonEncode({
          'receiver_id': receiverId,
          'peer_id': peerId,
          'call_type': callType,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true};
      }
      return {'success': false, 'error': data['error'] ?? 'Call failed'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> createCallRoom({
    required String receiverId,
    String callType = 'video',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/chat/call/create/'),
        headers: _getHeaders(),
        body: jsonEncode({
          'receiver_id': receiverId,
          'call_type': callType,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': data['error'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getCallRoom(String roomId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/chat/call/$roomId/'),
        headers: _getHeaders(),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'error': data['error'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateCallRoomPeerId({
    required String roomId,
    required String peerId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/chat/call/$roomId/peer/'),
        headers: _getHeaders(),
        body: jsonEncode({'peer_id': peerId}),
      );
      final data = jsonDecode(response.body);
      return {'success': response.statusCode == 200 && data['success'] == true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> endCallRoom(String roomId, int durationSeconds) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/chat/call/$roomId/end/'),
        headers: _getHeaders(),
        body: jsonEncode({'duration_seconds': durationSeconds}),
      );
      return {'success': response.statusCode == 200};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> sendSfx(String roomId, String sfx) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/chat/call/$roomId/sfx/'),
        headers: _getHeaders(),
        body: jsonEncode({'sfx': sfx}),
      );
      return {'success': response.statusCode == 200};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getLikedRecipesForCall() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/chat/call/liked-recipes/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data'] ?? []};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ============================================================
  // SYSTEM NOTIFICATIONS
  // ============================================================

  static Future<Map<String, dynamic>> getSystemNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/system-notifications/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'unread_count': data['unread_count'] ?? 0,
          'data': data['data'] ?? [],
        };
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> markSystemNotificationRead(String id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/system-notifications/$id/read/'),
        headers: _getHeaders(),
      );
      return response.statusCode == 200
          ? {'success': true}
          : {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> markAllSystemNotificationsRead() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/system-notifications/read-all/'),
        headers: _getHeaders(),
      );
      return response.statusCode == 200
          ? {'success': true}
          : {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> markMessagesRead(String otherUserId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/chat/messages/$otherUserId/read/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== STICKERS ====================
  static Future<Map<String, dynamic>> getStickers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/stickers/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data'] ?? []};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> reportPost({
    required String postType,   // 'recipe' | 'ingredient' | 'comment'
    required String postId,
    required String reason,
    String note = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reports/create/'),
        headers: _getHeaders(),
        body: jsonEncode({
          'post_type': postType,
          'post_id': postId,
          'reason': reason,
          'note': note,
        }),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      String errorMsg = 'Failed: ${response.statusCode}';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData['error'] != null) errorMsg = errorData['error'].toString();
      } catch (_) {}
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== REFUND FLOW ====================

  static Future<Map<String, dynamic>> requestRefund({
    required String bookingId,
    required String reason,
    String note = '',
    File? image,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/bookings/bookings/$bookingId/refund/'),
      );
      request.headers['Authorization'] = 'Token $authToken';
      request.fields['reason'] = reason;
      request.fields['note'] = note;
      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath('image', image.path));
      }
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
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

  static Future<Map<String, dynamic>> getRefundDetail(String refundId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/refunds/$refundId/'),
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

  static Future<Map<String, dynamic>> instructorRespondRefund({
    required String refundId,
    required bool agrees,
    String response = '',
    File? image,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/bookings/refunds/$refundId/respond/'),
      );
      request.headers['Authorization'] = 'Token $authToken';
      request.fields['agrees'] = agrees.toString();
      request.fields['response'] = response;
      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath('image', image.path));
      }
      final streamed = await request.send();
      final response2 = await http.Response.fromStream(streamed);
      if (response2.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response2.body)};
      }
      String errorMsg = 'Failed: ${response2.statusCode}';
      try {
        final d = jsonDecode(response2.body);
        if (d['error'] != null) errorMsg = d['error'].toString();
      } catch (_) {}
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getMyRefunds() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/my-refunds/'),
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

  static Future<Map<String, dynamic>> completeBooking(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/bookings/$bookingId/complete/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
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

  // ============================================================
  // MENTORSHIP / DISCOVERY API
  // ============================================================

  /// Get all users with is_mentor=True (excluding self).
  static Future<Map<String, dynamic>> getMentors() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/mentors/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data'] ?? []};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Get all active users (excluding self).
  static Future<Map<String, dynamic>> getAllUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/all-users/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data'] ?? []};
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Send a mentorship request to a mentor. Auto-sends a chat message.
  static Future<Map<String, dynamic>> sendMentorshipRequest({
    required String mentorUserId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/mentorship-request/'),
        headers: _getHeaders(),
        body: jsonEncode({'mentor_user_id': mentorUserId}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Failed: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Mentor accepts a pending mentorship request.
  static Future<Map<String, dynamic>> acceptMentorshipRequest(
      int requestId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/mentorship-request/$requestId/accept/'),
        headers: _getHeaders(),
      );
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'data': data['data'],
        'error': data['error'],
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Mentor declines a pending mentorship request.
  static Future<Map<String, dynamic>> declineMentorshipRequest(
      int requestId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/mentorship-request/$requestId/decline/'),
        headers: _getHeaders(),
      );
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'data': data['data'],
        'error': data['error'],
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

    /// Check the mentorship relationship between the current user and target.
  static Future<Map<String, dynamic>> checkMentorshipStatus(
      String otherUserId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/check-mentorship/$otherUserId/'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'is_my_mentor': data['data']?['is_my_mentor'] == true,
          'is_my_mentee': data['data']?['is_my_mentee'] == true,
        };
      }
      return {'success': false, 'error': 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== Chat History Management ====================

  /// Clear the current user's chat history with another user.
  /// Only affects the current user. The other user is unaffected.
  static Future<Map<String, dynamic>> clearChatHistory({
    required String otherUserId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/chat/clear/$otherUserId/'),
        headers: _getHeaders(),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true};
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Failed: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateAvailability({
    required String availabilityId,
    required String startDate,
    required String endDate,
    required bool isDailySame,
    String setType = 'weekly',
    List<Map<String, dynamic>> slots = const [],
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/availability/$availabilityId/update/'),
        headers: _getHeaders(),
        body: jsonEncode({
          'start_date': startDate,
          'end_date': endDate,
          'is_daily_same': isDailySame,
          'set_type': setType,
          'slots': slots,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}