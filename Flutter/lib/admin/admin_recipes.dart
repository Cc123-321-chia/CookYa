// lib/admin/admin_recipes.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/admin_api_service.dart';
import 'admin_approval_detail.dart';

class AdminRecipesScreen extends StatefulWidget {
  const AdminRecipesScreen({super.key});

  @override
  State<AdminRecipesScreen> createState() => _AdminRecipesScreenState();
}

class _AdminRecipesScreenState extends State<AdminRecipesScreen> {
  List<Map<String, dynamic>> _recipes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);
    final recipes = await AdminApiService.getRecipes();
    if (!mounted) return;
    setState(() {
      _recipes = recipes;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredRecipes {
    var filtered = _recipes.where((recipe) {
      if (_searchQuery.isEmpty) return true;
      final title = (recipe['title'] ?? '').toString().toLowerCase();
      final author = (recipe['authorName'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return title.contains(q) || author.contains(q);
    }).toList();

    if (_filterStatus == 'approved') {
      filtered = filtered.where((r) => r['isApproved'] == true).toList();
    } else if (_filterStatus == 'pending') {
      filtered = filtered.where((r) => r['isApproved'] == false).toList();
    }
    return filtered;
  }

  void _viewRecipeDetails(Map<String, dynamic> recipe) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: _RecipeDetailDialog(recipe: recipe),
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
                'Recipes',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Manage and monitor all recipes',
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
                _buildStatBadge('Total', _recipes.length,
                    const Color(0xFF6B4C2A), Icons.restaurant),
                Container(width: 1, height: 30, color: const Color(0xFFF0F0F0)),
                _buildStatBadge(
                    'Approved',
                    _recipes.where((r) => r['isApproved'] == true).length,
                    const Color(0xFF4CAF50),
                    Icons.check_circle),
                Container(width: 1, height: 30, color: const Color(0xFFF0F0F0)),
                _buildStatBadge(
                    'Pending',
                    _recipes.where((r) => r['isApproved'] == false).length,
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
                  hintText: 'Search by recipe or author...',
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
              onChanged: (v) => setState(() => _filterStatus = v!),
              underline: const SizedBox.shrink(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B4C2A),
              ),
              items: ['all', 'approved', 'pending']
                  .map<DropdownMenuItem<String>>((v) {
                return DropdownMenuItem<String>(
                  value: v,
                  child: Text(v[0].toUpperCase() + v.substring(1)),
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
          : _filteredRecipes.isEmpty
              ? _buildEmpty()
              : Table(
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: const Color(0xFFFFB347).withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  columnWidths: const {
                    0: FlexColumnWidth(4), // RECIPE
                    1: FlexColumnWidth(3), // AUTHOR
                    2: FlexColumnWidth(2), // CREATED
                    3: FlexColumnWidth(2), // LIKES
                    4: FlexColumnWidth(2), // COMMENTS
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
                        _buildHeaderCell('RECIPE'),
                        _buildHeaderCell('AUTHOR'),
                        _buildHeaderCell('CREATED'),
                        _buildHeaderCell('LIKES'),
                        _buildHeaderCell('COMMENTS'),
                        _buildHeaderCell('STATUS'),
                        _buildHeaderCell(''),
                      ],
                    ),
                    ..._filteredRecipes.map((r) {
                      return TableRow(
                        children: [
                          _buildRecipeCell(r),
                          _buildAuthorCell(r),
                          _buildCreatedCell(r),
                          _buildLikesCell(r),
                          _buildCommentsCell(r),
                          _buildStatusCell(r),
                          _buildActionsCell(r),
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
          children: [
            Icon(Icons.restaurant,
                size: 80,
                color: const Color(0xFFC9A96E).withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No recipes found',
                style: GoogleFonts.poppins(
                    fontSize: 16, color: const Color(0xFFC9A96E))),
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
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6B4C2A),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildRecipeCell(Map<String, dynamic> r) {
    final imageUrl = (r['imageUrl'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFFFFB347).withValues(alpha: 0.2),
              image: imageUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(imageUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: imageUrl.isEmpty
                ? const Icon(Icons.restaurant, size: 20, color: Color(0xFFFFB347))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  r['title'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B4C2A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  (r['cuisineType'] ?? '').toString().isNotEmpty
                      ? r['cuisineType']
                      : 'Unknown Cuisine',
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: const Color(0xFFC9A96E)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorCell(Map<String, dynamic> r) {
    final name = (r['authorName'] ?? 'Unknown').toString();
    final avatar = (r['authorAvatar'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFFFB347),
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: const Color(0xFF6B4C2A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatedCell(Map<String, dynamic> r) {
    final date = (r['createdAt'] ?? '').toString();
    final display = date.length >= 10 ? date.substring(0, 10) : date;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        display,
        style: GoogleFonts.poppins(
            fontSize: 12, color: const Color(0xFFC9A96E)),
      ),
    );
  }

  Widget _buildLikesCell(Map<String, dynamic> r) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite, size: 14, color: Color(0xFFE91E63)),
          const SizedBox(width: 4),
          Text(
            '${r['likes'] ?? 0}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B4C2A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsCell(Map<String, dynamic> r) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.comment, size: 14, color: Color(0xFF2196F3)),
          const SizedBox(width: 4),
          Text(
            '${r['comments'] ?? 0}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B4C2A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCell(Map<String, dynamic> r) {
    final isApproved = r['isApproved'] == true;
    final color = isApproved
        ? const Color(0xFF4CAF50)
        : const Color(0xFFFF9800);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isApproved ? 'Approved' : 'Pending',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionsCell(Map<String, dynamic> r) {
    final isApproved = r['isApproved'] == true;
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
                      pendingItem: {...r, 'type': 'recipe'},
                      readOnly: true,
                      onApproved: () {},
                    ),
                  ),
                ),
              ),
              if (!isApproved) ...[
                const SizedBox(width: 4),
                _actionIcon(
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF4CAF50),
                  bg: const Color(0xFFE8F5E9),
                  onTap: () async {
                    final ok = await AdminApiService.approveRecipe(
                        r['id'].toString());
                    if (!mounted) return;
                    if (ok) {
                      setState(() {
                        final i =
                            _recipes.indexWhere((x) => x['id'] == r['id']);
                        if (i != -1) {
                          _recipes[i] = Map<String, dynamic>.from(_recipes[i]);
                          _recipes[i]['isApproved'] = true;
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Recipe approved!'),
                          backgroundColor: Color(0xFF4CAF50),
                        ),
                      );
                    }
                  },
                ),
              ],
              const SizedBox(width: 4),
              _actionIcon(
                icon: Icons.delete_outline,
                color: const Color(0xFFDC2626),
                bg: const Color(0xFFFEF2F2),
                onTap: () => _confirmDelete(r),
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

  Future<void> _confirmDelete(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Recipe'),
        content: Text('Delete "${r['title']}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: const Color(0xFF6B4C2A))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final deleted =
        await AdminApiService.deleteRecipe(r['id'].toString());
    if (!mounted) return;
    if (deleted) {
      setState(() => _recipes.removeWhere((x) => x['id'] == r['id']));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recipe deleted'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
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
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: const Color(0xFFC9A96E))),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecipeDetailDialog extends StatelessWidget {
  final Map<String, dynamic> recipe;
  const _RecipeDetailDialog({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final imageUrl = (recipe['imageUrl'] ?? '').toString();
    final author = (recipe['authorName'] ?? 'Unknown').toString();
    final authorAvatar = (recipe['authorAvatar'] ?? '').toString();
    final isApproved = recipe['isApproved'] == true;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    recipe['title'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6B4C2A),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isApproved
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isApproved ? 'Approved' : 'Pending',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isApproved
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFF9800),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(imageUrl, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFFFB347),
                  backgroundImage:
                      authorAvatar.isNotEmpty ? NetworkImage(authorAvatar) : null,
                  child: authorAvatar.isEmpty
                      ? Text(
                          author.isNotEmpty ? author[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(author,
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            if ((recipe['description'] ?? '').toString().isNotEmpty)
              Text(
                recipe['description'].toString(),
                style: GoogleFonts.poppins(
                    fontSize: 13, height: 1.6, color: const Color(0xFF4A3728)),
              ),
          ],
        ),
      ),
    );
  }
}