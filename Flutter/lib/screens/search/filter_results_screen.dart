// screens/search/filter_results_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/recipe.dart';
import '../../services/api_service.dart';
import '../../widgets/recipe_card.dart';
import '../recipes/post_detail_screen.dart';

class FilterResultsScreen extends StatefulWidget {
  final Map<String, dynamic> filters;

  const FilterResultsScreen({
    super.key,
    required this.filters,
  });

  @override
  State<FilterResultsScreen> createState() => _FilterResultsScreenState();
}

class _FilterResultsScreenState extends State<FilterResultsScreen> {
  List<Recipe> _allRecipes = [];
  List<Recipe> _matchedRecipes = [];
  List<Recipe> _otherRecipes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchFilteredRecipes();
  }

  Future<void> _fetchFilteredRecipes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = ApiService.authToken;
      final baseUrl = ApiService.baseUrl;

      // 1. Fetch all recipes
      final allUrl = Uri.parse('$baseUrl/recipes/');
      final allResponse = await http.get(
        allUrl,
        headers: token != null ? {'Authorization': 'Token $token'} : {},
      );

      if (allResponse.statusCode != 200) {
        setState(() {
          _errorMessage = 'Failed to load all recipes';
          _isLoading = false;
        });
        return;
      }

      final List<dynamic> allData = jsonDecode(allResponse.body);
      final List<Recipe> allRecipes =
          allData.map((json) => Recipe.fromJson(json)).toList();

      // 2. Build filter URL
      var filterUrl = Uri.parse('$baseUrl/recipes/');
      final queryParams = <String, String>{};

      if (widget.filters['cuisine'] != null) {
        final cuisineValue = widget.filters['cuisine'];
        if (cuisineValue is List && cuisineValue.isNotEmpty) {
          queryParams['cuisine'] = cuisineValue.join(',');
        } else if (cuisineValue is String && cuisineValue.isNotEmpty) {
          queryParams['cuisine'] = cuisineValue;
        }
      }

      if (widget.filters['difficulty'] != null) {
        queryParams['difficulty'] = widget.filters['difficulty'].toString();
      }

      if (widget.filters['duration'] != null) {
        queryParams['max_duration'] = widget.filters['duration'].toString();
      }

      if (widget.filters['ingredients'] != null &&
          (widget.filters['ingredients'] as List).isNotEmpty) {
        queryParams['ingredients'] =
            (widget.filters['ingredients'] as List).join(',');
      }

      if (widget.filters['tools'] != null &&
          (widget.filters['tools'] as List).isNotEmpty) {
        queryParams['tools'] = (widget.filters['tools'] as List).join(',');
      }

      if (queryParams.isNotEmpty) {
        filterUrl = filterUrl.replace(queryParameters: queryParams);
      }

      // 3. Fetch matched recipes
      final filterResponse = await http.get(
        filterUrl,
        headers: token != null ? {'Authorization': 'Token $token'} : {},
      );

      if (filterResponse.statusCode == 200) {
        final List<dynamic> filterData = jsonDecode(filterResponse.body);
        final List<Recipe> matchedRecipes =
            filterData.map((json) => Recipe.fromJson(json)).toList();

        final Set<String> matchedIds = matchedRecipes.map((r) => r.id).toSet();
        final List<Recipe> otherRecipes =
            allRecipes.where((r) => !matchedIds.contains(r.id)).toList();

        setState(() {
          _allRecipes = allRecipes;
          _matchedRecipes = matchedRecipes;
          _otherRecipes = otherRecipes;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to load filtered recipes: ${filterResponse.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  String _getFilterSummary() {
    final parts = <String>[];

    if (widget.filters['cuisine'] != null) {
      final cuisineValue = widget.filters['cuisine'];
      if (cuisineValue is List && cuisineValue.isNotEmpty) {
        parts.add(cuisineValue.join(', '));
      } else if (cuisineValue is String && cuisineValue.isNotEmpty) {
        parts.add(cuisineValue);
      }
    }

    if (widget.filters['ingredients'] != null &&
        (widget.filters['ingredients'] as List).isNotEmpty) {
      parts.add('${(widget.filters['ingredients'] as List).length} ingredients');
    }

    if (widget.filters['duration'] != null) {
      parts.add('≤${widget.filters['duration']} min');
    }

    if (widget.filters['difficulty'] != null) {
      const difficultyMap = {
        1: 'Very Easy',
        2: 'Easy',
        3: 'Medium',
        4: 'Hard',
        5: 'Very Hard',
      };
      parts.add(difficultyMap[widget.filters['difficulty']] ?? 'Medium');
    }

    if (widget.filters['tools'] != null &&
        (widget.filters['tools'] as List).isNotEmpty) {
      parts.add('${(widget.filters['tools'] as List).length} tools');
    }

    return parts.isNotEmpty ? parts.join(' · ') : 'All Recipes';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          color: const Color(0xFF6B4C2A),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Results',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: const Color(0xFF6B4C2A),
              ),
            ),
            Text(
              _getFilterSummary(),
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFFC9A96E),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.tune, color: Color(0xFFFFB347)),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFFFB347)),
            SizedBox(height: 16),
            Text(
              'Loading recipes...',
              style: TextStyle(color: Color(0xFFC9A96E)),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFFFB347)),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: GoogleFonts.poppins(color: const Color(0xFF6B4C2A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchFilteredRecipes,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD966),
                foregroundColor: const Color(0xFF6B4C2A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_allRecipes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant, size: 64, color: Color(0xFFFFB347)),
            SizedBox(height: 16),
            Text(
              'No recipes found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B4C2A),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: TextStyle(color: Color(0xFFC9A96E)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_matchedRecipes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${_matchedRecipes.length} results found',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B4C2A),
              ),
            ),
            const SizedBox(height: 12),
            _buildRecipeGrid(_matchedRecipes),
            const SizedBox(height: 16),
          ],

          if (_otherRecipes.isNotEmpty) ...[
            const Divider(color: Color(0xFFFFF0B5), thickness: 1),
            const SizedBox(height: 12),
            Text(
              'Other Recipes',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFC9A96E),
              ),
            ),
            const SizedBox(height: 12),
            _buildRecipeGrid(_otherRecipes),
            const SizedBox(height: 20),
          ],

          if (_matchedRecipes.isEmpty && _otherRecipes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.search_off,
                      size: 32, color: Color(0xFFFFB347)),
                  const SizedBox(height: 8),
                  Text(
                    'No recipes match your filters',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFC9A96E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Showing all recipes instead',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFFC9A96E).withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildRecipeGrid(List<Recipe> recipes) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 280,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return RecipeCard(
          recipe: recipe,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailScreen(recipeId: recipe.id),
              ),
            );
          },
        );
      },
    );
  }
}