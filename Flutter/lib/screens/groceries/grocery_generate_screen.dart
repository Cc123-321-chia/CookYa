// screens/groceries/grocery_generate_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'grocery_item.dart';
import '../../services/api_service.dart';
import '../../models/recipe.dart';

class GroceryGenerateScreen extends StatefulWidget {
  final Map<String, Map<String, List<String>>> mealPlan;
  final Map<String, Recipe> allRecipes; // name -> Recipe

  const GroceryGenerateScreen({
    super.key,
    required this.mealPlan,
    required this.allRecipes,
  });

  @override
  State<GroceryGenerateScreen> createState() => _GroceryGenerateScreenState();
}

class _GroceryGenerateScreenState extends State<GroceryGenerateScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();

  List<GroceryItem> _generatedItems = [];
  bool _isGenerating = true;
  bool _isSaving = false;
  String? _errorMessage;

  final DateTime _createdAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _titleController.text = 'Shopping List';
    _generateShoppingListFromApi();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _generateShoppingListFromApi() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final Set<String> recipeNames = {};
      for (var day in widget.mealPlan.keys) {
        final meals = widget.mealPlan[day]!;
        for (var mealType in meals.keys) {
          final names = meals[mealType] ?? [];
          recipeNames.addAll(names.where((name) => name.isNotEmpty));
        }
      }

      if (recipeNames.isEmpty) {
        setState(() {
          _isGenerating = false;
          _generatedItems = [];
        });
        return;
      }

      final Map<String, List<Map<String, String>>> recipeIngredients = {};

      for (var recipeName in recipeNames) {
        final recipe = widget.allRecipes[recipeName];
        if (recipe == null) continue;

        try {
          final result = await ApiService.getRecipeIngredients(recipe.id);
          if (result['success'] == true) {
            final List<dynamic> raw = result['data']['ingredients'] ?? [];
            recipeIngredients[recipeName] = raw
                .map<Map<String, String>>((e) => {
                      'name': (e['name'] ?? '').toString(),
                      'amount': (e['amount'] ?? '').toString(),
                    })
                .toList();
          }
        } catch (e) {
          debugPrint('Error fetching $recipeName: $e');
        }
      }

      final Map<String, GroceryItem> itemMap = {};

      for (var day in widget.mealPlan.keys) {
        final meals = widget.mealPlan[day]!;
        for (var mealType in meals.keys) {
          final namesForMeal = meals[mealType] ?? [];
          for (var recipeName in namesForMeal) {
            if (recipeName.isEmpty) continue;

            final ingredients = recipeIngredients[recipeName] ?? [];
            for (var ing in ingredients) {
              final name = ing['name'] ?? '';
              if (name.isEmpty) continue;

              final amountStr = ing['amount'] ?? '';
              final parsed = _parseAmount(amountStr);

              if (!itemMap.containsKey(name)) {
                itemMap[name] = GroceryItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString() + name,
                  name: name,
                  quantity: parsed.$1,
                  unit: parsed.$2,
                  isChecked: false,
                  recipeName: recipeName,
                );
              } else {
                final existing = itemMap[name]!;
                final newQty = existing.unit == parsed.$2
                    ? existing.quantity + parsed.$1
                    : existing.quantity;
                itemMap[name] = existing.copyWith(quantity: newQty);
              }
            }
          }
        }
      }

      setState(() {
        _generatedItems = itemMap.values.toList();
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate shopping list: $e';
        _isGenerating = false;
      });
    }
  }

  (double, String) _parseAmount(String amount) {
    if (amount.isEmpty) return (1.0, 'pcs');
    final trimmed = amount.trim();

    final match = RegExp(r'^([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z]*)$').firstMatch(trimmed);
    if (match != null) {
      final qty = double.tryParse(match.group(1)!) ?? 1.0;
      final unit = (match.group(2) ?? '').trim();
      return (qty, unit.isEmpty ? 'pcs' : unit);
    }

    final numMatch = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(trimmed);
    if (numMatch != null) {
      final qty = double.tryParse(numMatch.group(1)!) ?? 1.0;
      final unit = trimmed.replaceAll(RegExp(r'[0-9.]'), '').trim();
      return (qty, unit.isEmpty ? 'pcs' : unit);
    }

    return (1.0, 'pcs');
  }

  Future<void> _saveList() async {
    if (_generatedItems.isEmpty) return;

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a list name'),
          backgroundColor: Color(0xFFFFB347),
        ),
      );
      return;
    }

    if (_remarkController.text.trim().length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remark too long (max 100 characters)'),
          backgroundColor: Color(0xFFFFB347),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final result = await ApiService.createGroceryList(
        title: _titleController.text.trim(),
        shoppingDate: _createdAt.toIso8601String().split('T').first,
        isGenerated: true,
        remark: _remarkController.text.trim(),
        items: _generatedItems.map((item) => item.toJson()).toList(),
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shopping list saved successfully!'),
            backgroundColor: Color(0xFFFFB347),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to save list'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  String _formatCreatedAt(DateTime d) {
    final y = d.year;
    final mo = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$y-$mo-$da $h:$mi';
  }

  String _formatQty(double q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    return q.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          'Generated List',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Color(0xFF6B4C2A)),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving || _generatedItems.isEmpty ? null : _saveList,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFFB347),
                    ),
                  )
                : Text(
                    'Save List',
                    style: GoogleFonts.poppins(
                      color: _generatedItems.isEmpty ? Colors.grey : const Color(0xFFFFB347),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: _isGenerating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFFB347)),
                  SizedBox(height: 16),
                  Text(
                    'Generating shopping list...',
                    style: TextStyle(color: Color(0xFFC9A96E)),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Color(0xFFFFB347)),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(color: const Color(0xFF6B4C2A)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _generateShoppingListFromApi,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB347),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== Name 区域 =====
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Name',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6B4C2A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _titleController,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: const Color(0xFF6B4C2A),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Shopping List',
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey.shade400,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFFF9E6),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.schedule,
                                    size: 14, color: Color(0xFFC9A96E)),
                                const SizedBox(width: 6),
                                Text(
                                  'Created at: ${_formatCreatedAt(_createdAt)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFFC9A96E),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFFFF0B5)),

                      // ===== Remark 区域 =====
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Remark',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6B4C2A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _remarkController,
                              minLines: 3,
                              maxLines: 5,
                              maxLength: 100,
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Write a remark...',
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey.shade400,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFFF9E6),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                                counterStyle: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFFC9A96E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFFFF0B5)),

                      // ===== Items 统计条 =====
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        color: Colors.white,
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                size: 18, color: Color(0xFFFFB347)),
                            const SizedBox(width: 8),
                            Text(
                              '${_generatedItems.length} items',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF6B4C2A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFFFF0B5)),

                      // ===== 食材列表（纯预览）=====
                      _generatedItems.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 60),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.inventory_2_outlined,
                                        size: 48, color: Color(0xFFC9A96E)),
                                    SizedBox(height: 16),
                                    Text(
                                      'No items generated',
                                      style: TextStyle(color: Color(0xFFC9A96E)),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: _generatedItems.length,
                              itemBuilder: (context, index) {
                                final item = _generatedItems[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      // 🔥 纯预览 checkbox（不能点）
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF6B4C2A),
                                              ),
                                            ),
                                            Text(
                                              '${_formatQty(item.quantity)} ${item.unit}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: const Color(0xFFC9A96E),
                                              ),
                                            ),
                                            if (item.recipeName != null)
                                              Text(
                                                'From: ${item.recipeName}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  color: const Color(0xFFC9A96E)
                                                      .withValues(alpha: 0.7),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }
}