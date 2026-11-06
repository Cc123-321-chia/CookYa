// screens/groceries/grocery_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'grocery_item.dart';
import 'grocery_add_screen.dart';
import 'grocery_meal_plan_screen.dart';
import '../../services/api_service.dart';

class GroceryScreen extends StatefulWidget {
  const GroceryScreen({super.key});

  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  List<GroceryList> _groceryLists = [];
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGroceryLists();
  }

  Future<void> _loadGroceryLists() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (ApiService.authToken == null) {
        setState(() {
          _errorMessage = 'Please login to view your grocery lists';
          _isLoading = false;
        });
        return;
      }

      final result = await ApiService.getGroceryLists();

      if (result['success'] == true) {
        final List<dynamic> data = result['data'];
        setState(() {
          _groceryLists =
              data.map((json) => GroceryList.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to load grocery lists';
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

  Future<void> _refreshLists() async {
    await _loadGroceryLists();
  }

  Future<void> _editListTitle(GroceryList list) async {
    final TextEditingController controller =
        TextEditingController(text: list.title);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Edit List Title',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter new title',
            hintStyle: GoogleFonts.poppins(
              color: Colors.grey.shade400,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFFFB347),
              ),
            ),
          ),
          style: GoogleFonts.poppins(
            color: const Color(0xFF6B4C2A),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(context, true);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: const Color(0xFFC9A96E),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB347),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      try {
        final apiResult = await ApiService.updateGroceryList(
          listId: list.id,
          title: controller.text.trim(),
        );

        if (apiResult['success'] == true) {
          await _loadGroceryLists();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('List title updated!'),
                backgroundColor: Color(0xFFFFB347),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(apiResult['error'] ?? 'Failed to update title'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteList(String listId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Delete List?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        content: Text(
          'This will permanently delete this shopping list.',
          style: GoogleFonts.poppins(
            color: const Color(0xFF6B4C2A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: const Color(0xFFC9A96E),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final result = await ApiService.deleteGroceryList(listId);
        if (result['success'] == true) {
          await _loadGroceryLists();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('List deleted successfully'),
                backgroundColor: Color(0xFFFFB347),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['error'] ?? 'Failed to delete'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          'Grocery',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildTab('My Lists', 0),
                const SizedBox(width: 12),
                _buildTab('Meal Plan', 1),
              ],
            ),
          ),
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildGroceryLists()
                : GroceryMealPlanScreen(
                    onListGenerated: () {
                      // 🔥 生成成功后切回 My Lists + 刷新
                      setState(() => _selectedTabIndex = 0);
                      _loadGroceryLists();
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedTabIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GroceryAddScreen(),
                  ),
                ).then((_) => _loadGroceryLists());
              },
              backgroundColor: const Color(0xFFFFB347),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFB347) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFB347).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFFC9A96E),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroceryLists() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFFFFB347),
            ),
            SizedBox(height: 16),
            Text(
              'Loading your lists...',
              style: TextStyle(color: Color(0xFFC9A96E)),
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
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFFFFB347),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: GoogleFonts.poppins(
                color: const Color(0xFF6B4C2A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGroceryLists,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB347),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_groceryLists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: const Color(0xFFFFB347).withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No shopping lists yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: const Color(0xFFC9A96E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new list or generate from meal plan',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFFC9A96E).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshLists,
      color: const Color(0xFFFFB347),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _groceryLists.length,
        itemBuilder: (context, index) {
          final list = _groceryLists[index];
          return _buildGroceryListCard(list);
        },
      ),
    );
  }

  Widget _buildGroceryListCard(GroceryList list) {
    final checkedCount =
        list.checkedItems ?? list.items.where((item) => item.isChecked).length;
    final totalItems = list.totalItems ?? list.items.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  list.title,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B4C2A),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _editListTitle(list),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Color(0xFFC9A96E),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _deleteList(list.id),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red.shade400,
                  ),
                ),
              ),
              if (list.isGenerated) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB347).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Generated',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: const Color(0xFFFFB347),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: Color(0xFFC9A96E),
              ),
              const SizedBox(width: 6),
              Text(
                '${list.shoppingDate.day}/${list.shoppingDate.month}/${list.shoppingDate.year}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFFC9A96E),
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: Color(0xFFC9A96E),
              ),
              const SizedBox(width: 6),
              Text(
                '$checkedCount / $totalItems items',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFFC9A96E),
                ),
              ),
            ],
          ),
          // 🔥 Remark（有才显示）
          if (list.remark != null && list.remark!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notes,
                  size: 14,
                  color: Color(0xFFC9A96E),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    list.remark!,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF6B4C2A),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0B5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              widthFactor: totalItems > 0 ? checkedCount / totalItems : 0,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB347),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _showShoppingMode(list);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF9E6),
                foregroundColor: const Color(0xFF6B4C2A),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                'View Items',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showShoppingMode(GroceryList list) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            List<GroceryItem> items = List.from(list.items);

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF9E6),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9A96E),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            list.title,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6B4C2A),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          child: Text(
                            'Close',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFC9A96E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(
                          '${items.where((i) => i.isChecked).length} / ${items.length} purchased',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFFC9A96E),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            try {
                              final result =
                                  await ApiService.bulkUpdateGroceryItems(
                                listId: list.id,
                                action: 'reset_all',
                              );
                              if (result['success'] == true) {
                                setModalState(() {
                                  for (var item in items) {
                                    item.isChecked = false;
                                  }
                                });
                                await _loadGroceryLists();
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          child: Text(
                            'Reset All',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFFC9A96E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 🔥 Remark（有才显示）
                  if (list.remark != null && list.remark!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.notes,
                              size: 14, color: Color(0xFFC9A96E)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              list.remark!,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF6B4C2A),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(color: Color(0xFFFFF0B5), thickness: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  try {
                                    final result =
                                        await ApiService.toggleGroceryItem(
                                            item.id!);
                                    if (result['success'] == true) {
                                      setModalState(() {
                                        item.isChecked = !item.isChecked;
                                      });
                                      await _loadGroceryLists();
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: item.isChecked
                                        ? const Color(0xFFFFB347)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: item.isChecked
                                          ? const Color(0xFFFFB347)
                                          : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                  ),
                                  child: item.isChecked
                                      ? const Icon(Icons.check,
                                          size: 14, color: Colors.white)
                                      : null,
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
                                        color: item.isChecked
                                            ? Colors.grey.shade400
                                            : const Color(0xFF6B4C2A),
                                        decoration: item.isChecked
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                      ),
                                    ),
                                    Text(
                                      '${item.quantity} ${item.unit}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: const Color(0xFFC9A96E),
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
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}