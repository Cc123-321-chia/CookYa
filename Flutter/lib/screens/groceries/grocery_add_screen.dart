// screens/groceries/grocery_add_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'grocery_item.dart';
import '../../services/api_service.dart';

class GroceryAddScreen extends StatefulWidget {
  const GroceryAddScreen({super.key});

  @override
  State<GroceryAddScreen> createState() => _GroceryAddScreenState();
}

class _GroceryAddScreenState extends State<GroceryAddScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedUnit = 'pcs';
  List<GroceryItem> _items = [];
  bool _isLoading = false;

  final List<String> _units = [
    'g', 'kg', 'ml', 'L', 'pcs', 'pack', 'bottle',
    'spoon', 'cup', 'box', 'bag', 'others'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _itemNameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _addItem() {
    if (_itemNameController.text.trim().isEmpty) return;

    setState(() {
      _items.add(GroceryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _itemNameController.text.trim(),
        quantity: double.tryParse(_quantityController.text) ?? 1,
        unit: _selectedUnit,
        isChecked: false,
      ));
    });

    _itemNameController.clear();
    _quantityController.clear();
  }

  void _removeItem(String id) {
    setState(() {
      _items.removeWhere((item) => item.id == id);
    });
  }

  Future<void> _saveList() async {
    if (ApiService.authToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a list title'),
          backgroundColor: Color(0xFFFFB347),
        ),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item'),
          backgroundColor: Color(0xFFFFB347),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final itemsJson = _items.map((item) => item.toJson()).toList();

      final result = await ApiService.createGroceryList(
        title: _titleController.text.trim(),
        shoppingDate: _selectedDate.toIso8601String().split('T').first,
        isGenerated: false,
        items: itemsJson,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shopping list created successfully!'),
            backgroundColor: Color(0xFFFFB347),
          ),
        );
        Navigator.pop(context, true);
      } else {
        String errorMsg = result['error'] ?? 'Failed to create list';
        if (result['statusCode'] != null) {
          errorMsg = 'Server error (${result['statusCode']}): $errorMsg';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          'New Shopping List',
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
            onPressed: _items.isEmpty || _isLoading ? null : _saveList,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFFB347),
                    ),
                  )
                : Text(
                    'Save',
                    style: GoogleFonts.poppins(
                      color: _items.isEmpty
                          ? Colors.grey
                          : const Color(0xFFFFB347),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleController,
              style: GoogleFonts.poppins(fontSize: 16),
              decoration: InputDecoration(
                labelText: 'List Title',
                labelStyle: GoogleFonts.poppins(color: const Color(0xFFC9A96E)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Date
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Color(0xFFFFB347)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Shopping Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF6B4C2A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => _selectedDate = date);
                      }
                    },
                    icon: const Icon(Icons.edit,
                        size: 18, color: Color(0xFFC9A96E)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Add Item Section
            Text(
              'Add Items',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B4C2A),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _itemNameController,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Item name',
                      hintStyle:
                          GoogleFonts.poppins(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    style: GoogleFonts.poppins(fontSize: 14),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Qty',
                      hintStyle:
                          GoogleFonts.poppins(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedUnit,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Color(0xFFFFB347)),
                        items: _units.map((unit) {
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(unit,
                                style: GoogleFonts.poppins(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedUnit = value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB347),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Add'),
              ),
            ),
            const SizedBox(height: 16),

            // Items List
            if (_items.isNotEmpty) ...[
              Text(
                'Items (${_items.length})',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
              const SizedBox(height: 8),
              ..._items.map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF6B4C2A),
                                ),
                              ),
                              Text(
                                '${item.quantity} ${item.unit}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFFC9A96E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _removeItem(item.id!),
                          icon: const Icon(Icons.close,
                              size: 18, color: Colors.red),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}