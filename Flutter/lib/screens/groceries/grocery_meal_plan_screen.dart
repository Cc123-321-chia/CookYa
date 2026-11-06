// screens/groceries/grocery_meal_plan_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'grocery_item.dart';
import 'grocery_generate_screen.dart';
import '../../services/api_service.dart';
import '../../models/recipe.dart';

class GroceryMealPlanScreen extends StatefulWidget {
  final VoidCallback? onListGenerated;

  const GroceryMealPlanScreen({
    super.key,
    this.onListGenerated,
  });

  @override
  State<GroceryMealPlanScreen> createState() => _GroceryMealPlanScreenState();
}

class _GroceryMealPlanScreenState extends State<GroceryMealPlanScreen> {
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner'];

  Map<String, Map<String, List<String>>> _mealPlan = {};

  // 🔥 从 API 获取的 Liked Recipes
  List<Recipe> _likedRecipes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initMealPlan();
    _loadLikedRecipes();
  }

  // 🔥 加载用户 Liked Recipes
  Future<void> _loadLikedRecipes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (ApiService.authToken == null) {
        setState(() {
          _errorMessage = 'Please login to see your liked recipes';
          _isLoading = false;
        });
        return;
      }

      final result = await ApiService.getLikedRecipes();

      if (result['success'] == true) {
        final List<dynamic> data = result['data'];
        setState(() {
          _likedRecipes = data.map((json) => Recipe.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to load liked recipes';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _initMealPlan() {
    final Map<String, Map<String, List<String>>> newPlan = {};
    for (var day in _days) {
      newPlan[day] = {};
      for (var meal in _mealTypes) {
        newPlan[day]![meal] = [];
      }
    }
    _mealPlan = newPlan;
  }

  void _addRecipeToMeal(String day, String mealType, String recipeName) {
    setState(() {
      if (!_mealPlan[day]![mealType]!.contains(recipeName)) {
        _mealPlan[day]![mealType]!.add(recipeName);
      }
    });
  }

  void _removeRecipeFromMeal(String day, String mealType, String recipeName) {
    setState(() {
      _mealPlan[day]![mealType]!.remove(recipeName);
    });
  }

  void _clearMeal(String day, String mealType) {
    setState(() {
      _mealPlan[day]![mealType] = [];
    });
  }

  void _clearDay(String day) {
    setState(() {
      for (var meal in _mealTypes) {
        _mealPlan[day]![meal] = [];
      }
    });
  }

  void _clearAllPlan() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Clear All Plan?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        content: Text(
          'This will remove all recipes from your weekly plan.',
          style: GoogleFonts.poppins(
            color: const Color(0xFF6B4C2A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: const Color(0xFFC9A96E),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _initMealPlan();
              setState(() {});
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showAddRecipeSheet(String day, String mealType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            String searchQuery = '';
            List<Recipe> filteredRecipes = _likedRecipes;

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF9E6),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9A96E),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$mealType - $day',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF6B4C2A),
                                ),
                              ),
                              Text(
                                '${_likedRecipes.length} liked recipes',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFFC9A96E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Text(
                            'Close',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFC9A96E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (value) {
                          setModalState(() {
                            searchQuery = value.toLowerCase();
                            filteredRecipes = _likedRecipes.where((recipe) {
                              return recipe.title.toLowerCase().contains(searchQuery);
                            }).toList();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search liked recipes...',
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade400,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFFFFB347),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Loading state
                  if (_isLoading)
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFFFFB347)),
                            SizedBox(height: 12),
                            Text(
                              'Loading liked recipes...',
                              style: TextStyle(color: Color(0xFFC9A96E)),
                            ),
                          ],
                        ),
                      ),
                    )
                  // Error state
                  else if (_errorMessage != null)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Color(0xFFFFB347)),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF6B4C2A),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadLikedRecipes,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFD966),
                                foregroundColor: const Color(0xFF6B4C2A),
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  // Empty state
                  else if (_likedRecipes.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.favorite_border, size: 48, color: Color(0xFFC9A96E)),
                            SizedBox(height: 12),
                            Text(
                              'No liked recipes yet',
                              style: TextStyle(color: Color(0xFFC9A96E)),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Go like some recipes first!',
                              style: TextStyle(color: Color(0xFFC9A96E), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  // Recipe list
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredRecipes.length,
                        itemBuilder: (context, index) {
                          final recipe = filteredRecipes[index];
                          final isAdded = _mealPlan[day]![mealType]!.contains(recipe.title);
                          return _buildRecipeOption(
                            recipe.title,
                            recipe.imageUrl ?? '',
                            isAdded: isAdded,
                            onTap: () {
                              if (isAdded) {
                                _removeRecipeFromMeal(day, mealType, recipe.title);
                              } else {
                                _addRecipeToMeal(day, mealType, recipe.title);
                              }
                              setModalState(() {});
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecipeOption(String name, String image, {required bool isAdded, required VoidCallback onTap}) {
    final fullUrl = ApiService.resolveImageUrl(image);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isAdded ? const Color(0xFFFFF9E6) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isAdded ? const Color(0xFFFFB347) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: fullUrl,
                cacheKey: fullUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 50,
                  height: 50,
                  color: const Color(0xFFFFF0B5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFFB347),
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 50,
                  height: 50,
                  color: const Color(0xFFFFD966),
                  child: const Icon(Icons.restaurant, color: Colors.white, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isAdded ? const Color(0xFFFFB347) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isAdded ? 'Added' : 'Add',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isAdded ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _generateFromPlan() {
    bool hasRecipes = false;
    for (var day in _mealPlan.keys) {
      for (var meal in _mealPlan[day]!.keys) {
        if (_mealPlan[day]![meal]!.isNotEmpty) {
          hasRecipes = true;
          break;
        }
      }
      if (hasRecipes) break;
    }

    if (!hasRecipes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add some recipes to your meal plan first'),
          backgroundColor: Color(0xFFFFB347),
        ),
      );
      return;
    }

    final Map<String, Recipe> nameToRecipe = {
      for (var r in _likedRecipes) r.title: r,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroceryGenerateScreen(
          mealPlan: _mealPlan,
          allRecipes: nameToRecipe,
        ),
      ),
    ).then((saved) {
      if (saved == true && mounted) {
        widget.onListGenerated?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Meal Plan',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6B4C2A),
                      ),
                    ),
                    Text(
                      '${_likedRecipes.length} liked recipes available',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFFC9A96E),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _clearAllPlan,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: Text(
                  'Clear All',
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFFFF0B5)),
        // Days list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _days.length,
            itemBuilder: (context, index) {
              final day = _days[index];
              final meals = _mealPlan[day]!;
              return _buildDayCard(day, meals);
            },
          ),
        ),
        // Generate button at bottom
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _generateFromPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB347),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Generate Shopping List',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(String day, Map<String, List<String>> meals) {
    int totalRecipes = 0;
    for (var meal in meals.keys) {
      totalRecipes += meals[meal]!.length;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6B4C2A),
                  ),
                ),
              ),
              if (totalRecipes > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB347).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalRecipes recipes',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: const Color(0xFFFFB347),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _clearDay(day),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: totalRecipes > 0 ? Colors.red.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.clear,
                    size: 16,
                    color: totalRecipes > 0 ? Colors.red : Colors.grey.shade300,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: _mealTypes.map((mealType) {
              final recipes = meals[mealType] ?? [];
              return Expanded(
                child: GestureDetector(
                  onTap: () => _showAddRecipeSheet(day, mealType),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: recipes.isNotEmpty ? const Color(0xFFFFF9E6) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: recipes.isNotEmpty ? const Color(0xFFFFB347) : Colors.grey.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          mealType,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: recipes.isNotEmpty ? const Color(0xFFFFB347) : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (recipes.isEmpty)
                          Text(
                            'Add',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                            ),
                          )
                        else
                          Column(
                            children: recipes.map((recipe) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.circle,
                                      size: 4,
                                      color: Color(0xFFFFB347),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        recipe,
                                        style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF6B4C2A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}