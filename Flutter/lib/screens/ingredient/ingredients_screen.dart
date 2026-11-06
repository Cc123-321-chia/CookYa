// screens/ingredient/ingredients_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_ingredient_post_screen.dart';
import 'ingredients_detail_screen.dart';
import 'models.dart';
import 'widgets.dart';
import '../../services/api_service.dart';

class IngredientsScreen extends StatefulWidget {
  const IngredientsScreen({super.key});

  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {
  String _searchQuery = '';
  List<IngredientPost> _posts = [];
  List<IngredientPost> _filteredPosts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (ApiService.authToken == null) {
        setState(() {
          _errorMessage = 'Please login to view posts';
          _isLoading = false;
        });
        return;
      }

      final result = await ApiService.getIngredientPosts();

      if (result['success'] == true) {
        final List<dynamic> data = result['data'];
        setState(() {
          _posts = data.map((json) => IngredientPost.fromJson(json)).toList();
          _filteredPosts = _posts;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to load posts';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _searchPosts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredPosts = _posts;
      } else {
        final searchLower = query.toLowerCase();
        _filteredPosts = _posts.where((post) {
          return post.title.toLowerCase().contains(searchLower) ||
              post.content.toLowerCase().contains(searchLower) ||
              post.authorName.toLowerCase().contains(searchLower) ||
              post.tags.any((tag) => tag.toLowerCase().contains(searchLower));
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          'Ingredients Guide',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddIngredientPostScreen()),
              );
              if (result == true) {
                _fetchPosts();
              }
            },
            icon: const Icon(Icons.add, color: Color(0xFFFFB347), size: 28),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                onChanged: _searchPosts,
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFFFB347)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchPosts('');
                          },
                          icon: const Icon(Icons.clear, color: Colors.grey),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFFFB347)),
            SizedBox(height: 16),
            Text(
              'Loading posts...',
              style: TextStyle(color: Color(0xFF6B4C2A)),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFFFB347)),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: GoogleFonts.poppins(color: const Color(0xFF6B4C2A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPosts,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD966),
                foregroundColor: const Color(0xFF6B4C2A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isEmpty ? Icons.inbox_outlined : Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty
                  ? 'No ingredients posts yet'
                  : 'No results found for "$_searchQuery"',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try different keywords',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
              ),
            ],
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddIngredientPostScreen()),
                  );
                  if (result == true) {
                    _fetchPosts();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD966),
                  foregroundColor: const Color(0xFF6B4C2A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Create First Post'),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: _filteredPosts.length,
        itemBuilder: (context, index) {
          final post = _filteredPosts[index];
          return IngredientCard(
            post: post,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => IngredientDetailScreen(post: post),
                ),
              );
              if (mounted) {
                _fetchPosts();
              }
            },
          );
        },
      ),
    );
  }
}