import 'package:flutter/material.dart';

enum SeriesStatus {
  nueva('Nueva'),
  mirando('Mirando'),
  terminada('Terminada'),
  enEspera('En Espera');

  const SeriesStatus(this.displayName);
  final String displayName;
}

class Series {
  final int? id;
  final int categoryId;
  final String name;
  final String? description;
  final SeriesStatus status;
  final int currentSeason;
  final int currentEpisode;
  final DateTime? startWatchingDate;
  final DateTime? finishWatchingDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Series({
    this.id,
    required this.categoryId,
    required this.name,
    this.description,
    required this.status,
    required this.currentSeason,
    required this.currentEpisode,
    this.startWatchingDate,
    this.finishWatchingDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'status': status.name,
      'current_season': currentSeason,
      'current_episode': currentEpisode,
      'start_watching_date': startWatchingDate?.toIso8601String(),
      'finish_watching_date': finishWatchingDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Series.fromMap(Map<String, dynamic> map) {
    return Series(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int,
      name: map['name'] as String,
      description: map['description'] as String?,
      status: SeriesStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => SeriesStatus.nueva,
      ),
      currentSeason: map['current_season'] as int? ?? 1,
      currentEpisode: map['current_episode'] as int? ?? 1,
      startWatchingDate: map['start_watching_date'] != null
          ? DateTime.parse(map['start_watching_date'] as String)
          : null,
      finishWatchingDate: map['finish_watching_date'] != null
          ? DateTime.parse(map['finish_watching_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Obtener color del estado
  Color get statusColor {
    switch (status) {
      case SeriesStatus.nueva:
        return Colors.blue;
      case SeriesStatus.mirando:
        return Colors.green;
      case SeriesStatus.terminada:
        return Colors.purple;
      case SeriesStatus.enEspera:
        return Colors.orange;
    }
  }

  // Obtener icono del estado
  IconData get statusIcon {
    switch (status) {
      case SeriesStatus.nueva:
        return Icons.play_circle_outline;
      case SeriesStatus.mirando:
        return Icons.play_circle;
      case SeriesStatus.terminada:
        return Icons.check_circle;
      case SeriesStatus.enEspera:
        return Icons.pause_circle;
    }
  }

  // Verificar si la serie está activa (mirando)
  bool get isActive {
    return status == SeriesStatus.mirando;
  }

  // Verificar si la serie está terminada
  bool get isFinished {
    return status == SeriesStatus.terminada;
  }

  // Verificar si la serie está en espera
  bool get isWaiting {
    return status == SeriesStatus.enEspera;
  }

  // Obtener progreso actual
  String get currentProgress {
    return 'Temporada $currentSeason, Capítulo $currentEpisode';
  }

  // Calcular días desde que empezó a ver
  int? get daysWatching {
    if (startWatchingDate == null) return null;
    
    final endDate = finishWatchingDate ?? DateTime.now();
    return endDate.difference(startWatchingDate!).inDays;
  }

  // Obtener resumen del estado
  String get statusSummary {
    switch (status) {
      case SeriesStatus.nueva:
        return 'Lista para empezar';
      case SeriesStatus.mirando:
        final days = daysWatching;
        return 'Viendo desde hace ${days ?? 0} días';
      case SeriesStatus.terminada:
        final days = daysWatching;
        return 'Terminada (${days ?? 0} días)';
      case SeriesStatus.enEspera:
        return 'Esperando nueva temporada';
    }
  }

  Series copyWith({
    int? id,
    int? categoryId,
    String? name,
    String? description,
    SeriesStatus? status,
    int? currentSeason,
    int? currentEpisode,
    DateTime? startWatchingDate,
    DateTime? finishWatchingDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Series(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      currentSeason: currentSeason ?? this.currentSeason,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      startWatchingDate: startWatchingDate ?? this.startWatchingDate,
      finishWatchingDate: finishWatchingDate ?? this.finishWatchingDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Series(id: $id, categoryId: $categoryId, name: $name, status: $status, currentSeason: $currentSeason, currentEpisode: $currentEpisode)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Series &&
        other.id == id &&
        other.categoryId == categoryId &&
        other.name == name &&
        other.description == description &&
        other.status == status &&
        other.currentSeason == currentSeason &&
        other.currentEpisode == currentEpisode &&
        other.startWatchingDate == startWatchingDate &&
        other.finishWatchingDate == finishWatchingDate &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        categoryId.hashCode ^
        name.hashCode ^
        description.hashCode ^
        status.hashCode ^
        currentSeason.hashCode ^
        currentEpisode.hashCode ^
        startWatchingDate.hashCode ^
        finishWatchingDate.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
