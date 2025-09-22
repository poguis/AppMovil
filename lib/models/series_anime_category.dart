class SeriesAnimeCategory {
  final int? id;
  final String name;
  final String type; // 'video' o 'lectura'
  final String? description;
  final DateTime startDate;
  final List<int> selectedDays; // 1=Lunes, 2=Martes, ..., 7=Domingo
  final int frequency; // Número de capítulos por día
  final int numberOfSeries; // Número de series que se pueden agregar
  final DateTime createdAt;

  SeriesAnimeCategory({
    this.id,
    required this.name,
    required this.type,
    this.description,
    required this.startDate,
    required this.selectedDays,
    required this.frequency,
    required this.numberOfSeries,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'start_date': startDate.toIso8601String(),
      'selected_days': selectedDays.join(','),
      'frequency': frequency,
      'number_of_series': numberOfSeries,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SeriesAnimeCategory.fromMap(Map<String, dynamic> map) {
    return SeriesAnimeCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      description: map['description'] as String?,
      startDate: map['start_date'] != null 
          ? DateTime.parse(map['start_date'] as String)
          : DateTime.now(),
      selectedDays: map['selected_days'] != null 
          ? _parseSelectedDays(map['selected_days'] as String)
          : [1, 2, 3, 4, 5, 6, 7], // Todos los días por defecto
      frequency: map['frequency'] as int? ?? 1,
      numberOfSeries: map['number_of_series'] as int? ?? 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
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

  // Calcular días de atraso
  int getDaysBehind() {
    final now = DateTime.now();
    final start = startDate;
    int daysBehind = 0;
    
    // Contar días desde la fecha de inicio hasta hoy
    DateTime currentDate = start;
    while (currentDate.isBefore(now)) {
      // Solo contar días que están seleccionados
      if (selectedDays.contains(currentDate.weekday)) {
        daysBehind++;
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    return daysBehind;
  }

  // Calcular capítulos de atraso
  int getChaptersBehind() {
    return getDaysBehind() * frequency;
  }

  // Obtener el próximo día para ver capítulos
  DateTime? getNextViewingDay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Si hoy es un día seleccionado, devolver hoy
    if (selectedDays.contains(today.weekday)) {
      return today;
    }
    
    // Buscar el próximo día seleccionado
    for (int i = 1; i <= 7; i++) {
      final nextDay = today.add(Duration(days: i));
      if (selectedDays.contains(nextDay.weekday)) {
        return nextDay;
      }
    }
    
    return null;
  }

  // Obtener mensaje de estado
  String getStatusMessage() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextDay = getNextViewingDay();
    
    if (nextDay == null) {
      return 'No hay días seleccionados';
    }
    
    if (nextDay == today) {
      return 'Puedes ver capítulos hoy';
    }
    
    final daysUntil = nextDay.difference(today).inDays;
    if (daysUntil == 1) {
      return 'Puedes ver capítulos mañana';
    } else {
      return 'Puedes ver capítulos en $daysUntil días';
    }
  }

  // Obtener resumen de la categoría
  String get categorySummary {
    return '${frequency} capítulo${frequency > 1 ? 's' : ''} por día, ${numberOfSeries} serie${numberOfSeries > 1 ? 's' : ''}';
  }

  SeriesAnimeCategory copyWith({
    int? id,
    String? name,
    String? type,
    String? description,
    DateTime? startDate,
    List<int>? selectedDays,
    int? frequency,
    int? numberOfSeries,
    DateTime? createdAt,
  }) {
    return SeriesAnimeCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      selectedDays: selectedDays ?? this.selectedDays,
      frequency: frequency ?? this.frequency,
      numberOfSeries: numberOfSeries ?? this.numberOfSeries,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'SeriesAnimeCategory(id: $id, name: $name, type: $type, description: $description, startDate: $startDate, selectedDays: $selectedDays, frequency: $frequency, numberOfSeries: $numberOfSeries, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SeriesAnimeCategory &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.description == description &&
        other.startDate == startDate &&
        other.selectedDays.toString() == selectedDays.toString() &&
        other.frequency == frequency &&
        other.numberOfSeries == numberOfSeries &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        type.hashCode ^
        description.hashCode ^
        startDate.hashCode ^
        selectedDays.hashCode ^
        frequency.hashCode ^
        numberOfSeries.hashCode ^
        createdAt.hashCode;
  }
}

