import 'package:flutter/material.dart';

class Season {
  final int? id;
  final int seriesId;
  final int seasonNumber;
  final String? title;
  final int totalEpisodes;
  final int watchedEpisodes;
  final DateTime? releaseDate;
  final DateTime? finishDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Season({
    this.id,
    required this.seriesId,
    required this.seasonNumber,
    this.title,
    required this.totalEpisodes,
    required this.watchedEpisodes,
    this.releaseDate,
    this.finishDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'series_id': seriesId,
      'season_number': seasonNumber,
      'title': title,
      'total_episodes': totalEpisodes,
      'watched_episodes': watchedEpisodes,
      'release_date': releaseDate?.toIso8601String(),
      'finish_date': finishDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Season.fromMap(Map<String, dynamic> map) {
    return Season(
      id: map['id'] as int?,
      seriesId: map['series_id'] as int,
      seasonNumber: map['season_number'] as int,
      title: map['title'] as String?,
      totalEpisodes: map['total_episodes'] as int? ?? 0,
      watchedEpisodes: map['watched_episodes'] as int? ?? 0,
      releaseDate: map['release_date'] != null
          ? DateTime.parse(map['release_date'] as String)
          : null,
      finishDate: map['finish_date'] != null
          ? DateTime.parse(map['finish_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Verificar si la temporada está completa
  bool get isComplete {
    return watchedEpisodes >= totalEpisodes && totalEpisodes > 0;
  }

  // Verificar si la temporada está en progreso
  bool get isInProgress {
    return watchedEpisodes > 0 && watchedEpisodes < totalEpisodes;
  }

  // Verificar si la temporada no ha comenzado
  bool get isNotStarted {
    return watchedEpisodes == 0;
  }

  // Obtener progreso en porcentaje
  double get progressPercentage {
    if (totalEpisodes == 0) return 0.0;
    return (watchedEpisodes / totalEpisodes) * 100;
  }

  // Obtener capítulos restantes
  int get remainingEpisodes {
    return totalEpisodes - watchedEpisodes;
  }

  // Obtener el próximo capítulo a ver
  int get nextEpisode {
    return watchedEpisodes + 1;
  }

  // Verificar si hay un próximo capítulo disponible
  bool get hasNextEpisode {
    return nextEpisode <= totalEpisodes;
  }

  // Obtener estado de la temporada
  String get status {
    if (isComplete) {
      return 'Completada';
    } else if (isInProgress) {
      return 'En progreso';
    } else {
      return 'Iniciada';
    }
  }

  // Obtener color del estado
  Color get statusColor {
    if (isComplete) {
      return Colors.green;
    } else if (isInProgress) {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }

  // Obtener icono del estado
  IconData get statusIcon {
    if (isComplete) {
      return Icons.check_circle;
    } else if (isInProgress) {
      return Icons.play_circle;
    } else {
      return Icons.play_circle_outline;
    }
  }

  // Obtener resumen de progreso
  String get progressSummary {
    return '$watchedEpisodes/$totalEpisodes capítulos';
  }

  // Obtener título de la temporada
  String get displayTitle {
    return title ?? 'Temporada $seasonNumber';
  }

  // Calcular días desde el inicio de la temporada
  int? get daysSinceStart {
    if (releaseDate == null) return null;
    
    final endDate = finishDate ?? DateTime.now();
    return endDate.difference(releaseDate!).inDays;
  }

  // Calcular días desde el final de la temporada
  int? get daysSinceFinish {
    if (finishDate == null) return null;
    return DateTime.now().difference(finishDate!).inDays;
  }

  Season copyWith({
    int? id,
    int? seriesId,
    int? seasonNumber,
    String? title,
    int? totalEpisodes,
    int? watchedEpisodes,
    DateTime? releaseDate,
    DateTime? finishDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Season(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      title: title ?? this.title,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      watchedEpisodes: watchedEpisodes ?? this.watchedEpisodes,
      releaseDate: releaseDate ?? this.releaseDate,
      finishDate: finishDate ?? this.finishDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Season(id: $id, seriesId: $seriesId, seasonNumber: $seasonNumber, title: $title, totalEpisodes: $totalEpisodes, watchedEpisodes: $watchedEpisodes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Season &&
        other.id == id &&
        other.seriesId == seriesId &&
        other.seasonNumber == seasonNumber &&
        other.title == title &&
        other.totalEpisodes == totalEpisodes &&
        other.watchedEpisodes == watchedEpisodes &&
        other.releaseDate == releaseDate &&
        other.finishDate == finishDate &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        seriesId.hashCode ^
        seasonNumber.hashCode ^
        title.hashCode ^
        totalEpisodes.hashCode ^
        watchedEpisodes.hashCode ^
        releaseDate.hashCode ^
        finishDate.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
