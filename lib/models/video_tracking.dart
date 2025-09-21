class VideoTracking {
  final int? id;
  final int categoryId;
  final String name;
  final DateTime startDate;
  final List<int> selectedDays; // 1=Lunes, 2=Martes, ..., 7=Domingo
  final Map<String, int> frequency; // {'daily': 2, 'every_2_days': 1, etc.}
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  VideoTracking({
    this.id,
    required this.categoryId,
    required this.name,
    required this.startDate,
    required this.selectedDays,
    required this.frequency,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'start_date': startDate.toIso8601String(),
      'selected_days': selectedDays.join(','), // Convertir lista a string separado por comas
      'frequency': _frequencyToJson(frequency),
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory VideoTracking.fromMap(Map<String, dynamic> map) {
    return VideoTracking(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int,
      name: map['name'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      selectedDays: _parseSelectedDays(map['selected_days'] as String),
      frequency: _frequencyFromJson(map['frequency'] as String),
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Convertir frecuencia a JSON string
  static String _frequencyToJson(Map<String, int> frequency) {
    return frequency.entries
        .map((e) => '${e.key}:${e.value}')
        .join(';');
  }

  // Convertir JSON string a frecuencia
  static Map<String, int> _frequencyFromJson(String json) {
    if (json.isEmpty) return {};
    
    final Map<String, int> frequency = {};
    final parts = json.split(';');
    
    for (final part in parts) {
      final keyValue = part.split(':');
      if (keyValue.length == 2) {
        frequency[keyValue[0]] = int.tryParse(keyValue[1]) ?? 0;
      }
    }
    
    return frequency;
  }

  // Convertir string de días a lista de enteros
  static List<int> _parseSelectedDays(String daysString) {
    if (daysString.isEmpty) return [];
    return daysString.split(',').map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList();
  }

  // Obtener nombre del día en español
  static String getDayName(int dayNumber) {
    const days = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return dayNumber >= 1 && dayNumber <= 7 ? days[dayNumber] : 'Día $dayNumber';
  }

  // Obtener nombres de los días seleccionados
  List<String> get selectedDayNames {
    return selectedDays.map((day) => getDayName(day)).toList();
  }

  // Verificar si un día específico está seleccionado
  bool isDaySelected(int dayNumber) {
    return selectedDays.contains(dayNumber);
  }

  // Obtener frecuencia para un tipo específico
  int getFrequencyForType(String type) {
    return frequency[type] ?? 0;
  }

  // Obtener resumen de frecuencia
  String get frequencySummary {
    if (frequency.isEmpty) return 'Sin frecuencia definida';
    
    final summaries = frequency.entries.map((e) {
      switch (e.key) {
        case 'daily':
          return '${e.value} capítulo${e.value > 1 ? 's' : ''} por día';
        case 'every_2_days':
          return '${e.value} capítulo${e.value > 1 ? 's' : ''} cada 2 días';
        case 'every_3_days':
          return '${e.value} capítulo${e.value > 1 ? 's' : ''} cada 3 días';
        case 'weekly':
          return '${e.value} capítulo${e.value > 1 ? 's' : ''} por semana';
        default:
          return '${e.value} capítulo${e.value > 1 ? 's' : ''} ${e.key}';
      }
    }).toList();
    
    return summaries.join(', ');
  }

  VideoTracking copyWith({
    int? id,
    int? categoryId,
    String? name,
    DateTime? startDate,
    List<int>? selectedDays,
    Map<String, int>? frequency,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VideoTracking(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      selectedDays: selectedDays ?? this.selectedDays,
      frequency: frequency ?? this.frequency,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'VideoTracking(id: $id, categoryId: $categoryId, name: $name, startDate: $startDate, selectedDays: $selectedDays, frequency: $frequency, description: $description, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoTracking &&
        other.id == id &&
        other.categoryId == categoryId &&
        other.name == name &&
        other.startDate == startDate &&
        other.selectedDays.toString() == selectedDays.toString() &&
        other.frequency.toString() == frequency.toString() &&
        other.description == description &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        categoryId.hashCode ^
        name.hashCode ^
        startDate.hashCode ^
        selectedDays.hashCode ^
        frequency.hashCode ^
        description.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
