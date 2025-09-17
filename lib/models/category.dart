class Category {
  final int? id;
  final String name;
  final String type; // 'income', 'expense', 'debt', 'loan'
  final String color;
  final String icon;
  final bool isDefault;
  final int? userId;
  final DateTime createdAt;

  Category({
    this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
    required this.isDefault,
    this.userId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'color': color,
      'icon': icon,
      'is_default': isDefault ? 1 : 0,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      color: map['color'],
      icon: map['icon'],
      isDefault: map['is_default'] == 1,
      userId: map['user_id'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
