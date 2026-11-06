// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import '../widgets/recipe_card.dart';
import '../models/recipe.dart';
import '../models/carousel_item.dart';
import 'carousel_search_result_screen.dart';
import 'recipes/post_detail_screen.dart';
import 'search/filter_screen.dart' as filter;
import 'search/filter_results_screen.dart' as filter_result;
import 'search/search_screen.dart';
import 'mentor-mentee/mentor_screen.dart';
import 'recipes/add_post/add_post_screen.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'groceries/grocery_screen.dart';
import 'booking/booking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Current filter conditions
  Map<String, dynamic> _currentFilters = {};

  // Recipes from API
  List<Recipe> _recipes = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Carousel related
  late PageController _pageController;
  int _currentCarouselIndex = 0;
  Timer? _carouselTimer;
  final double _viewportFraction = 0.82;

  // 🔥 Carousel items from API (no local fallback)
  List<CarouselItem> _carouselItems = [];
  bool _isCarouselLoading = true;

  // 🔥 删除 _getLocalCarouselItems() 方法

  // 🔥 获取轮播图 - 只从 API 获取
  Future<void> _fetchCarouselItems() async {
    try {
      final items = await ApiService.getCarouselItems();
      print('🔥 Carousel items from API: ${items.length}');

      setState(() {
        _carouselItems = items;
        _isCarouselLoading = false;
      });
    } catch (e) {
      print('🔥 Carousel error: $e');
      setState(() {
        _carouselItems = [];
        _isCarouselLoading = false;
      });
    }
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    if (_carouselItems.isEmpty) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients && _carouselItems.isNotEmpty) {
        int nextPage = _currentCarouselIndex + 1;
        if (nextPage >= _carouselItems.length) {
          nextPage = 0;
        }
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _stopCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = null;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: _viewportFraction,
    );
    _fetchCarouselItems();
    _fetchRecipes();
  }

  @override
  void dispose() {
    _stopCarouselTimer();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecipes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = ApiService.authToken;

      final baseUrl = ApiService.baseUrl;

      var url = Uri.parse('$baseUrl/recipes/');

      final queryParams = <String, String>{};
      if (_currentFilters['cuisine'] != null) {
        final cuisineValue = _currentFilters['cuisine'];
        if (cuisineValue is List && cuisineValue.isNotEmpty) {
          queryParams['cuisine'] = cuisineValue.join(',');
        } else if (cuisineValue is String && cuisineValue.isNotEmpty) {
          queryParams['cuisine'] = cuisineValue;
        }
      }
      if (_currentFilters['difficulty'] != null) {
        queryParams['difficulty'] = _currentFilters['difficulty'].toString();
      }
      if (_currentFilters['duration'] != null) {
        queryParams['max_duration'] = _currentFilters['duration'].toString();
      }
      if (_currentFilters['ingredients'] != null && (_currentFilters['ingredients'] as List).isNotEmpty) {
        queryParams['ingredients'] = (_currentFilters['ingredients'] as List).join(',');
      }
      if (_currentFilters['tools'] != null && (_currentFilters['tools'] as List).isNotEmpty) {
        queryParams['tools'] = (_currentFilters['tools'] as List).join(',');
      }

      if (queryParams.isNotEmpty) {
        url = url.replace(queryParameters: queryParams);
      }

      final response = await http.get(
        url,
        headers: token != null ? {'Authorization': 'Token $token'} : {},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _recipes = data.map((json) => Recipe.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load recipes: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error. Make sure the backend server is running.';
        _isLoading = false;
      });
    }
  }

  void _applyFilters(Map<String, dynamic> filters) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => filter_result.FilterResultsScreen(
          filters: filters,
        ),
      ),
    );
  }

  int _getFilterCount() {
    int count = 0;
    if (_currentFilters['cuisine'] != null &&
        _currentFilters['cuisine'].toString().isNotEmpty) {
      count++;
    }
    if (_currentFilters['ingredients'] != null &&
        (_currentFilters['ingredients'] as List).isNotEmpty) {
      count++;
    }
    if (_currentFilters['duration'] != null) {
      count++;
    }
    if (_currentFilters['difficulty'] != null) {
      count++;
    }
    if (_currentFilters['tools'] != null &&
        (_currentFilters['tools'] as List).isNotEmpty) {
      count++;
    }
    return count;
  }

  // 🔥 构建轮播图 Item
  Widget _buildCarouselItem(CarouselItem item) {
    final tagDisplay = item.tags.isNotEmpty ? item.tags.join(' · ') : '';

    return GestureDetector(
      onTap: () {
        if (item.tags.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CarouselSearchResultScreen(
                keywords: item.tags,
                title: item.title,
              ),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.imageUrl.isNotEmpty)
                Image.network(
                  ApiService.resolveImageUrl(item.imageUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFFFFB347),
                      child: Center(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  color: const Color(0xFFFFB347),
                  child: Center(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(offset: Offset(1, 1), blurRadius: 3, color: Color.fromRGBO(0, 0, 0, 0.38))
                        ],
                      ),
                    ),
                    if (tagDisplay.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        tagDisplay,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(offset: Offset(0.5, 0.5), blurRadius: 2, color: Color.fromRGBO(0, 0, 0, 0.38))
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 轮播图加载完成后启动计时器
    if (!_isCarouselLoading && _carouselItems.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startCarouselTimer();
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Search bar + Filter button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SearchScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search,
                                  color: Color(0xFFFFB347), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Search for recipes...',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: IconButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => filter.FilterScreen(
                                onApply: _applyFilters,
                                currentFilters: _currentFilters,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.tune, color: Color(0xFFFFB347)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Filter status bar
            if (_currentFilters.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_alt,
                          size: 14, color: Color(0xFFFFB347)),
                      const SizedBox(width: 4),
                      Text(
                        '${_getFilterCount()} filters applied',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          _applyFilters({});
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                        ),
                        child: const Text(
                          'Clear all',
                          style: TextStyle(fontSize: 12, color: Color(0xFFFFB347)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 🔥 Auto-scrolling carousel (from API only)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  if (_isCarouselLoading)
                    SizedBox(
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: Color(0xFFFFB347),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Loading carousel...',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_carouselItems.isEmpty)
                    const SizedBox(
                      height: 200,
                      child: Center(
                        child: Text(
                          'No carousel items available',
                          style: TextStyle(
                            color: Color(0xFFC9A96E),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    SizedBox(
                      height: 200,
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            scrollDirection: Axis.horizontal,
                            itemCount: _carouselItems.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentCarouselIndex = index;
                              });
                              _stopCarouselTimer();
                              _startCarouselTimer();
                            },
                            itemBuilder: (context, index) {
                              final item = _carouselItems[index];
                              return _buildCarouselItem(item);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_carouselItems.length, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          width: _currentCarouselIndex == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentCarouselIndex == index
                                ? const Color(0xFFFFB347)
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Five buttons - 2+3 layout
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    // First row: 2 buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernButton(
                            icon: Icons.school_outlined,
                            label: 'Find a Mentor',
                            color: const Color(0xFF6C5CE7),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const MentorScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModernButton(
                            icon: Icons.search_rounded,
                            label: 'Find a Recipe',
                            color: const Color(0xFFFFB347),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => filter.FilterScreen(
                                    onApply: _applyFilters,
                                    currentFilters: _currentFilters,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Second row: 3 buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernButton(
                            icon: Icons.add_photo_alternate_outlined,
                            label: 'Share Recipe',
                            color: const Color(0xFF00B894),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const AddPostScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModernButton(
                            icon: Icons.event_available,
                            label: 'Book a Class',
                            color: const Color(0xFFE74C3C),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const BookingScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModernButton(
                            icon: Icons.shopping_cart,
                            label: 'Groceries',
                            color: const Color(0xFF3498DB),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const GroceryScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Recommended Recipes title
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.favorite, color: Color(0xFFFFB347), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Recommended Recipes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 4)),

            // Loading state
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFFFFB347),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading recipes...',
                        style: TextStyle(
                          color: Color(0xFFC9A96E),
                        ),
                      ),
                    ],
                  ),
                ),
              )

            // Error state
            else if (_errorMessage != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Color(0xFFFFB347),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFF6B4C2A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchRecipes,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFFFD966),
                          foregroundColor: Color(0xFF6B4C2A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )

            // Empty state
            else if (_recipes.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant,
                          size: 64,
                          color: Color(0xFFFFB347),
                        ),
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
                          'Try adjusting your filters or add a new recipe',
                          style: TextStyle(
                            color: Color(0xFFC9A96E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )

            // Recipe grid
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 280,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return RecipeCard(
                        recipe: _recipes[index],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostDetailScreen(
                                recipeId: _recipes[index].id,
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: _recipes.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  // Modern button design
  Widget _buildModernButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}