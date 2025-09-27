import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'series.dart';
import 'season.dart';
import 'episode.dart';

class EpisodeLogEntry {
  final int episodeId;
  final int seasonId;
  final int seriesId;
  final String seriesName;
  final String categoryName;
  final int seasonNumber;
  final int episodeNumber;
  final String episodeTitle;
  final EpisodeStatus status;
  final DateTime? watchDate;

  EpisodeLogEntry({
    required this.episodeId,
    required this.seasonId,
    required this.seriesId,
    required this.seriesName,
    required this.categoryName,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.status,
    this.watchDate,
  });

  String get formattedEpisode {
    final season = seasonNumber.toString().padLeft(2, '0');
    final episode = episodeNumber.toString().padLeft(2, '0');
    return '$seriesName - ${season}x$episode';
  }

  String get formattedWatchDate {
    if (watchDate == null) return 'No visto';
    return DateFormat('dd/MM/yyyy HH:mm').format(watchDate!);
  }

  Color get statusColor {
    switch (status) {
      case EpisodeStatus.visto:
        return Colors.green;
      case EpisodeStatus.noVisto:
        return Colors.red;
      case EpisodeStatus.parcialmenteVisto:
        return Colors.orange;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case EpisodeStatus.visto:
        return Icons.check_circle;
      case EpisodeStatus.noVisto:
        return Icons.remove_circle_outline;
      case EpisodeStatus.parcialmenteVisto:
        return Icons.timelapse;
    }
  }

  // Verificar si está visto
  bool get isWatched => status == EpisodeStatus.visto;

  // Verificar si está pendiente
  bool get isPending => status == EpisodeStatus.noVisto;

  // Crear desde Series, Season y Episode
  factory EpisodeLogEntry.fromSeriesSeasonEpisode({
    required Series series,
    required Season season,
    required Episode episode,
    required String categoryName,
  }) {
    return EpisodeLogEntry(
      episodeId: episode.id!,
      seasonId: season.id!,
      seriesId: series.id!,
      seriesName: series.name,
      categoryName: categoryName,
      seasonNumber: season.seasonNumber,
      episodeNumber: episode.episodeNumber,
      episodeTitle: episode.title ?? 'Episodio ${episode.episodeNumber}',
      status: episode.status,
      watchDate: episode.watchDate,
    );
  }
}