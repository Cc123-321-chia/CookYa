// lib/admin/admin_users.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/admin_api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await AdminApiService.getUsers();
    if (!mounted) return;
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  List<_RoleTag> _rolesFor(Map<String, dynamic> user) {
    final roles = <_RoleTag>[];
    if (user['isOfficial'] == true) {
      roles.add(_RoleTag('Official', const Color(0xFF2196F3), Icons.verified));
    }
    if (user['isMentor'] == true) {
      roles.add(_RoleTag('Mentor', const Color(0xFFFF9800), Icons.star));
    }
    if (user['isExpert'] == true) {
      roles.add(_RoleTag('Expert', const Color(0xFF9C27B0), Icons.workspace_premium));
    }
    if (user['isCulinaryInstructor'] == true) {
      roles.add(_RoleTag('Instructor', const Color(0xFF4CAF50), Icons.school));
    }
    if (roles.isEmpty) {
      roles.add(_RoleTag('User', const Color(0xFF9E9E9E), Icons.person));
    }
    return roles;
  }

  List<Map<String, dynamic>> get _filteredUsers {
    var filtered = _users;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final name = (user['username'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }
    switch (_selectedFilter) {
      case 'Official':
        filtered = filtered.where((u) => u['isOfficial'] == true).toList();
        break;
      case 'Mentor':
        filtered = filtered.where((u) => u['isMentor'] == true).toList();
        break;
      case 'Expert':
        filtered = filtered.where((u) => u['isExpert'] == true).toList();
        break;
      case 'Instructor':
        filtered = filtered.where((u) => u['isCulinaryInstructor'] == true).toList();
        break;
      case 'User':
        filtered = filtered.where((u) =>
            u['isOfficial'] != true &&
            u['isMentor'] != true &&
            u['isExpert'] != true &&
            u['isCulinaryInstructor'] != true).toList();
        break;
      default:
        break;
    }
    return filtered;
  }

  void _viewUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
          child: _UserDetailDialog(user: user, roles: _rolesFor(user)),
        ),
      ),
    );
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete "${user['username']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF6B4C2A))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await AdminApiService.deleteUser(user['userId'].toString());
    if (!mounted) return;
    if (ok) {
      setState(() {
        _users.removeWhere((u) => u['userId'] == user['userId']);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted'), backgroundColor: Color(0xFFDC2626)),
      );
    }
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
                'Users',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Manage and monitor all registered users',
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
                _buildStatBadge('Total', _users.length, const Color(0xFF6B4C2A), Icons.people_outline),
                Container(width: 1, height: 30, color: const Color(0xFFF0F0F0)),
                _buildStatBadge('Mentors',
                    _users.where((u) => u['isMentor'] == true).length,
                    const Color(0xFFFFB347), Icons.star_outline),
                Container(width: 1, height: 30, color: const Color(0xFFF0F0F0)),
                _buildStatBadge('Experts',
                    _users.where((u) => u['isExpert'] == true).length,
                    const Color(0xFF9C27B0), Icons.workspace_premium),
                Container(width: 1, height: 30, color: const Color(0xFFF0F0F0)),
                _buildStatBadge('Instructors',
                    _users.where((u) => u['isCulinaryInstructor'] == true).length,
                    const Color(0xFF4CAF50), Icons.school),
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
                  hintText: 'Search by name or email...',
                  hintStyle: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFFC9A96E)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFC9A96E), size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFFC9A96E), size: 18),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
              value: _selectedFilter,
              onChanged: (String? newValue) => setState(() => _selectedFilter = newValue!),
              underline: const SizedBox.shrink(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B4C2A),
              ),
              items: ['All', 'Official', 'Mentor', 'Expert', 'Instructor', 'User']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFB347)))
          : _filteredUsers.isEmpty
              ? _buildEmpty()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // Table fills the available width.
                    return Table(
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: const Color(0xFFFFB347).withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(3),   // USER
                        1: FlexColumnWidth(3),   // EMAIL
                        2: FlexColumnWidth(3),   // ROLES
                        3: FlexColumnWidth(2),   // POINTS
                        4: FlexColumnWidth(1),   // ACTIONS
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF9E6),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          children: [
                            _buildHeaderCell('USER'),
                            _buildHeaderCell('EMAIL'),
                            _buildHeaderCell('ROLES'),
                            _buildHeaderCell('POINTS'),
                            _buildHeaderCell(''),
                          ],
                        ),
                        ..._filteredUsers.map((user) {
                          return TableRow(
                            children: [
                              _buildUserCell(user),
                              _buildEmailCell(user),
                              _buildRolesCell(user),
                              _buildPointsCell(user),
                              _buildActionsCell(user),
                            ],
                          );
                        }).toList(),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: const Color(0xFFC9A96E).withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: GoogleFonts.poppins(fontSize: 16, color: const Color(0xFFC9A96E)),
          ),
        ],
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

  Widget _buildUserCell(Map<String, dynamic> user) {
    final name = (user['username'] ?? 'Unknown').toString();
    final avatarUrl = (user['avatar'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFFFB347),
            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B4C2A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@${name.toLowerCase().replaceAll(' ', '')}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFFC9A96E),
                  ),
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

  Widget _buildEmailCell(Map<String, dynamic> user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        (user['email'] ?? '-').toString(),
        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B4C2A)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildRolesCell(Map<String, dynamic> user) {
    final roles = _rolesFor(user);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: roles.map((role) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: role.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(role.icon, size: 12, color: role.color),
                const SizedBox(width: 4),
                Text(
                  role.label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: role.color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Points cell:
  ///   [Lv 3]  ──  250 / 450 pts
  ///   ▓▓▓▓▓▓░░░░░░░░░
  /// Level on the left, current/next points on the right, progress bar below.
  /// Layout adapts to narrow widths to avoid overflow.
  Widget _buildPointsCell(Map<String, dynamic> user) {
    final points = (user['points'] ?? 0) as int;
    final level = (user['level'] ?? 1) as int;

    const thresholds = [0, 100, 250, 450, 700, 1000, 1350, 1750, 2500, 3500, 5000];

    final bool isMax = level >= thresholds.length;
    final int currentFloor = thresholds[level - 1];
    final int? nextLevel = isMax ? null : thresholds[level];

    double progress = 1;
    if (nextLevel != null) {
      progress = ((points - currentFloor) / (nextLevel - currentFloor)).clamp(0.0, 1.0);
    }

    final progressText = isMax ? '$points (MAX)' : '$points / $nextLevel';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // If the cell is very narrow, stack the level pill and points
          // vertically; otherwise show them on the same row.
          final bool isNarrow = constraints.maxWidth < 120;

          final levelPill = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB347).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFFB347).withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              'Lv $level',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF57C00),
                height: 1.2,
              ),
            ),
          );

          final progressTextWidget = Text(
            progressText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B4C2A),
            ),
          );

          final header = isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    levelPill,
                    const SizedBox(height: 4),
                    progressTextWidget,
                  ],
                )
              : Row(
                  children: [
                    levelPill,
                    const SizedBox(width: 8),
                    Expanded(child: progressTextWidget),
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              header,
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: const Color(0xFFF0EDE8),
                  color: const Color(0xFFFFB347),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionsCell(Map<String, dynamic> user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _actionIcon(
              icon: Icons.visibility_outlined,
              color: const Color(0xFF2196F3),
              bgColor: const Color(0xFFE3F2FD),
              onTap: () => _viewUserDetails(user),
            ),
            const SizedBox(width: 4),
            _actionIcon(
              icon: Icons.delete_outline,
              color: const Color(0xFFDC2626),
              bgColor: const Color(0xFFFEF2F2),
              onTap: () => _deleteUser(user),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: bgColor,
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

class _RoleTag {
  final String label;
  final Color color;
  final IconData icon;
  const _RoleTag(this.label, this.color, this.icon);
}

class _UserDetailDialog extends StatelessWidget {
  final Map<String, dynamic> user;
  final List<_RoleTag> roles;

  const _UserDetailDialog({required this.user, required this.roles});

  @override
  Widget build(BuildContext context) {
    final name = (user['username'] ?? 'Unknown').toString();
    final email = (user['email'] ?? '-').toString();
    final avatarUrl = (user['avatar'] ?? '').toString();
    final userId = (user['userId'] ?? '').toString();
    final points = (user['points'] ?? 0) as int;
    final level = (user['level'] ?? 1) as int;
    final recipeCount = (user['recipeCount'] ?? 0) as int;
    final ingredientCount = (user['ingredientCount'] ?? 0) as int;
    final followersCount = (user['followersCount'] ?? 0) as int;
    final followingCount = (user['followingCount'] ?? 0) as int;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: const Color(0xFFFFB347),
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6B4C2A),
                      ),
                    ),
                    Text(
                      email,
                      style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFC9A96E)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: roles.map((role) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: role.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(role.icon, size: 12, color: role.color),
                              const SizedBox(width: 4),
                              Text(
                                role.label,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: role.color,
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
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFFC9A96E)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF0F0F0)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statItem('Points', points.toString(), Icons.stars, const Color(0xFF4CAF50))),
              Expanded(child: _statItem('Level', level.toString(), Icons.trending_up, const Color(0xFFFF9800))),
              Expanded(child: _statItem('Recipes', recipeCount.toString(), Icons.restaurant, const Color(0xFF2196F3))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statItem('Ingredients', ingredientCount.toString(), Icons.eco, const Color(0xFF8BC34A))),
              Expanded(child: _statItem('Followers', followersCount.toString(), Icons.people, const Color(0xFFE91E63))),
              Expanded(child: _statItem('Following', followingCount.toString(), Icons.person_add, const Color(0xFF9C27B0))),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF0F0F0)),
          const SizedBox(height: 8),
          Text(
            'User ID: $userId',
            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFC9A96E)),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFFC9A96E)),
        ),
      ],
    );
  }
}