// screens/groceries/grocery_item.dart

class GroceryItem {
  final String? id;
  final String name;
  final String category;
  final double quantity;
  final String unit;
  bool isChecked;
  final String? recipeName;
  final DateTime? addedDate;

  GroceryItem({
    this.id,
    required this.name,
    this.category = 'Others',
    this.quantity = 1,
    this.unit = 'pcs',
    this.isChecked = false,
    this.recipeName,
    this.addedDate,
  });

  // From JSON (API response)
  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      id: json['id']?.toString(),
      name: json['name'] ?? '',
      category: json['category'] ?? 'Others',
      quantity: (json['quantity'] ?? 1).toDouble(),
      unit: json['unit'] ?? 'pcs',
      isChecked: json['is_checked'] ?? false,
      recipeName: json['recipe_name'],
      addedDate: json['added_date'] != null
          ? DateTime.tryParse(json['added_date'].toString())
          : null,
    );
  }

  // To JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'is_checked': isChecked,
      if (recipeName != null) 'recipe_name': recipeName,
    };
  }

  GroceryItem copyWith({
    String? id,
    String? name,
    String? category,
    double? quantity,
    String? unit,
    bool? isChecked,
    String? recipeName,
    DateTime? addedDate,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isChecked: isChecked ?? this.isChecked,
      recipeName: recipeName ?? this.recipeName,
      addedDate: addedDate ?? this.addedDate,
    );
  }
}

class GroceryList {
  final String id;
  final String title;
  final DateTime shoppingDate;
  List<GroceryItem> items;
  final bool isGenerated;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? userName;
  final String? remark; // 🔥 新增
  final int? totalItems;
  final int? checkedItems;
  final double? progress;

  GroceryList({
    required this.id,
    required this.title,
    required this.shoppingDate,
    this.items = const [],
    this.isGenerated = false,
    required this.createdAt,
    this.updatedAt,
    this.userName,
    this.remark, // 🔥 新增
    this.totalItems,
    this.checkedItems,
    this.progress,
  });

  // From JSON (API response)
  factory GroceryList.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List? ?? [];
    return GroceryList(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      shoppingDate: json['shopping_date'] != null
          ? DateTime.tryParse(json['shopping_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      items: itemsList.map((item) => GroceryItem.fromJson(item)).toList(),
      isGenerated: json['is_generated'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      userName: json['user_name'],
      remark: json['remark']?.toString(), // 🔥 新增
      totalItems: json['total_items'],
      checkedItems: json['checked_items'],
      progress: json['progress']?.toDouble(),
    );
  }

  // To JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'shopping_date': shoppingDate.toIso8601String().split('T').first,
      'is_generated': isGenerated,
      if (remark != null && remark!.isNotEmpty) 'remark': remark, // 🔥 新增
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  GroceryList copyWith({
    String? id,
    String? title,
    DateTime? shoppingDate,
    List<GroceryItem>? items,
    bool? isGenerated,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userName,
    String? remark, // 🔥 新增
    int? totalItems,
    int? checkedItems,
    double? progress,
  }) {
    return GroceryList(
      id: id ?? this.id,
      title: title ?? this.title,
      shoppingDate: shoppingDate ?? this.shoppingDate,
      items: items ?? this.items,
      isGenerated: isGenerated ?? this.isGenerated,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      remark: remark ?? this.remark, // 🔥 新增
      totalItems: totalItems ?? this.totalItems,
      checkedItems: checkedItems ?? this.checkedItems,
      progress: progress ?? this.progress,
    );
  }
}