// lib/admin/admin_posts.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/admin_api_service.dart';
import 'admin_approval_detail.dart';

class AdminPostsScreen extends StatefulWidget {
  const AdminPostsScreen({super.key});

  @override
  State<AdminPostsScreen> createState() => _AdminPostsScreenState();
}

class _AdminPostsScreenState extends State<AdminPostsScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);

    final recipes = await AdminApiService.getRecipes();
    final ingredients = await AdminApiService.getIngredientPosts();

    final posts = <Map<String, dynamic>>[];

    for (final r in recipes) {
      final createdAt = (r['createdAt'] ?? '').toString();
      posts.add({
        'id': r['id'],
        'type': 'recipe',
        'title': r['title'] ?? '',
        'authorName': r['authorName'] ?? '',
        'authorAvatar': r['authorAvatar'] ?? '',
        'imageUrl': r['imageUrl'] ?? '',
        'description': r['description'] ?? '',
        'cuisineType': r['cuisineType'] ?? '',
        'difficultyLevel': r['difficultyLevel'] ?? '',
        'durationMinutes': r['durationMinutes'] ?? 0,
        'likes': r['likes'] ?? 0,
        'comments': r['comments'] ?? 0,
        'isApproved': r['isApproved'] ?? false,
        'createdAt':
            createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt,
        'ingredients': r['ingredients'] ?? [],
        'steps': r['steps'] ?? [],
        'dishes': r['dishes'] ?? [],
        'tags': r['tags'] ?? [],
        'cookingTools': r['cookingTools'] ?? [],
        'photoUrls': r['photoUrls'] ?? [],
        'videoUrl': r['videoUrl'] ?? '',
      });
    }

    for (final i in ingredients) {
      final createdAt = (i['createdAt'] ?? '').toString();
      posts.add({
        'id': i['id'],
        'type': 'ingredient',
        'title': i['title'] ?? '',
        'authorName': i['authorName'] ?? '',
        'authorAvatar': i['authorAvatar'] ?? '',
        'imageUrl': i['imageUrl'] ?? '',
        'description': i['description'] ?? i['content'] ?? '',
        'cuisineType': '',
        'difficultyLevel': '',
        'durationMinutes': 0,
        'likes': i['likes'] ?? 0,
        'comments': i['comments'] ?? 0,
        'isApproved': i['isApproved'] ?? false,
        'createdAt':
            createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt,
        'ingredients': i['ingredients'] ?? [],
        'steps': i['steps'] ?? [],
        'dishes': i['dishes'] ?? [],
        'tags': i['tags'] ?? [],
        'cookingTools': i['cookingTools'] ?? [],
        'photoUrls': i['photoUrls'] ?? [],
        'videoUrl': i['videoUrl'] ?? '',
      });
    }

    posts.sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));

    if (!mounted) return;
    setState(() {
      _posts = posts;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredPosts {
    var filtered = _posts.where((post) {
      if (_searchQuery.isEmpty) return true;
      final title = (post['title'] ?? '').toString().toLowerCase();
      final author = (post['authorName'] ?? '').toString().toLowerCase();
      final cuisine = (post['cuisineType'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      final tagsMatch = (post['tags'] as List?)?.any(
            (tag) => tag.toString().toLowerCase().contains(q),
          ) ??
          false;
      return title.contains(q) ||
          author.contains(q) ||
          cuisine.contains(q) ||
          tagsMatch;
    }).toList();

    if (_filterStatus == 'approved') {
      filtered = filtered.where((p) => p['isApproved'] == true).toList();
    } else if (_filterStatus == 'pending') {
      filtered = filtered.where((p) => p['isApproved'] == false).toList();
    }
    return filtered;
  }

  void _openApproval(Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminApprovalDetailScreen(
          pendingItem: post,
          onApproved: () {
            setState(() {
              final index = _posts.indexWhere((p) => p['id'] == post['id']);
              if (index != -1) {
                _posts[index]['isApproved'] = true;
              }
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Posts',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Manage and monitor all user posts',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFFC9A96E),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildStatBadge('Total', _posts.length,
                    const Color(0xFF6B4C2A), Icons.image),
                Container(width: 1, height: 30, color: const Color(0xFFF0F0F0)),
                _buildStatBadge(
                    'Approved',
                    _posts.where((p) => p['isApproved'] == true).length,
                    const Color(0xFF4CAF50),
                    Icons.check_circle),
                Container(width: 1, height: 30, color: const Color(0xFFF0F0F0)),
                _buildStatBadge(
                    'Pending',
                    _posts.where((p) => p['isApproved'] == false).length,
                    const Color(0xFFFF9800),
                    Icons.pending),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search by title, author, or tags...',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 14, color: const Color(0xFFC9A96E)),
                  prefixIcon: const Icon(Icons.search,
                      color: Color(0xFFC9A96E), size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              color: Color(0xFFC9A96E), size: 18),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButton<String>(
              value: _filterStatus,
              onChanged: (String? newValue) =>
                  setState(() => _filterStatus = newValue!),
              underline: const SizedBox.shrink(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B4C2A),
              ),
              items: ['all', 'approved', 'pending']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value[0].toUpperCase() + value.substring(1)),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      margin: const EdgeInsets.fromLTRB(32, 0, 32, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB347)),
            )
          : _filteredPosts.isEmpty
              ? _buildEmpty()
              : Table(
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: const Color(0xFFFFB347).withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  columnWidths: const {
                    0: FlexColumnWidth(3), // AUTHOR
                    1: FlexColumnWidth(5), // TITLE
                    2: FlexColumnWidth(2), // TYPE
                    3: FlexColumnWidth(1), // LIKES
                    4: FlexColumnWidth(1), // COMMENTS
                    5: FlexColumnWidth(2), // STATUS
                    6: FlexColumnWidth(2), // ACTIONS
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF9E6),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      children: [
                        _buildHeaderCell('AUTHOR'),
                        _buildHeaderCell('TITLE'),
                        _buildHeaderCell('TYPE'),
                        _buildHeaderCell('LIKES'),
                        _buildHeaderCell('COMMENTS'),
                        _buildHeaderCell('STATUS'),
                        _buildHeaderCell(''),
                      ],
                    ),
                    ..._filteredPosts.map((post) {
                      return TableRow(
                        children: [
                          _buildAuthorCell(post),
                          _buildTitleCell(post),
                          _buildTypeCell(post),
                          _buildLikesCell(post),
                          _buildCommentsCell(post),
                          _buildStatusCell(post),
                          _buildActionsCell(post),
                        ],
                      );
                    }).toList(),
                  ],
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image,
                size: 80,
                color: const Color(0xFFC9A96E).withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No posts found',
              style: GoogleFonts.poppins(
                  fontSize: 16, color: const Color(0xFFC9A96E)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6B4C2A),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildAuthorCell(Map<String, dynamic> post) {
    final authorName = (post['authorName'] ?? 'Unknown').toString();
    final authorAvatar = (post['authorAvatar'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFFFB347),
            backgroundImage:
                authorAvatar.isNotEmpty ? NetworkImage(authorAvatar) : null,
            child: authorAvatar.isEmpty
                ? Text(
                    authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              authorName,
              style: GoogleFonts.poppins(
                fontSize: 11,
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
  }

  Widget _buildTitleCell(Map<String, dynamic> post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        post['title'] ?? 'Untitled',
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF6B4C2A),
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTypeCell(Map<String, dynamic> post) {
    final type = post['type'] ?? 'recipe';
    final isRecipe = type == 'recipe';
    final color = isRecipe ? const Color(0xFFFF9800) : const Color(0xFF2196F3);
    final bgColor =
        isRecipe ? const Color(0xFFFFF3E0) : const Color(0xFFE3F2FD);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isRecipe ? Icons.restaurant : Icons.eco,
                  size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                isRecipe ? 'Recipe' : 'Ingredient',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLikesCell(Map<String, dynamic> post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: Text(
          '${post['likes'] ?? 0}',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFE91E63),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsCell(Map<String, dynamic> post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: Text(
          '${post['comments'] ?? 0}',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B4C2A),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCell(Map<String, dynamic> post) {
    final isApproved = post['isApproved'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color:
                isApproved ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isApproved ? 'Approved' : 'Pending',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isApproved
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFFF9800),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionsCell(Map<String, dynamic> post) {
    final isApproved = post['isApproved'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionIcon(
                icon: Icons.visibility_outlined,
                color: const Color(0xFF2196F3),
                bg: const Color(0xFFE3F2FD),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminApprovalDetailScreen(
                      pendingItem: post,
                      readOnly: true,
                      onApproved: () {},
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _actionIcon(
                icon: isApproved
                    ? Icons.edit_note
                    : Icons.rate_review_outlined,
                color: isApproved
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF9800),
                bg: isApproved
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFF3E0),
                onTap: () => _openApproval(post),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Widget _buildStatBadge(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.toString(),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: const Color(0xFFC9A96E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}