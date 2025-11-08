import 'package:flutter/material.dart';

enum PendingItemType {
  pelicula('Película'),
  serie('Serie'),
  anime('Anime');

  const PendingItemType(this.displayName);
  final String displayName;
}

enum PendingItemStatus {
  pendiente('Pendiente'),
  mirando('Mirando'),
  visto('Visto');

  const PendingItemStatus(this.displayName);
  final String displayName;
}

enum SeriesFormat {
  format24min('24 min'),
  format40min('40 min');

  const SeriesFormat(this.displayName);
  final String displayName;
}

class PendingItem {
  final int? id;
  final PendingItemType type;
  final String title;
  final int? year; // Para películas
  final DateTime? startDate; // Para series/anime
  final DateTime? endDate; // Para series/anime (null si está en emisión)
  final bool isOngoing; // Para series/anime: true si está en emisión
  final SeriesFormat? seriesFormat; // Para series: 24 min o 40 min
  final PendingItemStatus status;
  final DateTime? watchedDate; // Fecha en que se marcó como visto
  final DateTime createdAt;
  final DateTime updatedAt;

  PendingItem({
    this.id,
    required this.type,
    required this.title,
    this.year,
    this.startDate,
    this.endDate,
    this.isOngoing = false,
    this.seriesFormat,
    required this.status,
    this.watchedDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'year': year,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_ongoing': isOngoing ? 1 : 0,
      'series_format': seriesFormat?.name,
      'status': status.name,
      'watched_date': watchedDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PendingItem.fromMap(Map<String, dynamic> map) {
    return PendingItem(
      id: map['id'] as int?,
      type: PendingItemType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => PendingItemType.pelicula,
      ),
      title: map['title'] as String,
      year: map['year'] as int?,
      startDate: map['start_date'] != null
          ? DateTime.parse(map['start_date'] as String)
          : null,
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      isOngoing: (map['is_ongoing'] as int? ?? 0) == 1,
      seriesFormat: map['series_format'] != null
          ? SeriesFormat.values.firstWhere(
              (f) => f.name == map['series_format'],
              orElse: () => SeriesFormat.format24min,
            )
          : null,
      status: PendingItemStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => PendingItemStatus.pendiente,
      ),
      watchedDate: map['watched_date'] != null
          ? DateTime.parse(map['watched_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Obtener color del estado
  Color get statusColor {
    switch (status) {
      case PendingItemStatus.pendiente:
        return Colors.grey;
      case PendingItemStatus.mirando:
        return Colors.blue;
      case PendingItemStatus.visto:
        return Colors.green;
    }
  }

  // Obtener icono del estado
  IconData get statusIcon {
    switch (status) {
      case PendingItemStatus.pendiente:
        return Icons.pending;
      case PendingItemStatus.mirando:
        return Icons.play_circle;
      case PendingItemStatus.visto:
        return Icons.check_circle;
    }
  }

  // Obtener icono del tipo
  IconData get typeIcon {
    switch (type) {
      case PendingItemType.pelicula:
        return Icons.movie;
      case PendingItemType.serie:
        return Icons.tv;
      case PendingItemType.anime:
        return Icons.animation;
    }
  }

  // Obtener color del tipo
  Color get typeColor {
    switch (type) {
      case PendingItemType.pelicula:
        return Colors.purple;
      case PendingItemType.serie:
        return Colors.blue;
      case PendingItemType.anime:
        return Colors.pink;
    }
  }

  // Obtener información de fecha para mostrar
  String get dateInfo {
    if (type == PendingItemType.pelicula) {
      return year != null ? 'Año: $year' : 'Sin año';
    } else {
      String formatInfo = '';
      if (type == PendingItemType.serie && seriesFormat != null) {
        formatInfo = ' (${seriesFormat!.displayName})';
      }
      
      if (isOngoing) {
        return startDate != null
            ? 'En emisión desde ${_formatDate(startDate!)}$formatInfo'
            : 'En emisión$formatInfo';
      } else {
        if (startDate != null && endDate != null) {
          return '${_formatDate(startDate!)} - ${_formatDate(endDate!)}$formatInfo';
        } else if (startDate != null) {
          return 'Inicio: ${_formatDate(startDate!)}$formatInfo';
        } else if (endDate != null) {
          return 'Fin: ${_formatDate(endDate!)}$formatInfo';
        } else {
          return 'Sin fechas$formatInfo';
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  PendingItem copyWith({
    int? id,
    PendingItemType? type,
    String? title,
    int? year,
    DateTime? startDate,
    DateTime? endDate,
    bool? isOngoing,
    SeriesFormat? seriesFormat,
    PendingItemStatus? status,
    DateTime? watchedDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PendingItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      year: year ?? this.year,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isOngoing: isOngoing ?? this.isOngoing,
      seriesFormat: seriesFormat ?? this.seriesFormat,
      status: status ?? this.status,
      watchedDate: watchedDate ?? this.watchedDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'PendingItem(id: $id, type: $type, title: $title, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PendingItem &&
        other.id == id &&
        other.type == type &&
        other.title == title &&
        other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^ type.hashCode ^ title.hashCode ^ status.hashCode;
  }
}

