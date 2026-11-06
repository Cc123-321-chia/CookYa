// models/user.dart
class User {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final List<String> savedRecipes;
  final List<String> myDishes;
  final int followers;
  final int following;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.savedRecipes,
    required this.myDishes,
    required this.followers,
    required this.following,
  });
}