class SeriesAnimeCategory {
  final int? id;
  final String name;
  final String type; // 'video' o 'lectura'
  final String? description;
  final DateTime createdAt;

  SeriesAnimeCategory({
    this.id,
    required this.name,
    required this.type,
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SeriesAnimeCategory.fromMap(Map<String, dynamic> map) {
    return SeriesAnimeCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  SeriesAnimeCategory copyWith({
    int? id,
    String? name,
    String? type,
    String? description,
    DateTime? createdAt,
  }) {
    return SeriesAnimeCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'SeriesAnimeCategory(id: $id, name: $name, type: $type, description: $description, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SeriesAnimeCategory &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.description == description &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        type.hashCode ^
        description.hashCode ^
        createdAt.hashCode;
  }
}

