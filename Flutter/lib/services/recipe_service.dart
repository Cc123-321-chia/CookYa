// services/recipe_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path/path.dart';
import '../models/recipe.dart';
import 'api_service.dart';

class RecipeService {
  static Future<Map<String, dynamic>> createRecipe({
    required String title,
    required String description,
    required String cuisineType,
    required int durationMinutes,
    required int difficultyLevel,
    required List<String> tags,
    required List<String> cookingTools,
    required List<IngredientItem> ingredients,
    required List<StepItem> steps,
    required List<File> photos,
    File? video,
    File? videoCover,
    required String token,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/recipes/create/'),
      );

      // Add headers
      request.headers['Authorization'] = 'Token $token';

      // Add simple fields
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['cuisine_type'] = cuisineType;
      request.fields['duration_minutes'] = durationMinutes.toString();
      request.fields['difficulty_level'] = difficultyLevel.toString();

      // Add JSON fields
      request.fields['tags'] = jsonEncode(tags);
      request.fields['cooking_tools'] = jsonEncode(cookingTools);

      // Format ingredients
      List<Map<String, String>> ingredientsList = ingredients.map((ing) {
        return {'name': ing.name, 'amount': ing.amount};
      }).toList();
      request.fields['ingredients'] = jsonEncode(ingredientsList);

      // Format steps
      List<Map<String, String>> stepsList = steps.map((step) {
        return {
          'instruction': step.instruction,
          'note': step.note ?? '',
        };
      }).toList();
      request.fields['steps'] = jsonEncode(stepsList);

      // Add photos
      for (int i = 0; i < photos.length; i++) {
        var photoFile = await http.MultipartFile.fromPath(
          'photos',
          photos[i].path,
          filename: 'photo_$i.jpg',
        );
        request.files.add(photoFile);
      }

      // Add video if exists
      if (video != null) {
        var videoFile = await http.MultipartFile.fromPath(
          'video',
          video.path,
          filename: 'video.mp4',
        );
        request.files.add(videoFile);
      }

      // Add video cover if exists
      if (videoCover != null) {
        var coverFile = await http.MultipartFile.fromPath(
          'video_cover',
          videoCover.path,
          filename: 'cover.jpg',
        );
        request.files.add(coverFile);
      }

      print('=== SENDING REQUEST ===');
      print('Fields: ${request.fields}');
      print('Files count: ${request.files.length}');

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
          'details': response.body
        };
      }

    } catch (e) {
      print('Error creating recipe: $e');
      return {
        'success': false,
        'error': 'Connection error: $e',
      };
    }
  }
   static Future<Map<String, dynamic>> updateRecipe({
    required String recipeId,
    required String title,
    required String description,
    required String cuisineType,
    required int durationMinutes,
    required int difficultyLevel,
    required List<String> tags,
    required List<String> cookingTools,
    required List<IngredientItem> ingredients,
    required List<StepItem> steps,
    required List<String> existingPhotoUrls,
    required List<File> newPhotos,
    String? existingVideoUrl,
    File? newVideo,
    String? existingVideoCoverUrl,
    File? newVideoCover,
    bool removeVideo = false,
    bool removeVideoCover = false,
    required String token,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/recipes/$recipeId/update/'),
      );

      request.headers['Authorization'] = 'Token $token';

      // Simple fields
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['cuisine_type'] = cuisineType;
      request.fields['duration_minutes'] = durationMinutes.toString();
      request.fields['difficulty_level'] = difficultyLevel.toString();

      // JSON fields
      request.fields['tags'] = jsonEncode(tags);
      request.fields['cooking_tools'] = jsonEncode(cookingTools);

      final ingredientsList = ingredients.map((ing) {
        return {'name': ing.name, 'amount': ing.amount};
      }).toList();
      request.fields['ingredients'] = jsonEncode(ingredientsList);

      final stepsList = steps.map((step) {
        return {
          'instruction': step.instruction,
          'note': step.note ?? '',
        };
      }).toList();
      request.fields['steps'] = jsonEncode(stepsList);

      // Media: 保留的旧照片
      request.fields['existing_photo_urls'] = jsonEncode(existingPhotoUrls);

      // Media: 新增照片
      for (int i = 0; i < newPhotos.length; i++) {
        try {
          final file = await http.MultipartFile.fromPath(
            'new_photos',
            newPhotos[i].path,
            filename: 'new_photo_$i.jpg',
          );
          request.files.add(file);
        } catch (e) {
          print('Error adding new photo $i: $e');
        }
      }

      // Video
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

      // Video cover
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

      print('=== UPDATE RECIPE REQUEST ===');
      print('URL: recipes/$recipeId/update/');
      print('Fields: ${request.fields}');
      print('Files count: ${request.files.length}');

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e) {
      print('Error updating recipe: $e');
      return {
        'success': false,
        'error': 'Connection error: $e',
      };
    }
  }
}