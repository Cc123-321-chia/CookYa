// screens/my_dishes_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/homework.dart';
import '../../services/api_service.dart';
import '../../utils/url_helper.dart';
import '../recipes/add_dish_post_screen.dart';

class MyDishesScreen extends StatefulWidget {
  final String? userId;
  const MyDishesScreen({super.key, this.userId});

  @override
  State<MyDishesScreen> createState() => _MyDishesScreenState();
}

class _MyDishesScreenState extends State<MyDishesScreen> {
  String _searchQuery = '';
  List<Homework> _allDishes = [];
  bool _isLoading = true;
  String? _errorMessage;

  bool get _isOwnProfile => widget.userId == null;

  // 三档评分（只用来显示）
  static const List<Map<String, dynamic>> _ratingOptions = [
    {
      'value': 'good',
      'label': 'Good',
      'icon': Icons.sentiment_very_satisfied,
      'color': Color(0xFF4CAF50),
    },
    {
      'value': 'ok',
      'label': 'OK',
      'icon': Icons.sentiment_neutral,
      'color': Color(0xFFFF9800),
    },
    {
      'value': 'bad',
      'label': 'Bad',
      'icon': Icons.sentiment_very_dissatisfied,
      'color': Color(0xFFF44336),
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchDishes();
  }

  // ==================== 数据获取 ====================
  Future<void> _fetchDishes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    Map<String, dynamic> result;
    if (widget.userId != null) {
      result = await ApiService.getUserHomeworks(widget.userId!);
    } else {
      result = await ApiService.getMyHomeworks();
    }

    if (!mounted) return;

    if (result['success'] == true) {
      final dynamic raw = result['data'];
      List<dynamic> list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'];
      }
      setState(() {
        _allDishes = list.map((j) => Homework.fromJson(j)).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Failed to load dishes';
        _isLoading = false;
      });
    }
  }

  List<Homework> get _filteredDishes {
    if (_searchQuery.isEmpty) return _allDishes;
    final q = _searchQuery.toLowerCase();
    return _allDishes
        .where((d) =>
            d.recipeTitle.toLowerCase().contains(q) ||
            d.review.toLowerCase().contains(q))
        .toList();
  }

  // ==================== 操作 ====================

  /// 🔥 打开 AddDishPostScreen（带旧数据），编辑完回来刷新
  Future<void> _editDish(Homework dish) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddDishPostScreen(
          recipeId: dish.recipeId,
          recipeTitle: dish.recipeTitle,
          // 🔥 编辑模式：传旧数据
          existingHomeworkId: dish.id,
          existingReview: dish.review,
          existingRating: dish.rating,
          existingImageUrl: dish.imageUrl,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      // 重新拉数据（最简单的刷新方式）
      _fetchDishes();
      _showSnack('Dish updated', isError: false);
    }
  }

  Future<void> _deleteDish(Homework dish) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9E6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Dish?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        content: Text(
          'Are you sure you want to delete this dish? This action cannot be undone.',
          style: GoogleFonts.poppins(
              fontSize: 13, color: const Color(0xFF6B4C2A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style:
                    GoogleFonts.poppins(color: const Color(0xFFC9A96E))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.poppins(
                    color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ApiService.deleteHomework(dish.id);
    if (!mounted) return;

    if (result['success'] == true) {
      setState(() => _allDishes.removeWhere((d) => d.id == dish.id));
      _showSnack('Dish deleted', isError: false);
    } else {
      _showSnack(result['error'] ?? 'Failed to delete', isError: true);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // ==================== Build ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          widget.userId == null ? 'My Dishes' : 'Dishes',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF6B4C2A),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _fetchDishes,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search your dishes...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFFFFB347)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFB347)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 64, color: Color(0xFFFFB347)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: GoogleFonts.poppins(color: const Color(0xFF6B4C2A)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchDishes,
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

    if (_filteredDishes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.kitchen, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty ? 'No dishes yet' : 'No dishes found',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDishes,
      color: const Color(0xFFFFB347),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredDishes.length,
        itemBuilder: (_, i) => _buildDishCard(_filteredDishes[i]),
      ),
    );
  }

  Widget _buildDishCard(Homework dish) {
    final avatarUrl = UrlHelper.fixUrl(dish.userAvatar);
    final dishImage = UrlHelper.fixUrl(dish.imageUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部：Recipe Title + 菜单
          Row(
            children: [
              Expanded(
                child: Text(
                  dish.recipeTitle.isNotEmpty ? dish.recipeTitle : 'Dish',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B4C2A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isOwnProfile) _buildPopupMenu(dish),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头像
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD966),
                  image: avatarUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.person,
                        size: 20, color: Color(0xFF6B4C2A))
                    : null,
              ),
              const SizedBox(width: 10),

              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dish.review.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          dish.review,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFFC9A96E),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (dishImage.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          dishImage,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            color: const Color(0xFFFFF0B5),
                            child: const Icon(
                              Icons.restaurant,
                              size: 40,
                              color: Color(0xFFFFD966),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // 🔥 Rating 列（只显示，不能点）
              Column(
                children: [
                  for (int i = 0; i < _ratingOptions.length; i++) ...[
                    _buildRatingDisplay(
                      icon: _ratingOptions[i]['icon'] as IconData,
                      type: _ratingOptions[i]['value'] as String,
                      dish: dish,
                      color: _ratingOptions[i]['color'] as Color,
                    ),
                    if (i < _ratingOptions.length - 1)
                      const SizedBox(height: 6),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 🔥 纯显示，无 onTap
  Widget _buildRatingDisplay({
    required IconData icon,
    required String type,
    required Homework dish,
    required Color color,
  }) {
    final isSelected = dish.rating == type;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isSelected
            ? color.withValues(alpha: 0.18)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? color : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: isSelected ? 24 : 20,
          color: isSelected ? color : Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildPopupMenu(Homework dish) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFFC9A96E)),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'edit') {
          _editDish(dish);       // 🔥 打开 AddDishPostScreen
        } else if (value == 'delete') {
          _deleteDish(dish);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit_outlined,
                  size: 18, color: Color(0xFF6B4C2A)),
              const SizedBox(width: 8),
              Text('Edit',
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF6B4C2A))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              const SizedBox(width: 8),
              Text('Delete',
                  style: GoogleFonts.poppins(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }
}