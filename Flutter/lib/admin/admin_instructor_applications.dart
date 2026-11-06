// lib/admin/admin_instructor_applications.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/admin_api_service.dart';
import 'admin_instructor_application_detail.dart';

class AdminInstructorApplicationsScreen extends StatefulWidget {
  const AdminInstructorApplicationsScreen({super.key});

  @override
  State<AdminInstructorApplicationsScreen> createState() =>
      _AdminInstructorApplicationsScreenState();
}

class _AdminInstructorApplicationsScreenState
    extends State<AdminInstructorApplicationsScreen> {
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    final data = await AdminApiService.getInstructorApplications(
      status: _filterStatus,
    );
    if (!mounted) return;
    setState(() {
      _applications = data;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredApplications {
    if (_searchQuery.isEmpty) return _applications;
    return _applications.where((a) {
      final shop = (a['shop_name'] ?? '').toString().toLowerCase();
      final user = (a['username'] ?? '').toString().toLowerCase();
      final email = (a['email'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return shop.contains(q) || user.contains(q) || email.contains(q);
    }).toList();
  }

  void _openDetail(Map<String, dynamic> application) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminInstructorApplicationDetailScreen(
          applicationId: application['id'].toString(),
        ),
      ),
    );
    if (result == true) {
      _loadApplications();
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Instructor Applications',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6B4C2A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Review and approve culinary instructor applications',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFFC9A96E),
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
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search by shop, user, or email...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFFC9A96E),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFFC9A96E),
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFFC9A96E),
                            size: 18,
                          ),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
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
              onChanged: (v) {
                setState(() => _filterStatus = v!);
                _loadApplications();
              },
              underline: const SizedBox.shrink(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B4C2A),
              ),
              items: ['all', 'pending', 'approved', 'rejected']
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
          : _filteredApplications.isEmpty
              ? _buildEmpty()
              : Table(
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: const Color(0xFFFFB347).withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  columnWidths: const {
                    0: FlexColumnWidth(3), // SHOP
                    1: FlexColumnWidth(3), // USER
                    2: FlexColumnWidth(3), // EMAIL
                    3: FlexColumnWidth(2), // APPLIED
                    4: FlexColumnWidth(2), // STATUS
                    5: FlexColumnWidth(1), // ACTIONS
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF9E6),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      children: [
                        _buildHeaderCell('SHOP'),
                        _buildHeaderCell('USER'),
                        _buildHeaderCell('EMAIL'),
                        _buildHeaderCell('APPLIED'),
                        _buildHeaderCell('STATUS'),
                        _buildHeaderCell(''),
                      ],
                    ),
                    ..._filteredApplications.map((a) {
                      return TableRow(
                        children: [
                          _buildShopCell(a),
                          _buildUserCell(a),
                          _buildEmailCell(a),
                          _buildAppliedCell(a),
                          _buildStatusCell(a),
                          _buildActionsCell(a),
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
            Icon(
              Icons.assignment_outlined,
              size: 80,
              color: const Color(0xFFC9A96E).withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No applications found',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: const Color(0xFFC9A96E),
              ),
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
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6B4C2A),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildShopCell(Map<String, dynamic> a) {
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
              image: a['avatar'] != null && a['avatar'].toString().isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(a['avatar']),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: a['avatar'] == null || a['avatar'].toString().isEmpty
                ? const Icon(Icons.store, color: Color(0xFFFFB347))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              a['shop_name'] ?? '-',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
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

  Widget _buildUserCell(Map<String, dynamic> a) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFB347),
            ),
            child: ClipOval(
              child: a['user_avatar'] != null &&
                      a['user_avatar'].toString().isNotEmpty
                  ? Image.network(a['user_avatar'], fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        (a['username'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              a['username'] ?? '-',
              style: GoogleFonts.poppins(
                fontSize: 12,
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

  Widget _buildEmailCell(Map<String, dynamic> a) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        a['email'] ?? '-',
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: const Color(0xFF6B4C2A),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildAppliedCell(Map<String, dynamic> a) {
    final applied = (a['applied_at'] ?? '').toString();
    final display = applied.length >= 10 ? applied.substring(0, 10) : applied;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        display,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: const Color(0xFFC9A96E),
        ),
      ),
    );
  }

  Widget _buildStatusCell(Map<String, dynamic> a) {
    final status = (a['status'] ?? 'pending').toString();
    Color color;
    switch (status) {
      case 'approved':
        color = const Color(0xFF4CAF50);
        break;
      case 'rejected':
        color = const Color(0xFFDC2626);
        break;
      default:
        color = const Color(0xFFFF9800);
    }
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
            status[0].toUpperCase() + status.substring(1),
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

  Widget _buildActionsCell(Map<String, dynamic> a) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: GestureDetector(
          onTap: () => _openDetail(a),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.visibility_outlined,
              size: 16,
              color: Color(0xFF2196F3),
            ),
          ),
        ),
      ),
    );
  }
}