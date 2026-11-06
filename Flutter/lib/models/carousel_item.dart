// models/carousel_item.dart
class CarouselItem {
  final String id;
  final String title;
  final List<String> tags;
  final String imageUrl;
  final List<String> keywords;
  final int order;
  final bool isActive;

  CarouselItem({
    required this.id,
    required this.title,
    this.tags = const [],
    required this.imageUrl,
    this.keywords = const [],
    required this.order,
    required this.isActive,
  });

  factory CarouselItem.fromJson(Map<String, dynamic> json) {
    return CarouselItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      tags: json['tags'] is List ? List<String>.from(json['tags']) : [],
      imageUrl: json['image_url_display']?.toString() ?? json['image_url']?.toString() ?? '',
      keywords: json['keywords'] is List ? List<String>.from(json['keywords']) : [],
      order: json['order'] as int? ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }
}