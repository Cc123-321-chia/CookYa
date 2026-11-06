// lib/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/admin_api_service.dart';
import 'admin_users.dart';
import 'admin_recipes.dart';
import 'admin_ingredients.dart';
import 'admin_posts.dart';
import 'admin_admins.dart';
import 'admin_upload_poster.dart';
import 'admin_approval_detail.dart';
import 'admin_instructor_applications.dart';
import 'admin_reports_screen.dart';
import 'admin_refunds_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard, 'label': 'Dashboard'},
    {'icon': Icons.people, 'label': 'Users'},
    {'icon': Icons.restaurant, 'label': 'Recipes'},
    {'icon': Icons.eco, 'label': 'Ingredients'},
    {'icon': Icons.image, 'label': 'User Posts'},
    {'icon': Icons.admin_panel_settings, 'label': 'Admins'},
    {'icon': Icons.wallpaper, 'label': 'Upload Poster'},
    {'icon': Icons.assignment_ind, 'label': 'Instructor Apps'},
    {'icon': Icons.flag, 'label': 'Reports'},
    {'icon': Icons.assignment_return, 'label': 'Refunds'},
  ];

  final List<Widget> _screens = [
    const DashboardContent(),
    const AdminUsersScreen(),
    const AdminRecipesScreen(),
    const AdminIngredientsScreen(),
    const AdminPostsScreen(),
    const AdminAdminsScreen(),
    const AdminUploadPosterScreen(),
    const AdminInstructorApplicationsScreen(),
    const AdminReportsScreen(),
    const AdminRefundsScreen(),
  ];

  Future<void> _onLogout() async {
    await AdminApiService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/admin/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      color: Colors.white,
      child: Column(
        children: [
          _buildBrand(),
          const Divider(color: Color(0xFFEEEEEE), thickness: 1),
          Expanded(child: _buildMenu()),
          _buildAccountFooter(),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text(
            'CookYa',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              foreground: Paint()
                ..shader = const LinearGradient(
                  colors: [Color(0xFFFFB347), Color(0xFFFF8C00)],
                ).createShader(const Rect.fromLTWH(0, 0, 150, 40)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Admin Panel',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFFC9A96E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _menuItems.length,
      itemBuilder: (context, index) {
        final item = _menuItems[index];
        final isSelected = _selectedIndex == index;
        return InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFFB347).withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  item['icon'] as IconData,
                  size: 20,
                  color: isSelected
                      ? const Color(0xFFFFB347)
                      : const Color(0xFF9E9E9E),
                ),
                const SizedBox(width: 14),
                Text(
                  item['label'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w500 : FontWeight.normal,
                    color: isSelected
                        ? const Color(0xFFFFB347)
                        : const Color(0xFF6B4C2A),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Sidebar footer: shows the currently logged-in admin.
  Widget _buildAccountFooter() {
    final name = AdminApiService.adminName ?? 'Admin';
    final email = AdminApiService.adminEmail ?? '';
    final role = AdminApiService.adminRole ?? '';
    final roleLabel = role == 'super_admin' ? 'Super Admin' : 'Moderator';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFFFB347),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'A',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B4C2A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFFC9A96E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  roleLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _onLogout,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.logout,
                  size: 18, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard content
// ---------------------------------------------------------------------------

class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _pendingApprovals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Auth is already enforced by AdminAuthGuard, so just load data.
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await AdminApiService.getStats();
      final pending = await AdminApiService.getPendingApprovals();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _pendingApprovals = pending;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Dashboard error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getCurrentDateTime() {
    final now = DateTime.now();
    return '${_getWeekday(now.weekday)}, ${now.day} ${_getMonth(now.month)} ${now.year}';
  }

  String _getWeekday(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }

  String _getMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFB347)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6B4C2A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _getCurrentDateTime(),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFFC9A96E),
            ),
          ),
          const SizedBox(height: 28),
          _buildTopStatsRow(),
          const SizedBox(height: 28),
          _buildTodayActivityCard(),
          const SizedBox(height: 28),
          _buildPendingApprovalsCard(),
        ],
      ),
    );
  }

  Widget _buildTopStatsRow() {
    return Row(
      children: [
        _buildSmallStatCard('Users', _stats['totalUsers'] ?? 0, Icons.people,
            const Color(0xFF4CAF50)),
        const SizedBox(width: 16),
        _buildSmallStatCard('Recipes', _stats['totalRecipes'] ?? 0,
            Icons.restaurant, const Color(0xFFFF9800)),
        const SizedBox(width: 16),
        _buildSmallStatCard('Ingredients', _stats['totalIngredients'] ?? 0,
            Icons.eco, const Color(0xFF2196F3)),
        const SizedBox(width: 16),
        _buildSmallStatCard('Posts', _stats['totalPosts'] ?? 0, Icons.image,
            const Color(0xFFE91E63)),
      ],
    );
  }

  Widget _buildTodayActivityCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Activity",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B4C2A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSmallTodayCard('New Users', _stats['newUsersToday'] ?? 0,
                  Icons.person_add, const Color(0xFF4CAF50)),
              const SizedBox(width: 16),
              _buildSmallTodayCard('New Recipes', _stats['newRecipesToday'] ?? 0,
                  Icons.add_circle, const Color(0xFFFF9800)),
              const SizedBox(width: 16),
              _buildSmallTodayCard('New Posts', _stats['newPostsToday'] ?? 0,
                  Icons.comment, const Color(0xFFE91E63)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Pending Approvals',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed:
                    _pendingApprovals.isEmpty ? null : _openPendingApprovals,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFFB347),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFFFFB347)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_pendingApprovals.isEmpty)
            _buildEmptyPending()
          else
            ..._pendingApprovals.take(3).map(_buildPendingItem),
          if (_pendingApprovals.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  '+${_pendingApprovals.length - 3} more items',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFFC9A96E),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyPending() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'All clear! No pending approvals.',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  void _openPendingApprovals() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminApprovalDetailScreen(
          pendingItems: _pendingApprovals,
          onApproved: _loadData,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
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
      child: child,
    );
  }

  Widget _buildSmallStatCard(
      String title, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6B4C2A),
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFFC9A96E),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallTodayCard(
      String title, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6B4C2A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: const Color(0xFFC9A96E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingItem(Map<String, dynamic> item) {
    final config =
        _pendingTypeConfig[item['type']] ?? _pendingTypeConfig['recipe']!;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminApprovalDetailScreen(
              pendingItem: item,
              onApproved: _loadData,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: config['bgColor'] as Color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                config['icon'] as IconData,
                color: config['color'] as Color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? 'Untitled',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: const Color(0xFF6B4C2A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'By ${item['authorName'] ?? 'Unknown'} • ${_formatDate(item['createdAt'])}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFFC9A96E),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                config['label'] as String,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: config['color'] as Color,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(0xFFC9A96E),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Recently';
    try {
      final dt = DateTime.parse(date.toString());
      final now = DateTime.now();
      final difference = now.difference(dt);
      if (difference.inDays > 7) {
        return '${dt.day}/${dt.month}/${dt.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inMinutes}m ago';
      }
    } catch (_) {
      return 'Recently';
    }
  }
}

// Static configuration for pending-approval item types.
const Map<String, Map<String, dynamic>> _pendingTypeConfig = {
  'recipe': {
    'icon': Icons.restaurant,
    'color': Color(0xFFFF9800),
    'bgColor': Color(0xFFFFF3E0),
    'label': 'Recipe',
  },
  'ingredient': {
    'icon': Icons.eco,
    'color': Color(0xFF2196F3),
    'bgColor': Color(0xFFE3F2FD),
    'label': 'Ingredient',
  },
};