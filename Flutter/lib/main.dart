// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'screens/main_navigation.dart';
import 'services/api_service.dart';

// Admin imports
import 'admin/admin_login.dart';
import 'admin/admin_dashboard.dart';
import 'admin/admin_users.dart';
import 'admin/admin_recipes.dart';
import 'admin/admin_ingredients.dart';
import 'admin/admin_posts.dart';
import 'admin/admin_admins.dart';
import 'admin/admin_upload_poster.dart';
import 'admin/admin_auth_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.loadSavedBaseUrl();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const emojiFallback = [
      'Noto Color Emoji',
      'Apple Color Emoji',
      'Segoe UI Emoji',
      'sans-serif',
    ];

    TextStyle emojiStyle(TextStyle base) {
      return base.copyWith(fontFamilyFallback: emojiFallback);
    }

    return MaterialApp(
      title: 'Recipes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFFFD966),
          secondary: Color(0xFFFFB347),
          tertiary: Color(0xFFFFF0B5),
          surface: Color(0xFFFFF9E6),
          onPrimary: Color(0xFF6B4C2A),
          onSecondary: Colors.white,
        ),
        fontFamily: 'sans-serif',
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.light().textTheme,
        ).apply(
          bodyColor: const Color(0xFF6B4C2A),
          displayColor: const Color(0xFF6B4C2A),
        ).copyWith(
          displayLarge: emojiStyle(GoogleFonts.poppins()),
          displayMedium: emojiStyle(GoogleFonts.poppins()),
          displaySmall: emojiStyle(GoogleFonts.poppins()),
          headlineLarge: emojiStyle(GoogleFonts.poppins()),
          headlineMedium: emojiStyle(GoogleFonts.poppins()),
          headlineSmall: emojiStyle(GoogleFonts.poppins()),
          titleLarge: emojiStyle(GoogleFonts.poppins()),
          titleMedium: emojiStyle(GoogleFonts.poppins()),
          titleSmall: emojiStyle(GoogleFonts.poppins()),
          bodyLarge: emojiStyle(GoogleFonts.poppins()),
          bodyMedium: emojiStyle(GoogleFonts.poppins()),
          bodySmall: emojiStyle(GoogleFonts.poppins()),
          labelLarge: emojiStyle(GoogleFonts.poppins()),
          labelMedium: emojiStyle(GoogleFonts.poppins()),
          labelSmall: emojiStyle(GoogleFonts.poppins()),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF6B4C2A),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamilyFallback: emojiFallback,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFFFFD966),
          unselectedItemColor: Color(0xFFC9A96E),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          elevation: 8,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFFD966),
          foregroundColor: Color(0xFF6B4C2A),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFFFFD966), width: 2),
          ),
          prefixIconColor: const Color(0xFFC9A96E),
          hintStyle: const TextStyle(color: Color(0xFFC9A96E)),
        ),
      ),
      // Choose entry screen based on URL:
      // - /admin*  -> admin login
      // - anything else -> user splash
      home: Builder(
        builder: (context) {
          final uri = Uri.base;
          if (uri.toString().contains('/admin')) {
            return const AdminLoginScreen();
          }
          return const SplashScreen();
        },
      ),
      routes: {
        '/main': (context) => const MainNavigation(),
        '/admin/login': (context) => const AdminLoginScreen(),
        // Protected: only accessible when a valid admin token exists.
        '/admin/dashboard': (context) => const AdminAuthGuard(
              child: AdminDashboardScreen(),
            ),
        '/admin/users': (context) => const AdminUsersScreen(),
        '/admin/recipes': (context) => const AdminRecipesScreen(),
        '/admin/ingredients': (context) => const AdminIngredientsScreen(),
        '/admin/posts': (context) => const AdminPostsScreen(),
        '/admin/admins': (context) => const AdminAdminsScreen(),
        '/admin/upload-poster': (context) => const AdminUploadPosterScreen(),
      },
    );
  }
}