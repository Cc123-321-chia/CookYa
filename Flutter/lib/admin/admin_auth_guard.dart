// lib/admin/admin_auth_guard.dart
import 'package:flutter/material.dart';
import '../services/admin_api_service.dart';

/// Wraps admin pages that require authentication.
///
/// Behavior:
/// - If no token is stored, redirect to `/admin/login`.
/// - If a token exists but is invalid (API returns 401), clear it and
///   redirect to `/admin/login`.
/// - Otherwise render [child].
class AdminAuthGuard extends StatefulWidget {
  final Widget child;

  const AdminAuthGuard({super.key, required this.child});

  @override
  State<AdminAuthGuard> createState() => _AdminAuthGuardState();
}

class _AdminAuthGuardState extends State<AdminAuthGuard> {
  bool _checked = false;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    // Step 1: token present?
    final hasToken = await AdminApiService.isLoggedIn();
    if (!mounted) return;

    if (!hasToken) {
      await _redirectToLogin();
      return;
    }

    // Step 2: token still valid? getStats returns {} on 401.
    final stats = await AdminApiService.getStats();
    if (!mounted) return;

    if (stats.isEmpty) {
      await _redirectToLogin();
      return;
    }

    setState(() {
      _allowed = true;
      _checked = true;
    });
  }

  Future<void> _redirectToLogin() async {
    await AdminApiService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/admin/login');
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFB347)),
        ),
      );
    }
    if (!_allowed) {
      return const SizedBox.shrink();
    }
    return widget.child;
  }
}