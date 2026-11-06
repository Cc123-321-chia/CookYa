import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'ingredient/ingredients_screen.dart';
import 'recipes/add_post/add_post_screen.dart';
import 'mentor-mentee/notifications_screen.dart';
import 'profile/profile_screen.dart';
import '../services/api_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  int _totalUnread = 0;

  final List<Widget> _screens = [
    HomeScreen(),
    IngredientsScreen(),
    SizedBox.shrink(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _refreshUnread();
  }

  Future<void> _refreshUnread() async {
    int total = 0;

    // 系统通知未读
    final sysRes = await ApiService.getSystemNotifications();
    if (sysRes['success'] == true) {
      final u = sysRes['unread_count'];
      total += (u is int) ? u : 0;
    }

    // 聊天未读
    final convRes = await ApiService.getConversations();
    if (convRes['success'] == true) {
      final list = (convRes['data'] as List?) ?? [];
      for (final item in list) {
        final u = item['unread_count'];
        total += (u is int) ? u : 0;
      }
    }

    if (mounted) setState(() => _totalUnread = total);
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AddPostScreen(),
        ),
      );
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
    // 切到 Message tab 时刷新未读
    if (index == 3) _refreshUnread();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        elevation: 8,
        selectedItemColor: const Color(0xFFFFB347),
        unselectedItemColor: const Color(0xFFC9A96E),
        selectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_outlined),
            activeIcon: Icon(Icons.restaurant_menu),
            label: 'Recipes',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            activeIcon: Icon(Icons.search),
            label: 'Ingredients',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _messageIcon(Icons.chat_bubble_outline),
            activeIcon: _messageIcon(Icons.chat_bubble),
            label: 'Message',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ✅ Message 图标 + 总未读红点
  Widget _messageIcon(IconData icon) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (_totalUnread > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _totalUnread > 99 ? '99+' : '$_totalUnread',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}