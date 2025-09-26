import 'package:flutter/material.dart';

enum EpisodeStatus {
  noVisto('No Visto'),
  visto('Visto'),
  parcialmenteVisto('Parcialmente Visto');

  const EpisodeStatus(this.displayName);
  final String displayName;
}

class Episode {
  final int? id;
  final int seasonId;
  final int episodeNumber;
  final String? title;
  final String? description;
  final EpisodeStatus status;
  final Duration? duration;
  final double? watchProgress; // 0.0 a 1.0
  final DateTime? watchDate;
  final int? rating; // 1-5 estrellas
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Episode({
    this.id,
    required this.seasonId,
    required this.episodeNumber,
    this.title,
    this.description,
    required this.status,
    this.duration,
    this.watchProgress,
    this.watchDate,
    this.rating,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'season_id': seasonId,
      'episode_number': episodeNumber,
      'title': title,
      'description': description,
      'status': status.name,
      'duration': duration?.inMinutes,
      'watch_progress': watchProgress,
      'watch_date': watchDate?.toIso8601String(),
      'rating': rating,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Episode.fromMap(Map<String, dynamic> map) {
    return Episode(
      id: map['id'] as int?,
      seasonId: map['season_id'] as int,
      episodeNumber: map['episode_number'] as int,
      title: map['title'] as String?,
      description: map['description'] as String?,
      status: EpisodeStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => EpisodeStatus.noVisto,
      ),
      duration: map['duration'] != null
          ? Duration(minutes: map['duration'] as int)
          : null,
      watchProgress: (map['watch_progress'] as num?)?.toDouble(),
      watchDate: map['watch_date'] != null
          ? DateTime.parse(map['watch_date'] as String)
          : null,
      rating: map['rating'] as int?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Verificar si el capítulo está completamente visto
  bool get isWatched {
    return status == EpisodeStatus.visto;
  }

  // Verificar si el capítulo está parcialmente visto
  bool get isPartiallyWatched {
    return status == EpisodeStatus.parcialmenteVisto;
  }

  // Verificar si el capítulo no ha sido visto
  bool get isNotWatched {
    return status == EpisodeStatus.noVisto;
  }

  // Obtener color del estado
  Color get statusColor {
    switch (status) {
      case EpisodeStatus.noVisto:
        return Colors.grey;
      case EpisodeStatus.parcialmenteVisto:
        return Colors.orange;
      case EpisodeStatus.visto:
        return Colors.green;
    }
  }

  // Obtener icono del estado
  IconData get statusIcon {
    switch (status) {
      case EpisodeStatus.noVisto:
        return Icons.play_circle_outline;
      case EpisodeStatus.parcialmenteVisto:
        return Icons.play_circle;
      case EpisodeStatus.visto:
        return Icons.check_circle;
    }
  }

  // Obtener título del capítulo
  String get displayTitle {
    return title ?? 'Capítulo $episodeNumber';
  }

  // Obtener duración formateada
  String get formattedDuration {
    if (duration == null) return 'Duración desconocida';
    
    final hours = duration!.inHours;
    final minutes = duration!.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  // Obtener progreso formateado
  String get formattedProgress {
    if (watchProgress == null) return '0%';
    return '${(watchProgress! * 100).toInt()}%';
  }

  // Obtener calificación con estrellas
  String get ratingStars {
    if (rating == null) return 'Sin calificar';
    return '★' * rating! + '☆' * (5 - rating!);
  }

  // Calcular tiempo restante
  Duration? get remainingTime {
    if (duration == null || watchProgress == null) return null;
    
    final totalMinutes = duration!.inMinutes;
    final watchedMinutes = (totalMinutes * watchProgress!).round();
    return Duration(minutes: totalMinutes - watchedMinutes);
  }

  // Obtener tiempo restante formateado
  String get formattedRemainingTime {
    final remaining = remainingTime;
    if (remaining == null) return 'Tiempo desconocido';
    
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m restantes';
    } else {
      return '${minutes}m restantes';
    }
  }

  // Obtener tiempo visto formateado
  String get formattedWatchedTime {
    if (duration == null || watchProgress == null) return '0m';
    
    final totalMinutes = duration!.inMinutes;
    final watchedMinutes = (totalMinutes * watchProgress!).round();
    
    final hours = watchedMinutes ~/ 60;
    final minutes = watchedMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m visto';
    } else {
      return '${minutes}m visto';
    }
  }

  // Verificar si tiene calificación
  bool get hasRating {
    return rating != null && rating! > 0;
  }

  // Verificar si tiene notas
  bool get hasNotes {
    return notes != null && notes!.isNotEmpty;
  }

  // Obtener resumen del capítulo
  String get summary {
    final parts = <String>[];
    
    parts.add(displayTitle);
    
    if (duration != null) {
      parts.add(formattedDuration);
    }
    
    if (isWatched) {
      parts.add('Visto');
      if (watchDate != null) {
        parts.add('el ${watchDate!.day}/${watchDate!.month}/${watchDate!.year}');
      }
    } else if (isPartiallyWatched) {
      parts.add(formattedProgress);
    }
    
    if (hasRating) {
      parts.add(ratingStars);
    }
    
    return parts.join(' • ');
  }

  Episode copyWith({
    int? id,
    int? seasonId,
    int? episodeNumber,
    String? title,
    String? description,
    EpisodeStatus? status,
    Duration? duration,
    double? watchProgress,
    DateTime? watchDate,
    int? rating,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Episode(
      id: id ?? this.id,
      seasonId: seasonId ?? this.seasonId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      duration: duration ?? this.duration,
      watchProgress: watchProgress ?? this.watchProgress,
      watchDate: watchDate ?? this.watchDate,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Episode(id: $id, seasonId: $seasonId, episodeNumber: $episodeNumber, title: $title, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Episode &&
        other.id == id &&
        other.seasonId == seasonId &&
        other.episodeNumber == episodeNumber &&
        other.title == title &&
        other.description == description &&
        other.status == status &&
        other.duration == duration &&
        other.watchProgress == watchProgress &&
        other.watchDate == watchDate &&
        other.rating == rating &&
        other.notes == notes &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        seasonId.hashCode ^
        episodeNumber.hashCode ^
        title.hashCode ^
        description.hashCode ^
        status.hashCode ^
        duration.hashCode ^
        watchProgress.hashCode ^
        watchDate.hashCode ^
        rating.hashCode ^
        notes.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
