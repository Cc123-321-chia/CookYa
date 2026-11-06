// screens/search/filter_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/duration_slider.dart';
import '../../widgets/star_rating.dart';

class FilterScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onApply;
  final Map<String, dynamic> currentFilters;

  const FilterScreen({
    super.key,
    required this.onApply,
    required this.currentFilters,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {

  List<String> _selectedCuisines = [];

  bool _isAddingOtherCuisine = false;
  final TextEditingController _otherCuisineController = TextEditingController();

  List<String> _ingredients = [];
  final TextEditingController _ingredientController = TextEditingController();

  double? _duration;

  int? _difficulty;

  List<String> _selectedTools = [];
  final TextEditingController _otherToolController = TextEditingController();
  bool _isAddingOtherTool = false;

  final List<String> _cuisines = [
    'Korean', 'Western', 'Chinese', 'Japanese', 'Italian', 'Mexican', 'Thai', 'Indian'
  ];

  final List<String> _availableTools = [
    'Airfryer', 'Oven', 'Microwave', 'Stove', 'Slow Cooker', 'Pressure Cooker'
  ];

  @override
  void initState() {
    super.initState();

    final cuisineValue = widget.currentFilters['cuisine'];
    if (cuisineValue is List) {
      _selectedCuisines = List<String>.from(cuisineValue);
    } else if (cuisineValue is String && cuisineValue.isNotEmpty) {
      _selectedCuisines = [cuisineValue];
    } else {
      _selectedCuisines = [];
    }

    _ingredients = List.from(widget.currentFilters['ingredients'] ?? []);

    final durationValue = widget.currentFilters['duration'];
    if (durationValue is double) {
      _duration = durationValue;
    } else if (durationValue is int) {
      _duration = durationValue.toDouble();
    } else if (durationValue is String) {
      _duration = double.tryParse(durationValue);
    } else {
      _duration = null;
    }

    final difficultyValue = widget.currentFilters['difficulty'];
    if (difficultyValue is int) {
      _difficulty = difficultyValue;
    } else if (difficultyValue is double) {
      _difficulty = difficultyValue.toInt();
    } else if (difficultyValue is String) {
      _difficulty = int.tryParse(difficultyValue);
    } else {
      _difficulty = null;
    }

    _selectedTools = List.from(widget.currentFilters['tools'] ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          'Filter Recipes',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF6B4C2A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Cuisine Type
            _buildSectionTitle('Cuisine Type', Icons.restaurant),
            const SizedBox(height: 12),
            _buildCuisineChips(),
            const SizedBox(height: 24),

            // 2. Ingredient Available
            _buildSectionTitle('Ingredients Available', Icons.kitchen),
            const SizedBox(height: 12),
            _buildIngredientsSection(),
            const SizedBox(height: 24),

            // 3. Duration
            _buildSectionTitle('Duration', Icons.timer),
            const SizedBox(height: 12),
            _buildDurationSlider(),
            const SizedBox(height: 24),

            // 4. Difficulty Level
            _buildSectionTitle('Difficulty Level', Icons.star),
            const SizedBox(height: 12),
            _buildDifficultyStars(),
            const SizedBox(height: 24),

            // 5. Cooking Tools
            _buildSectionTitle('Cooking Tools', Icons.build),
            const SizedBox(height: 12),
            _buildToolsSection(),
            const SizedBox(height: 32),

            // Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFFFB347)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6B4C2A),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFD966) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFFFFD966) : const Color(0xFFFFB347),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(
                Icons.check,
                size: 16,
                color: Color(0xFF6B4C2A),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF6B4C2A),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip({
    required String label,
    required VoidCallback onDelete,
    Color? backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFFFFF0D6),
        border: Border.all(color: const Color(0xFFFFB347), width: 1.5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF6B4C2A)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 16, color: Color(0xFFFFB347)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton({
    required String label,
    required VoidCallback onTap,
    IconData icon = Icons.add,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFFFB347), width: 1.5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFFFFB347)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Color(0xFFFFB347))),
          ],
        ),
      ),
    );
  }

  Widget _buildCuisineChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ..._cuisines.map((cuisine) {
              final isSelected = _selectedCuisines.contains(cuisine);
              return _buildOptionChip(
                label: cuisine,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedCuisines.remove(cuisine);
                    } else {
                      _selectedCuisines.add(cuisine);
                    }
                  });
                },
              );
            }),
            if (!_isAddingOtherCuisine)
              _buildAddButton(
                label: 'Other',
                onTap: () {
                  setState(() {
                    _isAddingOtherCuisine = true;
                  });
                },
              ),
          ],
        ),
        if (_isAddingOtherCuisine)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _otherCuisineController,
                    decoration: InputDecoration(
                      hintText: 'Enter custom cuisine...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    autofocus: true,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    if (_otherCuisineController.text.isNotEmpty) {
                      setState(() {
                        _selectedCuisines.add(_otherCuisineController.text);
                        _otherCuisineController.clear();
                        _isAddingOtherCuisine = false;
                      });
                    }
                  },
                  icon: const Icon(Icons.check_circle, color: Color(0xFFFFB347)),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isAddingOtherCuisine = false;
                      _otherCuisineController.clear();
                    });
                  },
                  icon: const Icon(Icons.cancel, color: Colors.grey),
                ),
              ],
            ),
          ),
        if (_selectedCuisines.where((c) => !_cuisines.contains(c)).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _selectedCuisines
                  .where((c) => !_cuisines.contains(c))
                  .map((cuisine) {
                return _buildTagChip(
                  label: cuisine,
                  onDelete: () {
                    setState(() {
                      _selectedCuisines.remove(cuisine);
                    });
                  },
                  backgroundColor: const Color(0xFFFFD966),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_ingredients.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _ingredients.map((ingredient) {
              return _buildTagChip(
                label: ingredient,
                onDelete: () {
                  setState(() {
                    _ingredients.remove(ingredient);
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        _buildAddButton(
          label: 'Add Ingredient',
          onTap: _showAddIngredientDialog,
        ),
        if (_ingredients.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'No ingredients selected. Tap "Add Ingredient" to add ingredients.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
      ],
    );
  }

  void _showAddIngredientDialog() {
    _ingredientController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Ingredient'),
        content: TextField(
          controller: _ingredientController,
          decoration: const InputDecoration(
            hintText: 'e.g., Tomato, Cheese, Chicken...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_ingredientController.text.isNotEmpty) {
                setState(() {
                  _ingredients.add(_ingredientController.text);
                });
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD966),
              foregroundColor: const Color(0xFF6B4C2A),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSlider() {
    return DurationSlider(
      durationMinutes: _duration?.toInt() ?? 0,
      onChanged: (minutes) {
        setState(() {
          _duration = minutes == 0 ? null : minutes.toDouble();
        });
      },
    );
  }

  Widget _buildDifficultyStars() {
    return StarRating(
      rating: _difficulty ?? 0,
      onRatingChanged: (rating) {
        setState(() {
          _difficulty = rating == 0 ? null : rating;
        });
      },
      starSize: 40,
      showLabel: true,
    );
  }

  Widget _buildToolsSection() {
    return Column(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ..._availableTools.map((tool) {
              final isSelected = _selectedTools.contains(tool);
              return _buildOptionChip(
                label: tool,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedTools.remove(tool);
                    } else {
                      _selectedTools.add(tool);
                    }
                  });
                },
              );
            }),
            if (!_isAddingOtherTool)
              _buildAddButton(
                label: 'Others',
                onTap: () {
                  setState(() {
                    _isAddingOtherTool = true;
                  });
                },
              ),
          ],
        ),
        if (_isAddingOtherTool)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _otherToolController,
                    decoration: InputDecoration(
                      hintText: 'Enter custom tool...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    autofocus: true,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    if (_otherToolController.text.isNotEmpty) {
                      setState(() {
                        _selectedTools.add(_otherToolController.text);
                        _otherToolController.clear();
                        _isAddingOtherTool = false;
                      });
                    }
                  },
                  icon: const Icon(Icons.check_circle, color: Color(0xFFFFB347)),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isAddingOtherTool = false;
                      _otherToolController.clear();
                    });
                  },
                  icon: const Icon(Icons.cancel, color: Colors.grey),
                ),
              ],
            ),
          ),
        if (_selectedTools.where((tool) => !_availableTools.contains(tool)).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _selectedTools
                  .where((tool) => !_availableTools.contains(tool))
                  .map((tool) {
                return _buildTagChip(
                  label: tool,
                  onDelete: () {
                    setState(() {
                      _selectedTools.remove(tool);
                    });
                  },
                  backgroundColor: const Color(0xFFFFD966),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _selectedCuisines = [];
                _ingredients = [];
                _duration = null;
                _difficulty = null;
                _selectedTools = [];
              });
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFFB347)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Clear All', style: TextStyle(color: Color(0xFFFFB347))),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              final filters = {
                'cuisine': _selectedCuisines.isNotEmpty ? _selectedCuisines : null,
                'ingredients': _ingredients,
                'duration': _duration?.toInt(),
                'difficulty': _difficulty,
                'tools': _selectedTools,
              };
              widget.onApply(filters);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD966),
              foregroundColor: const Color(0xFF6B4C2A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}